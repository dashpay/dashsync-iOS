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
#import "DSChain.h"
#import "DSCheckpoint.h"
#import "DSCheckpointsCache.h"
#import "DSMerkleBlock.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSBlocksCache : NSObject

/*! @brief In-memory storage for checkpoints.  */
@property (nonatomic, strong, readonly) DSCheckpointsCache *checkpointsCache;

// MARK: - Blocks and Headers

/*! @brief The last known chain sync block on the chain.  */
@property (nonatomic, readonly, nullable) DSBlock *lastSyncBlock;
/*! @brief The last known chain sync block on the chain, don't recover from checkpoints if it is not known.  */
@property (nonatomic, readonly, nullable) DSBlock *lastSyncBlockDontUseCheckpoints;
/*! @brief The last known terminal block on the chain.  */
@property (nonatomic, readonly, nullable) DSBlock *lastTerminalBlock;
/*! @brief The last known block on the chain before the given timestamp.  */
- (DSBlock *)lastChainSyncBlockOnOrBeforeTimestamp:(NSTimeInterval)timestamp;
/*! @brief The last known block or header on the chain before the given timestamp.  */
- (DSBlock *)lastBlockOnOrBeforeTimestamp:(NSTimeInterval)timestamp;

/*! @brief The last known orphan on the chain. An orphan is a block who's parent is currently not known.  */
@property (nonatomic, readonly, nullable) DSBlock *lastOrphan;

/*! @brief A dictionary of the the most recent known blocks keyed by block hash.  */
@property (nonatomic, readonly) NSDictionary<NSValue *, DSMerkleBlock *> *recentBlocks;

/*! @brief In-memory storage for terminal blocks.  */
@property (nonatomic, strong, readonly) NSDictionary<NSValue *, DSBlock *> *terminalBlocks;

/*! @brief The genesis hash is the hash of the first block of the chain. For a devnet this is actually the second block as the first block is created in a special way for devnets.  */
@property (nonatomic, readonly) UInt256 genesisHash;

/*! @brief Orphan blocks.  */
@property (nonatomic, strong, readonly) NSDictionary<NSValue *, DSBlock *> *orphans;

/*! @brief Returns the hash of the last persisted sync block. The sync block itself most likely is not persisted.  */
@property (nonatomic, readonly) UInt256 lastPersistedChainSyncBlockHash;
/*! @brief Returns the height of the last persisted sync block. The sync block itself most likely is not persisted.  */
@property (nonatomic, readonly) uint32_t lastPersistedChainSyncBlockHeight;
/*! @brief Returns the timestamp of the last persisted sync block. The sync block itself most likely is not persisted.  */
@property (nonatomic, readonly) NSTimeInterval lastPersistedChainSyncBlockTimestamp;
/*! @brief Returns the locators of the last persisted chain sync block. The sync block itself most likely is not persisted.  */
@property (nullable, nonatomic, strong) NSArray *lastPersistedChainSyncLocators;

/*! @brief Returns the chain work of the last persisted sync block. The sync block itself most likely is not persisted.  */
@property (nonatomic, readonly) UInt256 lastPersistedChainSyncBlockChainWork;

/*! @brief The block on the main chain at a certain height. By main chain it is understood to mean not forked chain - this could be on mainnet, testnet or a devnet.  */
- (DSBlock *)blockAtHeight:(uint32_t)height;
/*! @brief The block on the main chain at a certain height. If none exist return most recent.  */
- (DSBlock *)blockAtHeightOrLastTerminal:(uint32_t)height;
/*! @brief Returns a known block with the given block hash. This does not have to be in the main chain. A null result could mean that the block was old and has since been discarded.  */
- (DSMerkleBlock *_Nullable)blockForBlockHash:(UInt256)blockHash;
/*! @brief The timestamp of a block at a given height.  */
- (NSTimeInterval)timestampForBlockHeight:(uint32_t)blockHeight; // seconds since 1970, 00:00:00 01/01/01 GMT
- (DSBlock *)blockFromChainTip:(NSUInteger)blocksAgo;

/*! @brief Returns the height of a block having the given hash. If no block is found returns UINT32_MAX  */
- (uint32_t)heightForBlockHash:(UInt256)blockhash;
/*! @brief Returns the height of a block having the given hash. This does less expensive checks than heightForBlockHash and is not garanteed to be accurate, but can be used for logging. If no block is found returns UINT32_MAX  */
- (uint32_t)quickHeightForBlockHash:(UInt256)blockhash;


// MARK: - Estimation

/*! @brief Returns the estimated height of chain. This is reported by the current download peer but can not be verified and is not secure.  */
@property (nonatomic, readonly) uint32_t estimatedBlockHeight;

/*! @brief Adds a chainLock to the chain and applies it corresponding block. It will be applied to both terminal blocks and sync blocks.  */
- (BOOL)addChainLock:(DSChainLock *)chainLock;

// MARK: - Constructor

/*! @brief Constructor for Mainnet/Testnet.  */
- (instancetype)initWithFirstCheckpoint:(NSArray<DSCheckpoint *> *)checkpoints
                                onChain:(DSChain *)chain;
/*! @brief Constructor for Devnet.  */
- (instancetype)initWithDevnet:(DevnetType)devnetType
                   checkpoints:(NSArray<DSCheckpoint *> *)checkpoints
             onProtocolVersion:(uint32_t)protocolVersion
                      forChain:(DSChain *)chain;
/*! @brief Flag if non-zero genesis is present.  */


- (BOOL)isGenesisExist;
- (void)resetLastSyncBlock;
- (void)setSyncBlockFromCheckpoint:(DSCheckpoint *)checkpoint forChain:(DSChain *)chain;
- (DSBlock *)lastSyncBlockWithUseCheckpoints:(BOOL)useCheckpoints forChain:(DSChain *)chain;

- (void)setLastPersistedSyncBlockHeight:(uint32_t)height
                              blockHash:(UInt256)blockHash
                              timestamp:(NSTimeInterval)timestamp
                              chainWork:(UInt256)chainWork
                               locators:(NSArray *)locators;

- (void)wipeBlockchainInfo;
- (void)wipeBlockchainNonTerminalInfo;

@end

NS_ASSUME_NONNULL_END
