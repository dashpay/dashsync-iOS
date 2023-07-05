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

#import "BigIntTypes.h"
#import "DSMasternodeList.h"
#import "DSMasternodeListStore.h"
#import "DSMerkleBlock.h"
#import "DSQuorumEntry.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSMasternodeListStore (Protected)

@property (nonatomic, readwrite, nullable) DSMasternodeList *masternodeListAwaitingQuorumValidation;
@property (nonatomic, readonly) NSMutableSet<NSData *> *masternodeListQueriesNeedingQuorumsValidated;
@property (nonatomic, readwrite, assign) UInt256 lastQueriedBlockHash; //last by height, not by time queried

- (void)savePlatformPingInfoForEntries:(NSArray<DSSimplifiedMasternodeEntry *> *)entries
                             inContext:(NSManagedObjectContext *)context;
//- (void)checkPingTimesForMasternodesInContext:(NSManagedObjectContext *)context withCompletion:(void (^)(NSMutableDictionary<NSData *, NSNumber *> *pingTimes, NSMutableDictionary<NSData *, NSError *> *errors))completion;
- (UInt256)closestKnownBlockHashForBlockHash:(UInt256)blockHash;
- (DSQuorumEntry *)quorumEntryForChainLockRequestID:(UInt256)requestID forMerkleBlock:(DSMerkleBlock *)merkleBlock;
- (DSQuorumEntry *)quorumEntryForInstantSendRequestID:(UInt256)requestID forMerkleBlock:(DSMerkleBlock *)merkleBlock;

- (BOOL)addBlockToValidationQueue:(DSMerkleBlock *)merkleBlock;
@end

NS_ASSUME_NONNULL_END
