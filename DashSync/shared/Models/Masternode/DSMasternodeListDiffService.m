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

#import "DSGetMNListDiffRequest.h"
#import "DSMasternodeListDiffService.h"
#import "DSMasternodeListService+Protected.h"
#import "DSMasternodeListStore+Protected.h"
#import "NSString+Dash.h"

@implementation DSMasternodeListDiffService

- (void)composeMasternodeListRequest:(NSOrderedSet<NSData *> *)list {
    for (NSData *blockHashData in list) {
        // we should check the associated block still exists
        if ([self.store hasBlockForBlockHash:blockHashData]) {
            //there is the rare possibility we have the masternode list as a checkpoint, so lets first try that
            NSUInteger pos = [list indexOfObject:blockHashData];
            UInt256 blockHash = blockHashData.UInt256;
            DSMasternodeList *masternodeList = [self.delegate masternodeListSerivceDidRequestFileFromBlockHash:self blockHash:blockHash];
            if (masternodeList) {
                [self removeFromRetrievalQueue:blockHashData];
                [self checkWaitingForQuorums];
            } else {
                // we need to go get it
                UInt256 prevKnownBlockHash = [self.store closestKnownBlockHashForBlockHash:blockHash];
                UInt256 prevInQueueBlockHash = (pos ? [list objectAtIndex:pos - 1].UInt256 : UINT256_ZERO);
                UInt256 previousBlockHash = pos
                    ? ([self.store heightForBlockHash:prevKnownBlockHash] > [self.store heightForBlockHash:prevInQueueBlockHash]
                       ? prevKnownBlockHash
                       : prevInQueueBlockHash)
                    : prevKnownBlockHash;
                // request at: every new block
                NSAssert(([self.store heightForBlockHash:previousBlockHash] != UINT32_MAX) || uint256_is_zero(previousBlockHash), @"This block height should be known");
                [self requestMasternodeListDiff:previousBlockHash forBlockHash:blockHash];
            }
        } else {
            DSLog(@"Missing block (%@)", blockHashData.hexString);
            [self removeFromRetrievalQueue:blockHashData];
        }
    }
}

- (void)requestMasternodeListDiff:(UInt256)previousBlockHash forBlockHash:(UInt256)blockHash {
    DSGetMNListDiffRequest *request = [DSGetMNListDiffRequest requestWithBaseBlockHash:previousBlockHash blockHash:blockHash];
    DSMasternodeListRequest *matchedRequest = [self requestInRetrievalFor:previousBlockHash blockHash:blockHash];
    if (matchedRequest) {
        NSLog(@"•••• mnlistdiff request with such a range already in retrieval: %u..%u %@ .. %@", [self.store heightForBlockHash:previousBlockHash], [self.store heightForBlockHash:blockHash], uint256_hex(previousBlockHash), uint256_hex(blockHash));
        return;
    }
    NSLog(@"•••• requestMasternodeListDiff: %u..%u %@ .. %@", [self.store heightForBlockHash:previousBlockHash], [self.store heightForBlockHash:blockHash], uint256_hex(previousBlockHash), uint256_hex(blockHash));
    [self sendMasternodeListRequest:request];
}

/// test-only
/// Used for fast obtaining list diff chain for specific block hashes like this:
/// //DSMasternodeListDiffService *service = self.masternodeListDiffService;
//    [service sendReversedHashes:@"00000bafbc94add76cb75e2ec92894837288a481e5c005f6563d91623bf8bc2c" blockHash:@"000000e6b51b9aba9754e6b4ef996ef1d142d6cfcc032c1fd7fc78ca6663ee0a"];
//    [service sendReversedHashes:@"000000e6b51b9aba9754e6b4ef996ef1d142d6cfcc032c1fd7fc78ca6663ee0a" blockHash:@"00000009d7c0bcb59acf741f25239f45820eea178b74597d463ca80e104f753b"];

-(void)sendReversedHashes:(NSString *)baseBlockHash blockHash:(NSString *)blockHash {
    DSGetMNListDiffRequest *request = [DSGetMNListDiffRequest requestWithBaseBlockHash:baseBlockHash.hexToData.reverse.UInt256
                                                                             blockHash:blockHash.hexToData.reverse.UInt256];
    [self sendMasternodeListRequest:request];
}

@end
