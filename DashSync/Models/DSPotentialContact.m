//  
//  Created by Sam Westrich
//  Copyright © 2019 Dash Core Group. All rights reserved.
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

#import "DSPotentialContact.h"
#import "BigIntTypes.h"
#import "DSContactEntity+CoreDataClass.h"
#import "NSData+Bitcoin.h"

@implementation DSPotentialContact

-(instancetype)initWithUsername:(NSString*)username {
    self = [super init];
    if (self) {
        _username = username;
        _associatedBlockchainIdentityUniqueId = UINT256_ZERO;
    }
    return self;
}

-(instancetype)initWithUsername:(NSString*)username avatarPath:(NSString*)avatarPath publicMessage:(NSString*)publicMessage {
    self = [super init];
    if (self) {
        _username = username;
        _avatarPath = avatarPath;
        _publicMessage = publicMessage;
        _associatedBlockchainIdentityUniqueId = UINT256_ZERO;
    }
    return self;
}

-(instancetype)initWithContactEntity:(DSContactEntity*)contactEntity {
    self = [self initWithUsername:contactEntity.username avatarPath:contactEntity.avatarPath publicMessage:contactEntity.publicMessage];
    if (self) {
        _associatedBlockchainIdentityUniqueId = contactEntity.associatedBlockchainIdentityRegistrationHash.UInt256;
    }
    return self;
}

-(NSString*)debugDescription {
    return [NSString stringWithFormat:@"%@ - %@ - %@", [super debugDescription], self.username, uint256_hex(self.associatedBlockchainIdentityUniqueId)];
}



@end
