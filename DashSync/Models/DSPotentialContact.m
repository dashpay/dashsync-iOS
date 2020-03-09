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
#import "DSKey.h"
#import "NSData+Bitcoin.h"

@interface DSPotentialContact ()

@property (nonatomic, strong) NSMutableDictionary *keyDictionary;

@end

@implementation DSPotentialContact

- (instancetype)initWithUsername:(NSString *)username {
    self = [super init];
    if (self) {
        _username = username;
        _associatedBlockchainIdentityUniqueId = UINT256_ZERO;
        self.keyDictionary = [NSMutableDictionary dictionary];
    }
    return self;
}

- (instancetype)initWithUsername:(NSString *)username avatarPath:(NSString *)avatarPath publicMessage:(NSString *)publicMessage {
    self = [self initWithUsername:username];
    if (self) {
        _avatarPath = avatarPath;
        _publicMessage = publicMessage;
    }
    return self;
}

- (instancetype)initWithContactEntity:(DSContactEntity *)contactEntity {
    self = [self initWithUsername:contactEntity.username avatarPath:contactEntity.avatarPath publicMessage:contactEntity.publicMessage];
    if (self) {
        _associatedBlockchainIdentityUniqueId = contactEntity.associatedBlockchainIdentityUniqueId.UInt256;
    }
    return self;
}

- (NSString *)debugDescription {
    return [NSString stringWithFormat:@"%@ - %@ - %@", [super debugDescription], self.username, uint256_hex(self.associatedBlockchainIdentityUniqueId)];
}

- (void)addPublicKey:(DSKey *)key atIndex:(NSUInteger)index {
    self.keyDictionary[@(index)] = key;
}

- (DSKey *)publicKeyAtIndex:(NSUInteger)index {
    return self.keyDictionary[@(index)];
}


@end
