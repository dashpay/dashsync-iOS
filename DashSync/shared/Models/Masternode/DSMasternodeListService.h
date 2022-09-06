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
#import "DSMasternodeListStore.h"
#import "DSPeer.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const DSMasternodeListDiffValidationErrorNotification;

#define FAULTY_DML_MASTERNODE_PEERS @"FAULTY_DML_MASTERNODE_PEERS"
#define CHAIN_FAULTY_DML_MASTERNODE_PEERS [NSString stringWithFormat:@"%@_%@", peer.chain.uniqueID, FAULTY_DML_MASTERNODE_PEERS]
#define MAX_FAULTY_DML_PEERS 1

typedef NS_ENUM(NSUInteger, DSMasternodeListRequestMode) {
    DSMasternodeListRequestMode_MNLISTDIFF = 1,
    DSMasternodeListRequestMode_QRINFO = 2,
    DSMasternodeListRequestMode_MIXED = DSMasternodeListRequestMode_MNLISTDIFF | DSMasternodeListRequestMode_QRINFO
};
@class DSMasternodeListService;

@protocol DSMasternodeListServiceDelegate <NSObject>

- (uint32_t)masternodeListSerivceDidRequestHeightForBlockHash:(DSMasternodeListService *)service blockHash:(UInt256)blockHash;
- (DSMasternodeList *__nullable)masternodeListSerivceDidRequestFileFromBlockHash:(DSMasternodeListService *)service blockHash:(UInt256)blockHash;

@end

@interface DSMasternodeListService : NSObject

@property (nonatomic, readonly, nonnull) DSChain *chain;
@property (nonatomic, nullable) DSMasternodeList *currentMasternodeList;
@property (nonatomic, readonly) NSMutableSet<DSMasternodeListRequest *> *requestsInRetrieval;
@property (nonatomic, readonly) NSMutableOrderedSet<NSData *> *retrievalQueue;
@property (nonatomic, readonly) NSMutableOrderedSet<NSData *> *neededQueue; // TODO: Make storing hashes for tip list separately, to avoid
@property (nonatomic, readonly) NSUInteger retrievalQueueCount;
@property (nonatomic, readonly) NSUInteger retrievalQueueMaxAmount;
@property (nullable, nonatomic, weak) id<DSMasternodeListServiceDelegate> delegate;

@property (nonatomic, assign) uint16_t timedOutAttempt;
@property (nonatomic, assign) uint16_t timeOutObserverTry;

- (instancetype)initWithChain:(DSChain *)chain store:(DSMasternodeListStore *)store delegate:(id<DSMasternodeListServiceDelegate>)delegate;

- (void)populateRetrievalQueueWithBlockHashes:(NSOrderedSet *)blockHashes;
- (void)getRecentMasternodeList;
- (void)dequeueMasternodeListRequest;

- (void)addToRetrievalQueue:(NSData *)masternodeBlockHashData;
- (void)addToRetrievalQueueArray:(NSArray<NSData *> *)masternodeBlockHashDataArray;
- (void)cleanAllLists;
- (void)cleanListsRetrievalQueue;
- (void)cleanRequestsInRetrieval;
- (void)composeMasternodeListRequest:(NSOrderedSet<NSData *> *)list;

- (void)fetchMasternodeListsToRetrieve:(void (^)(NSOrderedSet<NSData *> *listsToRetrieve))completion;
- (void)removeFromRetrievalQueue:(NSData *)masternodeBlockHashData;
- (BOOL)removeRequestInRetrievalForBaseBlockHash:(UInt256)baseBlockHash blockHash:(UInt256)blockHash;

- (BOOL)hasLatestBlockInRetrievalQueueWithHash:(UInt256)blockHash;

- (void)disconnectFromDownloadPeer;
- (void)issueWithMasternodeListFromPeer:(DSPeer *)peer;

- (void)sendMasternodeListRequest:(DSMasternodeListRequest *)request;

@end

NS_ASSUME_NONNULL_END
