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
#import "DSIdentitiesManager.h"
#import "DSTransientDashpayUser.h"

NS_ASSUME_NONNULL_BEGIN

@class DSBlockchainIdentityEntity;

@interface DSIdentity ()
@property (nonatomic, weak) DSWallet *wallet;

@property (nonatomic, readonly) DSBlockchainIdentityEntity *identityEntity;
@property (nullable, nonatomic) DTransientUser *transientDashpayUser;
@property (nonatomic, weak) DSInvitation *associatedInvitation;
@property (nonatomic, assign) DMaybeOpaqueKey *registrationFundingPrivateKey;
@property (nonatomic, assign) UInt256 registrationAssetLockTransactionHash;

@property (nonatomic, readonly) NSManagedObjectContext *platformContext;
@property (nonatomic, strong) dispatch_queue_t identityQueue;
@property (nonatomic, strong) DSChain *chain;
@property (nonatomic, readonly) DSIdentitiesManager *identitiesManager;
@property (nonatomic, assign) DKeyKind *currentMainKeyType;
@property (nonatomic, assign) uint32_t currentMainKeyIndex;
@property (nonatomic, readonly) uint32_t keysCreated;

@property (nonatomic, assign) IdentityModel *model;

- (BOOL)isDashpayReady;
- (void)saveProfileTimestamp;

- (DSBlockchainIdentityEntity *)identityEntityInContext:(NSManagedObjectContext *)context;

- (instancetype)initWithIdentityEntity:(DSBlockchainIdentityEntity *)entity;

- (instancetype)initWithModel:(IdentityModel *)model
                      onChain:(DSChain *)chain;

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

//- (instancetype)initAtIndex:(uint32_t)index
//               withUniqueId:(UInt256)uniqueId
//                   inWallet:(DSWallet *)wallet;

- (instancetype)initAtIndex:(uint32_t)index
                   uniqueId:(UInt256)uniqueId
                   inWallet:(DSWallet *)wallet;
- (instancetype)initAtIndex:(uint32_t)index
   withAssetLockTransaction:(DSAssetLockTransaction *)transaction
                   inWallet:(DSWallet *)wallet;

- (DIdentityPublicKey *_Nullable)firstIdentityPublicKeyOfSecurityLevel:(DSecurityLevel *)security_level
                                                            andPurpose:(DPurpose *)purpose;
- (DMaybeOpaqueKey *_Nullable)publicKeyAtIndex:(uint32_t)index
                                        ofType:(DKeyKind *)type;

- (DMaybeOpaqueKey *_Nullable)privateKeyAtIndex:(uint32_t)index
                                         ofType:(DKeyKind *)type;
- (void)deletePersistentObjectAndSave:(BOOL)save
                            inContext:(NSManagedObjectContext *)context;

- (void)saveInitial;

- (void)saveInitialInContext:(NSManagedObjectContext *)context;

- (void)registerInWalletForIdentityUniqueId:(UInt256)identityUniqueId;

- (BOOL)createFundingPrivateKeyWithSeed:(NSData *)seed
                        isForInvitation:(BOOL)isForInvitation;


- (void)setInvitationUniqueId:(UInt256)uniqueId;

- (void)setInvitationAssetLockTransaction:(DSAssetLockTransaction *)transaction;

- (void)fetchIfNeededNetworkStateInformation:(DSIdentityQueryStep)querySteps
                                   inContext:(NSManagedObjectContext *)context
                              withCompletion:(void (^)(DSIdentityQueryStep failureStep, NSArray<NSError *> *errors))completion
                           onCompletionQueue:(dispatch_queue_t)completionQueue;

- (void)fetchNeededNetworkStateInformationInContext:(NSManagedObjectContext *)context
                                     withCompletion:(void (^)(DSIdentityQueryStep failureStep, NSArray<NSError *> *errors))completion
                                  onCompletionQueue:(dispatch_queue_t)completionQueue;
- (void)saveInContext:(NSManagedObjectContext *)context;
- (void)applyIdentity:(DIdentity *)identity
                 save:(BOOL)save
            inContext:(NSManagedObjectContext *_Nullable)context;
- (uint32_t)firstIndexOfKeyOfType:(DKeyKind *)type
               createIfNotPresent:(BOOL)createIfNotPresent
                          saveKey:(BOOL)saveKey;

- (DAssetLockProof *)createProof:(DSInstantSendTransactionLock *_Nullable)isLock;

- (UInt256)contractIdIfRegistered:(DDataContract *)contract;

- (DSAuthenticationKeysDerivationPath *)derivationPathForType:(DKeyKind *)type;
- (BOOL)createNewKey:(DOpaqueKey *)key
   forIdentityEntity:(DSBlockchainIdentityEntity *)identityEntity
              atPath:(NSIndexPath *)path
          withStatus:(DIdentityKeyStatus *)status
          withSecurityLevel:(DSecurityLevel *)security_level
          withPurpose:(DPurpose *)purpose
  fromDerivationPath:(DSDerivationPath *)derivationPath
           inContext:(NSManagedObjectContext *)context;
- (BOOL)saveNewKeyForCurrentEntity:(DOpaqueKey *)key
              atPath:(NSIndexPath *)path
          withStatus:(DIdentityKeyStatus *)status
          withSecurityLevel:(DSecurityLevel *)security_level
          withPurpose:(DPurpose *)purpose
  fromDerivationPath:(DSDerivationPath *)derivationPath
                           inContext:(NSManagedObjectContext *)context;


@end

NS_ASSUME_NONNULL_END
