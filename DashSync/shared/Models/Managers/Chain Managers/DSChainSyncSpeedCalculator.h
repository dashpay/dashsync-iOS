//
//  DSChainSyncSpeedCalculator.h
//  DashSync
//
//  Created for improved logging to match Android/DashJ behavior.
//  Copyright (c) 2024 Dash Core Group. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * DSChainSyncSpeedCalculator tracks blockchain sync speed and statistics.
 *
 * This class provides periodic logging of sync progress similar to Android/DashJ:
 * - Blocks/sec, tx/sec, pre-filtered tx/sec, headers/sec, mnlistdiff/sec
 * - Average and last KB/sec throughput
 * - Chain height vs target height
 * - Stall detection status
 */
@interface DSChainSyncSpeedCalculator : NSObject

/// Singleton instance for the main chain
+ (instancetype)sharedInstance;

/// Start calculating sync speed (call when sync begins)
- (void)startCalculating;

/// Stop calculating sync speed (call when sync ends)
- (void)stopCalculating;

/// Record a block being received
- (void)recordBlockReceived;

/// Record blocks being received (batch)
- (void)recordBlocksReceived:(NSUInteger)count;

/// Record a transaction being received
- (void)recordTransactionReceived;

/// Record transactions being received (batch)
- (void)recordTransactionsReceived:(NSUInteger)count;

/// Record pre-filtered transactions (before bloom filter)
- (void)recordPreFilteredTransactionsReceived:(NSUInteger)count;

/// Record a header being received
- (void)recordHeaderReceived;

/// Record headers being received (batch)
- (void)recordHeadersReceived:(NSUInteger)count;

/// Record a masternode list diff being received
- (void)recordMnListDiffReceived;

/// Record bytes received
- (void)recordBytesReceived:(NSUInteger)bytes;

/// Update chain heights for stall detection
- (void)updateChainHeight:(uint32_t)chainHeight commonHeight:(uint32_t)commonHeight targetHeight:(uint32_t)targetHeight;

/// Force a log output immediately
- (void)logCurrentStats;

/// Reset all counters
- (void)reset;

@end

NS_ASSUME_NONNULL_END
