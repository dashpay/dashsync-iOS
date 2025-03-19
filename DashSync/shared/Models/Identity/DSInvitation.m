//
//  Created by Samuel Westrich
//  Copyright © 2564 Dash Core Group. All rights reserved.
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

#import "DSInvitation.h"
#import "DSAuthenticationManager.h"
#import "DSIdentity+Profile.h"
#import "DSIdentity+Protected.h"
#import "DSIdentity+Username.h"
#import "DSBlockchainInvitationEntity+CoreDataClass.h"
#import "DSChain+Params.h"
#import "DSChainManager.h"
#import "DSAssetLockDerivationPath.h"
#import "DSDerivationPathFactory.h"
#import "DSIdentitiesManager+Protected.h"
#import "DSInstantSendTransactionLock.h"
#import "DSWallet.h"
#import "DSWallet+Identity.h"
#import "DSWallet+Invitation.h"
#import "NSData+DSHash.h"
#import "NSError+Dash.h"
#import "NSError+Platform.h"
#import "NSManagedObject+Sugar.h"
#import "NSManagedObjectContext+DSSugar.h"
#import "NSString+Dash.h"

#define ERROR_INVITATION_FORMAT [NSError errorWithCode:400 localizedDescriptionKey:@"Invitation format is not valid"]
#define ERROR_SETTING_EXT_PRV_KEY [NSError errorWithCode:500 localizedDescriptionKey:@"Error setting the external funding private key"]
#define ERROR_GEN_IDENTITY_KEYS [NSError errorWithCode:500 localizedDescriptionKey:@"Error generating Identity keys"]
#define ERROR_INVALID_FUNDING_PRV_KEY [NSError errorWithCode:400 localizedDescriptionKey:@"Funding private key is not valid"]
#define ERROR_INVALID_INV_TX [NSError errorWithCode:400 localizedDescriptionKey:@"Invitation transaction is not valid"]

@interface DSInvitation ()

@property (nonatomic, weak) DSWallet *wallet;
@property (nonatomic, strong) DSChain *chain;
@property (nonatomic, copy) NSString *link;
@property (nonatomic, strong) DSIdentity *identity;
@property (nonatomic, assign) BOOL isTransient;
@property (nonatomic, assign) BOOL needsIdentityRetrieval;
@property (nonatomic, assign) BOOL createdLocally;

@end

@implementation DSInvitation

- (instancetype)initAtIndex:(uint32_t)index
                   inWallet:(DSWallet *)wallet {
    //this is the creation of a new blockchain identity
    NSParameterAssert(wallet);

    if (!(self = [super init])) return nil;
    self.wallet = wallet;
    self.isTransient = FALSE;
    self.createdLocally = YES;
    self.identity = [[DSIdentity alloc] initAtIndex:index inWallet:wallet];
    [self.identity setAssociatedInvitation:self];
    self.chain = wallet.chain;
    self.needsIdentityRetrieval = NO;
    return self;
}

- (instancetype)initAtIndex:(uint32_t)index
   withAssetLockTransaction:(DSAssetLockTransaction *)transaction
                   inWallet:(DSWallet *)wallet {
    NSParameterAssert(wallet);
    NSAssert(index != UINT32_MAX, @"index must be found");
    if (!(self = [super init])) return nil;
    self.wallet = wallet;
    self.isTransient = FALSE;
    self.createdLocally = YES;
    self.identity = [[DSIdentity alloc] initAtIndex:index withAssetLockTransaction:transaction inWallet:wallet];
    [self.identity setAssociatedInvitation:self];
    self.chain = wallet.chain;
    self.needsIdentityRetrieval = NO;
    return self;
}

- (instancetype)initAtIndex:(uint32_t)index
         withLockedOutpoint:(DSUTXO)lockedOutpoint
                   inWallet:(DSWallet *)wallet {
    NSParameterAssert(wallet);
    NSAssert(index != UINT32_MAX, @"index must be found");
    if (!(self = [super init])) return nil;
    self.wallet = wallet;
    self.isTransient = FALSE;
    self.createdLocally = YES;
    self.identity = [[DSIdentity alloc] initAtIndex:index withLockedOutpoint:lockedOutpoint inWallet:wallet];
    [self.identity setAssociatedInvitation:self];
    self.chain = wallet.chain;
    self.needsIdentityRetrieval = NO;
    return self;
}

- (instancetype)initAtIndex:(uint32_t)index
         withLockedOutpoint:(DSUTXO)lockedOutpoint
                   inWallet:(DSWallet *)wallet
       withInvitationEntity:(DSBlockchainInvitationEntity *)invitationEntity {
    if (!(self = [super init])) return nil;
    self.wallet = wallet;
    self.isTransient = FALSE;
    self.createdLocally = YES;
    self.identity = [[DSIdentity alloc] initAtIndex:index withLockedOutpoint:lockedOutpoint inWallet:wallet withIdentityEntity:invitationEntity.blockchainIdentity associatedToInvitation:self];
    self.link = invitationEntity.link;
    self.name = invitationEntity.name;
    self.tag = invitationEntity.tag;
    self.chain = wallet.chain;
    self.needsIdentityRetrieval = NO;
    return self;
}

- (instancetype)initWithInvitationLink:(NSString *)invitationLink
                              inWallet:(DSWallet *)wallet {
    if (!(self = [super init])) return nil;
    self.link = invitationLink;
    self.wallet = wallet;
    self.chain = wallet.chain;
    self.needsIdentityRetrieval = YES;
    self.createdLocally = NO;
    return self;
}

- (void)generateInvitationsExtendedPublicKeysWithPrompt:(NSString *)prompt
                                             completion:(void (^_Nullable)(BOOL registered))completion {
    __block DSAssetLockDerivationPath *derivationPathInvitationFunding = [[DSDerivationPathFactory sharedInstance] identityInvitationFundingDerivationPathForWallet:self.wallet];
    if ([derivationPathInvitationFunding hasExtendedPublicKey]) {
        completion(YES);
        return;
    }
    [[DSAuthenticationManager sharedInstance] seedWithPrompt:prompt
                                                   forWallet:self.wallet
                                                   forAmount:0
                                         forceAuthentication:NO
                                                  completion:^(NSData *_Nullable seed, BOOL cancelled) {
        if (!seed) {
            completion(NO);
            return;
        }
        [derivationPathInvitationFunding generateExtendedPublicKeyFromSeed:seed
                                                  storeUnderWalletUniqueId:self.wallet.uniqueIDString];
        completion(YES);
    }];
}

- (void)registerInWalletForAssetLockTransaction:(DSAssetLockTransaction *)transaction {
    NSAssert(self.identity != nil, @"The identity must already exist");
    [self.identity setInvitationAssetLockTransaction:transaction];
    [self registerInWalletForIdentityUniqueId:transaction.creditBurnIdentityIdentifier];
    //we need to also set the address of the funding transaction to being used so future identities past the initial gap limit are found
    [transaction markInvitationAddressAsUsedInWallet:self.wallet];
}

- (void)registerInWalletForIdentityUniqueId:(UInt256)identityUniqueId {
    [self.identity setInvitationUniqueId:identityUniqueId];
    [self registerInWallet];
}

- (BOOL)isRegisteredInWallet {
    if (!self.wallet) return FALSE;
    return [self.wallet containsInvitation:self];
}

- (void)registerInWallet {
    NSAssert(self.identity.isOutgoingInvitation, @"The underlying identity is not from an invitation");
    if (!self.identity.isOutgoingInvitation) return;
    [self.wallet registerInvitation:self];
    [self.identity saveInitial];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DSInvitationDidUpdateNotification
                                                            object:nil
                                                          userInfo:@{
            DSChainManagerNotificationChainKey: self.chain,
            DSInvitationKey: self
        }];
    });
}

- (void)updateInWallet {
    [self saveInContext:[NSManagedObjectContext platformContext]];
}

- (BOOL)unregisterLocally {
    NSAssert(self.identity.isOutgoingInvitation, @"The underlying identity is not from an invitation");
    if (!self.identity.isOutgoingInvitation) return FALSE;
    if (self.identity.isRegistered) return FALSE; //if the invitation has already been used we can not unregister it
    [self.wallet unregisterInvitation:self];
    [self deletePersistentObjectAndSave:YES inContext:[NSManagedObjectContext platformContext]];
    return TRUE;
}

//- (void)verifyInvitationLinkWithCompletion:(void (^_Nullable)(DSTransaction *transaction, bool spent, NSError *error))completion
- (void)verifyInvitationLinkWithCompletion:(void (^_Nullable)(Result_ok_dashcore_blockdata_transaction_Transaction_err_dash_spv_platform_error_Error *result))completion
                           completionQueue:(dispatch_queue_t)completionQueue {
    [DSInvitation verifyInvitationLink:self.link
                               onChain:self.wallet.chain
                            completion:completion
                       completionQueue:completionQueue];
}

+ (void)verifyInvitationLink:(NSString *)invitationLink
                     onChain:(DSChain *)chain
                  completion:(void (^_Nullable)(Result_ok_dashcore_blockdata_transaction_Transaction_err_dash_spv_platform_error_Error *result))completion
//                  completion:(void (^_Nullable)(DSTransaction *transaction, bool spent, NSError *error))completion
             completionQueue:(dispatch_queue_t)completionQueue {
//    DSDAPICoreNetworkService *coreNetworkService = chain.chainManager.DAPIClient.DAPICoreNetworkService;
    NSURLComponents *components = [NSURLComponents componentsWithString:invitationLink];
    NSArray *queryItems = components.queryItems;
    UInt256 assetLockTransactionHash = UINT256_ZERO;
    BOOL isEmptyFundingPrivateKey = true;
    for (NSURLQueryItem *queryItem in queryItems) {
        if ([queryItem.name isEqualToString:@"assetlocktx"]) {
            assetLockTransactionHash = queryItem.value.hexToData.UInt256;
        } else if ([queryItem.name isEqualToString:@"pk"]) {
//            isEmptyFundingPrivateKey = key_ecdsa_secret_key_is_empty(DChar(queryItem.value), chain.chainType);
            isEmptyFundingPrivateKey = DECDSAKeyContainsSecretKey(DChar(queryItem.value), chain.chainType);
        }
    }
    if (uint256_is_zero(assetLockTransactionHash)) {
        if (completion) completion(nil);
//        if (completion) completion(nil, NO, ERROR_INVITATION_FORMAT);
        return;
    }
    if (isEmptyFundingPrivateKey) {
        if (completion) completion(nil);
        return;
    }
    
    Result_ok_dashcore_blockdata_transaction_Transaction_err_dash_spv_platform_error_Error *result = dash_spv_platform_PlatformSDK_get_transaction_with_hash(chain.sharedRuntime, chain.sharedPlatformObj, u256_ctor_u(assetLockTransactionHash));

    dispatch_async(completionQueue, ^{
        if (completion) completion(result);
//        if (result->error) {
//            Result_ok_dashcore_blockdata_transaction_Transaction_err_dash_spv_platform_error_Error_destroy(result);
//            if (completion) completion(nil, NO, ERROR_INVITATION_FORMAT);
//            return;
//        }
//        if (!result->ok) {
//            Result_ok_dashcore_blockdata_transaction_Transaction_err_dash_spv_platform_error_Error_destroy(result);
//            if (completion) completion(nil, NO, ERROR_INVALID_INV_TX);
//            return;
//        }
//        [DSAssetLockTransaction ffi]
//        if (completion) completion(tra)
    });
    
//    [coreNetworkService getTransactionWithHash:assetLockTransactionHash
//        completionQueue:completionQueue
//        success:^(DSTransaction *_Nonnull transaction) {
//            NSAssert(transaction, @"transaction must not be null");
//        if (!transaction || ![transaction isKindOfClass:[DSAssetLockTransaction class]]) {
//                if (completion) completion(nil, NO, ERROR_INVALID_INV_TX);
//                return;
//            }
//            if (completion) completion(transaction, NO, nil);
//        }
//        failure:^(NSError *_Nonnull error) {
//            if (completion) completion(nil, NO, ERROR_INVITATION_FORMAT);
//        }];
}

- (void)acceptInvitationUsingWalletIndex:(uint32_t)index
                      setDashpayUsername:(NSString *)dashpayUsername
                    authenticationPrompt:(NSString *)authenticationMessage
               identityRegistrationSteps:(DSIdentityRegistrationStep)identityRegistrationSteps
                          stepCompletion:(void (^_Nullable)(DSIdentityRegistrationStep stepCompleted))stepCompletion
                              completion:(void (^_Nullable)(DSIdentityRegistrationStep stepsCompleted, NSArray<NSError *> *errors))completion
                         completionQueue:(dispatch_queue_t)completionQueue {
//    DSDAPICoreNetworkService *coreNetworkService = self.chain.chainManager.DAPIClient.DAPICoreNetworkService;
    NSURLComponents *components = [NSURLComponents componentsWithString:self.link];
    NSArray *queryItems = components.queryItems;
    UInt256 assetLockTransactionHash = UINT256_ZERO;
    DMaybeOpaqueKey *fundingPrivateKey = nil;
    for (NSURLQueryItem *queryItem in queryItems) {
        if ([queryItem.name isEqualToString:@"assetlocktx"]) {
            assetLockTransactionHash = queryItem.value.hexToData.UInt256;
        } else if ([queryItem.name isEqualToString:@"pk"]) {
            fundingPrivateKey = DMaybeOpaqueKeyWithPrivateKey(DKeyKindECDSA(), DChar(queryItem.value), self.chain.chainType);
        }
    }
    if (uint256_is_zero(assetLockTransactionHash)) {
        if (completion) completion(DSIdentityRegistrationStep_None, @[ERROR_INVITATION_FORMAT]);
        return;
    }
    if (!fundingPrivateKey || !DOpaqueKeyHasPrivateKey(fundingPrivateKey->ok)) {
        if (completion) completion(DSIdentityRegistrationStep_None, @[ERROR_INVALID_FUNDING_PRV_KEY]);
        return;
    }
    
    Result_ok_dashcore_blockdata_transaction_Transaction_err_dash_spv_platform_error_Error *result = dash_spv_platform_PlatformSDK_get_transaction_with_hash(self.chain.sharedRuntime, self.chain.sharedPlatformObj, u256_ctor_u(assetLockTransactionHash));
    dispatch_async(self.chain.chainManager.identitiesManager.identityQueue, ^{
        if (result->error) {
            NSError *error = [NSError ffi_from_platform_error:result->error];
            Result_ok_dashcore_blockdata_transaction_Transaction_err_dash_spv_platform_error_Error_destroy(result);
            if (completion) completion(DSIdentityRegistrationStep_None, @[error]);
            return;
        }
        DSAssetLockTransaction *tx = [DSAssetLockTransaction ffi_from:result->ok onChain:self.chain];
        Result_ok_dashcore_blockdata_transaction_Transaction_err_dash_spv_platform_error_Error_destroy(result);

        self.identity = [[DSIdentity alloc] initAtIndex:index
                               withAssetLockTransaction:tx
                                               inWallet:self.wallet];
        [self.identity setAssociatedInvitation:self];
        [self.identity addDashpayUsername:dashpayUsername save:NO];
        [self.identity registerInWalletForAssetLockTransaction:tx];
        BOOL success = [self.identity setExternalFundingPrivateKey:fundingPrivateKey];
        if (!success && fundingPrivateKey != NULL)
            DMaybeOpaqueKeyDtor(fundingPrivateKey);

        NSAssert(success, @"We must be able to set the external funding private key");
        if (success) {
            [self.identity generateIdentityExtendedPublicKeysWithPrompt:authenticationMessage
                                                             completion:^(BOOL registered) {
                if (registered) {
                    [self.identity continueRegisteringIdentityOnNetwork:identityRegistrationSteps
                                                         stepsCompleted:DSIdentityRegistrationStep_L1Steps
                                                         stepCompletion:stepCompletion
                                                             completion:completion];
                } else if (completion) {
                    completion(DSIdentityRegistrationStep_None, @[ERROR_GEN_IDENTITY_KEYS]);
                }
            }];
        } else if (completion) {
            completion(DSIdentityRegistrationStep_None, @[ERROR_SETTING_EXT_PRV_KEY]);
        }
        
//                                       failure:^(NSError *_Nonnull error) {
//            if (completion) completion(DSIdentityRegistrationStep_None, ERROR_INVITATION_FORMAT);

    });
//    [coreNetworkService getTransactionWithHash:assetLockTransactionHash
//                               completionQueue:self.chain.chainManager.identitiesManager.identityQueue
//                                       success:^(DSTransaction *_Nonnull transaction) {
//        NSAssert(transaction, @"transaction must not be null");
//        if (!transaction || ![transaction isKindOfClass:[DSAssetLockTransaction class]]) {
//            if (completion) completion(DSIdentityRegistrationStep_None, ERROR_INVALID_INV_TX);
//            return;
//        }
//        self.identity = [[DSIdentity alloc] initAtIndex:index
//                               withAssetLockTransaction:(DSAssetLockTransaction *)transaction
//                                 withUsernameDictionary:nil
//                                               inWallet:self.wallet];
//        [self.identity setAssociatedInvitation:self];
//        [self.identity addDashpayUsername:dashpayUsername save:NO];
//        [self.identity registerInWalletForAssetLockTransaction: (DSAssetLockTransaction *)transaction];
//            BOOL success = [self.identity setExternalFundingPrivateKey:fundingPrivateKey];
//            if (!success && fundingPrivateKey != NULL)
//                DMaybeOpaqueKeyDtor(fundingPrivateKey);
//
//            NSAssert(success, @"We must be able to set the external funding private key");
//            if (success) {
//                [self.identity generateIdentityExtendedPublicKeysWithPrompt:authenticationMessage
//                                                                 completion:^(BOOL registered) {
//                    if (registered) {
//                        [self.identity continueRegisteringIdentityOnNetwork:identityRegistrationSteps
//                                                             stepsCompleted:DSIdentityRegistrationStep_L1Steps
//                                                             stepCompletion:stepCompletion
//                                                                 completion:completion];
//                    } else if (completion) {
//                        completion(DSIdentityRegistrationStep_None, ERROR_GEN_IDENTITY_KEYS);
//                    }
//                }];
//            } else if (completion) {
//                completion(DSIdentityRegistrationStep_None, ERROR_SETTING_EXT_PRV_KEY);
//            }
//        }
//                                       failure:^(NSError *_Nonnull error) {
//            if (completion) completion(DSIdentityRegistrationStep_None, ERROR_INVITATION_FORMAT);
//        }];
}

- (void)createInvitationFullLinkFromIdentity:(DSIdentity *)identity
                                  completion:(void (^_Nullable)(BOOL cancelled, NSString *invitationFullLink))completion {
    if (!self.identity.registrationAssetLockTransaction.instantSendLockAwaitingProcessing) {
        if (completion) completion(NO, nil);
        return;
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *senderUsername = identity.currentDashpayUsername;
        NSString *senderDisplayName = identity.displayName;
        NSString *senderAvatarPath = identity.avatarPath;
        NSString *fundingTransactionHexString = uint256_reverse_hex(self.identity.registrationAssetLockTransaction.txHash);
        __block DMaybeOpaqueKey *registrationFundingPrivateKey = self.identity.registrationFundingPrivateKey;
        __block BOOL rCancelled = FALSE;

        if (!registrationFundingPrivateKey) {
            dispatch_semaphore_t sem = dispatch_semaphore_create(0);
            dispatch_async(dispatch_get_main_queue(), ^{
                [[DSAuthenticationManager sharedInstance] seedWithPrompt:DSLocalizedString(@"Would you like to share this invitation?", nil)
                                                               forWallet:self.wallet
                                                               forAmount:0
                                                     forceAuthentication:NO
                                                              completion:^(NSData *_Nullable seed, BOOL cancelled) {
                    rCancelled = cancelled;
                    if (seed) {
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                            DSAssetLockDerivationPath *derivationPathRegistrationFunding = [[DSDerivationPathFactory sharedInstance] identityInvitationFundingDerivationPathForWallet:self.wallet];
                            // TODO: cleanup?
                            registrationFundingPrivateKey = [derivationPathRegistrationFunding privateKeyAtIndexPath:[NSIndexPath indexPathWithIndex:self.identity.index]
                                                                                                            fromSeed:seed];
                            dispatch_semaphore_signal(sem);
                        });
                    } else {
                        dispatch_semaphore_signal(sem);
                    }
                }];
            });
            dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
        }
        if (!registrationFundingPrivateKey) {
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(rCancelled, nil); });
            return;
        }
        //in WIF format
        NSString *registrationFundingPrivateKeyString = [DSKeyManager serializedPrivateKey:registrationFundingPrivateKey->ok chainType:self.chain.chainType];
        NSString *serializedISLock = [self.identity.registrationAssetLockTransaction.instantSendLockAwaitingProcessing.toData hexString];
        NSURLComponents *components = [NSURLComponents componentsWithString:@"https://invitations.dashpay.io/applink"];
        NSMutableArray *queryItems = [NSMutableArray array];
        if (senderUsername)
            [queryItems addObject:[NSURLQueryItem queryItemWithName:@"du" value:senderUsername]];
        if (senderDisplayName)
            [queryItems addObject:[NSURLQueryItem queryItemWithName:@"display-name" value:senderDisplayName]];
        if (senderAvatarPath)
            [queryItems addObject:[NSURLQueryItem queryItemWithName:@"avatar-url" value:senderAvatarPath]];
        [queryItems addObject:[NSURLQueryItem queryItemWithName:@"assetlocktx" value:fundingTransactionHexString.lowercaseString]];
        [queryItems addObject:[NSURLQueryItem queryItemWithName:@"pk" value:registrationFundingPrivateKeyString]];
        [queryItems addObject:[NSURLQueryItem queryItemWithName:@"islock" value:serializedISLock.lowercaseString]];
        components.queryItems = queryItems;
        dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(NO, components.URL.absoluteString); });
    });
}

// MARK: Saving

- (void)saveInContext:(NSManagedObjectContext *)context {
    if (self.isTransient) return;
    [context performBlockAndWait:^{
        BOOL changeOccured = NO;
        NSMutableArray *updateEvents = [NSMutableArray array];
        DSBlockchainInvitationEntity *entity = [self invitationEntityInContext:context];
        if (entity.tag != self.tag) {
            entity.tag = self.tag;
            changeOccured = YES;
            [updateEvents addObject:DSInvitationUpdateEvents];
        }
        if (entity.name != self.name) {
            entity.name = self.name;
            changeOccured = YES;
            [updateEvents addObject:DSInvitationUpdateEvents];
        }
        if (entity.link != self.link) {
            entity.link = self.link;
            changeOccured = YES;
            [updateEvents addObject:DSInvitationUpdateEventLink];
        }
        if (changeOccured) {
            [context ds_save];
            if (updateEvents.count) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:DSInvitationDidUpdateNotification
                                                                        object:nil
                                                                      userInfo:@{
                        DSChainManagerNotificationChainKey: self.chain,
                        DSInvitationKey: self,
                        DSInvitationUpdateEvents: updateEvents
                    }];
                });
            }
        }
    }];
}

// MARK: Deletion

- (void)deletePersistentObjectAndSave:(BOOL)save inContext:(NSManagedObjectContext *)context {
    [context performBlockAndWait:^{
        DSBlockchainInvitationEntity *invitationEntity = [self invitationEntityInContext:context];
        if (invitationEntity) {
            [invitationEntity deleteObjectAndWait];
            if (save) [context ds_save];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSInvitationDidUpdateNotification
                                                                object:nil
                                                              userInfo:@{
                DSChainManagerNotificationChainKey: self.chain,
                DSInvitationKey: self
            }];
        });
    }];
}

// MARK: Entity

- (DSBlockchainInvitationEntity *)invitationEntity {
    return [self invitationEntityInContext:[NSManagedObjectContext viewContext]];
}

- (DSBlockchainInvitationEntity *)invitationEntityInContext:(NSManagedObjectContext *)context {
    __block DSBlockchainInvitationEntity *entity = nil;
    [context performBlockAndWait:^{
        entity = [DSBlockchainInvitationEntity anyObjectInContext:context matching:@"blockchainIdentity.uniqueID == %@", self.identity.uniqueIDData];
    }];
    NSAssert(entity, @"An entity should always be found");
    return entity;
}

- (NSString *)debugDescription {
    return [[super debugDescription] stringByAppendingString:[NSString stringWithFormat:@" {%d-%@-%@}", self.identity.index, self.identity.currentDashpayUsername, self.identity.uniqueIdString]];
}


@end
