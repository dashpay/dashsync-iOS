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

#import "DSPeer.h"
#import "DSTransactionInvRequest.h"
#import "NSMutableData+Dash.h"

@implementation DSTransactionInvRequest

+ (instancetype)requestWithTransactionHashes:(NSOrderedSet<NSValue *> *)txHashes txLockRequestHashes:(NSOrderedSet<NSValue *> *)txLockRequestHashes {
    return [[DSTransactionInvRequest alloc] initWithTransactionHashes:txHashes txLockRequestHashes:txLockRequestHashes];
}

- (instancetype)initWithTransactionHashes:(NSOrderedSet<NSValue *> *)txHashes txLockRequestHashes:(NSOrderedSet<NSValue *> *)txLockRequestHashes {
    self = [super init];
    if (self) {
        _txHashes = txHashes;
        _txLockRequestHashes = txLockRequestHashes;
    }
    return self;
}

- (NSString *)type {
    return MSG_INV;
}

- (NSData *)toData {
    NSMutableData *msg = [NSMutableData data];
    UInt256 h;
    [msg appendVarInt:self.txHashes.count + self.txLockRequestHashes.count];
    for (NSValue *hash in self.txHashes) {
        [msg appendUInt32:DSInvType_Tx];
        [hash getValue:&h];
        [msg appendBytes:&h length:sizeof(h)];
    }
    for (NSValue *hash in self.txLockRequestHashes) {
        [msg appendUInt32:DSInvType_TxLockRequest];
        [hash getValue:&h];
        [msg appendBytes:&h length:sizeof(h)];
    }
    return msg;
}

@end
