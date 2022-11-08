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

#import "DSGetDataForTransactionHashesRequest.h"
#import "DSPeer.h"
#import "NSMutableData+Dash.h"

@implementation DSGetDataForTransactionHashesRequest

+ (instancetype)requestForTransactionHashes:(NSArray<NSValue *> *)txHashes
                      instantSendLockHashes:(NSArray<NSValue *> *)instantSendLockHashes
                     instantSendLockDHashes:(NSArray<NSValue *> *)instantSendLockDHashes
                                blockHashes:(NSArray<NSValue *> *)blockHashes
                            chainLockHashes:(NSArray<NSValue *> *)chainLockHashes {
    return [[DSGetDataForTransactionHashesRequest alloc] initForTransactionHashes:txHashes
                                                            instantSendLockHashes:instantSendLockHashes
                                                           instantSendLockDHashes:instantSendLockDHashes
                                                                      blockHashes:blockHashes
                                                                  chainLockHashes:chainLockHashes];
}

- (instancetype)initForTransactionHashes:(NSArray<NSValue *> *)txHashes
                   instantSendLockHashes:(NSArray<NSValue *> *)instantSendLockHashes
                  instantSendLockDHashes:(NSArray<NSValue *> *)instantSendLockDHashes
                             blockHashes:(NSArray<NSValue *> *)blockHashes
                         chainLockHashes:(NSArray<NSValue *> *)chainLockHashes {
    self = [super init];
    if (self) {
        _txHashes = txHashes;
        _instantSendLockHashes = instantSendLockHashes;
        _instantSendLockDHashes = instantSendLockDHashes;
        _blockHashes = blockHashes;
        _chainLockHashes = chainLockHashes;
    }
    return self;
}

- (NSData *)toData {
    NSMutableData *msg = [NSMutableData data];
    UInt256 h;
    [msg appendVarInt:self.txHashes.count + self.blockHashes.count + self.instantSendLockHashes.count + self.instantSendLockDHashes.count + self.chainLockHashes.count];
    for (NSValue *hash in self.txHashes) {
        [msg appendUInt32:DSInvType_Tx];
        [hash getValue:&h];
        [msg appendBytes:&h length:sizeof(h)];
    }
    for (NSValue *hash in self.instantSendLockHashes) {
        [msg appendUInt32:DSInvType_InstantSendLock];
        [hash getValue:&h];
        [msg appendBytes:&h length:sizeof(h)];
    }
    for (NSValue *hash in self.instantSendLockDHashes) {
        [msg appendUInt32:DSInvType_InstantSendDeterministicLock];
        [hash getValue:&h];
        [msg appendBytes:&h length:sizeof(h)];
    }
    for (NSValue *hash in self.blockHashes) {
        [msg appendUInt32:DSInvType_Merkleblock];
        [hash getValue:&h];
        [msg appendBytes:&h length:sizeof(h)];
    }
    for (NSValue *hash in self.chainLockHashes) {
        [msg appendUInt32:DSInvType_ChainLockSignature];
        [hash getValue:&h];
        [msg appendBytes:&h length:sizeof(h)];
    }
    return msg;
}

@end
