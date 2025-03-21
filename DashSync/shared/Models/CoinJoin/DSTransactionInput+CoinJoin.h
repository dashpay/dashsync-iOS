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

#import "DSTransactionInput.h"
#import "DSKeyManager.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DSTransactionInput (CoinJoin)

- (DTxIn *)ffi_malloc;
+ (void)ffi_free:(DTxIn *)input;

@end

@interface NSArray (Vec_dashcore_blockdata_transaction_txin_TxIn)
+ (DTxInputs *)ffi_to_tx_inputs:(NSArray<DSTransactionInput *> *)obj;
+ (void)ffi_destroy_tx_inputs:(DTxInputs *)ffi_ref;
@end


NS_ASSUME_NONNULL_END
