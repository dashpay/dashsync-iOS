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

#import "DSContact.h"
#import "DSAccount.h"
#import "DSWallet.h"
#import "DSDerivationPathFactory.h"
#import "DSFundsDerivationPath.h"
#import "DashPlatformProtocol+DashSync.h"

@interface DSContact()

@property (nonatomic, weak) DSAccount* account;
@property (nonatomic, weak) DSBlockchainUser * blockchainUserOwner;
@property (nonatomic, copy) NSString * username;
@property (nonatomic, strong) NSMutableSet <DSContact *> *mOutgoingFriendRequests;
@property (nonatomic, strong) NSMutableSet <DSContact *> *mIncomingFriendRequests;

@end

@implementation DSContact

-(instancetype)initWithUsername:(NSString*)username blockchainUserOwner:(DSBlockchainUser*)blockchainUserOwner account:(DSAccount*)account {
    if (!(self = [super init])) return nil;
    self.username = username;
    self.account = account;
    self.blockchainUserOwner = blockchainUserOwner;
    self.contactBlockchainUserRegistrationTransactionHash = UINT256_ZERO;
    self.mOutgoingFriendRequests = [NSMutableSet set];
    self.mIncomingFriendRequests = [NSMutableSet set];
    return self;
}

-(void)addIncomingContactRequestFromSender:(DSContact *)sender {
    [self.mIncomingFriendRequests addObject:sender];
}

-(void)addOutgoingContactRequestToRecipient:(DSContact *)recipient {
    [self.mOutgoingFriendRequests addObject:recipient];
}

-(NSArray*)outgoingFriendRequests {
    return [self.mOutgoingFriendRequests allObjects];
}

-(NSArray*)incomingFriendRequests {
    return [self.mIncomingFriendRequests allObjects];
}

-(NSArray <DSContact *> *)friends {
    NSMutableSet * friendSet = [self.mOutgoingFriendRequests mutableCopy];
    [friendSet intersectSet:self.mIncomingFriendRequests];
    return [friendSet allObjects];
}

-(DPDocument*)contactRequestDocument {
    NSAssert(!uint256_is_zero(self.contactBlockchainUserRegistrationTransactionHash), @"the contactBlockchainUserRegistrationTransactionHash must be set before making a friend request");
    DashPlatformProtocol *dpp = [DashPlatformProtocol sharedInstance];
    
    DSFundsDerivationPath * fundsDerivationPathForContact = [DSFundsDerivationPath
                                                             contactBasedDerivationPathForContact:self onChain:self.account.wallet.chain];
    NSError *error = nil;
    DPJSONObject *data = @{
                           @"toUserId" : uint256_hex(self.contactBlockchainUserRegistrationTransactionHash),
                           @"extendedPublicKey" : fundsDerivationPathForContact.extendedPublicKey,
                           };
    
    
    DPDocument *contact = [dpp.documentFactory documentWithType:@"contact" data:data error:&error];
    NSAssert(error == nil, @"Failed to build a contact");
    return contact;
}

-(BOOL)isEqual:(id)object {
    if ([super isEqual:object]) return TRUE;
    if (![object isMemberOfClass:[DSContact class]]) return FALSE;
    if ([self.username isEqualToString:((DSContact*)object).username] && self.account.accountNumber == ((DSContact*)object).account.accountNumber) return TRUE;
    return FALSE;
}

@end
