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

- (DSMasternodeList *)currentMasternodeList {
    return self.masternodeListAtTip;
}

- (void)composeMasternodeListRequest:(NSOrderedSet<NSData *> *)list {
    NSData *blockHashData = [list lastObject];
    if (!blockHashData) {
        return;
    }
    if ([self.store hasBlockForBlockHash:blockHashData]) {
        UInt256 blockHash = blockHashData.UInt256;
        UInt256 previousBlockHash = [self.store closestKnownBlockHashForBlockHash:blockHash];
        NSAssert(([self.store heightForBlockHash:previousBlockHash] != UINT32_MAX) || uint256_is_zero(previousBlockHash), @"This block height should be known");
        [self requestQuorumRotationInfo:previousBlockHash forBlockHash:blockHash];
    } else {
        DSLog(@"Missing block (%@)", blockHashData.hexString);
        [self removeFromRetrievalQueue:blockHashData];
    }
    /*
    NSMutableDictionary<NSData *, NSData *> *hashes = [NSMutableDictionary dictionary];
    for (NSData *blockHashData in list) {
        // we should check the associated block still exists
        if ([self.store hasBlockForBlockHash:blockHashData]) {
            //there is the rare possibility we have the masternode list as a checkpoint, so lets first try that
            NSUInteger pos = [list indexOfObject:blockHashData];
            UInt256 blockHash = blockHashData.UInt256;
            // No checkpoints for qrinfo at this moment
            UInt256 prevKnownBlockHash = [self.store closestKnownBlockHashForBlockHash:blockHash];
            UInt256 prevInQueueBlockHash = (pos ? [list objectAtIndex:pos - 1].UInt256 : UINT256_ZERO);
            UInt256 previousBlockHash = pos
                ? ([self.store heightForBlockHash:prevKnownBlockHash] > [self.store heightForBlockHash:prevInQueueBlockHash]
                   ? prevKnownBlockHash
                   : prevInQueueBlockHash)
                : prevKnownBlockHash;
            [hashes setObject:uint256_data(blockHash) forKey:uint256_data(previousBlockHash)];
            NSAssert(([self.store heightForBlockHash:previousBlockHash] != UINT32_MAX) || uint256_is_zero(previousBlockHash), @"This block height should be known");
            [self requestQuorumRotationInfo:previousBlockHash forBlockHash:blockHash];
        } else {
            DSLog(@"Missing block (%@)", blockHashData.hexString);
            [self removeFromRetrievalQueue:blockHashData];
        }
    }*/
}


- (void)getRecentMasternodeList {
    @synchronized(self.retrievalQueue) {
        DSMerkleBlock *merkleBlock = [self.chain blockFromChainTip:0];
        if (!merkleBlock) {
            // sometimes it happens while rescan
            DSLog(@"getRecentMasternodeList: (no block exist) for tip");
            return;
        }
        UInt256 merkleBlockHash = merkleBlock.blockHash;
        if ([self hasLatestBlockInRetrievalQueueWithHash:merkleBlockHash]) {
            //we are asking for the same as the last one
            return;
        }
        uint32_t lastHeight = merkleBlock.height;
        DKGParams dkgParams = self.chain.isDevnetAny ? DKG_DEVNET_DIP_0024 : DKG_60_75;
        uint32_t rotationOffset = dkgParams.mining_window_end;
        uint32_t updateInterval = dkgParams.interval;
        BOOL needUpdate = !self.masternodeListAtH || [self.masternodeListAtH hasUnverifiedRotatedQuorums] ||
        (lastHeight % updateInterval == rotationOffset && lastHeight >= [self.store heightForBlockHash:self.masternodeListAtH.blockHash] + rotationOffset);
        if (needUpdate && [self.store addBlockToValidationQueue:merkleBlock]) {
            DSLog(@"QuorumRotationService.Getting masternode list %u", merkleBlock.height);
            NSData *merkleBlockHashData = uint256_data(merkleBlockHash);
            BOOL emptyRequestQueue = ![self retrievalQueueCount];
            [self addToRetrievalQueue:merkleBlockHashData];
            if (emptyRequestQueue) {
                [self dequeueMasternodeListRequest];
            }
        }
    }
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
