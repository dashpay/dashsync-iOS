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
@class DSPeer, DSMasternodeListStore;

@interface DSMasternodeListService : NSObject

@property (nonatomic, readonly, nonnull) DSChain *chain;
@property (nonatomic, readonly) NSMutableSet<DSMasternodeListRequest *> *requestsInRetrieval;
@property (nonatomic, readonly, assign) indexmap_IndexSet_u8_32 *retrievalQueue;
@property (nonatomic, readonly) NSUInteger retrievalQueueCount;
@property (nonatomic, readonly) NSUInteger retrievalQueueMaxAmount;

@property (nonatomic, assign) uint16_t timedOutAttempt;
@property (nonatomic, assign) uint16_t timeOutObserverTry;

- (instancetype)initWithChain:(DSChain *)chain
                        store:(DSMasternodeListStore *)store;

- (void)dequeueMasternodeListRequest;
- (void)stop;

- (void)cleanAllLists;
- (void)cleanListsRetrievalQueue;
- (void)cleanRequestsInRetrieval;
- (void)composeMasternodeListRequest:(NSOrderedSet<NSData *> *)list;

- (void)fetchMasternodeListsToRetrieve:(void (^)(NSOrderedSet<NSData *> *listsToRetrieve))completion;
- (void)removeFromRetrievalQueue:(NSData *)masternodeBlockHashData;
- (BOOL)removeRequestInRetrievalForBaseBlockHash:(UInt256)baseBlockHash blockHash:(UInt256)blockHash;

- (void)disconnectFromDownloadPeer;
- (void)issueWithMasternodeListFromPeer:(DSPeer *)peer;

- (void)sendMasternodeListRequest:(DSMasternodeListRequest *)request;

- (void)checkWaitingForQuorums;
- (DSMasternodeListRequest*__nullable)requestInRetrievalFor:(UInt256)baseBlockHash blockHash:(UInt256)blockHash;

@end

NS_ASSUME_NONNULL_END
