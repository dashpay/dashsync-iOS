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

#import "DSInvRequest.h"
#import "DSPeer.h"
#import "NSMutableData+Dash.h"

@implementation DSInvRequest

+ (instancetype)requestWithHashes:(NSOrderedSet<NSValue *> *)hashes ofInvType:(uint32_t)invType {
    return [[DSInvRequest alloc] initWithHashes:hashes ofInvType:invType];
}

- (instancetype)initWithHashes:(NSOrderedSet<NSValue *> *)hashes ofInvType:(uint32_t)invType {
    self = [super init];
    if (self) {
        _hashes = hashes;
        _invType = invType;
    }
    return self;
}

- (NSString *)type {
    return MSG_INV;
}

- (NSData *)toData {
    NSMutableData *msg = [NSMutableData data];
    UInt256 h;
    [msg appendVarInt:self.hashes.count];

    for (NSValue *hash in self.hashes) {
        [msg appendUInt32:self.invType];
        [hash getValue:&h];
        [msg appendBytes:&h length:sizeof(h)];
    }
    return msg;
}

@end
