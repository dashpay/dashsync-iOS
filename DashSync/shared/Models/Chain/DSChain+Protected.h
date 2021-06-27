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

#import "DSChain.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSChain ()

@property (nonatomic, readonly, nullable) NSString *registeredPeersKey;

@property (nonatomic, readonly) NSDictionary<NSValue *, DSBlock *> *syncBlocks, *terminalBlocks, *orphans;

@property (nonatomic, strong) NSMutableDictionary<NSData *, DSBlock *> *insightVerifiedBlocksByHashDictionary;

// MARK: - Init And Setup

- (void)setUp;

// MARK: - Network Queues

@property (nonatomic, strong) dispatch_queue_t networkingQueue;
@property (nonatomic, strong) dispatch_queue_t dapiMetadataQueue;


// MARK: - Blocks

- (void)setEstimatedBlockHeight:(uint32_t)estimatedBlockHeight fromPeer:(DSPeer *)peer thresholdPeerCount:(uint32_t)thresholdPeerCount;
- (void)removeEstimatedBlockHeightOfPeer:(DSPeer *)peer;
- (BOOL)addBlock:(DSBlock *)block receivedAsHeader:(BOOL)isHeaderOnly fromPeer:(DSPeer *_Nullable)peer;
- (BOOL)addMinedFullBlock:(DSFullBlock *)block;
- (void)setBlockHeight:(int32_t)height andTimestamp:(NSTimeInterval)timestamp forTransactionHashes:(NSArray *)txHashes;
- (void)clearOrphans;
- (void)addInsightVerifiedBlock:(DSBlock *)block forBlockHash:(UInt256)blockHash;

@property (nonatomic, readonly) BOOL allowInsightBlocksForVerification;

// MARK: - ChainLocks
@property (nonatomic, strong) DSChainLock *lastChainLock;

// MARK: Chain Sync

/*! @brief Returns the hash of the last persisted sync block. The sync block itself most likely is not persisted.  */
@property (nonatomic, assign) UInt256 lastPersistedChainSyncBlockHash;

/*! @brief Returns the chain work of the last persisted sync block. The sync block itself most likely is not persisted.  */
@property (nonatomic, assign) UInt256 lastPersistedChainSyncBlockChainWork;

/*! @brief Returns the height of the last persisted sync block. The sync block itself most likely is not persisted.  */
@property (nonatomic, assign) uint32_t lastPersistedChainSyncBlockHeight;

/*! @brief Returns the timestamp of the last persisted sync block. The sync block itself most likely is not persisted.  */
@property (nonatomic, assign) NSTimeInterval lastPersistedChainSyncBlockTimestamp;

/*! @brief Returns the locators of the last persisted chain sync block. The sync block itself most likely is not persisted.  */
@property (nullable, nonatomic, strong) NSArray *lastPersistedChainSyncLocators;

// MARK: - Wallet, Accounts and Transactions

/*! @brief Add a wallet to the chain. It is only temporarily in the chain if externaly added this way.  */
- (BOOL)addWallet:(DSWallet *)wallet;

- (BOOL)registerSpecialTransaction:(DSTransaction *)transaction saveImmediately:(BOOL)saveImmediately;

- (void)triggerUpdatesForLocalReferences:(DSTransaction *)transaction;

- (void)reloadDerivationPaths;

// MARK: Wallet Discovery

- (DSWallet *_Nullable)walletHavingBlockchainIdentityCreditFundingRegistrationHash:(UInt160)creditFundingRegistrationHash foundAtIndex:(uint32_t *_Nullable)rIndex;

- (DSWallet *_Nullable)walletHavingBlockchainIdentityCreditFundingTopupHash:(UInt160)creditFundingTopupHash foundAtIndex:(uint32_t *)rIndex;

- (DSWallet *_Nullable)walletHavingBlockchainIdentityCreditFundingInvitationHash:(UInt160)creditFundingInvitationHash foundAtIndex:(uint32_t *)rIndex;

- (DSWallet *_Nullable)walletHavingProviderVotingAuthenticationHash:(UInt160)votingAuthenticationHash foundAtIndex:(uint32_t *_Nullable)rIndex;

- (DSWallet *_Nullable)walletHavingProviderOwnerAuthenticationHash:(UInt160)owningAuthenticationHash foundAtIndex:(uint32_t *_Nullable)rIndex;

- (DSWallet *_Nullable)walletHavingProviderOperatorAuthenticationKey:(UInt384)providerOperatorAuthenticationKey foundAtIndex:(uint32_t *_Nullable)rIndex;

- (DSWallet *_Nullable)walletContainingMasternodeHoldingAddressForProviderRegistrationTransaction:(DSProviderRegistrationTransaction *_Nonnull)transaction foundAtIndex:(uint32_t *_Nullable)rIndex;

// MARK: - Standalone Derivation Paths

/*! @brief Add a standalone derivation path to the chain. It is only temporarily in the chain if externaly added this way.  */
- (void)addStandaloneDerivationPath:(DSDerivationPath *)derivationPath;

// MARK: - Masternodes

@property (nonatomic, assign) UInt256 masternodeBaseBlockHash;

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
