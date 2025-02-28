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

#import "DSMasternodeListService+Protected.h"
#import "DSChain+Params.h"
#import "DSChain+Protected.h"
#import "DSChainManager+Protected.h"
#import "DSGetMNListDiffRequest.h"
#import "DSGetQRInfoRequest.h"
#import "DSMasternodeManager+Protected.h"
#import "DSMerkleBlock.h"
#import "DSPeerManager+Protected.h"
#import "DSTransactionManager+Protected.h"
#import "NSData+Dash.h"
#import "NSObject+Notification.h"

@interface DSMasternodeListService ()
// List<UInt256> Hashes of blocks for which masternode lists are need to be requested
@property (nonatomic) DSMasternodeListStore *store;
// List<UInt512>: list of block ranges baseBlockHash + blockHash
@property (nonatomic, strong) NSMutableSet<DSMasternodeListRequest *> *requestsInRetrieval;
@property (nonatomic, strong) dispatch_source_t timeoutTimer;

@end

@implementation DSMasternodeListService

- (instancetype)initWithChain:(DSChain *)chain store:(DSMasternodeListStore *)store {
    NSParameterAssert(chain);
    if (!(self = [super init])) return nil;
    _chain = chain;
    _store = store;
    _requestsInRetrieval = [NSMutableSet set];
    _timedOutAttempt = 0;
    _timeOutObserverTry = 0;
    return self;
}

- (void)startTimeOutObserver {
    [self cancelTimeOutObserver];
    @synchronized (self) {
        NSSet *requestsInRetrieval = [self.requestsInRetrieval copy];
        uintptr_t masternodeListCount = DKnownMasternodeListsCount(self.chain.sharedCacheObj);
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
                    uintptr_t count = DKnownMasternodeListsCount(self.chain.sharedCacheObj);
                    
                    if ((masternodeListCount == count) && [requestsInRetrieval isEqualToSet:leftToGet]) {
                        DSLog(@"%@ TimedOut -> dequeueMasternodeListRequest", self.logPrefix);
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

- (void)updateAfterProcessingMasternodeListWithBlockHash:(NSData *)blockHashData fromPeer:(DSPeer *)peer {
    
    [self removeFromRetrievalQueue:blockHashData];
    DSLog(@"%@ updateAfterProcessingMasternodeListWithBlockHash %@ -> dequeueMasternodeListRequest (mn)", self.logPrefix, blockHashData.hexString);
    [self dequeueMasternodeListRequest];
    [self checkWaitingForQuorums];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:CHAIN_FAULTY_DML_MASTERNODE_PEERS];
}

- (void)removeFromRetrievalQueue:(NSData *)masternodeBlockHashData {
    DMnDiffQueueRemove(self.chain.sharedProcessorObj, u256_ctor(masternodeBlockHashData));
}

- (void)cleanRequestsInRetrieval {
    [self.requestsInRetrieval removeAllObjects];
}

- (void)cleanListsRetrievalQueue {
    DMnDiffQueueClean(self.chain.sharedProcessorObj);
}

- (void)cleanAllLists {
    [self cleanListsRetrievalQueue];
    [self cleanRequestsInRetrieval];
    //    dispatch_async(dispatch_get_main_queue(), ^{
    //        [[NSNotificationCenter defaultCenter] postNotificationName:DSCurrentMasternodeListDidChangeNotification
    //                                                            object:nil
    //                                                          userInfo:@{
    //            DSChainManagerNotificationChainKey: self.chain,
    //            DSMasternodeManagerNotificationMasternodeListKey: [NSNull null]
    //        }];
    //    });
    
}

- (DSPeerManager *)peerManager {
    return self.chain.chainManager.peerManager;
}

- (NSOrderedSet<NSData *> *)retrievalQueue {
    indexmap_IndexSet_u8_32 *queue = dash_spv_masternode_processor_processing_processor_cache_MasternodeProcessorCache_mn_list_retrieval_queue(self.chain.sharedCacheObj);
    NSMutableOrderedSet *set = [NSMutableOrderedSet orderedSetWithCapacity:queue->count];
    for (int i = 0; i < queue->count; i++) {
        [set addObject:NSDataFromPtr(queue->values[i])];
    }
    indexmap_IndexSet_u8_32_destroy(queue);
    return [set copy];
}

- (NSUInteger)retrievalQueueCount {
    return DMnDiffQueueCount(self.chain.sharedCacheObj);
}
- (NSUInteger)retrievalQueueMaxAmount {
    return DMnDiffQueueMaxAmount(self.chain.sharedCacheObj);
}

- (BOOL)peerIsDisconnected {
    BOOL peerIsDisconnected;
    @synchronized (self.peerManager.downloadPeer) {
        peerIsDisconnected = !self.peerManager.downloadPeer || self.peerManager.downloadPeer.status != DSPeerStatus_Connected;
    }
    return peerIsDisconnected;
}


- (void)fetchMasternodeListsToRetrieve:(void (^)(NSOrderedSet<NSData *> *listsToRetrieve))completion {
    if (![self retrievalQueueCount]) {
        DSLog(@"%@ No masternode lists in retrieval", self.logPrefix);
        [self.chain.masternodeManager masternodeListServiceEmptiedRetrievalQueue:self];
        return;
    }
    if ([self.requestsInRetrieval count]) {
        DSLog(@"%@ Already in retrieval", self.logPrefix);
        return;
    }
    if ([self peerIsDisconnected]) {
        if (self.chain.chainManager.syncPhase != DSChainSyncPhase_Offline) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), self.chain.networkingQueue, ^{
                [self fetchMasternodeListsToRetrieve:completion];
            });
        }
        return;
    }
    completion([self retrievalQueue]);
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
    if (!matchedRequest) return NO;
    @synchronized (self.requestsInRetrieval) {
        [self.requestsInRetrieval removeObject:matchedRequest];
    }
    return YES;
}

- (void)disconnectFromDownloadPeer {
    [self.peerManager.downloadPeer disconnect];
}

- (void)issueWithMasternodeListFromPeer:(DSPeer *)peer {
    [self.peerManager peerMisbehaving:peer errorMessage:@"Issue with Deterministic Masternode list"];
    NSArray *faultyPeers = [[NSUserDefaults standardUserDefaults] arrayForKey:CHAIN_FAULTY_DML_MASTERNODE_PEERS];
    if (faultyPeers.count >= MAX_FAULTY_DML_PEERS) {
        DSLog(@"%@ Exceeded max failures for masternode list, starting from scratch", self.logPrefix);
        //no need to remove local masternodes
        [self cleanListsRetrievalQueue];
        [self.store deleteAllOnChain];
        [self.store removeOldMasternodeLists];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:CHAIN_FAULTY_DML_MASTERNODE_PEERS];
        [self.chain.masternodeManager getRecentMasternodeList];
    } else {
        if (!faultyPeers) {
            faultyPeers = @[peer.location];
        } else if (![faultyPeers containsObject:peer.location]) {
            faultyPeers = [faultyPeers arrayByAddingObject:peer.location];
        }
        [[NSUserDefaults standardUserDefaults] setObject:faultyPeers forKey:CHAIN_FAULTY_DML_MASTERNODE_PEERS];
        DSLog(@"%@ Failure %lu for masternode list from peer: %@", self.logPrefix, (unsigned long)faultyPeers.count, peer);
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
