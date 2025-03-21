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
#import "BigIntTypes.h"
#import "DSKeyManager.h"

NS_ASSUME_NONNULL_BEGIN

// CoinControl comes from Dash Core.  Not all functions fields and functions are supported within the Wallet class
@interface DSCoinControl : NSObject

@property (nonatomic, assign) BOOL allowOtherInputs;
@property (nonatomic, assign) BOOL requireAllInputs;
@property (nonatomic, assign) BOOL allowWatchOnly;
@property (nonatomic, assign) BOOL overrideFeeRate;
@property (nonatomic, assign) BOOL avoidPartialSpends;
@property (nonatomic, assign) BOOL avoidAddressReuse;
@property (nonatomic, assign) int32_t minDepth;
@property (nonatomic, assign) int32_t maxDepth;
@property (nonatomic, assign) uint64_t feeRate;
@property (nonatomic, assign) uint64_t discardFeeRate;
@property (nonatomic, strong) NSNumber *confirmTarget;
@property (nonatomic, assign) dash_spv_coinjoin_models_coin_control_CoinType coinType;
@property (nonatomic, strong) NSMutableOrderedSet *setSelected;
@property (nonatomic, strong) NSString *destChange;

- (instancetype)initWithFFICoinControl:(dash_spv_coinjoin_models_coin_control_CoinControl *)coinControl
                             chainType:(DChainType *)chainType;

- (BOOL)hasSelected;
- (BOOL)isSelected:(DSUTXO)utxo;
- (void)useCoinJoin:(BOOL)useCoinJoin;
- (BOOL)isUsingCoinJoin;
- (void)select:(DSUTXO)utxo;

@end

NS_ASSUME_NONNULL_END
