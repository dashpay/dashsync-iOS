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
#import "DSMnDiffProcessingResult.h"
#import "DSQuorumSnapshot.h"
#import "dash_shared_core.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DSQRInfoProcessingResult : NSObject

@property (nonatomic) DSQuorumSnapshot *snapshotAtHC;
@property (nonatomic) DSQuorumSnapshot *snapshotAtH2C;
@property (nonatomic) DSQuorumSnapshot *snapshotAtH3C;
@property (nonatomic) DSQuorumSnapshot *_Nullable snapshotAtH4C;

@property (nonatomic) DSMnDiffProcessingResult *mnListDiffResultAtTip;
@property (nonatomic) DSMnDiffProcessingResult *mnListDiffResultAtH;
@property (nonatomic) DSMnDiffProcessingResult *mnListDiffResultAtHC;
@property (nonatomic) DSMnDiffProcessingResult *mnListDiffResultAtH2C;
@property (nonatomic) DSMnDiffProcessingResult *mnListDiffResultAtH3C;
@property (nonatomic) DSMnDiffProcessingResult *_Nullable mnListDiffResultAtH4C;

@property (nonatomic) BOOL extraShare;

@property (nonatomic) NSOrderedSet<DSQuorumEntry *> *lastQuorumPerIndex;
@property (nonatomic) NSOrderedSet<DSQuorumSnapshot *> *snapshotList;
@property (nonatomic) NSOrderedSet<DSMnDiffProcessingResult *> *mnListDiffList;

+ (instancetype)processingResultWith:(QRInfoResult *)result onChain:(DSChain *)chain;

@end

NS_ASSUME_NONNULL_END
