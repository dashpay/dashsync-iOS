//
//  Created by Sam Westrich
//  Copyright © 2020 Dash Core Group. All rights reserved.
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

#import "DSBlocksCache.h"
#import "DSChain.h"
#import "DSChainParams.h"
#import "DSCheckpointsCache.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSChain ()

@property (nonatomic, readwrite) DSBlocksCache *blocksCache;
@property (nonatomic, readwrite) DSChainParams *params;

@property (nonatomic, readonly, nullable) NSString *registeredPeersKey;

//@property (nonatomic, readonly) NSDictionary<NSValue *, DSBlock *> *syncBlocks, *terminalBlocks, *orphans;

//@property (nonatomic, strong) NSMutableDictionary<NSData *, DSBlock *> *insightVerifiedBlocksByHashDictionary;

// MARK: - Init And Setup

- (void)setUp;

// MARK: - Network Queues

@property (nonatomic, strong) dispatch_queue_t networkingQueue;
@property (nonatomic, strong) dispatch_queue_t dapiMetadataQueue;


// MARK: - Blocks

- (void)setEstimatedBlockHeight:(uint32_t)estimatedBlockHeight 
                       fromPeer:(DSPeer *)peer
             thresholdPeerCount:(uint32_t)thresholdPeerCount;
- (void)setBlockHeight:(int32_t)height andTimestamp:(NSTimeInterval)timestamp forTransactionHashes:(NSArray *)txHashes;

// MARK: - ChainLocks
@property (nonatomic, strong) DSChainLock *lastChainLock;

// MARK: - Wallet, Accounts and Transactions

/*! @brief Add a wallet to the chain. It is only temporarily in the chain if externaly added this way.  */
- (BOOL)addWallet:(DSWallet *)wallet;

- (BOOL)registerSpecialTransaction:(DSTransaction *)transaction saveImmediately:(BOOL)saveImmediately;

- (void)triggerUpdatesForLocalReferences:(DSTransaction *)transaction;

- (void)reloadDerivationPaths;

- (void)markTransactionsUnconfirmedAboveBlockHeight:(uint32_t)blockHeight;

// MARK: - Standalone Derivation Paths

/*! @brief Add a standalone derivation path to the chain. It is only temporarily in the chain if externaly added this way.  */
- (void)addStandaloneDerivationPath:(DSDerivationPath *)derivationPath;

// MARK: - Masternodes

@property (nonatomic, assign) UInt256 masternodeBaseBlockHash;

- (void)loadFileDistributedMasternodeLists;
- (BOOL)hasMasternodeListCurrentlyBeingSaved;
- (void)updateAddressUsageOfSimplifiedMasternodeEntries:(NSArray *)simplifiedMasternodeEntries;

/*! @brief The header locator array is an array of the 10 most recent block hashes in decending order followed by block hashes that double the step back each iteration in decending order and finishing with the previous known checkpoint after that last hash. Something like (top, -1, -2, -3, -4, -5, -6, -7, -8, -9, -11, -15, -23, -39, -71, -135, ..., 0).  */
@property (nonatomic, readonly, nullable) NSArray *terminalBlocksLocatorArray;

// MARK: - Wiping

- (void)wipeWalletsAndDerivatives;

- (void)wipeMasternodesInContext:(NSManagedObjectContext *)context;

/*! @brief This removes all blockchain information from the chain's wallets and derivation paths. */
- (void)wipeBlockchainInfoInContext:(NSManagedObjectContext *)context;

- (void)wipeBlockchainNonTerminalInfoInContext:(NSManagedObjectContext *)context;

// MARK: - Persistence

/*! @brief Save chain info, this rarely needs to be called.  */
- (void)save;

- (void)saveInContext:(NSManagedObjectContext *)context;

- (void)saveBlockLocators;
- (void)saveTerminalBlocks;

@end

NS_ASSUME_NONNULL_END
