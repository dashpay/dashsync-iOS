//  
//  Created by Vladimir Pirogov
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

#import "DSAssetLockTransaction.h"
#import "DSChain.h"
#import "DSTransactionFactory.h"
#import "NSData+Dash.h"
#import "NSMutableData+Dash.h"

@implementation DSAssetLockTransaction

- (instancetype)initWithMessage:(NSData *)message onChain:(DSChain *)chain {
    if (!(self = [super initWithMessage:message onChain:chain]))
        return nil;
    self.type = DSTransactionType_AssetLock;
    NSUInteger length = message.length;
    uint32_t off = self.payloadOffset;
    
    if (length - off < 1) return nil;
    NSNumber *payloadLengthSize = nil;
    __unused uint64_t payloadLength = [message varIntAtOffset:off length:&payloadLengthSize];
    off += payloadLengthSize.unsignedLongValue;

    if (length - off < 1) return nil;
    self.specialTransactionVersion = [message UInt8AtOffset:off];
    off += 1;

    NSNumber *l = 0;
    if (length - off < 1) return nil;
    uint64_t count = (NSUInteger)[message varIntAtOffset:off length:&l]; // output count
    off += l.unsignedIntegerValue;
 
    NSMutableArray *creditOutputs = [NSMutableArray arrayWithCapacity:count];
    for (NSUInteger i = 0; i < count; i++) {            // outputs
        uint64_t amount = [message UInt64AtOffset:off]; // output amount
        off += sizeof(uint64_t);
        NSData *outScript = [message dataAtOffset:off length:&l]; // output script
        off += l.unsignedIntegerValue;
        DSTransactionOutput *transactionOutput = [DSTransactionOutput transactionOutputWithAmount:amount outScript:outScript onChain:self.chain];
        [creditOutputs addObject:transactionOutput];
    }
    self.creditOutputs = creditOutputs;
    self.payloadOffset = off;
    self.txHash = self.data.SHA256_2;
    
    return self;
}

- (NSData *)payloadData {
    return [self basePayloadData];
}

- (NSData *)basePayloadData {
    NSMutableData *data = [NSMutableData data];
    [data appendUInt8:self.specialTransactionVersion];
    NSUInteger creditOutputsCount = self.creditOutputs.count;
    [data appendVarInt:creditOutputsCount];
    for (NSUInteger i = 0; i < creditOutputsCount; i++) {
        DSTransactionOutput *output = self.creditOutputs[i];
        [data appendUInt64:output.amount];
        [data appendCountedData:output.outScript];
    }
    return data;
}

- (NSData *)toDataWithSubscriptIndex:(NSUInteger)subscriptIndex anyoneCanPay:(BOOL)anyoneCanPay {
    @synchronized(self) {
        NSMutableData *data = [[super toDataWithSubscriptIndex:subscriptIndex anyoneCanPay:anyoneCanPay] mutableCopy];
        [data appendCountedData:[self payloadData]];
        if (subscriptIndex != NSNotFound) [data appendUInt32:SIGHASH_ALL];
        return data;
    }
}

- (size_t)size {
    return [super size] + [self payloadData].length;
}

@end
