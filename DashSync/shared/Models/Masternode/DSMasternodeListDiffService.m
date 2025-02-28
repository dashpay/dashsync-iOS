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
#import "DSGetMNListDiffRequest.h"
#import "DSMasternodeListDiffService.h"
#import "DSMasternodeListStore+Protected.h"
#import "DSMasternodeManager+Protected.h"
#import "NSString+Dash.h"

@implementation DSMasternodeListDiffService

- (NSString *)logPrefix {
    return [NSString stringWithFormat:@"[%@] [MLDiffService] ", self.chain.name];
}

- (void)composeMasternodeListRequest:(NSOrderedSet<NSData *> *)list {
    for (NSData *blockHashData in list) {
        // we should check the associated block still exists
        if ([self.chain.masternodeManager.store hasBlockForBlockHash:blockHashData]) {
            //there is the rare possibility we have the masternode list as a checkpoint, so lets first try that
            NSUInteger pos = [list indexOfObject:blockHashData];
            UInt256 blockHash = blockHashData.UInt256;
            BOOL success = [self.chain.masternodeManager processRequestFromFileForBlockHash:blockHash];
            if (success) {
                [self removeFromRetrievalQueue:blockHashData];
                [self checkWaitingForQuorums];
            } else {
                // we need to go get it
                UInt256 prevKnownBlockHash = [self.chain.masternodeManager.store closestKnownBlockHashForBlockHash:blockHash];
                UInt256 prevInQueueBlockHash = (pos ? [list objectAtIndex:pos - 1].UInt256 : UINT256_ZERO);
                u256 *prev_known_block_hash = u256_ctor_u(prevKnownBlockHash);
                u256 *prev_in_queue_block_hash = u256_ctor_u(prevInQueueBlockHash);
                uint32_t prevKnownHeight = DHeightForBlockHash(self.chain.sharedProcessorObj, prev_known_block_hash);
                uint32_t prevInQueueBlockHeight = DHeightForBlockHash(self.chain.sharedProcessorObj, prev_in_queue_block_hash);
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

- (void)requestMasternodeListDiff:(UInt256)previousBlockHash forBlockHash:(UInt256)blockHash {
    DSGetMNListDiffRequest *request = [DSGetMNListDiffRequest requestWithBaseBlockHash:previousBlockHash blockHash:blockHash];
    DSMasternodeListRequest *matchedRequest = [self requestInRetrievalFor:previousBlockHash blockHash:blockHash];
    if (matchedRequest) {
//        DSLog(@"[%@] •••• mnlistdiff request with such a range already in retrieval: %u..%u %@ .. %@", self.chain.name, [self.store heightForBlockHash:previousBlockHash], [self.store heightForBlockHash:blockHash], uint256_hex(previousBlockHash), uint256_hex(blockHash));
        return;
    }
    uint32_t prev_h = DHeightForBlockHash(self.chain.sharedProcessorObj, u256_ctor_u(previousBlockHash));
    uint32_t h = DHeightForBlockHash(self.chain.sharedProcessorObj, u256_ctor_u(blockHash));
    DSLog(@"%@ Request: %u..%u %@ .. %@", self.logPrefix, prev_h, h, uint256_hex(previousBlockHash), uint256_hex(blockHash));
    if (prev_h == 0) {
        DSLog(@"%@ Zero height", self.logPrefix);
    }
    if (prev_h == 530000) {
        DSLog(@"start from checkpoint");
    }
    [self sendMasternodeListRequest:request];
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
