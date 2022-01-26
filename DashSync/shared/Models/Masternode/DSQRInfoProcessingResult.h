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
#import "DSMnListDiff.h"
#import "DSQuorumSnapshot.h"
#import "dash_shared_core.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DSQRInfoProcessingResult : NSObject

@property (nonatomic) DSQuorumSnapshot *snapshotAtHC;
@property (nonatomic) DSQuorumSnapshot *snapshotAtH2C;
@property (nonatomic) DSQuorumSnapshot *snapshotAtH3C;
@property (nonatomic) DSQuorumSnapshot *_Nullable snapshotAtH4C;

@property (nonatomic) DSMnListDiff *mnListDiffAtTip;
@property (nonatomic) DSMnListDiff *mnListDiffAtH;
@property (nonatomic) DSMnListDiff *mnListDiffAtHC;
@property (nonatomic) DSMnListDiff *mnListDiffAtH2C;
@property (nonatomic) DSMnListDiff *mnListDiffAtH3C;
@property (nonatomic) DSMnListDiff *_Nullable mnListDiffAtH4C;

@property (nonatomic) BOOL extraShare;
@property (nonatomic) NSOrderedSet<NSData *> *blockHashList;
@property (nonatomic) NSOrderedSet<DSQuorumSnapshot *> *snapshotList;
@property (nonatomic) NSOrderedSet<DSMnListDiff *> *mnListDiffList;

+ (instancetype)processingResultWith:(QuorumRotationInfo *)quorumRotationInfo onChain:(DSChain *)chain;

@end

NS_ASSUME_NONNULL_END
