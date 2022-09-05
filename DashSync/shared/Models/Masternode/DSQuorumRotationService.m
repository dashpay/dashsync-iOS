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

#import "DSGetQRInfoRequest.h"
#import "DSQuorumRotationService.h"
#import "DSMasternodeListService+Protected.h"
#import "DSMasternodeListStore+Protected.h"

@implementation DSQuorumRotationService

- (void)composeMasternodeListRequest:(NSOrderedSet<NSData *> *)list {
    NSMutableDictionary<NSData *, NSData *> *hashes = [NSMutableDictionary dictionary];
    for (NSData *blockHashData in list) {
        // we should check the associated block still exists
        if ([self.store hasBlockForBlockHash:blockHashData]) {
            //there is the rare possibility we have the masternode list as a checkpoint, so lets first try that
            NSUInteger pos = [list indexOfObject:blockHashData];
            UInt256 blockHash = blockHashData.UInt256;
            DSMasternodeList *masternodeList = [self.delegate masternodeListSerivceDidRequestFileFromBlockHash:self blockHash:blockHash];
            NSLog(@"•••• -> masternode list at [%u: %@] in files found: (%@)",[self.delegate masternodeListSerivceDidRequestHeightForBlockHash:self blockHash:blockHash], uint256_hex(blockHash), masternodeList);
            if (masternodeList) {
                if (uint256_eq(self.store.lastQueriedBlockHash, masternodeList.blockHash)) {
                    [self.store removeOldMasternodeLists];
                }
                [self removeFromRetrievalQueue:blockHashData];
                [self checkWaitingForQuorums];
            } else {
                // we need to go get it
                UInt256 prevKnownBlockHash = [self.store closestKnownBlockHashForBlockHash:blockHash];
                UInt256 prevInQueueBlockHash = (pos ? [list objectAtIndex:pos - 1].UInt256 : UINT256_ZERO);
                UInt256 previousBlockHash = pos
                    ? ([self.delegate masternodeListSerivceDidRequestHeightForBlockHash:self blockHash:prevKnownBlockHash] > [self.delegate masternodeListSerivceDidRequestHeightForBlockHash:self blockHash:prevInQueueBlockHash]
                       ? prevKnownBlockHash
                       : prevInQueueBlockHash)
                    : prevKnownBlockHash;
                [hashes setObject:uint256_data(blockHash) forKey:uint256_data(previousBlockHash)];
                NSAssert(([self.delegate masternodeListSerivceDidRequestHeightForBlockHash:self blockHash:previousBlockHash] != UINT32_MAX) || uint256_is_zero(previousBlockHash), @"This block height should be known");
                [self requestQuorumRotationInfo:previousBlockHash forBlockHash:blockHash];
            }
        } else {
            DSLog(@"Missing block (%@)", blockHashData.hexString);
            [self removeFromRetrievalQueue:blockHashData];
        }
    }
    
//    [self requestQuorumRotationInfo2:<#(NSArray<NSData *> *)#> forBlockHash:<#(UInt256)#>]
    
    //[self requestQuorumRotationInfo:previousBlockHash forBlockHash:blockHash];
}

- (void)requestQuorumRotationInfo:(UInt256)previousBlockHash forBlockHash:(UInt256)blockHash {
    // TODO: optimize qrinfo request queue (up to 4 blocks simultaneously, so we'd make masternodeListsToRetrieve.count%4)
    // blockHeight % dkgInterval == activeSigningQuorumsCount + 11 + 8
    DSMasternodeListRequest *matchedRequest = [self requestInRetrievalFor:previousBlockHash blockHash:blockHash];
    if (matchedRequest) {
        NSLog(@"•••• qrinfo request with such a range already in retrieval: %u..%u %@ .. %@", [self.delegate masternodeListSerivceDidRequestHeightForBlockHash:self blockHash:previousBlockHash], [self.delegate masternodeListSerivceDidRequestHeightForBlockHash:self blockHash:blockHash], uint256_hex(previousBlockHash), uint256_hex(blockHash));
        return;
    }
    NSArray<NSData *> *baseBlockHashes = @[[NSData dataWithUInt256:previousBlockHash]];
    DSGetQRInfoRequest *request = [DSGetQRInfoRequest requestWithBaseBlockHashes:baseBlockHashes blockHash:blockHash extraShare:YES];
    NSLog(@"•••• requestQuorumRotationInfo: %u..%u %@ .. %@", [self.delegate masternodeListSerivceDidRequestHeightForBlockHash:self blockHash:previousBlockHash], [self.delegate masternodeListSerivceDidRequestHeightForBlockHash:self blockHash:blockHash], uint256_hex(previousBlockHash), uint256_hex(blockHash));
    [self sendMasternodeListRequest:request];
}

- (void)requestQuorumRotationInfo2:(NSArray<NSData *> *)previousBlockHashes forBlockHash:(UInt256)blockHash {
    // TODO: optimize qrinfo request queue (up to 4 blocks simultaneously, so we'd make masternodeListsToRetrieve.count%4)
    // blockHeight % dkgInterval == activeSigningQuorumsCount + 11 + 8
//    DSMasternodeListRequest *matchedRequest = [self requestInRetrievalFor:previousBlockHash blockHash:blockHash];
//    if (matchedRequest) {
//        NSLog(@"•••• qrinfo request with such a range already in retrieval: %u..%u %@ .. %@", self.blockHeightLookup(previousBlockHash), self.blockHeightLookup(blockHash), uint256_hex(previousBlockHash), uint256_hex(blockHash));
//        return;
//    }
//    NSArray<NSData *> *baseBlockHashes = @[[NSData dataWithUInt256:previousBlockHash]];
//    NSMutableSet<NSString *> *log = [NSMutableSet set];
    NSMutableString *log = [NSMutableString stringWithFormat:@""];
    for (NSData *baseBlockHashData in previousBlockHashes) {
        [log appendString:[NSString stringWithFormat:@"%u, ", [self.delegate masternodeListSerivceDidRequestHeightForBlockHash:self blockHash:baseBlockHashData.UInt256]]];
    }
    DSGetQRInfoRequest *request = [DSGetQRInfoRequest requestWithBaseBlockHashes:previousBlockHashes blockHash:blockHash extraShare:YES];
    NSLog(@"•••• requestQuorumRotationInfo: %@: .. %d", log, [self.delegate masternodeListSerivceDidRequestHeightForBlockHash:self blockHash:blockHash]);
    [self sendMasternodeListRequest:request];
}
@end
