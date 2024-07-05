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

// MARK: - Imports

#import <Foundation/Foundation.h>
#import "BigIntTypes.h"
#import "DSChain.h"
#import "DSCheckpoint.h"

NS_ASSUME_NONNULL_BEGIN

// MARK: - Checkpoints Cache

@interface DSCheckpointsCache : NSObject

// MARK: - Properties

/*! @brief The genesis hash is the hash of the first block of the chain. For a devnet this is actually the second block as the first block is created in a special way for devnets.  */
@property (nonatomic, readonly) UInt256 genesisHash;

/*! @brief Timestamp of the last hardcoded checkpoint for the chain.  */
@property (nonatomic, readonly) NSTimeInterval lastCheckpointTimestamp;

/*! @brief Returns the last checkpoint.  */
@property (nonatomic, readonly, strong) DSCheckpoint *lastCheckpoint;
@property (nonatomic, readonly, strong) DSCheckpoint *terminalHeadersOverrideUseCheckpoint;
@property (nonatomic, readonly, strong) DSCheckpoint *syncHeadersOverrideUseCheckpoint;


/*! @brief An array of known hard coded checkpoints for the chain.  */
@property (nonatomic, readonly) NSArray<DSCheckpoint *> *checkpoints;

// MARK: - Methods
/*! @brief Flag if non-zero genesis is present.  */
- (BOOL)isGenesisExist;

/*! @brief Returns the last available checkpoint or syncHeadersOverrideUseCheckpoint.  */
- (DSCheckpoint *_Nullable)lastCheckpointForTerminalHeaders;

/*! @brief Returns the last checkpoint that has a masternode list attached to it.  */
- (DSCheckpoint *_Nullable)lastCheckpointHavingMasternodeList;

/*! @brief Returns the checkpoint matching the parameter block hash, if one exists.  */
- (DSCheckpoint *_Nullable)checkpointForBlockHash:(UInt256)blockHash;

/*! @brief Returns the checkpoint at a given block height, if one exists at that block height.  */
- (DSCheckpoint *_Nullable)checkpointForBlockHeight:(uint32_t)blockHeight;

- (DSCheckpoint *_Nullable)lastCheckpointOnOrBeforeHeight:(uint32_t)height forChain:(DSChain *)chain;
- (DSCheckpoint *_Nullable)lastCheckpointOnOrBeforeTimestamp:(NSTimeInterval)timestamp forChain:(DSChain *)chain;

/*! @brief Adds checkpoint to in-memory storage.  */
- (void)addCheckpointInDictionary:(DSCheckpoint *)checkpoint;

/*! @brief Returns checkpoint at the block height if persist  */
- (DSCheckpoint *_Nullable)checkpointForHeight:(uint32_t)height;

/*! @brief Returns height of the checkpoint with this block hash  */
- (uint32_t)checkpointHeightForBlockHash:(UInt256)blockhash;


- (instancetype)initWithFirstCheckpoint:(NSArray *)checkpoints;
- (instancetype)initWithDevnet:(DevnetType)devnetType
                   checkpoints:(NSArray<DSCheckpoint *> *)checkpoints
             onProtocolVersion:(uint32_t)protocolVersion
                      forChain:(DSChain *)chain;
- (void)addCheckpoint:(DSCheckpoint *)checkpoint;
- (void)useOverrideForSyncHeaders:(DSCheckpoint *)checkpoint;
- (void)useOverrideForTerminalHeaders:(DSCheckpoint *)checkpoint;

@end

NS_ASSUME_NONNULL_END
