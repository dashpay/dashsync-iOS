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

#import "DSChain+Params.h"
#import "DSChain+Protected.h"
#import "DSChainManager+Protected.h"
#import "DSGetMNListDiffRequest.h"
#import "DSMasternodeListDiffService.h"
#import "DSMasternodeListService+Protected.h"
#import "DSMasternodeManager+Protected.h"
#import "DSTransactionManager+Protected.h"
#import "NSString+Dash.h"

@interface DSMasternodeListDiffService ()

@property (nonatomic, strong) NSMutableOrderedSet<NSData *> *retrievalQueue;

@end

@implementation DSMasternodeListDiffService

- (instancetype)initWithChain:(DSChain *)chain {
    NSParameterAssert(chain);
    if (!(self = [super initWithChain:chain])) return nil;
    _retrievalQueue = [NSMutableOrderedSet orderedSet];
    return self;
}

- (NSString *)logPrefix {
    return [NSString stringWithFormat:@"[%@] [MasternodeManager::DiffService]", self.chain.name];
}

- (void)getRecent:(NSData *)blockHash {
    [self addToRetrievalQueue:blockHash];
    [self dequeueMasternodeListRequest];
}

- (void)composeMasternodeListRequest:(NSOrderedSet<NSData *> *)list {
    for (NSData *blockHashData in list) {
        // we should check the associated block still exists
        if ([self hasBlockForBlockHash:blockHashData]) {
            //there is the rare possibility we have the masternode list as a checkpoint, so lets first try that
            NSUInteger pos = [list indexOfObject:blockHashData];
            UInt256 blockHash = blockHashData.UInt256;
            BOOL success = [self.chain.masternodeManager processRequestFromFileForBlockHash:blockHash];
            if (success) {
                NSUInteger newCount = [self removeFromRetrievalQueue:blockHashData];
                dispatch_async(self.chain.networkingQueue, ^{
                    self.chain.chainManager.syncState.masternodeListSyncInfo.queueCount = (uint32_t) newCount;
                    [self.chain.chainManager notifySyncStateChanged];
                    if (!newCount)
                        [self.chain.chainManager.transactionManager checkWaitingForQuorums];
                });
            } else {
                // we need to go get it
                uint32_t blockHeight = [self.chain heightForBlockHash:blockHash];
                UInt256 prevKnownBlockHash = [self closestKnownBlockHashForBlockHeight:blockHeight];
                UInt256 prevInQueueBlockHash = (pos ? [list objectAtIndex:pos - 1].UInt256 : UINT256_ZERO);
                u256 *prev_known_block_hash = u256_ctor_u(prevKnownBlockHash);
                u256 *prev_in_queue_block_hash = u256_ctor_u(prevInQueueBlockHash);
                uint32_t prevKnownHeight = [self.chain heightForBlockHash:u256_cast(prev_known_block_hash)];
                uint32_t prevInQueueBlockHeight =  [self.chain heightForBlockHash:u256_cast(prev_in_queue_block_hash)];
                UInt256 previousBlockHash = pos ? (prevKnownHeight > prevInQueueBlockHeight ? prevKnownBlockHash : prevInQueueBlockHash) : prevKnownBlockHash;
                // request at: every new block
                //                NSAssert(([self.store heightForBlockHash:previousBlockHash] != UINT32_MAX) || uint256_is_zero(previousBlockHash), @"This block height should be known");
                if (uint256_eq(previousBlockHash, blockHash)) {
                    NSUInteger newCount = [self removeFromRetrievalQueue:blockHashData];
                    dispatch_async(self.chain.networkingQueue, ^{
                        self.chain.chainManager.syncState.masternodeListSyncInfo.queueCount = (uint32_t) newCount;
                        [self.chain.chainManager notifySyncStateChanged];
                    });
                } else {
                    [self requestMasternodeListDiff:previousBlockHash forBlockHash:blockHash];
                }
            }
        } else {
            DSLog(@"%@ Missing block (%@)", self.logPrefix, blockHashData.hexString);
            NSUInteger newCount = [self removeFromRetrievalQueue:blockHashData];
            dispatch_async(self.chain.networkingQueue, ^{
                self.chain.chainManager.syncState.masternodeListSyncInfo.queueCount = (uint32_t) newCount;
                [self.chain.chainManager notifySyncStateChanged];
            });
        }
    }
}

- (void)fetchMasternodeListsToRetrieve:(void (^)(NSOrderedSet<NSData *> *listsToRetrieve))completion {
    //DSLog(@"%@ fetchMasternodeListToRetrieve...: %u", self.logPrefix, [self hasActiveQueue]);
    if (![self hasActiveQueue]) {
        DSLog(@"%@ No masternode lists in retrieval", self.logPrefix);
        dispatch_async(self.chain.networkingQueue, ^{
            [self.chain.chainManager.syncState.masternodeListSyncInfo removeSyncKind:DSMasternodeListSyncStateKind_Diffs];
            [self.chain.masternodeManager masternodeListServiceEmptiedRetrievalQueue:self];
        });
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

- (void)dequeueMasternodeListRequest {
    [self fetchMasternodeListsToRetrieve:^(NSOrderedSet<NSData *> *list) {
        [self composeMasternodeListRequest:list];
        [self startTimeOutObserver];
    }];
}

- (NSOrderedSet<NSData *> *)retrievalQueue {
    @synchronized (_retrievalQueue) {
        return [_retrievalQueue copy];
    }
}

- (NSUInteger)retrievalQueueCount {
    @synchronized (_retrievalQueue) {
        return [_retrievalQueue count];
    }
}

- (NSUInteger)addToRetrievalQueue:(NSData *)masternodeBlockHashData {
    NSUInteger newCount = 0, maxAmount = 0;
    @synchronized (_retrievalQueue) {
        [_retrievalQueue addObject:uint256_data(masternodeBlockHashData.UInt256)];
        newCount = [_retrievalQueue count];
        maxAmount = MAX(self.retrievalQueueMaxAmount, newCount);
        self.retrievalQueueMaxAmount = maxAmount;
        [_retrievalQueue sortUsingComparator:^NSComparisonResult(NSData *obj1, NSData *obj2) {
            return ([self.chain heightForBlockHash:obj1.UInt256] < [self.chain heightForBlockHash:obj2.UInt256]) ? NSOrderedAscending : NSOrderedDescending;
        }];
    }
    return newCount;

}

- (NSUInteger)addToRetrievalQueueArray:(NSArray<NSData *> *_Nonnull)masternodeBlockHashDataArray {
    NSMutableArray *nonEmptyBlockHashes = [NSMutableArray array];
    NSUInteger newCount = 0, maxAmount = 0;
    @synchronized (_retrievalQueue) {
        NSMutableString *debugString = [NSMutableString string];
        for (NSData *blockHashData in masternodeBlockHashDataArray) {
            NSAssert(uint256_is_not_zero(blockHashData.UInt256), @"We should not be adding an empty block hash");
            if (uint256_is_not_zero(blockHashData.UInt256)) {
                [nonEmptyBlockHashes addObject:blockHashData];
                [debugString appendFormat:@"\t%@,\n", blockHashData.hexString];
            }
        }
        [_retrievalQueue addObjectsFromArray:nonEmptyBlockHashes];
        newCount = [_retrievalQueue count];
        maxAmount = MAX(self.retrievalQueueMaxAmount, newCount);
        self.retrievalQueueMaxAmount = maxAmount;
        [_retrievalQueue sortUsingComparator:^NSComparisonResult(NSData *obj1, NSData *obj2) {
            return ([self.chain heightForBlockHash:obj1.UInt256] < [self.chain heightForBlockHash:obj2.UInt256]) ? NSOrderedAscending : NSOrderedDescending;
        }];
    }
    return newCount;
}

- (NSUInteger)removeFromRetrievalQueue:(NSData *)masternodeBlockHashData {
    NSUInteger newCount = 0, maxAmount = 0;
    @synchronized (_retrievalQueue) {
        [_retrievalQueue removeObject:masternodeBlockHashData];
        newCount = [_retrievalQueue count];
        maxAmount = MAX(self.retrievalQueueMaxAmount, newCount);
    }
    return newCount;
}

- (void)cleanListsRetrievalQueue {
    @synchronized (_retrievalQueue) {
        [_retrievalQueue removeAllObjects];
    }
    self.retrievalQueueMaxAmount = 0;
}

- (BOOL)hasActiveQueue {
    return [self.retrievalQueue count];
}

- (void)requestMasternodeListDiff:(UInt256)previousBlockHash forBlockHash:(UInt256)blockHash {
    DSGetMNListDiffRequest *request = [DSGetMNListDiffRequest requestWithBaseBlockHash:previousBlockHash blockHash:blockHash];
    DSMasternodeListRequest *matchedRequest = [self requestInRetrievalFor:previousBlockHash blockHash:blockHash];
    if (matchedRequest) {
//        DSLog(@"[%@] •••• mnlistdiff request with such a range already in retrieval: %@ .. %@", self.chain.name, uint256_hex(previousBlockHash), uint256_hex(blockHash));
        return;
    }
    uint32_t prev_h =  [self.chain heightForBlockHash:previousBlockHash];
    uint32_t h =  [self.chain heightForBlockHash:blockHash];
    
    
    DSLog(@"%@ Request: %u..%u %@ .. %@", self.logPrefix, prev_h, h, uint256_hex(previousBlockHash), uint256_hex(blockHash));
    dispatch_async(self.chain.networkingQueue, ^{
        [self.chain.chainManager.syncState.masternodeListSyncInfo addSyncKind:DSMasternodeListSyncStateKind_Diffs];
    });
    [self sendMasternodeListRequest:request];
}

- (void)notifyQueueChange:(NSUInteger)newCount maxAmount:(NSUInteger)maxAmount {
    // DSLog(@"%@Queue Changed: %u/%u ", self.logPrefix, (uint32_t)newCount, (uint32_t)maxAmount);
    dispatch_async(self.chain.networkingQueue, ^{
        self.chain.chainManager.syncState.masternodeListSyncInfo.queueCount = (uint32_t) newCount;
        self.chain.chainManager.syncState.masternodeListSyncInfo.queueMaxAmount = (uint32_t) maxAmount;
        [self.chain.chainManager notifySyncStateChanged];
    });
}

@end
