//
//  Created by Vladimir Pirogov
//  Copyright © 2022 Dash Core Group. All rights reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://opensource.org/licenses/MIT
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "DSDAPIClient.h"
#import "DSMasternodeListService.h"
#import "DSMasternodeListService+Protected.h"
#import "DSMasternodeListStore+Protected.h"
#import "DSChain+Protected.h"
#import "DSChainManager.h"
#import "DSChainManager+Protected.h"
#import "DSGetMNListDiffRequest.h"
#import "DSGetQRInfoRequest.h"
#import "DSMasternodeManager+Protected.h"
#import "DSMerkleBlock.h"
#import "DSPeerManager+Protected.h"
#import "DSSimplifiedMasternodeEntry.h"
#import "DSTransactionManager+Protected.h"
#import "NSData+Dash.h"

@interface DSMasternodeListService ()
// List<UInt256> Hashes of blocks for which masternode lists are need to be requested
@property (nonatomic) DSMasternodeListStore *store;
@property (nonatomic, strong) NSMutableOrderedSet<NSData *> *retrievalQueue;
@property (nonatomic, strong) NSMutableOrderedSet<NSData *> *neededQueue;
@property (nonatomic, assign) NSUInteger retrievalQueueMaxAmount;
// List<UInt512>: list of block ranges baseBlockHash + blockHash
@property (nonatomic, strong) NSMutableSet<DSMasternodeListRequest *> *requestsInRetrieval;
@property (nonatomic, strong) dispatch_source_t timeoutTimer;

@end

@implementation DSMasternodeListService

- (instancetype)initWithChain:(DSChain *)chain store:(DSMasternodeListStore *)store delegate:(id<DSMasternodeListServiceDelegate>)delegate {
    NSParameterAssert(chain);
    if (!(self = [super init])) return nil;
    _chain = chain;
    _store = store;
    _delegate = delegate;
    _retrievalQueue = [NSMutableOrderedSet orderedSet];
    _requestsInRetrieval = [NSMutableSet set];
    _timedOutAttempt = 0;
    _timeOutObserverTry = 0;
    return self;
}

- (void)startTimeOutObserver {
    [self cancelTimeOutObserver];
    @synchronized (self) {
        NSSet *requestsInRetrieval = [self.requestsInRetrieval copy];
        NSUInteger masternodeListCount = [self.store knownMasternodeListsCount];
        self.timeOutObserverTry++;
        uint16_t timeOutObserverTry = self.timeOutObserverTry;
        dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20 * (self.timedOutAttempt + 1) * NSEC_PER_SEC));
        self.timeoutTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.chain.networkingQueue);
        if (self.timeoutTimer) {
            dispatch_source_set_timer(self.timeoutTimer, timeout, DISPATCH_TIME_FOREVER, 1ull * NSEC_PER_SEC);
            dispatch_source_set_event_handler(self.timeoutTimer, ^{
                @synchronized (self) {
                    if (!self.retrievalQueueMaxAmount || self.timeOutObserverTry != timeOutObserverTry) {
                        return;
                    }
                    NSSet *requestsInRetrieval2 = [self.requestsInRetrieval copy];
                    NSMutableSet *leftToGet = [requestsInRetrieval mutableCopy];
                    [leftToGet intersectSet:requestsInRetrieval2];
                    if ((masternodeListCount == [self.store knownMasternodeListsCount]) && [requestsInRetrieval isEqualToSet:leftToGet]) {
                        DSLog(@"[%@] %@ TimedOut", self.chain.name, self);
                        self.timedOutAttempt++;
                        [self disconnectFromDownloadPeer];
                        [self cleanRequestsInRetrieval];
                        [self dequeueMasternodeListRequest];
                    } else {
                        [self startTimeOutObserver];
                    }
                }
            });
            dispatch_resume(self.timeoutTimer);
        }
    }
}

- (void)cancelTimeOutObserver {
    @synchronized (self) {
        if (self.timeoutTimer) {
            dispatch_source_cancel(self.timeoutTimer);
            self.timeoutTimer = nil;
        }
    }
}

- (NSString *)logListSet:(NSOrderedSet<NSData *> *)list {
    NSString *str = @"\n";
    for (NSData *blockHashData in list) {
        str = [str stringByAppendingString:[NSString stringWithFormat:@"•••• -> %d: %@,\n",
                                            [self.store heightForBlockHash:blockHashData.UInt256], blockHashData.hexString]];
    }
    return str;
}

- (void)checkWaitingForQuorums {
    if (![self retrievalQueueCount]) {
        [self.chain.chainManager.transactionManager checkWaitingForQuorums];
    }
}

- (void)composeMasternodeListRequest:(NSOrderedSet<NSData *> *)list {
    /* Should be overriden */
}

- (void)dequeueMasternodeListRequest {
    [self fetchMasternodeListsToRetrieve:^(NSOrderedSet<NSData *> *list) {
        [self composeMasternodeListRequest:list];
        [self startTimeOutObserver];
    }];
}

- (void)stop {
    [self cancelTimeOutObserver];
    [self cleanAllLists];
}

- (void)getRecentMasternodeList {
    @synchronized(self.retrievalQueue) {
        DSMerkleBlock *merkleBlock = [self.chain blockFromChainTip:0];
        if (!merkleBlock) {
            // sometimes it happens while rescan
            DSLog(@"[%@] getRecentMasternodeList: (no block exist) for tip", self.chain.name);
            return;
        }
        UInt256 merkleBlockHash = merkleBlock.blockHash;
        if ([self hasLatestBlockInRetrievalQueueWithHash:merkleBlockHash]) {
            //we are asking for the same as the last one
            return;
        }
        if ([self.store addBlockToValidationQueue:merkleBlock]) {
            DSLog(@"[%@] MasternodeListService.Getting masternode list %u", self.chain.name, merkleBlock.height);
            NSData *merkleBlockHashData = uint256_data(merkleBlockHash);
            BOOL emptyRequestQueue = ![self retrievalQueueCount];
            [self addToRetrievalQueue:merkleBlockHashData];
            if (emptyRequestQueue) {
                [self dequeueMasternodeListRequest];
            }
        }
    }
}

- (void)setCurrentMasternodeList:(DSMasternodeList *_Nullable)currentMasternodeList {
    if (self.chain.isEvolutionEnabled) {
        if (!_currentMasternodeList) {
            for (DSSimplifiedMasternodeEntry *masternodeEntry in currentMasternodeList.simplifiedMasternodeEntries) {
                if (masternodeEntry.isValid) {
                    [self.chain.chainManager.DAPIClient addDAPINodeByAddress:masternodeEntry.ipAddressString];
                }
            }
        } else {
            NSDictionary *updates = [currentMasternodeList listOfChangedNodesComparedTo:_currentMasternodeList];
            NSArray *added = updates[MASTERNODE_LIST_ADDED_NODES];
            NSArray *removed = updates[MASTERNODE_LIST_REMOVED_NODES];
            NSArray *addedValidity = updates[MASTERNODE_LIST_ADDED_VALIDITY];
            NSArray *removedValidity = updates[MASTERNODE_LIST_REMOVED_VALIDITY];
            for (DSSimplifiedMasternodeEntry *masternodeEntry in added) {
                if (masternodeEntry.isValid) {
                    [self.chain.chainManager.DAPIClient addDAPINodeByAddress:masternodeEntry.ipAddressString];
                }
            }
            for (DSSimplifiedMasternodeEntry *masternodeEntry in addedValidity) {
                [self.chain.chainManager.DAPIClient addDAPINodeByAddress:masternodeEntry.ipAddressString];
            }
            for (DSSimplifiedMasternodeEntry *masternodeEntry in removed) {
                [self.chain.chainManager.DAPIClient removeDAPINodeByAddress:masternodeEntry.ipAddressString];
            }
            for (DSSimplifiedMasternodeEntry *masternodeEntry in removedValidity) {
                [self.chain.chainManager.DAPIClient removeDAPINodeByAddress:masternodeEntry.ipAddressString];
            }
        }
    }
    bool changed = _currentMasternodeList != currentMasternodeList;
    _currentMasternodeList = currentMasternodeList;
    if (changed) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSCurrentMasternodeListDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey: self.chain, DSMasternodeManagerNotificationMasternodeListKey: self.currentMasternodeList ? self.currentMasternodeList : [NSNull null]}];
        });
    }
}

- (void)populateRetrievalQueueWithBlockHashes:(NSOrderedSet *)blockHashes {
    @synchronized(self.retrievalQueue) {
        NSArray *orderedBlockHashes = [blockHashes sortedArrayUsingComparator:^NSComparisonResult(NSData *_Nonnull obj1, NSData *_Nonnull obj2) {
            uint32_t height1 = [self.store heightForBlockHash:obj1.UInt256];
            uint32_t height2 = [self.store heightForBlockHash:obj2.UInt256];
            return (height1 > height2) ? NSOrderedDescending : NSOrderedAscending;
        }];
        [self addToRetrievalQueueArray:orderedBlockHashes];
    }
    [self dequeueMasternodeListRequest];
}

- (BOOL)shouldProcessDiffResult:(DSMnDiffProcessingResult *)diffResult skipPresenceInRetrieval:(BOOL)skipPresenceInRetrieval {
    DSMasternodeList *masternodeList = diffResult.masternodeList;
    UInt256 masternodeListBlockHash = masternodeList.blockHash;
    NSData *masternodeListBlockHashData = uint256_data(masternodeListBlockHash);
    BOOL hasInRetrieval = [self.retrievalQueue containsObject:masternodeListBlockHashData];
//    uint32_t masternodeListBlockHeight = [self.store heightForBlockHash:masternodeListBlockHash];
    BOOL shouldNot = !hasInRetrieval && !skipPresenceInRetrieval;
    //DSLog(@"•••• shouldProcessDiffResult: %d: %@ %d", masternodeListBlockHeight, uint256_reverse_hex(masternodeListBlockHash), !shouldNot);
    if (shouldNot) {
        //We most likely wiped data in the meantime
        [self cleanRequestsInRetrieval];
        [self dequeueMasternodeListRequest];
        return NO;
    }
    BOOL isValid = [diffResult isTotallyValid];
    if (!isValid) {
        DSLog(@"[%@] Invalid diff result: %@", self.chain.name, diffResult.debugDescription);
    }
    return isValid;

}

- (void)updateAfterProcessingMasternodeListWithBlockHash:(NSData *)blockHashData fromPeer:(DSPeer *)peer {
    [self removeFromRetrievalQueue:blockHashData];
    [self dequeueMasternodeListRequest];
    [self checkWaitingForQuorums];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:CHAIN_FAULTY_DML_MASTERNODE_PEERS];
}

- (void)addToRetrievalQueue:(NSData *)masternodeBlockHashData {
    NSAssert(uint256_is_not_zero(masternodeBlockHashData.UInt256), @"the hash data must not be empty");
    [self.retrievalQueue addObject:masternodeBlockHashData];
    [self updateMasternodeRetrievalQueue];
}

- (void)addToRetrievalQueueArray:(NSArray<NSData *> *)masternodeBlockHashDataArray {
    NSMutableArray *nonEmptyBlockHashes = [NSMutableArray array];
    for (NSData *blockHashData in masternodeBlockHashDataArray) {
        NSAssert(uint256_is_not_zero(blockHashData.UInt256), @"We should not be adding an empty block hash");
        if (uint256_is_not_zero(blockHashData.UInt256)) {
            [nonEmptyBlockHashes addObject:blockHashData];
        }
    }
    [self.retrievalQueue addObjectsFromArray:nonEmptyBlockHashes];
    [self updateMasternodeRetrievalQueue];
}

- (void)removeFromRetrievalQueue:(NSData *)masternodeBlockHashData {
    [self.retrievalQueue removeObject:masternodeBlockHashData];
    double count = self.retrievalQueue.count;
    @synchronized (self.chain.chainManager.syncState) {
        self.chain.chainManager.syncState.masternodeListSyncInfo.retrievalQueueCount = count;
        self.chain.chainManager.syncState.masternodeListSyncInfo.retrievalQueueMaxAmount = (uint32_t) self.retrievalQueueMaxAmount;
        DSLog(@"[%@] Masternode list queue updated: %f/%lu", self.chain.name, count, self.retrievalQueueMaxAmount);
        [self.chain.chainManager notifySyncStateChanged];
    }
}

- (void)cleanRequestsInRetrieval {
    [self.requestsInRetrieval removeAllObjects];
}

- (void)cleanListsRetrievalQueue {
    [self.retrievalQueue removeAllObjects];
    @synchronized (self.chain.chainManager.syncState) {
        self.chain.chainManager.syncState.masternodeListSyncInfo.retrievalQueueCount = 0;
        self.chain.chainManager.syncState.masternodeListSyncInfo.retrievalQueueMaxAmount = (uint32_t) self.retrievalQueueMaxAmount;
        DSLog(@"[%@] Masternode list queue cleaned up: 0/%lu", self.chain.name, self.retrievalQueueMaxAmount);
        [self.chain.chainManager notifySyncStateChanged];
    }
}

- (void)cleanAllLists {
    self.currentMasternodeList = nil;
    [self cleanListsRetrievalQueue];
    [self cleanRequestsInRetrieval];
}

- (DSPeerManager *)peerManager {
    return self.chain.chainManager.peerManager;
}

- (NSUInteger)retrievalQueueCount {
    return self.retrievalQueue.count;
}

- (void)updateMasternodeRetrievalQueue {
    NSUInteger currentCount = self.retrievalQueue.count;
    self.retrievalQueueMaxAmount = MAX(self.retrievalQueueMaxAmount, currentCount);
    [self.retrievalQueue sortUsingComparator:^NSComparisonResult(NSData *_Nonnull obj1, NSData *_Nonnull obj2) {
        return [self.store heightForBlockHash:obj1.UInt256] < [self.store heightForBlockHash:obj2.UInt256] ? NSOrderedAscending : NSOrderedDescending;
    }];
    @synchronized (self.chain.chainManager.syncState) {
        self.chain.chainManager.syncState.masternodeListSyncInfo.retrievalQueueCount = (uint32_t) currentCount;
        self.chain.chainManager.syncState.masternodeListSyncInfo.retrievalQueueMaxAmount = (uint32_t) self.retrievalQueueMaxAmount;
        DSLog(@"[%@] Masternode list queue updated: %lu/%lu", self.chain.name, currentCount, self.retrievalQueueMaxAmount);
        [self.chain.chainManager notifySyncStateChanged];
    }
}

- (void)fetchMasternodeListsToRetrieve:(void (^)(NSOrderedSet<NSData *> *listsToRetrieve))completion {
    if (![self retrievalQueueCount]) {
        DSLog(@"[%@] No masternode lists in retrieval: %@", self.chain.name, self);
        [self.delegate masternodeListServiceEmptiedRetrievalQueue:self];
        return;
    }
    if ([self.requestsInRetrieval count]) {
        DSLog(@"[%@] A masternode list is already in retrieval: %@", self.chain.name, self);
        return;
    }
    BOOL peerIsDisconnected;
    @synchronized (self.peerManager.downloadPeer) {
        peerIsDisconnected = !self.peerManager.downloadPeer || self.peerManager.downloadPeer.status != DSPeerStatus_Connected;
    }
    if (peerIsDisconnected) {
        if (self.chain.chainManager.syncPhase != DSChainSyncPhase_Offline) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), self.chain.networkingQueue, ^{
                [self fetchMasternodeListsToRetrieve:completion];
            });
        }
        return;
    }
    completion([self.retrievalQueue copy]);
}

- (DSMasternodeListRequest*__nullable)requestInRetrievalFor:(UInt256)baseBlockHash blockHash:(UInt256)blockHash {
    DSMasternodeListRequest *matchedRequest = nil;
    for (DSMasternodeListRequest *request in [self.requestsInRetrieval copy]) {
        if ([request matchesInRangeWithBaseBlockHash:baseBlockHash blockHash:blockHash]) {
            matchedRequest = request;
            break;
        }
    }
    return matchedRequest;
}

- (BOOL)removeRequestInRetrievalForBaseBlockHash:(UInt256)baseBlockHash blockHash:(UInt256)blockHash {
    DSMasternodeListRequest *matchedRequest = [self requestInRetrievalFor:baseBlockHash blockHash:blockHash];
    if (!matchedRequest) {
        #if DEBUG
        NSSet *requestsInRetrieval;
        @synchronized (self.requestsInRetrieval) {
            requestsInRetrieval = [self.requestsInRetrieval copy];
        }
        NSMutableArray *requestsInRetrievalStrings = [NSMutableArray array];
        for (DSMasternodeListRequest *requestInRetrieval in requestsInRetrieval) {
            [requestsInRetrievalStrings addObject:[requestInRetrieval logWithBlockHeightLookup:^uint32_t(UInt256 blockHash) {
                return [self.store heightForBlockHash:blockHash];
            }]];
        }
        DSLog(@"[%@] A masternode list (%@ .. %@) was received that is not set to be retrieved (%@)", self.chain.name, uint256_hex(baseBlockHash), uint256_hex(blockHash), [requestsInRetrievalStrings componentsJoinedByString:@", "]);
        #endif /* DEBUG */
        return NO;
    }
    @synchronized (self.requestsInRetrieval) {
        [self.requestsInRetrieval removeObject:matchedRequest];
    }
    return YES;
}

- (BOOL)hasLatestBlockInRetrievalQueueWithHash:(UInt256)blockHash {
    return [self.retrievalQueue lastObject] && uint256_eq(blockHash, [self.retrievalQueue lastObject].UInt256);
}

- (void)disconnectFromDownloadPeer {
    [self.peerManager.downloadPeer disconnect];
}

- (void)issueWithMasternodeListFromPeer:(DSPeer *)peer {
    [self.peerManager peerMisbehaving:peer errorMessage:@"Issue with Deterministic Masternode list"];
    NSArray *faultyPeers = [[NSUserDefaults standardUserDefaults] arrayForKey:CHAIN_FAULTY_DML_MASTERNODE_PEERS];
    if (faultyPeers.count >= MAX_FAULTY_DML_PEERS) {
        DSLog(@"[%@] Exceeded max failures for masternode list, starting from scratch", self.chain.name);
        //no need to remove local masternodes
        [self cleanListsRetrievalQueue];
        [self.store deleteAllOnChain];
        [self.delegate masternodeListServiceExceededMaxFailuresForMasternodeList:self blockHash:self.currentMasternodeList.blockHash];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:CHAIN_FAULTY_DML_MASTERNODE_PEERS];
        [self getRecentMasternodeList];
    } else {
        if (!faultyPeers) {
            faultyPeers = @[peer.location];
        } else if (![faultyPeers containsObject:peer.location]) {
            faultyPeers = [faultyPeers arrayByAddingObject:peer.location];
        }
        [[NSUserDefaults standardUserDefaults] setObject:faultyPeers forKey:CHAIN_FAULTY_DML_MASTERNODE_PEERS];
        [self dequeueMasternodeListRequest];
    }
    [self.chain.chainManager notify:DSMasternodeListDiffValidationErrorNotification userInfo:@{DSChainManagerNotificationChainKey: self.chain}];
}

- (void)sendMasternodeListRequest:(DSMasternodeListRequest *)request {
//    DSLog(@"•••• sendMasternodeListRequest: %@", [request toData].hexString);
    [self.peerManager sendRequest:request];
    @synchronized (self.requestsInRetrieval) {
        [self.requestsInRetrieval addObject:request];
    }
}

@end
