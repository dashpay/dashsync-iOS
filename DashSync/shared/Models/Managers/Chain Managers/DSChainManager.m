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
#import "DSChain+Protected.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSChainManager+Mining.h"
#import "DSChainManager+Protected.h"
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
@property (nonatomic, strong) DSDAPIClient *DAPIClient;
@property (nonatomic, strong) DSTransactionManager *transactionManager;
@property (nonatomic, strong) DSPeerManager *peerManager;
@property (nonatomic, assign) uint64_t sessionConnectivityNonce;
@property (nonatomic, assign) BOOL gotSporksAtChainSyncStart;
@property (nonatomic, strong) NSData *maxTransactionsInfoData;
@property (nonatomic, strong) RHIntervalTree *heightTransactionZones;
@property (nonatomic, assign) uint32_t maxTransactionsInfoDataFirstHeight;
@property (nonatomic, assign) uint32_t maxTransactionsInfoDataLastHeight;
@property (nonatomic, strong) NSData *chainSynchronizationFingerprint;
@property (nonatomic, strong) NSOrderedSet *chainSynchronizationBlockZones;

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
    self.DAPIClient = [[DSDAPIClient alloc] initWithChain:chain]; //this must be
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
    DSLog(@"[%@] DSChainManager.initWithChain %@", chain.name, chain);
    return self;
}

- (BOOL)isSynced {
    return self.syncState.combinedSyncProgress == 1.0;
}
- (double)combinedSyncProgress {
    return self.syncState.combinedSyncProgress;
}

// MARK: - Max transaction info

- (void)loadMaxTransactionInfo {
    NSString *bundlePath = [[NSBundle bundleForClass:self.class] pathForResource:@"DashSync" ofType:@"bundle"];
    NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
    NSString *filePath = [bundle pathForResource:[NSString stringWithFormat:@"MaxTransactionInfo_%@", self.chain.name] ofType:@"dat"];
    self.maxTransactionsInfoData = [NSData dataWithContentsOfFile:filePath];
    if (self.maxTransactionsInfoData) {
        self.maxTransactionsInfoDataFirstHeight = [self.maxTransactionsInfoData UInt16AtOffset:0] * 500;
        self.maxTransactionsInfoDataLastHeight = [self.maxTransactionsInfoData UInt16AtOffset:self.maxTransactionsInfoData.length - 6] * 500;
        //We need MaxTransactionsInfoDataLastHeight to be after the last checkpoint so there is no gap in info. We can gather Max Transactions after the last checkpoint from the initial terminal sync.
        NSAssert(self.maxTransactionsInfoDataLastHeight > self.chain.checkpoints.lastObject.height, @"MaxTransactionsInfoDataLastHeight should always be after the last checkpoint for the system to work");
    }

    ////Some code to log checkpoints, keep it here for some testing in the future.
    //    for (DSCheckpoint * checkpoint in self.chain.checkpoints) {
    //        if (checkpoint.height > 340000) {
    //            NSLog(@"%d:%d",checkpoint.height,[self averageTransactionsFor500RangeAtHeight:checkpoint.height]);
    //        }
    //    }
    //    float average = 0;
    //    uint32_t startRange = self.maxTransactionsInfoDataFirstHeight;
    //    NSMutableData * data = [NSMutableData data];
    //    [data appendUInt16:startRange/500];
    //    while (startRange < self.maxTransactionsInfoDataLastHeight) {
    //        uint32_t endRange = [self firstHeightOutOfAverageRangeWithStart500RangeHeight:startRange rAverage:&average];
    //        NSLog(@"heights %d-%d averageTransactions %.1f",startRange,endRange,average);
    //        startRange = endRange;
    //        [data appendUInt16:(unsigned short)average];
    //        [data appendUInt16:endRange/500];
    //    }
    //
    //    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    //    NSString *documentsDirectory = [paths objectAtIndex:0];
    //    NSString *dataPath = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"HeightTransactionZones_%@.dat",self.chain.name]];
    //    [data writeToFile:dataPath atomically:YES];
    //
}

- (void)loadHeightTransactionZones {
    NSString *bundlePath = [[NSBundle bundleForClass:self.class] pathForResource:@"DashSync" ofType:@"bundle"];
    NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
    NSString *filePath = [bundle pathForResource:[NSString stringWithFormat:@"HeightTransactionZones_%@", self.chain.name] ofType:@"dat"];
    NSData *heightTransactionZonesData = [NSData dataWithContentsOfFile:filePath];
    if (heightTransactionZonesData) {
        NSMutableArray *intervals = [NSMutableArray array];
        for (uint16_t i = 0; i < heightTransactionZonesData.length - 4; i += 4) {
            uint32_t intervalStartHeight = [heightTransactionZonesData UInt16AtOffset:i] * 500;
            uint16_t average = [heightTransactionZonesData UInt16AtOffset:i + 2];
            uint32_t intervalEndHeight = [heightTransactionZonesData UInt16AtOffset:i + 4] * 500;
            [intervals addObject:[RHInterval intervalWithStart:intervalStartHeight stop:intervalEndHeight - 1 object:@(average)]];
        }
        self.heightTransactionZones = [[RHIntervalTree alloc] initWithIntervalObjects:intervals];
    }
}

- (uint16_t)averageTransactionsInZoneForStartHeight:(uint32_t)startHeight endHeight:(uint32_t)endHeight {
    NSArray<RHInterval *> *intervals = [self.heightTransactionZones overlappingObjectsForStart:startHeight andStop:endHeight];
    if (!intervals.count) return 0;
    if (intervals.count == 1) return [(NSNumber *)[intervals[0] object] unsignedShortValue];
    uint64_t aggregate = 0;
    for (RHInterval *interval in intervals) {
        uint64_t value = [(NSNumber *)interval.object unsignedLongValue];
        if (interval == [intervals firstObject]) {
            aggregate += value * (interval.stop - startHeight + 1);
        } else if (interval == [intervals lastObject]) {
            aggregate += value * (endHeight - interval.start + 1);
        } else {
            aggregate += value * (interval.stop - interval.start + 1);
        }
    }
    return aggregate / (endHeight - startHeight);
}

- (uint32_t)firstHeightOutOfAverageRangeWithStart500RangeHeight:(uint32_t)height rAverage:(float *)rAverage {
    return [self firstHeightOutOfAverageRangeWithStart500RangeHeight:height startingVarianceLevel:1 endingVarianceLevel:0.2 convergencePolynomial:0.33 rAverage:rAverage];
}

- (uint32_t)firstHeightOutOfAverageRangeWithStart500RangeHeight:(uint32_t)height startingVarianceLevel:(float)startingVarianceLevel endingVarianceLevel:(float)endingVarianceLevel convergencePolynomial:(float)convergencePolynomial rAverage:(float *)rAverage {
    return [self firstHeightOutOfAverageRangeWithStart500RangeHeight:height startingVarianceLevel:startingVarianceLevel endingVarianceLevel:endingVarianceLevel convergencePolynomial:convergencePolynomial recursionLevel:0 recursionMaxLevel:2 rAverage:rAverage rAverages:nil];
}

- (uint32_t)firstHeightOutOfAverageRangeWithStart500RangeHeight:(uint32_t)height startingVarianceLevel:(float)startingVarianceLevel endingVarianceLevel:(float)endingVarianceLevel convergencePolynomial:(float)convergencePolynomial recursionLevel:(uint16_t)recursionLevel recursionMaxLevel:(uint16_t)recursionMaxLevel rAverage:(float *)rAverage rAverages:(NSArray **)rAverages {
    NSMutableArray *averagesAtHeights = [NSMutableArray array];
    float currentAverage = 0;
    uint32_t checkHeight = height;
    uint16_t i = 0;
    float internalVarianceParameter = ((startingVarianceLevel - endingVarianceLevel) / endingVarianceLevel);
    while (checkHeight < self.maxTransactionsInfoDataLastHeight) {
        uint16_t averageValue = [self averageTransactionsFor500RangeAtHeight:checkHeight];

        if (i != 0 && averageValue > 10) { //before 12 just ignore
            float maxVariance = endingVarianceLevel * (powf((float)i, convergencePolynomial) + internalVarianceParameter) / powf((float)i, convergencePolynomial);
            //NSLog(@"height %d averageValue %hu currentAverage %.2f variance %.2f",checkHeight,averageValue,currentAverage,fabsf(averageValue - currentAverage)/currentAverage);
            if (fabsf(averageValue - currentAverage) > maxVariance * currentAverage) {
                //there was a big change in variance
                if (recursionLevel > recursionMaxLevel) break; //don't recurse again
                //We need to make sure that this wasn't a 1 time variance
                float nextAverage = 0;
                NSArray *nextAverages = nil;

                uint32_t nextHeight = [self firstHeightOutOfAverageRangeWithStart500RangeHeight:checkHeight startingVarianceLevel:startingVarianceLevel endingVarianceLevel:endingVarianceLevel convergencePolynomial:convergencePolynomial recursionLevel:recursionLevel + 1 recursionMaxLevel:recursionMaxLevel rAverage:&nextAverage rAverages:&nextAverages];
                if (fabsf(nextAverage - currentAverage) > endingVarianceLevel * currentAverage) {
                    break;
                } else {
                    [averagesAtHeights addObjectsFromArray:nextAverages];
                    checkHeight = nextHeight;
                }
            } else {
                [averagesAtHeights addObject:@(averageValue)];
                currentAverage = [[averagesAtHeights valueForKeyPath:@"@avg.self"] floatValue];
                checkHeight += 500;
            }
        } else {
            [averagesAtHeights addObject:@(averageValue)];
            currentAverage = [[averagesAtHeights valueForKeyPath:@"@avg.self"] floatValue];
            checkHeight += 500;
        }
        i++;
    }
    if (rAverage) {
        *rAverage = currentAverage;
    }
    if (rAverages) {
        *rAverages = averagesAtHeights;
    }
    return checkHeight;
}

- (uint16_t)averageTransactionsFor500RangeAtHeight:(uint32_t)height {
    if (height < self.maxTransactionsInfoDataFirstHeight) return 0;
    if (height > self.maxTransactionsInfoDataFirstHeight + self.maxTransactionsInfoData.length * 500 / 6) return 0;
    uint32_t offset = floor(((double)height - self.maxTransactionsInfoDataFirstHeight) * 2.0 / 500.0) * 3;
    //uint32_t checkHeight = [self.maxTransactionsInfoData UInt16AtOffset:offset]*500;
    uint16_t average = [self.maxTransactionsInfoData UInt16AtOffset:offset + 2];
    uint16_t max = [self.maxTransactionsInfoData UInt16AtOffset:offset + 4];
    NSAssert(average < max, @"Sanity check that average < max");
    return average;
}

- (uint16_t)maxTransactionsFor500RangeAtHeight:(uint32_t)height {
    if (height < self.maxTransactionsInfoDataFirstHeight) return 0;
    if (height > self.maxTransactionsInfoDataFirstHeight + self.maxTransactionsInfoData.length * 500 / 6) return 0;
    uint32_t offset = floor(((double)height - self.maxTransactionsInfoDataFirstHeight) * 2.0 / 500.0) * 3;
    //uint32_t checkHeight = [self.maxTransactionsInfoData UInt16AtOffset:offset]*500;
    uint16_t average = [self.maxTransactionsInfoData UInt16AtOffset:offset + 2];
    uint16_t max = [self.maxTransactionsInfoData UInt16AtOffset:offset + 4];
    NSAssert(average < max, @"Sanity check that average < max");
    return max;
}

// MARK: - Info

- (void)relayedNewItem {
    self.lastChainRelayTime = [NSDate timeIntervalSince1970];
}

// MARK: - Blockchain Sync

- (void)startSync {
    [self notify:DSChainManagerSyncWillStartNotification userInfo:@{DSChainManagerNotificationChainKey: self.chain}];
    DSLog(@"[%@] startSync -> peerManager::connect", self.chain.name);
    [self.peerManager connect];
}

- (void)stopSync {
    DSLog(@"[%@] stopSync (chain switch)", self.chain.name);
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
    DSLog(@"[%@] disconnectedMasternodeListAndBlocksRescan -> peerManager::connect", self.chain.name);
    [self.peerManager connect];
}

- (void)disconnectedMasternodeListRescan {
    NSManagedObjectContext *chainContext = [NSManagedObjectContext chainContext];
    [[DashSync sharedSyncController] wipeMasternodeDataForChain:self.chain inContext:chainContext];

    [self removeNonMainnetTrustedPeer];
    [self notify:DSChainManagerSyncWillStartNotification userInfo:@{DSChainManagerNotificationChainKey: self.chain}];
    DSLog(@"[%@] disconnectedMasternodeListRescan -> peerManager::connect", self.chain.name);
    [self.peerManager connect];
}

- (void)disconnectedSyncBlocksRescan {
    NSManagedObjectContext *chainContext = [NSManagedObjectContext chainContext];
    [[DashSync sharedSyncController] wipeBlockchainNonTerminalDataForChain:self.chain inContext:chainContext];

    [self removeNonMainnetTrustedPeer];
    [self notify:DSChainManagerSyncWillStartNotification userInfo:@{DSChainManagerNotificationChainKey: self.chain}];
    DSLog(@"[%@] disconnectedSyncBlocksRescan -> peerManager::connect", self.chain.name);
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

- (void)chain:(DSChain *)chain didFinishInChainSyncPhaseFetchingBlockchainIdentityDAPInformation:(DSBlockchainIdentity *)blockchainIdentity {
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

- (NSData *)chainSynchronizationFingerprint {
    //    if (!_chainSynchronizationFingerprint) {
    //        _chainSynchronizationFingerprint = @"".hexToData;
    //    }
    return _chainSynchronizationFingerprint;
}


- (NSOrderedSet *)chainSynchronizationBlockZones {
    if (!_chainSynchronizationBlockZones) {
        _chainSynchronizationBlockZones = [DSWallet blockZonesFromChainSynchronizationFingerprint:self.chainSynchronizationFingerprint rVersion:0 rChainHeight:0];
    }
    return _chainSynchronizationBlockZones;
}

- (BOOL)shouldRequestMerkleBlocksForZoneBetweenHeight:(uint32_t)blockHeight andEndHeight:(uint32_t)endBlockHeight {
    uint16_t blockZone = blockHeight / 500;
    uint16_t endBlockZone = endBlockHeight / 500 + (endBlockHeight % 500 ? 1 : 0);
    if (self.chainSynchronizationFingerprint) {
        while (blockZone < endBlockZone) {
            if ([[self chainSynchronizationBlockZones] containsObject:@(blockZone)]) return TRUE;
        }
        return NO;
    } else {
        return YES;
    }
}

- (BOOL)shouldRequestMerkleBlocksForZoneAfterHeight:(uint32_t)blockHeight {
    uint16_t blockZone = blockHeight / 500;
    uint16_t leftOver = blockHeight % 500;
    if (self.chainSynchronizationFingerprint) {
        return [[self chainSynchronizationBlockZones] containsObject:@(blockZone)] || [[self chainSynchronizationBlockZones] containsObject:@(blockZone + 1)] || [[self chainSynchronizationBlockZones] containsObject:@(blockZone + 2)] || [[self chainSynchronizationBlockZones] containsObject:@(blockZone + 3)] || (!leftOver && [self shouldRequestMerkleBlocksForZoneAfterHeight:(blockZone + 1) * 500]);
    } else {
        return YES;
    }
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
        } else if (([[DSOptionsManager sharedInstance] syncType] & DSSyncType_MasternodeList) && ((self.masternodeManager.lastMasternodeListBlockHeight < self.chain.lastTerminalBlockHeight - 8) || (self.masternodeManager.lastMasternodeListBlockHeight == UINT32_MAX))) {
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
    
    [self.peerManager chainSyncStopped];
    if (([[DSOptionsManager sharedInstance] syncType] & DSSyncType_MasternodeList)) {
        // make sure we care about masternode lists
        [self.masternodeManager startSync];
    }
}

- (void)chainFinishedSyncingTransactionsAndBlocks:(DSChain *)chain fromPeer:(DSPeer *)peer onMainChain:(BOOL)onMainChain {
    if (onMainChain && peer && (peer == self.peerManager.downloadPeer)) [self relayedNewItem];
    DSLog(@"[%@] finished syncing", self.chain.name);
    
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
    DSLog(@"[%@] syncBlockchain connected peers: %lu phase: %d", self.chain.name, self.peerManager.connectedPeerCount, self.syncPhase);
    if (self.peerManager.connectedPeerCount == 0) {
        if (self.syncPhase == DSChainSyncPhase_InitialTerminalBlocks) {
            self.syncState.syncPhase = DSChainSyncPhase_ChainSync;
            [self notifySyncStateChanged];
        }
        DSLog(@"[%@] syncBlockchain -> peerManager::connect", self.chain.name);
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
    DSLog(@"[%@] finished syncing masternode list and quorums, it should start syncing chain", self.chain.name);
    if (chain.isEvolutionEnabled) {
        [self.identitiesManager syncBlockchainIdentitiesWithCompletion:^(NSArray<DSBlockchainIdentity *> *_Nullable blockchainIdentities) {
            [self syncBlockchain];
        }];
    } else {
        [self syncBlockchain];
    }
}

- (void)chain:(DSChain *)chain badBlockReceivedFromPeer:(DSPeer *)peer {
    DSLog(@"[%@: %@:%d] peer is misbehaving", self.chain.name, peer.host, peer.port);
    [self.peerManager peerMisbehaving:peer errorMessage:@"Bad block received from peer"];
}

- (void)chain:(DSChain *)chain receivedOrphanBlock:(DSBlock *)block fromPeer:(DSPeer *)peer {
    // ignore orphans older than one week ago
    if (block.timestamp < [NSDate timeIntervalSince1970] - WEEK_TIME_INTERVAL) return;

    // call getblocks, unless we already did with the previous block, or we're still downloading the chain
    if (self.chain.lastSyncBlockHeight >= peer.lastBlockHeight && !uint256_eq(self.chain.lastOrphan.blockHash, block.prevBlock)) {
        DSLog(@"[%@: %@:%d] calling getblocks", self.chain.name, peer.host, peer.port);
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

- (void)setCount:(uint32_t)count forSyncCountInfo:(DSSyncCountInfo)syncCountInfo inContext:(NSManagedObjectContext *)context {
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
                    DSLog(@"[%@: %@:%d] no votes on object, going to next object", self.chain.name, peer.host, peer.port);
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

- (void)notifySyncStateChanged {
    [self setupNotificationTimer:^{
        @synchronized (self) {
            [self notify:DSChainManagerSyncStateDidChangeNotification
                userInfo:@{
                    DSChainManagerNotificationChainKey: self.chain,
                    DSChainManagerNotificationSyncStateKey: [self.syncState copy]
            }];
        }
    }];

}

- (void)notify:(NSNotificationName)name userInfo:(NSDictionary *_Nullable)userInfo {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:name object:nil userInfo:userInfo];
    });
}
@end
