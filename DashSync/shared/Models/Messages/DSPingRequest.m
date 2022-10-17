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

#import "DSPingRequest.h"
#import "DSPeer.h"
#import "NSMutableData+Dash.h"

@implementation DSPingRequest

+ (instancetype)requestWithLocalNonce:(uint64_t)localNonce {
    return [[DSPingRequest alloc] initWithLocalNonce:localNonce type:MSG_PING];
}

- (instancetype)initWithLocalNonce:(uint64_t)localNonce type:(NSString *)type {
    self = [super initWithType:type];
    if (self) {
        _localNonce = localNonce;
    }
    return self;
}

- (NSData *)toData {
    NSMutableData *msg = [NSMutableData data];
    [msg appendUInt64:self.localNonce];
    return msg;
}
@end
