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

#import "DSPotentialFriendship.h"
#import "DSAccount.h"
#import "DSWallet.h"
#import "DSDerivationPathFactory.h"
#import "DSFundsDerivationPath.h"
#import "DSDashPlatform.h"
#import "DSFriendRequestEntity+CoreDataClass.h"
#import "DSContactEntity+CoreDataClass.h"
#import "NSManagedObject+Sugar.h"
#import "DSBLSKey.h"
#import "DSIncomingFundsDerivationPath.h"
#import "DSDerivationPathEntity+CoreDataClass.h"
#import "DSPotentialContact.h"
#import "NSData+Encryption.h"

@interface DSPotentialFriendship()

@property (nonatomic, strong) DSAccount* account;
@property (nonatomic, strong) DSBlockchainIdentity * sourceBlockchainIdentity;
@property (nonatomic, strong) DSPotentialContact * destinationContact;
@property (nonatomic, strong) DSIncomingFundsDerivationPath * fundsDerivationPathForContact;
@property (nonatomic, strong) NSData * extendedPublicKey;
@property (nonatomic, strong) NSData * encryptedExtendedPublicKey;

@end

@implementation DSPotentialFriendship

-(instancetype)initWithDestinationContact:(DSPotentialContact*)destinationContact sourceBlockchainIdentity:(DSBlockchainIdentity*)sourceBlockchainIdentity account:(DSAccount*)account {
    if (!(self = [super init])) return nil;
    self.destinationContact = destinationContact;
    self.account = account;
    self.sourceBlockchainIdentity = sourceBlockchainIdentity;
    
    return self;
}

-(DSIncomingFundsDerivationPath*)createDerivationPath {
    NSAssert(!uint256_is_zero(self.destinationContact.associatedBlockchainIdentityUniqueId), @"associatedBlockchainIdentityUniqueId must not be null");
    self.fundsDerivationPathForContact = [DSIncomingFundsDerivationPath
                                          contactBasedDerivationPathWithDestinationBlockchainIdentityUniqueId:self.destinationContact.associatedBlockchainIdentityUniqueId sourceBlockchainIdentityUniqueId:self.sourceBlockchainIdentity.registrationTransitionHash forAccountNumber:self.account.accountNumber onChain:self.sourceBlockchainIdentity.wallet.chain];
    self.fundsDerivationPathForContact.account = self.account;
    DSDerivationPath * masterContactsDerivationPath = [self.account masterContactsDerivationPath];
    
    self.extendedPublicKey = [self.fundsDerivationPathForContact generateExtendedPublicKeyFromParentDerivationPath:masterContactsDerivationPath storeUnderWalletUniqueId:nil];
    __weak typeof(self) weakSelf = self;
    [self.sourceBlockchainIdentity encryptData:self.extendedPublicKey forRecipientKey:self.contactEncryptionPublicKey withPrompt:@"" completion:^(NSData * _Nonnull encryptedData) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        strongSelf.encryptedExtendedPublicKey = encryptedData;
    }];
    NSAssert(self.extendedPublicKey, @"Problem creating extended public key for potential contact?");
    return self.fundsDerivationPathForContact;
}

-(DPDocument*)contactRequestDocument {
    NSAssert(!uint256_is_zero(self.destinationContact.associatedBlockchainIdentityUniqueId), @"the destination contact's associatedBlockchainIdentityUniqueId must be set before making a friend request");
//    DSDashPlatform *dpp = [DSDashPlatform sharedInstanceForChain:self.sourceBlockchainIdentity.wallet.chain];
//    dpp.userId = uint256_reverse_hex(self.sourceBlockchainIdentity.registrationTransitionHash);
//
    //to do encrypt public key
    //DSBLSKey * key = [DSBLSKey blsKeyWithPublicKey:self.contactEncryptionPublicKey onChain:self.sourceBlockchainIdentity.wallet.chain];
    
    NSAssert(self.extendedPublicKey, @"Problem creating extended public key for potential contact?");
    NSError *error = nil;
    
    
    DSStringValueDictionary *data = @{
                           @"toUserId" : uint256_data(self.destinationContact.associatedBlockchainIdentityUniqueId).reverse.base58String,
                           @"encryptedPublicKey" : [self.encryptedExtendedPublicKey base64EncodedStringWithOptions:0],
                           };
    
    
    DPDocument *contact = [self.sourceBlockchainIdentity.dashpayDocumentFactory documentOnTable:@"contactRequest" withDataDictionary:data error:&error];
    NSAssert(error == nil, @"Failed to build a contact");
    return contact;
}

-(DSDerivationPathEntity*)storeExtendedPublicKeyAssociatedWithFriendRequest:(DSFriendRequestEntity*)friendRequestEntity {
    [self.fundsDerivationPathForContact storeExtendedPublicKeyUnderWalletUniqueId:self.account.wallet.uniqueID];
    
    
    __block DSDerivationPathEntity* fundsDerivationPathEntity = nil;
    
    [friendRequestEntity.managedObjectContext performBlockAndWait:^{
        [DSDerivationPathEntity setContext:friendRequestEntity.managedObjectContext];
        fundsDerivationPathEntity = [DSDerivationPathEntity derivationPathEntityMatchingDerivationPath:self.fundsDerivationPathForContact associateWithFriendRequest:friendRequestEntity];
    }];
    return fundsDerivationPathEntity;
}


-(DSFriendRequestEntity*)outgoingFriendRequestForContactEntity:(DSContactEntity*)contactEntity {
    NSParameterAssert(contactEntity);
    NSAssert(uint256_eq(contactEntity.associatedBlockchainIdentityUniqueId.UInt256,self.destinationContact.associatedBlockchainIdentityUniqueId), @"contact entity must match");
    DSFriendRequestEntity * friendRequestEntity = [DSFriendRequestEntity managedObject];
    friendRequestEntity.sourceContact = self.sourceBlockchainIdentity.ownContact;
    friendRequestEntity.destinationContact = contactEntity;
    friendRequestEntity.derivationPath = [DSDerivationPathEntity derivationPathEntityMatchingDerivationPath:self.fundsDerivationPathForContact];
    friendRequestEntity.account = friendRequestEntity.derivationPath.account;
    
    [friendRequestEntity finalizeWithFriendshipIdentifier];
    return friendRequestEntity;
}


-(DSFriendRequestEntity*)outgoingFriendRequest {
    NSAssert(!uint256_is_zero(self.destinationContact.associatedBlockchainIdentityUniqueId), @"destination contact must be known");
    DSContactEntity * contactEntity = [DSContactEntity anyObjectMatching:@"associatedBlockchainIdentityUniqueId == %@",uint256_data(self.destinationContact.associatedBlockchainIdentityUniqueId)];
    if (!contactEntity) {
        contactEntity =  [DSContactEntity managedObject];
        
        contactEntity.username = self.destinationContact.username;
        contactEntity.avatarPath = self.destinationContact.avatarPath;
        contactEntity.publicMessage = self.destinationContact.publicMessage;
        contactEntity.associatedBlockchainIdentityUniqueId = uint256_data(self.destinationContact.associatedBlockchainIdentityUniqueId);
        contactEntity.chain = self.account.wallet.chain.chainEntity;
    }
    
    return [self outgoingFriendRequestForContactEntity:contactEntity];
}

-(BOOL)isEqual:(id)object {
    if (self == object) {
        return TRUE;
    }
    
    if (![object isKindOfClass:[self class]]) {
        return FALSE;
    }
    
    if ([self.destinationContact.username isEqualToString:((DSPotentialFriendship*)object).destinationContact.username] && uint256_eq(self.sourceBlockchainIdentity.registrationTransitionHash,((DSPotentialFriendship*)object).sourceBlockchainIdentity.registrationTransitionHash) &&
        self.account.accountNumber == ((DSPotentialFriendship*)object).account.accountNumber) {
        return TRUE;
    }
    
    return FALSE;
}

- (NSUInteger)hash {
    return self.destinationContact.username.hash ^ self.sourceBlockchainIdentity.hash ^ self.account.accountNumber;
}

-(NSString*)debugDescription {
    return [NSString stringWithFormat:@"%@ - s:%@ d:%@", [super debugDescription], self.sourceBlockchainIdentity.currentUsername, self.destinationContact.username];
}

@end
