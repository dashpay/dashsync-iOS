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

#import "DPContract.h"
#import "DSIdentitiesManager.h"
#import "DSIdentitiesManager+CoreData.h"
#import "DSAssetLockTransaction.h"
#import "DSAuthenticationKeysDerivationPath.h"
#import "DSIdentity+Protected.h"
#import "DSIdentity+Username.h"
#import "DSBlockchainIdentityEntity+CoreDataClass.h"
#import "DSChain+Identity.h"
#import "DSChain+Params.h"
#import "DSChain+Protected.h"
#import "DSChain+Wallet.h"
#import "DSChainManager.h"
//#import "DSDAPIPlatformNetworkService.h"
#import "DSDashPlatform.h"
#import "DSMerkleBlock.h"
#import "DSOptionsManager.h"
#import "DSPeerManager.h"
#import "DSTransientDashpayUser+Protected.h"
#import "DSWallet.h"
#import "DSWallet+Identity.h"
#import "NSError+Dash.h"
#import "NSError+Platform.h"
#import "NSManagedObject+Sugar.h"
#import "NSManagedObjectContext+DSSugar.h"
#import "NSString+Dash.h"
#import "dash_shared_core.h"

#define ERROR_UNKNOWN_KEYS [NSError errorWithCode:500 localizedDescriptionKey:@"Identity has unknown keys"]
#define ERROR_CONTRACT_SETUP [NSError errorWithCode:500 localizedDescriptionKey:@"The Dashpay contract is not properly set up"]

@interface DSIdentitiesManager ()

@property (nonatomic, strong) DSChain *chain;
@property (nonatomic, strong) dispatch_queue_t identityQueue;
@property (nonatomic, strong) NSMutableDictionary *foreignIdentities;
@property (nonatomic, assign) NSTimeInterval lastSyncedIndentitiesTimestamp;
@property (nonatomic, assign) BOOL hasRecentIdentitiesSync;

@end

@implementation DSIdentitiesManager

- (instancetype)initWithChain:(DSChain *)chain {
    NSParameterAssert(chain);
    
    if (!(self = [super init])) return nil;
    
    self.chain = chain;
    _identityQueue = dispatch_queue_create([@"org.dashcore.dashsync.identity" UTF8String], DISPATCH_QUEUE_SERIAL);
    [self setup];
//    self.foreignIdentities = [NSMutableDictionary dictionary];
//    [self loadExternalIdentities];
    
    return self;
}

// MARK: - Loading


- (BOOL)hasRecentIdentitiesSync {
    return ([[NSDate date] timeIntervalSince1970] - self.lastSyncedIndentitiesTimestamp < 30);
}

// MARK: - Wiping

//- (void)clearExternalIdentities {
//    self.foreignIdentities = [NSMutableDictionary dictionary];
//}

// MARK: - Identities

//- (void)registerForeignIdentity:(DSIdentity *)identity {
//    NSAssert(!identity.isTransient, @"Dash Identity should no longer be transient");
//    @synchronized(self.foreignIdentities) {
//        if (!self.foreignIdentities[uint256_data(identity.uniqueID)]) {
//            [identity saveInitial];
//            self.foreignIdentities[uint256_data(identity.uniqueID)] = identity;
//        }
//    }
//}

//- (DSIdentity *)foreignIdentityWithUniqueId:(UInt256)uniqueId {
//    return [self foreignIdentityWithUniqueId:uniqueId createIfMissing:NO inContext:nil];
//}
//
//- (DSIdentity *)foreignIdentityWithUniqueId:(UInt256)uniqueId
//                                                createIfMissing:(BOOL)addIfMissing
//                                                      inContext:(NSManagedObjectContext *)context {
//    //foreign identities are for local blockchain identies' contacts, not for search.
//    @synchronized(self.foreignIdentities) {
//        DSIdentity *foreignIdentity = self.foreignIdentities[uint256_data(uniqueId)];
//        if (foreignIdentity) {
//            NSAssert(context ? [foreignIdentity identityEntityInContext:context] : foreignIdentity.identityEntity, @"Identity entity should exist");
//            return foreignIdentity;
//        } else if (addIfMissing) {
//            foreignIdentity = [[DSIdentity alloc] initWithUniqueId:uniqueId isTransient:FALSE onChain:self.chain];
//            [foreignIdentity saveInitialInContext:context];
//            self.foreignIdentities[uint256_data(uniqueId)] = foreignIdentity;
//            return self.foreignIdentities[uint256_data(uniqueId)];
//        }
//        return nil;
//    }
//}

- (NSArray *)unsyncedIdentities {
    NSMutableArray *unsyncedIdentities = [NSMutableArray array];
    for (DSIdentity *identity in [self.chain localIdentities]) {
        if (!identity.registrationAssetLockTransaction || (identity.registrationAssetLockTransaction.blockHeight == BLOCK_UNKNOWN_HEIGHT)) {
            [unsyncedIdentities addObject:identity];
        } else if (self.chain.lastSyncBlockHeight > identity.dashpaySyncronizationBlockHeight) {
            //If they are equal then the blockchain identity is synced
            //This is because the dashpaySyncronizationBlock represents the last block for the bloom filter used in L1 should be considered valid
            //That's because it is set at the time with the hash of the last
            [unsyncedIdentities addObject:identity];
        }
    }
    return unsyncedIdentities;
}

//TODO: if we get an error or identity not found, better stop the process and start syncing chain
- (void)syncIdentitiesWithCompletion:(IdentitiesSuccessCompletionBlock)completion {
    [self retrieveIdentitiesByKeysUntilSuccessWithCompletion:^(NSArray<DSIdentity *> *_Nullable retrievedIdentities) {
        [self fetchNeededNetworkStateInformationForIdentities:[self unsyncedIdentities]
                                               withCompletion:^(BOOL success, NSArray<DSIdentity *> *_Nullable identities, NSArray<NSError *> *_Nonnull errors) {
            self.lastSyncedIndentitiesTimestamp = [[NSDate date] timeIntervalSince1970];
            if (success) if (completion) completion(identities);
        }
                                                        completionQueue:self.chain.networkingQueue];
    }
     completionQueue:self.chain.networkingQueue];
}

- (void)retrieveAllIdentitiesChainStates {
    for (DSWallet *wallet in self.chain.wallets) {
        [self retrieveAllIdentitiesChainStatesForWallet:wallet];
    }
}

- (void)retrieveAllIdentitiesChainStatesForWallet:(DSWallet *)wallet {
    for (DSIdentity *identity in [wallet.identities allValues]) {
        if (identity.registrationStatus == DSIdentityRegistrationStatus_Unknown) {
            [identity fetchIdentityNetworkStateInformationWithCompletion:^(BOOL success, BOOL found, NSError *error) {
                //now lets get dpns info
                if (success && found && ([[DSOptionsManager sharedInstance] syncType] & DSSyncType_DPNS))
                    [identity fetchUsernamesWithCompletion:^(BOOL success, NSError *error) {}];
            }];
        } else if (identity.registrationStatus == DSIdentityRegistrationStatus_Registered && !identity.currentDashpayUsername && ([[DSOptionsManager sharedInstance] syncType] & DSSyncType_DPNS)) {
            [identity fetchUsernamesWithCompletion:^(BOOL success, NSError *error) {}];
        }
    }
}

- (void)searchIdentityByDashpayUsername:(NSString *)name
                         withCompletion:(IdentityCompletionBlock)completion {
    [self searchIdentityByName:name inDomain:@"dash" withCompletion:completion];
}

- (void)searchIdentityByName:(NSString *)name
                    inDomain:(NSString *)domain
              withCompletion:(IdentityCompletionBlock)completion {
    DMaybeDocumentsMap *result = dash_spv_platform_document_manager_DocumentsManager_dpns_documents_for_username(self.chain.shareCore.runtime, self.chain.shareCore.documentsManager->obj, (char *)[name UTF8String]);
    if (result->error) {
        NSError *error = [NSError ffi_from_platform_error:result->error];
        DMaybeDocumentsMapDtor(result);
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, nil, error); });
        return;
    }
    
    // TODO: in wallet we have unusuable but cancelable request, so...
    __block NSMutableArray *rIdentities = [NSMutableArray array];
    DDocumentsMap *documents = result->ok;
    for (int i = 0; i < documents->count; i++) {
        dpp_document_Document *document = documents->values[i];
        if (!document) continue;
        platform_value_Value *normalized_label_value = dash_spv_platform_document_get_document_property(document, (char *) [@"normalizedLabel" UTF8String]);
        NSString *normalizedLabel = [NSString stringWithCString:normalized_label_value->text encoding:NSUTF8StringEncoding];
        platform_value_Value_destroy(normalized_label_value);
        platform_value_Value *normalized_parent_domain_name_value = dash_spv_platform_document_get_document_property(document, (char *) [@"normalizedParentDomainName" UTF8String]);
        NSString *domain = [NSString stringWithCString:normalized_parent_domain_name_value->text encoding:NSUTF8StringEncoding];
        platform_value_Value_destroy(normalized_parent_domain_name_value);
        platform_value_types_identifier_Identifier *owner_id = document->v0->owner_id;

        DSIdentity *identity = [[DSIdentity alloc] initWithUniqueId:*(UInt256 *)owner_id->_0->_0 isTransient:TRUE onChain:self.chain];
        [identity addUsername:normalizedLabel inDomain:domain status:DSIdentityUsernameStatus_Confirmed save:NO registerOnNetwork:NO];
        [rIdentities addObject:identity];

    }
    if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(YES, [rIdentities firstObject], nil); });
}

- (void)fetchProfileForIdentity:(DSIdentity *)identity
                                            withCompletion:(DashpayUserInfoCompletionBlock)completion
                                         onCompletionQueue:(dispatch_queue_t)completionQueue {
    [self fetchProfileForIdentity:identity
                       retryCount:5
                            delay:2
                    delayIncrease:1
                   withCompletion:completion
                onCompletionQueue:completionQueue];
}

- (void)fetchProfileForIdentity:(DSIdentity *)identity
                     retryCount:(uint32_t)retryCount
                          delay:(uint32_t)delay
                  delayIncrease:(uint32_t)delayIncrease
                 withCompletion:(DashpayUserInfoCompletionBlock)completion
              onCompletionQueue:(dispatch_queue_t)completionQueue {
    DPContract *dashpayContract = [DSDashPlatform sharedInstanceForChain:self.chain].dashPayContract;
    if ([dashpayContract contractState] != DPContractState_Registered) {
        if (completion) dispatch_async(completionQueue, ^{ completion(NO, nil, nil); });
        return;
    }
    DMaybeDocument *result = dash_spv_platform_document_manager_DocumentsManager_dashpay_profile_for_user_id_using_contract(self.chain.shareCore.runtime, self.chain.shareCore.documentsManager->obj, u256_ctor_u(identity.uniqueID), dashpayContract.raw_contract);
    if (result->error) {
        NSError *error = [NSError ffi_from_platform_error:result->error];
        dispatch_async(completionQueue, ^{ completion(NO, nil, error); });
        DMaybeDocumentDtor(result);
        return;
    }
    if (!result->ok) {
        if (completion) dispatch_async(completionQueue, ^{ completion(YES, nil, nil); });
        DMaybeDocumentDtor(result);
        return;
   }
    DSTransientDashpayUser *transientDashpayUser = [[DSTransientDashpayUser alloc] initWithDocument:result->ok];
    dispatch_async(completionQueue, ^{ if (completion) completion(YES, transientDashpayUser, nil); });
}

- (void)fetchProfilesForIdentities:(NSArray<NSData *> *)identityUserIds
                    withCompletion:(DashpayUserInfosCompletionBlock)completion
                 onCompletionQueue:(dispatch_queue_t)completionQueue {
    __weak typeof(self) weakSelf = self;
    DPContract *dashpayContract = [DSDashPlatform sharedInstanceForChain:self.chain].dashPayContract;
    if ([dashpayContract contractState] != DPContractState_Registered) {
        if (completion) dispatch_async(completionQueue, ^{ completion(NO, nil, ERROR_CONTRACT_SETUP); });
        return;
    }
    NSUInteger user_ids_count = identityUserIds.count;
    u256 **user_ids_values = malloc(sizeof(u256 *) * user_ids_count);
    
    for (int i = 0; i < user_ids_count; i++) {
        NSData *userID = identityUserIds[i];
        user_ids_values[i] = u256_ctor(userID);
    }
    Vec_u8_32 *user_ids = Vec_u8_32_ctor(user_ids_count, user_ids_values);
    DMaybeDocumentsMap *result = dash_spv_platform_document_manager_DocumentsManager_dashpay_profiles_for_user_ids_using_contract(self.chain.shareCore.runtime, self.chain.shareCore.documentsManager->obj, user_ids, dashpayContract.raw_contract);
    if (result->error) {
        NSError *error = [NSError ffi_from_platform_error:result->error];
        if (completion) dispatch_async(completionQueue, ^{ completion(NO, nil, error); });
        DMaybeDocumentsMapDtor(result);
        return;
    }
    DDocumentsMap *documents = result->ok;
    NSMutableDictionary *dashpayUserDictionary = [NSMutableDictionary dictionary];
    for (int i = 0; i < documents->count; i++) {
        platform_value_types_identifier_Identifier *identifier = documents->keys[i];
        dpp_document_Document *document = documents->values[i];
        switch (document->tag) {
            case dpp_document_Document_V0: {
                platform_value_types_identifier_Identifier *owner_id = document->v0->owner_id;
                DSTransientDashpayUser *transientDashpayUser = [[DSTransientDashpayUser alloc] initWithDocument:document];
                [dashpayUserDictionary setObject:transientDashpayUser forKey:NSDataFromPtr(document->v0->owner_id->_0->_0)];
                break;
            }
            default:
                break;
        }
    }
    DMaybeDocumentsMapDtor(result);
    if (completion) dispatch_async(completionQueue, ^{ completion(YES, dashpayUserDictionary, nil); });
}

- (void)searchIdentitiesByDashpayUsernamePrefix:(NSString *)namePrefix
                        queryDashpayProfileInfo:(BOOL)queryDashpayProfileInfo
                                 withCompletion:(IdentitiesCompletionBlock)completion {
    [self searchIdentitiesByDashpayUsernamePrefix:namePrefix
                                       startAfter:nil
                                            limit:100
                          queryDashpayProfileInfo:queryDashpayProfileInfo
                                   withCompletion:completion];
}

- (void)searchIdentitiesByDashpayUsernamePrefix:(NSString *)namePrefix
                                     startAfter:(NSData* _Nullable)startAfter
                                          limit:(uint32_t)limit
                        queryDashpayProfileInfo:(BOOL)queryDashpayProfileInfo
                                 withCompletion:(IdentitiesCompletionBlock)completion {
    [self searchIdentitiesByNamePrefix:namePrefix
                            startAfter:startAfter
                                 limit:limit
                        withCompletion:^(BOOL success, NSArray<DSIdentity *> *_Nullable identities, NSArray<NSError *> *_Nonnull errors) {
        if (errors.count) {
            if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(success, identities, errors); });
        } else if (queryDashpayProfileInfo && identities.count) {
            __block NSMutableDictionary<NSData *, DSIdentity *> *identityDictionary = [NSMutableDictionary dictionary];
            for (DSIdentity *identity in identities) {
                [identityDictionary setObject:identity forKey:identity.uniqueIDData];
            }
            [self fetchProfilesForIdentities:identityDictionary.allKeys
                              withCompletion:^(BOOL success, NSDictionary<NSData *, DSTransientDashpayUser *> *_Nullable dashpayUserInfosByIdentityUniqueId, NSError *_Nullable error) {
                for (NSData *identityUniqueIdData in dashpayUserInfosByIdentityUniqueId) {
                    DSIdentity *identity = identityDictionary[identityUniqueIdData];
                    identity.transientDashpayUser = dashpayUserInfosByIdentityUniqueId[identityUniqueIdData];
                }
                if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(success, identities, errors); });
            }
                           onCompletionQueue:self.identityQueue];
        } else if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(success, identities, errors); });
        }
    }];
}

- (void)searchIdentitiesByNamePrefix:(NSString *)namePrefix
                          startAfter:(NSData* _Nullable)startAfter
                               limit:(uint32_t)limit
                      withCompletion:(IdentitiesCompletionBlock)completion {
    DMaybeDocumentsMap *result = dash_spv_platform_document_manager_DocumentsManager_dpns_documents_for_username_prefix(self.chain.shareCore.runtime, self.chain.shareCore.documentsManager->obj, (char *)[namePrefix UTF8String]);
    if (result->error) {
        NSError *error = [NSError ffi_from_platform_error:result->error];
        DMaybeDocumentsMapDtor(result);
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, nil, @[error]); });
        return;
    }
    DDocumentsMap *documents = result->ok;
    __block NSMutableDictionary *rIdentities = [NSMutableDictionary dictionary];
    for (int i = 0; i < documents->count; i++) {
        dpp_document_Document *document = documents->values[i];
        if (!document) continue;
        switch (document->tag) {
            case dpp_document_Document_V0: {
                u256 *owner_id = document->v0->owner_id->_0->_0;
                NSData *userIdData = NSDataFromPtr(owner_id);
                UInt256 uniqueId = *(UInt256 *)owner_id->values;
                DSIdentity *identity = [rIdentities objectForKey:userIdData];
                if (!identity)
                    identity = [self.chain identityForUniqueId:uniqueId foundInWallet:nil includeForeignIdentities:YES];
                platform_value_Value *label_value = dash_spv_platform_document_get_document_property(document, (char *) [@"label" UTF8String]);
                platform_value_Value *domain_value = dash_spv_platform_document_get_document_property(document, (char *) [@"normalizedParentDomainName" UTF8String]);
                NSString *label = [NSString stringWithCString:label_value->text encoding:NSUTF8StringEncoding];
                NSString *domain = [NSString stringWithCString:domain_value->text encoding:NSUTF8StringEncoding];
                if (!identity) {
                    identity = [[DSIdentity alloc] initWithUniqueId:uniqueId isTransient:TRUE onChain:self.chain];
                    [identity addUsername:label inDomain:domain status:DSIdentityUsernameStatus_Confirmed save:NO registerOnNetwork:NO];
                } else if (![identity.dashpayUsernames containsObject:label]) {
                    [identity addUsername:label inDomain:domain status:DSIdentityUsernameStatus_Confirmed save:YES registerOnNetwork:NO];
                }
                [rIdentities setObject:identity forKey:userIdData];
                break;
            }
            default:
                break;
        }
    }
    if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(YES, [[rIdentities allValues] copy], @[]); });
}

- (void)searchIdentitiesByDPNSRegisteredIdentityUniqueID:(NSData *)userID
                                          withCompletion:(IdentitiesCompletionBlock)completion {
    
    DMaybeDocumentsMap *result = dash_spv_platform_document_manager_DocumentsManager_dpns_documents_for_identity_with_user_id(self.chain.shareCore.runtime, self.chain.shareCore.documentsManager->obj, u256_ctor(userID));
    if (result->error) {
        NSError *error = [NSError ffi_from_platform_error:result->error];
        DMaybeDocumentsMapDtor(result);
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, nil, @[error]); });
        return;
    }
    DDocumentsMap *identities = result->ok;
    __block NSMutableArray *rIdentities = [NSMutableArray array];
    for (int i = 0; i < identities->count; i++) {
        dpp_document_Document *document = identities->values[i];
        if (!document) continue;
        switch (document->tag) {
            case dpp_document_Document_V0: {
                platform_value_Value *normalized_label_value = dash_spv_platform_document_get_document_property(document, (char *) [@"normalizedLabel" UTF8String]);
                NSString *normalizedLabel = [NSString stringWithCString:normalized_label_value->text encoding:NSUTF8StringEncoding];
                platform_value_Value_destroy(normalized_label_value);
                platform_value_Value *normalized_parent_domain_name_value = dash_spv_platform_document_get_document_property(document, (char *) [@"normalizedParentDomainName" UTF8String]);
                NSString *domain = [NSString stringWithCString:normalized_parent_domain_name_value->text encoding:NSUTF8StringEncoding];
                platform_value_Value_destroy(normalized_parent_domain_name_value);
                platform_value_types_identifier_Identifier *owner_id = document->v0->owner_id;
                DSIdentity *identity = [[DSIdentity alloc] initWithUniqueId:*(UInt256 *)owner_id->_0->_0 isTransient:TRUE onChain:self.chain];
                [identity addUsername:normalizedLabel inDomain:domain status:DSIdentityUsernameStatus_Confirmed save:NO registerOnNetwork:NO];
                [identity fetchIdentityNetworkStateInformationWithCompletion:^(BOOL success, BOOL found, NSError *error) {}];
                [rIdentities addObject:identity];
                break;
            }
            default:
                break;
        }
    }
    DMaybeDocumentsMapDtor(result);
    if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(YES, [rIdentities copy], @[]); });
}

- (void)checkAssetLockTransactionForPossibleNewIdentity:(DSAssetLockTransaction *)transaction {
    uint32_t index;
    DSWallet *wallet = [self.chain walletHavingIdentityAssetLockRegistrationHash:transaction.creditBurnPublicKeyHash foundAtIndex:&index];
    if (!wallet) return; //it's a topup or we are funding an external identity
    DSIdentity *identity = [wallet identityForUniqueId:transaction.creditBurnIdentityIdentifier];
    NSAssert(identity, @"We should have already created the blockchain identity at this point in the transaction manager by calling triggerUpdatesForLocalReferences");
    //DSLogPrivate(@"Paused Sync at block %d to gather identity information on %@", block.height, identity.uniqueIdString);
    [self fetchNeededNetworkStateInformationForIdentity:identity
                                         withCompletion:^(BOOL success, DSIdentity *_Nullable identity, NSError *_Nullable error) {
        if (success && identity != nil)
            [self chain:self.chain didFinishInChainSyncPhaseFetchingIdentityDAPInformation:identity];
    }
                                                  completionQueue:self.chain.networkingQueue];
}

- (void)fetchNeededNetworkStateInformationForIdentity:(DSIdentity *)identity
                                       withCompletion:(IdentityCompletionBlock)completion
                                      completionQueue:(dispatch_queue_t)completionQueue {
    [identity fetchNeededNetworkStateInformationWithCompletion:^(DSIdentityQueryStep failureStep, NSArray<NSError *> *_Nullable errors) {
        if (!failureStep || failureStep == DSIdentityQueryStep_NoIdentity) {
            //if this was never registered no need to retry
            if (completion) dispatch_async(completionQueue, ^{ completion(YES, identity, nil); });
        } else {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), completionQueue, ^{
                [self fetchNeededNetworkStateInformationForIdentity:identity withCompletion:completion completionQueue:completionQueue];
            });
        }
    }];
}

- (void)fetchNeededNetworkStateInformationForIdentities:(NSArray<DSIdentity *> *)identities
                                         withCompletion:(IdentitiesCompletionBlock)completion
                                        completionQueue:(dispatch_queue_t)completionQueue {
    dispatch_group_t dispatchGroup = dispatch_group_create();
    __block NSMutableArray *errors = [NSMutableArray array];
    for (DSIdentity *identity in identities) {
        dispatch_group_enter(dispatchGroup);
        [self fetchNeededNetworkStateInformationForIdentity:identity
                                             withCompletion:^(BOOL success, DSIdentity *_Nullable identity, NSError *_Nullable error) {
            if (success && identity != nil) {
                dispatch_group_leave(dispatchGroup);
            } else {
                [errors addObject:error];
            }
        }
                                                      completionQueue:self.identityQueue];
    }
    dispatch_group_notify(dispatchGroup, completionQueue, ^{
        if (completion) completion(!errors.count, identities, errors);
    });
}

//- (NSArray<DSIdentity *> *)identitiesFromIdentityDictionaries:(NSArray<NSDictionary *> *)identityDictionaries keyIndexes:(NSDictionary *)keyIndexes forWallet:(DSWallet *)wallet {
//    NSMutableArray *identities = [NSMutableArray array];
//    for (NSDictionary *versionedIdentityDictionary in identityDictionaries) {
//        NSNumber *version = [versionedIdentityDictionary objectForKey:@(DSPlatformStoredMessage_Version)];
//        NSDictionary *identityDictionary = [versionedIdentityDictionary objectForKey:@(DSPlatformStoredMessage_Item)];
//        DOpaqueKey *key = [DSIdentity firstKeyInIdentityDictionary:identityDictionary];
//        NSNumber *index = [keyIndexes objectForKey:[DSKeyManager publicKeyData:key]];
//        if (index) {
//            DSIdentity *identity = [[DSIdentity alloc] initAtIndex:index.intValue withIdentityDictionary:identityDictionary version:[version intValue] inWallet:wallet];
//            [identities addObject:identity];
//        }
//    }
//    return identities;
//}

#define RETRIEVE_IDENTITIES_DELAY_INCREMENT 2

- (void)retrieveIdentitiesByKeysUntilSuccessWithCompletion:(IdentitiesSuccessCompletionBlock)completion
                                           completionQueue:(dispatch_queue_t)completionQueue {
    [self internalRetrieveIdentitiesByKeysUntilSuccessWithDelay:0 withCompletion:completion completionQueue:completionQueue];
}

- (void)internalRetrieveIdentitiesByKeysUntilSuccessWithDelay:(uint32_t)delay
                                               withCompletion:(IdentitiesSuccessCompletionBlock)completion
                                              completionQueue:(dispatch_queue_t)completionQueue {
    [self
     retrieveIdentitiesByKeysWithCompletion:^(BOOL success, NSArray<DSIdentity *> *_Nullable identities, NSArray<NSError *> *_Nonnull errors) {
        if (!success) {
            dispatch_after(delay, self.identityQueue, ^{
                [self internalRetrieveIdentitiesByKeysUntilSuccessWithDelay:delay + RETRIEVE_IDENTITIES_DELAY_INCREMENT
                                                             withCompletion:completion
                                                            completionQueue:completionQueue];
            });
        } else if (completion) {
            completion(identities);
        }
    }
     completionQueue:completionQueue];
}

- (void)retrieveIdentitiesByKeysWithCompletion:(IdentitiesCompletionBlock)completion
                               completionQueue:(dispatch_queue_t)completionQueue {
    if (!self.chain.isEvolutionEnabled) {
        if (completion) dispatch_async(completionQueue, ^{ completion(YES, @[], @[]); });
        return;
    }
    dispatch_async(self.identityQueue, ^{
        NSArray<DSWallet *> *wallets = self.chain.wallets;

        __block dispatch_group_t dispatch_group = dispatch_group_create();
        __block NSMutableArray *errors = [NSMutableArray array];
        __block NSMutableArray *allIdentities = [NSMutableArray array];
        
        for (DSWallet *wallet in wallets) {
            uint32_t unusedIndex = [wallet unusedIdentityIndex];
            DSAuthenticationKeysDerivationPath *derivationPath = [DSIdentity derivationPathForType:dash_spv_crypto_keys_key_KeyKind_ECDSA_ctor() forWallet:wallet];
            const int keysToCheck = 5;
            NSMutableDictionary *keyIndexes = [NSMutableDictionary dictionaryWithCapacity:keysToCheck];
            u160 **key_hashes = malloc(keysToCheck * sizeof(u160 *));
            for (int i = 0; i < keysToCheck; i++) {
                const NSUInteger indexes[] = {(unusedIndex + i) | BIP32_HARD, 0 | BIP32_HARD};
                NSIndexPath *indexPath = [NSIndexPath indexPathWithIndexes:indexes length:2];
                NSData *publicKeyData = [derivationPath publicKeyDataAtIndexPath:indexPath];
                key_hashes[i] = u160_ctor_u(publicKeyData.hash160);
                [keyIndexes setObject:@(unusedIndex + i) forKey:publicKeyData];
            }
            dispatch_group_enter(dispatch_group);
            NSString *walletID = wallet.uniqueIDString;
            Result_ok_std_collections_Map_keys_u8_arr_20_values_dpp_identity_identity_Identity_err_dash_spv_platform_error_Error *result =            dash_spv_platform_identity_manager_IdentitiesManager_get_identities_for_key_hashes(self.chain.shareCore.runtime, self.chain.shareCore.identitiesManager->obj, (char *) [walletID UTF8String], Vec_u8_20_ctor(keysToCheck, key_hashes));
            
            if (!result) {
                DSLog(@"get_identities_for_key_hashes: NULL result ");
                [errors addObject:ERROR_UNKNOWN_KEYS];
                dispatch_group_leave(dispatch_group);
                return;
            }
            if (!result->ok) {
                DSLog(@"get_identities_for_key_hashes: Error ");
                [errors addObject:ERROR_UNKNOWN_KEYS];
                Result_ok_std_collections_Map_keys_u8_arr_20_values_dpp_identity_identity_Identity_err_dash_spv_platform_error_Error_destroy(result);
                dispatch_group_leave(dispatch_group);
                return;
            }
            std_collections_Map_keys_u8_arr_20_values_dpp_identity_identity_Identity *ok = result->ok;
            NSMutableArray *identities = [NSMutableArray array];
            
            for (int j = 0; j < ok->count; j++) {
                dpp_identity_identity_Identity *identity = ok->values[j];
                dpp_identity_v0_IdentityV0 *identity_v0 = identity->v0;
                DMaybeOpaqueKey *maybe_opaque_key = dash_spv_platform_identity_manager_opaque_key_from_identity_public_key(identity_v0->public_keys->values[0]);
                NSData *publicKeyData = [DSKeyManager publicKeyData:maybe_opaque_key->ok];
                NSNumber *index = [keyIndexes objectForKey:publicKeyData];
                DSIdentity *identityModel = [[DSIdentity alloc] initAtIndex:index.intValue uniqueId:u256_cast(identity_v0->id->_0->_0) inWallet:wallet];
                [identityModel applyIdentity:identity save:NO inContext:nil];
                [identities addObject:identityModel];
            }
            Result_ok_std_collections_Map_keys_u8_arr_20_values_dpp_identity_identity_Identity_err_dash_spv_platform_error_Error_destroy(result);
            BOOL success = [wallet registerIdentities:identities verify:YES];
            DSLog(@"get_identities_for_key_hashes: Success: %u ", success);
            if (success) {
                [allIdentities addObjectsFromArray:identities];
                NSManagedObjectContext *platformContext = [NSManagedObjectContext platformContext];
                [platformContext performBlockAndWait:^{
                    for (DSIdentity *identity in identities) {
                        [identity saveInitialInContext:platformContext];
                    }
                }];
            } else {
                [errors addObject:ERROR_UNKNOWN_KEYS];
            }
        }
        dispatch_group_notify(dispatch_group, completionQueue, ^{
            completion(!errors.count, allIdentities, errors);
        });
    });
}

// MARK: - DSChainIdentitiesDelegate

- (void)chain:(DSChain *)chain didFinishInChainSyncPhaseFetchingIdentityDAPInformation:(DSIdentity *)identity {
    [self.chain.chainManager chain:chain didFinishInChainSyncPhaseFetchingIdentityDAPInformation:identity];
}

@end
