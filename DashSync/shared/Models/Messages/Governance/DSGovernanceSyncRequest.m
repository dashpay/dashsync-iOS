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

#import "DSGovernanceSyncRequest.h"
#import "DSPeer.h"

@implementation DSGovernanceSyncRequest

- (instancetype)initWithParentHash:(UInt256)parentHash andBloomFilterData:(NSData *)bloomFilterData {
    self = [super init];
    if (self) {
        self.parentHash = parentHash;
        self.bloomFilterData = bloomFilterData;
    }
    return self;
}

- (NSString *)type {
    return MSG_GOVOBJSYNC;
}

- (NSData *)toData {
    UInt256 hash = self.parentHash;
    NSMutableData *msg = [NSMutableData data];
    [msg appendBytes:&hash length:sizeof(hash)];
    [msg appendData:self.bloomFilterData];
    return msg;
}

@end
