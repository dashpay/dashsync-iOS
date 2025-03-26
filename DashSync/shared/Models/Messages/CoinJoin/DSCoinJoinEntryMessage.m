//  
//  Created by Andrei Ashikhmin
//  Copyright © 2024 Dash Core Group. All rights reserved.
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

#import "DSCoinJoinEntryMessage.h"
#import "DSPeer.h"

@implementation DSCoinJoinEntryMessage

+ (instancetype)requestWithData:(NSData *)data {
    return [[DSCoinJoinEntryMessage alloc] initWithData:data];
}

+ (NSString *)type {
    return MSG_COINJOIN_ENTRY;
}

- (instancetype)initWithData:(NSData *)data {
    self = [super init];
    if (self) {
        _data = data;
    }
    return self;
}

- (NSString *)type {
    return DSCoinJoinEntryMessage.type;
}

- (NSData *)toData {
    return self.data;
}
@end
