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

#define DCoinType dash_spv_coinjoin_models_coin_control_CoinType
#define DCoinTypeIndex(ptr) dash_spv_coinjoin_models_coin_control_CoinType_index(ptr)
#define DCoinControl dash_spv_coinjoin_models_coin_control_CoinControl
#define DCoinControlDtor(ptr) dash_spv_coinjoin_models_coin_control_CoinControl_destroy(ptr)
#define DCompactTallyItem dash_spv_coinjoin_coin_selection_compact_tally_item_CompactTallyItem
#define DCompactTallyItemCtor(dest, amout, coins) dash_spv_coinjoin_coin_selection_compact_tally_item_CompactTallyItem_ctor(dest, amout, coins)
#define DCompactTallyItemDtor(ptr) dash_spv_coinjoin_coin_selection_compact_tally_item_CompactTallyItem_destroy(ptr)
#define DCompactTallyItems Vec_dash_spv_coinjoin_coin_selection_compact_tally_item_CompactTallyItem
#define DCompactTallyItemsCtor(count, values) Vec_dash_spv_coinjoin_coin_selection_compact_tally_item_CompactTallyItem_ctor(count, values)
#define DPoolState dash_spv_coinjoin_messages_pool_state_PoolState
#define DPoolStateValue(ptr) dash_spv_coinjoin_messages_pool_state_PoolState_value(ptr)
#define DPoolStateDtor(ptr) dash_spv_coinjoin_messages_pool_state_PoolState_destroy(ptr)
#define DPoolMessage dash_spv_coinjoin_messages_pool_message_PoolMessage
#define DPoolMessageValue(ptr) dash_spv_coinjoin_messages_pool_message_PoolMessage_value(ptr)
#define DPoolMessageDtor(ptr) dash_spv_coinjoin_messages_pool_message_PoolMessage_destroy(ptr)
#define DPoolStatus dash_spv_coinjoin_messages_pool_status_PoolStatus
#define DPoolStatusValue(ptr) dash_spv_coinjoin_messages_pool_status_PoolStatus_value(ptr)
#define DPoolStatusDtor(ptr) dash_spv_coinjoin_messages_pool_status_PoolStatus_destroy(ptr)
#define DPoolStatusFromIndex(index) dash_spv_coinjoin_messages_pool_status_PoolStatus_from_index(index)
#define DCoinJoinTransactionType dash_spv_coinjoin_models_coinjoin_tx_type_CoinJoinTransactionType
#define DCoinJoinTransactionTypeIndex(ptr) dash_spv_coinjoin_models_coinjoin_tx_type_CoinJoinTransactionType_index(ptr)
#define DCoinJoinClientOptions dash_spv_coinjoin_models_coinjoin_client_options_CoinJoinClientOptions
#define DInputCoin dash_spv_coinjoin_coin_selection_input_coin_InputCoin
#define DInputCoinCtor(outpoint, out, value) dash_spv_coinjoin_coin_selection_input_coin_InputCoin_ctor(outpoint, out, value)
#define DInputCoinDtor(ptr) dash_spv_coinjoin_coin_selection_input_coin_InputCoin_destroy(ptr)
#define DInputCoins Vec_dash_spv_coinjoin_coin_selection_input_coin_InputCoin
#define DInputCoinsCtor(count, values) Vec_dash_spv_coinjoin_coin_selection_input_coin_InputCoin_ctor(count, values)
#define DPoolStatuses Vec_dash_spv_coinjoin_messages_pool_status_PoolStatus
#define DPoolStatusesDtor(ptr) Vec_dash_spv_coinjoin_messages_pool_status_PoolStatus_destroy(ptr)

@class DSCoinJoinManager;

@interface DSCoinJoinWrapper : NSObject

@property (nonatomic, strong, nullable) DSChainManager *chainManager;
@property (nonatomic, strong) DSChain *chain;
@property (nonatomic, weak, nullable) DSCoinJoinManager *manager;
@property (nonatomic, assign, nullable) CoinJoinClientManager *clientManager;

- (instancetype)initWithManagers:(DSCoinJoinManager *)manager chainManager:(DSChainManager *)chainManager;
- (void)processDSQueueFrom:(DSPeer *)peer message:(NSData *)message;
- (void)processMessageFrom:(DSPeer *)peer message:(NSData *)message type:(NSString *)type;
- (void)notifyNewBestBlock:(DSBlock *)block;
- (void)setStopOnNothingToDo:(BOOL)stop;
- (BOOL)startMixing;
- (BOOL)doAutomaticDenominatingWithDryRun:(BOOL)dryRun;
- (void)doMaintenance;
- (void)registerCoinJoin:(DCoinJoinClientOptions *)options;
- (BOOL)isRegistered;
- (BOOL)isMixingFeeTx:(UInt256)txId;
- (void)refreshUnusedKeys;
- (BOOL)isDenominatedAmount:(uint64_t)amount;
- (BOOL)isFullyMixed:(DSUTXO)utxo;
- (void)initiateShutdown;
+ (DCoinJoinTransactionType *)coinJoinTxTypeForTransaction:(DSTransaction *)transaction;
+ (DCoinJoinTransactionType *)coinJoinTxTypeForTransaction:(DSTransaction *)transaction account:(DSAccount *)account;
- (void)unlockOutputs:(DSTransaction *)transaction;
- (uint64_t)getAnonymizableBalance:(BOOL)skipDenominated skipUnconfirmed:(BOOL)skipUnconfirmed;
- (uint64_t)getSmallestDenomination;
- (void)updateOptions:(DCoinJoinClientOptions *)options;
- (NSArray<NSNumber *> *)getStandardDenominations;
- (uint64_t)getCollateralAmount;
- (uint64_t)getMaxCollateralAmount;
- (BOOL)hasCollateralInputs:(BOOL)onlyConfirmed;
- (uint32_t)amountToDenomination:(uint64_t)amount;
- (int32_t)getRealOutpointCoinJoinRounds:(DSUTXO)utxo;
- (BOOL)isLockedCoin:(DSUTXO)utxo;
- (void)stopAndResetClientManager;
- (NSArray<NSNumber *> *)getSessionStatuses;

@end

NS_ASSUME_NONNULL_END
