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
#import "dash_shared_core.h"
#import "DSChain.h"
#import "DSTransactionOutput.h"
#import "DSCoinControl.h"
#import "DSCompactTallyItem.h"
#import "DSCoinJoinManager.h"
#import "DSCoinJoinWrapper.h"
#import "DSMasternodeGroup.h"
#import "DSCoinJoinBalance.h"

NS_ASSUME_NONNULL_BEGIN


@protocol DSCoinJoinManagerDelegate <NSObject>

- (void)sessionStartedWithId:(int32_t)baseId
             clientSessionId:(UInt256)clientId
                denomination:(uint32_t)denom
                   poolState:(DPoolState *)state
                 poolMessage:(DPoolMessage *)message
                  poolStatus:(DPoolStatus *)status
                   ipAddress:(UInt128)address
                    isJoined:(BOOL)joined;
- (void)sessionCompleteWithId:(int32_t)baseId
              clientSessionId:(UInt256)clientId
                 denomination:(uint32_t)denom
                    poolState:(DPoolState *)state
                  poolMessage:(DPoolMessage *)message
                   poolStatus:(DPoolStatus *)status
                    ipAddress:(UInt128)address
                     isJoined:(BOOL)joined;
- (void)mixingStarted;
- (void)mixingComplete:(BOOL)withError
           errorStatus:(DPoolStatus *)errorStatus
         isInterrupted:(BOOL)isInterrupted;
- (void)transactionProcessedWithId:(UInt256)txId
                              type:(DCoinJoinTransactionType *)type;

@end

@interface DSCoinJoinManager : NSObject

@property (nonatomic, assign, nullable) DSChain *chain;
@property (nonatomic, strong, nullable) DSMasternodeGroup *masternodeGroup;
@property (nonatomic, assign, nullable) DCoinJoinClientOptions *options;
@property (nonatomic, nullable, weak) id<DSCoinJoinManagerDelegate> managerDelegate;
@property (nonatomic, assign) BOOL anonymizableTallyCachedNonDenom;
@property (nonatomic, assign) BOOL anonymizableTallyCached;
@property (nonatomic, strong, nullable) DSCoinJoinWrapper *wrapper;
@property (nonatomic, readonly) BOOL isWaitingForNewBlock;
@property (atomic) BOOL isMixing;
@property (atomic) BOOL isShuttingDown;
@property (readonly) BOOL isChainSynced;

+ (instancetype)sharedInstanceForChain:(DSChain *)chain;
- (instancetype)initWithChain:(DSChain *)chain;

- (void)initMasternodeGroup;
- (BOOL)isMineInput:(UInt256)txHash index:(uint32_t)index;
- (NSArray<DSInputCoin *> *) availableCoins:(WalletEx *)walletEx onlySafe:(BOOL)onlySafe coinControl:(DSCoinControl *_Nullable)coinControl minimumAmount:(uint64_t)minimumAmount maximumAmount:(uint64_t)maximumAmount minimumSumAmount:(uint64_t)minimumSumAmount maximumCount:(uint64_t)maximumCount;
- (NSArray<DSCompactTallyItem *> *)selectCoinsGroupedByAddresses:(WalletEx *)walletEx skipDenominated:(BOOL)skipDenominated anonymizable:(BOOL)anonymizable skipUnconfirmed:(BOOL)skipUnconfirmed maxOupointsPerAddress:(int32_t)maxOupointsPerAddress;
- (uint32_t)countInputsWithAmount:(uint64_t)inputAmount;
- (NSString *)freshAddress:(BOOL)internal;
- (NSArray<NSString *> *)getIssuedReceiveAddresses;
- (NSArray<NSString *> *)getUsedReceiveAddresses;
- (BOOL)commitTransactionForAmounts:(NSArray *)amounts outputs:(NSArray *)outputs coinControl:(DSCoinControl *)coinControl onPublished:(void (^)(UInt256 txId, NSError * _Nullable error))onPublished;
- (DMasternodeEntry *)masternodeEntryByHash:(UInt256)hash;
- (uintptr_t)validMNCount;
- (DMasternodeList *)mnList;
- (BOOL)isMasternodeOrDisconnectRequested:(UInt128)ip port:(uint16_t)port;
- (BOOL)disconnectMasternode:(UInt128)ip port:(uint16_t)port;
- (BOOL)sendMessageOfType:(NSString *)messageType message:(NSData *)message withPeerIP:(UInt128)address port:(uint16_t)port warn:(BOOL)warn;
- (DSCoinJoinBalance *)getBalance;
- (void)configureMixingWithAmount:(uint64_t)amount rounds:(int32_t)rounds sessions:(int32_t)sessions withMultisession:(BOOL)multisession denominationGoal:(int32_t)denomGoal denominationHardCap:(int32_t)denomHardCap;
- (void)startAsync;
- (void)stopAsync;
- (void)start;
- (void)stop;
- (BOOL)addPendingMasternode:(UInt256)proTxHash clientSessionId:(UInt256)sessionId;
- (void)processMessageFrom:(DSPeer *)peer message:(NSData *)message type:(NSString *)type;
- (void)setStopOnNothingToDo:(BOOL)stop;
- (BOOL)startMixing;
- (void)doAutomaticDenominatingWithDryRun:(BOOL)dryRun completion:(void (^)(BOOL success))completion;
- (void)updateSuccessBlock;
- (void)refreshUnusedKeys;
- (DCoinJoinTransactionType *)coinJoinTxTypeForTransaction:(DSTransaction *)transaction;
- (double)getMixingProgress;
- (DSCoinControl *)selectCoinJoinUTXOs;
- (uint64_t)getSmallestDenomination;
//- (void)hasCollateralInputsWithOnlyConfirmed:(BOOL)onlyConfirmed completion:(void (^)(BOOL balance))completion;
- (void)calculateAnonymizableBalanceWithSkipDenominated:(BOOL)skipDenominated skipUnconfirmed:(BOOL)skipUnconfirmed completion:(void (^)(uint64_t balance))completion;
- (void)minimumAnonymizableBalanceWithCompletion:(void (^)(uint64_t balance))completion;
- (void)updateOptionsWithAmount:(uint64_t)amount;
- (void)updateOptionsWithEnabled:(BOOL)isEnabled;
- (void)initiateShutdown;

// Events
- (void)onSessionComplete:(int32_t)baseId
          clientSessionId:(UInt256)clientId
             denomination:(uint32_t)denom
                poolState:(DPoolState *)state
              poolMessage:(DPoolMessage *)message
               poolStatus:(DPoolStatus *)status
                ipAddress:(UInt128)address
                 isJoined:(BOOL)joined;
- (void)onSessionStarted:(int32_t)baseId
         clientSessionId:(UInt256)clientId
            denomination:(uint32_t)denom
               poolState:(DPoolState *)state
             poolMessage:(DPoolMessage *)message
              poolStatus:(DPoolStatus *)status
               ipAddress:(UInt128)address
                isJoined:(BOOL)joined;
- (void)onMixingStarted:(nonnull NSArray *)statuses;
- (void)onMixingComplete:(nonnull NSArray *)statuses isInterrupted:(BOOL)isInterrupted;
- (void)onTransactionProcessed:(UInt256)txId type:(DCoinJoinTransactionType *)type;

@end

NS_ASSUME_NONNULL_END
