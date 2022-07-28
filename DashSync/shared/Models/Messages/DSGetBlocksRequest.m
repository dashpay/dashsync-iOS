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

#import "BigIntTypes.h"
#import "DSGetBlocksRequest.h"
#import "DSPeer.h"
#import "NSData+Dash.h"
#import "NSMutableData+Dash.h"

@implementation DSGetBlocksRequest

+ (instancetype)requestWithLocators:(NSArray *)locators andHashStop:(UInt256)hashStop protocolVersion:(uint32_t)protocolVersion {
    return [[DSGetBlocksRequest alloc] initWithLocators:locators hashStop:hashStop protocolVersion:protocolVersion];
}

- (instancetype)initWithLocators:(NSArray *)locators hashStop:(UInt256)hashStop protocolVersion:(uint32_t)protocolVersion {
    self = [super init];
    if (self) {
        _locators = locators;
        _hashStop = hashStop;
        _protocolVersion = protocolVersion;
    }
    return self;
}

- (NSString *)type {
    return MSG_GETBLOCKS;
}

- (NSData *)toData {
    NSMutableData *msg = [NSMutableData data];

    [msg appendUInt32:self.protocolVersion];
    [msg appendVarInt:self.locators.count];

    for (NSData *hashData in self.locators) {
        [msg appendUInt256:hashData.UInt256];
    }
    UInt256 hashStop = self.hashStop;
    [msg appendBytes:&hashStop length:sizeof(hashStop)];
    return msg;
}

@end
