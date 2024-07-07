//  
//  Created by Vladimir Pirogov
//  Copyright © 2024 Dash Core Group. All rights reserved.
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

#import <Foundation/Foundation.h>
#import "DSBlock.h"
#import "DSBlocksCache.h"
#import "DSPeer.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(uint16_t, DSBlockEstimationResult) {
    DSBlockEstimationResult_BelowThreshold = 0,
    DSBlockEstimationResult_None = 1,
    DSBlockEstimationResult_NewBest = 2,
};

@interface DSBlocksCache ()

// MARK: - Insight verification
- (void)addInsightVerifiedBlock:(DSBlock *)block forBlockHash:(UInt256)blockHash;
- (DSBlock *_Nullable)insightVerifiedBlockWithHash:(UInt256)blockHash;
- (void)blockUntilGetInsightForBlockHash:(UInt256)blockHash;

- (DSBlock *)recentTerminalBlockForBlockHash:(UInt256)blockHash;
- (BOOL)blockHeightChainLocked:(uint32_t)height;


// MARK: - Persistence

/*! @brief Returns the hash of the last persisted sync block. The sync block itself most likely is not persisted.  */
@property (nonatomic, readwrite) UInt256 lastPersistedChainSyncBlockHash;
/*! @brief Returns the height of the last persisted sync block. The sync block itself most likely is not persisted.  */
@property (nonatomic, readwrite) uint32_t lastPersistedChainSyncBlockHeight;
/*! @brief Returns the timestamp of the last persisted sync block. The sync block itself most likely is not persisted.  */
@property (nonatomic, readwrite) NSTimeInterval lastPersistedChainSyncBlockTimestamp;

- (NSArray<NSData *> *)blockLocatorArrayOnOrBeforeTimestamp:(NSTimeInterval)timestamp
                               includeInitialTerminalBlocks:(BOOL)includeHeaders;
- (NSArray<NSData *> *)chainSyncBlockLocatorArray;

- (DSBlockEstimationResult)setEstimatedBlockHeight:(uint32_t)estimatedBlockHeight 
                                          fromPeer:(DSPeer *)peer
                                thresholdPeerCount:(uint32_t)thresholdPeerCount;
- (NSArray *)cacheBlockLocators;



- (BOOL)addBlock:(DSBlock *)block receivedAsHeader:(BOOL)isHeaderOnly fromPeer:(DSPeer *_Nullable)peer;
- (void)removeEstimatedBlockHeightOfPeer:(DSPeer *)peer;
- (void)clearOrphans;
- (BOOL)addMinedFullBlock:(DSFullBlock *)block;


@end


NS_ASSUME_NONNULL_END
