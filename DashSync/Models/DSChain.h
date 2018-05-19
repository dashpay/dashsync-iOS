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

#define MAINNET_STANDARD_PORT 9999
#define TESTNET_STANDARD_PORT 19999
#define DEVNET_STANDARD_PORT 19999

typedef NS_ENUM(NSUInteger, DSChainType) {
    DSChainType_MainNet,
    DSChainType_TestNet,
    DSChainType_DevNet,
};

@class DSWallet,DSMerkleBlock,DSChainPeerManager,DSPeer,DSChainEntity;

@protocol DSChainDelegate;

@interface DSCheckpoint : NSObject <NSCoding>

@property (nonatomic, assign) uint32_t height;
@property (nonatomic, assign) UInt256 checkpointHash;
@property (nonatomic, assign) uint32_t timestamp;
@property (nonatomic, assign) uint32_t target;

@end

@interface DSChain : NSObject
@property (nonatomic, readonly) BOOL hasWalletSet;
@property (nonatomic, readonly) DSWallet * _Nullable wallet;
@property (nonatomic, assign) DSChainType chainType;
@property (nonatomic, assign) uint32_t standardPort;
@property (nonatomic, assign) UInt256 genesisHash;
@property (nonatomic, readonly) NSString * _Nullable chainTip;
@property (nonatomic, readonly) uint32_t lastBlockHeight;
@property (nonatomic, readonly) uint32_t estimatedBlockHeight; // last block height reported by current download peer
@property (nonatomic, copy) NSString * networkName;
@property (nonatomic, readonly,getter=isActive) BOOL active;
@property (nonatomic, weak) DSChainPeerManager * peerManagerDelegate;
@property (nonatomic, readonly) NSTimeInterval earliestKeyTime;
@property (nonatomic, readonly) DSMerkleBlock * lastBlock;
@property (nonatomic, readonly) NSArray * blockLocatorArray;
@property (nonatomic, readonly) DSMerkleBlock *lastOrphan;
@property (nonatomic, readonly) DSChainEntity *chainEntity;

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

-(void)removeWallet;

@end

@protocol DSChainDelegate

-(void)chain:(DSChain*)chain didSetBlockHeight:(int32_t)height andTimestamp:(NSTimeInterval)timestamp forTxHashes:(NSArray *)txHashes updatedTx:(NSArray *)updatedTx;
-(void)chainWasWiped:(DSChain*)chain;
-(void)chainFinishedSyncing:(DSChain*)chain fromPeer:(DSPeer*)peer onMainChain:(BOOL)onMainChain;
-(void)chain:(DSChain*)chain receivedOrphanBlock:(DSMerkleBlock*)merkleBlock fromPeer:(DSPeer*)peer;
-(void)chain:(DSChain*)chain badBlockReceivedFromPeer:(DSPeer*)peer;

@end
