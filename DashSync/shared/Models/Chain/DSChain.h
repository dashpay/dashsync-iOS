//
//  DSChain.h
//  DashSync
//
//  Created by Quantum Explorer on 05/05/18.
//  Copyright (c) 2018 Quantum Explorer <quantum@dash.org>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "BigIntTypes.h"
#import "dash_spv_apple_bindings.h"
#import "DSChainConstants.h"
#import "DSDashSharedCore.h"
#import "DSTransaction.h"
#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const DSChainWalletsDidChangeNotification;
FOUNDATION_EXPORT NSString *const DSChainStandaloneDerivationPathsDidChangeNotification;
FOUNDATION_EXPORT NSString *const DSChainStandaloneAddressesDidChangeNotification;
FOUNDATION_EXPORT NSString *const DSChainBlockWasLockedNotification;
FOUNDATION_EXPORT NSString *const DSChainNotificationBlockKey;

// For improved performance DSChainInitialHeadersDidChangeNotification is not garanteed to trigger on every initial headers change.
FOUNDATION_EXPORT NSString *const DSChainInitialHeadersDidFinishSyncingNotification;
FOUNDATION_EXPORT NSString *const DSChainBlocksDidFinishSyncingNotification;

//typedef NS_ENUM(NSUInteger, DSTransactionDirection)
//{
//    DSTransactionDirection_Sent,
//    DSTransactionDirection_Received,
//    DSTransactionDirection_Moved,
//    DSTransactionDirection_NotAccountFunds,
//};

typedef NS_ENUM(uint16_t, DSChainSyncPhase)
{
    DSChainSyncPhase_Offline = 0,
    DSChainSyncPhase_InitialTerminalBlocks,
    DSChainSyncPhase_ChainSync,
    DSChainSyncPhase_Synced,
};

@class DSChain, DSChainEntity, DSChainManager, DSWallet, DSMerkleBlock, DSBlock, DSFullBlock, DSPeer, DSDerivationPath, DSTransaction, DSAccount, DSIdentity, DSBloomFilter, DSProviderRegistrationTransaction, DPContract, DSCheckpoint, DSChainLock, DSDashSharedCore, DSMasternodeManager;

@protocol DSChainDelegate;

@interface DSChain : NSObject

// MARK: - Shortcuts

/*! @brief The chain manager is a container for all managers (peer, identity, governance, masternode, spork and transition). It also is used to control the sync process.  */
@property (nonatomic, weak, nullable) DSChainManager *chainManager;
@property (nonatomic, weak, nullable) DSMasternodeManager *masternodeManager;
// MARK: - Shortcuts

/*! @brief The shared core is a container for all stuff related to rust dash-shared-core.  */
@property (nonatomic, nullable) DSDashSharedCore *shareCore;

/*! @brief Tokio Runtime Reference  */
@property (nonatomic, nullable) Runtime *sharedRuntime;

/*! @brief Masternode Processor Reference  */
@property (nonatomic, nullable) DArcProcessor *sharedProcessor;
@property (nonatomic, nullable) DProcessor *sharedProcessorObj;
/*! @brief Masternode Processor Cache Reference  */
//@property (nonatomic, nullable) DArcCache *sharedCache;
//@property (nonatomic, nullable) DCache *sharedCacheObj;
@property (nonatomic, nullable) DArcPlatformSDK *sharedPlatform;
@property (nonatomic, nullable) PlatformSDK *sharedPlatformObj;
@property (nonatomic, nullable) ContactRequestManager *sharedContactsObj;
@property (nonatomic, nullable) IdentitiesManager *sharedIdentitiesObj;
@property (nonatomic, nullable) DocumentsManager *sharedDocumentsObj;
@property (nonatomic, nullable) ContractsManager *sharedContractsObj;
@property (nonatomic, nullable) SaltedDomainHashesManager *sharedSaltedDomainHashesObj;


/*! @brief The chain entity associated in Core Data in the required context.  */
- (DSChainEntity *)chainEntityInContext:(NSManagedObjectContext *)context;

/*! @brief The managed object context of the chain.  */
@property (nonatomic, readonly) NSManagedObjectContext *chainManagedObjectContext;

// MARK: - L1 Network Chain Info

///*! @brief An array of known hard coded checkpoints for the chain.  */
//@property (nonatomic, readonly) NSArray<DSCheckpoint *> *checkpoints;




// MARK: - DashSync Chain Info


/*! @brief True if this chain syncs the blockchain. All Chains currently sync the blockchain.  */
@property (nonatomic, readonly) BOOL syncsBlockchain;

/*! @brief True if this chain should sync headers first for masternode list verification.  */
@property (nonatomic, readonly) BOOL needsInitialTerminalHeadersSync;


/*! @brief Returns all standard derivaton paths used for the chain based on the account number.  */
- (NSArray<DSDerivationPath *> *)standardDerivationPathsForAccountNumber:(uint32_t)accountNumber;


// MARK: - Standalone Derivation Paths

/*! @brief Standalone derivation paths used in this chain. This is currently an experimental feature  */
@property (nonatomic, readonly) NSArray<DSDerivationPath *> *standaloneDerivationPaths;

/*! @brief Conveniance method to find out if the chain has a standalone derivation path. Standalone derivation paths are currently an experimental feature  */
@property (nonatomic, readonly) BOOL hasAStandaloneDerivationPath;

/*! @brief Unregister a standalone derivation path from the chain, it will no longer be loaded or used. Standalone derivation paths are currently an experimental feature  */
- (void)unregisterStandaloneDerivationPath:(DSDerivationPath *)derivationPath;

/*! @brief Register a standalone derivation path to the chain. Standalone derivation paths are currently an experimental feature  */
- (void)registerStandaloneDerivationPath:(DSDerivationPath *)derivationPath;


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

/*! @brief A short hex string of the last block's block hash.  */
@property (nonatomic, readonly, nullable) NSString *chainTip;

/*! @brief The block locator array is an array of the 10 most recent block hashes in decending order followed by block hashes that double the step back each iteration in decending order and finishing with the previous known checkpoint after that last hash. Something like (top, -1, -2, -3, -4, -5, -6, -7, -8, -9, -11, -15, -23, -39, -71, -135, ..., 0).  */
@property (nonatomic, readonly, nullable) NSArray<NSData *> *chainSyncBlockLocatorArray;

/*! @brief This block locator array is an array of 10 block hashes in decending order before the given timestamp followed by block hashes that double the step back each iteration in decending order and finishing with the previous known checkpoint after that last hash. Something like (top, -1, -2, -3, -4, -5, -6, -7, -8, -9, -11, -15, -23, -39, -71, -135, ..., 0).  */
- (NSArray<NSData *> *)blockLocatorArrayOnOrBeforeTimestamp:(NSTimeInterval)timestamp includeInitialTerminalBlocks:(BOOL)includeHeaders;

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

- (uint32_t)chainTipHeight;

// MARK: Chain Sync

/*! @brief Returns the hash of the last persisted sync block. The sync block itself most likely is not persisted.  */
@property (nonatomic, readonly) UInt256 lastPersistedChainSyncBlockHash;

/*! @brief Returns the height of the last persisted sync block. The sync block itself most likely is not persisted.  */
@property (nonatomic, readonly) uint32_t lastPersistedChainSyncBlockHeight;

/*! @brief Returns the timestamp of the last persisted sync block. The sync block itself most likely is not persisted.  */
@property (nonatomic, readonly) NSTimeInterval lastPersistedChainSyncBlockTimestamp;

/*! @brief Returns the locators of the last persisted chain sync block. The sync block itself most likely is not persisted.  */
@property (nullable, nonatomic, readonly) NSArray *lastPersistedChainSyncLocators;

// MARK: Last Block Information

/*! @brief Returns the height of the last sync block.  */
@property (nonatomic, readonly) uint32_t lastSyncBlockHeight;

/*! @brief Returns the hash of the last sync block.  */
@property (nonatomic, readonly) UInt256 lastSyncBlockHash;

/*! @brief Returns the timestamp of the last sync block.  */
@property (nonatomic, readonly) NSTimeInterval lastSyncBlockTimestamp;

/*! @brief Returns the height of the last header used in initial headers sync to get the deterministic masternode list.  */
@property (nonatomic, readonly) uint32_t lastTerminalBlockHeight;

/*! @brief Returns the height of the best block.  */
@property (nonatomic, readonly) uint32_t bestBlockHeight;

/*! @brief Returns the estimated height of chain. This is reported by the current download peer but can not be verified and is not secure.  */
@property (nonatomic, readonly) uint32_t estimatedBlockHeight;

/*! @brief Returns the height of a block having the given hash. If no block is found returns UINT32_MAX  */
- (uint32_t)heightForBlockHash:(UInt256)blockhash;

/*! @brief Returns the height of a block having the given hash. This does less expensive checks than heightForBlockHash and is not garanteed to be accurate, but can be used for logging. If no block is found returns UINT32_MAX  */
- (uint32_t)quickHeightForBlockHash:(UInt256)blockhash;

// MARK: Chain Lock

/*! @brief Returns the last chainLock known by the chain at the heighest height.  */
@property (nonatomic, readonly) DSChainLock *lastChainLock;

/*! @brief Adds a chainLock to the chain and applies it corresponding block. It will be applied to both terminal blocks and sync blocks.  */
- (BOOL)addChainLock:(DSChainLock *)chainLock;

/*! @brief Returns if there is a block at the following height that is confirmed.  */
- (BOOL)blockHeightChainLocked:(uint32_t)height;


// MARK: - Bloom Filter

/*! @brief Returns if a filter can be created for the chain. Generally this means that the chain has at least a wallet or a standalone derivation path. */
@property (nonatomic, readonly) BOOL canConstructAFilter;

/*! @brief Returns a bloom filter with the given false positive rate tweaked with the value tweak. The value tweak is generally peer specific. */
- (DSBloomFilter *)bloomFilterWithFalsePositiveRate:(double)falsePositiveRate withTweak:(uint32_t)tweak;

/*! @brief Returns possibly new addresses for bloom filter, checks that at least the next <gap limit>. */
- (NSArray<NSString *> *)newAddressesForBloomFilter;


// MARK: - Governance

/*! @brief Returns a count of all governance objects.  */
@property (nonatomic, assign) uint32_t totalGovernanceObjectsCount;


// MARK: - Chain Retrieval methods

/*! @brief Mainnet chain.  */
+ (DSChain *)mainnet;

/*! @brief Testnet chain.  */
+ (DSChain *)testnet;

/*! @brief Devnet chain with given identifier.  */
+ (DSChain *_Nullable)devnetWithIdentifier:(NSString *)identifier;

/*! @brief Set up a given devnet with an identifier, checkpoints, default L1, JRPC and GRPC ports, a dpns contractId and a dashpay contract id. minimumDifficultyBlocks are used to speed up the initial chain creation. This devnet will be registered on the keychain. The additional isTransient property allows for test usage where you do not wish to persist the devnet.  */
+ (DSChain *)setUpDevnetWithIdentifier:(dash_spv_crypto_network_chain_type_DevnetType *)devnetType
                       protocolVersion:(uint32_t)protocolVersion
                    minProtocolVersion:(uint32_t)minProtocolVersion
                       withCheckpoints:(NSArray<DSCheckpoint *> *_Nullable)checkpointArray
           withMinimumDifficultyBlocks:(uint32_t)minimumDifficultyBlocks
                       withDefaultPort:(uint32_t)port
               withDefaultDapiJRPCPort:(uint32_t)dapiJRPCPort
               withDefaultDapiGRPCPort:(uint32_t)dapiGRPCPort
                        dpnsContractID:(UInt256)dpnsContractID
                     dashpayContractID:(UInt256)dashpayContractID
                          isTransient:(BOOL)isTransient;

/*! @brief Retrieve from the keychain a devnet with an identifier and add given checkpoints.  */
+ (DSChain *)recoverKnownDevnetWithIdentifier:(dash_spv_crypto_network_chain_type_DevnetType *)devnetType withCheckpoints:(NSArray<DSCheckpoint *> *)checkpointArray performSetup:(BOOL)performSetup;

/*! @brief Retrieve a chain having the specified network name.  */
+ (DSChain *_Nullable)chainForNetworkName:(NSString *_Nullable)networkName;


@end

@protocol DSChainTransactionsDelegate
@required

- (void)chain:(DSChain *)chain didSetBlockHeight:(int32_t)height andTimestamp:(NSTimeInterval)timestamp forTransactionHashes:(NSArray<NSValue *> *)txHashes updatedTransactions:(NSArray *)updatedTransactions;
- (void)chainWasWiped:(DSChain *)chain;

@end

@protocol DSChainIdentitiesDelegate
@required
- (void)chain:(DSChain *)chain didFinishInChainSyncPhaseFetchingIdentityDAPInformation:(DSIdentity *)identity;

@end

@protocol DSChainDelegate <DSChainTransactionsDelegate, DSChainIdentitiesDelegate>

@required

- (void)chainWillStartConnectingToPeers:(DSChain *)chain;
- (void)chainWillStartSyncingBlockchain:(DSChain *)chain;
- (void)chainShouldStartSyncingBlockchain:(DSChain *)chain onPeer:(DSPeer *)peer;
- (void)chainFinishedSyncingTransactionsAndBlocks:(DSChain *)chain fromPeer:(DSPeer *_Nullable)peer onMainChain:(BOOL)onMainChain;
- (void)chainFinishedSyncingInitialHeaders:(DSChain *)chain fromPeer:(DSPeer *_Nullable)peer onMainChain:(BOOL)onMainChain;
- (void)chainFinishedSyncingMasternodeListsAndQuorums:(DSChain *)chain;
- (void)chain:(DSChain *)chain receivedOrphanBlock:(DSBlock *)merkleBlock fromPeer:(DSPeer *)peer;
- (void)chain:(DSChain *)chain wasExtendedWithBlock:(DSBlock *)merkleBlock fromPeer:(DSPeer *)peer;
- (void)chain:(DSChain *)chain badBlockReceivedFromPeer:(DSPeer *)peer;
- (void)chain:(DSChain *)chain badMasternodeListReceivedFromPeer:(DSPeer *)peer;

@end

NS_ASSUME_NONNULL_END
