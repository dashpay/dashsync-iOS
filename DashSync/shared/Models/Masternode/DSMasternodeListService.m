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

#import "DSMasternodeListService.h"
#import "DSChain+Protected.h"
#import "DSChainManager.h"
#import "DSGetMNListDiffRequest.h"
#import "DSGetQRInfoRequest.h"
#import "DSPeerManager+Protected.h"
#import "NSData+Dash.h"

@interface DSMasternodeListService ()
// List<UInt256> Hashes of blocks for which masternode lists are need to be requested
@property (nonatomic, strong) NSMutableOrderedSet<NSData *> *retrievalQueue;
@property (nonatomic, strong) NSMutableOrderedSet<NSData *> *neededQueue;
@property (nonatomic, assign) NSUInteger retrievalQueueMaxAmount;
// List<UInt512>: list of block ranges baseBlockHash + blockHash
@property (nonatomic, strong) NSMutableSet<DSMasternodeListRequest *> *requestsInRetrieval;
@property (nonatomic, copy) BlockHeightFinder blockHeightLookup;

@end

@implementation DSMasternodeListService

- (instancetype)initWithChain:(DSChain *)chain blockHeightLookup:(BlockHeightFinder)blockHeightLookup {
    NSParameterAssert(chain);
    if (!(self = [super init])) return nil;
    _chain = chain;
    _blockHeightLookup = blockHeightLookup;
    _retrievalQueue = [NSMutableOrderedSet orderedSet];
    _requestsInRetrieval = [NSMutableSet set];
    return self;
}

- (void)addToRetrievalQueue:(NSData *)masternodeBlockHashData {
    NSAssert(uint256_is_not_zero(masternodeBlockHashData.UInt256), @"the hash data must not be empty");
    DSLog(@"••• addToRetrievalQueue: %d:%@", self.blockHeightLookup(masternodeBlockHashData.UInt256), masternodeBlockHashData.hexString);
    [self.retrievalQueue addObject:masternodeBlockHashData];
    [self updateMasternodeRetrievalQueue];
}

- (void)addToRetrievalQueueArray:(NSArray<NSData *> *)masternodeBlockHashDataArray {
    NSMutableArray *nonEmptyBlockHashes = [NSMutableArray array];
    for (NSData *blockHashData in masternodeBlockHashDataArray) {
        NSAssert(uint256_is_not_zero(blockHashData.UInt256), @"We should not be adding an empty block hash");
        if (uint256_is_not_zero(blockHashData.UInt256)) {
            DSLog(@"••• addToRetrievalQueueArray...: %d:%@", self.blockHeightLookup(blockHashData.UInt256), blockHashData.hexString);
            [nonEmptyBlockHashes addObject:blockHashData];
        }
    }
    [self.retrievalQueue addObjectsFromArray:nonEmptyBlockHashes];
    [self updateMasternodeRetrievalQueue];
}

- (void)removeFromRetrievalQueue:(NSData *)masternodeBlockHashData {
    DSLog(@"••• removeFromRetrievalQueue %d: %@", self.blockHeightLookup(masternodeBlockHashData.UInt256), masternodeBlockHashData.hexString);
    [self.retrievalQueue removeObject:masternodeBlockHashData];
}

- (void)cleanRequestsInRetrieval {
    DSLog(@"••• cleanRequestsInRetrieval");
    [self.requestsInRetrieval removeAllObjects];
}

- (void)cleanListsRetrievalQueue {
    [self.retrievalQueue removeAllObjects];
}

- (void)cleanAllLists {
    [self cleanListsRetrievalQueue];
    [self cleanRequestsInRetrieval];
}

- (DSPeerManager *)peerManager {
    return self.chain.chainManager.peerManager;
}

- (NSUInteger)retrievalQueueCount {
    return self.retrievalQueue.count;
}

- (void)updateMasternodeRetrievalQueue {
    self.retrievalQueueMaxAmount = MAX(self.retrievalQueueMaxAmount, self.retrievalQueue.count);
    [self.retrievalQueue sortUsingComparator:^NSComparisonResult(NSData *_Nonnull obj1, NSData *_Nonnull obj2) {
        return self.blockHeightLookup(obj1.UInt256) < self.blockHeightLookup(obj2.UInt256) ? NSOrderedAscending : NSOrderedDescending;
    }];
}

- (void)fetchMasternodeListsToRetrieve:(void (^)(NSOrderedSet<NSData *> *listsToRetrieve))completion {
    if (![self.retrievalQueue count]) {
        DSLog(@"No masternode lists in retrieval");
        [self.chain.chainManager chainFinishedSyncingMasternodeListsAndQuorums:self.chain];
        return;
    }
    if ([self.requestsInRetrieval count]) {
        DSLog(@"A masternode list is already in retrieval");
        return;
    }
    if (!self.peerManager.downloadPeer || (self.peerManager.downloadPeer.status != DSPeerStatus_Connected)) {
        if (self.chain.chainManager.syncPhase != DSChainSyncPhase_Offline) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), self.chain.networkingQueue, ^{
                [self fetchMasternodeListsToRetrieve:completion];
            });
        }
        return;
    }
    completion([self.retrievalQueue copy]);
}

- (BOOL)removeRequestInRetrievalForBaseBlockHash:(UInt256)baseBlockHash blockHash:(UInt256)blockHash {
    DSLog(@"••• removeRequestInRetrievalFor: [%@; %@]", uint256_hex(blockHash), uint256_hex(blockHash));
    DSMasternodeListRequest *matchedRequest = nil;
    for (DSMasternodeListRequest *request in self.requestsInRetrieval) {
        if ([request matchesInRangeWithBaseBlockHash:baseBlockHash blockHash:blockHash]) {
            matchedRequest = request;
            break;
        }
    }
    if (!matchedRequest) {
         NSMutableArray *requestsInRetrievalStrings = [NSMutableArray array];
         for (DSMasternodeListRequest *requestInRetrieval in self.requestsInRetrieval) {
             [requestsInRetrievalStrings addObject:[requestInRetrieval toData].hexString];
         }
         DSLog(@"A masternode list ([%@; %@]) was received that is not set to be retrieved (%@)", uint256_hex(baseBlockHash), uint256_hex(blockHash), [requestsInRetrievalStrings componentsJoinedByString:@", "]);
         return NO;
     }
    [self.requestsInRetrieval removeObject:matchedRequest];
    return YES;
}

- (BOOL)hasLatestBlockInRetrievalQueueWithHash:(UInt256)blockHash {
    return [self.retrievalQueue lastObject] && uint256_eq(blockHash, [self.retrievalQueue lastObject].UInt256);
}

- (void)disconnectFromDownloadPeer {
    [self.peerManager.downloadPeer disconnect];
}

- (void)issueWithMasternodeListFromPeer:(DSPeer *)peer {
    [self.peerManager peerMisbehaving:peer errorMessage:@"Issue with Deterministic Masternode list"];
}

- (void)requestMasternodeListDiff:(UInt256)previousBlockHash forBlockHash:(UInt256)blockHash {
    DSGetMNListDiffRequest *request = [DSGetMNListDiffRequest requestWithBaseBlockHash:previousBlockHash blockHash:blockHash];
    [self sendMasternodeListRequest:request];
}

- (void)requestQuorumRotationInfo:(UInt256)previousBlockHash forBlockHash:(UInt256)blockHash {
    // TODO: optimize qrinfo request queue (up to 4 blocks simultaneously, so we'd make masternodeListsToRetrieve.count%4)
    // blockHeight % dkgInterval == activeSigningQuorumsCount + 11 + 8
    
    NSArray<NSData *> *baseBlockHashes = @[[NSData dataWithUInt256:previousBlockHash]];
    DSGetQRInfoRequest *request = [DSGetQRInfoRequest requestWithBaseBlockHashes:baseBlockHashes blockHash:blockHash extraShare:YES];
    [self sendMasternodeListRequest:request];
}

- (void)sendMasternodeListRequest:(DSMasternodeListRequest *)request {
    //DSLog(@"••• sendMasternodeListRequest: %@", [request toData].hexString);
    [self.peerManager sendRequest:request];
    [self.requestsInRetrieval addObject:request];
}

@end
