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

#import "DSIdentitiesManager.h"
#import "DSAuthenticationKeysDerivationPath.h"
#import "DSBlockchainIdentity+Protected.h"
#import "DSBlockchainIdentityEntity+CoreDataClass.h"
#import "DSChain+Protected.h"
#import "DSChainManager.h"
#import "DSCreditFundingTransaction.h"
#import "DSDAPIClient.h"
#import "DSDAPIPlatformNetworkService.h"
#import "DSDashPlatform.h"
#import "DSMerkleBlock.h"
#import "DSOptionsManager.h"
#import "DSPeerManager.h"
#import "DSTransientDashpayUser+Protected.h"
#import "DSWallet.h"
#import "NSManagedObject+Sugar.h"
#import "NSManagedObjectContext+DSSugar.h"
#import "NSString+Dash.h"

@interface DSIdentitiesManager ()

@property (nonatomic, strong) DSChain *chain;
@property (nonatomic, strong) dispatch_queue_t identityQueue;
@property (nonatomic, strong) NSMutableDictionary *foreignBlockchainIdentities;

@end

@implementation DSIdentitiesManager

- (instancetype)initWithChain:(DSChain *)chain {
    NSParameterAssert(chain);

    if (!(self = [super init])) return nil;

    self.chain = chain;
    _identityQueue = dispatch_queue_create([@"org.dashcore.dashsync.identity" UTF8String], DISPATCH_QUEUE_SERIAL);
    self.foreignBlockchainIdentities = [NSMutableDictionary dictionary];
    [self loadExternalBlockchainIdentities];

    return self;
}

// MARK: - Loading

- (void)loadExternalBlockchainIdentities {
    NSManagedObjectContext *context = [NSManagedObjectContext chainContext]; //shouldn't matter what context is used

    [context performBlockAndWait:^{
        NSArray<DSBlockchainIdentityEntity *> *externalIdentityEntities = [DSBlockchainIdentityEntity objectsInContext:context matching:@"chain == %@ && isLocal == FALSE", [self.chain chainEntityInContext:context]];
        for (DSBlockchainIdentityEntity *entity in externalIdentityEntities) {
            DSBlockchainIdentity *identity = [[DSBlockchainIdentity alloc] initWithBlockchainIdentityEntity:entity];
            if (identity) {
                self.foreignBlockchainIdentities[uint256_data(identity.uniqueID)] = identity;
            }
        }
    }];
}

// MARK: - Wiping

- (void)clearExternalBlockchainIdentities {
    self.foreignBlockchainIdentities = [NSMutableDictionary dictionary];
}

// MARK: - Identities

- (void)registerForeignBlockchainIdentity:(DSBlockchainIdentity *)blockchainIdentity {
    NSAssert(!blockchainIdentity.isTransient, @"Dash Identity should no longer be transient");
    @synchronized(self.foreignBlockchainIdentities) {
        if (!self.foreignBlockchainIdentities[uint256_data(blockchainIdentity.uniqueID)]) {
            [blockchainIdentity saveInitial];
            self.foreignBlockchainIdentities[uint256_data(blockchainIdentity.uniqueID)] = blockchainIdentity;
        }
    }
}

- (DSBlockchainIdentity *)foreignBlockchainIdentityWithUniqueId:(UInt256)uniqueId {
    return [self foreignBlockchainIdentityWithUniqueId:uniqueId createIfMissing:NO inContext:nil];
}

- (DSBlockchainIdentity *)foreignBlockchainIdentityWithUniqueId:(UInt256)uniqueId createIfMissing:(BOOL)addIfMissing inContext:(NSManagedObjectContext *)context {
    //foreign blockchain identities are for local blockchain identies' contacts, not for search.
    @synchronized(self.foreignBlockchainIdentities) {
        DSBlockchainIdentity *foreignBlockchainIdentity = self.foreignBlockchainIdentities[uint256_data(uniqueId)];
        if (foreignBlockchainIdentity) {
            NSAssert(context ? [foreignBlockchainIdentity blockchainIdentityEntityInContext:context] : foreignBlockchainIdentity.blockchainIdentityEntity, @"Blockchain identity entity should exist");
            return foreignBlockchainIdentity;
        } else if (addIfMissing) {
            foreignBlockchainIdentity = [[DSBlockchainIdentity alloc] initWithUniqueId:uniqueId isTransient:FALSE onChain:self.chain];
            [foreignBlockchainIdentity saveInitialInContext:context];
            self.foreignBlockchainIdentities[uint256_data(uniqueId)] = foreignBlockchainIdentity;
            return self.foreignBlockchainIdentities[uint256_data(uniqueId)];
        }
        return nil;
    }
}

- (NSArray *)unsyncedBlockchainIdentities {
    NSMutableArray *unsyncedBlockchainIdentities = [NSMutableArray array];
    for (DSBlockchainIdentity *blockchainIdentity in [self.chain localBlockchainIdentities]) {
        if (!blockchainIdentity.registrationCreditFundingTransaction || (blockchainIdentity.registrationCreditFundingTransaction.blockHeight == BLOCK_UNKNOWN_HEIGHT)) {
            [unsyncedBlockchainIdentities addObject:blockchainIdentity];
        } else if (self.chain.lastSyncBlockHeight > blockchainIdentity.dashpaySyncronizationBlockHeight) {
            //If they are equal then the blockchain identity is synced
            //This is because the dashpaySyncronizationBlock represents the last block for the bloom filter used in L1 should be considered valid
            //That's because it is set at the time with the hash of the last
            [unsyncedBlockchainIdentities addObject:blockchainIdentity];
        }
    }
    return unsyncedBlockchainIdentities;
}

- (void)syncBlockchainIdentitiesWithCompletion:(IdentitiesSuccessCompletionBlock)completion {
    [self
        retrieveIdentitiesByKeysUntilSuccessWithCompletion:^(NSArray<DSBlockchainIdentity *> *_Nullable retrievedBlockchainIdentities) {
            NSArray<DSBlockchainIdentity *> *blockchainIdentities = [self unsyncedBlockchainIdentities];
            [self fetchNeededNetworkStateInformationForBlockchainIdentities:blockchainIdentities
                                                             withCompletion:^(BOOL success, NSArray<DSBlockchainIdentity *> *_Nullable blockchainIdentities, NSArray<NSError *> *_Nonnull errors) {
                                                                 if (success) {
                                                                     if (completion) {
                                                                         completion(blockchainIdentities);
                                                                     }
                                                                 }
                                                             }
                                                            completionQueue:self.chain.networkingQueue];
        }
                                           completionQueue:self.chain.networkingQueue];
}

- (void)retrieveAllBlockchainIdentitiesChainStates {
    for (DSWallet *wallet in self.chain.wallets) {
        [self retrieveAllBlockchainIdentitiesChainStatesForWallet:wallet];
    }
}

- (void)retrieveAllBlockchainIdentitiesChainStatesForWallet:(DSWallet *)wallet {
    for (DSBlockchainIdentity *identity in [wallet.blockchainIdentities allValues]) {
        if (identity.registrationStatus == DSBlockchainIdentityRegistrationStatus_Unknown) {
            [identity fetchIdentityNetworkStateInformationWithCompletion:^(BOOL success, BOOL found, NSError *error) {
                if (success && found) {
                    //now lets get dpns info
                    if (([[DSOptionsManager sharedInstance] syncType] & DSSyncType_DPNS)) {
                        [identity fetchUsernamesWithCompletion:^(BOOL success, NSError *error){

                        }];
                    }
                }
            }];
        } else if (identity.registrationStatus == DSBlockchainIdentityRegistrationStatus_Registered) {
            if (!identity.currentDashpayUsername) {
                if (([[DSOptionsManager sharedInstance] syncType] & DSSyncType_DPNS)) {
                    [identity fetchUsernamesWithCompletion:^(BOOL success, NSError *error){

                    }];
                }
            }
        }
    }
}

- (id<DSDAPINetworkServiceRequest>)searchIdentityByDashpayUsername:(NSString *)name withCompletion:(IdentityCompletionBlock)completion {
    return [self searchIdentityByName:name inDomain:@"dash" withCompletion:completion];
}

- (id<DSDAPINetworkServiceRequest>)searchIdentityByName:(NSString *)name inDomain:(NSString *)domain withCompletion:(IdentityCompletionBlock)completion {
    DSDAPIClient *client = self.chain.chainManager.DAPIClient;
    id<DSDAPINetworkServiceRequest> call = [client.DAPIPlatformNetworkService getDPNSDocumentsForUsernames:@[name]
        inDomain:domain
        completionQueue:self.identityQueue
        success:^(NSArray<NSDictionary *> *_Nonnull documents) {
            __block NSMutableArray *rBlockchainIdentities = [NSMutableArray array];
            for (NSDictionary *document in documents) {
                NSData *userIdData = document[@"$ownerId"];
                NSString *normalizedLabel = document[@"normalizedLabel"];
                NSString *domain = document[@"normalizedParentDomainName"];
                DSBlockchainIdentity *identity = [[DSBlockchainIdentity alloc] initWithUniqueId:userIdData.UInt256 isTransient:TRUE onChain:self.chain];
                [identity addUsername:normalizedLabel inDomain:domain status:DSBlockchainIdentityUsernameStatus_Confirmed save:NO registerOnNetwork:NO];
                [rBlockchainIdentities addObject:identity];
            }
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(YES, [rBlockchainIdentities firstObject], nil);
                });
            }
        }
        failure:^(NSError *_Nonnull error) {
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(NO, nil, error);
                });
            }
#if DEBUG
            DSLogPrivate(@"Failure in searchIdentityByName %@", error);
#else
            DSLog(@"Failure in searchIdentityByName %@", @"<REDACTED>");
#endif
        }];
    return call;
}

- (id<DSDAPINetworkServiceRequest>)fetchProfileForBlockchainIdentity:(DSBlockchainIdentity *)blockchainIdentity withCompletion:(DashpayUserInfoCompletionBlock)completion onCompletionQueue:(dispatch_queue_t)completionQueue {
    return [self fetchProfileForBlockchainIdentity:blockchainIdentity retryCount:5 delay:2 delayIncrease:1 withCompletion:completion onCompletionQueue:completionQueue];
}

- (id<DSDAPINetworkServiceRequest>)fetchProfileForBlockchainIdentity:(DSBlockchainIdentity *)blockchainIdentity
                                                          retryCount:(uint32_t)retryCount
                                                               delay:(uint32_t)delay
                                                       delayIncrease:(uint32_t)delayIncrease
                                                      withCompletion:(DashpayUserInfoCompletionBlock)completion
                                                   onCompletionQueue:(dispatch_queue_t)completionQueue {
    DPContract *dashpayContract = [DSDashPlatform sharedInstanceForChain:self.chain].dashPayContract;
    if ([dashpayContract contractState] != DPContractState_Registered) {
        if (completion) {
            dispatch_async(completionQueue, ^{
                completion(NO, nil, [NSError errorWithDomain:@"DashSync"
                                                        code:500
                                                    userInfo:@{NSLocalizedDescriptionKey:
                                                                 DSLocalizedString(@"The Dashpay contract is not properly set up", nil)}]);
            });
        }
        return nil;
    }
    DSDAPIClient *client = self.chain.chainManager.DAPIClient;
    id<DSDAPINetworkServiceRequest> call = [client.DAPIPlatformNetworkService getDashpayProfileForUserId:blockchainIdentity.uniqueIDData
        completionQueue:self.identityQueue
        success:^(NSArray<NSDictionary *> *_Nonnull documents) {
            if (documents.count == 0) {
                if (completion) {
                    dispatch_async(completionQueue, ^{
                        completion(YES, nil, nil);
                    });
                }
                return;
            }
            NSDictionary *contactDictionary = documents.firstObject;

            DSTransientDashpayUser *transientDashpayUser = [[DSTransientDashpayUser alloc] initWithDashpayProfileDocument:contactDictionary];
            if (completion) {
                dispatch_async(completionQueue, ^{
                    completion(YES, transientDashpayUser, nil);
                });
            }
        }
        failure:^(NSError *_Nonnull error) {
            if (retryCount > 0) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), self.identityQueue, ^{
                    [self fetchProfileForBlockchainIdentity:blockchainIdentity retryCount:retryCount - 1 delay:delay + delayIncrease delayIncrease:delayIncrease withCompletion:completion onCompletionQueue:completionQueue];
                });
            } else {
                if (completion) {
                    dispatch_async(completionQueue, ^{
                        completion(NO, nil, error);
                    });
                }
            }
        }];
    return call;
}

- (id<DSDAPINetworkServiceRequest>)fetchProfilesForBlockchainIdentities:(NSArray<DSBlockchainIdentity *> *)blockchainIdentities withCompletion:(DashpayUserInfosCompletionBlock)completion onCompletionQueue:(dispatch_queue_t)completionQueue {
    __weak typeof(self) weakSelf = self;

    DPContract *dashpayContract = [DSDashPlatform sharedInstanceForChain:self.chain].dashPayContract;
    if ([dashpayContract contractState] != DPContractState_Registered) {
        if (completion) {
            dispatch_async(completionQueue, ^{
                completion(NO, nil, [NSError errorWithDomain:@"DashSync"
                                                        code:500
                                                    userInfo:@{NSLocalizedDescriptionKey:
                                                                 DSLocalizedString(@"The Dashpay contract is not properly set up", nil)}]);
            });
        }
        return nil;
    }
    NSMutableArray *blockchainIdentityUserIds = [NSMutableArray array];
    for (DSBlockchainIdentity *blockchainIdentity in blockchainIdentities) {
        [blockchainIdentityUserIds addObject:blockchainIdentity.uniqueIDData];
    }
    DSDAPIClient *client = self.chain.chainManager.DAPIClient;
    id<DSDAPINetworkServiceRequest> call = [client.DAPIPlatformNetworkService getDashpayProfilesForUserIds:blockchainIdentityUserIds
        completionQueue:self.identityQueue
        success:^(NSArray<NSDictionary *> *_Nonnull documents) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                if (completion) {
                    dispatch_async(completionQueue, ^{
                        completion(NO, nil, [NSError errorWithDomain:@"DashSync"
                                                                code:500
                                                            userInfo:@{NSLocalizedDescriptionKey:
                                                                         DSLocalizedString(@"Internal memory allocation error", nil)}]);
                    });
                }
                return;
            }

            NSMutableDictionary *dashpayUserDictionary = [NSMutableDictionary dictionary];
            for (NSDictionary *documentDictionary in documents) {
                NSData *userIdData = documentDictionary[@"$ownerId"];
                DSTransientDashpayUser *transientDashpayUser = [[DSTransientDashpayUser alloc] initWithDashpayProfileDocument:documentDictionary];
                [dashpayUserDictionary setObject:transientDashpayUser forKey:userIdData];
            }
            __weak typeof(self) weakSelf = self;
            if (completion) {
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) {
                    return;
                }
                dispatch_async(completionQueue, ^{
                    completion(YES, dashpayUserDictionary, nil);
                });
            }
        }
        failure:^(NSError *_Nonnull error) {
            if (completion) {
                dispatch_async(completionQueue, ^{
                    completion(NO, nil, error);
                });
            }
        }];
    return call;
}

- (id<DSDAPINetworkServiceRequest>)searchIdentitiesByDashpayUsernamePrefix:(NSString *)namePrefix queryDashpayProfileInfo:(BOOL)queryDashpayProfileInfo withCompletion:(IdentitiesCompletionBlock)completion {
    return [self searchIdentitiesByDashpayUsernamePrefix:namePrefix offset:0 limit:100 queryDashpayProfileInfo:queryDashpayProfileInfo withCompletion:completion];
}

- (id<DSDAPINetworkServiceRequest>)searchIdentitiesByDashpayUsernamePrefix:(NSString *)namePrefix offset:(uint32_t)offset limit:(uint32_t)limit queryDashpayProfileInfo:(BOOL)queryDashpayProfileInfo withCompletion:(IdentitiesCompletionBlock)completion {
    return [self searchIdentitiesByNamePrefix:namePrefix
                                     inDomain:@"dash"
                                       offset:offset
                                        limit:limit
                               withCompletion:^(BOOL success, NSArray<DSBlockchainIdentity *> *_Nullable blockchainIdentities, NSArray<NSError *> *_Nonnull errors) {
                                   if (errors.count) {
                                       if (completion) {
                                           dispatch_async(dispatch_get_main_queue(), ^{
                                               completion(success, blockchainIdentities, errors);
                                           });
                                       }
                                   } else if (queryDashpayProfileInfo && blockchainIdentities.count) {
                                       __block NSMutableDictionary<NSData *, DSBlockchainIdentity *> *blockchainIdentityDictionary = [NSMutableDictionary dictionary];
                                       for (DSBlockchainIdentity *blockchainIdentity in blockchainIdentities) {
                                           [blockchainIdentityDictionary setObject:blockchainIdentity forKey:blockchainIdentity.uniqueIDData];
                                       }
                                       [self fetchProfilesForBlockchainIdentities:blockchainIdentities
                                                                   withCompletion:^(BOOL success, NSDictionary<NSData *, DSTransientDashpayUser *> *_Nullable dashpayUserInfosByBlockchainIdentityUniqueId, NSError *_Nullable error) {
                                                                       for (NSData *blockchainIdentityUniqueIdData in dashpayUserInfosByBlockchainIdentityUniqueId) {
                                                                           DSBlockchainIdentity *blockchainIdentity = blockchainIdentityDictionary[blockchainIdentityUniqueIdData];
                                                                           blockchainIdentity.transientDashpayUser = dashpayUserInfosByBlockchainIdentityUniqueId[blockchainIdentityUniqueIdData];
                                                                       }
                                                                       if (completion) {
                                                                           dispatch_async(dispatch_get_main_queue(), ^{
                                                                               completion(success, blockchainIdentities, errors);
                                                                           });
                                                                       }
                                                                   }
                                                                onCompletionQueue:self.identityQueue];
                                   } else {
                                       if (completion) {
                                           dispatch_async(dispatch_get_main_queue(), ^{
                                               completion(success, blockchainIdentities, errors);
                                           });
                                       }
                                   }
                               }];
}

- (id<DSDAPINetworkServiceRequest>)searchIdentitiesByNamePrefix:(NSString *)namePrefix inDomain:(NSString *)domain offset:(uint32_t)offset limit:(uint32_t)limit withCompletion:(IdentitiesCompletionBlock)completion {
    DSDAPIClient *client = self.chain.chainManager.DAPIClient;
    id<DSDAPINetworkServiceRequest> call = [client.DAPIPlatformNetworkService searchDPNSDocumentsForUsernamePrefix:namePrefix
        inDomain:domain
        offset:offset
        limit:limit
        completionQueue:self.identityQueue
        success:^(NSArray<NSDictionary *> *_Nonnull documents) {
            __block NSMutableArray *rBlockchainIdentities = [NSMutableArray array];
            for (NSDictionary *document in documents) {
                NSData *userIdData = document[@"$ownerId"];
                NSString *label = document[@"label"];
                NSString *domain = document[@"normalizedParentDomainName"];
                UInt256 uniqueId = userIdData.UInt256;
                DSBlockchainIdentity *identity = [self.chain blockchainIdentityForUniqueId:uniqueId foundInWallet:nil includeForeignBlockchainIdentities:YES];
                if (!identity) {
                    identity = [[DSBlockchainIdentity alloc] initWithUniqueId:uniqueId isTransient:TRUE onChain:self.chain];
                    [identity addUsername:label inDomain:domain status:DSBlockchainIdentityUsernameStatus_Confirmed save:NO registerOnNetwork:NO];
                } else {
                    if (![identity.dashpayUsernames containsObject:label]) {
                        [identity addUsername:label inDomain:domain status:DSBlockchainIdentityUsernameStatus_Confirmed save:YES registerOnNetwork:NO];
                    }
                }

                [rBlockchainIdentities addObject:identity];
            }
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(YES, [rBlockchainIdentities copy], @[]);
                });
            }
        }
        failure:^(NSError *_Nonnull error) {
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(NO, nil, @[error]);
                });
            }
#if DEBUG
            DSLogPrivate(@"Failure in searchIdentitiesByNamePrefix %@", error);
#else
            DSLog(@"Failure in searchIdentitiesByNamePrefix %@", @"<REDACTED>");
#endif
        }];
    return call;
}

- (void)searchIdentitiesByDPNSRegisteredBlockchainIdentityUniqueID:(NSData *)userID withCompletion:(IdentitiesCompletionBlock)completion {
    DSDAPIClient *client = self.chain.chainManager.DAPIClient;
    [client.DAPIPlatformNetworkService getDPNSDocumentsForIdentityWithUserId:userID
        completionQueue:self.identityQueue
        success:^(NSArray<NSDictionary *> *_Nonnull documents) {
            __block NSMutableArray *rBlockchainIdentities = [NSMutableArray array];
            for (NSDictionary *document in documents) {
                NSData *userIdData = document[@"$ownerId"];
                NSString *normalizedLabel = document[@"normalizedLabel"];
                NSString *domain = document[@"normalizedParentDomainName"];
                DSBlockchainIdentity *identity = [[DSBlockchainIdentity alloc] initWithUniqueId:userIdData.UInt256 isTransient:TRUE onChain:self.chain];
                [identity addUsername:normalizedLabel inDomain:domain status:DSBlockchainIdentityUsernameStatus_Confirmed save:NO registerOnNetwork:NO];
                [identity fetchIdentityNetworkStateInformationWithCompletion:^(BOOL success, BOOL found, NSError *error){

                }];
                [rBlockchainIdentities addObject:identity];
            }
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(YES, [rBlockchainIdentities copy], @[]);
                });
            }
        }
        failure:^(NSError *_Nonnull error) {
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(NO, nil, @[error]);
                });
            }
#if DEBUG
            DSLogPrivate(@"Failure in searchIdentitiesByDPNSRegisteredBlockchainIdentityUniqueID %@", error);
#else
            DSLog(@"Failure in searchIdentitiesByDPNSRegisteredBlockchainIdentityUniqueID %@", @"<REDACTED>");
#endif
        }];
}

- (void)checkCreditFundingTransactionForPossibleNewIdentity:(DSCreditFundingTransaction *)creditFundingTransaction {
    uint32_t index;
    DSWallet *wallet = [self.chain walletHavingBlockchainIdentityCreditFundingRegistrationHash:creditFundingTransaction.creditBurnPublicKeyHash foundAtIndex:&index];

    if (!wallet) return; //it's a topup or we are funding an external identity

    DSBlockchainIdentity *blockchainIdentity = [wallet blockchainIdentityForUniqueId:creditFundingTransaction.creditBurnIdentityIdentifier];

    NSAssert(blockchainIdentity, @"We should have already created the blockchain identity at this point in the transaction manager by calling triggerUpdatesForLocalReferences");


    //DSLogPrivate(@"Paused Sync at block %d to gather identity information on %@",block.height,blockchainIdentity.uniqueIdString);
    [self fetchNeededNetworkStateInformationForBlockchainIdentity:blockchainIdentity
                                                   withCompletion:^(BOOL success, DSBlockchainIdentity *_Nullable blockchainIdentity, NSError *_Nullable error) {
                                                       if (success && blockchainIdentity != nil) {
                                                           [self chain:self.chain didFinishInChainSyncPhaseFetchingBlockchainIdentityDAPInformation:blockchainIdentity];
                                                       }
                                                   }
                                                  completionQueue:self.chain.networkingQueue];
}

- (void)fetchNeededNetworkStateInformationForBlockchainIdentity:(DSBlockchainIdentity *)blockchainIdentity withCompletion:(IdentityCompletionBlock)completion completionQueue:(dispatch_queue_t)completionQueue {
    [blockchainIdentity fetchNeededNetworkStateInformationWithCompletion:^(DSBlockchainIdentityQueryStep failureStep, NSArray<NSError *> *_Nullable errors) {
        if (!failureStep || failureStep == DSBlockchainIdentityQueryStep_NoIdentity) {
            //if this was never registered no need to retry
            if (completion) {
                dispatch_async(completionQueue, ^{
                    completion(YES, blockchainIdentity, nil);
                });
            }
        } else {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), completionQueue, ^{
                [self fetchNeededNetworkStateInformationForBlockchainIdentity:blockchainIdentity withCompletion:completion completionQueue:completionQueue];
            });
        }
    }];
}

- (void)fetchNeededNetworkStateInformationForBlockchainIdentities:(NSArray<DSBlockchainIdentity *> *)blockchainIdentities withCompletion:(IdentitiesCompletionBlock)completion completionQueue:(dispatch_queue_t)completionQueue {
    dispatch_group_t dispatchGroup = dispatch_group_create();
    __block NSMutableArray *errors = [NSMutableArray array];
    for (DSBlockchainIdentity *blockchainIdentity in blockchainIdentities) {
        dispatch_group_enter(dispatchGroup);
        [self fetchNeededNetworkStateInformationForBlockchainIdentity:blockchainIdentity
                                                       withCompletion:^(BOOL success, DSBlockchainIdentity *_Nullable blockchainIdentity, NSError *_Nullable error) {
                                                           if (success && blockchainIdentity != nil) {
                                                               dispatch_group_leave(dispatchGroup);
                                                           } else {
                                                               [errors addObject:error];
                                                           }
                                                       }
                                                      completionQueue:self.identityQueue];
    }
    dispatch_group_notify(dispatchGroup, completionQueue, ^{
        if (completion) {
            completion(!errors.count, blockchainIdentities, errors);
        }
    });
}

- (NSArray<DSBlockchainIdentity *> *)identitiesFromIdentityDictionaries:(NSArray<NSDictionary *> *)identityDictionaries keyIndexes:(NSDictionary *)keyIndexes forWallet:(DSWallet *)wallet {
    NSMutableArray *identities = [NSMutableArray array];
    for (NSDictionary *identityDictionary in identityDictionaries) {
        DSKey *key = [DSBlockchainIdentity firstKeyInIdentityDictionary:identityDictionary];
        NSNumber *index = [keyIndexes objectForKey:key.publicKeyData];
        if (index) {
            DSBlockchainIdentity *blockchainIdentity = [[DSBlockchainIdentity alloc] initAtIndex:index.intValue withIdentityDictionary:identityDictionary inWallet:wallet];
            [identities addObject:blockchainIdentity];
        }
    }
    return identities;
}

#define RETRIEVE_IDENTITIES_DELAY_INCREMENT 2

- (void)retrieveIdentitiesByKeysUntilSuccessWithCompletion:(IdentitiesSuccessCompletionBlock)completion completionQueue:(dispatch_queue_t)completionQueue {
    [self internalRetrieveIdentitiesByKeysUntilSuccessWithDelay:0 withCompletion:completion completionQueue:completionQueue];
}

- (void)internalRetrieveIdentitiesByKeysUntilSuccessWithDelay:(uint32_t)delay withCompletion:(IdentitiesSuccessCompletionBlock)completion completionQueue:(dispatch_queue_t)completionQueue {
    [self
        retrieveIdentitiesByKeysWithCompletion:^(BOOL success, NSArray<DSBlockchainIdentity *> *_Nullable blockchainIdentities, NSArray<NSError *> *_Nonnull errors) {
            if (!success) {
                dispatch_after(delay, self.identityQueue, ^{
                    [self internalRetrieveIdentitiesByKeysUntilSuccessWithDelay:delay + RETRIEVE_IDENTITIES_DELAY_INCREMENT withCompletion:completion completionQueue:completionQueue];
                });
            } else if (completion) {
                completion(blockchainIdentities);
            }
        }
                               completionQueue:completionQueue];
}

- (void)retrieveIdentitiesByKeysWithCompletion:(IdentitiesCompletionBlock)completion completionQueue:(dispatch_queue_t)completionQueue {
    if (!self.chain.isEvolutionEnabled) {
        if (completion) {
            dispatch_async(completionQueue, ^{
                completion(YES, @[], @[]);
            });
        }
        return;
    }
    dispatch_async(self.identityQueue, ^{
        NSArray<DSWallet *> *wallets = self.chain.wallets;
        DSDAPIClient *client = self.chain.chainManager.DAPIClient;
        NSMutableArray<NSData *> *keyHashes = [NSMutableArray array];
        __block dispatch_group_t dispatch_group = dispatch_group_create();
        __block NSMutableArray *errors = [NSMutableArray array];
        __block NSMutableArray *allIdentities = [NSMutableArray array];

        for (DSWallet *wallet in wallets) {
            uint32_t unusedIndex = [wallet unusedBlockchainIdentityIndex];
            DSAuthenticationKeysDerivationPath *derivationPath = [DSBlockchainIdentity derivationPathForType:DSKeyType_ECDSA forWallet:wallet];
            const int keysToCheck = 5;
            NSMutableDictionary *keyIndexes = [NSMutableDictionary dictionary];
            for (int i = 0; i < keysToCheck; i++) {
                const NSUInteger indexes[] = {(unusedIndex + i) | BIP32_HARD, 0 | BIP32_HARD};
                NSIndexPath *indexPath = [NSIndexPath indexPathWithIndexes:indexes length:2];
                DSKey *key = [derivationPath publicKeyAtIndexPath:indexPath];
                [keyHashes addObject:uint160_data([key hash160])];
                [keyIndexes setObject:@(unusedIndex + i) forKey:key.publicKeyData];
            }
            dispatch_group_enter(dispatch_group);
            [client.DAPIPlatformNetworkService fetchIdentitiesByKeyHashes:keyHashes
                completionQueue:self.identityQueue
                success:^(NSArray<NSDictionary *> *_Nonnull identityDictionaries) {
                    NSArray<DSBlockchainIdentity *> *identities = [self identitiesFromIdentityDictionaries:identityDictionaries keyIndexes:keyIndexes forWallet:wallet];
                    BOOL success = [wallet registerBlockchainIdentities:identities verify:YES];
                    if (success) {
                        [allIdentities addObjectsFromArray:identities];
                        NSManagedObjectContext *platformContext = [NSManagedObjectContext platformContext];
                        [platformContext performBlockAndWait:^{
                            for (DSBlockchainIdentity *identity in identities) {
                                [identity saveInitialInContext:platformContext];
                            }
                            dispatch_group_leave(dispatch_group);
                        }];
                    } else {
                        [errors addObject:[NSError errorWithDomain:@"DashPlatform"
                                                              code:500
                                                          userInfo:@{NSLocalizedDescriptionKey:
                                                                       DSLocalizedString(@"Identity has unknown keys", nil)}]];
                        dispatch_group_leave(dispatch_group);
                    }
                }
                failure:^(NSError *_Nonnull error) {
                    if (error) {
                        [errors addObject:error];
                    }
                    dispatch_group_leave(dispatch_group);
                }];
        }

        dispatch_group_notify(dispatch_group, completionQueue, ^{
            completion(!errors.count, allIdentities, errors);
        });
    });
}

// MARK: - DSChainIdentitiesDelegate

- (void)chain:(DSChain *)chain didFinishInChainSyncPhaseFetchingBlockchainIdentityDAPInformation:(DSBlockchainIdentity *)blockchainIdentity {
    [self.chain.chainManager chain:chain didFinishInChainSyncPhaseFetchingBlockchainIdentityDAPInformation:blockchainIdentity];
}

@end
