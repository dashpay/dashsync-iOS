//
//  Created by Vladimir Pirogov
//  Copyright © 2021 Dash Core Group. All rights reserved.
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

#import "DSMasternodeList.h"
#import "dash_shared_core.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DSMnDiffProcessingResult : NSObject

@property (nonatomic) BOOL foundCoinbase;
@property (nonatomic) BOOL validCoinbase;
@property (nonatomic) BOOL rootMNListValid;
@property (nonatomic) BOOL rootQuorumListValid;
@property (nonatomic) BOOL validQuorums;
@property (nonatomic) DSMasternodeList *masternodeList;
@property (nonatomic) NSDictionary *addedMasternodes;
@property (nonatomic) NSDictionary *modifiedMasternodes;
@property (nonatomic) NSDictionary *addedQuorums;
@property (nonatomic) NSOrderedSet *neededMissingMasternodeLists;

+ (instancetype)processingResultWith:(MNListDiffResult *)result onChain:(DSChain *)chain;

- (BOOL)isValid;
- (BOOL)hasRotatedQuorums;

@end

NS_ASSUME_NONNULL_END
