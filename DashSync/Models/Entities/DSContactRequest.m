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
#import "NSData+Bitcoin.h"
#import "NSString+Bitcoin.h"
#import "NSData+Encryption.h"
#import "DSBlockchainIdentity+Protected.h"

@interface DSContactRequest()

@property(nonatomic,assign) UInt256 recipientBlockchainIdentityUniqueId;
@property(nonatomic,assign) UInt256 senderBlockchainIdentityUniqueId;
@property(nonatomic,assign) uint32_t recipientKeyIndex;
@property(nonatomic,assign) uint32_t senderKeyIndex;

@property(nonatomic,assign) NSTimeInterval timestamp;

@property(nonatomic,strong) NSData * encryptedPublicKeyData;
@property(nonatomic,strong) DSBlockchainIdentity * blockchainIdentity;

@end

@implementation DSContactRequest

-(instancetype)initWithDictionary:(DSStringValueDictionary*)rawContact onBlockchainIdentity:(DSBlockchainIdentity*)blockchainIdentity {
    NSParameterAssert(rawContact);
    NSParameterAssert(blockchainIdentity);
    self = [super init];
    if (self) {
        NSString *recipientString = rawContact[@"toUserId"];
        NSString *senderString = rawContact[@"$userId"];
        NSString *encryptedPublicKeyString = rawContact[@"encryptedPublicKey"];
        NSNumber *senderKeyIndex = rawContact[@"senderKeyIndex"];
        NSNumber *recipientKeyIndex = rawContact[@"recipientKeyIndex"];
        NSNumber *timestamp = rawContact[@"timestamp"];
        if (!recipientString || !senderString || !encryptedPublicKeyString || !senderKeyIndex || !recipientKeyIndex || !timestamp) {
            NSAssert(FALSE, @"malformed server response");
            return nil;
        }
        self.recipientBlockchainIdentityUniqueId = [recipientString base58ToData].UInt256;
        self.senderBlockchainIdentityUniqueId = [senderString base58ToData].UInt256;
        self.encryptedPublicKeyData = [encryptedPublicKeyString base64ToData];
        self.timestamp = [timestamp doubleValue];
        //todo fix -1
        self.recipientKeyIndex = [recipientKeyIndex unsignedIntValue] - 1;
        self.senderKeyIndex = [senderKeyIndex unsignedIntValue] - 1;
        self.blockchainIdentity = blockchainIdentity;
    }
    return self;
}

+(instancetype)contactRequestFromDictionary:(DSStringValueDictionary*)serverDictionary onBlockchainIdentity:(DSBlockchainIdentity*)blockchainIdentity {
    return [[self alloc] initWithDictionary:serverDictionary onBlockchainIdentity:blockchainIdentity];
}

-(DSKey*)secretKeyForDecryptionOfType:(DSKeyType)type {
    if (uint256_eq(self.blockchainIdentity.uniqueID,self.recipientBlockchainIdentityUniqueId)) {
        //we are the recipient of the friend request
        return [self.blockchainIdentity privateKeyAtIndex:self.recipientKeyIndex ofType:(DSKeyType)type];
    } else if (uint256_eq(self.blockchainIdentity.uniqueID,self.senderBlockchainIdentityUniqueId)) {
        //we are the sender of the friend request
        return [self.blockchainIdentity privateKeyAtIndex:self.senderKeyIndex ofType:(DSKeyType)type];
    }
    return nil;
}

-(NSData*)decryptedPublicKeyDataWithKey:(DSKey*)key {
    return [self.encryptedPublicKeyData decryptWithSecretKey:[self secretKeyForDecryptionOfType:key.keyType] fromPeerWithPublicKey:key];
}

@end
