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
#import "DashPlatformProtocol+DashSync.h"
#import "DSFriendRequestEntity+CoreDataClass.h"
#import "DSContactEntity+CoreDataClass.h"
#import "NSManagedObject+Sugar.h"
#import "DSDAPIClient+RegisterDashPayContract.h"
#import "DSBLSKey.h"
#import "DSIncomingFundsDerivationPath.h"
#import "DSDerivationPathEntity+CoreDataClass.h"

@interface DSPotentialFriendship()

@property (nonatomic, strong) DSAccount* account;
@property (nonatomic, strong) DSBlockchainUser * sourceBlockchainUser;
@property (nonatomic, copy) NSString * destinationContactUsername;
@property (nonatomic, strong) DSIncomingFundsDerivationPath * fundsDerivationPathForContact;
@property (nonatomic, strong) NSData * extendedPublicKey;

@end

@implementation DSPotentialFriendship

-(instancetype)initWithDestinationUsername:(NSString*)destinationUsername sourceBlockchainUser:(DSBlockchainUser*)sourceBlockchainUser account:(DSAccount*)account {
    if (!(self = [super init])) return nil;
    self.destinationContactUsername = destinationUsername;
    self.account = account;
    self.sourceBlockchainUser = sourceBlockchainUser;
    _contactBlockchainUserRegistrationTransactionHash = UINT256_ZERO;
    
    return self;
}

-(void)setContactBlockchainUserRegistrationTransactionHash:(UInt256)contactBlockchainUserRegistrationTransactionHash {
    _contactBlockchainUserRegistrationTransactionHash = contactBlockchainUserRegistrationTransactionHash;
    NSAssert(!uint256_is_zero(contactBlockchainUserRegistrationTransactionHash),@"contactBlockchainUserRegistrationTransactionHash must not be null");
    self.fundsDerivationPathForContact = [DSIncomingFundsDerivationPath
                                          contactBasedDerivationPathWithDestinationBlockchainUserRegistrationTransactionHash:self.contactBlockchainUserRegistrationTransactionHash sourceBlockchainUserRegistrationTransactionHash:self.sourceBlockchainUser.registrationTransactionHash forAccountNumber:self.account.accountNumber onChain:self.sourceBlockchainUser.wallet.chain];
    self.fundsDerivationPathForContact.account = self.account;
    DSDerivationPath * masterContactsDerivationPath = [self.account masterContactsDerivationPath];
    
    self.extendedPublicKey = [self.fundsDerivationPathForContact generateExtendedPublicKeyFromParentDerivationPath:masterContactsDerivationPath storeUnderWalletUniqueId:nil];
    NSAssert(self.extendedPublicKey, @"Problem creating extended public key for potential contact?");
}

-(DPDocument*)contactRequestDocument {
    NSAssert(!uint256_is_zero(self.contactBlockchainUserRegistrationTransactionHash), @"the contactBlockchainUserRegistrationTransactionHash must be set before making a friend request");
    DashPlatformProtocol *dpp = [DashPlatformProtocol sharedInstance];
    dpp.userId = uint256_reverse_hex(self.sourceBlockchainUser.registrationTransactionHash);
    DPContract *contract = [DSDAPIClient ds_currentDashPayContract];
    dpp.contract = contract;
    
    //to do encrypt public key
    //DSBLSKey * key = [DSBLSKey blsKeyWithPublicKey:self.contactEncryptionPublicKey onChain:self.sourceBlockchainUser.wallet.chain];
    
    NSAssert(self.extendedPublicKey, @"Problem creating extended public key for potential contact?");
    NSError *error = nil;
    DPJSONObject *data = @{
                           @"toUserId" : uint256_reverse_hex(self.contactBlockchainUserRegistrationTransactionHash),
                           @"publicKey" : [self.extendedPublicKey base64EncodedStringWithOptions:0],
                           };
    
    
    DPDocument *contact = [dpp.documentFactory documentWithType:@"contact" data:data error:&error];
    NSAssert(error == nil, @"Failed to build a contact");
    return contact;
}

-(void)storeExtendedPublicKeyAssociatedWithFriendRequest:(DSFriendRequestEntity*)friendRequestEntity {
    [self.fundsDerivationPathForContact storeExtendedPublicKeyUnderWalletUniqueId:self.account.wallet.uniqueID];
    
    [friendRequestEntity.managedObjectContext performBlockAndWait:^{
        [DSDerivationPathEntity setContext:friendRequestEntity.managedObjectContext];
        [DSDerivationPathEntity derivationPathEntityMatchingDerivationPath:self.fundsDerivationPathForContact associateWithFriendRequest:friendRequestEntity];
    }];
}


-(DSFriendRequestEntity*)outgoingFriendRequest {
    DSContactEntity * contactEntity = [DSContactEntity managedObject];
    
    contactEntity.username = self.destinationContactUsername;
    
    DSFriendRequestEntity * friendRequestEntity = [DSFriendRequestEntity managedObject];
    friendRequestEntity.sourceContact = self.sourceBlockchainUser.ownContact;
    friendRequestEntity.destinationContact = contactEntity;
    friendRequestEntity.derivationPath = [DSDerivationPathEntity derivationPathEntityMatchingDerivationPath:self.fundsDerivationPathForContact];
    return friendRequestEntity;
}

//-(DSFriendRequestEntity*)incomingFriendRequest {
//    DSContactEntity * contactEntity = [DSContactEntity managedObject];
//
//    [contactEntity setAttributesFromPotentialContact:self];
//
//    DSFriendRequestEntity * friendRequestEntity = [DSFriendRequestEntity managedObject];
//    friendRequestEntity.sourceContact = contactEntity;
//    friendRequestEntity.destinationContact = self.sourceBlockchainUser.ownContact;
//
//    friendRequestEntity.extendedPublicKey = self.incomingExtendedPublicKey;
//    return friendRequestEntity;
//}

-(BOOL)isEqual:(id)object {
    if (self == object) {
        return TRUE;
    }
    
    if (![object isKindOfClass:[self class]]) {
        return FALSE;
    }
    
    if ([self.destinationContactUsername isEqualToString:((DSPotentialFriendship*)object).destinationContactUsername] && uint256_eq(self.sourceBlockchainUser.registrationTransactionHash,((DSPotentialFriendship*)object).sourceBlockchainUser.registrationTransactionHash) &&
        self.account.accountNumber == ((DSPotentialFriendship*)object).account.accountNumber) {
        return TRUE;
    }
    
    return FALSE;
}

- (NSUInteger)hash {
    return self.destinationContactUsername.hash ^ self.sourceBlockchainUser.hash ^ self.account.accountNumber;
}

@end
