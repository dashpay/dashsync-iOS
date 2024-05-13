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
#import "DSChain.h"

NS_ASSUME_NONNULL_BEGIN

@class DSCoinJoinManager;

@interface DSMasternodeGroup : NSObject

@property (atomic, readonly) BOOL isRunning;
@property (nonatomic, strong) id blocksObserver;
@property (nonatomic, strong) DSChain *chain;
@property (nonatomic, weak, nullable) DSCoinJoinManager *coinJoinManager;
@property (nonatomic, strong) NSMutableSet<NSValue *> *pendingSessions;
@property (nonatomic, strong) NSMutableDictionary *masternodeMap;
@property (atomic, readonly) NSUInteger maxConnections;

- (instancetype)initWithManager:(DSCoinJoinManager *)manager;

- (void)startAsync;
- (void)stopAsync;
- (BOOL)isMasternodeOrDisconnectRequested;
- (BOOL)addPendingMasternode:(UInt256)proTxHash clientSessionId:(UInt256)sessionId;

@end

NS_ASSUME_NONNULL_END
