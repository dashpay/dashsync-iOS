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

- (void)runCoinJoin {
    if (_options == NULL) {
        _options = [self createOptions];
    }
    
    if (_walletEx == NULL) {
        DSLog(@"[OBJ-C] CoinJoin: register wallet ex");
        _walletEx = register_wallet_ex(AS_RUST(self), _options, getTransaction, signTransaction, destroyTransaction, isMineInput, commitTransaction, isBlockchainSynced, freshCoinJoinAddress, countInputsWithAmount, availableCoins, destroyGatheredOutputs, selectCoinsGroupedByAddresses, destroySelectedCoins, isMasternodeOrDisconnectRequested, disconnectMasternode, sendMessage, addPendingMasternode);
    }
    
    if (_clientManager == NULL) {
        DSLog(@"[OBJ-C] CoinJoin: register client manager");
        _clientManager = register_client_manager(AS_RUST(self), _walletEx, _options, getMNList, destroyMNList, getInputValueByPrevoutHash, hasChainLock, destroyInputValue);
    }
    
    if (_clientQueueManager == NULL) {
        DSLog(@"[OBJ-C] CoinJoin: register client queue manager");
        _clientQueueManager = register_client_queue_manager(_clientManager, _options, masternodeByHash, destroyMasternodeEntry, validMNCount, isBlockchainSynced, AS_RUST(self));
    }
}

- (BOOL)isWaitingForNewBlock {
    return is_waiting_for_new_block(_clientManager);
}

- (CoinJoinClientOptions *)createOptions {
    CoinJoinClientOptions *options = malloc(sizeof(CoinJoinClientOptions));
    options->enable_coinjoin = YES;
    options->coinjoin_rounds = 1;
    options->coinjoin_sessions = 1;
    options->coinjoin_amount = DUFFS / 4; // 0.25 DASH
    options->coinjoin_random_rounds = COINJOIN_RANDOM_ROUNDS;
    options->coinjoin_denoms_goal = DEFAULT_COINJOIN_DENOMS_GOAL;
    options->coinjoin_denoms_hardcap = DEFAULT_COINJOIN_DENOMS_HARDCAP;
    options->coinjoin_multi_session = NO;
    DSLog(@"[OBJ-C] CoinJoin: trusted balance: %llu", self.chainManager.chain.balance);
    
    return options;
}

- (void)processDSQueueFrom:(DSPeer *)peer message:(NSData *)message {
    ByteArray *array = malloc(sizeof(ByteArray));
    array->len = (uintptr_t)message.length;
    array->ptr = data_malloc(message);
    
    process_ds_queue(_clientQueueManager, peer.address.u8, peer.port, array);
    
    if (array) {
        if (array->ptr) {
            free((void *)array->ptr);
        }
        
        free(array);
    }
    
    DSLog(@"[OBJ-C] CoinJoin: call");
    Balance *balance = [self.manager getBalance];
    
    run_client_manager(_clientManager, _clientQueueManager, *balance);
    free(balance);
}

- (DSChain *)chain {
    return self.chainManager.chain;
}

- (void)dealloc {
    if (_options != NULL) {
        free(_options);
    }
    
    unregister_client_manager(_clientManager);
    unregister_wallet_ex(_walletEx); // Unregister last
}

///
/// MARK: Rust FFI callbacks
///

InputValue *getInputValueByPrevoutHash(uint8_t (*prevout_hash)[32], uint32_t index, const void *context) {
    UInt256 txHash = *((UInt256 *)prevout_hash);
    DSLog(@"[OBJ-C CALLBACK] CoinJoin: getInputValueByPrevoutHash");
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
    DSLog(@"[OBJ-C CALLBACK] CoinJoin: hasChainLock");
    BOOL hasChainLock = NO;
    
    @synchronized (context) {
        DSCoinJoinWrapper *wrapper = AS_OBJC(context);
        hasChainLock = [wrapper.chain blockHeightChainLocked:block->height];
    }
    
    processor_destroy_block(block);
    return hasChainLock;
}

Transaction *getTransaction(uint8_t (*tx_hash)[32], const void *context) {
    DSLog(@"[OBJ-C CALLBACK] CoinJoin: getTransaction");
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
    DSLog(@"[OBJ-C CALLBACK] CoinJoin: isMine");
    UInt256 txHash = *((UInt256 *)tx_hash);
    BOOL result = NO;
    
    @synchronized (context) {
        result = [AS_OBJC(context).manager isMineInput:txHash index:index];
    }
    
    processor_destroy_block_hash(tx_hash);
    return result;
}

GatheredOutputs* availableCoins(bool onlySafe, CoinControl coinControl, WalletEx *walletEx, const void *context) {
    DSLog(@"[OBJ-C CALLBACK] CoinJoin: hasCollateralInputs");
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
    DSLog(@"[OBJ-C CALLBACK] CoinJoin: selectCoinsGroupedByAddresses");
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
    DSLog(@"[OBJ-C] CoinJoin: 💀 InputValue");
    
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
    
    DSLog(@"[OBJ-C] CoinJoin: 💀 SelectedCoins");
    
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
    
    DSLog(@"[OBJ-C] CoinJoin: 💀 GatheredOutputs");
    
    if (gatheredOutputs->item_count > 0 && gatheredOutputs->items) {
        for (int i = 0; i < gatheredOutputs->item_count; i++) {
            [DSTransactionOutput ffi_free:gatheredOutputs->items[i]->output];
            free(gatheredOutputs->items[i]->outpoint_hash);
        }
        
        free(gatheredOutputs->items);
    }
    
    free(gatheredOutputs);
}

Transaction* signTransaction(Transaction *transaction, const void *context) {
    DSLog(@"[OBJ-C CALLBACK] CoinJoin: signTransaction");
    
    @synchronized (context) {
        DSCoinJoinWrapper *wrapper = AS_OBJC(context);
        DSTransaction *tx = [[DSTransaction alloc] initWithTransaction:transaction onChain:wrapper.chain];
        destroy_transaction(transaction);
        
        BOOL isSigned = [wrapper.chain.wallets.firstObject.accounts.firstObject signTransaction:tx];
        
        if (isSigned) {
            return [tx ffi_malloc:wrapper.chain.chainType];
        }
    }
    
    return nil;
}

unsigned int countInputsWithAmount(unsigned long long inputAmount, const void *context) {
    DSLog(@"[OBJ-C CALLBACK] CoinJoin: countInputsWithAmount");
    return [AS_OBJC(context).manager countInputsWithAmount:inputAmount];
}

ByteArray freshCoinJoinAddress(bool internal, const void *context) {
    DSLog(@"[OBJ-C CALLBACK] CoinJoin: freshCoinJoinAddress");
    DSCoinJoinWrapper *wrapper = AS_OBJC(context);
    NSString *address = [wrapper.manager freshAddress:internal];
    
    return script_pubkey_for_address([address UTF8String], wrapper.chain.chainType);
}

bool commitTransaction(struct Recipient **items, uintptr_t item_count, const void *context) {
    DSLog(@"[OBJ-C] CoinJoin: commitTransaction");
    
    NSMutableArray *amounts = [NSMutableArray array];
    NSMutableArray *scripts = [NSMutableArray array];
    
    for (uintptr_t i = 0; i < item_count; i++) {
        Recipient *recipient = items[i];
        [amounts addObject:@(recipient->amount)];
        NSData *script = [NSData dataWithBytes:recipient->script_pub_key.ptr length:recipient->script_pub_key.len];
        [scripts addObject:script];
    }
    
    // TODO: check subtract_fee_from_amount
    bool result = false;
    
    @synchronized (context) {
        DSCoinJoinWrapper *wrapper = AS_OBJC(context);
        result = [wrapper.manager commitTransactionForAmounts:amounts outputs:scripts onPublished:^(NSError * _Nullable error) {
            if (!error) {
                DSLog(@"[OBJ-C] CoinJoin: call finish_automatic_denominating");
                bool isFinished = finish_automatic_denominating(wrapper.clientManager);
                DSLog(@"[OBJ-C] CoinJoin: is automatic_denominating finished: %s", isFinished ? "YES" : "NO");
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
    
    DSLog(@"[OBJ-C] CoinJoin: 💀 MasternodeEntry");
    [DSSimplifiedMasternodeEntry ffi_free:masternodeEntry];
}

uint64_t validMNCount(const void *context) {
    uint64_t result = 0;
    
    @synchronized (context) {
        result = [AS_OBJC(context).manager validMNCount];
    }
    
    return result;
}

MasternodeList* getMNList(const void *context) {
    MasternodeList *masternodes;
    
    @synchronized (context) {
        DSCoinJoinWrapper *wrapper = AS_OBJC(context);
        DSMasternodeList *mnList = [wrapper.manager mnList];
        // TODO: might have 0 valid MNs, account for this
        DSLog(@"[OBJ-C] CoinJoin: getMNList, valid count: %llu", mnList.validMasternodeCount);
        masternodes = [mnList ffi_malloc];
    }
    
    return masternodes;
}

void destroyMNList(MasternodeList *masternodeList) { // TODO: check destroyMasternodeList
    if (!masternodeList) {
        return;
    }
    
    DSLog(@"[OBJ-C] CoinJoin: 💀 MasternodeList");
    [DSMasternodeList ffi_free:masternodeList];
}

bool isBlockchainSynced(const void *context) {
    BOOL result = NO;
    
    @synchronized (context) {
        result = AS_OBJC(context).chainManager.combinedSyncProgress == 1.0;
    }
    
    return result;
}

bool isMasternodeOrDisconnectRequested(uint8_t (*ip_address)[16], uint16_t port, const void *context) {
    UInt128 ipAddress = *((UInt128 *)ip_address);
    BOOL result = NO;
    
    @synchronized (context) {
        result = [AS_OBJC(context).manager isMasternodeOrDisconnectRequested:ipAddress port:port];
    }
    
    return result;
}

bool disconnectMasternode(uint8_t (*ip_address)[16], uint16_t port, const void *context) {
    UInt128 ipAddress = *((UInt128 *)ip_address);
    BOOL result = NO;
    
    @synchronized (context) {
        result = [AS_OBJC(context).manager disconnectMasternode:ipAddress port:port];
    }
    
    return result;
}

bool sendMessage(char *message_type, ByteArray *byteArray, uint8_t (*ip_address)[16], uint16_t port, const void *context) {
    NSString *messageType = [NSString stringWithUTF8String:message_type];
    UInt128 ipAddress = *((UInt128 *)ip_address);
    BOOL result = YES;
    
    @synchronized (context) {
        NSData *message = [NSData dataWithBytes:byteArray->ptr length:byteArray->len];
        result = [AS_OBJC(context).manager sendMessageOfType:messageType message:message withPeerIP:ipAddress port:port];
    }
    
    return result;
}

bool addPendingMasternode(uint8_t (*pro_tx_hash)[32], uint8_t (*session_id)[32], const void *context) {
    UInt256 sessionId = *((UInt256 *)session_id);
    UInt256 proTxHash = *((UInt256 *)pro_tx_hash);
    BOOL result = NO;
    
    @synchronized (context) {
        result = [AS_OBJC(context).manager addPendingMasternode:proTxHash clientSessionId:sessionId];
    }
    
    return result;
}

@end
