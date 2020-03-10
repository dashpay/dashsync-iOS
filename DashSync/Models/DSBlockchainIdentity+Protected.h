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

#import "DSBlockchainIdentity.h"

NS_ASSUME_NONNULL_BEGIN

@class DSBlockchainIdentityEntity;

@interface DSBlockchainIdentity ()

/*! @brief This is a convenience factory to quickly make dashpay documents */
@property (nonatomic,readonly) DPDocumentFactory* dashpayDocumentFactory;

/*! @brief This is a convenience factory to quickly make dpns documents */
@property (nonatomic,readonly) DPDocumentFactory* dpnsDocumentFactory;

@property (nonatomic,readonly) NSArray<DPDocument*>* unregisteredUsernamesPreorderDocuments;
@property (nonatomic,readonly,nullable) DSDocumentTransition* unregisteredUsernamesPreorderTransition;

@property (nonatomic,readonly) DSBlockchainIdentityEntity* blockchainIdentityEntity;

-(instancetype)initWithType:(DSBlockchainIdentityType)type atIndex:(uint32_t)index inWallet:(DSWallet*)wallet inContext:(NSManagedObjectContext* _Nullable)managedObjectContext;

-(instancetype)initWithType:(DSBlockchainIdentityType)type atIndex:(uint32_t)index withLockedOutpoint:(DSUTXO)lockedOutpoint inWallet:(DSWallet*)wallet inContext:(NSManagedObjectContext* _Nullable)managedObjectContext;

-(instancetype)initWithType:(DSBlockchainIdentityType)type atIndex:(uint32_t)index withFundingTransaction:(DSCreditFundingTransaction*)transaction withUsernameDictionary:(NSDictionary <NSString *,NSDictionary *> * _Nullable)usernameDictionary inWallet:(DSWallet*)wallet inContext:(NSManagedObjectContext* _Nullable)managedObjectContext;

-(instancetype)initWithType:(DSBlockchainIdentityType)type atIndex:(uint32_t)index withFundingTransaction:(DSCreditFundingTransaction*)transaction withUsernameDictionary:(NSDictionary <NSString *,NSDictionary *> * _Nullable)usernameDictionary havingCredits:(uint64_t)credits registrationStatus:(DSBlockchainIdentityRegistrationStatus)registrationStatus inWallet:(DSWallet*)wallet inContext:(NSManagedObjectContext* _Nullable)managedObjectContext;

-(void)addKey:(DSKey*)key atIndex:(uint32_t)index ofType:(DSDerivationPathSigningAlgorith)type save:(BOOL)save;
-(void)addKey:(DSKey*)key atIndexPath:(NSIndexPath*)indexPath ofType:(DSDerivationPathSigningAlgorith)type save:(BOOL)save;
-(void)registerKeyIsActive:(BOOL)active atIndexPath:(NSIndexPath*)indexPath ofType:(DSDerivationPathSigningAlgorith)type;
-(DSKey*)privateKeyAtIndex:(uint32_t)index ofType:(DSDerivationPathSigningAlgorith)type;
-(void)deletePersistentObject;

@end

NS_ASSUME_NONNULL_END
