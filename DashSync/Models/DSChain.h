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
#import "IntTypes.h"

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
#define DEVNET_STANDARD_PORT 19999


#define DASH_MAGIC_NUMBER_TESTNET 0xffcae2ce
#define DASH_MAGIC_NUMBER_MAINNET 0xbd6b0cbf


#define DEFAULT_FEE_PER_KB ((5000ULL*100 + 99)/100) // bitcoind 0.11 min relay fee on 100bytes
#define MIN_FEE_PER_KB     ((TX_FEE_PER_KB*1000 + 190)/191) // minimum relay fee on a 191byte tx
#define MAX_FEE_PER_KB     ((100100ULL*1000 + 190)/191) // slightly higher than a 1000bit fee on a 191byte tx

typedef NS_ENUM(uint16_t, DSChainType) {
    DSChainType_MainNet,
    DSChainType_TestNet,
    DSChainType_DevNet,
};

@class DSWallet,DSMerkleBlock,DSChainPeerManager,DSPeer,DSChainEntity,DSDerivationPath,DSTransaction,DSAccount;

@protocol DSChainDelegate;

@interface DSCheckpoint : NSObject <NSCoding>

@property (nonatomic, assign) uint32_t height;
@property (nonatomic, assign) UInt256 checkpointHash;
@property (nonatomic, assign) uint32_t timestamp;
@property (nonatomic, assign) uint32_t target;

@end

@interface DSChain : NSObject

@property (nonatomic, readonly) NSArray<DSWallet *> * _Nullable wallets;
@property (nonatomic, assign) DSChainType chainType;
@property (nonatomic, assign) uint32_t standardPort;
@property (nonatomic, assign) UInt256 genesisHash;
@property (nonatomic, readonly) NSString * _Nullable chainTip;
@property (nonatomic, readonly) uint32_t lastBlockHeight;
@property (nonatomic, readonly) uint32_t estimatedBlockHeight; // last block height reported by current download peer
@property (nonatomic, readonly) NSString * networkName;
@property (nonatomic, readonly) NSString * uniqueID;
@property (nonatomic, readonly,getter=isActive) BOOL active;
@property (nonatomic, weak) DSChainPeerManager * peerManagerDelegate;
@property (nonatomic, readonly) NSTimeInterval earliestKeyTime;
@property (nonatomic, readonly) DSMerkleBlock * lastBlock;
@property (nonatomic, readonly) NSArray * blockLocatorArray;
@property (nonatomic, readonly) DSMerkleBlock *lastOrphan;
@property (nonatomic, readonly) DSChainEntity *chainEntity;
@property (nonatomic, readonly) uint32_t magicNumber;
@property (nonatomic, readonly) NSString * chainWalletsKey;
@property (nonatomic, readonly) BOOL hasAWallet;
@property (nonatomic, assign) uint64_t feePerKb;

// outputs below this amount are uneconomical due to fees
@property (nonatomic, readonly) uint64_t minOutputAmount;

// all wallet transactions sorted by date, most recent first
@property (nonatomic, readonly) NSArray * _Nonnull allTransactions;

// current wallet balance excluding transactions known to be invalid
@property (nonatomic, readonly) uint64_t balance;

+(DSChain*)mainnet;
+(DSChain*)testnet;

+(DSChain*)devnetWithGenesisHash:(UInt256)genesisHash;
+(DSChain*)createDevnetWithCheckpoints:(NSArray*)checkpointArray onPort:(uint32_t)port;

+(DSChain*)chainForNetworkName:(NSString*)networkName;


-(BOOL)isMainnet;
-(BOOL)isTestnet;
-(BOOL)isDevnetAny;
-(BOOL)isDevnetWithGenesisHash:(UInt256)genesisHash;

-(void)setEstimatedBlockHeight:(uint32_t)estimatedBlockHeight fromPeer:(DSPeer*)peer;
-(BOOL)addBlock:(DSMerkleBlock *)block fromPeer:(DSPeer*)peer;
-(void)saveBlocks;
-(void)wipeChain;
-(void)clearOrphans;
-(void)setLastBlockHeightForRescan;
-(void)setBlockHeight:(int32_t)height andTimestamp:(NSTimeInterval)timestamp forTxHashes:(NSArray *)txHashes;
-(NSTimeInterval)timestampForBlockHeight:(uint32_t)blockHeight; // seconds since reference date, 00:00:00 01/01/01 GMT

-(void)removeWallet:(DSWallet*)wallet;
-(void)addWallet:(DSWallet*)objects;



// returns the transaction with the given hash if it's been registered in any wallet on the chain (might also return non-registered)
- (DSTransaction * _Nullable)transactionForHash:(UInt256)txHash;

// returns an account to which the given transaction is associated with (even if it hasn't been registered), no account if the transaction is not associated with the wallet
- (DSAccount* _Nullable)accountContainingTransaction:(DSTransaction * _Nonnull)transaction;

// returns an account to which the given transaction hash is associated with, no account if the transaction hash is not associated with the wallet
- (DSAccount * _Nullable)accountForTransactionHash:(UInt256)txHash transaction:(DSTransaction **)transaction wallet:(DSWallet **)wallet;


-(NSArray<DSDerivationPath*>*)standardDerivationPathsForAccountNumber:(uint32_t)accountNumber;

// fee that will be added for a transaction of the given size in bytes
- (uint64_t)feeForTxSize:(NSUInteger)size isInstant:(BOOL)isInstant inputCount:(NSInteger)inputCount;


@end

@protocol DSChainDelegate

-(void)chain:(DSChain*)chain didSetBlockHeight:(int32_t)height andTimestamp:(NSTimeInterval)timestamp forTxHashes:(NSArray *)txHashes updatedTx:(NSArray *)updatedTx;
-(void)chainWasWiped:(DSChain*)chain;
-(void)chainFinishedSyncing:(DSChain*)chain fromPeer:(DSPeer*)peer onMainChain:(BOOL)onMainChain;
-(void)chain:(DSChain*)chain receivedOrphanBlock:(DSMerkleBlock*)merkleBlock fromPeer:(DSPeer*)peer;
-(void)chain:(DSChain*)chain badBlockReceivedFromPeer:(DSPeer*)peer;

@end
