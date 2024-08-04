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

@class DSCoinJoinManager;

@interface DSCoinJoinWrapper : NSObject

@property (nonatomic, strong, nullable) DSChainManager *chainManager;
@property (nonatomic, strong) DSChain *chain;
@property (nonatomic, weak, nullable) DSCoinJoinManager *manager;

@property (nonatomic, assign, nullable) WalletEx *walletEx;
@property (nonatomic, assign, nullable) CoinJoinClientManager *clientManager;

- (instancetype)initWithManagers:(DSCoinJoinManager *)manager chainManager:(DSChainManager *)chainManager;
- (void)processDSQueueFrom:(DSPeer *)peer message:(NSData *)message;
- (void)processMessageFrom:(DSPeer *)peer message:(NSData *)message type:(NSString *)type;
- (void)notifyNewBestBlock:(DSBlock *)block;
- (void)setStopOnNothingToDo:(BOOL)stop;
- (BOOL)startMixing;
- (BOOL)doAutomaticDenominating;
- (void)doMaintenance;
- (void)registerCoinJoin:(CoinJoinClientOptions *)options;

@end

NS_ASSUME_NONNULL_END
