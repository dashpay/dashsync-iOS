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

@interface DSCoinJoinViewController ()
@property (strong, nonatomic) IBOutlet UISwitch *coinJoinSwitch;
@property (strong, nonatomic) IBOutlet UILabel *infoLabel;
@property (nonatomic, assign, nullable) CoinJoin *coinJoin;
@property (nonatomic, assign, nullable) WalletEx *walletEx;
@property (nonatomic, assign, nullable) CoinJoinClientOptions *options;
@property (nonatomic, strong) DSCoinJoinWrapper *wrapper;

@end

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
    
    
//    [self runCoinJoin];
    [self runWalletEx];
}

-(void)runCoinJoin {
    if (_coinJoin == NULL) {
        DSLog(@"[OBJ-C] CoinJoin: register");
        _coinJoin = register_coinjoin(getInputValueByPrevoutHash, hasChainLock, destroyInputValue, AS_RUST(self.wrapper));
    }

    DSTransaction *tx = self.chainManager.chain.allTransactions.firstObject;
    Transaction *transaction = [tx ffi_malloc:self.wrapper.chain.chainType];

    DSLog(@"[OBJ-C] CoinJoin: call");
    BOOL result = call_coinjoin(_coinJoin, transaction, AS_RUST(self.wrapper));
    DSLog(@"[OBJ-C] CoinJoin: call result: %s", result ? "TRUE" : "FALSE");
    [DSTransaction ffi_free:transaction];
}

-(void)runWalletEx {
    if (_walletEx == NULL) {
        DSLog(@"[OBJ-C] WalletEx: register");
        
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
        
        _walletEx = register_wallet_ex(_options, getTransaction, destroyTransaction, isMineInput, AS_RUST(self.wrapper));
    }
    
    DSUTXO o;
    for (NSValue *utxo in self.wrapper.chain.wallets.firstObject.unspentOutputs) {
        [utxo getValue:&o];
        DSTransaction *tx = [self.wrapper.chain transactionForHash:o.hash];
        int32_t result = call_wallet_ex(_walletEx, (uint8_t (*)[32])&(o.hash.u8), (uint32_t)o.n);
        DSLog(@"[OBJ-C] CoinJoin: get_real_outpoint_coinjoin_rounds for %llu: %d", tx.outputs[o.n].amount, result);
    }
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

bool hasCollateralInputs(BOOL onlyConfirmed, const void *context) {
    DSLog(@"[OBJ-C CALLBACK] CoinJoin: hasCollateralInputs");
    BOOL result = NO;
    
    @synchronized (context) {
        result = [AS_OBJC(context) hasCollateralInputs:onlyConfirmed];
    }
    
    return result;
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

@end
