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
#import "DSAssetLockTransaction.h"
#import "DSTransaction+FFI.h"
#import "DSTransactionInput+FFI.h"
#import "DSTransactionOutput+FFI.h"
#import "NSData+Dash.h"
#import "DSKeyManager.h"

@implementation DSTransaction (FFI)

+ (nonnull instancetype)ffi_from:(nonnull DTransaction *)transaction onChain:(nonnull DSChain *)chain {
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
            DSLog(@"[DSTransaction] ffi_from: %@ == %@ (%@)", uint256_hex(hashValue), inputTx, [chain transactionForHash:uint256_reverse(hashValue)]);
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
        NSString *address = [DSKeyManager addressWithScriptPubKey:scriptPubKey forChain:chain];
        NSNumber *amount = @(output->value);
        
        [addresses addObject:address ?: [NSNull null]]; // Use NSNull turned into OP_RETURN script later
        [amounts addObject:amount];
    }

    DSTransaction *tx;
    switch (transaction->special_transaction_payload->tag) {
        case dashcore_blockdata_transaction_special_transaction_TransactionPayload_AssetLockPayloadType: {
            dashcore_blockdata_transaction_special_transaction_asset_lock_AssetLockPayload *payload = transaction->special_transaction_payload->asset_lock_payload_type;
            NSMutableArray<DSTransactionOutput *> *creditOutputs = [NSMutableArray arrayWithCapacity:payload->credit_outputs->count];
            for (int i = 0; i < payload->credit_outputs->count; i++) {
                DTxOut *output = payload->credit_outputs->values[i];
                NSData *script = NSDataFromPtr(output->script_pubkey->_0);
                [creditOutputs addObject:[DSTransactionOutput transactionOutputWithAmount:output->value outScript:script onChain:chain]];
            }
            
            tx = [[DSAssetLockTransaction alloc] initWithInputHashes:hashes
                                                        inputIndexes:indexes
                                                        inputScripts:scripts
                                                      inputSequences:inputSequences
                                                     outputAddresses:addresses
                                                       outputAmounts:amounts
                                                       creditOutputs:creditOutputs
                                                      payloadVersion:payload->version
                                                             onChain:chain];
        }
        default: {
            // TODO: implement other transactions types
            tx = [[DSTransaction alloc] initWithInputHashes:hashes
                                               inputIndexes:indexes
                                               inputScripts:scripts
                                             inputSequences:inputSequences
                                            outputAddresses:addresses
                                              outputAmounts:amounts
                                                    onChain:chain];

        };
    }

    
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
        DSTransactionOutput *output = self.outputs[i];
        output_values[i] = [output ffi_malloc];
    }
    DTransaction *transaction = DTransactionCtor(self.version, self.lockTime, DTxInputsCtor(inputsCount, input_values), DTxOutputsCtor(outputsCount, output_values), NULL);
    return transaction;
}

+ (void)ffi_free:(DTransaction *)tx {
    if (!tx) return;
    DTransactionDtor(tx);
}



@end

