//
//  DSContactEntity+CoreDataClass.m
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


#import "DSContactEntity+CoreDataClass.h"
#import "DSAccount.h"
#import "DSWallet.h"
#import "DSDerivationPathFactory.h"
#import "DSFundsDerivationPath.h"
#import "DashPlatformProtocol+DashSync.h"
#import "NSData+Bitcoin.h"
#import "DSPotentialContact.h"
#import "DSAccountEntity+CoreDataClass.h"
#import "DSBlockchainUserRegistrationTransactionEntity+CoreDataClass.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSChainManager.h"
#import "DSIncomingFundsDerivationPath.h"

@implementation DSContactEntity

@synthesize blockchainUserOwner;

- (instancetype)setAttributesFromPotentialContact:(DSPotentialContact *)potentialContact {
    [self.managedObjectContext performBlockAndWait:^{
        self.username = potentialContact.username;
        self.account = [DSAccountEntity accountEntityForWalletUniqueID:potentialContact.account.wallet.uniqueID index:potentialContact.account.accountNumber];
    }];
    
    return self;
}



-(DPDocument*)contactRequestDocumentForWallet:(DSWallet*)wallet {
    NSAssert(!uint256_is_zero(self.blockchainUserRegistrationHash.UInt256), @"the contactBlockchainUserRegistrationTransactionHash must be set before making a friend request");
    DashPlatformProtocol * dpp = [DashPlatformProtocol sharedInstance];
    
    DSIncomingFundsDerivationPath * fundsDerivationPathForContact = [DSIncomingFundsDerivationPath
                                                             contactBasedDerivationPathForBlockchainUserRegistrationTransactionHash:self.blockchainUserRegistrationHash.UInt256 forAccountNumber:self.account.index onChain:self.ownerBlockchainUserRegistrationTransaction.chain.chain];
    DSAccount * account = [wallet accountWithNumber:self.account.index];
    DSDerivationPath * masterContactsDerivationPath = [account masterContactsDerivationPath];
    
    [fundsDerivationPathForContact generateExtendedPublicKeyFromParentDerivationPath:masterContactsDerivationPath storeUnderWalletUniqueId:nil];
    //DSBLSKey * key = [DSBLSKey blsKeyWithPublicKey:self.contactEncryptionPublicKey onChain:self.blockchainUserOwner.wallet.chain];
    
    NSAssert(fundsDerivationPathForContact.extendedPublicKey, @"Problem creating extended public key for potential contact?");
    NSError *error = nil;
    DPJSONObject *data = @{
                           @"toUserId" : self.blockchainUserRegistrationHash.reverse,
                           @"publicKey" : [fundsDerivationPathForContact.extendedPublicKey base64EncodedStringWithOptions:0],
                           };
    
    
    DPDocument *contact = [dpp.documentFactory documentWithType:@"contact" data:data error:&error];
    NSAssert(error == nil, @"Failed to build a contact");
    return contact;
}


-(void)storeExtendedPublicKeyInWallet:(DSWallet*)wallet {
    DSIncomingFundsDerivationPath * fundsDerivationPathForContact = [DSIncomingFundsDerivationPath
                                                             contactBasedDerivationPathForBlockchainUserRegistrationTransactionHash:self.blockchainUserRegistrationHash.UInt256 forAccountNumber:self.account.index onChain:self.ownerBlockchainUserRegistrationTransaction.chain.chain];
    DSAccount * account =[wallet accountWithNumber:self.account.index];
    DSDerivationPath * masterContactsDerivationPath = [account masterContactsDerivationPath];
    
    [fundsDerivationPathForContact generateExtendedPublicKeyFromParentDerivationPath:masterContactsDerivationPath storeUnderWalletUniqueId:wallet.uniqueID];
}

@end
