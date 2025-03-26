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

- (TransactionInput *)ffi_malloc {
    TransactionInput *transactionInput = malloc(sizeof(TransactionInput));
    transactionInput->input_hash = uint256_malloc(self.inputHash);
    transactionInput->index = self.index;
    transactionInput->sequence = self.sequence;
    
    NSData *scriptData = self.inScript;
    transactionInput->script_length = scriptData.length;
    transactionInput->script = data_malloc(scriptData);
    
    NSData *signatureData = self.signature;
    transactionInput->signature_length = signatureData.length;
    transactionInput->signature = data_malloc(signatureData);
    
    return transactionInput;
}

+ (void)ffi_free:(TransactionInput *)input {
    if (!input) return;
    
    free(input->input_hash);
    
    if (input->script) {
        free(input->script);
    }
    
    if (input->signature) {
        free(input->signature);
    }
    
    free(input);
}

@end

