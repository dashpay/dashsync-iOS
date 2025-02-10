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
#import "DSGetQRInfoRequest.h"
#import "DSQuorumRotationService.h"
#import "DSMasternodeListService+Protected.h"
#import "DSMasternodeListStore+Protected.h"

@implementation DSQuorumRotationService

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
        DSLog(@"[%@] Missing block (%@)", self.chain.name, blockHashData.hexString);
        DQrInfoQueueRemove(self.chain.shareCore.processor->obj, u256_ctor(blockHashData));
    }
}
- (indexmap_IndexSet_u8_32 *)retrievalQueue {
    return dash_spv_masternode_processor_processing_processor_cache_MasternodeProcessorCache_qr_info_retrieval_queue(self.chain.shareCore.cache->obj);
}

- (NSUInteger)retrievalQueueCount {
    return DQrInfoQueueCount(self.chain.shareCore.cache->obj);
}
- (NSUInteger)retrievalQueueMaxAmount {
    return DQrInfoQueueMaxAmount(self.chain.shareCore.cache->obj);
}
- (BOOL)hasLatestBlockInRetrievalQueueWithHash:(UInt256)blockHash {
    return dash_spv_masternode_processor_processing_processor_cache_MasternodeProcessorCache_has_latest_block_in_qr_info_retrieval_queue_with_hash(self.chain.shareCore.cache->obj, u256_ctor_u(blockHash));
}
- (void)removeFromRetrievalQueue:(NSData *)masternodeBlockHashData {
    DQrInfoQueueRemove(self.chain.shareCore.processor->obj, u256_ctor(masternodeBlockHashData));
}
- (void)cleanListsRetrievalQueue {
    DQrInfoQueueClean(self.chain.shareCore.processor->obj);
}
//- (void)getRecentMasternodeList {
//    DSMerkleBlock *merkleBlock = [self.chain blockFromChainTip:0];
//    if (!merkleBlock) {
//        // sometimes it happens while rescan
//        DSLog(@"[%@] getRecentMasternodeList: (no block exist) for tip", self.chain.name);
//        return;
//    }
//    u256 *block_hash = u256_ctor_u(merkleBlock.blockHash);
//    DBlock *block = DBlockCtor(merkleBlock.height, block_hash);
//    dash_spv_masternode_processor_processing_processor_MasternodeProcessor_get_recent_qr_info(self.chain.shareCore.processor->obj, block);
//}

- (void)requestQuorumRotationInfo:(UInt256)previousBlockHash forBlockHash:(UInt256)blockHash {
    // TODO: optimize qrinfo request queue (up to 4 blocks simultaneously, so we'd make masternodeListsToRetrieve.count%4)
    // blockHeight % dkgInterval == activeSigningQuorumsCount + 11 + 8
    DSMasternodeListRequest *matchedRequest = [self requestInRetrievalFor:previousBlockHash blockHash:blockHash];
    if (matchedRequest) {
        DSLog(@"[%@] •••• qrinfo request with such a range already in retrieval: %@ .. %@", self.chain.name,  uint256_hex(previousBlockHash), uint256_hex(blockHash));
        return;
    }
    NSArray<NSData *> *baseBlockHashes = @[[NSData dataWithUInt256:previousBlockHash]];
    DSGetQRInfoRequest *request = [DSGetQRInfoRequest requestWithBaseBlockHashes:baseBlockHashes blockHash:blockHash extraShare:YES];
    uint32_t prev_h = DHeightForBlockHash(self.chain.shareCore.processor->obj, u256_ctor_u(previousBlockHash));
    uint32_t h = DHeightForBlockHash(self.chain.shareCore.processor->obj, u256_ctor_u(blockHash));
    DSLog(@"[%@] •••• requestQuorumRotationInfo: %u..%u %@ .. %@", self.chain.name, prev_h, h, uint256_hex(previousBlockHash), uint256_hex(blockHash));
    [self sendMasternodeListRequest:request];
}

@end
