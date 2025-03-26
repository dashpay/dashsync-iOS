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
    return [NSString stringWithFormat:@"[%@] [MasternodeManager::DiffService] ", self.chain.name];
}

- (void)composeMasternodeListRequest:(NSOrderedSet<NSData *> *)list {
    NSMutableString *debugString = [NSMutableString stringWithString:@"Needed:\n"];
    for (NSData *data in list) {
        uint32_t h = [self.chain heightForBlockHash:data.UInt256];
        [debugString appendFormat:@"%u: %@\n", h, data.hexString];
    }
    [debugString appendFormat:@"KnownLists:\n"];
    DKnownMasternodeLists *lists = dash_spv_masternode_processor_processing_processor_MasternodeProcessor_masternode_lists(self.chain.sharedProcessorObj);
    for (int i = 0; i < lists->count; i++) {
        dashcore_prelude_CoreBlockHeight *core_block_height = lists->keys[i];
        DMasternodeList *list = lists->values[i];
        u256 *block_hash = dashcore_hash_types_BlockHash_inner(list->block_hash);
        [debugString appendFormat:@"%u: %@\n", core_block_height->_0, u256_hex(block_hash)];
    }
    DKnownMasternodeListsDtor(lists);
    DSLog(@"%@ composeMasternodeListRequest: \n%@", self.logPrefix, debugString);
    for (NSData *blockHashData in list) {
        // we should check the associated block still exists
        if ([self.chain.masternodeManager hasBlockForBlockHash:blockHashData]) {
            //there is the rare possibility we have the masternode list as a checkpoint, so lets first try that
            NSUInteger pos = [list indexOfObject:blockHashData];
            UInt256 blockHash = blockHashData.UInt256;
            BOOL success = [self.chain.masternodeManager processRequestFromFileForBlockHash:blockHash];
            if (success) {
                [self removeFromRetrievalQueue:blockHashData];
                if (![self retrievalQueueCount])
                    [self.chain.chainManager.transactionManager checkWaitingForQuorums];
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
                [self requestMasternodeListDiff:previousBlockHash forBlockHash:blockHash];
//                [self requestMasternodeListDiff:@"00000ffd590b1485b3caadc19b22e6379c733355108f107a430458cdf3407ab6".hexToData.reverse.UInt256 forBlockHash:@"c21ff900433ace7e6b7841bdfec8c449ca06414b237167e30b00000000000000".hexToData.UInt256];
            }
        } else {
            DSLog(@"%@ Missing block (%@)", self.logPrefix, blockHashData.hexString);
            [self removeFromRetrievalQueue:blockHashData];
        }
    }
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
    [self notifyQueueChange:newCount maxAmount:maxAmount];
    return newCount;

}

- (NSUInteger)addToRetrievalQueueArray:(NSArray<NSData *> *_Nonnull)masternodeBlockHashDataArray {
    NSMutableArray *nonEmptyBlockHashes = [NSMutableArray array];
    NSUInteger newCount = 0, maxAmount = 0;
    @synchronized (_retrievalQueue) {
        for (NSData *blockHashData in masternodeBlockHashDataArray) {
            NSAssert(uint256_is_not_zero(blockHashData.UInt256), @"We should not be adding an empty block hash");
            if (uint256_is_not_zero(blockHashData.UInt256)) {
                [nonEmptyBlockHashes addObject:blockHashData];
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
    [self notifyQueueChange:newCount maxAmount:maxAmount];
    return newCount;
}

- (NSUInteger)removeFromRetrievalQueue:(NSData *)masternodeBlockHashData {
    NSUInteger newCount = 0, maxAmount = 0;
    @synchronized (_retrievalQueue) {
        [_retrievalQueue removeObject:masternodeBlockHashData];
        newCount = [_retrievalQueue count];
        maxAmount = MAX(self.retrievalQueueMaxAmount, newCount);

    }
    [self notifyQueueChange:newCount maxAmount:maxAmount];
    return newCount;
}

- (void)cleanListsRetrievalQueue {
    @synchronized (_retrievalQueue) {
        [_retrievalQueue removeAllObjects];
    }
}


- (void)requestMasternodeListDiff:(UInt256)previousBlockHash forBlockHash:(UInt256)blockHash {
    DSGetMNListDiffRequest *request = [DSGetMNListDiffRequest requestWithBaseBlockHash:previousBlockHash blockHash:blockHash];
    DSMasternodeListRequest *matchedRequest = [self requestInRetrievalFor:previousBlockHash blockHash:blockHash];
    if (matchedRequest) {
//        DSLog(@"[%@] •••• mnlistdiff request with such a range already in retrieval: %u..%u %@ .. %@", self.chain.name, [self.store heightForBlockHash:previousBlockHash], [self.store heightForBlockHash:blockHash], uint256_hex(previousBlockHash), uint256_hex(blockHash));
        return;
    }
    uint32_t prev_h =  [self.chain heightForBlockHash:previousBlockHash];
    uint32_t h =  [self.chain heightForBlockHash:blockHash];

//    uint32_t prev_h = DHeightForBlockHash(self.chain.sharedProcessorObj, u256_ctor_u(previousBlockHash));
//    uint32_t h = DHeightForBlockHash(self.chain.sharedProcessorObj, u256_ctor_u(blockHash));
    DSLog(@"%@ Request: %u..%u %@ .. %@", self.logPrefix, prev_h, h, uint256_hex(previousBlockHash), uint256_hex(blockHash));
    if (prev_h == 0) {
        DSLog(@"%@ Zero height", self.logPrefix);
    }
    if (prev_h == 530000) {
        DSLog(@"start from checkpoint");
    }
    [self sendMasternodeListRequest:request];
}

- (void)notifyQueueChange:(NSUInteger)newCount maxAmount:(NSUInteger)maxAmount {
    DSLog(@"%@ Queue Changed: %u/%u ", self.logPrefix, (uint32_t)newCount, (uint32_t)maxAmount);
    @synchronized (self.chain.chainManager.syncState) {
        self.chain.chainManager.syncState.masternodeListSyncInfo.retrievalQueueCount = (uint32_t) newCount;
        self.chain.chainManager.syncState.masternodeListSyncInfo.retrievalQueueMaxAmount = (uint32_t) maxAmount;
        [self.chain.chainManager notifySyncStateChanged];
    }

}

/// test-only
/// Used for fast obtaining list diff chain for specific block hashes like this:
/// //DSMasternodeListDiffService *service = self.masternodeListDiffService;
//    [service sendReversedHashes:@"00000bafbc94add76cb75e2ec92894837288a481e5c005f6563d91623bf8bc2c" blockHash:@"000000e6b51b9aba9754e6b4ef996ef1d142d6cfcc032c1fd7fc78ca6663ee0a"];
//    [service sendReversedHashes:@"000000e6b51b9aba9754e6b4ef996ef1d142d6cfcc032c1fd7fc78ca6663ee0a" blockHash:@"00000009d7c0bcb59acf741f25239f45820eea178b74597d463ca80e104f753b"];

//-(void)sendReversedHashes:(NSString *)baseBlockHash blockHash:(NSString *)blockHash {
//    DSGetMNListDiffRequest *request = [DSGetMNListDiffRequest requestWithBaseBlockHash:baseBlockHash.hexToData.reverse.UInt256
//                                                                             blockHash:blockHash.hexToData.reverse.UInt256];
//    [self sendMasternodeListRequest:request];
//}

@end
