//  
//  Created by Vladimir Pirogov
//  Copyright © 2024 Dash Core Group. All rights reserved.
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
#import "DSIdentity+Protected.h"
#import "DSIdentity+Username.h"
#import "DSChainManager.h"
#import "DSDashPlatform.h"
#import "DSWallet.h"
#import "NSArray+Dash.h"
#import "NSError+Dash.h"
#import "NSError+Platform.h"
#import "NSManagedObject+Sugar.h"

#define DEFAULT_FETCH_USERNAMES_RETRY_COUNT 5

#define ERROR_DPNS_CONTRACT_NOT_REGISTERED [NSError errorWithCode:500 localizedDescriptionKey:@"DPNS Contract is not yet registered on network"]
#define ERROR_TRANSITION_SIGNING [NSError errorWithCode:501 localizedDescriptionKey:@"Unable to sign transition"]
#define ERROR_UNSUPPORTED_DOCUMENT_VERSION(version) [NSError errorWithCode:500 descriptionKey:DSLocalizedFormat(@"Unsupported document version: %u", nil, version)]

@implementation DSIdentity (Username)

- (void)applyUsernameEntitiesFromIdentityEntity:(DSBlockchainIdentityEntity *)identityEntity {
    for (DSBlockchainIdentityUsernameEntity *usernameEntity in identityEntity.usernames) {
        NSData *saltData = usernameEntity.salt;
        NSString *domain = usernameEntity.domain;
        NSString *username = usernameEntity.stringValue;
        DUsernameStatus *status = DUsernameStatusFromIndex(usernameEntity.status);
        if (saltData) {
            u256 *salt = u256_ctor(saltData);
            dash_spv_platform_identity_model_IdentityModel_add_username_with_salt(self.model, DChar(username), DChar(domain), status, salt);
            DAddSaltForUsername(self.model, username, salt);
        } else {
            DUsernameAdd(self.model, username, domain ? domain : @"", status);
        }
    }
}

- (void)collectUsernameEntitiesIntoIdentityEntityInContext:(DSBlockchainIdentityEntity *)identityEntity
                                                   context:(NSManagedObjectContext *)context {
    DUsernameStatuses *username_statuses = dash_spv_platform_identity_model_IdentityModel_username_statuses(self.model);
    for (int i = 0; i < username_statuses->count; i++) {
        char *username_full_path = username_statuses->keys[i];
        DUsernameStatusInfo *info = username_statuses->values[i];
        DSBlockchainIdentityUsernameEntity *usernameEntity = [DSBlockchainIdentityUsernameEntity managedObjectInBlockedContext:context];
        NSString *usernameFullPath = NSStringFromPtr(username_full_path);
        usernameEntity.status = DUsernameStatusIndex(info->status);
        usernameEntity.stringValue = [self usernameOfUsernameFullPath:usernameFullPath];
        usernameEntity.domain = [self domainOfUsernameFullPath:usernameFullPath];
        usernameEntity.blockchainIdentity = identityEntity;
        [identityEntity addUsernamesObject:usernameEntity];
        [identityEntity setDashpayUsername:usernameEntity];
    }
    DUsernameStatusesDtor(username_statuses);
}

// MARK: Usernames

- (void)addDashpayUsername:(NSString *)username {
    [self addUsername:username
             inDomain:@"dash"
               status:dash_spv_platform_document_usernames_UsernameStatus_Initial];
}
- (void)addDashpayUsername:(NSString *)username
                      save:(BOOL)save {
    [self addUsername:username
             inDomain:@"dash"
               status:dash_spv_platform_document_usernames_UsernameStatus_Initial
                 save:save
    registerOnNetwork:YES];
}

- (void)addUsername:(NSString *)username
           inDomain:(NSString *)domain
               save:(BOOL)save {
    [self addUsername:username
             inDomain:domain
               status:dash_spv_platform_document_usernames_UsernameStatus_Initial
                 save:save
    registerOnNetwork:YES];
}
- (void)addConfirmedUsername:(NSString *)username
                    inDomain:(NSString *)domain {
    [self addUsername:username
             inDomain:domain
               status:dash_spv_platform_document_usernames_UsernameStatus_Confirmed];
}

- (void)addUsername:(NSString *)username
           inDomain:(NSString *)domain
             status:(DUsernameStatus)status {
    DUsernameAdd(self.model, username, domain, &status);

}

- (void)addUsername:(NSString *)username
           inDomain:(NSString *)domain
             status:(DUsernameStatus)status
               save:(BOOL)save
  registerOnNetwork:(BOOL)registerOnNetwork {
    [self addUsername:username inDomain:domain status:status];
    if (save)
        dispatch_async(self.identityQueue, ^{
            NSAssert([username containsString:@"."] == FALSE, @"This is most likely an error");
            NSAssert(domain, @"Domain must not be nil");
            if (self.isTransient || !self.isActive) return;
            NSManagedObjectContext *storageContext = self.platformContext;
            [self.platformContext performBlockAndWait:^{
                DSBlockchainIdentityEntity *entity = [self identityEntityInContext:self.platformContext];
                DSBlockchainIdentityUsernameEntity *usernameEntity = [DSBlockchainIdentityUsernameEntity managedObjectInBlockedContext:storageContext];
                usernameEntity.status = status;
                usernameEntity.stringValue = username;
                NSString *usernameFullPath = [self fullPathForUsername:username inDomain:domain];
                BOOL is_initial = dash_spv_platform_identity_model_IdentityModel_status_of_username_full_path_is_initial(self.model, DChar(usernameFullPath));
                u256 *maybe_salt = DSaltForUsername(self.model, usernameFullPath);
                if (is_initial || !maybe_salt) {
                    NSData *salt = uint256_data(uint256_random);
                    usernameEntity.salt = salt;
                    DAddSaltForUsername(self.model, usernameFullPath, u256_ctor(salt));
                } else {
                    usernameEntity.salt = NSDataFromPtr(maybe_salt);
                }
                if (maybe_salt)
                    u256_dtor(maybe_salt);
                usernameEntity.domain = domain;
                [entity addUsernamesObject:usernameEntity];
                [entity setDashpayUsername:usernameEntity];
                [storageContext ds_save];
                [self notifyUsernameUpdate:@{
                    DSChainManagerNotificationChainKey: self.chain,
                    DSIdentityKey: self
                }];
            }];
            if (registerOnNetwork && self.registered && status != dash_spv_platform_document_usernames_UsernameStatus_Confirmed)
                [self registerUsernamesWithCompletion:^(BOOL success, NSArray<NSError *> *errors) {}];
        });
}

- (DUsernameStatus *_Nullable)statusOfUsername:(NSString *)username
                                      inDomain:(NSString *)domain {
    return username ? dash_spv_platform_identity_model_IdentityModel_status_of_username(self.model, DChar(username), DChar(domain)) : nil;
}

- (DUsernameStatus *_Nullable)statusOfDashpayUsername:(NSString *)username {
    return username ? dash_spv_platform_identity_model_IdentityModel_status_of_dashpay_username(self.model, DChar(username)) : nil;
}

- (DUsernameStatus *)statusOfUsernameFullPath:(NSString *)usernameFullPath {
    return dash_spv_platform_identity_model_IdentityModel_status_of_username_full_path(self.model, DChar(usernameFullPath));
}

- (NSString *)usernameOfUsernameFullPath:(NSString *)usernameFullPath {
    char *result = dash_spv_platform_identity_model_IdentityModel_username_of_username_full_path(self.model, DChar(usernameFullPath));
    NSString *res = NSStringFromPtr(result);
    DCharDtor(result);
    return res;
}

- (NSString *)domainOfUsernameFullPath:(NSString *)usernameFullPath {
    char *result = dash_spv_platform_identity_model_IdentityModel_domain_of_username_full_path(self.model, DChar(usernameFullPath));
    NSString *res = NSStringFromPtr(result);
    DCharDtor(result);
    return res;
}

- (NSString *)fullPathForUsername:(NSString *)username
                         inDomain:(NSString *)domain {
    return [[username lowercaseString] stringByAppendingFormat:@".%@", [domain lowercaseString]];
}
- (NSUInteger)dashpayUsernameCount {
    return dash_spv_platform_identity_model_IdentityModel_dashpay_username_count(self.model);
}
- (NSArray<NSString *> *)dashpayUsernameFullPaths {
    Vec_String *result = dash_spv_platform_identity_model_IdentityModel_dashpay_username_full_paths(self.model);
    NSArray<NSString *>*arr = [NSArray ffi_from_vec_of_string:result];
    Vec_String_destroy(result);
    return arr;
}
- (BOOL)hasDashpayUsername:(NSString *)username {
    return dash_spv_platform_identity_model_IdentityModel_has_dashpay_username(self.model, DChar(username));
}
- (NSArray<NSString *> *)dashpayUsernames {
    Vec_String *result = dash_spv_platform_identity_model_IdentityModel_dashpay_usernames(self.model);
    NSArray<NSString *>*arr = [NSArray ffi_from_vec_of_string:result];
    Vec_String_destroy(result);
    return arr;
}

// MARK: Username Helpers


//- (NSMutableDictionary<NSString *, NSData *> *)saltedDomainHashesForUsernameFullPaths:(NSArray *)usernameFullPaths
//                                                                            inContext:(NSManagedObjectContext *)context {
//    NSMutableDictionary *mSaltedDomainHashes = [NSMutableDictionary dictionary];
//    for (NSString *unregisteredUsernameFullPath in usernameFullPaths) {
//        NSMutableData *saltedDomain = [NSMutableData data];
//        NSData *salt;
//        BOOL is_initial = dash_spv_platform_identity_model_IdentityModel_status_of_username_full_path_is_initial(self.model, DChar(unregisteredUsernameFullPath));
//        u256 *maybe_salt = DSaltForUsername(self.model, unregisteredUsernameFullPath);
//        if (is_initial || !maybe_salt) {
//            salt = uint256_data(uint256_random);
//            DAddSaltForUsername(self.model, unregisteredUsernameFullPath, u256_ctor(salt));
//            [self saveUsername:[self usernameOfUsernameFullPath:unregisteredUsernameFullPath]
//                      inDomain:[self domainOfUsernameFullPath:unregisteredUsernameFullPath]
//                        status:DUsernameStatusIndex([self statusOfUsernameFullPath:unregisteredUsernameFullPath])
//                          salt:salt
//                    commitSave:YES
//                     inContext:context];
//        } else {
//            salt = NSDataFromPtr(maybe_salt);
//        }
//        if (maybe_salt)
//            u256_dtor(maybe_salt);
//
//        [saltedDomain appendData:salt];
//        [saltedDomain appendData:[unregisteredUsernameFullPath dataUsingEncoding:NSUTF8StringEncoding]];
//        mSaltedDomainHashes[unregisteredUsernameFullPath] = uint256_data([saltedDomain SHA256_2]);
//        DAddSaltForUsername(self.model, unregisteredUsernameFullPath, u256_ctor(salt));
//    }
//    return [mSaltedDomainHashes copy];
//}
//
//- (void)saveNewUsername:(NSString *)username
//               inDomain:(NSString *)domain
//                 status:(uint16_t)status
//              inContext:(NSManagedObjectContext *)context {
//    NSAssert([username containsString:@"."] == FALSE, @"This is most likely an error");
//    NSAssert(domain, @"Domain must not be nil");
//    if (self.isTransient || !self.isActive) return;
//    [context performBlockAndWait:^{
//        DSBlockchainIdentityEntity *entity = [self identityEntityInContext:context];
//        DSBlockchainIdentityUsernameEntity *usernameEntity = [DSBlockchainIdentityUsernameEntity managedObjectInBlockedContext:context];
//        usernameEntity.status = status;
//        usernameEntity.stringValue = username;
//        NSString *usernameFullPath = [self fullPathForUsername:username inDomain:domain];
//        BOOL is_initial = dash_spv_platform_identity_model_IdentityModel_status_of_username_full_path_is_initial(self.model, DChar(usernameFullPath));
//        u256 *maybe_salt = DSaltForUsername(self.model, usernameFullPath);
//        if (is_initial || !maybe_salt) {
//            NSData *salt = uint256_data(uint256_random);
//            usernameEntity.salt = salt;
//            DAddSaltForUsername(self.model, usernameFullPath, u256_ctor(salt));
//        } else {
//            usernameEntity.salt = NSDataFromPtr(maybe_salt);
//        }
//        if (maybe_salt)
//            u256_dtor(maybe_salt);
//        usernameEntity.domain = domain;
//        [entity addUsernamesObject:usernameEntity];
//        [entity setDashpayUsername:usernameEntity];
//        [context ds_save];
//        [self notifyUsernameUpdate:@{
//            DSChainManagerNotificationChainKey: self.chain,
//            DSIdentityKey: self
//        }];
//    }];
//}
//
//- (void)setAndSaveUsernameFullPaths:(NSArray *)usernameFullPaths
//                           toStatus:(DUsernameStatus *)status
//                          inContext:(NSManagedObjectContext *)context {
//    Vec_String *username_full_paths = [NSArray ffi_to_vec_of_string:usernameFullPaths];
//    dash_spv_platform_identity_model_IdentityModel_set_username_full_paths(self.model, username_full_paths, status);
//    if (self.isTransient || !self.isActive) return;
//    Vec_Tuple_String_String *result = dash_spv_platform_identity_model_IdentityModel_usernames_and_domains(self.model, username_full_paths);
//    [context performBlockAndWait:^{
//        for (int i = 0; i < result->count; i++) {
//            Tuple_String_String *pair = result->values[i];
//            NSString *username = NSStringFromPtr(pair->o_0);
//            NSString *domain = NSStringFromPtr(pair->o_1);
//            [self saveUsername:username
//                      inDomain:domain
//                        status:DUsernameStatusIndex(status)
//                          salt:nil
//                    commitSave:NO
//                     inContext:context];
//        }
//        [context ds_save];
//    }];
//    Vec_Tuple_String_String_destroy(result);
//}
//
//- (void)saveUsernameFullPath:(NSString *)usernameFullPath
//                      status:(DUsernameStatus *)status
//                        salt:(NSData *)salt
//                  commitSave:(BOOL)commitSave
//                   inContext:(NSManagedObjectContext *)context {
//    if (self.isTransient || !self.isActive) return;
//    [context performBlockAndWait:^{
//        DSBlockchainIdentityEntity *entity = [self identityEntityInContext:context];
//        NSSet *usernamesPassingTest = [entity.usernames objectsPassingTest:^BOOL(DSBlockchainIdentityUsernameEntity *_Nonnull obj, BOOL *_Nonnull stop) {
//            BOOL isEqual = [[self fullPathForUsername:obj.stringValue inDomain:obj.domain] isEqualToString:usernameFullPath];
//            if (isEqual) *stop = YES;
//            return isEqual;
//        }];
//        if ([usernamesPassingTest count]) {
//            NSAssert([usernamesPassingTest count] == 1, @"There should never be more than 1");
//            DSBlockchainIdentityUsernameEntity *usernameEntity = [usernamesPassingTest anyObject];
//            usernameEntity.status = DUsernameStatusIndex(status);
//            if (salt)
//                usernameEntity.salt = salt;
//            if (commitSave)
//                [context ds_save];
//            [self notifyUsernameUpdate:@{
//                DSChainManagerNotificationChainKey: self.chain,
//                DSIdentityKey: self,
//                DSIdentityUsernameKey: usernameEntity.stringValue,
//                DSIdentityUsernameDomainKey: usernameEntity.domain
//            }];
//        }
//    }];
//}
//
//- (void)saveUsername:(NSString *)username
//            inDomain:(NSString *)domain
//              status:(uint16_t)status
//                salt:(NSData *)salt
//          commitSave:(BOOL)commitSave
//           inContext:(NSManagedObjectContext *)context {
//    if (self.isTransient || !self.isActive) return;
//    [context performBlockAndWait:^{
//        DSBlockchainIdentityEntity *entity = [self identityEntityInContext:context];
//        NSSet *usernamesPassingTest = [entity.usernames objectsPassingTest:^BOOL(DSBlockchainIdentityUsernameEntity *_Nonnull obj, BOOL *_Nonnull stop) {
//            BOOL isEqual = [obj.stringValue isEqualToString:username];
//            if (isEqual) *stop = YES;
//            return isEqual;
//        }];
//        if ([usernamesPassingTest count]) {
//            NSAssert([usernamesPassingTest count] == 1, @"There should never be more than 1");
//            DSBlockchainIdentityUsernameEntity *usernameEntity = [usernamesPassingTest anyObject];
//            usernameEntity.status = status;
//            if (salt)
//                usernameEntity.salt = salt;
//            if (commitSave)
//                [context ds_save];
//            [self notifyUsernameUpdate:@{
//                DSChainManagerNotificationChainKey: self.chain,
//                DSIdentityKey: self,
//                DSIdentityUsernameKey: username,
//                DSIdentityUsernameDomainKey: domain
//            }];
//        }
//    }];
//}



- (void)fetchUsernamesInContext:(NSManagedObjectContext *)context
                 withCompletion:(void (^)(BOOL success, NSError *error))completion
              onCompletionQueue:(dispatch_queue_t)completionQueue {
    NSMutableString *debugInfo = [NSMutableString stringWithFormat:@"%@ Fetch Usernames", self.logPrefix];
    
    
    
    
    DSLog(@"%@", debugInfo);
    DPContract *contract = [DSDashPlatform sharedInstanceForChain:self.chain].dpnsContract;
    if (contract.contractState != DPContractState_Registered) {
        DSLog(@"%@: ERROR: %@", debugInfo, ERROR_DPNS_CONTRACT_NOT_REGISTERED);
        if (completion) dispatch_async(completionQueue, ^{ completion(NO, ERROR_DPNS_CONTRACT_NOT_REGISTERED); });
        return;
    }
    
    Result_ok_bool_err_dash_spv_platform_error_Error *result = dash_spv_platform_document_manager_DocumentsManager_fetch_usernames(self.chain.sharedRuntime, self.chain.sharedDocumentsObj, self.model, contract.raw_contract, ((__bridge void *)(self)));
    if (result->error) {
        NSError *error = [NSError ffi_from_platform_error:result->error];
        Result_ok_bool_err_dash_spv_platform_error_Error_destroy(result);
//        DMaybeDocumentsMapDtor(result);
        DSLog(@"%@: ERROR: %@", debugInfo, error);
        if (completion) dispatch_async(completionQueue, ^{ completion(NO, error); });
        return;
    }
    if (completion) dispatch_async(completionQueue, ^{ completion(YES, nil); });

    
    
    
//    DMaybeDocumentsMap *result = dash_spv_platform_document_manager_DocumentsManager_stream_dpns_documents_for_identity_with_user_id_using_contract(self.chain.sharedRuntime, self.chain.sharedDocumentsObj, u256_ctor_u(self.uniqueID), contract.raw_contract, DRetryLinear(DEFAULT_FETCH_USERNAMES_RETRY_COUNT), DNotFoundAsAnError(), 1000);
//    if (result->error) {
//        NSError *error = [NSError ffi_from_platform_error:result->error];
//        DMaybeDocumentsMapDtor(result);
//        DSLog(@"%@: ERROR: %@", debugInfo, error);
//        if (completion) dispatch_async(completionQueue, ^{ completion(NO, error); });
//        return;
//    }
//    DDocumentsMap *documents = result->ok;
//    if (documents->count == 0) {
//        DMaybeDocumentsMapDtor(result);
//        DSLog(@"%@: ERROR: No documents", debugInfo);
//        if (completion) dispatch_async(completionQueue, ^{ completion(YES, nil); });
//        return;
//    }
//    [debugInfo appendFormat:@"docs: %lu", documents->count];
//    for (int i = 0; i < documents->count; i++) {
//        DDocument *document = documents->values[i];
//        switch (document->tag) {
//            case dpp_document_Document_V0: {
//                NSString *username = DGetTextDocProperty(document, @"label");
//                NSString *lowercaseUsername = DGetTextDocProperty(document, @"normalizedLabel");
//                NSString *domain = DGetTextDocProperty(document, @"normalizedParentDomainName");
//                [debugInfo appendFormat:@"\t%i: %@ -- %@ -- %@", i, username, lowercaseUsername, domain];
//
//                if (username && lowercaseUsername && domain) {
//                    BOOL isNew = dash_spv_platform_identity_model_IdentityModel_set_username_status_confirmed2(self.model, DChar(username), DChar(domain), DChar(lowercaseUsername));
//                    if (isNew) {
//                        [self saveNewUsername:username
//                                     inDomain:domain
//                                       status:dash_spv_platform_document_usernames_UsernameStatus_Confirmed
//                                    inContext:context];
//                    } else {
//                        [self saveUsername:username
//                                  inDomain:domain
//                                    status:dash_spv_platform_document_usernames_UsernameStatus_Confirmed
//                                      salt:nil
//                                commitSave:YES
//                                 inContext:context];
//                    }
//                }
//
//                break;
//            }
//            default:
//                break;
//        }
//    }
//    DSLog(@"%@: OK", debugInfo);
//    DMaybeDocumentsMapDtor(result);
//    if (completion) dispatch_async(completionQueue, ^{ completion(YES, nil); });
}

- (void)registerUsernamesWithCompletion:(void (^_Nullable)(BOOL success, NSArray<NSError *> *errors))completion {
    [self registerUsernamesAtStage:dash_spv_platform_document_usernames_UsernameStatus_Initial_ctor()
                         inContext:self.platformContext
                        completion:completion
                 onCompletionQueue:dispatch_get_main_queue()];
}

//- (NSError *_Nullable)registerUsernameWithSaltedDomainHash:(NSData *)saltedDomainHashData
//                                             usingContract:(DDataContract *)contract
//                                            andEntropyData:(NSData *)entropyData
//                                     withIdentityPublicKey:(DIdentityPublicKey *)identity_public_key
//                                            withPrivateKey:(DMaybeOpaqueKey *)maybe_private_key {
//    NSMutableString *debugInfo = [NSMutableString stringWithFormat:@"[%@] Register Username With SaltedDomainHash [%@]", self.logPrefix, saltedDomainHashData.hexString];
//    DDocumentResult *result = dash_spv_platform_PlatformSDK_register_preordered_salted_domain_hash_for_username_full_path(self.chain.sharedRuntime, self.chain.sharedPlatformObj, contract, u256_ctor_u(self.uniqueID), identity_public_key, bytes_ctor(saltedDomainHashData), u256_ctor(entropyData));
//    if (result->error) {
//        NSError *error = [NSError ffi_from_platform_error:result->error];
//        DDocumentResultDtor(result);
//        DSLog(@"%@: ERROR: (%@)", debugInfo, error);
//        return error;
//    }
//    DDocument *document = result->ok;
//    switch (document->tag) {
//        case dpp_document_Document_V0: {
//            DSLog(@"%@: OK: (%@)", debugInfo, u256_hex(document->v0->id->_0->_0));
//            DDocumentResultDtor(result);
//            return nil;
//        }
//        default: {
//            NSError *error = ERROR_UNSUPPORTED_DOCUMENT_VERSION(document->tag);
//            DSLog(@"%@: ERROR: (%@)", debugInfo, error);
//            DDocumentResultDtor(result);
//            return error;
//        }
//    }
//}

- (void)registerUsernamesAtStage:(DUsernameStatus *)status
                       inContext:(NSManagedObjectContext *)context
                      completion:(void (^_Nullable)(BOOL success, NSArray<NSError *> *errors))completion
               onCompletionQueue:(dispatch_queue_t)completionQueue {
    NSMutableString *debugInfo = [NSMutableString stringWithFormat:@"%@ Register Usernames At Stage [%hhu]", self.logPrefix, DUsernameStatusIndex(status)];

    Result_ok_bool_err_dash_spv_platform_error_Error *result = dash_spv_platform_PlatformSDK_register_usernames_at_stage(self.chain.sharedRuntime, self.chain.sharedPlatformObj, self.model, status, ((__bridge void *)(context)));
    
    
    if (result->error) {
        switch (result->error->tag) {
            case dash_spv_platform_error_Error_UsernameRegistrationError: {
                DUsernameStatus *next_status = dash_spv_platform_document_usernames_UsernameStatus_next_status(status);
                BOOL proceedToNext = result->error->username_registration_error->tag != dash_spv_platform_identity_username_registration_error_UsernameRegistrationError_NotSupported && next_status != nil;
                Result_ok_bool_err_dash_spv_platform_error_Error_destroy(result);
                if (proceedToNext) {
                    [self registerUsernamesAtStage:next_status inContext:context completion:completion onCompletionQueue:completionQueue];
                } else {
                    if (completion) dispatch_async(completionQueue, ^{ completion(NO, nil); });
                }
                break;
            }
            default: {
                Result_ok_bool_err_dash_spv_platform_error_Error_destroy(result);
                if (completion) dispatch_async(completionQueue, ^{ completion(NO, nil); });
                break;
            }
        }
        return;
    }
    DUsernameStatus *next_status = dash_spv_platform_document_usernames_UsernameStatus_next_status(status);
    BOOL ok = result->ok[0];
    Result_ok_bool_err_dash_spv_platform_error_Error_destroy(result);
    if (next_status) {
        [self registerUsernamesAtStage:next_status inContext:context completion:completion onCompletionQueue:completionQueue];
    } else {
        if (completion) dispatch_async(completionQueue, ^{ completion(ok, nil); });
    }
    
    
//    Vec_String *result = dash_spv_platform_identity_model_IdentityModel_username_full_paths_with_status(self.model, status);
//    NSArray *usernameFullPaths = [NSArray ffi_from_vec_of_string:result];
//    Vec_String_destroy(result);
//
//    uint8_t status_index = DUsernameStatusIndex(status);
//    switch (status_index) {
//        case dash_spv_platform_document_usernames_UsernameStatus_Initial: {
//            [debugInfo appendFormat:@" (Initial) usernameFullPaths: %@\n", usernameFullPaths];
//            if (usernameFullPaths.count) {
//                NSDictionary<NSString *, NSData *> *saltedDomainHashesForUsernameFullPaths = [self saltedDomainHashesForUsernameFullPaths:usernameFullPaths inContext:context];
//                [debugInfo appendFormat:@" saltedDomainHashesForUsernameFullPaths: %@\n", saltedDomainHashesForUsernameFullPaths];
//                if (![saltedDomainHashesForUsernameFullPaths count]) {
//                    DSLog(@"%@ ERROR: No usernamePreorderDocuments", debugInfo);
//                    if (completion) dispatch_async(completionQueue, ^{ completion(NO, nil); });
//                    return;
//                }
//
//                if (!self.keysCreated) {
//                    uint32_t index;
//                    [self createNewKeyOfType:DKeyKindECDSA()
//                               securityLevel:DSecurityLevelHigh()
//                                     purpose:DPurposeAuth()
//                                     saveKey:!self.wallet.isTransient
//                                 returnIndex:&index];
//                }
//
//                DSecurityLevel *level = DSecurityLevelHigh();
//                DPurpose *purpose = DPurposeAuth();
//                DIdentityPublicKey *maybe_identity_public_key = [self firstIdentityPublicKeyOfSecurityLevel:level andPurpose:purpose];
//                if (!maybe_identity_public_key) {
//                    DSecurityLevelDtor(level);
//                    DPurposeDtor(purpose);
//                    NSAssert(NULL, @"Key with security_level: HIGH and purpose: AUTHENTICATION should exist");
//                }
//
//                uintptr_t i = 0;
//                NSData *entropyData = uint256_random_data;
//                DDataContract *contract = [DSDashPlatform sharedInstanceForChain:self.chain].dpnsRawContract;
//                DMaybeOpaqueKey *private_key = [self privateKeyAtIndex:self.currentMainKeyIndex ofType:self.currentMainKeyType];
//
//                NSMutableArray<NSError *> *errors = [NSMutableArray array];
//                for (NSData *saltedDomainHashData in [saltedDomainHashesForUsernameFullPaths allValues]) {
//                    
//                    NSError *error = [self registerUsernameWithSaltedDomainHash:saltedDomainHashData
//                                                                  usingContract:contract
//                                                                 andEntropyData:entropyData
//                                                          withIdentityPublicKey:maybe_identity_public_key
//                                                                 withPrivateKey:private_key];
//                    if (error) [errors addObject:error];
//                    i++;
//                }
//                if ([errors count]) {
//                    if (completion) dispatch_async(completionQueue, ^{ completion(NO, [errors copy]); });
//                    return;
//                }
//                DSLog(@"%@: OK", debugInfo);
//                if (completion)
//                    dispatch_async(self.identityQueue, ^{
//                        [self registerUsernamesAtStage:dash_spv_platform_document_usernames_UsernameStatus_PreorderRegistrationPending_ctor()
//                                             inContext:context
//                                            completion:completion
//                                     onCompletionQueue:completionQueue];
//                    });
//            } else {
//                DSLog(@"%@: Ok (No usernameFullPaths)", debugInfo);
//                [self registerUsernamesAtStage:dash_spv_platform_document_usernames_UsernameStatus_PreorderRegistrationPending_ctor()
//                                     inContext:context
//                                    completion:completion
//                             onCompletionQueue:completionQueue];
//            }
//            break;
//        }
////        case DSIdentityUsernameStatus_Initial: {
////            [debugInfo appendFormat:@" (Initial) usernameFullPaths: %@\n", usernameFullPaths];
////            if (usernameFullPaths.count) {
////                NSData *entropyData = uint256_random_data;
////                NSDictionary<NSString *, NSData *> *saltedDomainHashesForUsernameFullPaths = [self saltedDomainHashesForUsernameFullPaths:usernameFullPaths inContext:context];
////                [debugInfo appendFormat:@" saltedDomainHashesForUsernameFullPaths: %@\n", saltedDomainHashesForUsernameFullPaths];
////                if (![saltedDomainHashesForUsernameFullPaths count]) {
////                    DSLog(@"%@ ERROR: No usernamePreorderDocuments", debugInfo);
////                    if (completion) dispatch_async(completionQueue, ^{ completion(NO, nil); });
////                    return;
////                }
////                uintptr_t i = 0;
////                Vec_u8 **salted_domain_hashes_values = malloc(sizeof(Vec_u8 *) * saltedDomainHashesForUsernameFullPaths.count);
////                for (NSData *saltedDomainHashData in [saltedDomainHashesForUsernameFullPaths allValues]) {
////                    salted_domain_hashes_values[i] = bytes_ctor(saltedDomainHashData);
////                    i++;
////                }
////                if (!self.keysCreated) {
////                    uint32_t index;
////                    [self createNewKeyOfType:DKeyKindECDSA() saveKey:!self.wallet.isTransient returnIndex:&index];
////                }
////                DMaybeOpaqueKey *private_key = [self privateKeyAtIndex:self.currentMainKeyIndex ofType:self.currentMainKeyType];
////                DSUsernameFullPathSaveContext *saveContext = [DSUsernameFullPathSaveContext contextWithUsernames:usernameFullPaths forIdentity:self inContext:context];
////                DUsernameStatusCallback save_callback = { .caller = &usernames_save_context_caller };
////                DPContract *contract = [DSDashPlatform sharedInstanceForChain:self.chain].dpnsContract;
////                DMaybeStateTransitionProofResult *result = dash_spv_platform_PlatformSDK_register_preordered_salted_domain_hashes_for_username_full_paths(self.chain.sharedRuntime, self.chain.sharedPlatformObj, contract.raw_contract, u256_ctor_u(self.uniqueID), Vec_Vec_u8_ctor(i, salted_domain_hashes_values), u256_ctor(entropyData), private_key->ok, ((__bridge void *)(saveContext)), save_callback);
////                if (result->error) {
////                    NSError *error = [NSError ffi_from_platform_error:result->error];
////                    DMaybeStateTransitionProofResultDtor(result);
////                    DSLog(@"%@: ERROR: %@", debugInfo, error);
////                    if (completion) dispatch_async(completionQueue, ^{ completion(NO, error); });
////                    return;
////                }
////                DMaybeStateTransitionProofResultDtor(result);
////                DSLog(@"%@: OK", debugInfo);
////                if (completion)
////                    dispatch_async(self.identityQueue, ^{
////                        [self registerUsernamesAtStage:DSIdentityUsernameStatus_PreorderRegistrationPending
////                                             inContext:context
////                                            completion:completion
////                                     onCompletionQueue:completionQueue];
////                    });
////            } else {
////                DSLog(@"%@: Ok (No usernameFullPaths)", debugInfo);
////                [self registerUsernamesAtStage:DSIdentityUsernameStatus_PreorderRegistrationPending
////                                     inContext:context
////                                    completion:completion
////                             onCompletionQueue:completionQueue];
////            }
////            break;
////        }
//        case dash_spv_platform_document_usernames_UsernameStatus_PreorderRegistrationPending: {
//            [debugInfo appendFormat:@" (PreorderRegistrationPending) usernameFullPaths: %@", usernameFullPaths];
//            NSDictionary<NSString *, NSData *> *saltedDomainHashes = [self saltedDomainHashesForUsernameFullPaths:usernameFullPaths inContext:context];
//            [debugInfo appendFormat:@", saltedDomainHashes: %@", saltedDomainHashes];
//            if (saltedDomainHashes.count) {
//                Vec_u8_32 *vec_hashes = [NSArray ffi_to_vec_u256:[saltedDomainHashes allValues]];
//                DMaybeDocumentsMap *result = dash_spv_platform_document_salted_domain_hashes_SaltedDomainHashesManager_preorder_salted_domain_hashes_stream(self.chain.sharedRuntime, self.chain.sharedSaltedDomainHashesObj, vec_hashes, DRetryLinear(4), dash_spv_platform_document_salted_domain_hashes_SaltedDomainHashValidator_None_ctor(), 100);
//                BOOL allFound = NO;
//                if (result->error) {
//                    NSError *error = [NSError ffi_from_platform_error:result->error];
//                    DMaybeDocumentsMapDtor(result);
//                    DSLog(@"%@: ERROR: %@", debugInfo, error);
//                    if (completion) dispatch_async(self.identityQueue, ^{ completion(allFound, @[error]); });
//                    return;
//                }
//                for (NSString *usernameFullPath in saltedDomainHashes) {
//                    NSData *saltedDomainHashData = saltedDomainHashes[usernameFullPath];
//                    DDocumentsMap *documents = result->ok;
//                    for (int i = 0; i < documents->count; i++) {
//                        allFound &= [self processSaltedDomainHashDocument:usernameFullPath
//                                                                     hash:saltedDomainHashData
//                                                                 document:documents->values[i]
//                                                                inContext:context];
//                    }
//                }
//                DSLog(@"%@: OK: allFound: %u", debugInfo, allFound);
//                DMaybeDocumentsMapDtor(result);
//                if (completion)
//                    dispatch_async(self.identityQueue, ^{
//                        if (allFound) {
//                            [self registerUsernamesAtStage:dash_spv_platform_document_usernames_UsernameStatus_Preordered_ctor()
//                                                 inContext:context
//                                                completion:completion
//                                         onCompletionQueue:completionQueue];
//                        } else {
//                            //todo: This needs to be done per username and not for all usernames
//                            [self setAndSaveUsernameFullPaths:usernameFullPaths
//                                                     toStatus:dash_spv_platform_document_usernames_UsernameStatus_Initial_ctor()
//                                                    inContext:context];
//                            [self registerUsernamesAtStage:dash_spv_platform_document_usernames_UsernameStatus_Initial_ctor()
//                                                 inContext:context
//                                                completion:completion
//                                         onCompletionQueue:completionQueue];
//                        }
//                    });
//            } else {
//                DSLog(@"%@: OK (No saltedDomainHashes)", debugInfo);
//                [self registerUsernamesAtStage:dash_spv_platform_document_usernames_UsernameStatus_Preordered_ctor()
//                                     inContext:context
//                                    completion:completion
//                             onCompletionQueue:completionQueue];
//            }
//            break;
//        }
//        case dash_spv_platform_document_usernames_UsernameStatus_Preordered: {
//            [debugInfo appendFormat:@" (Preordered) usernameFullPaths: %@: ", usernameFullPaths];
//            if (usernameFullPaths.count) {
//                NSError *error = nil;
//                NSData *entropyData = uint256_random_data;
//                NSDictionary<NSString *, NSData *> *saltedDomainHashesForUsernameFullPaths = [self saltedDomainHashesForUsernameFullPaths:usernameFullPaths inContext:context];
//                if (![saltedDomainHashesForUsernameFullPaths count]) {
//                    DSLog(@"%@ ERROR: No username preorder documents", debugInfo);
//                    if (completion) dispatch_async(completionQueue, ^{ completion(NO, @[error]); });
//                    return;
//                }
//
//                uintptr_t i = 0;
//                DValue **values_values = malloc(sizeof(DValue *) * saltedDomainHashesForUsernameFullPaths.count);
//                for (NSString *usernameFullPath in saltedDomainHashesForUsernameFullPaths) {
//                    NSString *username = [self usernameOfUsernameFullPath:usernameFullPath];
//                    NSString *domain = [self domainOfUsernameFullPath:usernameFullPath];
//                    DValuePair **values = malloc(sizeof(DValuePair *) * 6);
//                    DValuePair **records = malloc(sizeof(DValuePair *) * 1);
//                    DValuePair **subdomain_rules = malloc(sizeof(DValuePair *) * 1);
//                    records[0] = DValueTextBytesPairCtor(@"identity", uint256_data(self.uniqueID));
//                    subdomain_rules[0] = DValueTextBoolPairCtor(@"allowSubdomains", false);
//                    values[0] = DValueTextTextPairCtor(@"label", username);
//                    values[1] = DValueTextTextPairCtor(@"normalizedLabel", [username lowercaseString]);
//                    values[2] = DValueTextTextPairCtor(@"normalizedParentDomainName", domain);
//                    values[3] = DValueTextPairCtor(@"preorderSalt", platform_value_Value_Bytes32_ctor(DSaltForUsername(self.model, usernameFullPath)));
//                    values[4] = DValueTextMapPairCtor(@"records", DValueMapCtor(DValuePairVecCtor(1, records)));
//                    values[5] = DValueTextMapPairCtor(@"subdomainRules", DValueMapCtor(DValuePairVecCtor(1, subdomain_rules)));
//                    values_values[i] = platform_value_Value_Map_ctor(DValueMapCtor(DValuePairVecCtor(6, values)));
//                    i++;
//                }
//                if (!self.keysCreated) {
//                    uint32_t index;
//                    [self createNewKeyOfType:DKeyKindECDSA()
//                               securityLevel:DSecurityLevelMaster()
//                                     purpose:DPurposeAuth()
//                                     saveKey:!self.wallet.isTransient
//                                 returnIndex:&index];
//                }
//                DMaybeOpaqueKey *private_key = [self privateKeyAtIndex:self.currentMainKeyIndex ofType:self.currentMainKeyType];
//                DSUsernameFullPathSaveContext *saveContext = [DSUsernameFullPathSaveContext contextWithUsernames:usernameFullPaths forIdentity:self inContext:context];
//                DUsernameStatusCallback save_callback = { .caller = &usernames_save_context_caller };
//                DPContract *contract = [DSDashPlatform sharedInstanceForChain:self.chain].dpnsContract;
//                DMaybeStateTransitionProofResult *result = dash_spv_platform_PlatformSDK_register_username_domains_for_username_full_paths(self.chain.sharedRuntime, self.chain.sharedPlatformObj, contract.raw_contract, u256_ctor_u(self.uniqueID), DValueVecCtor(i, values_values), u256_ctor(entropyData), private_key->ok, ((__bridge void *)(saveContext)), save_callback);
//                if (result->error) {
//                    NSError *error = [NSError ffi_from_platform_error:result->error];
//                    DMaybeStateTransitionProofResultDtor(result);
//                    DSLog(@"%@: ERROR: %@", debugInfo, error);
//                    if (completion) dispatch_async(completionQueue, ^{ completion(NO, @[error]); });
//                    return;
//                }
//                DMaybeStateTransitionProofResultDtor(result);
//                DSLog(@"%@: OK", debugInfo);
//                if (completion)
//                    dispatch_async(completionQueue, ^{
//                        [self registerUsernamesAtStage:dash_spv_platform_document_usernames_UsernameStatus_RegistrationPending_ctor()
//                                             inContext:context
//                                            completion:completion
//                                     onCompletionQueue:completionQueue];
//                    });
//            } else {
//                DSLog(@"%@: OK (No usernameFullPaths)", debugInfo);
//                [self registerUsernamesAtStage:dash_spv_platform_document_usernames_UsernameStatus_RegistrationPending_ctor()
//                                     inContext:context
//                                    completion:completion
//                             onCompletionQueue:completionQueue];
//            }
//            break;
//        }
//        case dash_spv_platform_document_usernames_UsernameStatus_RegistrationPending: {
//            [debugInfo appendFormat:@" (RegistrationPending) usernameFullPaths: %@", usernameFullPaths];
//            if (usernameFullPaths.count) {
//                NSMutableDictionary *domains = [NSMutableDictionary dictionary];
//                for (NSString *usernameFullPath in usernameFullPaths) {
//                    NSArray *components = [usernameFullPath componentsSeparatedByString:@"."];
//                    NSString *domain = @"";
//                    NSString *name = components[0];
//                    if (components.count > 1)
//                        domain = [[components subarrayWithRange:NSMakeRange(1, components.count - 1)] componentsJoinedByString:@"."];
//                    if (!domains[domain])
//                        domains[domain] = [NSMutableArray array];
//                    [domains[domain] addObject:name];
//                }
//                __block BOOL finished = FALSE;
//                __block NSUInteger countAllFound = 0;
//                __block NSUInteger countReturned = 0;
//                DPContract *contract = [DSDashPlatform sharedInstanceForChain:self.chain].dpnsContract;
//                for (NSString *domain in domains) {
//                    NSArray<NSString *> *usernames = domains[domain];
//                    Vec_String *usernames_vec = [NSArray ffi_to_vec_of_string:usernames];
//                    DMaybeDocumentsMap *result = dash_spv_platform_document_usernames_UsernamesManager_stream_usernames_with_contract(self.chain.sharedRuntime, self.chain.shareCore.usernames->obj, DChar(domain), usernames_vec, contract.raw_contract, DRetryLinear(5), dash_spv_platform_document_usernames_UsernameValidator_None_ctor(), 5 * NSEC_PER_SEC);
//                    
//                    if (result->error) {
//                        NSError *error = [NSError ffi_from_platform_error:result->error];
//                        DMaybeDocumentsMapDtor(result);
//                        DSLog(@"%@: ERROR: %@", debugInfo, error);
//                        dispatch_async(completionQueue, ^{ completion(FALSE, @[error]); });
//                        return;
//                    }
//                    DDocumentsMap *documents = result->ok;
//                    BOOL allDomainFound = NO;
//                    
//                    for (NSString *username in usernames) {
//                        for (int i = 0; i < documents->count; i++) {
//                            DDocument *document = documents->values[i];
//                            NSString *normalizedLabel = DGetTextDocProperty(document, @"normalizedLabel");
//                            NSString *label = DGetTextDocProperty(document, @"label");
//                            NSString *normalizedParentDomainName = DGetTextDocProperty(document, @"normalizedParentDomainName");
//                            BOOL equal = [normalizedLabel isEqualToString:[username lowercaseString]];
//                            DSLog(@"%@: %u: %@ == %@", debugInfo, equal, normalizedLabel, [username lowercaseString]);
//                            allDomainFound &= equal;
//
//                            if (equal) {
//                                dash_spv_platform_identity_model_IdentityModel_set_username_status_confirmed(self.model, DChar(username), DChar(normalizedParentDomainName), DChar(label));
//                                [self saveUsername:username
//                                          inDomain:normalizedParentDomainName
//                                            status:dash_spv_platform_document_usernames_UsernameStatus_Confirmed
//                                              salt:nil
//                                        commitSave:YES
//                                         inContext:context];
//                            }
//                        }
//                    }
//                    DMaybeDocumentsMapDtor(result);
//                    if (allDomainFound)
//                        countAllFound++;
//                    countReturned++;
//                    if (countReturned == domains.count) {
//                        finished = TRUE;
//                        if (countAllFound == domains.count) {
//                            dispatch_async(completionQueue, ^{ completion(YES, nil); });
//                        } else {
//                            //todo: This needs to be done per username and not for all usernames
//                            [self setAndSaveUsernameFullPaths:usernameFullPaths
//                                                     toStatus:dash_spv_platform_document_usernames_UsernameStatus_Preordered_ctor()
//                                                    inContext:context];
//                            [self registerUsernamesAtStage:dash_spv_platform_document_usernames_UsernameStatus_Preordered_ctor()
//                                                 inContext:context
//                                                completion:completion
//                                         onCompletionQueue:completionQueue];
//                        }
//                        if (completion)
//                            completion(countAllFound == domains.count, nil);
//                    }
//                }
//                DSLog(@"%@: OK: all found (%lu) == domains (%lu)", debugInfo, countAllFound, domains.count);
//                if (completion)
//                    completion(countAllFound == domains.count, nil);
//            } else if (completion) {
//                DSLog(@"%@: OK (No usernameFullPaths)", debugInfo);
//                dispatch_async(completionQueue, ^{ completion(YES, nil); });
//            }
//            break;
//        }
//        default:
//            if (completion) dispatch_async(completionQueue, ^{ completion(NO, nil); });
//            break;
//    }
}
//
//
//- (BOOL)processSaltedDomainHashDocument:(NSString *)usernameFullPath
//                                   hash:(NSData *)hash
//                               document:(DDocument *)document
//                              inContext:(NSManagedObjectContext  *)context {
//    switch (document->tag) {
//        case dpp_document_Document_V0: {
//            NSData *saltedDomainHash = DGetBytesDocProperty(document, @"saltedDomainHash");
//            if ([saltedDomainHash isEqualToData:hash]) {
//                DUsernameStatus *status = dash_spv_platform_document_usernames_UsernameStatus_Preordered_ctor();
//                dash_spv_platform_identity_model_IdentityModel_set_username_status(self.model, DChar(usernameFullPath), status);
//                [self saveUsernameFullPath:usernameFullPath
//                                    status:status
//                                      salt:nil
//                                commitSave:YES
//                                 inContext:context];
//                return YES;
//            }
//            break;
//        }
//        default:
//            break;
//    }
//    return NO;
//}

- (void)notifyUsernameUpdate:(nullable NSDictionary *)userInfo {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DSIdentityDidUpdateUsernameStatusNotification
                                                            object:nil
                                                          userInfo:userInfo];
    });

}
@end
