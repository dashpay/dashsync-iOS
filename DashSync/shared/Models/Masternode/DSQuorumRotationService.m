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
#import "DSMasternodeManager.h"
#import "NSString+Bitcoin.h"

@interface DSQuorumRotationService ()

@property (nonatomic, strong, nullable) NSData *retrievalBlockHash;

@end

@implementation DSQuorumRotationService

- (NSString *)logPrefix {
    return [NSString stringWithFormat:@"[%@] [MasternodeManager::QRInfoService]", self.chain.name];
}

- (BOOL)hasRecentQrInfoSync {
    return ([[NSDate date] timeIntervalSince1970] - self.lastSyncedTimestamp < 30);
}


- (void)composeMasternodeListRequest:(NSData *)blockHashData {
    if (!blockHashData) {
        return;
    }
    if ([self hasBlockForBlockHash:blockHashData]) {
        UInt256 blockHash = blockHashData.UInt256;
        uint32_t blockHeight = [self.chain heightForBlockHash:blockHash];
        UInt256 previousBlockHash = [self closestKnownBlockHashForBlockHeight:blockHeight];
//        NSAssert(([self.store heightForBlockHash:previousBlockHash] != UINT32_MAX) || uint256_is_zero(previousBlockHash), @"This block height should be known");
        if (uint256_eq(previousBlockHash, blockHash)) {
            self.retrievalBlockHash = nil;
            self.retrievalQueueMaxAmount = 0;
        } else {
            [self requestQuorumRotationInfo:previousBlockHash forBlockHash:blockHash];
        }
    } else {
        DSLog(@"%@ Missing block: %@ (%@)", self.logPrefix, blockHashData.hexString, blockHashData.reverse.hexString);
        self.retrievalBlockHash = nil;
        self.retrievalQueueMaxAmount = 0;
    }
}

- (void)dequeueMasternodeListRequest {
    [self fetchMasternodeListToRetrieve:^(NSData *blockHashData) {
        [self composeMasternodeListRequest:blockHashData];
        [self startTimeOutObserver];
    }];
}

- (void)fetchMasternodeListToRetrieve:(void (^)(NSData *listsToRetrieve))completion {
    //DSLog(@"%@ fetchMasternodeListToRetrieve...: %u", self.logPrefix, [self hasActiveQueue]);
    if (![self hasActiveQueue]) {
        //DSLog(@"%@ No masternode lists in retrieval", self.logPrefix);
        dispatch_async(self.chain.networkingQueue, ^{
            [self.chain.chainManager.syncState.masternodeListSyncInfo removeSyncKind:DSMasternodeListSyncStateKind_QrInfo];
            [self.chain.masternodeManager masternodeListServiceEmptiedRetrievalQueue:self];
        });
        return;
    }
    if ([self.requestsInRetrieval count]) {
        //DSLog(@"%@ A masternode list is already in retrieval", self.logPrefix);
        return;
    }
    if ([self peerIsDisconnected]) {
        if (self.chain.chainManager.syncPhase != DSChainSyncPhase_Offline) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), self.chain.networkingQueue, ^{
                [self fetchMasternodeListToRetrieve:completion];
            });
        }
        return;
    }
    completion([self.retrievalBlockHash copy]);
}

- (void)getRecent:(NSData *)blockHash {
    self.retrievalQueueMaxAmount = 1;
    self.retrievalBlockHash = blockHash;
    [self dequeueMasternodeListRequest];
}

- (void)cleanListsRetrievalQueue {
    self.retrievalQueueMaxAmount = 0;
    self.retrievalBlockHash = nil;
}
- (BOOL)hasActiveQueue {
    return self.retrievalBlockHash != nil;
}
- (void)requestQuorumRotationInfo:(UInt256)previousBlockHash forBlockHash:(UInt256)blockHash {
    // TODO: optimize qrinfo request queue (up to 4 blocks simultaneously, so we'd make masternodeListsToRetrieve.count%4)
    // blockHeight % dkgInterval == activeSigningQuorumsCount + 11 + 8
    DSMasternodeListRequest *matchedRequest = [self requestInRetrievalFor:previousBlockHash blockHash:blockHash];
    if (matchedRequest) {
        DSLog(@"%@ Request: already in retrieval: %@ .. %@", self.logPrefix,  uint256_hex(previousBlockHash), uint256_hex(blockHash));
        return;
    }
    
    NSArray<NSData *> *baseBlockHashes = self.chain.isMainnet ? @[@"989ba7a808cd8dda1755658a235b366c1496122485cdfd990800000000000000".hexToData, [NSData dataWithUInt256:previousBlockHash]] : @[[NSData dataWithUInt256:previousBlockHash]];

    DSGetQRInfoRequest *request = [DSGetQRInfoRequest requestWithBaseBlockHashes:baseBlockHashes blockHash:blockHash extraShare:YES];
    uint32_t prev_h = [self.chain heightForBlockHash:previousBlockHash];
    uint32_t h = [self.chain heightForBlockHash:blockHash];
    DSLog(@"%@ Request: %u..%u %@ .. %@", self.logPrefix, prev_h, h, uint256_hex(previousBlockHash), uint256_hex(blockHash));
    dispatch_async(self.chain.networkingQueue, ^{
        [self.chain.chainManager.syncState.masternodeListSyncInfo addSyncKind:DSMasternodeListSyncStateKind_QrInfo];
    });
    [self sendMasternodeListRequest:request];
}

@end
