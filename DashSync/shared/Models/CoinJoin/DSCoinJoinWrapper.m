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

#import "DSCoinJoinManager.h"
#import "DSWallet.h"
#import "DSTransaction+CoinJoin.h"
#import "DSTransactionOutput+CoinJoin.h"
#import "DSAccount.h"
#import "DSChain+Params.h"
#import "DSChain+Transaction.h"
#import "DSChain+Wallet.h"
#import "DSChainManager.h"
#import "DSCoinJoinWrapper.h"
#import "DSBlock.h"
#import "NSArray+Dash.h"

#define AS_OBJC(context) ((__bridge DSCoinJoinWrapper *)(context))
#define AS_RUST(context) ((__bridge void *)(context))

#define DGetWalletTransaction Fn_ARGS_std_os_raw_c_void_Arr_u8_32_RTRN_Option_dashcore_blockdata_transaction_Transaction
#define DSignTransaction Fn_ARGS_std_os_raw_c_void_dashcore_blockdata_transaction_Transaction_bool_RTRN_Option_dashcore_blockdata_transaction_Transaction
#define DIsMineInput Fn_ARGS_std_os_raw_c_void_dashcore_blockdata_transaction_outpoint_OutPoint_RTRN_bool
#define DSelectCoins Fn_ARGS_std_os_raw_c_void_bool_bool_bool_i32_dash_spv_coinjoin_wallet_ex_WalletEx_RTRN_Vec_dash_spv_coinjoin_coin_selection_compact_tally_item_CompactTallyItem
#define DInputsWithAmount Fn_ARGS_std_os_raw_c_void_u64_RTRN_u32
#define DFreshCoinjoinAddress Fn_ARGS_std_os_raw_c_void_bool_RTRN_String
#define DAvailableCoins Fn_ARGS_std_os_raw_c_void_bool_dash_spv_coinjoin_models_coin_control_CoinControl_dash_spv_coinjoin_wallet_ex_WalletEx_RTRN_Vec_dash_spv_coinjoin_coin_selection_input_coin_InputCoin
#define DCommitTransaction Fn_ARGS_std_os_raw_c_void_Vec_dashcore_blockdata_transaction_txout_TxOut_dash_spv_coinjoin_models_coin_control_CoinControl_bool_Arr_u8_32_RTRN_bool
#define DSessionLifecycle Fn_ARGS_std_os_raw_c_void_bool_i32_Arr_u8_32_u32_dash_spv_coinjoin_messages_pool_state_PoolState_dash_spv_coinjoin_messages_pool_message_PoolMessage_dash_spv_coinjoin_messages_pool_status_PoolStatus_Option_std_net_SocketAddr_bool_RTRN_
#define DMixingLifecycle Fn_ARGS_std_os_raw_c_void_bool_bool_Vec_dash_spv_coinjoin_messages_pool_status_PoolStatus_RTRN_
#define DMasternodeByHash Fn_ARGS_std_os_raw_c_void_Arr_u8_32_RTRN_Option_dashcore_sml_masternode_list_entry_qualified_masternode_list_entry_QualifiedMasternodeListEntry

@implementation DSCoinJoinWrapper

- (instancetype)initWithManagers:(DSCoinJoinManager *)manager chainManager:(DSChainManager *)chainManager {
    self = [super init];
    if (self) {
        _chainManager = chainManager;
        _manager = manager;
    }
    return self;
}

- (void)registerCoinJoin:(DCoinJoinClientOptions *)options {
    
    @synchronized (self) {
        if (_clientManager == NULL) {
            DGetWalletTransaction get_wallet_transaction = {
                .caller = &getTransaction,
            };
            DSignTransaction sign_transaction = {
                .caller = &signTransaction
            };
            DIsMineInput is_mine_input = {
                .caller = &isMineInput
            };
            DSelectCoins select_coins = {
                .caller = &selectCoinsGroupedByAddresses
            };
            DInputsWithAmount inputs_with_amount = {
                .caller = &countInputsWithAmount
            };
            DFreshCoinjoinAddress fresh_coinjoin_address = {
                .caller = &freshCoinJoinAddress
            };
            DCommitTransaction commit_transaction = {
                .caller = &commitTransaction
            };
            Fn_ARGS_std_os_raw_c_void_RTRN_bool is_synced = {
                .caller = &isBlockchainSynced
            };
            Fn_ARGS_std_os_raw_c_void_std_net_SocketAddr_RTRN_bool is_masternode_or_disconnect_requested = {
                .caller = &isMasternodeOrDisconnectRequested
            };
            Fn_ARGS_std_os_raw_c_void_std_net_SocketAddr_RTRN_bool disconnect_masternode = {
                .caller = &disconnectMasternode
            };
            Fn_ARGS_std_os_raw_c_void_String_Vec_u8_std_net_SocketAddr_bool_RTRN_bool send_message = {
                .caller = &sendMessage
            };
            Fn_ARGS_std_os_raw_c_void_Arr_u8_32_Arr_u8_32_RTRN_bool add_pending_masternode = {
                .caller = &addPendingMasternode
            };
            Fn_ARGS_std_os_raw_c_void_RTRN_ start_manager_async = {
                .caller = &startManagerAsync
            };
            Fn_ARGS_std_os_raw_c_void_bool_RTRN_Vec_String get_coinjoin_keys = {
                .caller = &getCoinJoinKeys
            };
            Fn_ARGS_std_os_raw_c_void_Arr_u8_32_u32_RTRN_i64 get_input_value_by_prev_outpoint = {
                .caller = &getInputValueByPrevoutHash
            };
            Fn_ARGS_std_os_raw_c_void_u32_RTRN_bool has_chain_lock = {
                .caller = &hasChainLock
            };
            Fn_ARGS_std_os_raw_c_void_RTRN_dashcore_sml_masternode_list_MasternodeList get_masternode_list = {
                .caller = &getMNList
            };
            Fn_ARGS_std_os_raw_c_void_RTRN_ update_success_block = {
                .caller = &updateSuccessBlock
            };
            Fn_ARGS_std_os_raw_c_void_RTRN_bool is_waiting_for_new_block = {
                .caller = &isWaitingForNewBlock
            };
            DSessionLifecycle session_lifecycle_listener = {
                .caller = &sessionLifecycleListener
            };
            DMixingLifecycle mixing_lifecycle_listener = {
                .caller = &mixingLifecycleListener
            };
            DMasternodeByHash masternode_by_hash = {
                .caller = &masternodeByHash
            };
            Fn_ARGS_std_os_raw_c_void_RTRN_usize valid_mns_count = {
                .caller = &validMNCount
            };
            DAvailableCoins available_coins = {
                .caller = &availableCoins
            };
            WalletEx *wallet_ex = dash_spv_coinjoin_wallet_ex_WalletEx_new(AS_RUST(self), options, get_wallet_transaction, sign_transaction, is_mine_input, available_coins, select_coins, inputs_with_amount, fresh_coinjoin_address, commit_transaction, is_synced, is_masternode_or_disconnect_requested, disconnect_masternode, send_message, add_pending_masternode, start_manager_async, get_coinjoin_keys);
            CoinJoin *coinjoin = dash_spv_coinjoin_coinjoin_CoinJoin_new(get_input_value_by_prev_outpoint, has_chain_lock, AS_RUST(self));
            _clientManager = dash_spv_coinjoin_coinjoin_client_manager_CoinJoinClientManager_new(wallet_ex, coinjoin, options, get_masternode_list, update_success_block, is_waiting_for_new_block, session_lifecycle_listener, mixing_lifecycle_listener, masternode_by_hash, valid_mns_count, AS_RUST(self));
        }
    }
}

- (BOOL)isRegistered {
    return self.clientManager != NULL;
}

- (void)updateOptions:(DCoinJoinClientOptions *)options {
    @synchronized (self) {
        dash_spv_coinjoin_coinjoin_client_manager_CoinJoinClientManager_change_options(self.clientManager, options);
    }
}

- (void)setStopOnNothingToDo:(BOOL)stop {
    @synchronized (self) {
        dash_spv_coinjoin_coinjoin_client_manager_CoinJoinClientManager_set_stop_on_nothing_to_do(self.clientManager, stop);
    }
}

- (BOOL)startMixing {
    @synchronized (self) {
        return dash_spv_coinjoin_coinjoin_client_manager_CoinJoinClientManager_start_mixing(self.clientManager);
    }
}

- (void)refreshUnusedKeys {
    @synchronized (self) {
        dash_spv_coinjoin_coinjoin_client_manager_CoinJoinClientManager_refresh_unused_keys(self.clientManager);
    }
}

- (BOOL)doAutomaticDenominatingWithDryRun:(BOOL)dryRun {
    @synchronized (self) {
        DBalance *balance = [DSCoinJoinBalance ffi_to:[self.manager getBalance]];
        return dash_spv_coinjoin_coinjoin_client_manager_CoinJoinClientManager_do_automatic_denominating(self.clientManager, balance, dryRun);
    }
}

- (void)doMaintenance {
    @synchronized (self) {
        DBalance *balance = [DSCoinJoinBalance ffi_to:[self.manager getBalance]];
        dash_spv_coinjoin_coinjoin_client_manager_CoinJoinClientManager_do_maintenance(self.clientManager, balance);
    }
}

- (void)initiateShutdown {
    @synchronized (self) {
        dash_spv_coinjoin_coinjoin_client_manager_CoinJoinClientManager_initiate_shutdown(self.clientManager);
    }
}

- (BOOL)isDenominatedAmount:(uint64_t)amount {
    return dash_spv_coinjoin_coinjoin_CoinJoin_is_denominated_amount(amount);
}

- (BOOL)isFullyMixed:(DSUTXO)utxo {
    @synchronized (self) {
        DOutPoint *outpoint = DOutPointFromUTXO(utxo);
        return dash_spv_coinjoin_coinjoin_client_manager_CoinJoinClientManager_check_if_is_fully_mixed(self.clientManager, outpoint);
    }
}

- (void)processDSQueueFrom:(DSPeer *)peer message:(NSData *)message {
    @synchronized (self) {
        SocketAddr *addr = DSocketAddrFrom(u128_ctor_u(peer.address), peer.port);
        dash_spv_coinjoin_coinjoin_client_manager_CoinJoinClientManager_process_ds_queue(self.clientManager, addr, slice_ctor(message));
    }
}

- (void)processMessageFrom:(DSPeer *)peer message:(NSData *)message type:(NSString *)type {
    @synchronized (self) {
        SocketAddr *addr = DSocketAddrFrom(u128_ctor_u(peer.address), peer.port);
        dash_spv_coinjoin_coinjoin_client_manager_CoinJoinClientManager_process_raw_message(self.clientManager, addr, slice_ctor(message), DChar(type));
    }
}

- (void)notifyNewBestBlock:(DSBlock *)block {
    if (block) {
        @synchronized (self) {
            dash_spv_coinjoin_coinjoin_client_manager_CoinJoinClientManager_update_block_tip(self.clientManager, block.height);
        }
    }
}

- (BOOL)isMixingFeeTx:(UInt256)txId {
    @synchronized (self) {
        return dash_spv_coinjoin_coinjoin_client_manager_CoinJoinClientManager_is_mixing_fee_tx(self.clientManager, DTxidCtor(u256_ctor_u(txId)));
    }
}

+ (DCoinJoinTransactionType *)coinJoinTxTypeForTransaction:(DSTransaction *)transaction {
    DSAccount *account = [transaction.chain firstAccountThatCanContainTransaction:transaction];
    return [DSCoinJoinWrapper coinJoinTxTypeForTransaction:transaction account:account];
}

+ (DCoinJoinTransactionType *)coinJoinTxTypeForTransaction:(DSTransaction *)transaction account:(DSAccount *)account {
    NSArray *amountsSent = [account amountsSentByTransaction:transaction];
    DTransaction *tx = [transaction ffi_malloc:transaction.chain.chainType];
    uint64_t *inputValues = malloc(amountsSent.count * sizeof(uint64_t));
    for (uintptr_t i = 0; i < amountsSent.count; i++) {
        inputValues[i] = [amountsSent[i] unsignedLongLongValue];
    }
    return dash_spv_coinjoin_models_coinjoin_tx_type_CoinJoinTransactionType_from_tx(tx, Vec_u64_ctor(amountsSent.count, inputValues));
}

- (void)unlockOutputs:(DSTransaction *)transaction {
    @synchronized (self) {
        DTransaction *tx = [transaction ffi_malloc:transaction.chain.chainType];
        dash_spv_coinjoin_coinjoin_client_manager_CoinJoinClientManager_unlock_outputs(self.clientManager, tx);
    }
}

- (uint64_t)getAnonymizableBalance:(BOOL)skipDenominated skipUnconfirmed:(BOOL)skipUnconfirmed {
    @synchronized (self) {
        return dash_spv_coinjoin_coinjoin_client_manager_CoinJoinClientManager_get_anonymizable_balance(self.clientManager, skipDenominated, skipUnconfirmed);
    }
}

- (uint64_t)getSmallestDenomination {
    return dash_spv_coinjoin_coinjoin_CoinJoin_get_smallest_denomination();
}

- (NSArray<NSNumber *> *)getStandardDenominations {
    @synchronized (self) {
        Arr_u64_5 *denominations = dash_spv_coinjoin_coinjoin_CoinJoin_get_standard_denominations();
        NSMutableArray<NSNumber *> *result = [NSMutableArray arrayWithCapacity:denominations->count];
        for (size_t i = 0; i < denominations->count; i++) {
            [result addObject:@(denominations->values[i])];
        }
        Arr_u64_5_destroy(denominations);
        return result;
    }
}

- (uint64_t)getCollateralAmount {
    return dash_spv_coinjoin_coinjoin_CoinJoin_get_collateral_amount();
}

- (uint64_t)getMaxCollateralAmount {
    return dash_spv_coinjoin_coinjoin_CoinJoin_get_max_collateral_amount();
}

- (BOOL)hasCollateralInputs:(BOOL)onlyConfirmed {
    @synchronized (self) {
        return dash_spv_coinjoin_coinjoin_client_manager_CoinJoinClientManager_has_collateral_inputs(_clientManager, onlyConfirmed);
    }
}

- (uint32_t)amountToDenomination:(uint64_t)amount {
    return dash_spv_coinjoin_coinjoin_CoinJoin_amount_to_denomination(amount);
}

- (int32_t)getRealOutpointCoinJoinRounds:(DSUTXO)utxo {
    @synchronized (self) {
        DOutPoint *outpoint = DOutPointFromUTXO(utxo);
        return dash_spv_coinjoin_coinjoin_client_manager_CoinJoinClientManager_get_real_outpoint_coinjoin_rounds(_clientManager, outpoint, 0);
    }
}

- (NSArray<NSNumber *> *)getSessionStatuses {
    @synchronized (self) {
        DPoolStatuses *statuses = dash_spv_coinjoin_coinjoin_client_manager_CoinJoinClientManager_get_sessions_status(_clientManager);
        NSMutableArray<NSNumber *> *statusArray = [NSMutableArray arrayWithCapacity:statuses->count];
        for (int i = 0; i < statuses->count; i++) {
            [statusArray addObject:@(DPoolStatusValue(statuses->values[i]))];
        }
        DPoolStatusesDtor(statuses);
        return statusArray;
    }
}

- (BOOL)isLockedCoin:(DSUTXO)utxo {
    @synchronized (self) {
        DOutPoint *outpoint = DOutPointFromUTXO(utxo);
        return dash_spv_coinjoin_coinjoin_client_manager_CoinJoinClientManager_is_locked_coin(self.clientManager, outpoint);
    }
}

- (void)stopAndResetClientManager {
    @synchronized (self) {
        dash_spv_coinjoin_coinjoin_client_manager_CoinJoinClientManager_stop_and_reset(self.clientManager);
    }
}

- (DSChain *)chain {
    return self.chainManager.chain;
}

- (void)dealloc {
    @synchronized (self) {
        dash_spv_coinjoin_coinjoin_client_manager_CoinJoinClientManager_destroy(self.clientManager);
        _clientManager = NULL;
    }
}


///
/// MARK: Rust FFI callbacks
///

int64_t getInputValueByPrevoutHash(const void *context, u256 *tx_hash, uint32_t index) {
    @synchronized (context) {
        DSCoinJoinWrapper *wrapper = AS_OBJC(context);
        DSWallet *wallet = [wrapper.chain.wallets firstObject];
        UInt256 txHash = u256_cast(tx_hash);
        u256_dtor(tx_hash);
        return [wallet inputValue:txHash inputIndex:index];
    }
}


bool hasChainLock(const void *context, uint32_t block_height) {
    BOOL hasChainLock = NO;
    
    @synchronized (context) {
        DSCoinJoinWrapper *wrapper = AS_OBJC(context);
        hasChainLock = [wrapper.chain blockHeightChainLocked:block_height];
    }
    
    return hasChainLock;
}

DTransaction *getTransaction(const void *context, u256 *tx_hash) {
    // TODO: check if reversed
    UInt256 txHash = u256_cast(tx_hash);
    u256_dtor(tx_hash);
    DTransaction *tx = NULL;
    
    @synchronized (context) {
        DSCoinJoinWrapper *wrapper = AS_OBJC(context);
        DSTransaction *transaction = [wrapper.chain transactionForHash:txHash];
        if (transaction)
            tx = [transaction ffi_malloc:wrapper.chain.chainType];
    }
    
    return tx;
}

bool isMineInput(const void *context, DOutPoint *outpoint) {
    UInt256 txHash = u256_cast(dashcore_hash_types_Txid_inner(outpoint->txid));
    uint32_t index = outpoint->vout;
    BOOL result = NO;
    DOutPointDtor(outpoint);
    @synchronized (context) {
        result = [AS_OBJC(context).manager isMineInput:txHash index:index];
    }
    
    return result;
}

DInputCoins* availableCoins(const void *context, bool onlySafe, DCoinControl *coinControl, WalletEx *walletEx) {
    DInputCoins *gatheredOutputs;
    @synchronized (context) {
        DSCoinJoinWrapper *wrapper = AS_OBJC(context);
        DChainType *chainType = wrapper.chain.chainType;
        DSCoinControl *cc = [[DSCoinControl alloc] initWithFFICoinControl:coinControl chainType:wrapper.chain.chainType];
        NSArray<DSInputCoin *> *coins = [wrapper.manager availableCoins:walletEx
                                                               onlySafe:onlySafe
                                                            coinControl:cc
                                                          minimumAmount:1
                                                          maximumAmount:MAX_MONEY
                                                       minimumSumAmount:MAX_MONEY
                                                           maximumCount:0];
        DCoinControlDtor(coinControl);
        NSUInteger count = coins.count;
        DInputCoin **values = malloc(count * sizeof(DInputCoin *));
        for (NSUInteger i = 0; i < count; i++) {
            values[i] = [coins[i] ffi_malloc:chainType];
        }
        gatheredOutputs = DInputCoinsCtor(count, values);
    }
    
    return gatheredOutputs;
}

DCompactTallyItems* selectCoinsGroupedByAddresses(const void *context,
                                                  bool skipDenominated,
                                                  bool anonymizable,
                                                  bool skipUnconfirmed,
                                                  int maxOupointsPerAddress,
                                                  WalletEx* walletEx) {
    @synchronized (context) {
        DSCoinJoinWrapper *wrapper = AS_OBJC(context);
        NSArray<DSCompactTallyItem *> *tempVecTallyRet = [wrapper.manager selectCoinsGroupedByAddresses:walletEx
                                                                                        skipDenominated:skipDenominated
                                                                                           anonymizable:anonymizable
                                                                                        skipUnconfirmed:skipUnconfirmed
                                                                                  maxOupointsPerAddress:maxOupointsPerAddress];
        
        NSUInteger count = tempVecTallyRet.count;
        DCompactTallyItem **values = malloc(count * sizeof(DCompactTallyItem *));
        for (uint32_t i = 0; i < tempVecTallyRet.count; i++) {
            values[i] = [tempVecTallyRet[i] ffi_malloc:wrapper.chain.chainType];
        }
        return DCompactTallyItemsCtor(count, values);
    }
    
}

DTransaction* signTransaction(const void *context, DTransaction *transaction, bool anyoneCanPay) {
    @synchronized (context) {
        DSCoinJoinWrapper *wrapper = AS_OBJC(context);
        DSTransaction *tx = [[DSTransaction alloc] initWithTransaction:transaction onChain:wrapper.chain];
        DTransactionDtor(transaction);
        BOOL isSigned = [wrapper.chain.wallets.firstObject.accounts.firstObject signTransaction:tx anyoneCanPay:anyoneCanPay];
        if (isSigned) {
            return [tx ffi_malloc:wrapper.chain.chainType];
        }
    }
    
    return nil;
}

uint32_t countInputsWithAmount(const void *context, uint64_t inputAmount) {
    @synchronized (context) {
        return [AS_OBJC(context).manager countInputsWithAmount:inputAmount];
    }
}

char *freshCoinJoinAddress(const void *context, bool internal) {
    @synchronized (context) {
        DSCoinJoinWrapper *wrapper = AS_OBJC(context);
        NSString *address = [wrapper.manager freshAddress:internal];
        return DChar(address);
    }
}

bool commitTransaction(const void *context,
                       DTxOutputs *items,
                       DCoinControl *coin_control,
                       bool is_denominating,
                       u256 *client_session_id) {
    NSMutableArray *amounts = [NSMutableArray array];
    NSMutableArray *scripts = [NSMutableArray array];
    for (uintptr_t i = 0; i < items->count; i++) {
        DTxOut *recipient = items->values[i];
        [amounts addObject:@(recipient->value)];
        NSData *script = NSDataFromPtr(recipient->script_pubkey->_0);
        [scripts addObject:script];
    }
    DTxOutputsDtor(items);
    bool result = false;
    
    @synchronized (context) {
        DSCoinJoinWrapper *wrapper = AS_OBJC(context);
        DSCoinControl *cc = [[DSCoinControl alloc] initWithFFICoinControl:coin_control chainType:wrapper.chain.chainType];
        DCoinControlDtor(coin_control);
        result = [wrapper.manager commitTransactionForAmounts:amounts outputs:scripts coinControl:cc onPublished:^(UInt256 txId, NSError * _Nullable error) {
            @synchronized (context) {
                if (error) {
                    DSLog(@"[%@] CoinJoin: commit tx error: %@, tx type: %@", wrapper.chain.name, error, is_denominating ? @"denominations" : @"collateral");
                } else if (is_denominating) {
                    #if DEBUG
                        DSLog(@"[%@] CoinJoin tx: Denominations Created: %@", wrapper.chain.name, uint256_reverse_hex(txId));
                    #else
                        DSLog(@"[%@] CoinJoin tx: Denominations Created: %@", wrapper.chain.name, @"<REDACTED>");
                    #endif
                    bool isFinished = dash_spv_coinjoin_coinjoin_client_manager_CoinJoinClientManager_finish_automatic_denominating(wrapper.clientManager, client_session_id);
                    
                    if (!isFinished)
                        DSLog(@"[%@] CoinJoin: auto_denom not finished", wrapper.chain.name);
                    [wrapper.manager onTransactionProcessed:txId type:dash_spv_coinjoin_models_coinjoin_tx_type_CoinJoinTransactionType_CreateDenomination_ctor()];
                } else {
                    #if DEBUG
                        DSLog(@"[%@] CoinJoin tx: Collateral Created: %@", wrapper.chain.name, uint256_reverse_hex(txId));
                    #else
                        DSLog(@"[%@] CoinJoin tx: Collateral Created: %@", wrapper.chain.name, @"<REDACTED>");
                    #endif
                    [wrapper.manager onTransactionProcessed:txId type:dash_spv_coinjoin_models_coinjoin_tx_type_CoinJoinTransactionType_MakeCollateralInputs_ctor()];
                }
                u256_dtor(client_session_id);
            }
        }];
    }
    
    return result;
}

DMasternodeEntry* masternodeByHash(const void *context, u256 *hash) {
    UInt256 mnHash = u256_cast(hash);
    DMasternodeEntry *masternode;
    u256_dtor(hash);
    @synchronized (context) {
        masternode = [AS_OBJC(context).manager masternodeEntryByHash:mnHash];
    }
    
    return masternode;
}

uintptr_t validMNCount(const void *context) {
    @synchronized (context) {
        return [AS_OBJC(context).manager validMNCount];
    }
}

DMasternodeList* getMNList(const void *context) {
    @synchronized (context) {
        DSCoinJoinWrapper *wrapper = AS_OBJC(context);
        return [wrapper.manager mnList];
    }
}

bool isBlockchainSynced(const void *context) {
    @synchronized (context) {
        return AS_OBJC(context).manager.isChainSynced;
    }
}

bool isMasternodeOrDisconnectRequested(const void *context, SocketAddr *addr) {
    u128 *ip_address = DSocketAddrIp(addr);
    uint16_t port = DSocketAddrPort(addr);
    UInt128 ipAddress = u128_cast(ip_address);
    u128_dtor(ip_address);
    SocketAddr_destroy(addr);
    @synchronized (context) {
        return [AS_OBJC(context).manager isMasternodeOrDisconnectRequested:ipAddress port:port];
    }
}

bool disconnectMasternode(const void *context, SocketAddr *addr) {
    u128 *ip_address = DSocketAddrIp(addr);
    uint16_t port = DSocketAddrPort(addr);
    UInt128 ipAddress = u128_cast(ip_address);
    u128_dtor(ip_address);
    SocketAddr_destroy(addr);

    @synchronized (context) {
        return [AS_OBJC(context).manager disconnectMasternode:ipAddress port:port];
    }
}
bool sendMessage(const void *context, char *message_type, Vec_u8 *message, SocketAddr *addr, bool warn) {
    NSString *messageType = NSStringFromPtr(message_type);
    str_destroy(message_type);
    u128 *ip_address = DSocketAddrIp(addr);
    uint16_t port = DSocketAddrPort(addr);
    UInt128 ipAddress = u128_cast(ip_address);
    SocketAddr_destroy(addr);
    NSData *data = NSDataFromPtr(message);
    bytes_dtor(message);
    @synchronized (context) {
        return [AS_OBJC(context).manager sendMessageOfType:messageType message:data withPeerIP:ipAddress port:port warn:warn];
    }
}

bool addPendingMasternode(const void *context, u256 *pro_tx_hash, u256 *session_id) {
    UInt256 sessionId = u256_cast(session_id);
    UInt256 proTxHash = u256_cast(pro_tx_hash);
    u256_dtor(session_id);
    u256_dtor(pro_tx_hash);
    @synchronized (context) {
        return [AS_OBJC(context).manager addPendingMasternode:proTxHash clientSessionId:sessionId];
    }
}

void startManagerAsync(const void *context) {
    @synchronized (context) {
        [AS_OBJC(context).manager startAsync];
    }
}

void updateSuccessBlock(const void *context) {
    @synchronized (context) {
        [AS_OBJC(context).manager updateSuccessBlock];
    }
}

bool isWaitingForNewBlock(const void *context) {
    @synchronized (context) {
        return [AS_OBJC(context).manager isWaitingForNewBlock];
    }
}

void sessionLifecycleListener(const void *context,
                              bool is_complete,
                              int32_t base_session_id,
                              u256 *client_session_id,
                              uint32_t denomination,
                              DPoolState *state,
                              DPoolMessage *message,
                              DPoolStatus *status,
                              SocketAddr *addr,
                              bool joined
                              ) {
    @synchronized (context) {
        UInt256 clientSessionId = u256_cast(client_session_id);
        u128 *ip = DSocketAddrIp(addr);
        UInt128 ipAddress = u128_cast(ip);
        u256_dtor(client_session_id);
        DPoolState state_index = DPoolStateValue(state);
        DPoolMessage message_index = DPoolMessageValue(message);
        DPoolStatus status_index = DPoolStatusValue(status);
        DPoolStateDtor(state);
        DPoolMessageDtor(message);
        DPoolStatusDtor(status);
        SocketAddr_destroy(addr);

        if (is_complete) {
            [AS_OBJC(context).manager onSessionComplete:base_session_id
                                        clientSessionId:clientSessionId
                                           denomination:denomination
                                              poolState:state_index
                                            poolMessage:message_index
                                             poolStatus:status_index
                                              ipAddress:ipAddress
                                               isJoined:joined];
        } else {
            [AS_OBJC(context).manager onSessionStarted:base_session_id
                                       clientSessionId:clientSessionId
                                          denomination:denomination
                                             poolState:state_index
                                           poolMessage:message_index
                                            poolStatus:status_index
                                             ipAddress:ipAddress
                                              isJoined:joined];
        }
    }
}

void mixingLifecycleListener(const void *context,
                             bool is_complete,
                             bool is_interrupted,
                             DPoolStatuses *pool_statuses) {
    @synchronized (context) {
        NSMutableArray *statuses = [NSMutableArray array];
        for (uintptr_t i = 0; i < pool_statuses->count; i++) {
            [statuses addObject:@(DPoolStatusValue(pool_statuses->values[i]))];
        }
        DPoolStatusesDtor(pool_statuses);
        if (is_complete || is_interrupted) {
            [AS_OBJC(context).manager onMixingComplete:statuses isInterrupted:is_interrupted];
        } else {
            [AS_OBJC(context).manager onMixingStarted:statuses];
        }
    }
}

Vec_String* getCoinJoinKeys(const void *context, bool used) {
    @synchronized (context) {
        DSCoinJoinWrapper *wrapper = AS_OBJC(context);
        NSArray<NSString *> *addresses = used ? [wrapper.manager getIssuedReceiveAddresses] : [wrapper.manager getUsedReceiveAddresses];
        return [NSArray ffi_to_vec_of_string:addresses];
    }
}

@end
