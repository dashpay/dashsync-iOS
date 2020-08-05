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

@property (nonatomic,readonly) DSBlockchainIdentityEntity* blockchainIdentityEntity;

-(DSBlockchainIdentityEntity*)blockchainIdentityEntityInContext:(NSManagedObjectContext*)context;

-(instancetype)initWithBlockchainIdentityEntity:(DSBlockchainIdentityEntity*)blockchainIdentityEntity;

-(instancetype)initAtIndex:(uint32_t)index withLockedOutpoint:(DSUTXO)lockedOutpoint inWallet:(DSWallet*)wallet withBlockchainIdentityEntity:(DSBlockchainIdentityEntity*)blockchainIdentityEntity;

-(instancetype)initWithUniqueId:(UInt256)uniqueId isTransient:(BOOL)isTransient onChain:(DSChain*)chain;

-(instancetype)initAtIndex:(uint32_t)index inWallet:(DSWallet*)wallet;

-(instancetype)initAtIndex:(uint32_t)index withLockedOutpoint:(DSUTXO)lockedOutpoint inWallet:(DSWallet*)wallet;

-(instancetype)initAtIndex:(uint32_t)index withFundingTransaction:(DSCreditFundingTransaction*)transaction withUsernameDictionary:(NSDictionary <NSString *,NSDictionary *> * _Nullable)usernameDictionary inWallet:(DSWallet*)wallet;

-(instancetype)initAtIndex:(uint32_t)index withFundingTransaction:(DSCreditFundingTransaction*)transaction withUsernameDictionary:(NSDictionary <NSString *,NSDictionary *> * _Nullable)usernameDictionary havingCredits:(uint64_t)credits registrationStatus:(DSBlockchainIdentityRegistrationStatus)registrationStatus inWallet:(DSWallet*)wallet;

-(void)addUsername:(NSString*)username inDomain:(NSString*)domain status:(DSBlockchainIdentityUsernameStatus)status save:(BOOL)save registerOnNetwork:(BOOL)registerOnNetwork;

-(void)addKey:(DSKey*)key atIndex:(uint32_t)index ofType:(DSKeyType)type withStatus:(DSBlockchainIdentityKeyStatus)status save:(BOOL)save;
-(void)addKey:(DSKey*)key atIndexPath:(NSIndexPath*)indexPath ofType:(DSKeyType)type withStatus:(DSBlockchainIdentityKeyStatus)status save:(BOOL)save;
-(BOOL)registerKeyWithStatus:(DSBlockchainIdentityKeyStatus)status atIndexPath:(NSIndexPath*)indexPath ofType:(DSKeyType)type;
-(DSKey* _Nullable)privateKeyAtIndex:(uint32_t)index ofType:(DSKeyType)type;
-(void)deletePersistentObjectAndSave:(BOOL)save inContext:(NSManagedObjectContext*)context;


-(void)saveInitial;

-(void)saveInitialInContext:(NSManagedObjectContext*)context;

-(void)registerInWalletForBlockchainIdentityUniqueId:(UInt256)blockchainIdentityUniqueId;

-(void)registrationTransitionWithCompletion:(void (^ _Nullable)(DSBlockchainIdentityRegistrationTransition * _Nullable blockchainIdentityRegistrationTransition, NSError * _Nullable error))completion;

-(void)createFundingPrivateKeyWithSeed:(NSData*)seed completion:(void (^ _Nullable)(BOOL success))completion;

//-(void)topupTransitionForForFundingTransaction:(DSTransaction*)fundingTransaction completion:(void (^ _Nullable)(DSBlockchainIdentityTopupTransition * blockchainIdentityTopupTransition))completion;
//
//-(void)updateTransitionUsingNewIndex:(uint32_t)index completion:(void (^ _Nullable)(DSBlockchainIdentityUpdateTransition * blockchainIdentityUpdateTransition))completion;

@end

NS_ASSUME_NONNULL_END
