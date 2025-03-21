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
#import "DSTransactionInput.h"
#import "DSTransactionInput+CoinJoin.h"
#import "NSData+Dash.h"

@implementation DSTransactionInput (CoinJoin)

- (DTxIn *)ffi_malloc {
    DTxid *txid = DTxidCtor(u256_ctor_u(self.inputHash));
    DOutPoint *outpoint = DOutPointCtor(txid, self.index);
    DScriptBuf *script;
    if (self.inScript)
        script = DScriptBufCtor(bytes_ctor(self.inScript));
    else
        script = DScriptBufCtor(bytes_ctor(self.signature));
    
    return DTxInCtor(outpoint, script, self.sequence);
//    TransactionInput *transactionInput = malloc(sizeof(TransactionInput));
//    transactionInput->input_hash = uint256_malloc(self.inputHash);
//    transactionInput->index = self.index;
//    transactionInput->sequence = self.sequence;
//    
//    NSData *scriptData = self.inScript;
//    transactionInput->script_length = scriptData.length;
//    transactionInput->script = data_malloc(scriptData);
//    
//    NSData *signatureData = self.signature;
//    transactionInput->signature_length = signatureData.length;
//    transactionInput->signature = data_malloc(signatureData);
//    
//    return transactionInput;
}

+ (void)ffi_free:(DTxIn *)input {
    if (!input) return;
    DTxInDtor(input);
    
//    free(input->input_hash);
//    
//    if (input->script) {
//        free(input->script);
//    }
//    
//    if (input->signature) {
//        free(input->signature);
//    }
//    
//    free(input);
}

@end

@implementation NSArray (Vec_dashcore_blockdata_transaction_txin_TxIn)
//+ (NSArray<DSTransactionInput *> *)ffi_from_tx_inputs:(Vec_dashcore_blockdata_transaction_txin_TxIn *)ffi_ref {
//    
//}
+ (Vec_dashcore_blockdata_transaction_txin_TxIn *)ffi_to_tx_inputs:(NSArray<DSTransactionInput *> *)obj {
    NSUInteger count = obj.count;
    DTxIn **values = malloc(count * sizeof(DTxIn *));
    for (NSUInteger i = 0; i < count; i++) {
        values[i] = [obj[i] ffi_malloc];
    }
    return Vec_dashcore_blockdata_transaction_txin_TxIn_ctor(count, values);

}
+ (void)ffi_destroy_tx_inputs:(Vec_dashcore_blockdata_transaction_txin_TxIn *)ffi_ref {
    if (ffi_ref) Vec_dashcore_blockdata_transaction_txin_TxIn_destroy(ffi_ref);
}
@end

