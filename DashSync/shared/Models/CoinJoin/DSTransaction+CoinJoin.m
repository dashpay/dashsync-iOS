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
#import "DSChain+Transaction.h"
#import "DSTransaction.h"
#import "DSTransaction+CoinJoin.h"
#import "DSTransactionInput+CoinJoin.h"
#import "DSTransactionOutput+CoinJoin.h"
#import "NSData+Dash.h"
#import "DSKeyManager.h"

@implementation DSTransaction (CoinJoin)

- (DSTransaction *)initWithTransaction:(DTransaction *)transaction onChain:(DSChain *)chain {
    NSMutableArray *hashes = [NSMutableArray array];
    NSMutableArray *indexes = [NSMutableArray array];
    NSMutableArray *scripts = [NSMutableArray array];
    NSMutableArray *inputSequences = [NSMutableArray array];
    NSMutableArray *addresses = [NSMutableArray array];
    NSMutableArray *amounts = [NSMutableArray array];

    for (uintptr_t i = 0; i < transaction->input->count; i++) {
        DTxIn *txin = transaction->input->values[i];
        uint32_t index = txin->previous_output->vout;
        u256 *hash = dashcore_hash_types_Txid_inner(txin->previous_output->txid);
        // TODO: check if it's reversed
        UInt256 hashValue = u256_cast(hash);
        Vec_u8 *script_sig = txin->script_sig->_0;
        NSData *script = NSDataFromPtr(script_sig);
        if (!script.length) {
            DSTransaction *inputTx = [chain transactionForHash:hashValue];
            if (inputTx)
                script = inputTx.outputs[index].outScript;
        }
        [hashes addObject:uint256_obj(hashValue)];
        [indexes addObject:@(index)];
        [scripts addObject:script];
        [inputSequences addObject:@(txin->sequence)];
    }
    for (uintptr_t i = 0; i < transaction->output->count; i++) {
        DTxOut *output = transaction->output->values[i];
        NSData *scriptPubKey = NSDataFromPtr(output->script_pubkey->_0);
//        NSData *scriptPubKey = [NSData dataWithBytes:output->script length:output->script_length];
        NSString *address = [DSKeyManager addressWithScriptPubKey:scriptPubKey forChain:chain];
        NSNumber *amount = @(output->value);
        
        [addresses addObject:address ?: [NSNull null]]; // Use NSNull turned into OP_RETURN script later
        [amounts addObject:amount];
    }


//    for (uintptr_t i = 0; i < transaction->inputs_count; i++) {
//        TransactionInput *input = transaction->inputs[i];
//        UInt256 hashValue;
//        memcpy(hashValue.u8, *input->input_hash, 32);
//        NSNumber *index = @(input->index);
//        NSData *script = [NSData data];
//        
//        if (input->script && input->script_length != 0) {
//            script = [NSData dataWithBytes:input->script length:input->script_length];
//        } else {
//            DSTransaction *inputTx = [chain transactionForHash:hashValue];
//            
//            if (inputTx) {
//                script = inputTx.outputs[index.integerValue].outScript;
//            }
//        }
//        
//        NSNumber *sequence = @(input->sequence);
//        
//        [hashes addObject:uint256_obj(hashValue)];
//        [indexes addObject:index];
//        [scripts addObject:script];
//        [inputSequences addObject:sequence];
//    }
//    
//    NSMutableArray *addresses = [NSMutableArray array];
//    NSMutableArray *amounts = [NSMutableArray array];
//
//    for (uintptr_t i = 0; i < transaction->outputs_count; i++) {
//        TransactionOutput *output = transaction->outputs[i];
//        NSData *scriptPubKey = [NSData dataWithBytes:output->script length:output->script_length];
//        NSString *address = [DSKeyManager addressWithScriptPubKey:scriptPubKey forChain:chain];
//        NSNumber *amount = @(output->amount);
//        
//        [addresses addObject:address ?: [NSNull null]]; // Use NSNull turned into OP_RETURN script later
//        [amounts addObject:amount];
//    }

    DSTransaction *tx = [[DSTransaction alloc] initWithInputHashes:hashes
                                                      inputIndexes:indexes
                                                      inputScripts:scripts
                                                    inputSequences:inputSequences
                                                   outputAddresses:addresses
                                                     outputAmounts:amounts
                                                           onChain:chain];
    tx.version = transaction->version;
    
    return tx;
}

- (DTransaction *)ffi_malloc:(DChainType *)chainType {
    uintptr_t inputsCount = self.inputs.count;
    uintptr_t outputsCount = self.outputs.count;
    DTxIn **input_values = malloc(inputsCount * sizeof(DTxIn *));
    DTxOut **output_values = malloc(outputsCount * sizeof(DTxOut *));
    for (uintptr_t i = 0; i < inputsCount; ++i) {
        input_values[i] = [self.inputs[i] ffi_malloc];
    }
    
    for (uintptr_t i = 0; i < outputsCount; ++i) {
        output_values[i] = [self.outputs[i] ffi_malloc:chainType];
    }
    DTransaction *transaction = DTransactionCtor(self.version, self.lockTime, Vec_dashcore_blockdata_transaction_txin_TxIn_ctor(inputsCount, input_values), Vec_dashcore_blockdata_transaction_txout_TxOut_ctor(outputsCount, output_values), NULL);

    
//    Transaction *transaction = malloc(sizeof(Transaction));
//    
//    transaction->tx_hash = uint256_malloc(self.txHash);
//    uintptr_t inputsCount = self.inputs.count;
//    uintptr_t outputsCount = self.outputs.count;
//    transaction->inputs_count = inputsCount;
//    transaction->outputs_count = outputsCount;
//    
//    TransactionInput **inputsArray = malloc(inputsCount * sizeof(TransactionInput *));
//    TransactionOutput **outputsArray = malloc(outputsCount * sizeof(TransactionOutput *));
//    
//    for (uintptr_t i = 0; i < inputsCount; ++i) {
//        inputsArray[i] = [self.inputs[i] ffi_malloc];
//    }
//    
//    for (uintptr_t i = 0; i < outputsCount; ++i) {
//        outputsArray[i] = [self.outputs[i] ffi_malloc:chainType];
//    }
//    
//    transaction->inputs = inputsArray;
//    transaction->outputs = outputsArray;
//    transaction->lock_time = self.lockTime;
//    transaction->version = self.version;
//    transaction->tx_type = (TransactionType)self.type;
//    transaction->payload_offset = self.payloadOffset;
//    transaction->block_height = self.blockHeight;
    
    return transaction;
}

+ (void)ffi_free:(DTransaction *)tx {
    if (!tx) return;
    DTransactionDtor(tx);
//    free(tx->tx_hash);
//    
//    if (tx->inputs) {
//        for (int i = 0; i < tx->inputs_count; i++) {
//            [DSTransactionInput ffi_free:tx->inputs[i]];
//        }
//        
//        free(tx->inputs);
//    }
//    
//    if (tx->outputs) {
//        for (int i = 0; i < tx->outputs_count; i++) {
//            [DSTransactionOutput ffi_free:tx->outputs[i]];
//        }
//        
//        free(tx->outputs);
//    }
//    
//    free(tx);
}

@end

