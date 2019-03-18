//
//  DSChainManager.m
//  DashSync
//
//  Created by Sam Westrich on 11/21/18.
//  Copyright (c) 2018 Dash Core Group <contact@dash.org>
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

#import "DSChainManager.h"
#import "DSPeerManager+Protected.h"
#import "DSEventManager.h"
#import "DSChain.h"
#import "DSSporkManager.h"
#import "DSOptionsManager.h"
#import "DSMasternodeManager+Protected.h"
#import "DSGovernanceSyncManager+Protected.h"
#import "DSTransactionManager+Protected.h"
#import "DSBloomFilter.h"
#import "DSMerkleBlock.h"
#import "DSWallet.h"
#import "DSDerivationPath.h"
#import "NSString+Bitcoin.h"
#import "NSDate+Utils.h"
#import "DashSync.h"

#define SYNC_STARTHEIGHT_KEY @"SYNC_STARTHEIGHT"

@interface DSChainManager ()

@property (nonatomic, strong) DSChain * chain;
@property (nonatomic, strong) DSSporkManager * sporkManager;
@property (nonatomic, strong) DSMasternodeManager * masternodeManager;
@property (nonatomic, strong) DSGovernanceSyncManager * governanceSyncManager;
@property (nonatomic, strong) DSDAPIClient * DAPIClient;
@property (nonatomic, strong) DSTransactionManager * transactionManager;
@property (nonatomic, strong) DSPeerManager * peerManager;
@property (nonatomic, assign) uint32_t syncStartHeight;
@property (nonatomic, assign) NSTimeInterval lastChainRelayTime;

@end

@implementation DSChainManager

- (instancetype)initWithChain:(DSChain*)chain
{
    if (! (self = [super init])) return nil;
    
    self.chain = chain;
    chain.chainManager = self;
    self.sporkManager = [[DSSporkManager alloc] initWithChain:chain];
    self.masternodeManager = [[DSMasternodeManager alloc] initWithChain:chain];
    [self.masternodeManager setUp];
    self.governanceSyncManager = [[DSGovernanceSyncManager alloc] initWithChain:chain];
    self.transactionManager = [[DSTransactionManager alloc] initWithChain:chain];
    self.peerManager = [[DSPeerManager alloc] initWithChain:chain];
    
    // TODO: node should be randomly selected on every DAPI call
    // (using devnet-maithai for now)
    NSURL *dapiNodeURL = [NSURL URLWithString:@"http://54.187.113.35:3000"];
    HTTPLoaderFactory *loaderFactory = [DSNetworkingCoordinator sharedInstance].loaderFactory;
    self.DAPIClient = [[DSDAPIClient alloc] initWithDAPINodeURL:dapiNodeURL httpLoaderFactory:loaderFactory];
    
    return self;
}

// MARK: - Info

-(NSString*)syncStartHeightKey {
    return [NSString stringWithFormat:@"%@_%@",SYNC_STARTHEIGHT_KEY,[self.chain uniqueID]];
}

- (double)syncProgress
{
    if (! self.peerManager.downloadPeer && self.syncStartHeight == 0) return 0.0;
    //if (self.downloadPeer.status != DSPeerStatus_Connected) return 0.05;
    if (self.chain.lastBlockHeight >= self.chain.estimatedBlockHeight) return 1.0;
    
    double lastBlockHeight = self.chain.lastBlockHeight;
    double estimatedBlockHeight = self.chain.estimatedBlockHeight;
    double syncStartHeight = self.syncStartHeight;
    double progress;
    if (syncStartHeight > lastBlockHeight) {
        progress = lastBlockHeight / estimatedBlockHeight;
    }
    else {
        progress = (lastBlockHeight - syncStartHeight) / (estimatedBlockHeight - syncStartHeight);
    }
    return MIN(1.0, MAX(0.0, 0.1 + 0.9 * progress));
}

-(void)resetSyncStartHeight {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    if (self.syncStartHeight == 0) self.syncStartHeight = (uint32_t)[userDefaults integerForKey:self.syncStartHeightKey];
    
    if (self.syncStartHeight == 0) {
        self.syncStartHeight = self.chain.lastBlockHeight;
        [[NSUserDefaults standardUserDefaults] setInteger:self.syncStartHeight forKey:self.syncStartHeightKey];
    }
}

-(void)restartSyncStartHeight {
    self.syncStartHeight = 0;
    [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:self.syncStartHeightKey];
}

- (void)relayedNewItem {
    self.lastChainRelayTime = [NSDate timeIntervalSince1970];
}

-(void)resetLastRelayedItemTime {
    self.lastChainRelayTime = 0;
}

// MARK: - Blockchain Sync

-(void)disconnectedRescan {
    
    DSChainEntity * chainEntity = self.chain.chainEntity;
    [DSMerkleBlockEntity deleteBlocksOnChain:chainEntity];
    [DSTransactionHashEntity deleteTransactionHashesOnChain:chainEntity];
    [self.chain wipeBlockchainInfo];
    [DSTransactionEntity saveContext];
    
    if (![self.chain isMainnet]) {
        [self.chain.chainManager.peerManager removeTrustedPeerHost];
        [self.chain.chainManager.peerManager clearPeers];
        [DSPeerEntity deletePeersForChain:chainEntity];
        [DSPeerEntity saveContext];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DSWalletBalanceDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:DSChainBlocksDidChangeNotification object:nil];
    });
    
    self.syncStartHeight = self.chain.lastBlockHeight;
    [[NSUserDefaults standardUserDefaults] setInteger:self.syncStartHeight forKey:self.syncStartHeightKey];
    [self.peerManager connect];
}

// rescans blocks and transactions after earliestKeyTime, a new random download peer is also selected due to the
// possibility that a malicious node might lie by omitting transactions that match the bloom filter
- (void)rescan
{
    if (!self.peerManager.connected) {
        [self disconnectedRescan];
    } else {
        [self.peerManager disconnectDownloadPeerWithCompletion:^(BOOL success) {
            [self disconnectedRescan];
        }];
    }
}

// MARK: - DSChainDelegate

-(void)chain:(DSChain*)chain didSetBlockHeight:(int32_t)height andTimestamp:(NSTimeInterval)timestamp forTxHashes:(NSArray *)txHashes updatedTx:(NSArray *)updatedTx {
    [self.transactionManager chain:chain didSetBlockHeight:height andTimestamp:timestamp forTxHashes:txHashes updatedTx:updatedTx];
}

-(void)chainWasWiped:(DSChain*)chain {
    [self.transactionManager chainWasWiped:chain];
}

-(void)chainWillStartSyncingBlockchain:(DSChain*)chain {
    [self.sporkManager getSporks]; //get the sporks early on
}

-(void)chainFinishedSyncingTransactionsAndBlocks:(DSChain*)chain fromPeer:(DSPeer*)peer onMainChain:(BOOL)onMainChain {
    if (onMainChain && peer && (peer == self.peerManager.downloadPeer)) self.lastChainRelayTime = [NSDate timeIntervalSince1970];
    DSDLog(@"chain finished syncing");
    self.syncStartHeight = 0;
    [self.transactionManager fetchMempoolFromNetwork];
    [self.sporkManager getSporks];
    [self.governanceSyncManager startGovernanceSync];
    [self.masternodeManager getMasternodeList];
}

-(void)chain:(DSChain*)chain badBlockReceivedFromPeer:(DSPeer*)peer {
    DSDLog(@"peer at address %@ is misbehaving",peer.host);
    [self.peerManager peerMisbehaving:peer];
}

-(void)chain:(DSChain*)chain receivedOrphanBlock:(DSMerkleBlock*)block fromPeer:(DSPeer*)peer {
    // ignore orphans older than one week ago
    if (block.timestamp < [NSDate timeIntervalSince1970] - WEEK_TIME_INTERVAL) return;
    
    // call getblocks, unless we already did with the previous block, or we're still downloading the chain
    if (self.chain.lastBlockHeight >= peer.lastblock && ! uint256_eq(self.chain.lastOrphan.blockHash, block.prevBlock)) {
        DSDLog(@"%@:%d calling getblocks", peer.host, peer.port);
        [peer sendGetblocksMessageWithLocators:[self.chain blockLocatorArray] andHashStop:UINT256_ZERO];
    }
}

-(void)chain:(DSChain*)chain wasExtendedWithBlock:(DSMerkleBlock*)merkleBlock fromPeer:(DSPeer*)peer {
    [self.masternodeManager getMasternodeList];
}

// MARK: - Count Info

-(void)resetSyncCountInfo:(DSSyncCountInfo)syncCountInfo {
    [self setCount:0 forSyncCountInfo:syncCountInfo];
}

-(void)setCount:(uint32_t)count forSyncCountInfo:(DSSyncCountInfo)syncCountInfo {
    //    if (syncCountInfo ==  DSSyncCountInfo_List || syncCountInfo == DSSyncCountInfo_GovernanceObject) {
    //        NSString * storageKey = [NSString stringWithFormat:@"%@_%@_%d",self.chain.uniqueID,SYNC_COUNT_INFO,syncCountInfo];
    //        [[NSUserDefaults standardUserDefaults] setInteger:count forKey:storageKey];
    //        [self.syncCountInfo setObject:@(count) forKey:@(syncCountInfo)];
    //    }
    switch (syncCountInfo) {
        case DSSyncCountInfo_List:
            self.chain.totalMasternodeCount = count;
            [self.chain save];
            break;
        case DSSyncCountInfo_GovernanceObject:
            self.chain.totalGovernanceObjectsCount = count;
            [self.chain save];
            break;
        case DSSyncCountInfo_GovernanceObjectVote:
            self.governanceSyncManager.currentGovernanceSyncObject.totalGovernanceVoteCount = count;
            [self.governanceSyncManager.currentGovernanceSyncObject save];
            break;
        default:
            break;
    }
}

// MARK: - DSPeerChainDelegate

- (void)peer:(DSPeer *)peer relayedSyncInfo:(DSSyncCountInfo)syncCountInfo count:(uint32_t)count {
    [self setCount:count forSyncCountInfo:syncCountInfo];
    switch (syncCountInfo) {
        case DSSyncCountInfo_List:
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:DSMasternodeListCountUpdateNotification object:nil userInfo:@{@(syncCountInfo):@(count),DSChainManagerNotificationChainKey:self.chain}];
            });
            break;
        }
        case DSSyncCountInfo_GovernanceObject:
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:DSGovernanceObjectCountUpdateNotification object:nil userInfo:@{@(syncCountInfo):@(count),DSChainManagerNotificationChainKey:self.chain}];
            });
            break;
        }
        case DSSyncCountInfo_GovernanceObjectVote:
        {
            if (peer.governanceRequestState == DSGovernanceRequestState_GovernanceObjectVoteHashesReceived) {
                if (count == 0) {
                    //there were no votes
                    DSDLog(@"no votes on object, going to next object");
                    peer.governanceRequestState = DSGovernanceRequestState_GovernanceObjectVotes;
                    [self.governanceSyncManager finishedGovernanceVoteSyncWithPeer:peer];
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[NSNotificationCenter defaultCenter] postNotificationName:DSGovernanceVoteCountUpdateNotification object:nil userInfo:@{@(syncCountInfo):@(count),DSChainManagerNotificationChainKey:self.chain}];
                    });
                }
            }
            
            break;
        }
        default:
            break;
    }
}

@end
