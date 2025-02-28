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
#import "DSGetQRInfoRequest.h"
#import "DSQuorumRotationService.h"
#import "DSMasternodeListService+Protected.h"
#import "DSMasternodeListStore+Protected.h"

@implementation DSQuorumRotationService

- (NSString *)logPrefix {
    return [NSString stringWithFormat:@"[%@] [QRInfoService] ", self.chain.name];
}

- (void)composeMasternodeListRequest:(NSOrderedSet<NSData *> *)list {
    NSData *blockHashData = [list lastObject];
    if (!blockHashData) {
        return;
    }
    if ([self.store hasBlockForBlockHash:blockHashData]) {
        UInt256 blockHash = blockHashData.UInt256;
        UInt256 previousBlockHash = [self.store closestKnownBlockHashForBlockHash:blockHash];
//        NSAssert(([self.store heightForBlockHash:previousBlockHash] != UINT32_MAX) || uint256_is_zero(previousBlockHash), @"This block height should be known");
        [self requestQuorumRotationInfo:previousBlockHash forBlockHash:blockHash];
    } else {
        DSLog(@"%@ Missing block: %@ (%@)", self.logPrefix, blockHashData.hexString, blockHashData.reverse.hexString);
        DQrInfoQueueRemove(self.chain.sharedProcessorObj, u256_ctor(blockHashData));
    }
}

- (void)fetchMasternodeListsToRetrieve:(void (^)(NSOrderedSet<NSData *> *listsToRetrieve))completion {
    if ([self.requestsInRetrieval count]) {
        DSLog(@"%@ A masternode list is already in retrieval", self.logPrefix);
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

- (NSOrderedSet<NSData *> *)retrievalQueue {
    indexmap_IndexSet_u8_32 *queue = dash_spv_masternode_processor_processing_processor_cache_MasternodeProcessorCache_qr_info_retrieval_queue(self.chain.sharedCacheObj);
    NSMutableOrderedSet *set = [NSMutableOrderedSet orderedSetWithCapacity:queue->count];
    for (int i = 0; i < queue->count; i++) {
        [set addObject:NSDataFromPtr(queue->values[i])];
    }
    indexmap_IndexSet_u8_32_destroy(queue);
    return [set copy];
}

- (NSUInteger)retrievalQueueCount {
    return DQrInfoQueueCount(self.chain.sharedCacheObj);
}
- (NSUInteger)retrievalQueueMaxAmount {
    return DQrInfoQueueMaxAmount(self.chain.sharedCacheObj);
}

- (void)removeFromRetrievalQueue:(NSData *)masternodeBlockHashData {
    DQrInfoQueueRemove(self.chain.sharedProcessorObj, u256_ctor(masternodeBlockHashData));
}
- (void)cleanListsRetrievalQueue {
    DQrInfoQueueClean(self.chain.sharedProcessorObj);
}

- (void)requestQuorumRotationInfo:(UInt256)previousBlockHash forBlockHash:(UInt256)blockHash {
    // TODO: optimize qrinfo request queue (up to 4 blocks simultaneously, so we'd make masternodeListsToRetrieve.count%4)
    // blockHeight % dkgInterval == activeSigningQuorumsCount + 11 + 8
    DSMasternodeListRequest *matchedRequest = [self requestInRetrievalFor:previousBlockHash blockHash:blockHash];
    if (matchedRequest) {
        DSLog(@"%@ Request: already in retrieval: %@ .. %@", self.logPrefix,  uint256_hex(previousBlockHash), uint256_hex(blockHash));
        return;
    }
    NSArray<NSData *> *baseBlockHashes = @[[NSData dataWithUInt256:previousBlockHash]];
    DSGetQRInfoRequest *request = [DSGetQRInfoRequest requestWithBaseBlockHashes:baseBlockHashes blockHash:blockHash extraShare:YES];
    uint32_t prev_h = DHeightForBlockHash(self.chain.sharedProcessorObj, u256_ctor_u(previousBlockHash));
    uint32_t h = DHeightForBlockHash(self.chain.sharedProcessorObj, u256_ctor_u(blockHash));
    DSLog(@"%@ Request: %u..%u %@ .. %@", self.logPrefix, prev_h, h, uint256_hex(previousBlockHash), uint256_hex(blockHash));
    [self sendMasternodeListRequest:request];
}

@end
