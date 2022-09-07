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
#import "DSChain.h"
#import "DSMasternodeList.h"
#import "DSQuorumSnapshot.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const DSCurrentMasternodeListDidChangeNotification;
FOUNDATION_EXPORT NSString *const DSMasternodeListDidChangeNotification;
FOUNDATION_EXPORT NSString *const DSMasternodeManagerNotificationMasternodeListKey;
FOUNDATION_EXPORT NSString *const DSQuorumListDidChangeNotification;

#define CHAINLOCK_ACTIVATION_HEIGHT 1088640

@interface DSMasternodeListStore : NSObject

//@property (nonatomic, nullable) DSMasternodeList *currentMasternodeList;
@property (nonatomic, readonly) NSUInteger knownMasternodeListsCount;
@property (nonatomic, readonly) NSArray *recentMasternodeLists;
@property (nonatomic, readonly) uint32_t earliestMasternodeListBlockHeight;
@property (nonatomic, readonly) uint32_t lastMasternodeListBlockHeight;
@property (nonatomic, readonly) NSMutableDictionary<NSData *, DSMasternodeList *> *masternodeListsByBlockHash;
@property (nonatomic, readonly) NSMutableSet<NSData *> *masternodeListsBlockHashStubs;
@property (nonatomic, readonly) NSMutableDictionary<NSData *, DSQuorumEntry *> *activeQuorums;
@property (nonatomic, readonly) uint32_t masternodeListsToSync;
@property (nonatomic, readonly) BOOL masternodeListsAndQuorumsIsSynced;

@property (nonatomic, readonly) NSMutableDictionary<NSData *, DSQuorumSnapshot *> *cachedQuorumSnapshots;

- (instancetype)initWithChain:(DSChain *)chain;
- (void)setUp:(void (^)(DSMasternodeList *masternodeList))completion;
- (void)deleteAllOnChain;
- (void)deleteEmptyMasternodeLists;
- (BOOL)hasBlockForBlockHash:(NSData *)blockHashData;
- (BOOL)hasMasternodeListAt:(NSData *)blockHashData;
- (BOOL)hasMasternodeListCurrentlyBeingSaved;
- (uint32_t)heightForBlockHash:(UInt256)blockhash;
- (void)loadLocalMasternodes;
- (DSMasternodeList *)loadMasternodeListAtBlockHash:(NSData *)blockHash withBlockHeightLookup:(BlockHeightFinder)blockHeightLookup;
- (DSMasternodeList *_Nullable)reloadMasternodeListsWithBlockHeightLookup:(BlockHeightFinder)blockHeightLookup;
- (DSMasternodeList *_Nullable)masternodeListBeforeBlockHash:(UInt256)blockHash;
- (DSMasternodeList *_Nullable)masternodeListForBlockHash:(UInt256)blockHash withBlockHeightLookup:(BlockHeightFinder)blockHeightLookup;
- (void)removeAllMasternodeLists;
- (void)removeOldMasternodeLists:(uint32_t)lastBlockHeight;
- (void)removeOldSimplifiedMasternodeEntries;

- (void)saveMasternodeList:(DSMasternodeList *)masternodeList
          addedMasternodes:(NSDictionary *)addedMasternodes
       modifiedMasternodes:(NSDictionary *)modifiedMasternodes
              addedQuorums:(NSDictionary *)addedQuorums
                completion:(void (^)(NSError *error))completion;
- (void)saveQuorumSnapshot:(DSQuorumSnapshot *)quorumSnapshot
                   toChain:(DSChain *)chain
                completion:(void (^)(NSError *error))completion;

+ (void)saveMasternodeList:(DSMasternodeList *)masternodeList toChain:(DSChain *)chain havingModifiedMasternodes:(NSDictionary *)modifiedMasternodes addedQuorums:(NSDictionary *)addedQuorums createUnknownBlocks:(BOOL)createUnknownBlocks inContext:(NSManagedObjectContext *)context completion:(void (^)(NSError *error))completion;

- (DSQuorumEntry *_Nullable)quorumEntryForPlatformHavingQuorumHash:(UInt256)quorumHash forBlockHeight:(uint32_t)blockHeight;

@end

NS_ASSUME_NONNULL_END
