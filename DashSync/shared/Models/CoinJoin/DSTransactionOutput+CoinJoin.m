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
#import "DSTransactionOutput.h"
#import "DSTransactionOutput+CoinJoin.h"
#import "NSData+Dash.h"

@implementation DSTransactionOutput (CoinJoin)

- (TransactionOutput *)ffi_malloc:(ChainType)type {
    TransactionOutput *transactionOutput = malloc(sizeof(TransactionOutput));
    transactionOutput->amount = self.amount;
    
    NSUInteger length = self.outScript.length;
    transactionOutput->script_length = (uintptr_t)length;
    NSData *scriptData = self.outScript;
    transactionOutput->script = data_malloc(scriptData);
    
    char *c_string = address_with_script_pubkey(self.outScript.bytes, self.outScript.length, type);
    size_t addressLength = strlen(c_string);
    transactionOutput->address_length = (uintptr_t)addressLength;
    transactionOutput->address = (uint8_t *)c_string;
    
    return transactionOutput;
}

+ (void)ffi_free:(TransactionOutput *)output {
    if (!output) return;
    
    if (output->script) {
        free(output->script);
    }
    
    if (output->address) {
        // TODO: should we use processor_destroy_string(c_string) here?
        free(output->address);
    }

    free(output);
}

@end

