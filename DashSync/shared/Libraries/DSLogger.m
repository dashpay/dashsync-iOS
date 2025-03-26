//
//  Created by Andrew Podkovyrin
//  Copyright © 2019 Dash Core Group. All rights reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://opensource.org/licenses/MIT
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "DSLogger.h"
#import "CompressingLogFileManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface NoTimestampLogFormatter : NSObject <DDLogFormatter>
@end
@implementation NoTimestampLogFormatter
- (nullable NSString *)formatLogMessage:(DDLogMessage *)logMessage {
    return logMessage.message;
}
@end

@interface DSLogger ()

@property (readonly, nonatomic, strong) DDFileLogger *fileLogger;

@end

@implementation DSLogger

+ (instancetype)sharedInstance {
    static DSLogger *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] init];
    });
    return _sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [DDLog addLogger:[DDOSLogger sharedInstance]]; // os_log

        unsigned long long maxFileSize = 1024 * 1024 * 5; // 5 MB max. Then log files are ziped
        CompressingLogFileManager *logFileManager = [[CompressingLogFileManager alloc] initWithFileSize:maxFileSize];
        DDFileLogger *fileLogger = [[DDFileLogger alloc] initWithLogFileManager:logFileManager];
        fileLogger.rollingFrequency = 60 * 60 * 24;     // 24 hour rolling
        fileLogger.maximumFileSize = maxFileSize;
        fileLogger.logFileManager.maximumNumberOfLogFiles = 10;
        
        [DDLog addLogger:fileLogger];
        _fileLogger = fileLogger;
    }
    return self;
}

- (NSArray<NSURL *> *)logFiles {
    NSString *logsDirectory = [self.fileLogger.logFileManager logsDirectory];
    NSArray *fileNames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:logsDirectory error:nil];
    NSMutableArray *logFiles = [NSMutableArray arrayWithCapacity:[fileNames count]];

    for (NSString *fileName in fileNames) {
        BOOL hasProperSuffix = [fileName hasSuffix:@".log"] || [fileName hasSuffix:@".gz"];
        
        if (hasProperSuffix) {
            NSString *filePath = [logsDirectory stringByAppendingPathComponent:fileName];
            NSURL *fileURL = [NSURL fileURLWithPath:filePath];
            
            if (fileURL) {
                [logFiles addObject:fileURL];
            }
        }
    }
    
    return [logFiles copy];
}

+ (void)log:(NSString *)message {
    DSLog(@"%@", message);
}

@end

NS_ASSUME_NONNULL_END
