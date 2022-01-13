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

#import "DSMasternodeService.h"
#import "DSChain+Protected.h"
#import "DSChainManager.h"
#import "DSPeerManager+Protected.h"
#import "NSData+Dash.h"

@interface DSMasternodeService ()
@property (nonatomic, strong) NSMutableOrderedSet<NSData *> *masternodeListRetrievalQueue;
@property (nonatomic, assign) NSUInteger masternodeListRetrievalQueueMaxAmount;
@property (nonatomic, strong) NSMutableSet<NSData *> *masternodeListsInRetrieval;
@property (nonatomic, copy) BlockHeightFinder blockHeightLookup;

@end

@implementation DSMasternodeService

- (instancetype)initWithChain:(DSChain *)chain blockHeightLookup:(BlockHeightFinder)blockHeightLookup {
    NSParameterAssert(chain);
    if (!(self = [super init])) return nil;
    _chain = chain;
    _blockHeightLookup = blockHeightLookup;
    _masternodeListRetrievalQueue = [NSMutableOrderedSet orderedSet];
    _masternodeListsInRetrieval = [NSMutableSet set];
    return self;
}

- (void)addToMasternodeRetrievalQueue:(NSData *)masternodeBlockHashData {
    NSAssert(uint256_is_not_zero(masternodeBlockHashData.UInt256), @"the hash data must not be empty");
    [self.masternodeListRetrievalQueue addObject:masternodeBlockHashData];
    [self updateMasternodeRetrievalQueue];
}

- (void)addToMasternodeRetrievalQueueArray:(NSArray *)masternodeBlockHashDataArray {
    NSMutableArray *nonEmptyBlockHashes = [NSMutableArray array];
    for (NSData *blockHashData in masternodeBlockHashDataArray) {
        NSAssert(uint256_is_not_zero(blockHashData.UInt256), @"We should not be adding an empty block hash");
        if (uint256_is_not_zero(blockHashData.UInt256)) {
            [nonEmptyBlockHashes addObject:blockHashData];
        }
    }
    [self.masternodeListRetrievalQueue addObjectsFromArray:nonEmptyBlockHashes];
    [self updateMasternodeRetrievalQueue];
}

- (void)cleanListsInRetrieval {
    [self.masternodeListsInRetrieval removeAllObjects];
}

- (void)cleanListsRetrievalQueue {
    [self.masternodeListRetrievalQueue removeAllObjects];
}

- (void)cleanAllLists {
    [self cleanListsRetrievalQueue];
    [self cleanListsInRetrieval];
}

- (DSPeerManager *)peerManager {
    return self.chain.chainManager.peerManager;
}

- (NSUInteger)masternodeListRetrievalQueueCount {
    return self.masternodeListRetrievalQueue.count;
}

- (void)blockUntilAddInsight:(UInt256)entryQuorumHash {
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    [[DSInsightManager sharedInstance] blockForBlockHash:uint256_reverse(entryQuorumHash)
                                                 onChain:self.chain
                                              completion:^(DSBlock *_Nullable block, NSError *_Nullable error) {
        if (!error && block) {
            [self.chain addInsightVerifiedBlock:block forBlockHash:entryQuorumHash];
        }
        dispatch_semaphore_signal(sem);
    }];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
}

- (void)updateMasternodeRetrievalQueue {
    self.masternodeListRetrievalQueueMaxAmount = MAX(self.masternodeListRetrievalQueueMaxAmount, self.masternodeListRetrievalQueue.count);
    [self.masternodeListRetrievalQueue sortUsingComparator:^NSComparisonResult(NSData *_Nonnull obj1, NSData *_Nonnull obj2) {
        return self.blockHeightLookup(obj1.UInt256) < self.blockHeightLookup(obj2.UInt256)
        ? NSOrderedAscending
        : NSOrderedDescending;
    }];
}

- (void)fetchMasternodeListsToRetrieve:(void (^)(NSOrderedSet<NSData *> *listsToRetrieve))completion {
    if (![self.masternodeListRetrievalQueue count]) {
        DSLog(@"No masternode lists in retrieval");
        [self.chain.chainManager chainFinishedSyncingMasternodeListsAndQuorums:self.chain];
        return;
    }
    if ([self.masternodeListsInRetrieval count]) {
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
    completion([self.masternodeListRetrievalQueue copy]);
}

- (BOOL)removeListInRetrievalForKey:(NSData *)blockHashDiffsData {
    if (![self.masternodeListsInRetrieval containsObject:blockHashDiffsData]) {
        NSMutableArray *masternodeListsInRetrievalStrings = [NSMutableArray array];
        for (NSData *masternodeListInRetrieval in self.masternodeListsInRetrieval) {
            [masternodeListsInRetrievalStrings addObject:masternodeListInRetrieval.hexString];
        }
        DSLog(@"A masternode list (%@) was received that is not set to be retrieved (%@)", blockHashDiffsData.hexString, [masternodeListsInRetrievalStrings componentsJoinedByString:@", "]);
        return NO;
    }
    [self.masternodeListsInRetrieval removeObject:blockHashDiffsData];
    return YES;
}

- (void)disconnectFromDownloadPeer {
    [self.peerManager.downloadPeer disconnect];
}

- (void)issueWithMasternodeListFromPeer:(DSPeer *)peer {
    [self.peerManager peerMisbehaving:peer errorMessage:@"Issue with Deterministic Masternode list"];
}
- (void)requestMasternodesAndQuorums:(UInt256)previousBlockHash forBlockHash:(UInt256)blockHash {
    if ([self.chain hasDIP0024Enabled]) {
        [self requestQuorumRotationInfo:previousBlockHash forBlockHash:blockHash extraShare:YES];
    } else {
        [self requestMasternodeListDiff:previousBlockHash forBlockHash:blockHash];
    }
}
- (void)requestMasternodeListDiff:(UInt256)previousBlockHash forBlockHash:(UInt256)blockHash {
    [self.peerManager.downloadPeer sendGetMasternodeListFromPreviousBlockHash:previousBlockHash forBlockHash:blockHash];
}

- (void)requestQuorumRotationInfo:(UInt256)previousBlockHash forBlockHash:(UInt256)blockHash extraShare:(BOOL)extraShare {
    // TODO: optimize qrinfo request queue (up to 4 blocks simultaneously, so we'd make masternodeListsToRetrieve.count%4)
    NSArray<NSData *> *baseBlockHashes = @[[NSData dataWithUInt256:previousBlockHash]];
    [self.peerManager.downloadPeer sendGetQuorumRotationInfoForBaseBlockHashes:baseBlockHashes forBlockHash:blockHash extraShare:extraShare];
}

@end
