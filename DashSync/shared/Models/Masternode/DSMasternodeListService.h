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
#import "DSPeer.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DSMasternodeListService : NSObject

@property (nonatomic, readonly, nonnull) DSChain *chain;
@property (nonatomic, readonly) NSMutableSet<NSData *> *listsInRetrieval;
@property (nonatomic, readonly) NSMutableOrderedSet<NSData *> *retrievalQueue;
@property (nonatomic, readonly) NSUInteger retrievalQueueCount;
@property (nonatomic, readonly) NSUInteger retrievalQueueMaxAmount;

- (instancetype)initWithChain:(DSChain *)chain blockHeightLookup:(BlockHeightFinder)blockHeightLookup;
- (void)addToRetrievalQueue:(NSData *)masternodeBlockHashData;
- (void)addToRetrievalQueueArray:(NSArray<NSData *> *)masternodeBlockHashDataArray;
- (void)cleanAllLists;
- (void)cleanListsInRetrieval;
- (void)cleanListsRetrievalQueue;
- (void)fetchMasternodeListsToRetrieve:(void (^)(NSOrderedSet<NSData *> *listsToRetrieve))completion;
- (void)removeFromRetrievalQueue:(NSData *)masternodeBlockHashData;
- (BOOL)removeListInRetrievalForKey:(NSData *)blockHashDiffsData;
- (BOOL)hasLatestBlockInRetrievalQueueWithHash:(UInt256)blockHash;

- (void)disconnectFromDownloadPeer;
- (void)issueWithMasternodeListFromPeer:(DSPeer *)peer;
- (void)requestMasternodesAndQuorums:(UInt256)previousBlockHash forBlockHash:(UInt256)blockHash;
- (void)retrieveMasternodeList:(UInt256)previousBlockHash forBlockHash:(UInt256)blockHash;

@end

NS_ASSUME_NONNULL_END
