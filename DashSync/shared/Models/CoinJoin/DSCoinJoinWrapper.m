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
#import "DSSimplifiedMasternodeEntry+Mndiff.h"
#import "DSMasternodeList+Mndiff.h"
#import "DSAccount.h"
#import "DSChainManager.h"
#import "DSCoinJoinWrapper.h"
#import "DSBlock.h"

#define AS_OBJC(context) ((__bridge DSCoinJoinWrapper *)(context))
#define AS_RUST(context) ((__bridge void *)(context))

@implementation DSCoinJoinWrapper

- (instancetype)initWithManagers:(DSCoinJoinManager *)manager chainManager:(DSChainManager *)chainManager {
    self = [super init];
    if (self) {
        _chainManager = chainManager;
        _manager = manager;
    }
    return self;
}

- (void)registerCoinJoin:(CoinJoinClientOptions *)options {
    @synchronized (self) {
        if (_clientManager == NULL) {
            DSLog(@"[OBJ-C] CoinJoin: register client manager");
            _clientManager = register_client_manager(AS_RUST(self), options, getMNList, destroyMNList, getInputValueByPrevoutHash, hasChainLock, destroyInputValue, updateSuccessBlock, isWaitingForNewBlock, getTransaction, signTransaction, destroyTransaction, isMineInput, commitTransaction, isBlockchainSynced, freshCoinJoinAddress, countInputsWithAmount, availableCoins, destroyGatheredOutputs, selectCoinsGroupedByAddresses, destroySelectedCoins, isMasternodeOrDisconnectRequested, disconnectMasternode, sendMessage, addPendingMasternode, startManagerAsync, sessionLifecycleListener, mixingLifecycleListener, getCoinJoinKeys, destroyCoinJoinKeys);

            DSLog(@"[OBJ-C] CoinJoin: register client queue manager");
            add_client_queue_manager(_clientManager, masternodeByHash, destroyMasternodeEntry, validMNCount, AS_RUST(self));
        }
    }
}

- (BOOL)isRegistered {
    return self.clientManager != NULL;
}

- (void)updateOptions:(CoinJoinClientOptions *)options {
    @synchronized (self) {
        change_coinjoin_options(_clientManager, options);
    }
}

- (void)setStopOnNothingToDo:(BOOL)stop {
    @synchronized (self) {
        set_stop_on_nothing_to_do(self.clientManager, stop);
    }
}

- (BOOL)startMixing {
    @synchronized (self) {
        return start_mixing(self.clientManager);
    }
}

- (void)refreshUnusedKeys {
    @synchronized (self) {
        refresh_unused_keys(self.clientManager);
    }
}

- (BOOL)doAutomaticDenominatingWithDryRun:(BOOL)dryRun {
    @synchronized (self) {
        Balance *balance = [[self.manager getBalance] ffi_malloc];
        BOOL result = do_automatic_denominating(_clientManager, *balance, dryRun);
        [DSCoinJoinBalance ffi_free:balance];
        
        return result;
    }
}

- (void)doMaintenance {
    @synchronized (self) {
        Balance *balance = [[self.manager getBalance] ffi_malloc];
        do_maintenance(_clientManager, *balance);
        [DSCoinJoinBalance ffi_free:balance];
    }
}

- (void)processDSQueueFrom:(DSPeer *)peer message:(NSData *)message {
    @synchronized (self) {
        DSLog(@"[OBJ-C] CoinJoin: process DSQ from %@", peer.location);
        
        ByteArray *array = malloc(sizeof(ByteArray));
        array->len = (uintptr_t)message.length;
        array->ptr = data_malloc(message);
        
        process_ds_queue(_clientManager, peer.address.u8, peer.port, array);
        
        if (array) {
            if (array->ptr) {
                free((void *)array->ptr);
            }
            
            free(array);
        }
    }
}

- (void)processMessageFrom:(DSPeer *)peer message:(NSData *)message type:(NSString *)type {
    @synchronized (self) {
        ByteArray *array = malloc(sizeof(ByteArray));
        array->len = (uintptr_t)message.length;
        array->ptr = data_malloc(message);
        
        process_coinjoin_message(_clientManager, peer.address.u8, peer.port, array, [type UTF8String]);
        
        if (array->ptr) {
            free((void *)array->ptr);
        }
        
        free(array);
    }
}

- (void)notifyNewBestBlock:(DSBlock *)block {
    if (block) {
        @synchronized (self) {
            notify_new_best_block(_clientManager, (uint8_t (*)[32])(block.blockHash.u8), block.height);
        }
    }
}

- (BOOL)isMixingFeeTx:(UInt256)txId {
    @synchronized (self) {
        return is_mixing_fee_tx(_clientManager, (uint8_t (*)[32])(txId.u8));
    }
}

- (CoinJoinTransactionType)coinJoinTxTypeForTransaction:(DSTransaction *)transaction {
    DSAccount *account = [self.chain firstAccountThatCanContainTransaction:transaction];
    NSArray *amountsSent = [account amountsSentByTransaction:transaction];
    
    Transaction *tx = [transaction ffi_malloc:self.chain.chainType];
    uint64_t *inputValues = malloc(amountsSent.count * sizeof(uint64_t));

    for (uintptr_t i = 0; i < amountsSent.count; i++) {
        inputValues[i] = [amountsSent[i] unsignedLongLongValue];
    }
    
    CoinJoinTransactionType type = get_coinjoin_tx_type(tx, inputValues, amountsSent.count);
    [DSTransaction ffi_free:tx];
    free(inputValues);
    
    return type;
}

- (uint64_t)getAnonymizableBalance:(BOOL)skipDenominated skipUnconfirmed:(BOOL)skipUnconfirmed {
    @synchronized (self) {
        return get_anonymizable_balance(_clientManager, skipDenominated, skipUnconfirmed);
    }
}

- (uint64_t)getSmallestDenomination {
    return coinjoin_get_smallest_denomination();
}

- (NSArray<NSNumber *> *)getStandardDenominations {
    @synchronized (self) {
        CoinJoinDenominations *denominations = get_standard_denominations();
        NSMutableArray<NSNumber *> *result = [NSMutableArray arrayWithCapacity:denominations->length];
        
        for (size_t i = 0; i < denominations->length; i++) {
            [result addObject:@(denominations->denoms[i])];
        }
        
        destroy_coinjoin_denomination(denominations);
        return result;
    }
}

- (uint64_t)getCollateralAmount {
    @synchronized (self) {
        return get_collateral_amount();
    }
}

- (uint32_t)amountToDenomination:(uint64_t)amount {
    @synchronized (self) {
        return amount_to_denomination(amount);
    }
}

- (int32_t)getRealOutpointCoinJoinRounds:(DSUTXO)utxo {
    @synchronized (self) {
        UInt256 hash = utxo.hash;
        return get_real_outpoint_coinjoin_rounds(_clientManager, (uint8_t (*)[32])&hash, (uint32_t)utxo.n, 0);
    }
}

- (NSArray<NSNumber *> *)getSessionStatuses {
    @synchronized (self) {
        CoinJoinSessionStatuses* statuses = get_sessions_status(_clientManager);
        
        if (statuses) {
            NSMutableArray<NSNumber *> *statusArray = [NSMutableArray arrayWithCapacity:statuses->length];
            
            for (size_t i = 0; i < statuses->length; i++) {
                PoolStatus status = statuses->statuses[i];
                [statusArray addObject:@(status)];
            }
            
            destroy_coinjoin_session_statuses(statuses);
            
            return statusArray;
        } else {
            return @[];
        }
    }
}

- (void)stopAndResetClientManager {
    @synchronized (self) {
        stop_and_reset_coinjoin(_clientManager);
    }
}

- (DSChain *)chain {
    return self.chainManager.chain;
}

- (void)dealloc {
    @synchronized (self) {
        unregister_client_manager(_clientManager);
    }
}

///
/// MARK: Rust FFI callbacks
///

InputValue *getInputValueByPrevoutHash(uint8_t (*prevout_hash)[32], uint32_t index, const void *context) {
    UInt256 txHash = *((UInt256 *)prevout_hash);
    InputValue *inputValue = NULL;
    
    @synchronized (context) {
        DSCoinJoinWrapper *wrapper = AS_OBJC(context);
        inputValue = malloc(sizeof(InputValue));
        DSWallet *wallet = wrapper.chain.wallets.firstObject;
        int64_t value = [wallet inputValue:txHash inputIndex:index];
            
        if (value != -1) {
            inputValue->is_valid = TRUE;
            inputValue->value = value;
        } else {
            inputValue->is_valid = FALSE;
        }
    }
    
    processor_destroy_block_hash(prevout_hash);
    return inputValue;
}


bool hasChainLock(Block *block, const void *context) {
    BOOL hasChainLock = NO;
    
    @synchronized (context) {
        DSCoinJoinWrapper *wrapper = AS_OBJC(context);
        hasChainLock = [wrapper.chain blockHeightChainLocked:block->height];
    }
    
    processor_destroy_block(block);
    return hasChainLock;
}

Transaction *getTransaction(uint8_t (*tx_hash)[32], const void *context) {
    UInt256 txHash = *((UInt256 *)tx_hash);
    Transaction *tx = NULL;
    
    @synchronized (context) {
        DSCoinJoinWrapper *wrapper = AS_OBJC(context);
        DSTransaction *transaction = [wrapper.chain transactionForHash:txHash];

        if (transaction) {
            tx = [transaction ffi_malloc:wrapper.chain.chainType];
        }
    }
    
    processor_destroy_block_hash(tx_hash);
    return tx;
}

bool isMineInput(uint8_t (*tx_hash)[32], uint32_t index, const void *context) {
    UInt256 txHash = *((UInt256 *)tx_hash);
    BOOL result = NO;
    
    @synchronized (context) {
        result = [AS_OBJC(context).manager isMineInput:txHash index:index];
    }
    
    processor_destroy_block_hash(tx_hash);
    return result;
}

GatheredOutputs* availableCoins(bool onlySafe, CoinControl coinControl, WalletEx *walletEx, const void *context) {
    GatheredOutputs *gatheredOutputs;
    
    @synchronized (context) {
        DSCoinJoinWrapper *wrapper = AS_OBJC(context);
        ChainType chainType = wrapper.chain.chainType;
        DSCoinControl *cc = [[DSCoinControl alloc] initWithFFICoinControl:&coinControl];
        NSArray<DSInputCoin *> *coins = [wrapper.manager availableCoins:walletEx onlySafe:onlySafe coinControl:cc minimumAmount:1 maximumAmount:MAX_MONEY minimumSumAmount:MAX_MONEY maximumCount:0];
        
        gatheredOutputs = malloc(sizeof(GatheredOutputs));
        InputCoin **coinsArray = malloc(coins.count * sizeof(InputCoin *));
        
        for (uintptr_t i = 0; i < coins.count; ++i) {
            coinsArray[i] = [coins[i] ffi_malloc:chainType];
        }
        
        gatheredOutputs->items = coinsArray;
        gatheredOutputs->item_count = (uintptr_t)coins.count;
    }
    
    return gatheredOutputs;
}

SelectedCoins* selectCoinsGroupedByAddresses(bool skipDenominated, bool anonymizable, bool skipUnconfirmed, int maxOupointsPerAddress, WalletEx* walletEx, const void *context) {
    SelectedCoins *vecTallyRet;
    
    @synchronized (context) {
        DSCoinJoinWrapper *wrapper = AS_OBJC(context);
        NSArray<DSCompactTallyItem *> *tempVecTallyRet = [wrapper.manager selectCoinsGroupedByAddresses:walletEx skipDenominated:skipDenominated anonymizable:anonymizable skipUnconfirmed:skipUnconfirmed maxOupointsPerAddress:maxOupointsPerAddress];
        
        vecTallyRet = malloc(sizeof(SelectedCoins));
        vecTallyRet->item_count = tempVecTallyRet.count;
        vecTallyRet->items = malloc(tempVecTallyRet.count * sizeof(CompactTallyItem *));
        
        for (uint32_t i = 0; i < tempVecTallyRet.count; i++) {
            vecTallyRet->items[i] = [tempVecTallyRet[i] ffi_malloc:wrapper.chain.chainType];
        }
    }
    
    return vecTallyRet;
}

void destroyInputValue(InputValue *value) {
    if (value) {
        free(value);
    }
}

void destroyTransaction(Transaction *value) {
    if (value) {
        [DSTransaction ffi_free:value];
    }
}

void destroySelectedCoins(SelectedCoins *selectedCoins) {
    if (!selectedCoins) {
        return;
    }
    
    if (selectedCoins->item_count > 0 && selectedCoins->items) {
        for (int i = 0; i < selectedCoins->item_count; i++) {
            [DSCompactTallyItem ffi_free:selectedCoins->items[i]];
        }
        
        free(selectedCoins->items);
    }
    
    free(selectedCoins);
}

void destroyGatheredOutputs(GatheredOutputs *gatheredOutputs) {
    if (!gatheredOutputs) {
        return;
    }
    
    if (gatheredOutputs->item_count > 0 && gatheredOutputs->items) {
        for (int i = 0; i < gatheredOutputs->item_count; i++) {
            [DSTransactionOutput ffi_free:gatheredOutputs->items[i]->output];
            free(gatheredOutputs->items[i]->outpoint_hash);
        }
        
        free(gatheredOutputs->items);
    }
    
    free(gatheredOutputs);
}

Transaction* signTransaction(Transaction *transaction, bool anyoneCanPay, const void *context) {
    DSLog(@"[OBJ-C CALLBACK] CoinJoin: signTransaction");
    
    @synchronized (context) {
        DSCoinJoinWrapper *wrapper = AS_OBJC(context);
        DSTransaction *tx = [[DSTransaction alloc] initWithTransaction:transaction onChain:wrapper.chain];
        destroy_transaction(transaction);
        BOOL isSigned = [wrapper.chain.wallets.firstObject.accounts.firstObject signTransaction:tx anyoneCanPay:anyoneCanPay];
        
        if (isSigned) {
            return [tx ffi_malloc:wrapper.chain.chainType];
        }
    }
    
    return nil;
}

unsigned int countInputsWithAmount(unsigned long long inputAmount, const void *context) {
    @synchronized (context) {
        return [AS_OBJC(context).manager countInputsWithAmount:inputAmount];
    }
}

ByteArray freshCoinJoinAddress(bool internal, const void *context) {
    @synchronized (context) {
        DSCoinJoinWrapper *wrapper = AS_OBJC(context);
        NSString *address = [wrapper.manager freshAddress:internal];
        
        return script_pubkey_for_address([address UTF8String], wrapper.chain.chainType);
    }
}

bool commitTransaction(struct Recipient **items, uintptr_t item_count, bool is_denominating, uint8_t (*client_session_id)[32], const void *context) {
    DSLog(@"[OBJ-C] CoinJoin: commitTransaction");
    
    NSMutableArray *amounts = [NSMutableArray array];
    NSMutableArray *scripts = [NSMutableArray array];
    
    for (uintptr_t i = 0; i < item_count; i++) {
        Recipient *recipient = items[i];
        [amounts addObject:@(recipient->amount)];
        NSData *script = [NSData dataWithBytes:recipient->script_pub_key.ptr length:recipient->script_pub_key.len];
        [scripts addObject:script];
    }
    
    bool result = false;
    
    @synchronized (context) {
        DSCoinJoinWrapper *wrapper = AS_OBJC(context);
        result = [wrapper.manager commitTransactionForAmounts:amounts outputs:scripts onPublished:^(UInt256 txId, NSError * _Nullable error) {
            if (error) {
                DSLog(@"[OBJ-C] CoinJoin: commit tx error: %@, tx type: %@", error, is_denominating ? @"denominations" : @"collateral");
            } else if (is_denominating) {
                DSLog(@"[OBJ-C] CoinJoin tx: Denominations Created: %@", uint256_reverse_hex(txId));
                bool isFinished = finish_automatic_denominating(wrapper.clientManager, client_session_id);
                
                if (!isFinished) {
                    DSLog(@"[OBJ-C] CoinJoin: auto_denom not finished");
                }
                
                processor_destroy_block_hash(client_session_id);
                [wrapper.manager onTransactionProcessed:txId type:CoinJoinTransactionType_CreateDenomination];
            } else {
                DSLog(@"[OBJ-C] CoinJoin tx: Collateral Created: %@", uint256_reverse_hex(txId));
                [wrapper.manager onTransactionProcessed:txId type:CoinJoinTransactionType_MakeCollateralInputs];
            }
        }];
    }
    
    return result;
}

MasternodeEntry* masternodeByHash(uint8_t (*hash)[32], const void *context) {
    UInt256 mnHash = *((UInt256 *)hash);
    MasternodeEntry *masternode;
    
    @synchronized (context) {
        masternode = [[AS_OBJC(context).manager masternodeEntryByHash:mnHash] ffi_malloc];
    }
    
    return masternode;
}

void destroyMasternodeEntry(MasternodeEntry *masternodeEntry) {
    if (!masternodeEntry) {
        return;
    }
    
    [DSSimplifiedMasternodeEntry ffi_free:masternodeEntry];
}

uint64_t validMNCount(const void *context) {
    @synchronized (context) {
        return [AS_OBJC(context).manager validMNCount];
    }
}

MasternodeList* getMNList(const void *context) {
    @synchronized (context) {
        DSCoinJoinWrapper *wrapper = AS_OBJC(context);
        DSMasternodeList *mnList = [wrapper.manager mnList];
        return [mnList ffi_malloc];
    }
}

void destroyMNList(MasternodeList *masternodeList) { // TODO: check destroyMasternodeList
    if (!masternodeList) {
        return;
    }
    
    [DSMasternodeList ffi_free:masternodeList];
}

bool isBlockchainSynced(const void *context) {
    @synchronized (context) {
        return AS_OBJC(context).manager.isChainSynced;
    }
}

bool isMasternodeOrDisconnectRequested(uint8_t (*ip_address)[16], uint16_t port, const void *context) {
    UInt128 ipAddress = *((UInt128 *)ip_address);
    
    @synchronized (context) {
        return [AS_OBJC(context).manager isMasternodeOrDisconnectRequested:ipAddress port:port];
    }
}

bool disconnectMasternode(uint8_t (*ip_address)[16], uint16_t port, const void *context) {
    UInt128 ipAddress = *((UInt128 *)ip_address);
    
    @synchronized (context) {
        return [AS_OBJC(context).manager disconnectMasternode:ipAddress port:port];
    }
}

bool sendMessage(char *message_type, ByteArray *byteArray, uint8_t (*ip_address)[16], uint16_t port, bool warn, const void *context) {
    NSString *messageType = [NSString stringWithUTF8String:message_type];
    UInt128 ipAddress = *((UInt128 *)ip_address);
    
    @synchronized (context) {
        NSData *message = [NSData dataWithBytes:byteArray->ptr length:byteArray->len];
        return [AS_OBJC(context).manager sendMessageOfType:messageType message:message withPeerIP:ipAddress port:port warn:warn];
    }
}

bool addPendingMasternode(uint8_t (*pro_tx_hash)[32], uint8_t (*session_id)[32], const void *context) {
    UInt256 sessionId = *((UInt256 *)session_id);
    UInt256 proTxHash = *((UInt256 *)pro_tx_hash);
    
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

void sessionLifecycleListener(bool is_complete,
                             int32_t base_session_id,
                             uint8_t (*client_session_id)[32],
                             uint32_t denomination,
                             enum PoolState state,
                             enum PoolMessage message,
                             uint8_t (*ip_address)[16],
                             bool joined,
                             const void *context) {
    @synchronized (context) {
        UInt256 clientSessionId = *((UInt256 *)client_session_id);
        UInt128 ipAddress = *((UInt128 *)ip_address);
        
        if (is_complete) {
            [AS_OBJC(context).manager onSessionComplete:base_session_id clientSessionId:clientSessionId denomination:denomination poolState:state poolMessage:message ipAddress:ipAddress isJoined:joined];
        } else {
            [AS_OBJC(context).manager onSessionStarted:base_session_id clientSessionId:clientSessionId denomination:denomination poolState:state poolMessage:message ipAddress:ipAddress isJoined:joined];
        }
    }
}

void mixingLifecycleListener(bool is_complete,
                             const enum PoolStatus *pool_statuses,
                             uintptr_t pool_statuses_len,
                             const void *context) {
    @synchronized (context) {
        NSMutableArray *statuses = [NSMutableArray array];

        for (uintptr_t i = 0; i < pool_statuses_len; i++) {
            [statuses addObject:@(pool_statuses[i])];
        }

        if (is_complete) {
            [AS_OBJC(context).manager onMixingComplete:statuses];
        } else {
            [AS_OBJC(context).manager onMixingStarted:statuses];
        }
    }
}

CoinJoinKeys* getCoinJoinKeys(bool used, const void *context) {
    @synchronized (context) {
        DSCoinJoinWrapper *wrapper = AS_OBJC(context);
        NSArray *addresses;
        
        if (used) {
            addresses = [wrapper.manager getIssuedReceiveAddresses];
        } else {
            addresses = [wrapper.manager getUsedReceiveAddresses];
        }
        
        CoinJoinKeys *keys = malloc(sizeof(CoinJoinKeys));
        keys->item_count = addresses.count;
        keys->items = malloc(sizeof(ByteArray *) * keys->item_count);
        
        for (NSUInteger i = 0; i < addresses.count; i++) {
            NSString *address = addresses[i];
            ByteArray *byteArray = malloc(sizeof(ByteArray));
            byteArray->ptr = script_pubkey_for_address([address UTF8String], wrapper.chain.chainType).ptr;
            byteArray->len = script_pubkey_for_address([address UTF8String], wrapper.chain.chainType).len;
            keys->items[i] = byteArray;
        }
        
        return keys;
    }
}

void destroyCoinJoinKeys(struct CoinJoinKeys *coinjoin_keys) {
    if (coinjoin_keys == NULL) {
        return;
    }
    
    for (uintptr_t i = 0; i < coinjoin_keys->item_count; i++) {
        if (coinjoin_keys->items[i] != NULL) {
            free(coinjoin_keys->items[i]->ptr);
            free(coinjoin_keys->items[i]);
        }
    }
    
    free(coinjoin_keys->items);
    free(coinjoin_keys);
}

@end
