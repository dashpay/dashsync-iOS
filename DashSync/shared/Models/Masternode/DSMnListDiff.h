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

#import "DSCoinbaseTransaction.h"
#import "DSMasternodeList.h"
#import "dash_shared_core.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DSMnListDiff : NSObject

@property (nonatomic) DSChain *chain;

@property (nonatomic, assign) UInt256 baseBlockHash;
@property (nonatomic, assign) UInt256 blockHash;
@property (nonatomic) NSUInteger totalTransactions;
@property (nonatomic) NSOrderedSet<NSNumber *> *merkleHashes;
@property (nonatomic) NSOrderedSet<NSNumber *> *merkleFlags;
@property (nonatomic) DSCoinbaseTransaction *coinbaseTransaction;
@property (nonatomic) NSOrderedSet<NSData *> *deletedMasternodeHashes;
@property (nonatomic) NSOrderedSet<DSSimplifiedMasternodeEntry *> *addedOrModifiedMasternodes;
@property (nonatomic) NSDictionary<NSNumber *, NSArray<NSData *> *> *deletedQuorums;
@property (nonatomic) NSOrderedSet<DSQuorumEntry *> *addedQuorums;

//@property (nonatomic) DSMasternodeList *masternodeList;
//@property (nonatomic) NSDictionary *addedMasternodes;
@property (nonatomic) NSUInteger length;
@property (nonatomic) NSUInteger blockHeight;

+ (instancetype)mnListDiffWith:(MNListDiff *)mnListDiff onChain:(DSChain *)chain;

@end

NS_ASSUME_NONNULL_END
