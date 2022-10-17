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

#import "DSAddrRequest.h"
#import "DSPeer.h"
#import "NSMutableData+Dash.h"

@implementation DSAddrRequest

+ (instancetype)request {
    return [[DSAddrRequest alloc] init];
}

- (NSString *)type {
    return MSG_ADDR;
}

- (NSData *)toData {
    NSMutableData *msg = [NSMutableData data];
    // TODO: send peer addresses we know about
    [msg appendVarInt:0];
    return msg;
}
@end
