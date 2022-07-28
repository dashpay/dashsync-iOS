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

#import "DSGetMNListDiffRequest.h"
#import "DSPeer.h"
#import "NSCoder+Dash.h"
#import "NSMutableData+Dash.h"

#define kBaseBlockHashKey @"BaseBlockHash"
#define kBlockHashKey @"BlockHash"

@implementation DSGetMNListDiffRequest

/**
 * baseBlockHash: Hash of a block the requestor already has a valid masternode list of. Can be all-zero to indicate that a full masternode list is requested.
 * blockHash: Hash of the block for which the masternode list diff is requested
 */
+ (instancetype)requestWithBaseBlockHash:(UInt256)baseBlockHash blockHash:(UInt256)blockHash {
    return [[DSGetMNListDiffRequest alloc] initWithBaseBlockHash:baseBlockHash blockHash:blockHash];
}

- (instancetype)initWithBaseBlockHash:(UInt256)baseBlockHash blockHash:(UInt256)blockHash {
    self = [super init];
    if (self) {
        self.baseBlockHash = baseBlockHash;
        self.blockHash = blockHash;
    }
    return self;
}

// Overriden
- (NSString *)type {
    return MSG_GETMNLISTDIFF;
}

// Overriden
- (NSData *)toData {
    NSMutableData *msg = [NSMutableData data];
    [msg appendUInt256:self.baseBlockHash];
    [msg appendUInt256:self.blockHash];
    return msg;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeUInt256:self.baseBlockHash forKey:kBaseBlockHashKey];
    [coder encodeUInt256:self.blockHash forKey:kBlockHashKey];
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder {
    UInt256 baseBlockHash = [coder decodeUInt256ForKey:kBaseBlockHashKey];
    UInt256 blockHash = [coder decodeUInt256ForKey:kBlockHashKey];
    return [self initWithBaseBlockHash:baseBlockHash blockHash:blockHash];
}



@end
