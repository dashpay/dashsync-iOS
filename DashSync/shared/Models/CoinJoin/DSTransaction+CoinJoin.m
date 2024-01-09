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

#import "BigIntTypes.h"
#import "DSTransaction.h"
#import "DSTransaction+CoinJoin.h"
#import "DSTransactionInput+CoinJoin.h"
#import "DSTransactionOutput+CoinJoin.h"
#import "NSData+Dash.h"

@implementation DSTransaction (CoinJoin)

- (Transaction *)ffi_malloc:(ChainType)chainType {
    Transaction *transaction = malloc(sizeof(Transaction));
    
    transaction->tx_hash = uint256_malloc(self.txHash);
    uintptr_t inputsCount = self.inputs.count;
    uintptr_t outputsCount = self.outputs.count;
    transaction->inputs_count = inputsCount;
    transaction->outputs_count = outputsCount;
    
    TransactionInput **inputsArray = malloc(inputsCount * sizeof(TransactionInput *));
    TransactionOutput **outputsArray = malloc(outputsCount * sizeof(TransactionOutput *));
    
    for (uintptr_t i = 0; i < inputsCount; ++i) {
        inputsArray[i] = [self.inputs[i] ffi_malloc];
    }
    
    for (uintptr_t i = 0; i < outputsCount; ++i) {
        outputsArray[i] = [self.outputs[i] ffi_malloc:chainType];
    }
    
    transaction->inputs = inputsArray;
    transaction->outputs = outputsArray;
    transaction->lock_time = self.lockTime;
    transaction->version = self.version;
    transaction->tx_type = (TransactionType)self.type;
    transaction->payload_offset = self.payloadOffset;
    transaction->block_height = self.blockHeight;
    
    return transaction;
}

+ (void)ffi_free:(Transaction *)tx {
    if (!tx) return;
    
    free(tx->tx_hash);
    
    if (tx->inputs_count > 0 && tx->inputs) {
        for (int i = 0; i < tx->inputs_count; i++) {
            [DSTransactionInput ffi_free:tx->inputs[i]];
        }
        
        free(tx->inputs);
    }
    
    if (tx->outputs_count > 0 && tx->outputs) {
        for (int i = 0; i < tx->outputs_count; i++) {
            [DSTransactionOutput ffi_free:tx->outputs[i]];
        }
        
        free(tx->outputs);
    }
    
    free(tx);
    DSLog(@"[OBJ-C] CoinJoin: 💀 transaction");
}

@end

