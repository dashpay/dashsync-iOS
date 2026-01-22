//
//  DSChainSyncSpeedCalculator.m
//  DashSync
//
//  Created for improved logging to match Android/DashJ behavior.
//  Copyright (c) 2024 Dash Core Group. All rights reserved.
//

#import "DSChainSyncSpeedCalculator.h"
#import "DSLogger.h"

// Log interval in seconds (matches Android)
static const NSTimeInterval kLogIntervalSeconds = 1.0;

// Stall detection - if no progress for this many seconds, consider stalled
static const NSTimeInterval kStallDetectionSeconds = 30.0;

@interface DSChainSyncSpeedCalculator ()

@property (nonatomic, strong) NSTimer *logTimer;
@property (nonatomic, strong) dispatch_queue_t statsQueue;

// Current interval counters
@property (atomic, assign) NSUInteger blocksThisInterval;
@property (atomic, assign) NSUInteger transactionsThisInterval;
@property (atomic, assign) NSUInteger preFilteredTxThisInterval;
@property (atomic, assign) NSUInteger headersThisInterval;
@property (atomic, assign) NSUInteger mnListDiffsThisInterval;
@property (atomic, assign) NSUInteger bytesThisInterval;

// Cumulative counters for averaging
@property (atomic, assign) NSUInteger totalBlocks;
@property (atomic, assign) NSUInteger totalTransactions;
@property (atomic, assign) NSUInteger totalBytes;
@property (atomic, assign) NSTimeInterval startTime;

// Rolling averages
@property (atomic, assign) double avgKBPerSec;
@property (atomic, assign) double lastKBPerSec;

// Chain heights for stall detection
@property (atomic, assign) uint32_t chainHeight;
@property (atomic, assign) uint32_t commonHeight;
@property (atomic, assign) uint32_t targetHeight;
@property (atomic, assign) NSTimeInterval lastProgressTime;
@property (atomic, assign) uint32_t lastChainHeight;

// History for statistics logging (ring buffer of last 10 intervals)
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *historyBuffer;
@property (atomic, assign) NSUInteger historyIndex;

@end

@implementation DSChainSyncSpeedCalculator

+ (instancetype)sharedInstance {
    static DSChainSyncSpeedCalculator *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _statsQueue = dispatch_queue_create("org.dashcore.dashsync.speedcalculator", DISPATCH_QUEUE_SERIAL);
        _historyBuffer = [NSMutableArray arrayWithCapacity:10];
        [self reset];
    }
    return self;
}

- (void)startCalculating {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.logTimer invalidate];
        self.startTime = [[NSDate date] timeIntervalSince1970];
        self.lastProgressTime = self.startTime;
        self.logTimer = [NSTimer scheduledTimerWithTimeInterval:kLogIntervalSeconds
                                                         target:self
                                                       selector:@selector(timerFired)
                                                       userInfo:nil
                                                        repeats:YES];
        [[NSRunLoop currentRunLoop] addTimer:self.logTimer forMode:NSRunLoopCommonModes];
    });
}

- (void)stopCalculating {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.logTimer invalidate];
        self.logTimer = nil;
    });
}

- (void)timerFired {
    [self logCurrentStats];
    [self resetIntervalCounters];
}

- (void)recordBlockReceived {
    dispatch_async(self.statsQueue, ^{
        self.blocksThisInterval++;
        self.totalBlocks++;
    });
}

- (void)recordBlocksReceived:(NSUInteger)count {
    dispatch_async(self.statsQueue, ^{
        self.blocksThisInterval += count;
        self.totalBlocks += count;
    });
}

- (void)recordTransactionReceived {
    dispatch_async(self.statsQueue, ^{
        self.transactionsThisInterval++;
        self.totalTransactions++;
    });
}

- (void)recordTransactionsReceived:(NSUInteger)count {
    dispatch_async(self.statsQueue, ^{
        self.transactionsThisInterval += count;
        self.totalTransactions += count;
    });
}

- (void)recordPreFilteredTransactionsReceived:(NSUInteger)count {
    dispatch_async(self.statsQueue, ^{
        self.preFilteredTxThisInterval += count;
    });
}

- (void)recordHeaderReceived {
    dispatch_async(self.statsQueue, ^{
        self.headersThisInterval++;
    });
}

- (void)recordHeadersReceived:(NSUInteger)count {
    dispatch_async(self.statsQueue, ^{
        self.headersThisInterval += count;
    });
}

- (void)recordMnListDiffReceived {
    dispatch_async(self.statsQueue, ^{
        self.mnListDiffsThisInterval++;
    });
}

- (void)recordBytesReceived:(NSUInteger)bytes {
    dispatch_async(self.statsQueue, ^{
        self.bytesThisInterval += bytes;
        self.totalBytes += bytes;
    });
}

- (void)updateChainHeight:(uint32_t)chainHeight commonHeight:(uint32_t)commonHeight targetHeight:(uint32_t)targetHeight {
    dispatch_async(self.statsQueue, ^{
        if (chainHeight > self.lastChainHeight) {
            self.lastProgressTime = [[NSDate date] timeIntervalSince1970];
            self.lastChainHeight = chainHeight;
        }
        self.chainHeight = chainHeight;
        self.commonHeight = commonHeight;
        self.targetHeight = targetHeight;
    });
}

- (void)logCurrentStats {
    __block NSUInteger blocks, txs, preFilteredTxs, headers, mnListDiffs, bytes;
    __block uint32_t chainH, commonH, targetH;
    __block NSTimeInterval lastProgress;
    __block double avgKB, totalB;
    __block NSTimeInterval elapsed;

    dispatch_sync(self.statsQueue, ^{
        blocks = self.blocksThisInterval;
        txs = self.transactionsThisInterval;
        preFilteredTxs = self.preFilteredTxThisInterval;
        headers = self.headersThisInterval;
        mnListDiffs = self.mnListDiffsThisInterval;
        bytes = self.bytesThisInterval;
        chainH = self.chainHeight;
        commonH = self.commonHeight;
        targetH = self.targetHeight;
        lastProgress = self.lastProgressTime;
        totalB = (double)self.totalBytes;
        elapsed = [[NSDate date] timeIntervalSince1970] - self.startTime;
    });

    // Calculate KB/sec
    double lastKB = (double)bytes / 1024.0;
    double avgKBPerSec = (elapsed > 0) ? (totalB / 1024.0 / elapsed) : 0;

    // Stall detection
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    BOOL isStalled = (now - lastProgress) > kStallDetectionSeconds;
    NSString *stallStatus = isStalled ? @"STALLED" : @"not stalled";

    // Only log if there's activity or we haven't logged in a while
    if (blocks > 0 || txs > 0 || headers > 0 || mnListDiffs > 0) {
        // Store in history buffer for History Statistics logging
        NSDictionary *historyEntry = @{
            @"tx": @(txs),
            @"blocks": @(blocks),
            @"headers": @(headers),
            @"mnlistdiff": @(mnListDiffs)
        };
        dispatch_async(self.statsQueue, ^{
            if (self.historyBuffer.count >= 10) {
                [self.historyBuffer removeObjectAtIndex:0];
            }
            [self.historyBuffer addObject:historyEntry];
        });

        // Log Android-style output
        DSLogInfo(@"DSChainSyncSpeedCalculator",
                  @"%lu blocks/sec, %lu tx/sec, %lu pre-filtered tx/sec, %lu headers/sec, %lu mnlistdiff/sec, avg/last %.2f/%.2f kilobytes per sec, chain/common height %u/%u, %@",
                  (unsigned long)blocks,
                  (unsigned long)txs,
                  (unsigned long)preFilteredTxs,
                  (unsigned long)headers,
                  (unsigned long)mnListDiffs,
                  avgKBPerSec,
                  lastKB,
                  chainH,
                  commonH,
                  stallStatus);
    }

    // Store for averaging
    dispatch_async(self.statsQueue, ^{
        self.avgKBPerSec = avgKBPerSec;
        self.lastKBPerSec = lastKB;
    });
}

- (void)logHistoryStats {
    __block NSMutableString *historyString = [NSMutableString string];

    dispatch_sync(self.statsQueue, ^{
        for (NSDictionary *entry in self.historyBuffer) {
            if (historyString.length > 0) {
                [historyString appendString:@", "];
            }
            [historyString appendFormat:@"%@/%@/%@/%@",
             entry[@"tx"], entry[@"blocks"], entry[@"headers"], entry[@"mnlistdiff"]];
        }
    });

    if (historyString.length > 0) {
        DSLogInfo(@"DSChainSyncSpeedCalculator", @"History of transactions/blocks/headers/mnlistdiff: %@", historyString);
    }
}

- (void)resetIntervalCounters {
    dispatch_async(self.statsQueue, ^{
        self.blocksThisInterval = 0;
        self.transactionsThisInterval = 0;
        self.preFilteredTxThisInterval = 0;
        self.headersThisInterval = 0;
        self.mnListDiffsThisInterval = 0;
        self.bytesThisInterval = 0;
    });
}

- (void)reset {
    dispatch_sync(self.statsQueue, ^{
        self.blocksThisInterval = 0;
        self.transactionsThisInterval = 0;
        self.preFilteredTxThisInterval = 0;
        self.headersThisInterval = 0;
        self.mnListDiffsThisInterval = 0;
        self.bytesThisInterval = 0;
        self.totalBlocks = 0;
        self.totalTransactions = 0;
        self.totalBytes = 0;
        self.startTime = [[NSDate date] timeIntervalSince1970];
        self.avgKBPerSec = 0;
        self.lastKBPerSec = 0;
        self.chainHeight = 0;
        self.commonHeight = 0;
        self.targetHeight = 0;
        self.lastProgressTime = self.startTime;
        self.lastChainHeight = 0;
        [self.historyBuffer removeAllObjects];
    });
}

@end
