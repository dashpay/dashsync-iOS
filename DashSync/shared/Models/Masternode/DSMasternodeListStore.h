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
#import "DSKeyManager.h"
#import <Foundation/Foundation.h>
#import "NSManagedObject+Sugar.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const DSCurrentMasternodeListDidChangeNotification;
FOUNDATION_EXPORT NSString *const DSMasternodeListDidChangeNotification;
FOUNDATION_EXPORT NSString *const DSMasternodeManagerNotificationMasternodeListKey;
FOUNDATION_EXPORT NSString *const DSQuorumListDidChangeNotification;

#define CHAINLOCK_ACTIVATION_HEIGHT 1088640
@class DSChain;
@interface DSMasternodeListStore : NSObject

@property (nonatomic, readonly) uint32_t earliestMasternodeListBlockHeight;
@property (nonatomic, readonly) uint32_t lastMasternodeListBlockHeight;
@property (nonatomic, readonly) dispatch_group_t savingGroup;

- (instancetype)initWithChain:(DSChain *)chain;
- (void)setUp;
- (void)deleteAllOnChain;
- (void)deleteEmptyMasternodeLists;
- (BOOL)hasBlockForBlockHash:(NSData *)blockHashData;
- (uint32_t)heightForBlockHash:(UInt256)blockhash;

- (void)loadLocalMasternodes;
- (DArcMasternodeList *)loadMasternodeListAtBlockHash:(NSData *)blockHash
                                withBlockHeightLookup:(BlockHeightFinder)blockHeightLookup;
- (DArcMasternodeList *)loadMasternodeListsWithBlockHeightLookup:(BlockHeightFinder)blockHeightLookup;
- (void)removeOldMasternodeLists;
- (void)removeOldSimplifiedMasternodeEntries;
- (nullable NSError *)saveQuorumSnapshot:(DLLMQSnapshot *)quorumSnapshot
                            forBlockHash:(u256 *)block_hash;

+ (nullable NSError *)saveMasternodeList:(DArcMasternodeList *)masternodeList
                                 toChain:(DSChain *)chain
               havingModifiedMasternodes:(DMasternodeEntryMap *)modifiedMasternodes
                     createUnknownBlocks:(BOOL)createUnknownBlocks
                               inContext:(NSManagedObjectContext *)context;

@end

NS_ASSUME_NONNULL_END
