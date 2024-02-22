//  
//  Created by Andrei Ashikhmin
//  Copyright © 2023 Dash Core Group. All rights reserved.
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

#import "DSCoinJoinViewController.h"
#import "DSChainManager.h"
#import "NSString+Dash.h"
#import "DSTransaction+CoinJoin.h"
#import "DSCoinControl.h"
#import "DSCoinJoinWrapper.h"

#define AS_OBJC(context) ((__bridge DSCoinJoinWrapper *)(context))
#define AS_RUST(context) ((__bridge void *)(context))

@implementation DSCoinJoinViewController

- (IBAction)coinJoinSwitchDidChangeValue:(id)sender {
    if (_coinJoinSwitch.on) {
        [self startCoinJoin];
    } else {
        [self stopCoinJoin];
    }
}

- (void)stopCoinJoin {
    
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
//    unregister_coinjoin(_coinJoin);
//    _coinJoin = NULL;
}

- (void)startCoinJoin {
    // TODO: init parameters
    // TODO: subscribe
    // TODO: refreshUnusedKeys()
    
    if (_wrapper == NULL) {
        DSChain *chain = self.chainManager.chain;
        _wrapper = [[DSCoinJoinWrapper alloc] initWithChain:chain];
    }
    
//
//    UInt256 indexes[] = {uint256_from_long(FEATURE_PURPOSE), uint256_from_long(chain_coin_type(chain.chainType)), uint256_from_long(FEATURE_PURPOSE_COINJOIN), uint256_from_long(0)};
//    BOOL hardenedIndexes[] = {YES, YES, YES, YES};
//    DSDerivationPath *path = [DSCreditFundingDerivationPath derivationPathWithIndexes:indexes hardened:hardenedIndexes length:4 type:DSDerivationPathType_Unknown /* ??? DSDerivationPathType_AnonymousFunds ??? */ signingAlgorithm:KeyKind_ECDSA reference:DSDerivationPathReference_BlockchainIdentityCreditInvitationFunding onChain:chain];
//    
//    DSAccount *account = chain.wallets.firstObject.accounts.firstObject;
//    [account addDerivationPath:path];
//    
//    [path setAccount:account];
    
    
    [self runCoinJoin];
}

-(void)runCoinJoin {
    if (_options != NULL) {
        free(_options);
    }
    
    _options = malloc(sizeof(CoinJoinClientOptions));
    _options->enable_coinjoin = YES;
    _options->coinjoin_rounds = 1;
    _options->coinjoin_sessions = 1;
    _options->coinjoin_amount = 4 * DUFFS;
    _options->coinjoin_random_rounds = COINJOIN_RANDOM_ROUNDS;
    _options->coinjoin_denoms_goal = DEFAULT_COINJOIN_DENOMS_GOAL;
    _options->coinjoin_denoms_hardcap = DEFAULT_COINJOIN_DENOMS_HARDCAP;
    _options->coinjoin_multi_session = NO;
    
    if (_coinJoin == NULL) {
        DSLog(@"[OBJ-C] CoinJoin: register");
        _coinJoin = register_coinjoin(getInputValueByPrevoutHash, hasChainLock, destroyInputValue, AS_RUST(self.wrapper));
    }
    
    if (_clientSession == NULL) {
        _clientSession = register_client_session(_coinJoin, _options, getTransaction, destroyTransaction, isMineInput, hasCollateralInputs, selectCoinsGroupedByAddresses, destroySelectedCoins, signTransaction, countInputsWithAmount, AS_RUST(self.wrapper));
        self.wrapper.clientSession = _clientSession;
    }

    DSLog(@"[OBJ-C] CoinJoin: call");
    BOOL result = call_session(_clientSession, 300000000);
    DSLog(@"[OBJ-C] CoinJoin: call result: %s", result ? "TRUE" : "FALSE");
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
        result = [AS_OBJC(context) isMineInput:txHash index:index];
    }
    
    processor_destroy_block_hash(tx_hash);
    return result;
}

bool hasCollateralInputs(BOOL onlyConfirmed, WalletEx* walletEx, const void *context) {
    DSLog(@"[OBJ-C CALLBACK] CoinJoin: hasCollateralInputs");
    BOOL result = NO;
    
    @synchronized (context) {
        result = [AS_OBJC(context) hasCollateralInputs:walletEx onlyConfirmed:onlyConfirmed];
    }
    
    return result;
}

SelectedCoins* selectCoinsGroupedByAddresses(bool skipDenominated, bool anonymizable, bool skipUnconfirmed, int maxOupointsPerAddress, WalletEx* walletEx, const void *context) {
    DSLog(@"[OBJ-C CALLBACK] CoinJoin: selectCoinsGroupedByAddresses");
    SelectedCoins *vecTallyRet;
    
    @synchronized (context) {
        DSCoinJoinWrapper *wrapper = AS_OBJC(context);
        NSArray<DSCompactTallyItem *> *tempVecTallyRet = [wrapper selectCoinsGroupedByAddresses:walletEx skipDenominated:skipDenominated anonymizable:anonymizable skipUnconfirmed:skipUnconfirmed maxOupointsPerAddress:maxOupointsPerAddress];
        
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
    
    if (selectedCoins->item_count > 0 && selectedCoins->items) {
        for (int i = 0; i < selectedCoins->item_count; i++) {
            [DSCompactTallyItem ffi_free:selectedCoins->items[i]];
        }
        
        free(selectedCoins->items);
    }
    
    free(selectedCoins);
}

void signTransaction(Transaction *transaction, const void *context) {
    DSLog(@"[OBJ-C CALLBACK] CoinJoin: signTransaction");
    
    @synchronized (context) {
        DSCoinJoinWrapper *wrapper = AS_OBJC(context);
        DSTransaction *tx = [[DSTransaction alloc] initWithTransaction:transaction onChain:wrapper.chain];
        destroy_transaction(transaction);
        
        [wrapper.chain.wallets.firstObject.accounts.firstObject signTransaction:tx completion:^(BOOL signedTransaction, BOOL cancelled) {
            if (signedTransaction && !cancelled) {
                Transaction *returnTx = [tx ffi_malloc:wrapper.chain.chainType];
                on_transaction_signed_for_session(returnTx, wrapper.clientSession, destroyTransaction);
            } else {
                DSLog(@"[OBJ-C CALLBACK] CoinJoin: signTransaction error: not signed or canceled");
            }
        }];
    }
}

unsigned int countInputsWithAmount(unsigned long long inputAmount, const void *context) {
    DSLog(@"[OBJ-C CALLBACK] CoinJoin: countInputsWithAmount");
    return [AS_OBJC(context) countInputsWithAmount:inputAmount];
}

@end
