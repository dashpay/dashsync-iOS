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

#import "DSBlockchainInvitation.h"
#import "DSAuthenticationManager.h"
#import "DSBlockchainIdentity+Protected.h"
#import "DSBlockchainInvitationEntity+CoreDataClass.h"
#import "DSChainManager.h"
#import "DSCreditFundingDerivationPath.h"
#import "DSCreditFundingTransaction.h"
#import "DSDAPICoreNetworkService.h"
#import "DSDerivationPathFactory.h"
#import "DSIdentitiesManager+Protected.h"
#import "DSInstantSendTransactionLock.h"
#import "DSWallet.h"
#import "NSData+DSHash.h"
#import "NSManagedObject+Sugar.h"
#import "NSManagedObjectContext+DSSugar.h"
#import "NSString+Dash.h"

@interface DSBlockchainInvitation ()

@property (nonatomic, weak) DSWallet *wallet;
@property (nonatomic, strong) DSChain *chain;
@property (nonatomic, copy) NSString *link;
@property (nonatomic, strong) DSBlockchainIdentity *identity;
@property (nonatomic, assign) BOOL isTransient;
@property (nonatomic, assign) BOOL needsIdentityRetrieval;
@property (nonatomic, assign) BOOL createdLocally;

@end

@implementation DSBlockchainInvitation

- (instancetype)initAtIndex:(uint32_t)index inWallet:(DSWallet *)wallet {
    //this is the creation of a new blockchain identity
    NSParameterAssert(wallet);

    if (!(self = [super init])) return nil;
    self.wallet = wallet;
    self.isTransient = FALSE;
    self.identity = [[DSBlockchainIdentity alloc] initAtIndex:index inWallet:wallet];
    [self.identity setAssociatedInvitation:self];
    self.chain = wallet.chain;
    self.needsIdentityRetrieval = NO;
    self.createdLocally = YES;
    return self;
}

- (instancetype)initAtIndex:(uint32_t)index withFundingTransaction:(DSCreditFundingTransaction *)transaction inWallet:(DSWallet *)wallet {
    NSParameterAssert(wallet);
    if (![transaction isCreditFundingTransaction]) return nil;
    NSAssert(index != UINT32_MAX, @"index must be found");
    if (!(self = [super init])) return nil;
    self.wallet = wallet;
    self.isTransient = FALSE;
    self.createdLocally = YES;
    self.identity = [[DSBlockchainIdentity alloc] initAtIndex:index withFundingTransaction:transaction withUsernameDictionary:nil inWallet:wallet];
    [self.identity setAssociatedInvitation:self];
    self.chain = wallet.chain;
    self.needsIdentityRetrieval = NO;
    return self;
}

- (instancetype)initAtIndex:(uint32_t)index withLockedOutpoint:(DSUTXO)lockedOutpoint inWallet:(DSWallet *)wallet {
    NSParameterAssert(wallet);
    NSAssert(index != UINT32_MAX, @"index must be found");
    if (!(self = [super init])) return nil;
    self.wallet = wallet;
    self.isTransient = FALSE;
    self.createdLocally = YES;
    self.identity = [[DSBlockchainIdentity alloc] initAtIndex:index withLockedOutpoint:lockedOutpoint inWallet:wallet];
    [self.identity setAssociatedInvitation:self];
    self.chain = wallet.chain;
    self.needsIdentityRetrieval = NO;

    return self;
}

- (instancetype)initAtIndex:(uint32_t)index withLockedOutpoint:(DSUTXO)lockedOutpoint inWallet:(DSWallet *)wallet withBlockchainInvitationEntity:(DSBlockchainInvitationEntity *)blockchainInvitationEntity {
    if (!(self = [super init])) return nil;
    self.wallet = wallet;
    self.isTransient = FALSE;
    self.createdLocally = YES;
    self.identity = [[DSBlockchainIdentity alloc] initAtIndex:index withLockedOutpoint:lockedOutpoint inWallet:wallet withBlockchainIdentityEntity:blockchainInvitationEntity.blockchainIdentity associatedToInvitation:self];
    self.link = blockchainInvitationEntity.link;
    self.chain = wallet.chain;
    self.needsIdentityRetrieval = NO;
    return self;
}

- (instancetype)initWithInvitationLink:(NSString *)invitationLink inWallet:(DSWallet *)wallet {
    if (!(self = [super init])) return nil;
    self.link = invitationLink;
    self.wallet = wallet;
    self.chain = wallet.chain;
    self.needsIdentityRetrieval = YES;
    self.createdLocally = NO;
    return self;
}

- (void)generateBlockchainInvitationsExtendedPublicKeysWithPrompt:(NSString *)prompt completion:(void (^_Nullable)(BOOL registered))completion {
    __block DSCreditFundingDerivationPath *derivationPathInvitationFunding = [[DSDerivationPathFactory sharedInstance] blockchainIdentityInvitationFundingDerivationPathForWallet:self.wallet];
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


- (void)registerInWalletForRegistrationFundingTransaction:(DSCreditFundingTransaction *)fundingTransaction {
    NSAssert(self.identity != nil, @"The identity must already exist");
    [self.identity setInvitationRegistrationCreditFundingTransaction:fundingTransaction];
    [self registerInWalletForBlockchainIdentityUniqueId:fundingTransaction.creditBurnIdentityIdentifier];

    //we need to also set the address of the funding transaction to being used so future identities past the initial gap limit are found
    [fundingTransaction markInvitationAddressAsUsedInWallet:self.wallet];
}

- (void)registerInWalletForBlockchainIdentityUniqueId:(UInt256)blockchainIdentityUniqueId {
    [self.identity setInvitationUniqueId:blockchainIdentityUniqueId];
    [self registerInWallet];
}

- (BOOL)isRegisteredInWallet {
    if (!self.wallet) return FALSE;
    return [self.wallet containsBlockchainInvitation:self];
}

- (void)registerInWallet {
    NSAssert(self.identity.isOutgoingInvitation, @"The underlying identity is not from an invitation");
    if (!self.identity.isOutgoingInvitation) return;
    [self.wallet registerBlockchainInvitation:self];
    [self.identity saveInitial];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DSBlockchainInvitationDidUpdateNotification object:nil userInfo:@{DSChainManagerNotificationChainKey: self.chain, DSBlockchainInvitationKey: self}];
    });
}

- (BOOL)unregisterLocally {
    NSAssert(self.identity.isOutgoingInvitation, @"The underlying identity is not from an invitation");
    if (!self.identity.isOutgoingInvitation) return FALSE;
    if (self.identity.isRegistered) return FALSE; //if the invitation has already been used we can not unregister it
    [self.wallet unregisterBlockchainInvitation:self];
    [self deletePersistentObjectAndSave:YES inContext:[NSManagedObjectContext platformContext]];
    return TRUE;
}

- (void)verifyInvitationLinkWithCompletion:(void (^_Nullable)(DSTransaction *transaction, bool spent, NSError *error))completion completionQueue:(dispatch_queue_t)completionQueue {
    [DSBlockchainInvitation verifyInvitationLink:self.link onChain:self.wallet.chain completion:completion completionQueue:completionQueue];
}

+ (void)verifyInvitationLink:(NSString *)invitationLink onChain:(DSChain *)chain completion:(void (^_Nullable)(DSTransaction *transaction, bool spent, NSError *error))completion completionQueue:(dispatch_queue_t)completionQueue {
    DSDAPICoreNetworkService *coreNetworkService = chain.chainManager.DAPIClient.DAPICoreNetworkService;
    NSURLComponents *components = [NSURLComponents componentsWithString:invitationLink];
    NSArray *queryItems = components.queryItems;
    UInt256 assetLockTransactionHash = UINT256_ZERO;
    DSECDSAKey *fundingPrivateKey = nil;
    for (NSURLQueryItem *queryItem in queryItems) {
        if ([queryItem.name isEqualToString:@"assetlocktx"]) {
            NSString *assetLockTransactionHashString = queryItem.value;
            assetLockTransactionHash = assetLockTransactionHashString.hexToData.UInt256;
        } else if ([queryItem.name isEqualToString:@"pk"]) {
            NSString *fundingPrivateKeyString = queryItem.value;
            fundingPrivateKey = [DSECDSAKey keyWithPrivateKey:fundingPrivateKeyString onChain:chain];
        }
    }
    if (uint256_is_zero(assetLockTransactionHash)) {
        if (completion) {
            completion(nil, NO, [NSError errorWithDomain:@"DashSync"
                                                    code:400
                                                userInfo:@{NSLocalizedDescriptionKey:
                                                             DSLocalizedString(@"Invitation format is not valid", nil)}]);
        }
        return;
    }
    if (!fundingPrivateKey || uint256_is_zero(*fundingPrivateKey.secretKey)) {
        if (completion) {
            completion(nil, NO, [NSError errorWithDomain:@"DashSync"
                                                    code:400
                                                userInfo:@{NSLocalizedDescriptionKey:
                                                             DSLocalizedString(@"Funding private key is not valid", nil)}]);
        }
        return;
    }

    [coreNetworkService getTransactionWithHash:assetLockTransactionHash
        completionQueue:completionQueue
        success:^(DSTransaction *_Nonnull transaction) {
            NSAssert(transaction, @"transaction must not be null");
            if (!transaction || ![transaction isKindOfClass:[DSCreditFundingTransaction class]]) {
                if (completion) {
                    completion(nil, NO, [NSError errorWithDomain:@"DashSync"
                                                            code:400
                                                        userInfo:@{NSLocalizedDescriptionKey:
                                                                     DSLocalizedString(@"Invitation transaction is not valid", nil)}]);
                }
                return;
            }
            if (completion) {
                completion(transaction, NO, nil);
            }
        }
        failure:^(NSError *_Nonnull error) {
            if (completion) {
                completion(nil, NO, [NSError errorWithDomain:@"DashSync"
                                                        code:400
                                                    userInfo:@{NSLocalizedDescriptionKey:
                                                                 DSLocalizedString(@"Invitation format is not valid", nil)}]);
            }
        }];
}

- (void)acceptInvitationUsingWalletIndex:(uint32_t)index setDashpayUsername:(NSString *)dashpayUsername authenticationPrompt:(NSString *)authenticationMessage identityRegistrationSteps:(DSBlockchainIdentityRegistrationStep)identityRegistrationSteps stepCompletion:(void (^_Nullable)(DSBlockchainIdentityRegistrationStep stepCompleted))stepCompletion completion:(void (^_Nullable)(DSBlockchainIdentityRegistrationStep stepsCompleted, NSError *error))completion completionQueue:(dispatch_queue_t)completionQueue {
    DSDAPICoreNetworkService *coreNetworkService = self.chain.chainManager.DAPIClient.DAPICoreNetworkService;
    NSURLComponents *components = [NSURLComponents componentsWithString:self.link];
    NSArray *queryItems = components.queryItems;
    UInt256 assetLockTransactionHash = UINT256_ZERO;
    DSECDSAKey *fundingPrivateKey = nil;
    for (NSURLQueryItem *queryItem in queryItems) {
        if ([queryItem.name isEqualToString:@"assetlocktx"]) {
            NSString *assetLockTransactionHashString = queryItem.value;
            assetLockTransactionHash = assetLockTransactionHashString.hexToData.UInt256;
        } else if ([queryItem.name isEqualToString:@"pk"]) {
            NSString *fundingPrivateKeyString = queryItem.value;
            fundingPrivateKey = [DSECDSAKey keyWithPrivateKey:fundingPrivateKeyString onChain:self.chain];
        }
    }
    if (uint256_is_zero(assetLockTransactionHash)) {
        if (completion) {
            completion(DSBlockchainIdentityRegistrationStep_None, [NSError errorWithDomain:@"DashSync"
                                                                                      code:400
                                                                                  userInfo:@{NSLocalizedDescriptionKey:
                                                                                               DSLocalizedString(@"Invitation format is not valid", nil)}]);
        }
        return;
    }
    if (!fundingPrivateKey || uint256_is_zero(*fundingPrivateKey.secretKey)) {
        if (completion) {
            completion(DSBlockchainIdentityRegistrationStep_None, [NSError errorWithDomain:@"DashSync"
                                                                                      code:400
                                                                                  userInfo:@{NSLocalizedDescriptionKey:
                                                                                               DSLocalizedString(@"Funding private key is not valid", nil)}]);
        }
        return;
    }

    [coreNetworkService getTransactionWithHash:assetLockTransactionHash
        completionQueue:self.chain.chainManager.identitiesManager.identityQueue
        success:^(DSTransaction *_Nonnull transaction) {
            NSAssert(transaction, @"transaction must not be null");
            if (!transaction || ![transaction isKindOfClass:[DSCreditFundingTransaction class]]) {
                if (completion) {
                    completion(DSBlockchainIdentityRegistrationStep_None, [NSError errorWithDomain:@"DashSync"
                                                                                              code:400
                                                                                          userInfo:@{NSLocalizedDescriptionKey:
                                                                                                       DSLocalizedString(@"Invitation transaction is not valid", nil)}]);
                }
                return;
            }
            self.identity = [[DSBlockchainIdentity alloc] initAtIndex:index withFundingTransaction:(DSCreditFundingTransaction *)transaction withUsernameDictionary:nil inWallet:self.wallet];
            [self.identity setAssociatedInvitation:self];
            [self.identity addDashpayUsername:dashpayUsername save:NO];
            BOOL success = [self.identity setExternalFundingPrivateKey:fundingPrivateKey];
            NSAssert(success, @"We must be able to set the external funding private key");
            if (success) {
                [self.identity generateBlockchainIdentityExtendedPublicKeysWithPrompt:authenticationMessage
                                                                           completion:^(BOOL registered) {
                                                                               if (registered) {
                                                                                   [self.identity continueRegisteringIdentityOnNetwork:identityRegistrationSteps stepsCompleted:DSBlockchainIdentityRegistrationStep_L1Steps stepCompletion:stepCompletion completion:completion];
                                                                               } else if (completion) {
                                                                                   completion(DSBlockchainIdentityRegistrationStep_None, [NSError errorWithDomain:@"DashSync"
                                                                                                                                                             code:500
                                                                                                                                                         userInfo:@{NSLocalizedDescriptionKey:
                                                                                                                                                                      DSLocalizedString(@"Error generating Identity keys", nil)}]);
                                                                               }
                                                                           }];
            } else {
                if (completion) {
                    completion(DSBlockchainIdentityRegistrationStep_None, [NSError errorWithDomain:@"DashSync"
                                                                                              code:500
                                                                                          userInfo:@{NSLocalizedDescriptionKey:
                                                                                                       DSLocalizedString(@"Error setting the external funding private key", nil)}]);
                }
            }
        }
        failure:^(NSError *_Nonnull error) {
            if (completion) {
                completion(DSBlockchainIdentityRegistrationStep_None, [NSError errorWithDomain:@"DashSync"
                                                                                          code:400
                                                                                      userInfo:@{NSLocalizedDescriptionKey:
                                                                                                   DSLocalizedString(@"Invitation format is not valid", nil)}]);
            }
        }];
}

- (void)createInvitationFullLinkFromIdentity:(DSBlockchainIdentity *)identity completion:(void (^_Nullable)(BOOL cancelled, NSString *invitationFullLink))completion {
    if (!self.identity.registrationCreditFundingTransaction.instantSendLockAwaitingProcessing) {
        if (completion) {
            completion(NO, nil);
        }
        return;
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *senderUsername = identity.currentDashpayUsername;
        NSString *senderDisplayName = identity.displayName;
        NSString *senderAvatarPath = identity.avatarPath;
        NSString *fundingTransactionHexString = uint256_reverse_hex(self.identity.registrationCreditFundingTransaction.txHash);
        __block DSECDSAKey *registrationFundingPrivateKey = self.identity.registrationFundingPrivateKey;
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
                                                                          DSCreditFundingDerivationPath *derivationPathRegistrationFunding = [[DSDerivationPathFactory sharedInstance] blockchainIdentityInvitationFundingDerivationPathForWallet:self.wallet];

                                                                          registrationFundingPrivateKey = (DSECDSAKey *)[derivationPathRegistrationFunding privateKeyAtIndexPath:[NSIndexPath indexPathWithIndex:self.identity.index] fromSeed:seed];
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
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) {
                    completion(rCancelled, nil);
                }
            });
            return;
        }
        NSString *registrationFundingPrivateKeyString = [registrationFundingPrivateKey serializedPrivateKeyForChain:self.chain]; //in WIF format

        NSString *serializedISLock = [self.identity.registrationCreditFundingTransaction.instantSendLockAwaitingProcessing.toData hexString];

        NSURLComponents *components = [NSURLComponents componentsWithString:@"https://invitations.dashpay.io/applink"];
        NSMutableArray *queryItems = [NSMutableArray array];
        if (senderUsername) {
            NSURLQueryItem *senderUsernameQueryItem = [NSURLQueryItem queryItemWithName:@"du" value:senderUsername];
            [queryItems addObject:senderUsernameQueryItem];
        }
        if (senderDisplayName) {
            NSURLQueryItem *senderDisplayNameQueryItem = [NSURLQueryItem queryItemWithName:@"display-name" value:senderDisplayName];
            [queryItems addObject:senderDisplayNameQueryItem];
        }
        if (senderAvatarPath) {
            NSURLQueryItem *senderAvatarPathQueryItem = [NSURLQueryItem queryItemWithName:@"avatar-url" value:senderAvatarPath];
            [queryItems addObject:senderAvatarPathQueryItem];
        }

        NSURLQueryItem *fundingTransactionQueryItem = [NSURLQueryItem queryItemWithName:@"assetlocktx" value:fundingTransactionHexString];
        [queryItems addObject:fundingTransactionQueryItem];

        NSURLQueryItem *registrationFundingPrivateKeyQueryItem = [NSURLQueryItem queryItemWithName:@"pk" value:registrationFundingPrivateKeyString];
        [queryItems addObject:registrationFundingPrivateKeyQueryItem];

        NSURLQueryItem *serializedISLockQueryItem = [NSURLQueryItem queryItemWithName:@"islock" value:serializedISLock];
        [queryItems addObject:serializedISLockQueryItem];

        components.queryItems = queryItems;

        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(NO, components.URL.absoluteString);
            }
        });
    });
}

// MARK: Saving

- (void)saveInContext:(NSManagedObjectContext *)context {
    if (self.isTransient) return;
    [context performBlockAndWait:^{
        BOOL changeOccured = NO;
        NSMutableArray *updateEvents = [NSMutableArray array];
        DSBlockchainInvitationEntity *entity = [self blockchainInvitationEntityInContext:context];
        if (entity.link != self.link) {
            entity.link = self.link;
            changeOccured = YES;
            [updateEvents addObject:DSBlockchainInvitationUpdateEventLink];
        }
        if (changeOccured) {
            [context ds_save];
            if (updateEvents.count) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:DSBlockchainInvitationDidUpdateNotification object:nil userInfo:@{DSChainManagerNotificationChainKey: self.chain, DSBlockchainInvitationKey: self, DSBlockchainInvitationUpdateEvents: updateEvents}];
                });
            }
        }
    }];
}

// MARK: Deletion

- (void)deletePersistentObjectAndSave:(BOOL)save inContext:(NSManagedObjectContext *)context {
    [context performBlockAndWait:^{
        DSBlockchainInvitationEntity *blockchainInvitationEntity = [self blockchainInvitationEntityInContext:context];
        if (blockchainInvitationEntity) {
            [blockchainInvitationEntity deleteObjectAndWait];
            if (save) {
                [context ds_save];
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSBlockchainInvitationDidUpdateNotification object:nil userInfo:@{DSChainManagerNotificationChainKey: self.chain, DSBlockchainInvitationKey: self}];
        });
    }];
}

// MARK: Entity

- (DSBlockchainInvitationEntity *)blockchainInvitationEntity {
    return [self blockchainInvitationEntityInContext:[NSManagedObjectContext viewContext]];
}

- (DSBlockchainInvitationEntity *)blockchainInvitationEntityInContext:(NSManagedObjectContext *)context {
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
