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

#import "dash_shared_core.h"
#import "DPDocumentFactory.h"
#import "DSPotentialOneWayFriendship.h"
#import "DSAccount.h"
#import "DSIdentity+Protected.h"
#import "DSBlockchainIdentityEntity+CoreDataClass.h"
#import "DSDashPlatform.h"
#import "DSDashpayUserEntity+CoreDataClass.h"
#import "DSDerivationPath+Protected.h"
#import "DSDerivationPathEntity+CoreDataClass.h"
#import "DSDerivationPathFactory.h"
#import "DSFriendRequestEntity+CoreDataClass.h"
#import "DSFundsDerivationPath.h"
#import "DSIncomingFundsDerivationPath.h"
#import "DSKeyManager.h"
#import "DSPotentialContact.h"
#import "DSWallet.h"
#import "NSData+Encryption.h"
#import "NSManagedObject+Sugar.h"

@interface DSPotentialOneWayFriendship ()

@property (nonatomic, strong) DSAccount *account;
@property (nonatomic, strong) DSIdentity *sourceIdentity;
@property (nonatomic, strong) DSIdentity *destinationIdentity;
@property (nonatomic, strong) DSPotentialContact *destinationContact;
@property (nonatomic, strong) DSIncomingFundsDerivationPath *fundsDerivationPathForContact;
@property (nonatomic, assign) DMaybeOpaqueKey *extendedPublicKey;
@property (nonatomic, strong) NSData *encryptedExtendedPublicKeyData;
@property (nonatomic, assign) uint32_t sourceKeyIndex;
@property (nonatomic, assign) uint32_t destinationKeyIndex;
@property (nonatomic, assign) NSTimeInterval createdAt;

@end

@implementation DSPotentialOneWayFriendship

- (instancetype)initWithDestinationIdentity:(DSIdentity *)destinationIdentity
                        destinationKeyIndex:(uint32_t)destinationKeyIndex
                             sourceIdentity:(DSIdentity *)sourceIdentity
                             sourceKeyIndex:(uint32_t)sourceKeyIndex
                                    account:(DSAccount *)account {
    return [self initWithDestinationIdentity:destinationIdentity
                         destinationKeyIndex:destinationKeyIndex
                              sourceIdentity:sourceIdentity
                              sourceKeyIndex:sourceKeyIndex
                                     account:account
                                   createdAt:[[NSDate date] timeIntervalSince1970]];
}

- (instancetype)initWithDestinationIdentity:(DSIdentity *)destinationIdentity
                        destinationKeyIndex:(uint32_t)destinationKeyIndex
                             sourceIdentity:(DSIdentity *)sourceIdentity
                             sourceKeyIndex:(uint32_t)sourceKeyIndex
                                    account:(DSAccount *)account
                                  createdAt:(NSTimeInterval)createdAt {
    if (!(self = [super init])) return nil;
    self.destinationIdentity = destinationIdentity;
    self.account = account;
    self.sourceIdentity = sourceIdentity;
    self.sourceKeyIndex = sourceKeyIndex;
    self.destinationKeyIndex = destinationKeyIndex;
    self.createdAt = createdAt;

    return self;
}

- (UInt256)destinationIdentityUniqueId {
    if (self.destinationIdentity) {
        return self.destinationIdentity.uniqueID;
    } else if (self.destinationContact) {
        return self.destinationContact.associatedIdentityUniqueId;
    }
    return UINT256_ZERO;
}

- (DMaybeOpaqueKey *)sourceKeyAtIndex {
    NSAssert(self.sourceIdentity != nil, @"The source identity should be present");
    return [self.sourceIdentity keyAtIndex:self.sourceKeyIndex];
}

- (DMaybeOpaqueKey *)destinationKeyAtIndex {
    if (self.destinationIdentity) {
        return [self.destinationIdentity keyAtIndex:self.destinationKeyIndex];
    } else if (self.destinationContact) {
        return [self.destinationContact publicKeyAtIndex:self.destinationKeyIndex].pointerValue;
    }
    return nil;
}

- (DSIncomingFundsDerivationPath *)derivationPath {
    NSAssert(uint256_is_not_zero([self destinationIdentityUniqueId]), @"destinationBlockchainIdentityUniqueId must not be null");
    return [DSIncomingFundsDerivationPath contactBasedDerivationPathWithDestinationIdentityUniqueId:[self destinationIdentityUniqueId]
                                                                             sourceIdentityUniqueId:self.sourceIdentity.uniqueID
                                                                                         forAccount:self.account
                                                                                            onChain:self.sourceIdentity.wallet.chain];
}

- (void)createDerivationPathAndSaveExtendedPublicKeyWithCompletion:(void (^)(BOOL success, DSIncomingFundsDerivationPath *incomingFundsDerivationPath))completion {
    NSAssert(uint256_is_not_zero([self destinationIdentityUniqueId]), @"destinationBlockchainIdentityUniqueId must not be null");
    self.fundsDerivationPathForContact = [self derivationPath];
    DSDerivationPath *masterContactsDerivationPath = [self.account masterContactsDerivationPath];
    self.extendedPublicKey = [self.fundsDerivationPathForContact generateExtendedPublicKeyFromParentDerivationPath:masterContactsDerivationPath storeUnderWalletUniqueId:nil];
    if (completion) completion(YES, self.fundsDerivationPathForContact);
}

- (void)encryptExtendedPublicKeyWithCompletion:(void (^)(BOOL success))completion {
    NSAssert(self.extendedPublicKey && self.extendedPublicKey->ok, @"Problem creating extended public key for potential contact?");
    __weak typeof(self) weakSelf = self;
    DMaybeOpaqueKey *recipientKey = [self destinationKeyAtIndex];
    [self.sourceIdentity encryptData:[DSKeyManager extendedPublicKeyData:self.extendedPublicKey->ok]
                      withKeyAtIndex:self.sourceKeyIndex
                     forRecipientKey:recipientKey->ok
                          completion:^(NSData *_Nonnull encryptedData) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            if (completion) completion(NO);
            return;
        }
        strongSelf.encryptedExtendedPublicKeyData = encryptedData;
        if (completion) completion(YES);
    }];
}

- (uint32_t)createAccountReference {
    // TODO: make test
    return dash_spv_crypto_keys_key_OpaqueKey_create_account_reference([self sourceKeyAtIndex]->ok, self.extendedPublicKey->ok, self.account.accountNumber);
}

- (DPDocument *)contactRequestDocumentWithEntropy:(NSData *)entropyData {
    NSAssert(uint256_is_not_zero([self destinationIdentityUniqueId]), @"the destination contact's associatedIdentityUniqueId must be set before making a friend request");
    NSAssert([self.encryptedExtendedPublicKeyData length] > 0, @"The encrypted extended public key must exist");
    NSAssert(self.extendedPublicKey, @"Problem creating extended public key for potential contact?");
    NSError *error = nil;

    uint64_t createAtMs = (self.createdAt) * 1000;
    DSStringValueDictionary *data = @{
        @"$createdAt": @(createAtMs),
        @"toUserId": uint256_data([self destinationIdentityUniqueId]),
        @"encryptedPublicKey": self.encryptedExtendedPublicKeyData,
        @"senderKeyIndex": @(self.sourceKeyIndex),
        @"recipientKeyIndex": @(self.destinationKeyIndex),
        @"accountReference": @([self createAccountReference])
    };
    DPDocument *contact = [self.sourceIdentity.dashpayDocumentFactory documentOnTable:@"contactRequest" withDataDictionary:data usingEntropy:entropyData error:&error];
    NSAssert(error == nil, @"Failed to build a contact");
    return contact;
}

- (DSDerivationPathEntity *)storeExtendedPublicKeyAssociatedWithFriendRequest:(DSFriendRequestEntity *)entity
                                                                    inContext:(NSManagedObjectContext *)context {
//    [self.fundsDerivationPathForContact storeExtendedPublicKeyUnderWalletUniqueId:self.account.wallet.uniqueIDString];
    
    NSData *data = [DSKeyManager extendedPublicKeyData:self.fundsDerivationPathForContact.extendedPublicKey->ok];
    setKeychainData(data, [self.fundsDerivationPathForContact walletBasedExtendedPublicKeyLocationStringForWalletUniqueID:self.account.wallet.uniqueIDString], NO);
    __block DSDerivationPathEntity *fundsDerivationPathEntity = nil;
    
    [context performBlockAndWait:^{
        fundsDerivationPathEntity = [DSDerivationPathEntity derivationPathEntityMatchingDerivationPath:self.fundsDerivationPathForContact
                                                                            associateWithFriendRequest:entity
                                                                                             inContext:context];
    }];
    return fundsDerivationPathEntity;
}

- (DSDerivationPathEntity *)storeExtendedPublicKeyAssociatedWithFriendRequest:(DSFriendRequestEntity *)entity {
    return [self storeExtendedPublicKeyAssociatedWithFriendRequest:entity
                                                         inContext:entity.managedObjectContext];
}


- (DSFriendRequestEntity *)outgoingFriendRequestForDashpayUserEntity:(DSDashpayUserEntity *)dashpayUserEntity
                                                         atTimestamp:(NSTimeInterval)timestamp {
    NSParameterAssert(dashpayUserEntity);
    NSAssert(uint256_eq(dashpayUserEntity.associatedBlockchainIdentity.uniqueID.UInt256, [self destinationIdentityUniqueId]), @"contact entity must match");
    NSAssert(self.sourceIdentity.matchingDashpayUserInViewContext, @"The own contact of the source Identity must be set");
    DSFriendRequestEntity *friendRequestEntity = [DSFriendRequestEntity managedObjectInBlockedContext:dashpayUserEntity.managedObjectContext];
    friendRequestEntity.sourceContact = [self.sourceIdentity matchingDashpayUserInContext:friendRequestEntity.managedObjectContext];
    friendRequestEntity.destinationContact = dashpayUserEntity;
    NSAssert(friendRequestEntity.sourceContact != friendRequestEntity.destinationContact, @"This must be different contacts");
    friendRequestEntity.derivationPath = [DSDerivationPathEntity derivationPathEntityMatchingDerivationPath:self.fundsDerivationPathForContact inContext:dashpayUserEntity.managedObjectContext];
    NSAssert(friendRequestEntity.derivationPath, @"There must be a derivation path");
    friendRequestEntity.account = friendRequestEntity.derivationPath.account;
    friendRequestEntity.timestamp = timestamp;
    [friendRequestEntity finalizeWithFriendshipIdentifier];
    return friendRequestEntity;
}


//-(DSFriendRequestEntity*)outgoingFriendRequest {
//    NSAssert(uint256_is_not_zero(self.destinationContact.associatedIdentityUniqueId), @"destination contact must be known");
//    DSDashpayUserEntity * dashpayUserEntity = [DSDashpayUserEntity anyObjectInContext:context matching:@"associatedBlockchainIdentityUniqueId == %@",uint256_data(self.destinationContact.associatedIdentityUniqueId)];
//    if (!dashpayUserEntity) {
//        dashpayUserEntity =  [DSDashpayUserEntity managedObject];
//        dashpayUserEntity.avatarPath = self.destinationContact.avatarPath;
//        dashpayUserEntity.publicMessage = self.destinationContact.publicMessage;
//        dashpayUserEntity.associatedBlockchainIdentity = uint256_data([self destinationBlockchainIdentityUniqueId]);
//        dashpayUserEntity.chain = self.account.wallet.chain.chainEntity;
//    }
//
//    return [self outgoingFriendRequestForDashpayUserEntity:dashpayUserEntity];
//}

- (BOOL)isEqual:(id)object {
    if (self == object) return TRUE;
    if (![object isKindOfClass:[self class]]) return FALSE;
    if (uint256_eq(self.destinationIdentity.uniqueID, ((DSPotentialOneWayFriendship *)object).destinationIdentity.uniqueID) && uint256_eq(self.sourceIdentity.uniqueID, ((DSPotentialOneWayFriendship *)object).sourceIdentity.uniqueID) &&
        self.account.accountNumber == ((DSPotentialOneWayFriendship *)object).account.accountNumber) {
        return TRUE;
    }
    return FALSE;
}

- (NSUInteger)hash {
    return self.destinationIdentity.hash ^ self.sourceIdentity.hash ^ self.account.accountNumber;
}

- (NSString *)debugDescription {
    return [NSString stringWithFormat:@"%@ - s:%@ d:%@", [super debugDescription], self.sourceIdentity.currentDashpayUsername, self.destinationIdentity.currentDashpayUsername];
}

@end
