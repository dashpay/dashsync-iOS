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
#import "DSMasternodeGroup.h"
#import "DSChainManager.h"

NS_ASSUME_NONNULL_BEGIN

@class DSCoinJoinWrapper;

@interface DSCoinJoinManager : NSObject

@property (nonatomic, strong, nullable) DSChainManager *chainManager;
@property (nonatomic, strong, nullable) DSCoinJoinWrapper *wrapper;
@property (nonatomic, strong, nullable) DSMasternodeGroup *masternodeGroup;

@property (nonatomic, assign, nullable) WalletEx *walletEx;
@property (nonatomic, assign, nullable) CoinJoinClientManager *clientManager;
@property (nonatomic, assign, nullable) CoinJoinClientOptions *options;

- (instancetype)initWithChainManager:(DSChainManager *)chainManager;
- (void)runCoinJoin;

@end

NS_ASSUME_NONNULL_END
