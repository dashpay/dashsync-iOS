//  
//  Created by Andrei Ashikhmin
//  Copyright © 2024 Dash Core Group. All rights reserved.
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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, CoinType) {
    CoinTypeAllCoins,
    CoinTypeOnlyFullyMixed,
    CoinTypeOnlyReadyToMix,
    CoinTypeOnlyNonDenominated,
    CoinTypeOnlyMasternodeCollateral,
    CoinTypeOnlyCoinJoinCollateral
};

// CoinControl comes from Dash Core.  Not all functions fields and functions are supported within the Wallet class
@interface DSCoinControl : NSObject

@property (nonatomic, assign) BOOL allowOtherInputs;
@property (nonatomic, assign) BOOL requireAllInputs;
@property (nonatomic, assign) BOOL allowWatchOnly;
@property (nonatomic, assign) BOOL overrideFeeRate;
@property (nonatomic, assign) BOOL avoidPartialSpends;
@property (nonatomic, assign) BOOL avoidAddressReuse;
@property (nonatomic, assign) int minDepth;
@property (nonatomic, assign) uint64_t feeRate;
@property (nonatomic, assign) uint64_t discardFeeRate;
@property (nonatomic, strong) NSNumber *confirmTarget;
@property (nonatomic, assign) CoinType coinType;
@property (nonatomic, strong) NSMutableOrderedSet *setSelected;

- (BOOL)hasSelected;
- (BOOL)isSelected:(NSValue *)output;
- (void)select:(NSValue *)output;
- (void)unSelect:(NSValue *)output;
- (void)unSelectAll;
- (void)useCoinJoin:(BOOL)fUseCoinJoin;
- (BOOL)isUsingCoinJoin;

@end

NS_ASSUME_NONNULL_END
