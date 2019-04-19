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
#import "DSAccount.h"
#import "DSWallet.h"
#import "DSDerivationPathFactory.h"
#import "DSFundsDerivationPath.h"
#import "DashPlatformProtocol+DashSync.h"
#import "DSFriendRequestEntity+CoreDataClass.h"
#import "DSContactEntity+CoreDataClass.h"
#import "NSManagedObject+Sugar.h"
#import "DSDAPIClient+RegisterDashPayContract.h"

@interface DSPotentialContact()

@property (nonatomic, strong) DSAccount* account;
@property (nonatomic, strong) DSBlockchainUser * blockchainUserOwner;
@property (nonatomic, copy) NSString * username;

@end

@implementation DSPotentialContact

-(instancetype)initWithUsername:(NSString*)username blockchainUserOwner:(DSBlockchainUser*)blockchainUserOwner account:(DSAccount*)account {
    if (!(self = [super init])) return nil;
    self.username = username;
    self.account = account;
    self.blockchainUserOwner = blockchainUserOwner;
    self.contactBlockchainUserRegistrationTransactionHash = UINT256_ZERO;
    return self;
}

-(DPDocument*)contactRequestDocument {
    NSAssert(!uint256_is_zero(self.contactBlockchainUserRegistrationTransactionHash), @"the contactBlockchainUserRegistrationTransactionHash must be set before making a friend request");
    DashPlatformProtocol *dpp = [DashPlatformProtocol sharedInstance];
    dpp.userId = self.blockchainUserOwner.registrationTransactionHashIdentifier;
    DPContract *contract = [DSDAPIClient ds_currentDashPayContract];
    dpp.contract = contract;
    
    DSFundsDerivationPath * fundsDerivationPathForContact = [DSFundsDerivationPath
                                                             contactBasedDerivationPathForBlockchainUserRegistrationTransactionHash:self.contactBlockchainUserRegistrationTransactionHash forAccountNumber:self.account.accountNumber onChain:self.account.wallet.chain];
    DSDerivationPath * masterContactsDerivationPath = [self.account masterContactsDerivationPath];
    
    [fundsDerivationPathForContact generateExtendedPublicKeyFromParentDerivationPath:masterContactsDerivationPath storeUnderWalletUniqueId:nil];
    NSAssert(fundsDerivationPathForContact.extendedPublicKey, @"Problem creating extended public key for potential contact?");
    NSError *error = nil;
    DPJSONObject *data = @{
                           @"toUserId" : uint256_reverse_hex(self.contactBlockchainUserRegistrationTransactionHash),
                           @"extendedPublicKey" : [fundsDerivationPathForContact.extendedPublicKey base64EncodedStringWithOptions:0],
                           };
    
    
    DPDocument *contact = [dpp.documentFactory documentWithType:@"contact" data:data error:&error];
    NSAssert(error == nil, @"Failed to build a contact");
    return contact;
}


-(DSFriendRequestEntity*)outgoingFriendRequest {
    DSContactEntity * contactEntity = [DSContactEntity managedObject];
    
    [contactEntity setAttributesFromPotentialContact:self];
    
    DSFriendRequestEntity * friendRequestEntity = [DSFriendRequestEntity managedObject];
    friendRequestEntity.sourceContact = self.blockchainUserOwner.ownContact;
    friendRequestEntity.destinationContact = contactEntity;
    return friendRequestEntity;
}

-(DSFriendRequestEntity*)incomingFriendRequest {
    DSContactEntity * contactEntity = [DSContactEntity managedObject];
    
    [contactEntity setAttributesFromPotentialContact:self];
    
    DSFriendRequestEntity * friendRequestEntity = [DSFriendRequestEntity managedObject];
    friendRequestEntity.sourceContact = contactEntity;
    friendRequestEntity.destinationContact = self.blockchainUserOwner.ownContact;
    friendRequestEntity.extendedPublicKey = self.extendedPublicKey;
    return friendRequestEntity;
}

-(BOOL)isEqual:(id)object {
    if (self == object) {
        return TRUE;
    }
    
    if (![object isKindOfClass:[self class]]) {
        return FALSE;
    }
    
    if ([self.username isEqualToString:((DSPotentialContact*)object).username] &&
        self.account.accountNumber == ((DSPotentialContact*)object).account.accountNumber) {
        return TRUE;
    }
    
    return FALSE;
}

- (NSUInteger)hash {
    return self.username.hash ^ self.account.accountNumber;
}

@end
