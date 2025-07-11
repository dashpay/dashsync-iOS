//
//  CompressingLogFileManager.m
//  LogFileCompressor
//
//  CocoaLumberjack Demos
//

#import "CompressingLogFileManager.h"
#import "dash_shared_core.h"
#import <zlib.h>

// We probably shouldn't be using DDLog() statements within the DDLog implementation.
// But we still want to leave our log statements for any future debugging,
// and to allow other developers to trace the implementation (which is a great learning tool).
//
// So we use primitive logging macros around NSLog.
// We maintain the NS prefix on the macros to be explicit about the fact that we're using NSLog.

#define LOG_LEVEL 4

#define NSLogError(frmt, ...)    do{ if(LOG_LEVEL >= 1) NSLog(frmt, ##__VA_ARGS__); } while(0)
#define NSLogWarn(frmt, ...)     do{ if(LOG_LEVEL >= 2) NSLog(frmt, ##__VA_ARGS__); } while(0)
#define NSLogInfo(frmt, ...)     do{ if(LOG_LEVEL >= 3) NSLog(frmt, ##__VA_ARGS__); } while(0)
#define NSLogVerbose(frmt, ...)  do{ if(LOG_LEVEL >= 4) NSLog(frmt, ##__VA_ARGS__); } while(0)

@interface CompressingLogFileManager (/* Must be nameless for properties */)

@property (readwrite) BOOL isCompressing;

@end

@interface DDLogFileInfo (Compressor)

@property (nonatomic, readonly) BOOL isCompressed;

- (NSString *)tempFilePathByAppendingPathExtension:(NSString *)newExt;
- (NSString *)fileNameByAppendingPathExtension:(NSString *)newExt;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation CompressingLogFileManager

@synthesize isCompressing;

- (instancetype)initWithFileSize:(unsigned long long)maxFileSize {
    self = [self initWithLogsDirectory:nil];
    if (self) {
        _maxFileSize = maxFileSize;
    }
    return self;
}

- (id)init
{
    return [self initWithLogsDirectory:nil];
}

- (id)initWithLogsDirectory:(NSString *)aLogsDirectory
{
    if ((self = [super initWithLogsDirectory:aLogsDirectory]))
    {
        upToDate = NO;
        
        // Check for any files that need to be compressed.
        // But don't start right away.
        // Wait for the app startup process to finish.
        
        [self performSelector:@selector(compressNextLogFile) withObject:nil afterDelay:5.0];
    }
    return self;
}

- (void)dealloc
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(compressNextLogFile) object:nil];
}

- (void)compressLogFile:(DDLogFileInfo *)logFile
{
    self.isCompressing = YES;

    CompressingLogFileManager* __weak weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [weakSelf backgroundThread_CompressLogFile:logFile];
    });
}

- (void)compressNextLogFile
{
    if (self.isCompressing)
    {
        // We're already compressing a file.
        // Wait until it's done to move onto the next file.
        return;
    }
    
    NSLogVerbose(@"CompressingLogFileManager: compressNextLogFile");
    
    upToDate = NO;
    
    NSMutableArray *sortedLogFileInfos = [[self sortedLogFileInfos] mutableCopy];
    [self handleProcessorLogRotationWithSortedLogs:sortedLogFileInfos];
    
    NSUInteger count = [sortedLogFileInfos count];
    if (count == 0)
    {
        // Nothing to compress
        upToDate = YES;
        return;
    }
    
    NSUInteger i = count;
    while (i > 0)
    {
        DDLogFileInfo *logFileInfo = [sortedLogFileInfos objectAtIndex:(i - 1)];
        
        if ((logFileInfo.isArchived || [logFileInfo.fileName hasPrefix:@"processor"]) && !logFileInfo.isCompressed)
        {
            [self compressLogFile:logFileInfo];
            
            break;
        }
        
        i--;
    }
    
    upToDate = YES;
}

- (void)handleProcessorLogRotationWithSortedLogs:(NSMutableArray *)sortedLogFileInfos {
    // Get all processor log files
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *files = [fileManager contentsOfDirectoryAtPath:self.logsDirectory error:nil];
    NSMutableArray *processorLogs = [NSMutableArray array];
    NSMutableArray *compressedLogs = [NSMutableArray array];
    
    // Separate processor logs into compressed and uncompressed
    for (NSString *file in files) {
        if ([file hasPrefix:@"processor."]) {
            NSArray *components = [file componentsSeparatedByString:@"."];
            if (components.count >= 3) {
                if ([file hasSuffix:@".gz"]) {
                    [compressedLogs addObject:file];
                } else {
                    [processorLogs addObject:file]; 
                }
            }
        }
    }
    
    // Remove compressed logs older than 5 days
    NSDate *cutoffDate = [NSDate dateWithTimeIntervalSinceNow:-5 * 24 * 60 * 60];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd"];
    
    for (NSString *file in compressedLogs) {
        // Extract date from filename (assuming format processor.[date].log.gz)
        NSArray *components = [file componentsSeparatedByString:@"."];
        if (components.count >= 2) {
            NSString *dateString = components[1];
            NSDate *fileDate = [dateFormatter dateFromString:dateString];
            
            if (fileDate && [fileDate compare:cutoffDate] == NSOrderedAscending) {
                NSString *fullPath = [self.logsDirectory stringByAppendingPathComponent:file];
                [fileManager removeItemAtPath:fullPath error:nil];
            }
        }
    }
    
    // Handle uncompressed processor logs
    if (processorLogs.count > 1) {
        // Sort by date (oldest first)
        [processorLogs sortUsingComparator:^NSComparisonResult(NSString *file1, NSString *file2) {
            return [file1 compare:file2];
        }];
        
        // Add older logs to sortedLogFileInfos for compression
        for (NSInteger i = 0; i < processorLogs.count - 1; i++) {
            NSString *logPath = [self.logsDirectory stringByAppendingPathComponent:processorLogs[i]];
            [sortedLogFileInfos addObject:[DDLogFileInfo logFileWithPath:logPath]];
        }
    }
}

- (void)compressionDidSucceed:(DDLogFileInfo *)logFile
{
    NSLogVerbose(@"CompressingLogFileManager: compressionDidSucceed: %@", logFile.fileName);
    
    self.isCompressing = NO;
    
    [self compressNextLogFile];
}

- (void)compressionDidFail:(DDLogFileInfo *)logFile
{
    NSLogWarn(@"CompressingLogFileManager: compressionDidFail: %@", logFile.fileName);
    
    self.isCompressing = NO;
    
    // We should try the compression again, but after a short delay.
    //
    // If the compression failed there is probably some filesystem issue,
    // so flooding it with compression attempts is only going to make things worse.
    
    NSTimeInterval delay = (60 * 15); // 15 minutes
    
    [self performSelector:@selector(compressNextLogFile) withObject:nil afterDelay:delay];
}

- (void)didArchiveLogFile:(NSString *)logFilePath wasRolled:(BOOL)wasRolled {
    NSLogVerbose(@"CompressingLogFileManager: didArchiveLogFile: %@ wasRolled: %@",
                 [logFilePath lastPathComponent], (wasRolled ? @"YES" : @"NO"));

    // If all other log files have been compressed, then we can get started right away.
    // Otherwise we should just wait for the current compression process to finish.

    if (upToDate)
    {
        [self compressLogFile:[DDLogFileInfo logFileWithPath:logFilePath]];
    }
}

- (void)backgroundThread_CompressLogFile:(DDLogFileInfo *)logFile
{
    @autoreleasepool {
    
    NSLogInfo(@"CompressingLogFileManager: Compressing log file: %@", logFile.fileName);
    
    // Steps:
    //  1. Create a new file with the same fileName, but added "gzip" extension
    //  2. Open the new file for writing (output file)
    //  3. Open the given file for reading (input file)
    //  4. Setup zlib for gzip compression
    //  5. Read a chunk of the given file
    //  6. Compress the chunk
    //  7. Write the compressed chunk to the output file
    //  8. Repeat steps 5 - 7 until the input file is exhausted
    //  9. Close input and output file
    // 10. Teardown zlib
    
    
    // STEP 1
    
    NSString *inputFilePath = logFile.filePath;
    
    NSString *tempOutputFilePath = [logFile tempFilePathByAppendingPathExtension:@"gz"];
    
#if TARGET_OS_IPHONE
    // We use the same protection as the original file.  This means that it has the same security characteristics.
    // Also, if the app can run in the background, this means that it gets
    // NSFileProtectionCompleteUntilFirstUserAuthentication so that we can do this compression even with the
    // device locked.  c.f. DDFileLogger.doesAppRunInBackground.
    NSString* protection = logFile.fileAttributes[NSFileProtectionKey];
    NSDictionary* attributes = protection == nil ? nil : @{NSFileProtectionKey: protection};
    [[NSFileManager defaultManager] createFileAtPath:tempOutputFilePath contents:nil attributes:attributes];
#endif
    
    // STEP 2 & 3
    
    NSInputStream *inputStream = [NSInputStream inputStreamWithFileAtPath:inputFilePath];
    NSOutputStream *outputStream = [NSOutputStream outputStreamToFileAtPath:tempOutputFilePath append:NO];
    
    [inputStream open];
    [outputStream open];
    
    // STEP 4
    
    z_stream strm;
    
    // Zero out the structure before (to be safe) before we start using it
    bzero(&strm, sizeof(strm));
    
    strm.zalloc = Z_NULL;
    strm.zfree = Z_NULL;
    strm.opaque = Z_NULL;
    strm.total_out = 0;
    
    // Compresssion Levels:
    //   Z_NO_COMPRESSION
    //   Z_BEST_SPEED
    //   Z_BEST_COMPRESSION
    //   Z_DEFAULT_COMPRESSION
    
    deflateInit2(&strm, Z_BEST_COMPRESSION, Z_DEFLATED, (15+16), 9, Z_DEFAULT_STRATEGY);
    
    // Prepare our variables for steps 5-7
    //
    // inputDataLength  : Total length of buffer that we will read file data into
    // outputDataLength : Total length of buffer that zlib will output compressed bytes into
    //
    // Note: The output buffer can be smaller than the input buffer because the
    //       compressed/output data is smaller than the file/input data (obviously).
    //
    // inputDataSize : The number of bytes in the input buffer that have valid data to be compressed.
    //
    // Imagine compressing a tiny file that is actually smaller than our inputDataLength.
    // In this case only a portion of the input buffer would have valid file data.
    // The inputDataSize helps represent the portion of the buffer that is valid.
    //
    // Imagine compressing a huge file, but consider what happens when we get to the very end of the file.
    // The last read will likely only fill a portion of the input buffer.
    // The inputDataSize helps represent the portion of the buffer that is valid.
    
    NSUInteger inputDataLength  = (1024 * 64);  // 64 KB
    NSUInteger outputDataLength = (1024 * 32);  // 32 KB
    
    NSMutableData *inputData = [NSMutableData dataWithLength:inputDataLength];
    NSMutableData *outputData = [NSMutableData dataWithLength:outputDataLength];
    
    NSUInteger inputDataSize = 0;
    
    BOOL done = YES;
    NSError* error = nil;
    do
    {
        @autoreleasepool {
        
        // STEP 5
        // Read data from the input stream into our input buffer.
        //
        // inputBuffer : pointer to where we want the input stream to copy bytes into
        // inputBufferLength : max number of bytes the input stream should read
        //
        // Recall that inputDataSize is the number of valid bytes that already exist in the
        // input buffer that still need to be compressed.
        // This value is usually zero, but may be larger if a previous iteration of the loop
        // was unable to compress all the bytes in the input buffer.
        //
        // For example, imagine that we ready 2K worth of data from the file in the last loop iteration,
        // but when we asked zlib to compress it all, zlib was only able to compress 1.5K of it.
        // We would still have 0.5K leftover that still needs to be compressed.
        // We want to make sure not to skip this important data.
        //
        // The [inputData mutableBytes] gives us a pointer to the beginning of the underlying buffer.
        // When we add inputDataSize we get to the proper offset within the buffer
        // at which our input stream can start copying bytes into without overwriting anything it shouldn't.
        
        const void *inputBuffer = [inputData mutableBytes] + inputDataSize;
        NSUInteger inputBufferLength = inputDataLength - inputDataSize;
        
        NSInteger readLength = [inputStream read:(uint8_t *)inputBuffer maxLength:inputBufferLength];
        if (readLength < 0) {
            error = [inputStream streamError];
            break;
        }
        
        NSLogVerbose(@"CompressingLogFileManager: Read %li bytes from file", (long)readLength);
        
        inputDataSize += readLength;
        
        // STEP 6
        // Ask zlib to compress our input buffer.
        // Tell it to put the compressed bytes into our output buffer.
        
        strm.next_in = (Bytef *)[inputData mutableBytes];   // Read from input buffer
        strm.avail_in = (uInt)inputDataSize;                // as much as was read from file (plus leftovers).
        
        strm.next_out = (Bytef *)[outputData mutableBytes]; // Write data to output buffer
        strm.avail_out = (uInt)outputDataLength;            // as much space as is available in the buffer.
        
        // When we tell zlib to compress our data,
        // it won't directly tell us how much data was processed.
        // Instead it keeps a running total of the number of bytes it has processed.
        // In other words, every iteration from the loop it increments its total values.
        // So to figure out how much data was processed in this iteration,
        // we fetch the totals before we ask it to compress data,
        // and then afterwards we subtract from the new totals.
        
        NSUInteger prevTotalIn = strm.total_in;
        NSUInteger prevTotalOut = strm.total_out;
        
        int flush = [inputStream hasBytesAvailable] ? Z_SYNC_FLUSH : Z_FINISH;
        deflate(&strm, flush);
        
        NSUInteger inputProcessed = strm.total_in - prevTotalIn;
        NSUInteger outputProcessed = strm.total_out - prevTotalOut;
        
        NSLogVerbose(@"CompressingLogFileManager: Total bytes uncompressed: %lu", (unsigned long)strm.total_in);
        NSLogVerbose(@"CompressingLogFileManager: Total bytes compressed: %lu", (unsigned long)strm.total_out);
        NSLogVerbose(@"CompressingLogFileManager: Compression ratio: %.1f%%",
                     (double)(1.0F - (float)(strm.total_out) / (float)(strm.total_in)) * 100);
        
        // STEP 7
        // Now write all compressed bytes to our output stream.
        //
        // It is theoretically possible that the write operation doesn't write everything we ask it to.
        // Although this is highly unlikely, we take precautions.
        // Also, we watch out for any errors (maybe the disk is full).
        
        NSUInteger totalWriteLength = 0;
        NSInteger writeLength = 0;
        
        do
        {
            const void *outputBuffer = [outputData mutableBytes] + totalWriteLength;
            NSUInteger outputBufferLength = outputProcessed - totalWriteLength;
            
            writeLength = [outputStream write:(const uint8_t *)outputBuffer maxLength:outputBufferLength];
            
            if (writeLength < 0)
            {
                error = [outputStream streamError];
            }
            else
            {
                totalWriteLength += writeLength;
            }
            
        } while((totalWriteLength < outputProcessed) && !error);
        
        // STEP 7.5
        //
        // We now have data in our input buffer that has already been compressed.
        // We want to remove all the processed data from the input buffer,
        // and we want to move any unprocessed data to the beginning of the buffer.
        //
        // If the amount processed is less than the valid buffer size, we have leftovers.
        
        NSUInteger inputRemaining = inputDataSize - inputProcessed;
        if (inputRemaining > 0)
        {
            void *inputDst = [inputData mutableBytes];
            void *inputSrc = [inputData mutableBytes] + inputProcessed;
            
            memmove(inputDst, inputSrc, inputRemaining);
        }
        
        inputDataSize = inputRemaining;
        
        // Are we done yet?
        
        done = ((flush == Z_FINISH) && (inputDataSize == 0));
        
        // STEP 8
        // Loop repeats until end of data (or unlikely error)
        
        } // end @autoreleasepool
        
    } while (!done && error == nil);
    
    // STEP 9
    
    [inputStream close];
    [outputStream close];
    
    // STEP 10
    
    deflateEnd(&strm);
    
    // We're done!
    // Report success or failure back to the logging thread/queue.
    
    if (error)
    {
        // Remove output file.
        // Our compression attempt failed.

        NSLogError(@"Compression of %@ failed: %@", inputFilePath, error);
        error = nil;
        BOOL ok = [[NSFileManager defaultManager] removeItemAtPath:tempOutputFilePath error:&error];
        if (!ok)
            NSLogError(@"Failed to clean up %@ after failed compression: %@", tempOutputFilePath, error);
        
        // Report failure to class via logging thread/queue
        
        dispatch_async([DDLog loggingQueue], ^{ @autoreleasepool {
            [self compressionDidFail:logFile];
        }});
    }
    else
    {
        // Remove original input file.
        // It will be replaced with the new compressed version.

        error = nil;
        BOOL ok = [[NSFileManager defaultManager] removeItemAtPath:inputFilePath error:&error];
        if (!ok)
            NSLogWarn(@"Warning: failed to remove original file %@ after compression: %@", inputFilePath, error);
        
        // Mark the compressed file as archived,
        // and then move it into its final destination.
        //
        // temp-log-ABC123.txt.gz -> log-ABC123.txt.gz
        //
        // The reason we were using the "temp-" prefix was so the file would not be
        // considered a log file while it was only partially complete.
        // Only files that begin with "log-" are considered log files.
        
        DDLogFileInfo *compressedLogFile = [DDLogFileInfo logFileWithPath:tempOutputFilePath];
        compressedLogFile.isArchived = YES;
        
        NSString *outputFileName = [logFile fileNameByAppendingPathExtension:@"gz"];
        [compressedLogFile renameFile:outputFileName];
        
        // Report success to class via logging thread/queue
        
        dispatch_async([DDLog loggingQueue], ^{ @autoreleasepool {
            [self compressionDidSucceed:compressedLogFile];
        }});
    }
    
    } // end @autoreleasepool
}
                 
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation DDLogFileInfo (Compressor)

@dynamic isCompressed;

- (BOOL)isCompressed
{
    return [[[self fileName] pathExtension] isEqualToString:@"gz"];
}

- (NSString *)tempFilePathByAppendingPathExtension:(NSString *)newExt
{
    // Example:
    //
    // Current File Name: "/full/path/to/log-ABC123.txt"
    //
    // newExt: "gzip"
    // result: "/full/path/to/temp-log-ABC123.txt.gzip"
    
    NSString *tempFileName = [NSString stringWithFormat:@"temp-%@", [self fileName]];
    
    NSString *newFileName = [tempFileName stringByAppendingPathExtension:newExt];
    
    NSString *fileDir = [[self filePath] stringByDeletingLastPathComponent];
    
    NSString *newFilePath = [fileDir stringByAppendingPathComponent:newFileName];
    
    return newFilePath;
}

- (NSString *)fileNameByAppendingPathExtension:(NSString *)newExt
{
    // Example:
    //
    // Current File Name: "log-ABC123.txt"
    //
    // newExt: "gzip"
    // result: "log-ABC123.txt.gzip"
    
    NSString *fileNameExtension = [[self fileName] pathExtension];
    
    if ([fileNameExtension isEqualToString:newExt])
    {
        return [self fileName];
    }
    
    return [[self fileName] stringByAppendingPathExtension:newExt];
}

@end
