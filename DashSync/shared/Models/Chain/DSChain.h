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
#import "dash_shared_core.h"
#import "DSChainConstants.h"
#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const DSChainWalletsDidChangeNotification;
FOUNDATION_EXPORT NSString *const DSChainStandaloneDerivationPathsDidChangeNotification;
FOUNDATION_EXPORT NSString *const DSChainStandaloneAddressesDidChangeNotification;
FOUNDATION_EXPORT NSString *const DSChainChainSyncBlocksDidChangeNotification;
FOUNDATION_EXPORT NSString *const DSChainBlockWasLockedNotification;
FOUNDATION_EXPORT NSString *const DSChainNotificationBlockKey;

// For improved performance DSChainInitialHeadersDidChangeNotification is not garanteed to trigger on every initial headers change.
FOUNDATION_EXPORT NSString *const DSChainTerminalBlocksDidChangeNotification;
FOUNDATION_EXPORT NSString *const DSChainInitialHeadersDidFinishSyncingNotification;
FOUNDATION_EXPORT NSString *const DSChainBlocksDidFinishSyncingNotification;
FOUNDATION_EXPORT NSString *const DSChainNewChainTipBlockNotification;

typedef NS_ENUM(NSUInteger, DSTransactionDirection)
{
    DSTransactionDirection_Sent,
    DSTransactionDirection_Received,
    DSTransactionDirection_Moved,
    DSTransactionDirection_NotAccountFunds,
};

typedef NS_ENUM(uint16_t, DSChainSyncPhase)
{
    DSChainSyncPhase_Offline = 0,
    DSChainSyncPhase_InitialTerminalBlocks,
    DSChainSyncPhase_ChainSync,
    DSChainSyncPhase_Synced,
};

@class DSChain, DSChainEntity, DSChainManager, DSWallet, DSMerkleBlock, DSBlock, DSFullBlock, DSPeer, DSDerivationPath, DSTransaction, DSAccount, DSSimplifiedMasternodeEntry, DSBlockchainIdentity, DSBloomFilter, DSProviderRegistrationTransaction, DSMasternodeList, DPContract, DSCheckpoint, DSChainLock;

@protocol DSChainDelegate;

@interface DSChain : NSObject

//@property (nonatomic, readonly) DSBlocksCache *blocksCache;
//@property (nonatomic, readwrite) DSChainParams *params;

// MARK: - Shortcuts

/*! @brief The chain manager is a container for all managers (peer, identity, governance, masternode, spork and transition). It also is used to control the sync process.  */
@property (nonatomic, weak, nullable) DSChainManager *chainManager;

/*! @brief The chain entity associated in Core Data in the required context.  */
- (DSChainEntity *)chainEntityInContext:(NSManagedObjectContext *)context;

/*! @brief The managed object context of the chain.  */
@property (nonatomic, readonly) NSManagedObjectContext *chainManagedObjectContext;

// MARK: - L1 Network Chain Info

/*! @brief The network name. Currently main, test, dev or reg.  */
@property (nonatomic, readonly) NSString *networkName;

/*! @brief An array of known hard coded checkpoints for the chain.  */
@property (nonatomic, readonly) NSArray<DSCheckpoint *> *checkpoints;

// MARK: Sync

/*! @brief The genesis hash is the hash of the first block of the chain. For a devnet this is actually the second block as the first block is created in a special way for devnets.  */
@property (nonatomic, readonly) UInt256 genesisHash;






// MARK: - DashSync Chain Info

/*! @brief The chain type (MainNet, TestNet or DevNet).  */
@property (nonatomic, readonly) ChainType chainType;

/*! @brief A threshold after which a peer will be banned.  */
@property (nonatomic, readonly) uintptr_t peerMisbehavingThreshold;

/*! @brief True if this chain syncs the blockchain. All Chains currently sync the blockchain.  */
@property (nonatomic, readonly) BOOL syncsBlockchain;

/*! @brief True if this chain should sync headers first for masternode list verification.  */
@property (nonatomic, readonly) BOOL needsInitialTerminalHeadersSync;

/*! @brief The default transaction version used when sending transactions.  */
@property (nonatomic, readonly) uint16_t transactionVersion;

/*! @brief The number of minimumDifficultyBlocks.  */
@property (nonatomic, assign) uint32_t minimumDifficultyBlocks;

/*! @brief The flag represents whether the quorum rotation is enabled in this chain.  */
@property (nonatomic, assign) BOOL isRotatedQuorumsPresented;

/*! @brief Returns all standard derivaton paths used for the chain based on the account number.  */
- (NSArray<DSDerivationPath *> *)standardDerivationPathsForAccountNumber:(uint32_t)accountNumber;

// MARK: Names and Identifiers

/*! @brief The unique identifier of the chain. This unique id follows the same chain accross devices because it is the short hex string of the genesis hash.  */
@property (nonatomic, readonly) NSString *uniqueID;

/*! @brief The name of the chain (Mainnet-Testnet-Devnet).  */
@property (nonatomic, readonly) NSString *name;

/*! @brief The localized name of the chain (Mainnet-Testnet-Devnet).  */
@property (nonatomic, readonly) NSString *localizedName;

- (void)setDevnetNetworkName:(NSString *)networkName;

// MARK: - Wallets

/*! @brief The wallets in the chain.  */
@property (nonatomic, readonly) NSArray<DSWallet *> *wallets;

/*! @brief Conveniance method. Does this walleet have a chain?  */
@property (nonatomic, readonly) BOOL hasAWallet;

/*! @brief Conveniance method. The earliest known creation time for any wallet in this chain.  */
@property (nonatomic, readonly) NSTimeInterval earliestWalletCreationTime;

/*! @brief Unregister a wallet from the chain, it will no longer be loaded or used.  */
- (void)unregisterWallet:(DSWallet *)wallet;

/*! @brief Register a wallet to the chain.  */
- (void)registerWallet:(DSWallet *)wallet;

/*! @brief Unregister all wallets from the chain, they will no longer be loaded or used.  */
- (void)unregisterAllWallets;

/*! @brief Unregister all wallets from the chain that don't have an extended public key in one of their derivation paths, they will no longer be loaded or used.  */
- (void)unregisterAllWalletsMissingExtendedPublicKeys;

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

///*! @brief The last known chain sync block on the chain.  */
@property (nonatomic, readonly, nullable) DSBlock *lastSyncBlock;
//
///*! @brief The last known chain sync block on the chain, don't recover from checkpoints if it is not known.  */
//@property (nonatomic, readonly, nullable) DSBlock *lastSyncBlockDontUseCheckpoints;
//
/*! @brief The last known terminal block on the chain.  */
@property (nonatomic, readonly, nullable) DSBlock *lastTerminalBlock;
//
///*! @brief The last known block on the chain before the given timestamp.  */
//- (DSBlock *)lastChainSyncBlockOnOrBeforeTimestamp:(NSTimeInterval)timestamp;
//
///*! @brief The last known block or header on the chain before the given timestamp.  */
//- (DSBlock *)lastBlockOnOrBeforeTimestamp:(NSTimeInterval)timestamp;
//
/*! @brief The last known orphan on the chain. An orphan is a block who's parent is currently not known.  */
@property (nonatomic, readonly, nullable) DSBlock *lastOrphan;
//
///*! @brief A dictionary of the the most recent known blocks keyed by block hash.  */
//@property (nonatomic, readonly) NSDictionary<NSValue *, DSMerkleBlock *> *recentBlocks;

/*! @brief A short hex string of the last block's block hash.  */
@property (nonatomic, readonly, nullable) NSString *chainTip;

/*! @brief The block locator array is an array of the 10 most recent block hashes in decending order followed by block hashes that double the step back each iteration in decending order and finishing with the previous known checkpoint after that last hash. Something like (top, -1, -2, -3, -4, -5, -6, -7, -8, -9, -11, -15, -23, -39, -71, -135, ..., 0).  */
@property (nonatomic, readonly, nullable) NSArray<NSData *> *chainSyncBlockLocatorArray;


// MARK: Chain Sync

///*! @brief Returns the hash of the last persisted sync block. The sync block itself most likely is not persisted.  */
//@property (nonatomic, readonly) UInt256 lastPersistedChainSyncBlockHash;
//
///*! @brief Returns the height of the last persisted sync block. The sync block itself most likely is not persisted.  */
//@property (nonatomic, readonly) uint32_t lastPersistedChainSyncBlockHeight;
//
///*! @brief Returns the timestamp of the last persisted sync block. The sync block itself most likely is not persisted.  */
//@property (nonatomic, readonly) NSTimeInterval lastPersistedChainSyncBlockTimestamp;

///*! @brief Returns the locators of the last persisted chain sync block. The sync block itself most likely is not persisted.  */
//@property (nullable, nonatomic, readonly) NSArray *lastPersistedChainSyncLocators;

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


// MARK: Chain Lock

/*! @brief Returns the last chainLock known by the chain at the heighest height.  */
@property (nonatomic, readonly) DSChainLock *lastChainLock;

// MARK: - Transactions

/*! @brief Returns all wallet transactions sorted by date, most recent first.  */
@property (nonatomic, readonly) NSArray<DSTransaction *> *allTransactions;

/*! @brief Returns the transaction with the given hash if it's been registered in any wallet on the chain (might also return non-registered) */
- (DSTransaction *_Nullable)transactionForHash:(UInt256)txHash;

/*! @brief Returns the direction of a transaction for the chain (Sent - Received - Moved - Not Account Funds) */
- (DSTransactionDirection)directionOfTransaction:(DSTransaction *)transaction;

/*! @brief Returns the amount received globally from the transaction (total outputs to change and/or receive addresses) */
- (uint64_t)amountReceivedFromTransaction:(DSTransaction *)transaction;

/*! @brief Returns the amount sent globally by the trasaction (total wallet outputs consumed, change and fee included) */
- (uint64_t)amountSentByTransaction:(DSTransaction *)transaction;

/*! @brief Returns if this transaction has any local references. Local references are a pubkey hash contained in a wallet, pubkeys in wallets special derivation paths, or anything that would make the transaction relevant for this device. */
- (BOOL)transactionHasLocalReferences:(DSTransaction *)transaction;

// MARK: - Bloom Filter

/*! @brief Returns if a filter can be created for the chain. Generally this means that the chain has at least a wallet or a standalone derivation path. */
@property (nonatomic, readonly) BOOL canConstructAFilter;

/*! @brief Returns a bloom filter with the given false positive rate tweaked with the value tweak. The value tweak is generally peer specific. */
- (DSBloomFilter *)bloomFilterWithFalsePositiveRate:(double)falsePositiveRate withTweak:(uint32_t)tweak;

// MARK: - Accounts and Balances

/*! @brief The current wallet balance excluding transactions known to be invalid.  */
@property (nonatomic, readonly) uint64_t balance;

/*! @brief All accounts that contain the specified transaction hash. The transaction is also returned if it is found.  */
- (NSArray<DSAccount *> *)accountsForTransactionHash:(UInt256)txHash transaction:(DSTransaction *_Nullable *_Nullable)transaction;

/*! @brief Returns the first account with a balance.   */
- (DSAccount *_Nullable)firstAccountWithBalance;

/*! @brief Returns an account to which the given transaction is or can be associated with (even if it hasn't been registered), no account if the transaction is not associated with the wallet.  */
- (DSAccount *_Nullable)firstAccountThatCanContainTransaction:(DSTransaction *)transaction;

/*! @brief Returns all accounts to which the given transaction is or can be associated with (even if it hasn't been registered)  */
- (NSArray *)accountsThatCanContainTransaction:(DSTransaction *_Nonnull)transaction;

/*! @brief Returns an account to which the given transaction hash is associated with, no account if the transaction hash is not associated with the wallet.  */
- (DSAccount *_Nullable)firstAccountForTransactionHash:(UInt256)txHash transaction:(DSTransaction *_Nullable *_Nullable)transaction wallet:(DSWallet *_Nullable *_Nullable)wallet;

/*! @brief Returns an account to which the given address is contained in a derivation path.  */
- (DSAccount *_Nullable)accountContainingAddress:(NSString *)address;

/*! @brief Returns an account to which the given address is known by a dashpay outgoing derivation path.  */
- (DSAccount *_Nullable)accountContainingDashpayExternalDerivationPathAddress:(NSString *)address;

// MARK: - Governance

/*! @brief Returns a count of all governance objects.  */
@property (nonatomic, assign) uint32_t totalGovernanceObjectsCount;

// MARK: - Identities

/*! @brief Returns a count of local blockchain identities.  */
@property (nonatomic, readonly) uint32_t localBlockchainIdentitiesCount;

/*! @brief Returns a count of blockchain invitations that have been created locally.  */
@property (nonatomic, readonly) uint32_t localBlockchainInvitationsCount;

/*! @brief Returns an array of all local blockchain identities.  */
@property (nonatomic, readonly) NSArray<DSBlockchainIdentity *> *localBlockchainIdentities;

/*! @brief Returns a dictionary of all local blockchain identities keyed by uniqueId.  */
@property (nonatomic, readonly) NSDictionary<NSData *, DSBlockchainIdentity *> *localBlockchainIdentitiesByUniqueIdDictionary;

/*! @brief Returns a blockchain identity by uniqueId, if it exists.  */
- (DSBlockchainIdentity *_Nullable)blockchainIdentityForUniqueId:(UInt256)uniqueId;

/*! @brief Returns a blockchain identity that could have created this contract.  */
- (DSBlockchainIdentity *_Nullable)blockchainIdentityThatCreatedContract:(DPContract *)contract withContractId:(UInt256)contractId foundInWallet:(DSWallet *_Nullable *_Nullable)foundInWallet;

/*! @brief Returns a blockchain identity by uniqueId, if it exists. Also returns the wallet it was found in.  */
- (DSBlockchainIdentity *_Nullable)blockchainIdentityForUniqueId:(UInt256)uniqueId foundInWallet:(DSWallet *_Nullable *_Nullable)foundInWallet;

/*! @brief Returns a blockchain identity by uniqueId, if it exists. Also returns the wallet it was found in. Allows to search foreign blockchain identities too  */
- (DSBlockchainIdentity *)blockchainIdentityForUniqueId:(UInt256)uniqueId foundInWallet:(DSWallet *_Nullable *_Nullable)foundInWallet includeForeignBlockchainIdentities:(BOOL)includeForeignBlockchainIdentities;

// MARK: - Chain Retrieval methods

/*! @brief Mainnet chain.  */
+ (DSChain *)mainnet;

/*! @brief Testnet chain.  */
+ (DSChain *)testnet;

/*! @brief Devnet chain with given identifier.  */
+ (DSChain *_Nullable)devnetWithIdentifier:(NSString *)identifier;

/*! @brief Set up a given devnet with an identifier, checkpoints, default L1, JRPC and GRPC ports, a dpns contractId and a dashpay contract id. minimumDifficultyBlocks are used to speed up the initial chain creation. This devnet will be registered on the keychain. The additional isTransient property allows for test usage where you do not wish to persist the devnet.  */
+ (DSChain *)setUpDevnetWithIdentifier:(DevnetType)devnetType
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
+ (DSChain *)recoverKnownDevnetWithIdentifier:(DevnetType)devnetType withCheckpoints:(NSArray<DSCheckpoint *> *)checkpointArray performSetup:(BOOL)performSetup;

/*! @brief Retrieve a chain having the specified network name.  */
+ (DSChain *_Nullable)chainForNetworkName:(NSString *_Nullable)networkName;

//// MARK: - Chain Info methods

//
//- (BOOL)isMainnet;
//- (BOOL)isTestnet;
//- (BOOL)isDevnetAny;
//- (BOOL)isEvolutionEnabled;
//- (BOOL)isDevnetWithGenesisHash:(UInt256)genesisHash;
- (BOOL)isCore19Active;
- (BOOL)isCore20Active;
//- (BOOL)isCore20ActiveAtHeight:(uint32_t)height;
//- (KeyKind)activeBLSType;

@end

@protocol DSChainTransactionsDelegate
@required

- (void)chain:(DSChain *)chain didSetBlockHeight:(int32_t)height andTimestamp:(NSTimeInterval)timestamp forTransactionHashes:(NSArray<NSValue *> *)txHashes updatedTransactions:(NSArray *)updatedTransactions;
- (void)chainWasWiped:(DSChain *)chain;

@end

@protocol DSChainIdentitiesDelegate
@required
- (void)chain:(DSChain *)chain didFinishInChainSyncPhaseFetchingBlockchainIdentityDAPInformation:(DSBlockchainIdentity *)blockchainIdentity;

@end

@protocol DSChainDelegate <DSChainTransactionsDelegate, DSChainIdentitiesDelegate>

@required

- (void)chainWillStartSyncingBlockchain:(DSChain *)chain;
- (void)chainShouldStartSyncingBlockchain:(DSChain *)chain onPeer:(DSPeer *)peer;
- (void)chainFinishedSyncingTransactionsAndBlocks:(DSChain *)chain fromPeer:(DSPeer *_Nullable)peer onMainChain:(BOOL)onMainChain;
- (void)chainFinishedSyncingInitialHeaders:(DSChain *)chain fromPeer:(DSPeer *_Nullable)peer onMainChain:(BOOL)onMainChain;
- (void)chainFinishedSyncingMasternodeListsAndQuorums:(DSChain *)chain;
- (void)chain:(DSChain *)chain receivedOrphanBlock:(DSBlock *)merkleBlock fromPeer:(DSPeer *)peer;
- (void)chain:(DSChain *)chain wasExtendedWithBlock:(DSBlock *)merkleBlock fromPeer:(DSPeer *)peer;
- (void)chain:(DSChain *)chain badBlockReceivedFromPeer:(DSPeer *)peer;

@end

NS_ASSUME_NONNULL_END
