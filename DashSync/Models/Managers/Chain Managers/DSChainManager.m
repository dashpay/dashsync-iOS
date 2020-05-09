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
#import "DSChain+Protected.h"
#import "DSSporkManager+Protected.h"
#import "DSOptionsManager.h"
#import "DSMasternodeManager+Protected.h"
#import "DSGovernanceSyncManager+Protected.h"
#import "DSTransactionManager+Protected.h"
#import "DSIdentitiesManager.h"
#import "DSBloomFilter.h"
#import "DSMerkleBlock.h"
#import "DSWallet.h"
#import "DSDerivationPath.h"
#import "NSString+Bitcoin.h"
#import "NSDate+Utils.h"
#import "DashSync.h"
#import "DSChainEntity+CoreDataClass.h"

#define SYNC_STARTHEIGHT_KEY @"SYNC_STARTHEIGHT"

@interface DSChainManager ()

@property (nonatomic, strong) DSChain * chain;
@property (nonatomic, strong) DSSporkManager * sporkManager;
@property (nonatomic, strong) DSMasternodeManager * masternodeManager;
@property (nonatomic, strong) DSGovernanceSyncManager * governanceSyncManager;
@property (nonatomic, strong) DSIdentitiesManager * identitiesManager;
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
    self.DAPIClient = [[DSDAPIClient alloc] initWithChain:chain]; //this must be
    [self.masternodeManager setUp];
    self.governanceSyncManager = [[DSGovernanceSyncManager alloc] initWithChain:chain];
    self.transactionManager = [[DSTransactionManager alloc] initWithChain:chain];
    self.peerManager = [[DSPeerManager alloc] initWithChain:chain];
    self.identitiesManager = [[DSIdentitiesManager alloc] initWithChain:chain];
    
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

- (void)startSync {
    if ([self.identitiesManager unsyncedBlockchainIdentities].count) {
        [self.identitiesManager syncBlockchainIdentitiesWithCompletion:^(BOOL success, NSArray<DSBlockchainIdentity *> * _Nullable blockchainIdentities, NSArray<NSError *> * _Nonnull errors) {
            if (success) {
                [self.peerManager connect];
            } else {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self startSync];
                });
            }
        }];
    } else {
        [self.peerManager connect];
    }
    
}

- (void)stopSync {
    
    [self.peerManager disconnect];
}

-(void)disconnectedRescan {
    NSManagedObjectContext * chainContext = [NSManagedObjectContext chainContext];
    DSChainEntity * chainEntity = [self.chain chainEntityInContext:chainContext];
    [chainEntity.managedObjectContext performBlockAndWait:^{
        [self.chain wipeMasternodesInContext:chainEntity.managedObjectContext];//masternodes and quorums must go first
        [DSMerkleBlockEntity deleteBlocksOnChainEntity:chainEntity];
        [DSTransactionHashEntity deleteTransactionHashesOnChainEntity:chainEntity];
        [self.masternodeManager wipeMasternodeInfo];
        [self.chain wipeBlockchainInfoInContext:chainContext];
        [chainContext ds_save];
    }];
    
    NSManagedObjectContext * peerContext =  [NSManagedObjectContext peerContext];
    DSChainEntity * chainEntityInPeerContext = [self.chain chainEntityInContext:peerContext];
    
    if (![self.chain isMainnet]) {
        [self.chain.chainManager.peerManager removeTrustedPeerHost];
        [self.chain.chainManager.peerManager clearPeers];
        [DSPeerEntity deletePeersForChainEntity:chainEntityInPeerContext];
        [peerContext ds_save];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DSWalletBalanceDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self}];
        [[NSNotificationCenter defaultCenter] postNotificationName:DSChainBlocksDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self}];
        [[NSNotificationCenter defaultCenter] postNotificationName:DSMasternodeListDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self}];
        [[NSNotificationCenter defaultCenter] postNotificationName:DSQuorumListDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self}];
        
    });
    
    self.syncStartHeight = self.chain.lastBlockHeight;
    [[NSUserDefaults standardUserDefaults] setInteger:self.syncStartHeight forKey:self.syncStartHeightKey];
    [self.peerManager connect];
}

-(void)disconnectedRescanOfMasternodeListsAndQuorums {
    NSManagedObjectContext * chainContext = [NSManagedObjectContext chainContext];
    DSChainEntity * chainEntity = [self.chain chainEntityInContext:chainContext];
    [chainEntity.managedObjectContext performBlockAndWait:^{
        [self.chain wipeMasternodesInContext:chainEntity.managedObjectContext];//masternodes and quorums must go first
        [self.masternodeManager wipeMasternodeInfo];
        [chainContext ds_save];
    }];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DSMasternodeListDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self}];
        [[NSNotificationCenter defaultCenter] postNotificationName:DSQuorumListDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self}];
        
    });
    [self.peerManager connect];
}

// rescans blocks and transactions after earliestKeyTime, a new random download peer is also selected due to the
// possibility that a malicious node might lie by omitting transactions that match the bloom filter
- (void)rescan
{
    if (!self.peerManager.connected) {
        [self disconnectedRescan];
    } else {
        [self.peerManager disconnectDownloadPeerForError:nil withCompletion:^(BOOL success) {
            [self disconnectedRescan];
        }];
    }
}

- (void)rescanMasternodeListsAndQuorums
{
    if (!self.peerManager.connected) {
        [self disconnectedRescanOfMasternodeListsAndQuorums];
    } else {
        [self.peerManager disconnectDownloadPeerForError:nil withCompletion:^(BOOL success) {
            [self disconnectedRescanOfMasternodeListsAndQuorums];
        }];
    }
}


// MARK: - DSChainDelegate

-(void)chain:(DSChain*)chain didSetBlockHeight:(int32_t)height andTimestamp:(NSTimeInterval)timestamp forTransactionHashes:(NSArray *)txHashes updatedTransactions:(NSArray *)updatedTransactions {
    [self.transactionManager chain:chain didSetBlockHeight:height andTimestamp:timestamp forTransactionHashes:txHashes updatedTransactions:updatedTransactions];
}

-(void)chain:(DSChain*)chain didFinishFetchingBlockchainIdentityDAPInformation:(DSBlockchainIdentity*)blockchainIdentity {
    [self.peerManager resumeBlockchainSynchronizationOnPeers];
}

-(void)chainWasWiped:(DSChain*)chain {
    [self.transactionManager chainWasWiped:chain];
}

-(void)chainWillStartSyncingBlockchain:(DSChain*)chain {
    [self.sporkManager getSporks]; //get the sporks early on
}

-(void)chainShouldStartSyncingBlockchain:(DSChain*)chain onPeer:(DSPeer*)peer {
    dispatch_async(self.chain.networkingQueue, ^{
        if (self.chain.shouldSyncHeadersFirstForMasternodeListVerification) {
        //masternode list should be synced first and the masternode list is old
            [peer sendGetheadersMessageWithLocators:[self.chain headerLocatorArrayForMasternodeSync] andHashStop:UINT256_ZERO];
        } else {
            BOOL startingDevnetSync = [self.chain isDevnetAny] && self.chain.lastBlock.height < 5;
            if (startingDevnetSync || self.chain.lastBlock.timestamp + (2*HOUR_TIME_INTERVAL + WEEK_TIME_INTERVAL)/4 >= self.chain.earliestWalletCreationTime) {
                [peer sendGetblocksMessageWithLocators:[self.chain blockLocatorArray] andHashStop:UINT256_ZERO];
            }
            else {
                [peer sendGetheadersMessageWithLocators:[self.chain blockLocatorArray] andHashStop:UINT256_ZERO];
            }
        }
    });
}

-(void)chainFinishedSyncingInitialHeaders:(DSChain*)chain fromPeer:(DSPeer*)peer onMainChain:(BOOL)onMainChain {
    if (onMainChain && peer && (peer == self.peerManager.downloadPeer)) self.lastChainRelayTime = [NSDate timeIntervalSince1970];
    [self.peerManager chainSyncStopped];
    if (([[DSOptionsManager sharedInstance] syncType] & DSSyncType_MasternodeList)) {
        // make sure we care about masternode lists
        [self.masternodeManager getRecentMasternodeList:32 withSafetyDelay:0];
        [self.masternodeManager getCurrentMasternodeListWithSafetyDelay:0];
    }
}

-(void)chainFinishedSyncingTransactionsAndBlocks:(DSChain*)chain fromPeer:(DSPeer*)peer onMainChain:(BOOL)onMainChain {
    if (onMainChain && peer && (peer == self.peerManager.downloadPeer)) self.lastChainRelayTime = [NSDate timeIntervalSince1970];
    DSDLog(@"chain finished syncing");
    self.syncStartHeight = 0;
    [self.transactionManager fetchMempoolFromNetwork];
    [self.sporkManager getSporks];
    [self.governanceSyncManager startGovernanceSync];
    if (([[DSOptionsManager sharedInstance] syncType] & DSSyncType_MasternodeList)) {
        // make sure we care about masternode lists
        [self.masternodeManager getRecentMasternodeList:32 withSafetyDelay:0];
        [self.masternodeManager getCurrentMasternodeListWithSafetyDelay:0];
    }
}

-(void)chainFinishedSyncingMasternodeListsAndQuorums:(DSChain*)chain {
    
    if (([[DSOptionsManager sharedInstance] syncType] & DSSyncType_MasternodeListFirst)) {
        if (self.peerManager.connectedPeerCount == 0) {
            [self.peerManager connect];
        } else {
            [self chainShouldStartSyncingBlockchain:chain onPeer:self.peerManager.downloadPeer];
        }
    } else {
        if ([self.chain isEvolutionEnabled]) {
            if (([[DSOptionsManager sharedInstance] syncType] & DSSyncType_BlockchainIdentities)) {
                //this only needs to happen once per session
                static dispatch_once_t onceToken;
                dispatch_once(&onceToken, ^{
                    [self.identitiesManager retrieveAllBlockchainIdentitiesChainStates];
                });
            }
        }
    }
}

-(void)chain:(DSChain*)chain badBlockReceivedFromPeer:(DSPeer*)peer {
    DSDLog(@"peer at address %@ is misbehaving",peer.host);
    [self.peerManager peerMisbehaving:peer errorMessage:@"Bad block received from peer"];
}

-(void)chain:(DSChain*)chain receivedOrphanBlock:(DSMerkleBlock*)block fromPeer:(DSPeer*)peer {
    // ignore orphans older than one week ago
    if (block.timestamp < [NSDate timeIntervalSince1970] - WEEK_TIME_INTERVAL) return;
    
    // call getblocks, unless we already did with the previous block, or we're still downloading the chain
    if (self.chain.lastBlockHeight >= peer.lastBlockHeight && ! uint256_eq(self.chain.lastOrphan.blockHash, block.prevBlock)) {
        DSDLog(@"%@:%d calling getblocks", peer.host, peer.port);
        [peer sendGetblocksMessageWithLocators:[self.chain blockLocatorArray] andHashStop:UINT256_ZERO];
    }
}

-(void)chain:(DSChain*)chain wasExtendedWithBlock:(DSMerkleBlock*)merkleBlock fromPeer:(DSPeer*)peer {
    if (([[DSOptionsManager sharedInstance] syncType] & DSSyncType_MasternodeList)) {
        // make sure we care about masternode lists
        [self.masternodeManager getCurrentMasternodeListWithSafetyDelay:3];
    }
    
}



// MARK: - Count Info

-(void)resetSyncCountInfo:(DSSyncCountInfo)syncCountInfo {
    [self setCount:0 forSyncCountInfo:syncCountInfo];
}

-(void)setCount:(uint32_t)count forSyncCountInfo:(DSSyncCountInfo)syncCountInfo {
    switch (syncCountInfo) {
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
            //deprecated
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
