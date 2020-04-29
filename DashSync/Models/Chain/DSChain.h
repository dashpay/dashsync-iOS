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

#import <Foundation/Foundation.h>
#import "BigIntTypes.h"
#import "DSChainConstants.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString* const DSChainWalletsDidChangeNotification;
FOUNDATION_EXPORT NSString* const DSChainStandaloneDerivationPathsDidChangeNotification;
FOUNDATION_EXPORT NSString* const DSChainStandaloneAddressesDidChangeNotification;
FOUNDATION_EXPORT NSString* const DSChainBlocksDidChangeNotification;
FOUNDATION_EXPORT NSString* const DSChainBlockWasLockedNotification;
FOUNDATION_EXPORT NSString* const DSChainNotificationBlockKey;
FOUNDATION_EXPORT NSString* const DSChainNewChainTipBlockNotification;

typedef NS_ENUM(uint16_t, DSChainType) {
    DSChainType_MainNet,
    DSChainType_TestNet,
    DSChainType_DevNet,
};

typedef NS_ENUM(NSUInteger, DSTransactionDirection) {
    DSTransactionDirection_Sent,
    DSTransactionDirection_Received,
    DSTransactionDirection_Moved,
    DSTransactionDirection_NotAccountFunds,
};

@class DSChain, DSChainEntity, DSChainManager, DSWallet, DSMerkleBlock, DSPeer, DSDerivationPath, DSTransaction, DSAccount, DSSimplifiedMasternodeEntry, DSBlockchainIdentity, DSBloomFilter, DSProviderRegistrationTransaction, DSMasternodeList;

@protocol DSChainDelegate;

@interface DSCheckpoint : NSObject <NSCoding>

+ (DSCheckpoint*)genesisDevnetCheckpoint;
@property (nonatomic, assign) uint32_t height;
@property (nonatomic, assign) UInt256 checkpointHash;
@property (nonatomic, assign) uint32_t timestamp;
@property (nonatomic, assign) uint32_t target;
@property (nonatomic, strong) NSString * masternodeListName;
@property (nonatomic, assign) UInt256 merkleRoot;

- (DSMerkleBlock*)merkleBlockForChain:(DSChain*)chain;

@end

@interface DSChain : NSObject

// MARK: - Shortcuts

/*! @brief The chain manager is a container for all managers (peer, identity, governance, masternode, spork and transition). It also is used to control the sync process.  */
@property (nonatomic, weak, nullable) DSChainManager * chainManager;

/*! @brief The chain entity associated in Core Data in the context of the chain's managed object context.  */
@property (nonatomic, readonly, nullable) DSChainEntity * chainEntity;

/*! @brief The managed object context of the chain.  */
@property (nonatomic, readonly) NSManagedObjectContext * managedObjectContext;

// MARK: - L1 Network Chain Info

/*! @brief The network name. Currently main, test, dev or reg.  */
@property (nonatomic, readonly) NSString * networkName;

/*! @brief An array of known hard coded checkpoints for the chain.  */
@property (nonatomic, readonly) NSArray<DSCheckpoint*> * checkpoints;

// MARK: Sync

/*! @brief The genesis hash is the hash of the first block of the chain. For a devnet this is actually the second block as the first block is created in a special way for devnets.  */
@property (nonatomic, readonly) UInt256 genesisHash;

/*! @brief The magic number is used in message headers to indicate what network (or chain) a message is intended for.  */
@property (nonatomic, readonly) uint32_t magicNumber;

/*! @brief The base reward is the intial mining reward at genesis for the chain. This goes down by 7% every year. A SPV client does not validate that the reward amount is correct as it would not make sense for miners to enter incorrect rewards as the blocks would be rejected by full nodes.  */
@property (nonatomic, readonly) uint64_t baseReward;

/*! @brief minProtocolVersion is the minimum protocol version that peers on this chain can communicate with. This should only be changed in the case of devnets.  */
@property (nonatomic, assign) uint32_t minProtocolVersion;

/*! @brief protocolVersion is the protocol version that we currently use for this chain. This should only be changed in the case of devnets.  */
@property (nonatomic, assign) uint32_t protocolVersion;

/*! @brief protocolVersion is the protocol version that we currently use for this chain.  */
@property (nonatomic, readonly) uint32_t maxProofOfWork;

/*! @brief allowMinDifficultyBlocks is set to TRUE on networks where mining is low enough that it can be attacked by increasing difficulty with ASICs and then no longer running ASICs. This is set to NO for Mainnet, and generally should be YES on all other networks.  */
@property (nonatomic, readonly) BOOL allowMinDifficultyBlocks;

/*! @brief This is the minimum amount that can be entered into an amount for a output for it not to be considered dust.  */
@property (nonatomic, readonly) uint64_t minOutputAmount;

// MARK: Fees

@property (nonatomic, assign) uint64_t feePerByte;

/*! @brief The fee for transactions in L1 are now entirely dependent on their size.  */
- (uint64_t)feeForTxSize:(NSUInteger)size;

// MARK: Ports

/*! @brief The standard port for the chain for L1 communication.  */
@property (nonatomic, assign) uint32_t standardPort;

/*! @brief The standard port for the chain for L2 communication through JRPC.  */
@property (nonatomic, assign) uint32_t standardDapiJRPCPort;

/*! @brief The standard port for the chain for L2 communication through GRPC.  */
@property (nonatomic, assign) uint32_t standardDapiGRPCPort;

// MARK: Sporks

/*! @brief The spork public key as a hex string.  */
@property (nonatomic, strong, nullable) NSString * sporkPublicKeyHexString;

/*! @brief The spork private key as a base 58 string.  */
@property (nonatomic, strong, nullable) NSString * sporkPrivateKeyBase58String;

/*! @brief The spork address base 58 string (addresses are known to be base 58).  */
@property (nonatomic, strong, nullable) NSString * sporkAddress;

// MARK: - L2 Network Chain Info

/*! @brief The dpns contract id.  */
@property (nonatomic, assign) UInt256 dpnsContractID;

/*! @brief The dashpay contract id.  */
@property (nonatomic, assign) UInt256 dashpayContractID;

// MARK: - DashSync Chain Info

/*! @brief The chain type (MainNet, TestNet or DevNet).  */
@property (nonatomic, readonly) DSChainType chainType;

/*! @brief A threshold after which a peer will be banned.  */
@property (nonatomic, readonly) uint32_t peerMisbehavingThreshold;

/*! @brief True if this chain syncs the blockchain. All Chains currently sync the blockchain.  */
@property (nonatomic, readonly) BOOL syncsBlockchain;

/*! @brief The default transaction version used when sending transactions.  */
@property (nonatomic, readonly) uint16_t transactionVersion;

/*! @brief Returns all standard derivaton paths used for the chain based on the account number.  */
- (NSArray<DSDerivationPath*>*)standardDerivationPathsForAccountNumber:(uint32_t)accountNumber;

// MARK: Names and Identifiers

/*! @brief The unique identifier of the chain. This unique id follows the same chain accross devices because it is the short hex string of the genesis hash.  */
@property (nonatomic, readonly) NSString * uniqueID;

/*! @brief The devnet identifier is the name of the devnet, the genesis hash of a devnet uses this devnet identifier in its construction.  */
@property (nonatomic, readonly, nullable) NSString * devnetIdentifier;

/*! @brief The name of the chain (Mainnet-Testnet-Devnet).  */
@property (nonatomic, readonly) NSString * name;

/*! @brief The localized name of the chain (Mainnet-Testnet-Devnet).  */
@property (nonatomic, readonly) NSString * localizedName;

- (void)setDevnetNetworkName:(NSString*)networkName;

// MARK: - Wallets

/*! @brief The wallets in the chain.  */
@property (nonatomic, readonly) NSArray<DSWallet *> * wallets;

/*! @brief Conveniance method. Does this walleet have a chain?  */
@property (nonatomic, readonly) BOOL hasAWallet;

/*! @brief Conveniance method. The earliest known creation time for any wallet in this chain.  */
@property (nonatomic, readonly) NSTimeInterval earliestWalletCreationTime;

/*! @brief Unregister a wallet from the chain, it will no longer be loaded or used.  */
- (void)unregisterWallet:(DSWallet*)wallet;

/*! @brief Register a wallet to the chain.  */
- (void)registerWallet:(DSWallet*)wallet;

/*! @brief Unregister all wallets from the chain, they will no longer be loaded or used.  */
- (void)unregisterAllWallets;

// MARK: - Standalone Derivation Paths

/*! @brief Standalone derivation paths used in this chain. This is currently an experimental feature  */
@property (nonatomic, readonly) NSArray<DSDerivationPath *> * standaloneDerivationPaths;

/*! @brief Conveniance method to find out if the chain has a standalone derivation path. Standalone derivation paths are currently an experimental feature  */
@property (nonatomic, readonly) BOOL hasAStandaloneDerivationPath;

/*! @brief Unregister a standalone derivation path from the chain, it will no longer be loaded or used. Standalone derivation paths are currently an experimental feature  */
- (void)unregisterStandaloneDerivationPath:(DSDerivationPath*)derivationPath;

/*! @brief Register a standalone derivation path to the chain. Standalone derivation paths are currently an experimental feature  */
- (void)registerStandaloneDerivationPath:(DSDerivationPath*)derivationPath;

// MARK: - Checkpoints

/*! @brief Returns the last checkpoint that has a masternode list attached to it.  */
- (DSCheckpoint* _Nullable)lastCheckpointHavingMasternodeList;

/*! @brief Returns the checkpoint matching the parameter block hash, if one exists.  */
- (DSCheckpoint* _Nullable)checkpointForBlockHash:(UInt256)blockHash;

/*! @brief Returns the checkpoint at a given block height, if one exists at that block height.  */
- (DSCheckpoint* _Nullable)checkpointForBlockHeight:(uint32_t)blockHeight;

// MARK: - Blocks

/*! @brief The last known block on the chain.  */
@property (nonatomic, readonly, nullable) DSMerkleBlock * lastBlock;

/*! @brief The last known orphan on the chain. An orphan is a block who's parent is currently not known.  */
@property (nonatomic, readonly, nullable) DSMerkleBlock * lastOrphan;

/*! @brief A dictionary of the the most recent known blocks keyed by block hash.  */
@property (nonatomic, readonly) NSDictionary <NSValue*,DSMerkleBlock*> *recentBlocks;

/*! @brief A short hex string of the last block's block hash.  */
@property (nonatomic, readonly, nullable) NSString * chainTip;

/*! @brief The block locator array is an array of the 10 most recent block hashes in decending order followed by block hashes that double the step back each iteration in decending order and finishing with the previous known checkpoint after that last hash. Something like (top, -1, -2, -3, -4, -5, -6, -7, -8, -9, -11, -15, -23, -39, -71, -135, ..., 0).  */
@property (nonatomic, readonly, nullable) NSArray <NSData*> * blockLocatorArray;

/*! @brief The timestamp of a block at a given height.  */
- (NSTimeInterval)timestampForBlockHeight:(uint32_t)blockHeight; // seconds since 1970, 00:00:00 01/01/01 GMT

/*! @brief The block on the main chain at a certain height. By main chain it is understood to mean not forked chain - this could be on mainnet, testnet or a devnet.  */
- (DSMerkleBlock * _Nullable)blockAtHeight:(uint32_t)height;

/*! @brief Returns a known block with the given block hash. A null result could mean that the block was old and has since been discarded.  */
- (DSMerkleBlock * _Nullable)blockForBlockHash:(UInt256)blockHash;


/*! @brief Returns a known block with a given distance from the chain tip. A null result would mean that the given distance exceeded the number of blocks kept locally.  */
- (DSMerkleBlock * _Nullable)blockFromChainTip:(NSUInteger)blocksAgo;

// MARK: Heights

/*! @brief Returns the height of the last block.  */
@property (nonatomic, readonly) uint32_t lastBlockHeight;

/*! @brief Returns the height of the last block.  */
@property (nonatomic, readonly) uint32_t bestBlockHeight;

/*! @brief Returns the estimated height of chain. This is reported by the current download peer but can not be verified and is not secure.  */
@property (nonatomic, readonly) uint32_t estimatedBlockHeight;

/*! @brief Returns the height of a block having the given hash. If no block is found returns UINT32_MAX  */
- (uint32_t)heightForBlockHash:(UInt256)blockhash;

// MARK: Chain Lock

/*! @brief Returns if there is a block at the following height that is confirmed.  */
- (BOOL)blockHeightChainLocked:(uint32_t)height;

// MARK: - Transactions

/*! @brief Returns all wallet transactions sorted by date, most recent first.  */
@property (nonatomic, readonly) NSArray <DSTransaction*> * allTransactions;

/*! @brief Returns the transaction with the given hash if it's been registered in any wallet on the chain (might also return non-registered) */
- (DSTransaction * _Nullable)transactionForHash:(UInt256)txHash;

/*! @brief Returns the direction of a transaction for the chain (Sent - Received - Moved - Not Account Funds) */
- (DSTransactionDirection)directionOfTransaction:(DSTransaction *)transaction;

/*! @brief Returns the amount received globally from the transaction (total outputs to change and/or receive addresses) */
- (uint64_t)amountReceivedFromTransaction:(DSTransaction *)transaction;

/*! @brief Returns the amount sent globally by the trasaction (total wallet outputs consumed, change and fee included) */
- (uint64_t)amountSentByTransaction:(DSTransaction *)transaction;

/*! @brief Returns if this transaction has any local references. Local references are a pubkey hash contained in a wallet, pubkeys in wallets special derivation paths, or anything that would make the transaction relevant for this device. */
- (BOOL)transactionHasLocalReferences:(DSTransaction*)transaction;

// MARK: - Bloom Filter

/*! @brief Returns if a filter can be created for the chain. Generally this means that the chain has at least a wallet or a standalone derivation path. */
@property (nonatomic, readonly) BOOL canConstructAFilter;

/*! @brief Returns a bloom filter with the given false positive rate tweaked with the value tweak. The value tweak is generally peer specific. */
- (DSBloomFilter*)bloomFilterWithFalsePositiveRate:(double)falsePositiveRate withTweak:(uint32_t)tweak;

// MARK: - Accounts and Balances

/*! @brief The current wallet balance excluding transactions known to be invalid.  */
@property (nonatomic, readonly) uint64_t balance;

/*! @brief All accounts that contain the specified transaction hash. The transaction is also returned if it is found.  */
- (NSArray<DSAccount *> *)accountsForTransactionHash:(UInt256)txHash transaction:(DSTransaction *_Nullable*_Nullable)transaction;

/*! @brief Returns an account to which the given transaction is or can be associated with (even if it hasn't been registered), no account if the transaction is not associated with the wallet.  */
- (DSAccount* _Nullable)firstAccountThatCanContainTransaction:(DSTransaction *)transaction;

/*! @brief Returns all accounts to which the given transaction is or can be associated with (even if it hasn't been registered)  */
- (NSArray*)accountsThatCanContainTransaction:(DSTransaction * _Nonnull)transaction;

/*! @brief Returns an account to which the given transaction hash is associated with, no account if the transaction hash is not associated with the wallet.  */
- (DSAccount * _Nullable)firstAccountForTransactionHash:(UInt256)txHash transaction:(DSTransaction * _Nullable * _Nullable)transaction wallet:(DSWallet * _Nullable * _Nullable)wallet;

/*! @brief Returns an account to which the given address is contained in a derivation path.  */
- (DSAccount* _Nullable)accountContainingAddress:(NSString *)address;

// MARK: - Governance

/*! @brief Returns a count of all governance objects.  */
@property (nonatomic, assign) uint32_t totalGovernanceObjectsCount;

// MARK: - Identities

/*! @brief Returns a count of local blockchain identities.  */
@property (nonatomic, readonly) uint32_t localBlockchainIdentitiesCount;

/*! @brief Returns an array of all local blockchain identities.  */
@property (nonatomic, readonly) NSArray <DSBlockchainIdentity *>* localBlockchainIdentities;

/*! @brief Returns a dictionary of all local blockchain identities keyed by uniqueId.  */
@property (nonatomic, readonly) NSDictionary <NSData*,DSBlockchainIdentity *>* localBlockchainIdentitiesByUniqueIdDictionary;

/*! @brief Returns a blockchain identity by uniqueId, if it exists.  */
- (DSBlockchainIdentity* _Nullable)blockchainIdentityForUniqueId:(UInt256)uniqueId;

/*! @brief Returns a blockchain identity by uniqueId, if it exists. Also returns the wallet it was found in.  */
- (DSBlockchainIdentity* _Nullable)blockchainIdentityForUniqueId:(UInt256)uniqueId foundInWallet:(DSWallet*_Nullable*_Nullable)foundInWallet;

// MARK: - Chain Retrieval methods

/*! @brief Mainnet chain.  */
+ (DSChain*)mainnet;

/*! @brief Testnet chain.  */
+ (DSChain*)testnet;

/*! @brief Devnet chain with given identifier.  */
+ (DSChain* _Nullable)devnetWithIdentifier:(NSString*)identifier;

/*! @brief Set up a given devnet with an identifier, checkpoints, default L1, JRPC and GRPC ports, a dpns contractId and a dashpay contract id. This devnet will be registered on the keychain.  */
+ (DSChain*)setUpDevnetWithIdentifier:(NSString*)identifier withCheckpoints:(NSArray<DSCheckpoint*>* _Nullable)checkpointArray withDefaultPort:(uint32_t)port withDefaultDapiJRPCPort:(uint32_t)dapiJRPCPort withDefaultDapiGRPCPort:(uint32_t)dapiGRPCPort dpnsContractID:(UInt256)dpnsContractID dashpayContractID:(UInt256)dashpayContractID;

/*! @brief Retrieve from the keychain a devnet with an identifier and add given checkpoints.  */
+ (DSChain*)recoverKnownDevnetWithIdentifier:(NSString*)identifier withCheckpoints:(NSArray<DSCheckpoint*>*)checkpointArray;

/*! @brief Retrieve a chain having the specified network name.  */
+ (DSChain* _Nullable)chainForNetworkName:(NSString* _Nullable)networkName;

// MARK: - Chain Info methods

- (BOOL)isMainnet;
- (BOOL)isTestnet;
- (BOOL)isDevnetAny;
- (BOOL)isEvolutionEnabled;
- (BOOL)isDevnetWithGenesisHash:(UInt256)genesisHash;

@end

@protocol DSChainTransactionsDelegate
@required

-(void)chain:(DSChain*)chain didSetBlockHeight:(int32_t)height andTimestamp:(NSTimeInterval)timestamp forTxHashes:(NSArray *)txHashes updatedTx:(NSArray *)updatedTx;
-(void)chainWasWiped:(DSChain*)chain;

@end

@protocol DSChainDelegate <DSChainTransactionsDelegate>

@required

-(void)chainWillStartSyncingBlockchain:(DSChain*)chain;
-(void)chainFinishedSyncingTransactionsAndBlocks:(DSChain*)chain fromPeer:(DSPeer* _Nullable)peer onMainChain:(BOOL)onMainChain;
-(void)chainFinishedSyncingMasternodeListsAndQuorums:(DSChain*)chain;
-(void)chain:(DSChain*)chain receivedOrphanBlock:(DSMerkleBlock*)merkleBlock fromPeer:(DSPeer*)peer;
-(void)chain:(DSChain*)chain wasExtendedWithBlock:(DSMerkleBlock*)merkleBlock fromPeer:(DSPeer*)peer;
-(void)chain:(DSChain*)chain badBlockReceivedFromPeer:(DSPeer*)peer;

@end

NS_ASSUME_NONNULL_END
