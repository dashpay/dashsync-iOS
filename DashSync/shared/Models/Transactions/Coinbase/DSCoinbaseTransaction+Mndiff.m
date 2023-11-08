//
//  Created by Vladimir Pirogov
//  Copyright © 2022 Dash Core Group. All rights reserved.
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

#import "DSCoinbaseTransaction+Mndiff.h"
#import "NSData+Dash.h"

@implementation DSCoinbaseTransaction (Mndiff)

/*+ (instancetype)coinbaseTransactionWith:(CoinbaseTransaction *)coinbaseTransaction onChain:(DSChain *)chain {
    DSCoinbaseTransaction *ctx = [[DSCoinbaseTransaction alloc] init];
    Transaction *tx = coinbaseTransaction->base;
    uintptr_t inputs_count = tx->inputs_count;
    TransactionInput **tx_inputs = tx->inputs;
    for (NSUInteger i = 0; i < inputs_count; i++) {
        TransactionInput *input = tx_inputs[i];
        UInt256 hash = *(UInt256 *)input->input_hash;
        uint32_t index = input->index;
        uintptr_t script_length = input->script_length;
        uintptr_t signature_length = input->signature_length;
        NSData *script = script_length > 0 ? [NSData dataWithBytes:input->script length:script_length] : nil;
        NSData *signature = signature_length > 0 ? [NSData dataWithBytes:input->signature length:signature_length] : nil;
        uint32_t sequence = input->sequence;
        [ctx addInputHash:hash
                    index:index
                   script:script
                signature:signature
                 sequence:sequence];
    }
    uintptr_t outputs_count = tx->outputs_count;
    TransactionOutput **tx_outputs = tx->outputs;
    for (NSUInteger i = 0; i < outputs_count; i++) {
        TransactionOutput *output = tx_outputs[i];
        uint64_t amount = output->amount;
        uintptr_t address_length = output->address_length;
        uintptr_t script_length = output->script_length;
        NSString *address = address_length > 0 ? [NSData dataWithBytes:output->address length:address_length].hexString : nil;
        NSData *script = script_length > 0 ? [NSData dataWithBytes:output->script length:script_length] : nil;
        [ctx addOutputScript:script
                 withAddress:address
                      amount:amount];
    }
    ctx.height = coinbaseTransaction->height;
    ctx.coinbaseTransactionVersion = coinbaseTransaction->coinbase_transaction_version;
    ctx.merkleRootMNList = *(UInt256 *)coinbaseTransaction->merkle_root_mn_list;
    ctx.merkleRootLLMQList = *(UInt256 *)coinbaseTransaction->merkle_root_llmq_list;
    ctx.lockTime = tx->lock_time;
    ctx.version = tx->version;
    ctx.txHash = *(UInt256 *)tx->tx_hash;
    ctx.type = tx->tx_type;
    ctx.blockHeight = tx->block_height;
    return ctx;
}*/

@end
