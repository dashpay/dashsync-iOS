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

#import "DSDSegRequest.h"
#import "DSPeer.h"
#import "NSMutableData+Dash.h"

@implementation DSDSegRequest

+ (instancetype)requestWithUTXO:(DSUTXO)utxo {
    return [[DSDSegRequest alloc] initWithUTXO:utxo];
}

- (instancetype)initWithUTXO:(DSUTXO)utxo {
    self = [super init];
    if (self) {
        self.utxo = utxo;
    }
    return self;
}

- (NSString *)type {
    return MSG_DSEG;
}

- (NSString *)description {
    return uint256_is_zero(self.utxo.hash) ? @"Masternode List" : @"Masternode Entry";
}

- (NSData *)toData {
    NSMutableData *msg = [NSMutableData data];
    DSUTXO utxo = self.utxo;
    [msg appendUInt256:utxo.hash];
    if (uint256_is_zero(utxo.hash)) {
        [msg appendUInt32:UINT32_MAX];
    } else {
        [msg appendUInt32:(uint32_t)utxo.n];
    }

    [msg appendUInt8:0];
    [msg appendUInt32:UINT32_MAX];
    return msg;
}
@end
