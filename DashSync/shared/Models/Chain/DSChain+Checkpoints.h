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

#import "BigIntTypes.h"
#import "DSChain.h"
#import "DSCheckpoint.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSChain (Checkpoints)

@property (nonatomic, readonly) uint32_t lastCheckpointHeight;

// MARK: - Checkpoints
- (BOOL)blockHeightHasCheckpoint:(uint32_t)blockHeight;

/*! @brief Returns the last checkpoint that has a masternode list attached to it.  */
- (DSCheckpoint *_Nullable)lastCheckpointHavingMasternodeList;

/*! @brief Returns the checkpoint matching the parameter block hash, if one exists.  */
- (DSCheckpoint *_Nullable)checkpointForBlockHash:(UInt256)blockHash;

/*! @brief Returns the checkpoint at a given block height, if one exists at that block height.  */
- (DSCheckpoint *_Nullable)checkpointForBlockHeight:(uint32_t)blockHeight;

/*! @brief Returns the last checkpoint on or before the given height.  */
- (DSCheckpoint *)lastCheckpointOnOrBeforeHeight:(uint32_t)height;

/*! @brief Returns the last checkpoint on or before the given timestamp.  */
- (DSCheckpoint *)lastCheckpointOnOrBeforeTimestamp:(NSTimeInterval)timestamp;

/*! @brief When used this will change the checkpoint used for initial headers sync. This value is not persisted.  */
- (void)useCheckpointBeforeOrOnHeightForTerminalBlocksSync:(uint32_t)blockHeight;

/*! @brief When used this will change the checkpoint used for main chain syncing. This value is not persisted.  */
- (void)useCheckpointBeforeOrOnHeightForSyncingChainBlocks:(uint32_t)blockHeight;

@end

NS_ASSUME_NONNULL_END
