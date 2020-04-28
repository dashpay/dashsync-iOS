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

typedef NS_ENUM(uint16_t, DSChainType) {
    DSChainType_MainNet,
    DSChainType_TestNet,
    DSChainType_DevNet,
};

FOUNDATION_EXPORT NSString* const DSChainWalletsDidChangeNotification;
FOUNDATION_EXPORT NSString* const DSChainStandaloneDerivationPathsDidChangeNotification;
FOUNDATION_EXPORT NSString* const DSChainStandaloneAddressesDidChangeNotification;
FOUNDATION_EXPORT NSString* const DSChainBlocksDidChangeNotification;
FOUNDATION_EXPORT NSString* const DSChainBlockWasLockedNotification;
FOUNDATION_EXPORT NSString* const DSChainNotificationBlockKey;
FOUNDATION_EXPORT NSString* const DSChainNewChainTipBlockNotification;

typedef NS_ENUM(NSUInteger, DSTransactionDirection) {
    DSTransactionDirection_Sent,
    DSTransactionDirection_Received,
    DSTransactionDirection_Moved,
    DSTransactionDirection_NotAccountFunds,
};

@class DSWallet,DSMerkleBlock,DSChainManager,DSPeer,DSChainEntity,DSDerivationPath,DSTransaction,DSAccount,DSSimplifiedMasternodeEntry,DSBlockchainIdentity,DSBloomFilter,DSProviderRegistrationTransaction,DSChain,DSMasternodeList;

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

@property (nonatomic, weak, nullable) DSChainManager * chainManager;
@property (nonatomic, readonly, nullable) DSChainEntity * chainEntity;
@property (nonatomic, readonly) NSManagedObjectContext * managedObjectContext;

// MARK: - L1 Network Chain Info

@property (nonatomic, readonly) NSString * networkName;
@property (nonatomic, readonly) NSArray<DSCheckpoint*> * checkpoints;

// MARK: Sync

@property (nonatomic, assign) UInt256 genesisHash;
@property (nonatomic, readonly) uint32_t magicNumber;
@property (nonatomic, readonly) uint64_t baseReward;
@property (nonatomic, assign) uint32_t minProtocolVersion;
@property (nonatomic, assign) uint32_t protocolVersion;
@property (nonatomic, readonly) uint32_t maxProofOfWork;
@property (nonatomic, readonly) BOOL allowMinDifficultyBlocks;
@property (nonatomic, assign) uint64_t feePerByte;
// outputs below this amount are uneconomical due to fees
@property (nonatomic, readonly) uint64_t minOutputAmount;

// MARK: Ports

@property (nonatomic, assign) uint32_t standardPort;
@property (nonatomic, assign) uint32_t standardDapiJRPCPort;
@property (nonatomic, assign) uint32_t standardDapiGRPCPort;

// MARK: Sporks

@property (nonatomic, strong, nullable) NSString * sporkPublicKey;
@property (nonatomic, strong, nullable) NSString * sporkPrivateKey;
@property (nonatomic, strong, nullable) NSString * sporkAddress;

// MARK: - L2 Network Chain Info

@property (nonatomic, assign) UInt256 dpnsContractID;
@property (nonatomic, assign) UInt256 dashpayContractID;

// MARK: - DashSync Chain Info

@property (nonatomic, assign) DSChainType chainType;
@property (nonatomic, readonly) uint32_t peerMisbehavingThreshold;
@property (nonatomic, readonly) BOOL syncsBlockchain;
@property (nonatomic, readonly) uint16_t transactionVersion;

// MARK: Names and Identifiers

@property (nonatomic, readonly) NSString * uniqueID;
@property (nonatomic, readonly,nullable) NSString * devnetIdentifier;
@property (nonatomic, readonly) NSString * name;
@property (nonatomic, readonly) NSString * localizedName;


// MARK: - Wallets

@property (nonatomic, readonly) NSArray<DSWallet *> * wallets;
@property (nonatomic, readonly) BOOL hasAWallet;
@property (nonatomic, readonly) NSTimeInterval earliestWalletCreationTime;
@property (nonatomic, readonly) NSString * chainWalletsKey;

// MARK: - Standalone Derivation Paths

@property (nonatomic, readonly) NSArray<DSDerivationPath *> * standaloneDerivationPaths;
@property (nonatomic, readonly) BOOL hasAStandaloneDerivationPath;

- (void)unregisterStandaloneDerivationPath:(DSDerivationPath*)derivationPath;
- (void)addStandaloneDerivationPath:(DSDerivationPath*)derivationPath;
- (void)registerStandaloneDerivationPath:(DSDerivationPath*)derivationPath;

// MARK: - Blocks

@property (nonatomic, readonly) NSDictionary *recentBlocks;
@property (nonatomic, readonly, nullable) NSString * chainTip;
@property (nonatomic, readonly, nullable) DSMerkleBlock * lastBlock;
@property (nonatomic, readonly, nullable) NSArray * blockLocatorArray;
@property (nonatomic, readonly, nullable) DSMerkleBlock *lastOrphan;

- (NSTimeInterval)timestampForBlockHeight:(uint32_t)blockHeight; // seconds since 1970, 00:00:00 01/01/01 GMT

- (DSMerkleBlock * _Nullable)blockAtHeight:(uint32_t)height;

- (DSMerkleBlock * _Nullable)blockForBlockHash:(UInt256)blockHash;

- (DSMerkleBlock * _Nullable)blockFromChainTip:(NSUInteger)blocksAgo;

// MARK: Heights

@property (nonatomic, readonly) uint32_t lastBlockHeight;
@property (nonatomic, readonly) uint32_t bestBlockHeight;
@property (nonatomic, readonly) uint32_t estimatedBlockHeight; // last block height reported by current download peer

- (uint32_t)heightForBlockHash:(UInt256)blockhash;

// MARK: Chain Lock

//Is there a block at the following height that is confirmed?
- (BOOL)blockHeightChainLocked:(uint32_t)height;

// MARK: - Transactions

// all wallet transactions sorted by date, most recent first
@property (nonatomic, readonly) NSArray * allTransactions;

-(void)setBlockHeight:(int32_t)height andTimestamp:(NSTimeInterval)timestamp forTxHashes:(NSArray *)txHashes;

// returns the transaction with the given hash if it's been registered in any wallet on the chain (might also return non-registered)
- (DSTransaction * _Nullable)transactionForHash:(UInt256)txHash;

- (DSTransactionDirection)directionOfTransaction:(DSTransaction *)transaction;

// returns the amount received globally from the transaction (total outputs to change and/or receive addresses)
- (uint64_t)amountReceivedFromTransaction:(DSTransaction *)transaction;

// retuns the amount sent globally by the trasaction (total wallet outputs consumed, change and fee included)
- (uint64_t)amountSentByTransaction:(DSTransaction *)transaction;

// Does this transaction have any local references, this means a pubkey hash contained in a wallet, pubkeys in wallets special derivation paths, or anything that would make the transaction important
- (BOOL)transactionHasLocalReferences:(DSTransaction*)transaction;

// MARK: - Bloom Filter

@property (nonatomic, readonly) BOOL canConstructAFilter;

- (DSBloomFilter*)bloomFilterWithFalsePositiveRate:(double)falsePositiveRate withTweak:(uint32_t)tweak;

// MARK: - Accounts and Balances

// current wallet balance excluding transactions known to be invalid
@property (nonatomic, readonly) uint64_t balance;

- (NSArray<DSAccount *> *)accountsForTransactionHash:(UInt256)txHash transaction:(DSTransaction *_Nullable*_Nullable)transaction;

// returns an account to which the given transaction is or can be associated with (even if it hasn't been registered), no account if the transaction is not associated with the wallet
- (DSAccount* _Nullable)firstAccountThatCanContainTransaction:(DSTransaction *)transaction;

// returns all accounts to which the given transaction is or can be associated with (even if it hasn't been registered)
- (NSArray*)accountsThatCanContainTransaction:(DSTransaction * _Nonnull)transaction;

// returns an account to which the given transaction hash is associated with, no account if the transaction hash is not associated with the wallet
- (DSAccount * _Nullable)firstAccountForTransactionHash:(UInt256)txHash transaction:(DSTransaction * _Nullable * _Nullable)transaction wallet:(DSWallet * _Nullable * _Nullable)wallet;

// returns an account to which the given address is contained in a derivation path
- (DSAccount* _Nullable)accountContainingAddress:(NSString *)address;

-(NSArray<DSDerivationPath*>*)standardDerivationPathsForAccountNumber:(uint32_t)accountNumber;

// MARK: - Masternode Lists and Quorums

@property (nonatomic, assign) uint32_t totalMasternodeCount;
@property (nonatomic, assign) UInt256 masternodeBaseBlockHash;

// MARK: - Governance

@property (nonatomic, assign) uint32_t totalGovernanceObjectsCount;

// MARK: - Identities

@property (nonatomic, readonly) uint32_t localBlockchainIdentitiesCount;

@property (nonatomic, readonly) NSArray <DSBlockchainIdentity *>* localBlockchainIdentities;

@property (nonatomic, readonly) NSDictionary <NSData*,DSBlockchainIdentity *>* localBlockchainIdentitiesByUniqueIdDictionary;

- (DSBlockchainIdentity* _Nullable)blockchainIdentityForUniqueId:(UInt256)uniqueId;

- (DSBlockchainIdentity* _Nullable)blockchainIdentityForUniqueId:(UInt256)uniqueId foundInWallet:(DSWallet*_Nullable*_Nullable)foundInWallet;

// MARK: - Peers

@property (nonatomic, readonly,nullable) NSString * registeredPeersKey;

// MARK: - Chain Retrieval methods

+ (DSChain*)mainnet;
+ (DSChain*)testnet;

+ (DSChain* _Nullable)devnetWithIdentifier:(NSString*)identifier;
+ (DSChain*)setUpDevnetWithIdentifier:(NSString*)identifier withCheckpoints:(NSArray<DSCheckpoint*>* _Nullable)checkpointArray withDefaultPort:(uint32_t)port withDefaultDapiJRPCPort:(uint32_t)dapiJRPCPort withDefaultDapiGRPCPort:(uint32_t)dapiGRPCPort dpnsContractID:(UInt256)dpnsContractID dashpayContractID:(UInt256)dashpayContractID;
+ (DSChain*)setUpDevnetWithIdentifier:(NSString*)identifier withCheckpoints:(NSArray<DSCheckpoint*>* _Nullable)checkpointArray withDefaultPort:(uint32_t)port withDefaultDapiJRPCPort:(uint32_t)dapiJRPCPort withDefaultDapiGRPCPort:(uint32_t)dapiGRPCPort dpnsContractID:(UInt256)dpnsContractID dashpayContractID:(UInt256)dashpayContractID isTransient:(BOOL)isTransient;
+ (DSChain*)recoverKnownDevnetWithIdentifier:(NSString*)identifier withCheckpoints:(NSArray<DSCheckpoint*>*)checkpointArray;

+ (DSChain* _Nullable)chainForNetworkName:(NSString* _Nullable)networkName;

// MARK: - Chain Info methods

- (BOOL)isMainnet;
- (BOOL)isTestnet;
- (BOOL)isDevnetAny;
- (BOOL)isEvolutionEnabled;
- (BOOL)isDevnetWithGenesisHash:(UInt256)genesisHash;

// MARK: - Chain Setup methods

-(void)setDevnetNetworkName:(NSString*)networkName;

-(void)setUp;

-(void)save;


-(void)setLastBlockHeightForRescan;



-(void)unregisterWallet:(DSWallet*)wallet;
-(void)addWallet:(DSWallet*)wallet;
-(void)registerWallet:(DSWallet*)wallet;
-(void)unregisterAllWallets;

// fee that will be added for a transaction of the given size in bytes
- (uint64_t)feeForTxSize:(NSUInteger)size;

- (DSCheckpoint* _Nullable)lastCheckpointWithMasternodeList;

- (DSCheckpoint* _Nullable)checkpointForBlockHash:(UInt256)blockHash;

- (DSCheckpoint* _Nullable)checkpointForBlockHeight:(uint32_t)blockHeight;


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
