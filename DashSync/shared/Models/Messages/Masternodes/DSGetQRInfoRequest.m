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

#import "DSGetQRInfoRequest.h"
#import "DSPeer.h"
#import "NSCoder+Dash.h"
#import "NSMutableData+Dash.h"

#define kBaseBlockHashesKey @"BaseBlockHashes"
#define kBlockHashKey @"BlockHash"
#define kExtraShareKey @"ExtraShare"

@implementation DSGetQRInfoRequest

+ (instancetype)requestWithBaseBlockHashes:(NSArray<NSData *> *)baseBlockHashes blockHash:(UInt256)blockHash extraShare:(BOOL)extraShare {
    return [[DSGetQRInfoRequest alloc] initWithBaseBlockHashes:baseBlockHashes blockHash:blockHash extraShare:extraShare];
}

- (instancetype)initWithBaseBlockHashes:(NSArray<NSData *> *)baseBlockHashes blockHash:(UInt256)blockHash extraShare:(BOOL)extraShare {
    self = [super init];
    if (self) {
        self.baseBlockHashes = baseBlockHashes;
        self.blockHash = blockHash;
        self.extraShare = extraShare;
    }
    return self;
}

// MARK: Override

- (NSString *)type {
    return MSG_GETQUORUMROTATIONINFO;
}



- (NSData *)toData {
    NSMutableData *msg = [NSMutableData data];
    // Number of masternode lists the light client knows
    [msg appendVarInt:self.baseBlockHashes.count];
    // The base block hashes of the masternode lists the light client knows
    for (NSData *baseBlockHash in self.baseBlockHashes) {
        [msg appendData:baseBlockHash];
    }
    // Hash of the height the client requests
    [msg appendUInt256:self.blockHash];
    // Flag to indicate if an extra share is requested
    [msg appendUInt8:self.extraShare ? 1 : 0];

    return msg;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.baseBlockHashes forKey:kBaseBlockHashesKey];
    [coder encodeUInt256:self.blockHash forKey:kBlockHashKey];
    [coder encodeBool:self.extraShare forKey:kExtraShareKey];
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder {
    NSArray<NSData *> *baseBlockHashes = [coder decodeObjectForKey:kBaseBlockHashesKey];
    UInt256 blockHash = [coder decodeUInt256ForKey:kBlockHashKey];
    BOOL extraShare = [coder decodeBoolForKey:kExtraShareKey];
    return [self initWithBaseBlockHashes:baseBlockHashes blockHash:blockHash extraShare:extraShare];
}


@end
