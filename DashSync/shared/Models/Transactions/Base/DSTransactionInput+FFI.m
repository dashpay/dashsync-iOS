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
#import "DSTransactionInput+FFI.h"
#import "NSData+Dash.h"

@implementation DSTransactionInput (FFI)

- (DTxIn *)ffi_malloc {
    DOutPoint *outpoint = DOutPointCtorU(self.inputHash, self.index);
    DScriptBuf *script;
    if (self.inScript)
        script = DScriptBufCtor(bytes_ctor(self.inScript));
    else
        script = DScriptBufCtor(bytes_ctor(self.signature));
    
    return DTxInCtor(outpoint, script, self.sequence);
}

+ (void)ffi_free:(DTxIn *)input {
    if (!input) return;
    DTxInDtor(input);
}

@end

@implementation NSArray (Vec_dashcore_blockdata_transaction_txin_TxIn)
+ (DTxInputs *)ffi_to_tx_inputs:(NSArray<DSTransactionInput *> *)obj {
    NSUInteger count = obj.count;
    DTxIn **values = malloc(count * sizeof(DTxIn *));
    for (NSUInteger i = 0; i < count; i++) {
        values[i] = [obj[i] ffi_malloc];
    }
    return DTxInputsCtor(count, values);

}
+ (void)ffi_destroy_tx_inputs:(DTxInputs *)ffi_ref {
    if (ffi_ref) DTxInputsDtor(ffi_ref);
}
@end

