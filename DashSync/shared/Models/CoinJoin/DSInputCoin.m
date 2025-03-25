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

#import "DSInputCoin.h"

@implementation DSInputCoin

- (instancetype)initWithTx:(DSTransaction *)tx index:(int32_t)i {
    self = [super init];
    if (self) {
        _outpointHash = tx.txHash;
        _outpointIndex = i;
        _output = tx.outputs[i];
        _effectiveValue = tx.outputs[i].amount;
    }
    return self;
}

- (DInputCoin *)ffi_malloc:(DChainType *)type {
    // TODO: check outpoint hash reverse or not
    DOutPoint *outpoint = DOutPointCtorU(self.outpointHash, self.outpointIndex);
    DTxOut *tx_out = DTxOutCtor(self.output.amount, DScriptBufCtor(bytes_ctor(self.output.outScript)));
    return DInputCoinCtor(outpoint, tx_out, self.effectiveValue);
}

+ (void)ffi_free:(DInputCoin *)inputCoin {
    if (!inputCoin) return;
    DInputCoinDtor(inputCoin);
}

@end
