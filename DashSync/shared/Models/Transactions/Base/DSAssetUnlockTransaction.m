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

#import "DSAssetUnlockTransaction.h"
#import "DSAssetUnlockTransactionEntity+CoreDataClass.h"
#import "DSChain.h"
#import "DSTransactionFactory.h"
#import "NSData+Dash.h"
#import "NSMutableData+Dash.h"

@implementation DSAssetUnlockTransaction

- (instancetype)initOnChain:(DSChain *)chain {
    self = [super initOnChain:chain];
    if (self) {
        self.type = DSTransactionType_AssetUnlock;
        self.version = SPECIAL_TX_VERSION;
    }
    return self;
}

- (instancetype)initWithMessage:(NSData *)message onChain:(DSChain *)chain {
    if (!(self = [super initWithMessage:message onChain:chain]))
        return nil;
    self.type = DSTransactionType_AssetUnlock;
    NSUInteger length = message.length;
    uint32_t off = self.payloadOffset;
    
    if (length - off < 1) return nil;
    NSNumber *payloadLengthSize = nil;
    uint64_t payloadLength = [message varIntAtOffset:off length:&payloadLengthSize];
    off += payloadLengthSize.unsignedLongValue;
    
    if (length - off < 1) return nil;
    self.specialTransactionVersion = [message UInt8AtOffset:off];
    off += 1;
    if (length - off < 8) return nil;
    self.index = [message UInt64AtOffset:off];
    off += 8;
    if (length - off < 4) return nil;
    self.fee = [message UInt32AtOffset:off];
    off += 4;
    if (length - off < 4) return nil;
    self.requestedHeight = [message UInt32AtOffset:off];
    off += 4;
    
    if (length - off < 32) return nil;
    self.quorumHash = [message UInt256AtOffset:off];
    off += 32;
    if (length - off < 96) return nil;
    self.quorumSignature = [message UInt768AtOffset:off];
    off += 96;

    self.payloadOffset = off;
    if ([self payloadData].length != payloadLength) return nil;
    self.txHash = self.data.SHA256_2;

    return self;

}
- (BOOL)transactionTypeRequiresInputs {
    return NO;
}
- (NSData *)payloadData {
    return [self basePayloadData];
}

- (NSData *)basePayloadData {
    NSMutableData *data = [NSMutableData data];
    [data appendUInt8:self.specialTransactionVersion];
    [data appendUInt64:self.index];
    [data appendUInt32:self.fee];
    [data appendUInt32:self.requestedHeight];
    [data appendUInt256:self.quorumHash];
    [data appendUInt768:self.quorumSignature];
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
    @synchronized(self) {
        if (uint256_is_not_zero(self.txHash)) return self.data.length;
        return [super size] + [NSMutableData sizeOfVarInt:self.payloadData.length] + ([self basePayloadData].length);
    }
}
- (Class)entityClass {
    return [DSAssetUnlockTransactionEntity class];
}

@end
