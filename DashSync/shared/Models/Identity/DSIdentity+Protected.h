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

#import "DSIdentity.h"
#import "DSDAPIClient.h"
#import "DSDAPIPlatformNetworkService.h"
#import "DSIdentitiesManager.h"
#import "DSTransientDashpayUser.h"

NS_ASSUME_NONNULL_BEGIN

@class DSBlockchainIdentityEntity;

@interface DSIdentity ()
@property (nonatomic, weak) DSWallet *wallet;

@property (nonatomic, readonly) DSBlockchainIdentityEntity *identityEntity;
@property (nullable, nonatomic, strong) DSTransientDashpayUser *transientDashpayUser;
@property (nonatomic, weak) DSInvitation *associatedInvitation;
@property (nonatomic, assign) DMaybeOpaqueKey *registrationFundingPrivateKey;
@property (nonatomic, assign) BOOL isLocal;
@property (nonatomic, assign) UInt256 registrationAssetLockTransactionHash;

@property (nonatomic, readonly) NSManagedObjectContext *platformContext;
@property (nonatomic, strong) dispatch_queue_t identityQueue;
@property (nonatomic, strong) DSChain *chain;
@property (nonatomic, readonly) DSDAPIClient *DAPIClient;
@property (nonatomic, readonly) DSDAPIPlatformNetworkService *DAPINetworkService;
@property (nonatomic, readonly) DSIdentitiesManager *identitiesManager;
@property (nonatomic, assign) DKeyKind *currentMainKeyType;
@property (nonatomic, assign) BOOL isTransient;

@property (nonatomic, assign) uint64_t lastCheckedIncomingContactsTimestamp;
@property (nonatomic, assign) uint64_t lastCheckedOutgoingContactsTimestamp;

- (BOOL)isDashpayReady;
- (void)saveProfileTimestamp;

- (DSBlockchainIdentityEntity *)identityEntityInContext:(NSManagedObjectContext *)context;

- (instancetype)initWithIdentityEntity:(DSBlockchainIdentityEntity *)entity;

//This one is called for a local identity that is being recreated from the network
- (instancetype)initAtIndex:(uint32_t)index
               withUniqueId:(UInt256)uniqueId
                   inWallet:(DSWallet *)wallet
         withIdentityEntity:(DSBlockchainIdentityEntity *)entity;

//This one is called from an identity that was created locally by creating a credit funding transaction
- (instancetype)initAtIndex:(uint32_t)index
         withLockedOutpoint:(DSUTXO)lockedOutpoint
                   inWallet:(DSWallet *)wallet
         withIdentityEntity:(DSBlockchainIdentityEntity *)entity;

- (instancetype)initAtIndex:(uint32_t)index
         withLockedOutpoint:(DSUTXO)lockedOutpoint
                   inWallet:(DSWallet *)wallet
         withIdentityEntity:(DSBlockchainIdentityEntity *)entity
     associatedToInvitation:(DSInvitation *)invitation;

- (instancetype)initWithUniqueId:(UInt256)uniqueId
                     isTransient:(BOOL)isTransient
                         onChain:(DSChain *)chain;

- (instancetype)initAtIndex:(uint32_t)index
                   inWallet:(DSWallet *)wallet;

- (instancetype)initAtIndex:(uint32_t)index
         withLockedOutpoint:(DSUTXO)lockedOutpoint
                   inWallet:(DSWallet *)wallet;

- (instancetype)initAtIndex:(uint32_t)index
               withUniqueId:(UInt256)uniqueId
                   inWallet:(DSWallet *)wallet;

//- (instancetype)initAtIndex:(uint32_t)index
//     withIdentityDictionary:(NSDictionary *)identityDictionary
//                    version:(uint32_t)version
//                   inWallet:(DSWallet *)wallet;
- (instancetype)initAtIndex:(uint32_t)index
                   uniqueId:(UInt256)uniqueId
//                    balance:(uint64_t)balance
//                public_keys:(std_collections_Map_keys_dpp_identity_identity_public_key_KeyID_values_dpp_identity_identity_public_key_IdentityPublicKey *)public_keys
                   inWallet:(DSWallet *)wallet;

- (instancetype)initAtIndex:(uint32_t)index
   withAssetLockTransaction:(DSAssetLockTransaction *)transaction
     withUsernameDictionary:(NSDictionary<NSString *, NSDictionary *> *_Nullable)usernameDictionary
                   inWallet:(DSWallet *)wallet;

- (instancetype)initAtIndex:(uint32_t)index
   withAssetLockTransaction:(DSAssetLockTransaction *)transaction
     withUsernameDictionary:(NSDictionary<NSString *, NSDictionary *> *_Nullable)usernameDictionary
              havingCredits:(uint64_t)credits
         registrationStatus:(DSIdentityRegistrationStatus)registrationStatus
                   inWallet:(DSWallet *)wallet;


- (void)addKey:(DMaybeOpaqueKey *)key
       atIndex:(uint32_t)index
        ofType:(DKeyKind *)type
    withStatus:(DSIdentityKeyStatus)status
          save:(BOOL)save;
- (void)addKey:(DMaybeOpaqueKey *)key
   atIndexPath:(NSIndexPath *)indexPath
        ofType:(DKeyKind *)type
    withStatus:(DSIdentityKeyStatus)status
          save:(BOOL)save;
- (BOOL)registerKeyWithStatus:(DSIdentityKeyStatus)status
                  atIndexPath:(NSIndexPath *)indexPath
                       ofType:(DKeyKind *)type;
- (DMaybeOpaqueKey *_Nullable)privateKeyAtIndex:(uint32_t)index
                                         ofType:(DKeyKind *)type;
- (DMaybeOpaqueKey *_Nullable)privateKeyAtIndex:(uint32_t)index
                                         ofType:(DKeyKind *)type
                                        forSeed:(NSData *)seed;
- (void)deletePersistentObjectAndSave:(BOOL)save
                            inContext:(NSManagedObjectContext *)context;

- (void)saveInitial;

- (void)saveInitialInContext:(NSManagedObjectContext *)context;

- (void)registerInWalletForIdentityUniqueId:(UInt256)identityUniqueId;

//- (void)registrationTransitionWithCompletion:(void (^_Nullable)(DSIdentityRegistrationTransition *_Nullable identityRegistrationTransition, NSError *_Nullable error))completion;

- (void)createFundingPrivateKeyWithSeed:(NSData *)seed
                        isForInvitation:(BOOL)isForInvitation
                             completion:(void (^_Nullable)(BOOL success))completion;


- (void)setInvitationUniqueId:(UInt256)uniqueId;

- (void)setInvitationAssetLockTransaction:(DSAssetLockTransaction *)transaction;

//-(void)topupTransitionForForFundingTransaction:(DSTransaction*)fundingTransaction completion:(void (^ _Nullable)(DSIdentityTopupTransition * identityTopupTransition))completion;
//
//-(void)updateTransitionUsingNewIndex:(uint32_t)index completion:(void (^ _Nullable)(DSIdentityUpdateTransition * identityUpdateTransition))completion;

- (void)fetchIfNeededNetworkStateInformation:(DSIdentityQueryStep)querySteps
                                   inContext:(NSManagedObjectContext *)context
                              withCompletion:(void (^)(DSIdentityQueryStep failureStep, NSArray<NSError *> *errors))completion
                           onCompletionQueue:(dispatch_queue_t)completionQueue;

- (void)fetchNeededNetworkStateInformationInContext:(NSManagedObjectContext *)context
                                     withCompletion:(void (^)(DSIdentityQueryStep failureStep, NSArray<NSError *> *errors))completion
                                  onCompletionQueue:(dispatch_queue_t)completionQueue;
- (void)saveInContext:(NSManagedObjectContext *)context;
- (void)applyIdentityDictionary:(NSDictionary *)identityDictionary
                        version:(uint32_t)version
                           save:(BOOL)save
                      inContext:(NSManagedObjectContext *_Nullable)context;
- (void)applyIdentity:(dpp_identity_identity_Identity *)identity
                 save:(BOOL)save
            inContext:(NSManagedObjectContext *_Nullable)context;
- (uint32_t)firstIndexOfKeyOfType:(DKeyKind *)type
               createIfNotPresent:(BOOL)createIfNotPresent
                          saveKey:(BOOL)saveKey;

@end

NS_ASSUME_NONNULL_END
