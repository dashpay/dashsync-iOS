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

NS_ASSUME_NONNULL_BEGIN

typedef struct _DSUTXO {
    UInt256 hash;
    unsigned long n; // use unsigned long instead of uint32_t to avoid trailing struct padding (for NSValue comparisons)
} DSUTXO;

#define dsutxo_obj(o) [NSValue value:&(o) withObjCType:@encode(DSUTXO)]
#define dsutxo_data(o) [NSData dataWithBytes:&((struct { uint32_t u[256/32 + 1]; }) {\
o.hash.u32[0], o.hash.u32[1], o.hash.u32[2], o.hash.u32[3],\
o.hash.u32[4], o.hash.u32[5], o.hash.u32[6], o.hash.u32[7],\
CFSwapInt32HostToLittle((uint32_t)o.n) }) length:sizeof(UInt256) + sizeof(uint32_t)]

#define MAINNET_STANDARD_PORT 9999
#define TESTNET_STANDARD_PORT 19999
#define DEVNET_STANDARD_PORT 12999

#define MAINNET_DAPI_STANDARD_PORT 3000
#define TESTNET_DAPI_STANDARD_PORT 3000
#define DEVNET_DAPI_STANDARD_PORT 3000

#define PROTOCOL_VERSION_MAINNET   70210
#define MIN_PROTOCOL_VERSION_MAINNET  70209

#define PROTOCOL_VERSION_TESTNET   70212
#define MIN_PROTOCOL_VERSION_TESTNET  70212

#define PROTOCOL_VERSION_DEVNET   70212
#define MIN_PROTOCOL_VERSION_DEVNET  70212

#define DASH_MAGIC_NUMBER_TESTNET 0xffcae2ce
#define DASH_MAGIC_NUMBER_MAINNET 0xbd6b0cbf
#define DASH_MAGIC_NUMBER_DEVNET 0xceffcae2

#define MAX_PROOF_OF_WORK_MAINNET 0x1e0fffffu   // highest value for difficulty target (higher values are less difficult)
#define MAX_PROOF_OF_WORK_TESTNET 0x1e0fffffu
#define MAX_PROOF_OF_WORK_DEVNET 0x207fffffu

#define SPORK_PUBLIC_KEY_MAINNET @"04549ac134f694c0243f503e8c8a9a986f5de6610049c40b07816809b0d1d06a21b07be27b9bb555931773f62ba6cf35a25fd52f694d4e1106ccd237a7bb899fdd"

#define SPORK_PUBLIC_KEY_TESTNET @"046f78dcf911fbd61910136f7f0f8d90578f68d0b3ac973b5040fb7afb501b5939f39b108b0569dca71488f5bbf498d92e4d1194f6f941307ffd95f75e76869f0e"


#define SPORK_ADDRESS_MAINNET @"Xgtyuk76vhuFW2iT7UAiHgNdWXCf3J34wh"
#define SPORK_ADDRESS_TESTNET @"yjPtiKh2uwk3bDutTEA2q9mCtXyiZRWn55"


#define DEFAULT_FEE_PER_B TX_FEE_PER_B
#define MIN_FEE_PER_B     TX_FEE_PER_B // minimum relay fee on a 191byte tx
#define MAX_FEE_PER_B     1000 // slightly higher than a 1000bit fee on a 191byte tx

typedef NS_ENUM(uint16_t, DSChainType) {
    DSChainType_MainNet,
    DSChainType_TestNet,
    DSChainType_DevNet,
};

FOUNDATION_EXPORT NSString* const DSChainWalletsDidChangeNotification;
FOUNDATION_EXPORT NSString* const DSChainBlockchainUsersDidChangeNotification;
FOUNDATION_EXPORT NSString* const DSChainStandaloneDerivationPathsDidChangeNotification;
FOUNDATION_EXPORT NSString* const DSChainStandaloneAddressesDidChangeNotification;
FOUNDATION_EXPORT NSString* const DSChainBlocksDidChangeNotification;

@class DSWallet,DSMerkleBlock,DSChainPeerManager,DSPeer,DSChainEntity,DSDerivationPath,DSTransaction,DSAccount,DSSimplifiedMasternodeEntry,DSChainPeerManager,DSBlockchainUser;

@protocol DSChainDelegate;

@interface DSCheckpoint : NSObject <NSCoding>

+(DSCheckpoint*)genesisDevnetCheckpoint;
@property (nonatomic, assign) uint32_t height;
@property (nonatomic, assign) UInt256 checkpointHash;
@property (nonatomic, assign) uint32_t timestamp;
@property (nonatomic, assign) uint32_t target;

@end

@interface DSChain : NSObject

@property (nonatomic, readonly) NSArray<DSWallet *> * wallets;
@property (nonatomic, readonly) NSArray<DSDerivationPath *> * standaloneDerivationPaths;
@property (nonatomic, readonly) NSDictionary *recentBlocks;
@property (nonatomic, assign) DSChainType chainType;
@property (nonatomic, assign) uint32_t standardPort;
@property (nonatomic, assign) uint32_t standardDapiPort;
@property (nonatomic, assign) UInt256 genesisHash;
@property (nonatomic, readonly,nullable) NSString * chainTip;
@property (nonatomic, readonly) uint32_t lastBlockHeight;
@property (nonatomic, readonly) uint32_t estimatedBlockHeight; // last block height reported by current download peer
@property (nonatomic, readonly) NSString * networkName;
@property (nonatomic, readonly) NSString * name;
@property (nonatomic, readonly) NSString * localizedName;
@property (nonatomic, readonly) NSString * uniqueID;
@property (nonatomic, readonly,getter=isActive) BOOL active;
@property (nonatomic, weak,nullable) DSChainPeerManager * peerManagerDelegate;
@property (nonatomic, readonly,nullable) DSMerkleBlock * lastBlock;
@property (nonatomic, readonly,nullable) NSArray * blockLocatorArray;
@property (nonatomic, readonly,nullable) DSMerkleBlock *lastOrphan;
@property (nonatomic, readonly,nullable) DSChainEntity *chainEntity;
@property (nonatomic, readonly) uint32_t magicNumber;
@property (nonatomic, readonly) NSString * chainWalletsKey;
@property (nonatomic, readonly) uint64_t baseReward;
@property (nonatomic, readonly) BOOL canConstructAFilter;
@property (nonatomic, readonly) BOOL hasAWallet;
@property (nonatomic, readonly) BOOL hasAStandaloneDerivationPath;
@property (nonatomic, readonly) BOOL syncsBlockchain;
@property (nonatomic, readonly,nullable) NSString * devnetIdentifier;
@property (nonatomic, assign) uint64_t feePerByte;
@property (nonatomic, readonly) NSTimeInterval earliestWalletCreationTime;
@property (nonatomic, readonly,nullable) NSString * registeredPeersKey;
@property (nonatomic, readonly) NSArray<DSCheckpoint*> * checkpoints;
@property (nonatomic, assign) uint32_t minProtocolVersion;
@property (nonatomic, assign) uint32_t protocolVersion;
@property (nonatomic, readonly) uint32_t maxProofOfWork;
@property (nonatomic, strong, nullable) NSString * sporkPublicKey;
@property (nonatomic, strong, nullable) NSString * sporkPrivateKey;
@property (nonatomic, strong, nullable) NSString * sporkAddress;
@property (nonatomic, readonly) uint16_t transactionVersion;
@property (nonatomic, assign) uint32_t totalGovernanceObjectsCount;
@property (nonatomic, assign) uint32_t totalMasternodeCount;
@property (nonatomic, readonly) uint32_t blockchainUsersCount;

// outputs below this amount are uneconomical due to fees
@property (nonatomic, readonly) uint64_t minOutputAmount;

// all wallet transactions sorted by date, most recent first
@property (nonatomic, readonly) NSArray * allTransactions;

// current wallet balance excluding transactions known to be invalid
@property (nonatomic, readonly) uint64_t balance;

@property (nonatomic, assign) uint32_t bestBlockHeight;

+(DSChain*)mainnet;
+(DSChain*)testnet;

+(DSChain* _Nullable)devnetWithIdentifier:(NSString*)identifier;
+(DSChain*)setUpDevnetWithIdentifier:(NSString*)identifier withCheckpoints:(NSArray<DSCheckpoint*>* _Nullable)checkpointArray withDefaultPort:(uint32_t)port withDefaultDapiPort:(uint32_t)dapiPort;

+(DSChain* _Nullable)chainForNetworkName:(NSString* _Nullable)networkName;


-(BOOL)isMainnet;
-(BOOL)isTestnet;
-(BOOL)isDevnetAny;
-(BOOL)isDevnetWithGenesisHash:(UInt256)genesisHash;

-(void)save;

-(void)setEstimatedBlockHeight:(uint32_t)estimatedBlockHeight fromPeer:(DSPeer*)peer;
-(BOOL)addBlock:(DSMerkleBlock *)block fromPeer:(DSPeer*)peer;
-(void)saveBlocks;
-(void)wipeWalletsAndDerivatives;
-(void)clearOrphans;
-(void)setLastBlockHeightForRescan;
-(void)setBlockHeight:(int32_t)height andTimestamp:(NSTimeInterval)timestamp forTxHashes:(NSArray *)txHashes;
-(NSTimeInterval)timestampForBlockHeight:(uint32_t)blockHeight; // seconds since 1970, 00:00:00 01/01/01 GMT

-(void)unregisterWallet:(DSWallet*)wallet;
-(void)addWallet:(DSWallet*)wallet;
-(void)registerWallet:(DSWallet*)wallet;

-(void)unregisterStandaloneDerivationPath:(DSDerivationPath*)derivationPath;
-(void)addStandaloneDerivationPath:(DSDerivationPath*)derivationPath;
-(void)registerStandaloneDerivationPath:(DSDerivationPath*)derivationPath;

-(void)registerVotingKey:(NSData*)votingKey forMasternodeEntry:(DSSimplifiedMasternodeEntry*)masternodeEntry;

// returns the transaction with the given hash if it's been registered in any wallet on the chain (might also return non-registered)
- (DSTransaction * _Nullable)transactionForHash:(UInt256)txHash;

// returns an account to which the given transaction is associated with (even if it hasn't been registered), no account if the transaction is not associated with the wallet
- (DSAccount* _Nullable)accountContainingTransaction:(DSTransaction *)transaction;

// returns an account to which the given transaction hash is associated with, no account if the transaction hash is not associated with the wallet
- (DSAccount * _Nullable)accountForTransactionHash:(UInt256)txHash transaction:(DSTransaction * _Nullable * _Nullable)transaction wallet:(DSWallet * _Nullable * _Nullable)wallet;


-(NSArray<DSDerivationPath*>*)standardDerivationPathsForAccountNumber:(uint32_t)accountNumber;

// fee that will be added for a transaction of the given size in bytes
- (uint64_t)feeForTxSize:(NSUInteger)size isInstant:(BOOL)isInstant inputCount:(NSInteger)inputCount;

-(NSData* _Nullable)votingKeyForMasternode:(DSSimplifiedMasternodeEntry*)masternodeEntry;

-(NSArray*)registeredMasternodes;

//This removes all blockchain information from the chain's wallets and derivation paths
- (void)wipeBlockchainInfo;


@end

@protocol DSChainDelegate

-(void)chain:(DSChain*)chain didSetBlockHeight:(int32_t)height andTimestamp:(NSTimeInterval)timestamp forTxHashes:(NSArray *)txHashes updatedTx:(NSArray *)updatedTx;
-(void)chainWasWiped:(DSChain*)chain;
-(void)chainFinishedSyncing:(DSChain*)chain fromPeer:(DSPeer*)peer onMainChain:(BOOL)onMainChain;
-(void)chain:(DSChain*)chain receivedOrphanBlock:(DSMerkleBlock*)merkleBlock fromPeer:(DSPeer*)peer;
-(void)chain:(DSChain*)chain badBlockReceivedFromPeer:(DSPeer*)peer;

@end

NS_ASSUME_NONNULL_END
