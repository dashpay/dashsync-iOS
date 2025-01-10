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
#import "DSIdentity+Protected.h"
#import "NSData+Dash.h"
#import "NSData+Encryption.h"
#import "NSString+Bitcoin.h"

@interface DSContactRequest ()

@property (nonatomic, assign) UInt256 recipientIdentityUniqueId;
@property (nonatomic, assign) UInt256 senderIdentityUniqueId;
@property (nonatomic, assign) uint32_t recipientKeyIndex;
@property (nonatomic, assign) uint32_t senderKeyIndex;
@property (nonatomic, assign) uint32_t accountReference;
@property (nonatomic, strong) NSData *encryptedAccountLabel;

@property (nonatomic, assign) NSTimeInterval createdAt;

@property (nonatomic, strong) NSData *encryptedPublicKeyData;
@property (nonatomic, strong) DSIdentity *identity;

@end

@implementation DSContactRequest

- (instancetype)initWithDictionary:(DSStringValueDictionary *)rawContact onIdentity:(DSIdentity *)identity {
    NSParameterAssert(rawContact);
    NSParameterAssert(identity);
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
    self.recipientIdentityUniqueId = recipientData.UInt256;
    self.senderIdentityUniqueId = senderData.UInt256;
    self.encryptedPublicKeyData = encryptedPublicKeyData;
    self.encryptedAccountLabel = encryptedAccountLabel;
    self.accountReference = [accountReference unsignedIntValue];
    self.createdAt = [createdAt doubleValue] / 1000.0;
    self.recipientKeyIndex = [recipientKeyIndex unsignedIntValue];
    self.senderKeyIndex = [senderKeyIndex unsignedIntValue];
    self.identity = identity;
    return self;
}

+ (instancetype)contactRequestFromDictionary:(DSStringValueDictionary *)serverDictionary
                                  onIdentity:(DSIdentity *)identity {
    return [[self alloc] initWithDictionary:serverDictionary onIdentity:identity];
}

- (BOOL)identityIsRecipient {
    if (uint256_eq(self.identity.uniqueID, self.recipientIdentityUniqueId)) {
        //we are the recipient of the friend request
        return YES;
    } else if (uint256_eq(self.identity.uniqueID, self.senderIdentityUniqueId)) {
        //we are the sender of the friend request
        return NO;
    }
    NSAssert(NO, @"We should never get here");
    return NO;
}

- (DMaybeOpaqueKey *)secretKeyForDecryptionOfType:(DKeyKind *)type {
    uint32_t index = [self identityIsRecipient] ? self.recipientKeyIndex : self.senderKeyIndex;
    DMaybeOpaqueKey *key = [self.identity privateKeyAtIndex:index ofType:type];
    NSAssert(key, @"Key should exist");
    return key;
}

- (NSData *)decryptedPublicKeyDataWithKey:(DOpaqueKey *)key {
    NSParameterAssert(key);
    DKeyKind *kind = dash_spv_crypto_keys_key_OpaqueKey_kind(key);
    DMaybeOpaqueKey *maybe_key = [self secretKeyForDecryptionOfType:kind];
    NSData *data = [self.encryptedPublicKeyData decryptWithSecretKey:maybe_key->ok fromPublicKey:key];
    DMaybeOpaqueKeyDtor(maybe_key);
    return data;
}

- (NSString *)debugDescription {
    return [NSString stringWithFormat:@"%@ - from %@/%d to %@/%d", [super debugDescription], uint256_base58(self.senderIdentityUniqueId), self.senderKeyIndex, uint256_base58(self.recipientIdentityUniqueId), self.recipientKeyIndex];
}

@end
