//
//  Created by Sam Westrich
//  Copyright © 2020 Dash Core Group. All rights reserved.
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

#import "DSContactRequest.h"
#import "DSBlockchainIdentity+Protected.h"
#import "NSData+Bitcoin.h"
#import "NSData+Encryption.h"
#import "NSString+Bitcoin.h"

@interface DSContactRequest ()

@property (nonatomic, assign) UInt256 recipientBlockchainIdentityUniqueId;
@property (nonatomic, assign) UInt256 senderBlockchainIdentityUniqueId;
@property (nonatomic, assign) uint32_t recipientKeyIndex;
@property (nonatomic, assign) uint32_t senderKeyIndex;
@property (nonatomic, assign) uint32_t accountReference;
@property (nonatomic, strong) NSData *encryptedAccountLabel;

@property (nonatomic, assign) NSTimeInterval createdAt;

@property (nonatomic, strong) NSData *encryptedPublicKeyData;
@property (nonatomic, strong) DSBlockchainIdentity *blockchainIdentity;

@end

@implementation DSContactRequest

- (instancetype)initWithDictionary:(DSStringValueDictionary *)rawContact onBlockchainIdentity:(DSBlockchainIdentity *)blockchainIdentity {
    NSParameterAssert(rawContact);
    NSParameterAssert(blockchainIdentity);
    if (!(self = [super init])) return nil;

    NSData *recipientData = rawContact[@"toUserId"];
    NSData *senderData = rawContact[@"$ownerId"];
    NSData *encryptedAccountLabel = rawContact[@"encryptedAccountLabel"];
    NSData *encryptedPublicKeyData = rawContact[@"encryptedPublicKey"];
    NSNumber *accountReference = rawContact[@"accountReference"];
    NSNumber *senderKeyIndex = rawContact[@"senderKeyIndex"];
    NSNumber *recipientKeyIndex = rawContact[@"recipientKeyIndex"];
    NSNumber *createdAt = rawContact[@"$createdAt"];
    if (!recipientData || !senderData || !encryptedPublicKeyData || !senderKeyIndex || !recipientKeyIndex || !createdAt) {
        NSAssert(FALSE, @"malformed server response");
        return nil;
    }
    self.recipientBlockchainIdentityUniqueId = recipientData.UInt256;
    self.senderBlockchainIdentityUniqueId = senderData.UInt256;
    self.encryptedPublicKeyData = encryptedPublicKeyData;
    self.encryptedAccountLabel = encryptedAccountLabel;
    self.accountReference = [accountReference unsignedIntValue];
    self.createdAt = [createdAt doubleValue] / 1000.0;
    self.recipientKeyIndex = [recipientKeyIndex unsignedIntValue];
    self.senderKeyIndex = [senderKeyIndex unsignedIntValue];
    self.blockchainIdentity = blockchainIdentity;
    return self;
}

+ (instancetype)contactRequestFromDictionary:(DSStringValueDictionary *)serverDictionary onBlockchainIdentity:(DSBlockchainIdentity *)blockchainIdentity {
    return [[self alloc] initWithDictionary:serverDictionary onBlockchainIdentity:blockchainIdentity];
}

- (BOOL)blockchainIdentityIsRecipient {
    if (uint256_eq(self.blockchainIdentity.uniqueID, self.recipientBlockchainIdentityUniqueId)) {
        //we are the recipient of the friend request
        return YES;
    } else if (uint256_eq(self.blockchainIdentity.uniqueID, self.senderBlockchainIdentityUniqueId)) {
        //we are the sender of the friend request
        return NO;
    }
    NSAssert(NO, @"We should never get here");
    return NO;
}

- (DSKey *)secretKeyForDecryptionOfType:(DSKeyType)type {
    uint32_t index = [self blockchainIdentityIsRecipient] ? self.recipientKeyIndex : self.senderKeyIndex;
    DSKey *key = [self.blockchainIdentity privateKeyAtIndex:index ofType:(DSKeyType)type];
    NSAssert(key, @"Key should exist");
    return key;
}

- (NSData *)decryptedPublicKeyDataWithKey:(DSKey *)key {
    return [self.encryptedPublicKeyData decryptWithSecretKey:[self secretKeyForDecryptionOfType:key.keyType] fromPublicKey:key];
}

- (NSString *)debugDescription {
    return [NSString stringWithFormat:@"%@ - from %@/%d to %@/%d", [super debugDescription], uint256_base58(self.senderBlockchainIdentityUniqueId), self.senderKeyIndex, uint256_base58(self.recipientBlockchainIdentityUniqueId), self.recipientKeyIndex];
}

@end
