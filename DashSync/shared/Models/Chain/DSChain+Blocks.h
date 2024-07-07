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
#import "DSChainLock.h"
#import "DSMerkleBlock.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSChain (Blocks)

/*! @brief Returns the estimated height of chain. This is reported by the current download peer but can not be verified and is not secure.  */
@property (nonatomic, readonly) uint32_t estimatedBlockHeight;

/*! @brief Locks before receive block from insight API.  */
- (void)blockUntilGetInsightForBlockHash:(UInt256)blockHash;

/*! @brief The timestamp of a block at a given height.  */
- (NSTimeInterval)timestampForBlockHeight:(uint32_t)blockHeight; // seconds since 1970, 00:00:00 01/01/01 GMT

/*! @brief The block on the main chain at a certain height. By main chain it is understood to mean not forked chain - this could be on mainnet, testnet or a devnet.  */
- (DSMerkleBlock *_Nullable)blockAtHeight:(uint32_t)height;

/*! @brief The block on the main chain at a certain height. If none exist return most recent.  */
- (DSMerkleBlock *_Nullable)blockAtHeightOrLastTerminal:(uint32_t)height;

/*! @brief Returns a known block with the given block hash. This does not have to be in the main chain. A null result could mean that the block was old and has since been discarded.  */
- (DSMerkleBlock *_Nullable)blockForBlockHash:(UInt256)blockHash;

/*! @brief Returns a known block in the main chain with the given block hash. A null result could mean that the block was old and has since been discarded.  */
- (DSMerkleBlock *_Nullable)recentTerminalBlockForBlockHash:(UInt256)blockHash;

/*! @brief Returns a known block with a given distance from the chain tip. A null result would mean that the given distance exceeded the number of blocks kept locally.  */
- (DSMerkleBlock *_Nullable)blockFromChainTip:(NSUInteger)blocksAgo;


/*! @brief Returns the height of a block having the given hash. If no block is found returns UINT32_MAX  */
- (uint32_t)heightForBlockHash:(UInt256)blockhash;

/*! @brief Returns the height of a block having the given hash. This does less expensive checks than heightForBlockHash and is not garanteed to be accurate, but can be used for logging. If no block is found returns UINT32_MAX  */
- (uint32_t)quickHeightForBlockHash:(UInt256)blockhash;

/*! @brief This block locator array is an array of 10 block hashes in decending order before the given timestamp followed by block hashes that double the step back each iteration in decending order and finishing with the previous known checkpoint after that last hash. Something like (top, -1, -2, -3, -4, -5, -6, -7, -8, -9, -11, -15, -23, -39, -71, -135, ..., 0).  */
- (NSArray<NSData *> *)blockLocatorArrayOnOrBeforeTimestamp:(NSTimeInterval)timestamp includeInitialTerminalBlocks:(BOOL)includeHeaders;

// MARK: - ChainLocks

/*! @brief Adds a chainLock to the chain and applies it corresponding block. It will be applied to both terminal blocks and sync blocks.  */
- (BOOL)addChainLock:(DSChainLock *)chainLock;

/*! @brief Returns if there is a block at the following height that is confirmed.  */
- (BOOL)blockHeightChainLocked:(uint32_t)height;

- (BOOL)addBlock:(DSBlock *)block receivedAsHeader:(BOOL)isHeaderOnly fromPeer:(DSPeer *_Nullable)peer;

- (void)removeEstimatedBlockHeightOfPeer:(DSPeer *)peer;
- (BOOL)addMinedFullBlock:(DSFullBlock *)block;

@end

NS_ASSUME_NONNULL_END
