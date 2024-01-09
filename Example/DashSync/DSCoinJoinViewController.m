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
#import "BigIntTypes.h"
#import "DSChain+Protected.h"
#import "DSChainManager.h"
#import "DSFullBlock.h"
#import "NSData+DSHash.h"
#import "NSData+Dash.h"
#import "NSString+Dash.h"
#import "DSTransaction+CoinJoin.h"
#import "DSTransactionInput+CoinJoin.h"
#import "DSTransactionOutput+CoinJoin.h"

#define AS_OBJC(context) ((__bridge DSChain *)(context))
#define AS_RUST(context) ((__bridge void *)(context))

@interface DSCoinJoinViewController ()
@property (strong, nonatomic) IBOutlet UISwitch *coinJoinSwitch;
@property (strong, nonatomic) IBOutlet UILabel *infoLabel;
@property (nonatomic, assign, nullable) CoinJoin *coinJoin;

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
    
    unregister_coinjoin(_coinJoin);
    _coinJoin = NULL;
}

- (void)startCoinJoin {
    DSChain *context = self.chainManager.chain;
    
    if (_coinJoin == NULL) {
        DSLog(@"[OBJ-C] CoinJoin: register");
        _coinJoin = register_coinjoin(getInputValueByPrevoutHash, hasChainLock, destroyInputValue, AS_RUST(context));
    }
    
    DSTransaction *tx = self.chainManager.chain.allTransactions.firstObject;
    Transaction *transaction = [tx ffi_malloc:context.chainType];
    
    DSLog(@"[OBJ-C] CoinJoin: call");
    BOOL result = call_coinjoin(_coinJoin, transaction, AS_RUST(context));
    DSLog(@"[OBJ-C] CoinJoin: call result: %s", result ? "TRUE" : "FALSE");
    [DSTransaction ffi_free:transaction];
}


///
/// MARK: Rust FFI callbacks
///

InputValue *getInputValueByPrevoutHash(uint8_t (*prevout_hash)[32], uint32_t index, const void *context) {
    UInt256 txHash = *((UInt256 *)prevout_hash);
    DSLog(@"[OBJ-C CALLBACK] CoinJoin: getInputValueByPrevoutHash");
    InputValue *inputValue = NULL;
    @synchronized (context) {
        DSChain *chain = AS_OBJC(context);
        
        if (chain) {
            inputValue = malloc(sizeof(InputValue));
            DSWallet *wallet = chain.wallets.firstObject;
            int64_t value = [wallet inputValue:txHash inputIndex:index];
            
            if (value != -1) {
                inputValue->is_valid = TRUE;
                inputValue->value = value;
            } else {
                inputValue->is_valid = FALSE;
            }
        }
    }
    
    processor_destroy_block_hash(prevout_hash);
    return inputValue;
}


bool hasChainLock(Block *block, const void *context) {
    DSLog(@"[OBJ-C] CoinJoin: hasChainLock");
    BOOL hasChainLock = NO;
    @synchronized (context) {
        DSChain *chain = AS_OBJC(context);
        
        if (chain) {
            hasChainLock = [chain blockHeightChainLocked:block->height];
        }
    }
    processor_destroy_block(block);
    return hasChainLock;
}

void destroyInputValue(InputValue *value) {
    DSLog(@"[OBJ-C] CoinJoin: 💀 InputValue");
    
    if (value) {
        free(value);
    }
}

@end
