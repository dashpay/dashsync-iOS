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
#import "DSChainManager+Protected.h"
#import "DSDashPlatform.h"
#import "DSDerivationPathFactory.h"
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
#import "dash_spv_apple_bindings.h"

#define ERROR_UNKNOWN_KEYS [NSError errorWithCode:500 localizedDescriptionKey:@"Identity has unknown keys"]
#define ERROR_CONTRACT_SETUP [NSError errorWithCode:500 localizedDescriptionKey:@"The Dashpay contract is not properly set up"]

@interface DSIdentitiesManager ()

@property (nonatomic, strong) DSChain *chain;
@property (nonatomic, strong) dispatch_queue_t identityQueue;
@property (nonatomic, strong) NSMutableDictionary *foreignIdentities;
@property (nonatomic, assign) NSTimeInterval lastSyncedIndentitiesTimestamp;

@end

@implementation DSIdentitiesManager

- (NSString *)logPrefix {
    return [NSString stringWithFormat:@"[%@] [Identity Manager]", self.chain.name];
}

- (instancetype)initWithChain:(DSChain *)chain {
    NSParameterAssert(chain);
    
    if (!(self = [super init])) return nil;
    
    self.chain = chain;
    
    dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INITIATED, 0);
    _identityQueue = dispatch_queue_create("org.dashcore.dashsync.identity", attr);

    [self setup];
//    self.foreignIdentities = [NSMutableDictionary dictionary];
//    [self loadExternalIdentities];
    
    return self;
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
            DSLog(@"%@ Unsynced identity (asset lock tx unknown or has unknown height) %@ %@", self.logPrefix, uint256_hex(identity.registrationAssetLockTransactionHash), identity.registrationAssetLockTransaction);

            [unsyncedIdentities addObject:identity];
        } else if (self.chain.lastSyncBlockHeight > identity.dashpaySyncronizationBlockHeight) {
            DSLog(@"%@ Unsynced identity (lastSyncBlockHeight (%u) > dashpaySyncronizationBlockHeight %u)", self.logPrefix, self.chain.lastSyncBlockHeight, identity.dashpaySyncronizationBlockHeight);
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
    if (!self.chain.isEvolutionEnabled) {
        if (completion) dispatch_async(self.chain.networkingQueue, ^{ completion(@[]); });
        return;
    }
    DSLog(@"%@ Sync Identities", self.logPrefix);
    dispatch_async(self.identityQueue, ^{
        NSArray<DSWallet *> *wallets = self.chain.wallets;

        __block dispatch_group_t keyHashesDispatchGroup = dispatch_group_create();
        __block NSMutableArray *errors = [NSMutableArray array];
        __block NSMutableArray *allIdentities = [NSMutableArray array];
        const int keysToCheck = 5;
        dispatch_async(self.chain.networkingQueue, ^{
            [self.chain.chainManager.syncState addSyncKind:DSSyncStateExtKind_Platform];
            [self.chain.chainManager.syncState.platformSyncInfo addSyncKind:DSPlatformSyncStateKind_KeyHashes];
            self.chain.chainManager.syncState.platformSyncInfo.queueCount = 0;
            self.chain.chainManager.syncState.platformSyncInfo.queueMaxAmount = keysToCheck * (uint32_t) wallets.count;
            [self.chain.chainManager notifySyncStateChanged];
       });

        for (DSWallet *wallet in wallets) {
            uint32_t unusedIndex = [wallet unusedIdentityIndex];
            DSAuthenticationKeysDerivationPath *derivationPath = [[DSDerivationPathFactory sharedInstance] identityECDSAKeysDerivationPathForWallet:wallet];
            NSMutableDictionary *keyIndexes = [NSMutableDictionary dictionaryWithCapacity:keysToCheck];
            u160 **key_hashes = malloc(keysToCheck * sizeof(u160 *));
            for (int i = 0; i < keysToCheck; i++) {
                const NSUInteger indexes[] = {(unusedIndex + i) | BIP32_HARD, 0 | BIP32_HARD};
                NSIndexPath *indexPath = [NSIndexPath indexPathWithIndexes:indexes length:2];
                NSData *publicKeyData = [derivationPath publicKeyDataAtIndexPath:indexPath];
                key_hashes[i] = u160_ctor_u(publicKeyData.hash160);
                [keyIndexes setObject:@(unusedIndex + i) forKey:publicKeyData];
            }
            dispatch_group_enter(keyHashesDispatchGroup);
            DRetry *stragegy = DRetryLinear(5);
            dash_spv_platform_identity_manager_IdentityValidator *options = DAcceptIdentityNotFound();
            
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
                Result_ok_std_collections_Map_keys_u8_arr_20_values_dpp_identity_identity_Identity_err_dash_spv_platform_error_Error *result = dash_spv_platform_identity_manager_IdentitiesManager_monitor_for_key_hashes(self.chain.sharedRuntime, self.chain.sharedIdentitiesObj, Vec_u8_20_ctor(keysToCheck, key_hashes), stragegy, options);
                            
                if (result->error) {
                    NSError *error = [NSError ffi_from_platform_error:result->error];
                    DSLog(@"%@: Sync Identities: ERROR %@", self.logPrefix, error);
                    Result_ok_std_collections_Map_keys_u8_arr_20_values_dpp_identity_identity_Identity_err_dash_spv_platform_error_Error_destroy(result);
                    [errors addObject:error];
                    dispatch_group_leave(keyHashesDispatchGroup);
                    return;
                }
                std_collections_Map_keys_u8_arr_20_values_dpp_identity_identity_Identity *ok = result->ok;
                NSMutableArray *identities = [NSMutableArray array];
                
                for (int j = 0; j < ok->count; j++) {
                    DIdentity *identity = ok->values[j];
                    switch (identity->tag) {
                        case dpp_identity_identity_Identity_V0: {
                            dpp_identity_v0_IdentityV0 *identity_v0 = identity->v0;
                            DMaybeOpaqueKey *maybe_opaque_key = DOpaqueKeyFromIdentityPubKey(identity_v0->public_keys->values[0]);
                            NSData *publicKeyData = [DSKeyManager publicKeyData:maybe_opaque_key->ok];
                            NSNumber *index = [keyIndexes objectForKey:publicKeyData];
                            DSIdentity *identityModel = [[DSIdentity alloc] initAtIndex:index.intValue uniqueId:u256_cast(identity_v0->id->_0->_0) inWallet:wallet];
                            [identityModel applyIdentity:identity save:NO inContext:nil];
                            [identities addObject:identityModel];
                            break;
                        }
                            
                        default:
                            break;
                    }
                }
                
                Result_ok_std_collections_Map_keys_u8_arr_20_values_dpp_identity_identity_Identity_err_dash_spv_platform_error_Error_destroy(result);
                BOOL success = [wallet registerIdentities:identities verify:YES];
                dispatch_async(self.chain.networkingQueue, ^{
                    self.chain.chainManager.syncState.platformSyncInfo.queueCount = keysToCheck;
                    [self.chain.chainManager notifySyncStateChanged];
                });

                DSLog(@"%@: Sync Identities: %@", self.logPrefix, DSLocalizedFormat(success ? @"OK (%lu)" :  @"Retrieved (%lu) but can't register in wallet", nil, identities.count));
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
                dispatch_group_leave(keyHashesDispatchGroup);
            });


        }
        
        dispatch_group_notify(keyHashesDispatchGroup, self.chain.networkingQueue, ^{
            [self.chain.chainManager.syncState.platformSyncInfo removeSyncKind:DSPlatformSyncStateKind_KeyHashes];
            NSArray *identities = [self unsyncedIdentities];
            NSMutableString *deb_id = [NSMutableString stringWithFormat:@"%@ Sync Identities: unsynced: ", self.logPrefix];
            for (DSIdentity *identitity in identities) {
                [deb_id appendFormat:@"%@,", uint256_hex(identitity.uniqueID)];
            }
            DSLog(@"%@", deb_id);
            NSUInteger identitiesCount = [identities count];
            if (identitiesCount) {
                self.chain.chainManager.syncState.platformSyncInfo.queueCount = 0;
                self.chain.chainManager.syncState.platformSyncInfo.queueMaxAmount = (uint32_t) identitiesCount;
                [self.chain.chainManager.syncState.platformSyncInfo addSyncKind:DSPlatformSyncStateKind_Unsynced];
            }
            [self.chain.chainManager notifySyncStateChanged];

            dispatch_group_t dispatchGroup = dispatch_group_create();
            __block NSMutableArray *errors = [NSMutableArray array];
            for (DSIdentity *identity in identities) {
                dispatch_group_enter(dispatchGroup);
                [self fetchNeededNetworkStateInformationForIdentity:identity withCompletion:^(BOOL success, DSIdentity *_Nullable identity, NSError *_Nullable error) {
                    dispatch_async(self.chain.networkingQueue, ^{
                        self.chain.chainManager.syncState.platformSyncInfo.queueCount++;
                        [self.chain.chainManager notifySyncStateChanged];
             });
                    if (success && identity != nil) {
                        dispatch_group_leave(dispatchGroup);
                    } else {
                        [errors addObject:error];
                    }
                }
                                                              completionQueue:self.identityQueue];
            }
            dispatch_group_notify(dispatchGroup, self.chain.networkingQueue, ^{
                self.lastSyncedIndentitiesTimestamp = [[NSDate date] timeIntervalSince1970];
                self.chain.chainManager.syncState.platformSyncInfo.queueCount = 0;
                self.chain.chainManager.syncState.platformSyncInfo.queueMaxAmount = 0;
                self.chain.chainManager.syncState.platformSyncInfo.lastSyncedIndentitiesTimestamp = self.lastSyncedIndentitiesTimestamp;
                [self.chain.chainManager.syncState.platformSyncInfo resetSyncKind];
                [self.chain.chainManager.syncState removeSyncKind:DSSyncStateExtKind_Platform];
                [self.chain.chainManager notifySyncStateChanged];
                if (!errors.count && completion)
                    completion(identities);
            });

        });
    });
}

- (void)searchIdentityByDashpayUsername:(NSString *)name
                         withCompletion:(IdentityCompletionBlock)completion {
    [self searchIdentityByName:name
                      inDomain:@"dash"
                withCompletion:completion];
}

- (void)searchIdentityByName:(NSString *)name
                    inDomain:(NSString *)domain
              withCompletion:(IdentityCompletionBlock)completion {
    NSMutableString *debugString = [NSMutableString stringWithFormat:@"%@ Search Identity by name: %@, domain: %@", self.logPrefix, name, domain];
    DSLog(@"%@", debugString);
    DMaybeDocumentsMap *result = dash_spv_platform_document_manager_DocumentsManager_dpns_documents_for_username(self.chain.sharedRuntime, self.chain.sharedDocumentsObj, DChar(name));
    if (result->error) {
        NSError *error = [NSError ffi_from_platform_error:result->error];
        DMaybeDocumentsMapDtor(result);
        DSLog(@"%@: ERROR: %@", debugString, error);
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, nil, error); });
        return;
    }
    
    // TODO: in wallet we have unusuable but cancelable request, so...
    __block NSMutableArray *rIdentities = [NSMutableArray array];
    DDocumentsMap *documents = result->ok;
    for (int i = 0; i < documents->count; i++) {
        DDocument *document = documents->values[i];
        DSLog(@"%@: document[%i]: ", debugString, i);
        dash_spv_platform_document_print_document(document);

        if (!document) continue;
        NSString *normalizedLabel = DGetTextDocProperty(document, @"normalizedLabel");
        NSString *domain = DGetTextDocProperty(document, @"normalizedParentDomainName");
        DIdentifier *owner_id = document->v0->owner_id;
        
        DSIdentity *identity = [[DSIdentity alloc] initWithUniqueId:u256_cast(owner_id->_0->_0) isTransient:TRUE onChain:self.chain];
        [identity addUsername:normalizedLabel inDomain:domain status:dash_spv_platform_document_usernames_UsernameStatus_Confirmed_ctor() save:NO registerOnNetwork:NO];
        [rIdentities addObject:identity];

    }
    DSLog(@"%@: OK: %@", debugString, [rIdentities firstObject]);
    if (completion)
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(YES, [rIdentities firstObject], nil);
        });
}

- (void)fetchProfileForIdentity:(DSIdentity *)identity
                 withCompletion:(DashpayUserInfoCompletionBlock)completion
              onCompletionQueue:(dispatch_queue_t)completionQueue {
    NSMutableString *debugString = [NSMutableString stringWithFormat:@"%@ Fetch Profile for: %@", self.logPrefix, identity];
    DSLog(@"%@", debugString);
    DPContract *dashpayContract = [DSDashPlatform sharedInstanceForChain:self.chain].dashPayContract;
    if ([dashpayContract contractState] != DPContractState_Registered) {
        DSLog(@"%@: ERROR: DashPay Contract Not Registered", debugString);
        if (completion) dispatch_async(completionQueue, ^{ completion(NO, nil, nil); });
        return;
    }
    DMaybeDocument *result = dash_spv_platform_document_manager_DocumentsManager_stream_dashpay_profile_for_user_id_using_contract(self.chain.sharedRuntime, self.chain.sharedDocumentsObj, u256_ctor_u(identity.uniqueID), dashpayContract.raw_contract, DRetryDown20(5), DNotFoundAsAnError(), 2000);
    if (result->error) {
        NSError *error = [NSError ffi_from_platform_error:result->error];
        DSLog(@"%@: ERROR: %@", debugString, error);
        dispatch_async(completionQueue, ^{ completion(NO, nil, error); });
        DMaybeDocumentDtor(result);
        return;
    }
    if (!result->ok) {
        DSLog(@"%@: ERROR: Profile is None", debugString);
        if (completion) dispatch_async(completionQueue, ^{ completion(YES, nil, nil); });
        DMaybeDocumentDtor(result);
        return;
   }
    DSTransientDashpayUser *transientDashpayUser = [[DSTransientDashpayUser alloc] initWithDocument:result->ok];
    DSLog(@"%@: OK: %@", debugString, transientDashpayUser);
    dispatch_async(completionQueue, ^{ if (completion) completion(YES, transientDashpayUser, nil); });
}

- (void)fetchProfilesForIdentities:(NSArray<NSData *> *)identityUserIds
                    withCompletion:(DashpayUserInfosCompletionBlock)completion
                 onCompletionQueue:(dispatch_queue_t)completionQueue {
    NSMutableString *debugString = [NSMutableString stringWithFormat:@"%@ Fetch Profiles for: %@", self.logPrefix, identityUserIds];
    DSLog(@"%@", debugString);
    DPContract *dashpayContract = [DSDashPlatform sharedInstanceForChain:self.chain].dashPayContract;
    if ([dashpayContract contractState] != DPContractState_Registered) {
        DSLog(@"%@: ERROR: DashPay Contract Not Registered", debugString);
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
    DMaybeDocumentsMap *result = dash_spv_platform_document_manager_DocumentsManager_stream_dashpay_profiles_for_user_ids_using_contract(self.chain.sharedRuntime, self.chain.sharedDocumentsObj, user_ids, dashpayContract.raw_contract, DRetryDown20(5), DNotFoundAsAnError(), 2000);
    if (result->error) {
        NSError *error = [NSError ffi_from_platform_error:result->error];
        DSLog(@"%@: ERROR: %@", debugString, error);
        if (completion) dispatch_async(completionQueue, ^{ completion(NO, nil, error); });
        DMaybeDocumentsMapDtor(result);
        return;
    }
    DDocumentsMap *documents = result->ok;
    NSMutableDictionary *dashpayUserDictionary = [NSMutableDictionary dictionary];
    for (int i = 0; i < documents->count; i++) {
        DDocument *document = documents->values[i];
        switch (document->tag) {
            case dpp_document_Document_V0: {
                DSTransientDashpayUser *transientDashpayUser = [[DSTransientDashpayUser alloc] initWithDocument:document];
                [dashpayUserDictionary setObject:transientDashpayUser forKey:NSDataFromPtr(document->v0->owner_id->_0->_0)];
                break;
            }
            default:
                break;
        }
    }
    DMaybeDocumentsMapDtor(result);
    DSLog(@"%@: OK: %@", debugString, dashpayUserDictionary);
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
    NSMutableString *debugString = [NSMutableString stringWithFormat:@"%@ Search Identities By Name Prefix: %@", self.logPrefix, namePrefix];
    DSLog(@"%@", debugString);
    DMaybeDocumentsMap *result = dash_spv_platform_document_manager_DocumentsManager_dpns_documents_for_username_prefix(self.chain.sharedRuntime, self.chain.sharedDocumentsObj, DChar(namePrefix));
    if (result->error) {
        NSError *error = [NSError ffi_from_platform_error:result->error];
        DSLog(@"%@: ERROR: %@", debugString, error);
        DMaybeDocumentsMapDtor(result);
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, nil, @[error]); });
        return;
    }
    DDocumentsMap *documents = result->ok;
    __block NSMutableDictionary *rIdentities = [NSMutableDictionary dictionary];
    for (int i = 0; i < documents->count; i++) {
        DDocument *document = documents->values[i];
        if (!document) continue;
        DSLog(@"%@: document[%i]: ", debugString, i);
        dash_spv_platform_document_print_document(document);

        switch (document->tag) {
            case dpp_document_Document_V0: {
                u256 *owner_id = document->v0->owner_id->_0->_0;
                NSData *userIdData = NSDataFromPtr(owner_id);
                UInt256 uniqueId = u256_cast(owner_id);
                DSIdentity *identity = [rIdentities objectForKey:userIdData];
                if (!identity)
                    identity = [self.chain identityForUniqueId:uniqueId foundInWallet:nil includeForeignIdentities:YES];
                NSString *label = DGetTextDocProperty(document, @"label");
                NSString *domain = DGetTextDocProperty(document, @"normalizedParentDomainName");
                if (!identity) {
                    identity = [[DSIdentity alloc] initWithUniqueId:uniqueId isTransient:TRUE onChain:self.chain];
                    [identity addUsername:label inDomain:domain status:dash_spv_platform_document_usernames_UsernameStatus_Confirmed_ctor() save:NO registerOnNetwork:NO];
                } else if (![identity hasDashpayUsername:label]) {
                    [identity addUsername:label inDomain:domain status:dash_spv_platform_document_usernames_UsernameStatus_Confirmed_ctor() save:YES registerOnNetwork:NO];
                }
                [rIdentities setObject:identity forKey:userIdData];
                break;
            }
            default:
                break;
        }
    }
    DSLog(@"%@: OK: %@", debugString, rIdentities);

    if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(YES, [[rIdentities allValues] copy], @[]); });
}

- (void)searchIdentitiesByDPNSRegisteredIdentityUniqueID:(NSData *)userID
                                          withCompletion:(IdentitiesCompletionBlock)completion {
    NSMutableString *debugString = [NSMutableString stringWithFormat:@"%@ Search Identities By DPNS identity id: %@", self.logPrefix, userID.hexString];
    DSLog(@"%@", debugString);
    DMaybeDocumentsMap *result = dash_spv_platform_document_manager_DocumentsManager_dpns_documents_for_identity_with_user_id(self.chain.sharedRuntime, self.chain.sharedDocumentsObj, u256_ctor(userID));
    if (result->error) {
        NSError *error = [NSError ffi_from_platform_error:result->error];
        DMaybeDocumentsMapDtor(result);
        DSLog(@"%@: ERROR: %@", debugString, error);
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, nil, @[error]); });
        return;
    }
    DDocumentsMap *documents = result->ok;
    __block NSMutableArray *rIdentities = [NSMutableArray array];
    for (int i = 0; i < documents->count; i++) {
        DDocument *document = documents->values[i];
        if (!document) continue;
        DSLog(@"%@: document[%i]: ", debugString, i);
        dash_spv_platform_document_print_document(document);

        switch (document->tag) {
            case dpp_document_Document_V0: {
                NSString *normalizedLabel = DGetTextDocProperty(document, @"normalizedLabel");
                NSString *domain = DGetTextDocProperty(document, @"normalizedParentDomainName");
                DSIdentity *identity = [[DSIdentity alloc] initWithUniqueId:u256_cast(document->v0->owner_id->_0->_0) isTransient:TRUE onChain:self.chain];
                [identity addUsername:normalizedLabel inDomain:domain status:dash_spv_platform_document_usernames_UsernameStatus_Confirmed_ctor() save:NO registerOnNetwork:NO];
                [identity fetchIdentityNetworkStateInformationWithCompletion:^(BOOL success, BOOL found, NSError *error) {}];
                [rIdentities addObject:identity];
                break;
            }
            default:
                break;
        }
    }
    DSLog(@"%@: OK: %@", debugString, rIdentities);
    DMaybeDocumentsMapDtor(result);
    if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(YES, [rIdentities copy], @[]); });
}

// always from chain.networkingQueue
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
    [identity fetchNeededNetworkStateInformationInContext:[NSManagedObjectContext platformContext]
                                       withCompletion:^(DSIdentityQueryStep failureStep, NSArray<NSError *> *_Nullable errors) {
        if (!failureStep || failureStep == DSIdentityQueryStep_NoIdentity) {
            //if this was never registered no need to retry
            if (completion)
                dispatch_async(completionQueue, ^{ completion(YES, identity, nil); });
        } else {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), completionQueue, ^{
                [self fetchNeededNetworkStateInformationForIdentity:identity
                                                     withCompletion:completion
                                                    completionQueue:completionQueue];
            });
        }
    }
                                    onCompletionQueue:dispatch_get_main_queue()];
}

// MARK: - DSChainIdentitiesDelegate

// always from chain.networkingQueue
- (void)chain:(DSChain *)chain didFinishInChainSyncPhaseFetchingIdentityDAPInformation:(DSIdentity *)identity {
    [self.chain.chainManager chain:chain didFinishInChainSyncPhaseFetchingIdentityDAPInformation:identity];
}

@end
