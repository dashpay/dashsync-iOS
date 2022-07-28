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

#import "DSChain.h"
#import "DSInsightManager.h"
#import "DSMasternodeListRequest.h"
#import "DSPeer.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, DSMasternodeListRequestMode) {
    DSMasternodeListRequestMode_MNLISTDIFF = 1,
    DSMasternodeListRequestMode_QRINFO = 2,
    DSMasternodeListRequestMode_MIXED = DSMasternodeListRequestMode_MNLISTDIFF | DSMasternodeListRequestMode_QRINFO
};

@interface DSMasternodeListService : NSObject

@property (nonatomic, readonly, nonnull) DSChain *chain;
@property (nonatomic, readonly) NSMutableSet<DSMasternodeListRequest *> *requestsInRetrieval;
@property (nonatomic, readonly) NSMutableOrderedSet<NSData *> *retrievalQueue;
@property (nonatomic, readonly) NSMutableOrderedSet<NSData *> *neededQueue; // TODO: Make storing hashes for tip list separately, to avoid
@property (nonatomic, readonly) NSUInteger retrievalQueueCount;
@property (nonatomic, readonly) NSUInteger retrievalQueueMaxAmount;

- (instancetype)initWithChain:(DSChain *)chain blockHeightLookup:(BlockHeightFinder)blockHeightLookup;

- (void)addToRetrievalQueue:(NSData *)masternodeBlockHashData;
- (void)addToRetrievalQueueArray:(NSArray<NSData *> *)masternodeBlockHashDataArray;
- (void)cleanAllLists;
- (void)cleanListsRetrievalQueue;
- (void)cleanRequestsInRetrieval;

- (void)fetchMasternodeListsToRetrieve:(void (^)(NSOrderedSet<NSData *> *listsToRetrieve))completion;
- (void)removeFromRetrievalQueue:(NSData *)masternodeBlockHashData;
- (BOOL)removeRequestInRetrievalForBaseBlockHash:(UInt256)baseBlockHash blockHash:(UInt256)blockHash;

- (BOOL)hasLatestBlockInRetrievalQueueWithHash:(UInt256)blockHash;

- (void)disconnectFromDownloadPeer;
- (void)issueWithMasternodeListFromPeer:(DSPeer *)peer;
- (void)requestMasternodeListDiff:(UInt256)previousBlockHash forBlockHash:(UInt256)blockHash;
- (void)requestQuorumRotationInfo:(UInt256)previousBlockHash forBlockHash:(UInt256)blockHash;
@end

NS_ASSUME_NONNULL_END
