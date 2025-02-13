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

#import "DSBloomFilter.h"
#import "DSChain+Params.h"
#import "DSChain+Protected.h"
#import "DSChain+Wallet.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSChainManager+Mining.h"
#import "DSChainManager+Protected.h"
#import "DSChainManager+Transactions.h"
#import "DSCheckpoint.h"
#import "DSDerivationPath.h"
#import "DSEventManager.h"
#import "DSFullBlock.h"
#import "DSGovernanceSyncManager+Protected.h"
#import "DSIdentitiesManager.h"
#import "DSMasternodeManager+LocalMasternode.h"
#import "DSMasternodeManager+Protected.h"
#import "DSMerkleBlock.h"
#import "DSOptionsManager.h"
#import "DSPeerManager+Protected.h"
#import "DSSporkManager+Protected.h"
#import "DSTransactionManager+Protected.h"
#import "DSWallet+Protected.h"
#import "DSWallet.h"
#import "DashSync.h"
#import "NSDate+Utils.h"
#import "NSError+Dash.h"
#import "NSString+Bitcoin.h"
#import "NSObject+Notification.h"
#import "RHIntervalTree.h"

#define SYNC_STARTHEIGHT_KEY @"SYNC_STARTHEIGHT"
#define TERMINAL_SYNC_STARTHEIGHT_KEY @"TERMINAL_SYNC_STARTHEIGHT"

@interface DSChainManager ()

@property (nonatomic, strong) DSChain *chain;
@property (nonatomic, strong) DSBackgroundManager *backgroundManager;
@property (nonatomic, strong) DSSporkManager *sporkManager;
@property (nonatomic, strong) DSMasternodeManager *masternodeManager;
@property (nonatomic, strong) DSKeyManager *keyManager;
@property (nonatomic, strong) DSGovernanceSyncManager *governanceSyncManager;
@property (nonatomic, strong) DSIdentitiesManager *identitiesManager;
@property (nonatomic, strong) DSTransactionManager *transactionManager;
@property (nonatomic, strong) DSPeerManager *peerManager;
@property (nonatomic, assign) uint64_t sessionConnectivityNonce;
@property (nonatomic, assign) BOOL gotSporksAtChainSyncStart;

@property (nonatomic, strong) DSSyncState *syncState;
@property (nonatomic, assign) NSTimeInterval lastNotifiedBlockDidChange;
@property (nonatomic, strong) NSTimer *lastNotifiedBlockDidChangeTimer;


@end

@implementation DSChainManager

- (instancetype)initWithChain:(DSChain *)chain {
    if (!(self = [super init])) return nil;

    self.chain = chain;
    chain.chainManager = self;
    self.syncState = [[DSSyncState alloc] initWithSyncPhase:DSChainSyncPhase_Offline];
    self.keyManager = [[DSKeyManager alloc] initWithChain:chain];
    self.backgroundManager = [[DSBackgroundManager alloc] initWithChain:chain];
    self.sporkManager = [[DSSporkManager alloc] initWithChain:chain];
    self.masternodeManager = [[DSMasternodeManager alloc] initWithChain:chain];
    [self.masternodeManager setUp];
    self.governanceSyncManager = [[DSGovernanceSyncManager alloc] initWithChain:chain];
    self.transactionManager = [[DSTransactionManager alloc] initWithChain:chain];
    self.peerManager = [[DSPeerManager alloc] initWithChain:chain];
    self.identitiesManager = [[DSIdentitiesManager alloc] initWithChain:chain];
    self.gotSporksAtChainSyncStart = FALSE;
    self.sessionConnectivityNonce = ((uint64_t)arc4random() << 32) | arc4random();
    self.lastNotifiedBlockDidChange = 0;

    if ([self.masternodeManager hasCurrentMasternodeListInLast30Days]) {
        [self.peerManager useMasternodeList:self.masternodeManager.currentMasternodeList withConnectivityNonce:self.sessionConnectivityNonce];
    }

    //[self loadMaxTransactionInfo];
    //[self loadHeightTransactionZones];

    self.miningQueue = dispatch_queue_create([[NSString stringWithFormat:@"org.dashcore.dashsync.mining.%@", self.chain.uniqueID] UTF8String], DISPATCH_QUEUE_SERIAL);
    DSLog(@"[%@] initWithChain %@", self.logPrefix, chain);
    return self;
}

- (NSString *)logPrefix {
    return [NSString stringWithFormat:@"[%@] [Chain Manager] ", self.chain.name];
}

- (BOOL)isSynced {
    return self.syncState.combinedSyncProgress == 1.0;
}
- (double)combinedSyncProgress {
    return self.syncState.combinedSyncProgress;
}


// MARK: - Info

- (void)relayedNewItem {
    self.lastChainRelayTime = [NSDate timeIntervalSince1970];
}

// MARK: - Blockchain Sync

- (void)startSync {
    [self notify:DSChainManagerSyncWillStartNotification userInfo:@{DSChainManagerNotificationChainKey: self.chain}];
    DSLog(@"[%@] startSync -> peerManager::connect", self.logPrefix);
    [self.peerManager connect];
}

- (void)stopSync {
    DSLog(@"[%@] stopSync (chain switch)", self.logPrefix);
    [self.masternodeManager stopSync];
    [self.peerManager disconnect:DSDisconnectReason_ChainSwitch];
    self.syncState.syncPhase = DSChainSyncPhase_Offline;
    [self notifySyncStateChanged];
}

- (void)removeNonMainnetTrustedPeer {
    if (![self.chain isMainnet]) {
        NSManagedObjectContext *chainContext = [NSManagedObjectContext chainContext];
        [[DashSync sharedSyncController] wipePeerDataForChain:self.chain inContext:chainContext];
    }
}

- (void)disconnectedMasternodeListAndBlocksRescan {
    NSManagedObjectContext *chainContext = [NSManagedObjectContext chainContext];
    [[DashSync sharedSyncController] wipeMasternodeDataForChain:self.chain inContext:chainContext];
    [[DashSync sharedSyncController] wipeBlockchainDataForChain:self.chain inContext:chainContext];

    [self removeNonMainnetTrustedPeer];
    [self notify:DSChainManagerSyncWillStartNotification userInfo:@{DSChainManagerNotificationChainKey: self.chain}];
    DSLog(@"[%@] disconnectedMasternodeListAndBlocksRescan -> peerManager::connect", self.logPrefix);
    [self.peerManager connect];
}

- (void)disconnectedMasternodeListRescan {
    NSManagedObjectContext *chainContext = [NSManagedObjectContext chainContext];
    [[DashSync sharedSyncController] wipeMasternodeDataForChain:self.chain inContext:chainContext];

    [self removeNonMainnetTrustedPeer];
    [self notify:DSChainManagerSyncWillStartNotification userInfo:@{DSChainManagerNotificationChainKey: self.chain}];
    DSLog(@"[%@] disconnectedMasternodeListRescan -> peerManager::connect", self.logPrefix);
    [self.peerManager connect];
}

- (void)disconnectedSyncBlocksRescan {
    NSManagedObjectContext *chainContext = [NSManagedObjectContext chainContext];
    [[DashSync sharedSyncController] wipeBlockchainNonTerminalDataForChain:self.chain inContext:chainContext];

    [self removeNonMainnetTrustedPeer];
    [self notify:DSChainManagerSyncWillStartNotification userInfo:@{DSChainManagerNotificationChainKey: self.chain}];
    DSLog(@"[%@] disconnectedSyncBlocksRescan -> peerManager::connect", self.logPrefix);
    [self.peerManager connect];
}

// rescans blocks and transactions after earliestKeyTime, a new random download peer is also selected due to the
// possibility that a malicious node might lie by omitting transactions that match the bloom filter
- (void)syncBlocksRescan {
    if (!self.peerManager.connected) {
        [self disconnectedSyncBlocksRescan];
    } else {
        [self.peerManager disconnectDownloadPeerForError:nil
                                          withCompletion:^(BOOL success) {
                                              [self disconnectedSyncBlocksRescan];
                                          }];
    }
}

- (void)masternodeListAndBlocksRescan {
    if (!self.peerManager.connected) {
        [self disconnectedMasternodeListAndBlocksRescan];
    } else {
        [self.peerManager disconnectDownloadPeerForError:nil
                                          withCompletion:^(BOOL success) {
                                              [self disconnectedMasternodeListAndBlocksRescan];
                                          }];
    }
}

- (void)masternodeListRescan {
    if (!self.peerManager.connected) {
        [self disconnectedMasternodeListRescan];
    } else {
        [self.peerManager disconnectDownloadPeerForError:nil
                                          withCompletion:^(BOOL success) {
                                              [self disconnectedMasternodeListRescan];
                                          }];
    }
}


// MARK: - DSChainDelegate

- (void)chain:(DSChain *)chain didSetBlockHeight:(int32_t)height andTimestamp:(NSTimeInterval)timestamp forTransactionHashes:(NSArray *)txHashes updatedTransactions:(NSArray *)updatedTransactions {
    [self.transactionManager chain:chain didSetBlockHeight:height andTimestamp:timestamp forTransactionHashes:txHashes updatedTransactions:updatedTransactions];
}

- (void)chain:(DSChain *)chain didFinishInChainSyncPhaseFetchingIdentityDAPInformation:(DSIdentity *)identity {
    dispatch_async(chain.networkingQueue, ^{
        [self.peerManager resumeBlockchainSynchronizationOnPeers];
    });
}

- (void)chainWasWiped:(DSChain *)chain {
    [self.transactionManager chainWasWiped:chain];
}

- (void)chainWillStartSyncingBlockchain:(DSChain *)chain {
    self.lastChainRelayTime = 0;
    if (!self.gotSporksAtChainSyncStart) {
        [self.sporkManager getSporks]; //get the sporks early on
    }
}

- (void)chainWillStartConnectingToPeers:(DSChain *)chain {
    
}

- (void)chainShouldStartSyncingBlockchain:(DSChain *)chain onPeer:(DSPeer *)peer {
    [self notify:DSChainManagerChainSyncDidStartNotification userInfo:@{
        DSChainManagerNotificationChainKey: self.chain,
        DSPeerManagerNotificationPeerKey: peer ? peer : [NSNull null]}];
    dispatch_async(self.chain.networkingQueue, ^{
        if ((self.syncPhase != DSChainSyncPhase_ChainSync && self.syncPhase != DSChainSyncPhase_Synced) && self.chain.needsInitialTerminalHeadersSync) {
            //masternode list should be synced first and the masternode list is old
            self.syncState.syncPhase = DSChainSyncPhase_InitialTerminalBlocks;
            [peer sendGetheadersMessageWithLocators:[self.chain terminalBlocksLocatorArray] andHashStop:UINT256_ZERO];
        } else if (([[DSOptionsManager sharedInstance] syncType] & DSSyncType_MasternodeList) && [self.masternodeManager isMasternodeListOutdated]) {
            self.syncState.syncPhase = DSChainSyncPhase_InitialTerminalBlocks;
            [self.masternodeManager startSync];
        } else {
            self.syncState.syncPhase = DSChainSyncPhase_ChainSync;
            BOOL startingDevnetSync = [self.chain isDevnetAny] && self.chain.lastSyncBlockHeight < 5;
            NSTimeInterval cutoffTime = self.chain.earliestWalletCreationTime - HEADER_WINDOW_BUFFER_TIME;
            if (startingDevnetSync || (self.chain.lastSyncBlockTimestamp >= cutoffTime && [self shouldRequestMerkleBlocksForZoneAfterHeight:[self.chain lastSyncBlockHeight]])) {
                [peer sendGetblocksMessageWithLocators:[self.chain chainSyncBlockLocatorArray] andHashStop:UINT256_ZERO];
            } else {
                [peer sendGetheadersMessageWithLocators:[self.chain chainSyncBlockLocatorArray] andHashStop:UINT256_ZERO];
            }
        }
        [self notifySyncStateChanged];
    });
}

- (void)chainFinishedSyncingInitialHeaders:(DSChain *)chain fromPeer:(DSPeer *)peer onMainChain:(BOOL)onMainChain {
    if (onMainChain && peer && (peer == self.peerManager.downloadPeer)) [self relayedNewItem];
    DSLog(@"%@ Sync Status: initial headers: OK -> sync masternode lists & quorums", self.logPrefix);
    [self.peerManager chainSyncStopped];
    if (([[DSOptionsManager sharedInstance] syncType] & DSSyncType_MasternodeList)) {
        // make sure we care about masternode lists
        [self.masternodeManager startSync];
    }
}

- (void)chainFinishedSyncingTransactionsAndBlocks:(DSChain *)chain fromPeer:(DSPeer *)peer onMainChain:(BOOL)onMainChain {
    if (onMainChain && peer && (peer == self.peerManager.downloadPeer)) [self relayedNewItem];
    DSLog(@"%@ Sync Status: transactions and blocks: OK -> sync mempool, sporks & governance", self.logPrefix);
    
    self.syncState.chainSyncStartHeight = 0;
    self.syncState.syncPhase = DSChainSyncPhase_Synced;
    [self.transactionManager fetchMempoolFromNetwork];
    [self.sporkManager getSporks];
    [self.governanceSyncManager startGovernanceSync];
    if (([[DSOptionsManager sharedInstance] syncType] & DSSyncType_MasternodeList)) {
        // make sure we care about masternode lists
        [self.masternodeManager startSync];
    }
    [self notifySyncStateChanged];
}

- (DSChainSyncPhase)syncPhase {
    return [self.syncState syncPhase];
}

- (void)setSyncPhase:(DSChainSyncPhase)syncPhase {
    self.syncState.syncPhase = syncPhase;
}

- (void)syncBlockchain {
    DSLog(@"[%@] syncBlockchain connected peers: %lu phase: %d", self.logPrefix, self.peerManager.connectedPeerCount, self.syncPhase);
    if (self.peerManager.connectedPeerCount == 0) {
        if (self.syncPhase == DSChainSyncPhase_InitialTerminalBlocks) {
            self.syncState.syncPhase = DSChainSyncPhase_ChainSync;
            [self notifySyncStateChanged];
        }
        DSLog(@"[%@] syncBlockchain -> peerManager::connect", self.logPrefix);
        [self.peerManager connect];
    } else if (!self.peerManager.masternodeList && self.masternodeManager.currentMasternodeList) {
        [self.peerManager useMasternodeList:self.masternodeManager.currentMasternodeList withConnectivityNonce:self.sessionConnectivityNonce];
    } else if (self.syncPhase == DSChainSyncPhase_InitialTerminalBlocks) {
        self.syncState.syncPhase = DSChainSyncPhase_ChainSync;
        [self notifySyncStateChanged];
        [self chainShouldStartSyncingBlockchain:self.chain onPeer:self.peerManager.downloadPeer];
    }
}

- (void)chainFinishedSyncingMasternodeListsAndQuorums:(DSChain *)chain {
    if (chain.isEvolutionEnabled) {
        DSLog(@"%@ Sync Status: masternode list and quorums: OK -> sync identities", self.logPrefix);
        [self.identitiesManager syncIdentitiesWithCompletion:^(NSArray<DSIdentity *> *_Nullable identities) {
            [self syncBlockchain];
        }];
    } else {
        DSLog(@"%@ Sync Status: masternode list and quorums: OK -> sync chain", self.logPrefix);
        [self syncBlockchain];
    }
}

- (void)chain:(DSChain *)chain badBlockReceivedFromPeer:(DSPeer *)peer {
    DSLog(@"[%@: %@:%d] peer is misbehaving", self.logPrefix, peer.host, peer.port);
    [self.peerManager peerMisbehaving:peer errorMessage:@"Bad block received from peer"];
}

- (void)chain:(DSChain *)chain receivedOrphanBlock:(DSBlock *)block fromPeer:(DSPeer *)peer {
    // ignore orphans older than one week ago
    if (block.timestamp < [NSDate timeIntervalSince1970] - WEEK_TIME_INTERVAL) return;

    // call getblocks, unless we already did with the previous block, or we're still downloading the chain
    if (self.chain.lastSyncBlockHeight >= peer.lastBlockHeight && !uint256_eq(self.chain.lastOrphan.blockHash, block.prevBlock)) {
        DSLog(@"[%@: %@:%d] calling getblocks", self.logPrefix, peer.host, peer.port);
        [peer sendGetblocksMessageWithLocators:[self.chain chainSyncBlockLocatorArray] andHashStop:UINT256_ZERO];
    }
}

- (void)chain:(DSChain *)chain wasExtendedWithBlock:(DSBlock *)merkleBlock fromPeer:(DSPeer *)peer {
    if (([[DSOptionsManager sharedInstance] syncType] & DSSyncType_MasternodeList)) {
        // make sure we care about masternode lists
        [self.masternodeManager getCurrentMasternodeListWithSafetyDelay:3];
    }
}


// MARK: - Count Info

- (void)resetSyncCountInfo:(DSSyncCountInfo)syncCountInfo inContext:(NSManagedObjectContext *)context {
    [self setCount:0 forSyncCountInfo:syncCountInfo inContext:context];
}

- (void)setCount:(uint32_t)count
forSyncCountInfo:(DSSyncCountInfo)syncCountInfo
       inContext:(NSManagedObjectContext *)context {
    switch (syncCountInfo) {
        case DSSyncCountInfo_GovernanceObject:
            self.chain.totalGovernanceObjectsCount = count;
            [self.chain saveInContext:context];
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
    [self setCount:count forSyncCountInfo:syncCountInfo inContext:self.chain.chainManagedObjectContext];
    switch (syncCountInfo) {
        case DSSyncCountInfo_List: {
            //deprecated
            break;
        }
        case DSSyncCountInfo_GovernanceObject: {
            [self notify:DSGovernanceObjectCountUpdateNotification userInfo:@{@(syncCountInfo): @(count), DSChainManagerNotificationChainKey: self.chain}];
            break;
        }
        case DSSyncCountInfo_GovernanceObjectVote: {
            if (peer.governanceRequestState == DSGovernanceRequestState_GovernanceObjectVoteHashesReceived) {
                if (count == 0) {
                    //there were no votes
                    DSLog(@"[%@: %@:%d] no votes on object, going to next object", self.logPrefix, peer.host, peer.port);
                    peer.governanceRequestState = DSGovernanceRequestState_GovernanceObjectVotes;
                    [self.governanceSyncManager finishedGovernanceVoteSyncWithPeer:peer];
                } else {
                    [self notify:DSGovernanceVoteCountUpdateNotification userInfo:@{@(syncCountInfo): @(count), DSChainManagerNotificationChainKey: self.chain}];
                }
            }

            break;
        }
        default:
            break;
    }
}

- (void)wipeMasternodeInfo {
    [self.masternodeManager wipeLocalMasternodeInfo];
    [self.masternodeManager wipeMasternodeInfo];
}

- (DSChainLock * _Nullable)chainLockForBlockHash:(UInt256)blockHash {
    return [self.transactionManager chainLockForBlockHash:blockHash];
}

- (NSString *)chainSyncStartHeightKey {
    return [NSString stringWithFormat:@"%@_%@", SYNC_STARTHEIGHT_KEY, [self.chain uniqueID]];
}

- (NSString *)terminalSyncStartHeightKey {
    return [NSString stringWithFormat:@"%@_%@", TERMINAL_SYNC_STARTHEIGHT_KEY, [self.chain uniqueID]];
}


- (void)resetChainSyncStartHeight {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    BOOL changed = NO;
    if (self.syncState.chainSyncStartHeight == 0) {
        self.syncState.chainSyncStartHeight = (uint32_t)[userDefaults integerForKey:self.chainSyncStartHeightKey];
        changed = YES;
    }
    if (self.syncState.chainSyncStartHeight == 0) {
        self.syncState.chainSyncStartHeight = self.chain.lastSyncBlockHeight;
        changed = YES;
        [[NSUserDefaults standardUserDefaults] setInteger:self.syncState.chainSyncStartHeight forKey:self.chainSyncStartHeightKey];
    }
    if (changed)
        [self notifySyncStateChanged];
}

- (void)restartChainSyncStartHeight {
    self.syncState.chainSyncStartHeight = 0;
    [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:self.chainSyncStartHeightKey];
    [self notifySyncStateChanged];

}


- (void)resetTerminalSyncStartHeight {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    if (self.syncState.terminalSyncStartHeight == 0)
        self.syncState.terminalSyncStartHeight = (uint32_t)[userDefaults integerForKey:self.terminalSyncStartHeightKey];

    if (self.syncState.terminalSyncStartHeight == 0) {
        self.syncState.terminalSyncStartHeight = self.chain.lastTerminalBlockHeight;
        [[NSUserDefaults standardUserDefaults] setInteger:self.syncState.terminalSyncStartHeight forKey:self.terminalSyncStartHeightKey];
    }
}

- (void)restartTerminalSyncStartHeight {
    self.syncState.terminalSyncStartHeight = 0;
    [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:self.terminalSyncStartHeightKey];
}


// MARK: Notifications

- (void)setupNotificationTimer:(void (^ __nullable)(void))completion {
    //we should avoid dispatching this message too frequently
    NSTimeInterval timestamp = [[NSDate date] timeIntervalSince1970];
    if (!self.lastNotifiedBlockDidChange || (timestamp - self.lastNotifiedBlockDidChange > 0.1)) {
        self.lastNotifiedBlockDidChange = timestamp;
        if (self.lastNotifiedBlockDidChangeTimer) {
            [self.lastNotifiedBlockDidChangeTimer invalidate];
            self.lastNotifiedBlockDidChangeTimer = nil;
        }
        completion();
    } else if (!self.lastNotifiedBlockDidChangeTimer) {
        self.lastNotifiedBlockDidChangeTimer = [NSTimer timerWithTimeInterval:1 repeats:NO block:^(NSTimer *_Nonnull timer) {
            completion();
        }];
        [[NSRunLoop mainRunLoop] addTimer:self.lastNotifiedBlockDidChangeTimer forMode:NSRunLoopCommonModes];
    }
}

- (void)notifyMasternodeSyncStateChange:(uint32_t)lastBlockHeihgt storedCount:(uintptr_t)storedCount {
    @synchronized (self.syncState) {
        self.syncState.masternodeListSyncInfo.lastBlockHeight = lastBlockHeihgt;
        self.syncState.masternodeListSyncInfo.storedCount = storedCount;
        [self notifySyncStateChanged];
    }
}

- (void)notifySyncStateChanged {
    [self setupNotificationTimer:^{
        @synchronized (self) {
//            NSLog(@"[%@] Sync: %@", self.chain.name, self.syncState);
            [self notify:DSChainManagerSyncStateDidChangeNotification
                userInfo:@{
                    DSChainManagerNotificationChainKey: self.chain,
                    DSChainManagerNotificationSyncStateKey: [self.syncState copy]
            }];
        }
    }];

}

@end
