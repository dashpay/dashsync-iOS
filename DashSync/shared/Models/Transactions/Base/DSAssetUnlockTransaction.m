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
#import "DSChain.h"
#import "DSTransactionFactory.h"
#import "NSData+Dash.h"

@implementation DSAssetUnlockTransaction

- (instancetype)initWithMessage:(NSData *)message onChain:(DSChain *)chain {
    if (!(self = [super initWithMessage:message onChain:chain]))
        return nil;
    self.type = DSTransactionType_AssetUnlock;
    NSUInteger length = message.length;
    uint32_t off = self.payloadOffset;
    
    if (length - off < 1) return nil;
    NSNumber *payloadLengthSize = nil;
    __unused uint64_t payloadLength = [message varIntAtOffset:off length:&payloadLengthSize];
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
    self.txHash = self.data.SHA256_2;

    return self;

}

@end
