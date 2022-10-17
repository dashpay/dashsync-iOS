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

#import "DSGetDataForTransactionHashRequest.h"
#import "DSPeer.h"
#import "NSMutableData+Dash.h"

@implementation DSGetDataForTransactionHashRequest

+ (instancetype)requestForTransactionHash:(UInt256)txHash {
    return [[DSGetDataForTransactionHashRequest alloc] initWithTransactionHash:txHash];
}

- (instancetype)initWithTransactionHash:(UInt256)txHash {
    self = [super init];
    if (self) {
        self.txHash = txHash;
    }
    return self;
}

- (NSData *)toData {
    NSMutableData *msg = [NSMutableData data];
    [msg appendVarInt:1];
    [msg appendUInt32:DSInvType_Tx];
    [msg appendUInt256:self.txHash];
    return msg;
}

@end
