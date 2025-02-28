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
#import "DSUsernameFullPathSaveContext.h"
#import "DSWallet.h"
#import "NSArray+Dash.h"
#import "NSError+Dash.h"
#import "NSError+Platform.h"
#import "NSManagedObject+Sugar.h"
#import <objc/runtime.h>

#define DEFAULT_FETCH_USERNAMES_RETRY_COUNT 5

#define ERROR_DPNS_CONTRACT_NOT_REGISTERED [NSError errorWithCode:500 localizedDescriptionKey:@"DPNS Contract is not yet registered on network"]
#define ERROR_TRANSITION_SIGNING [NSError errorWithCode:501 localizedDescriptionKey:@"Unable to sign transition"]

NSString const *usernameStatusesKey = @"usernameStatusesKey";
NSString const *usernameSaltsKey = @"usernameSaltsKey";
NSString const *usernameDomainsKey = @"usernameDomainsKey";

void usernames_save_context_caller(const void *context, dash_spv_platform_document_usernames_UsernameStatus *status) {
    DSUsernameFullPathSaveContext *saveContext = ((__bridge DSUsernameFullPathSaveContext *)(context));
    switch (*status) {
        case dash_spv_platform_document_usernames_UsernameStatus_PreorderRegistrationPending: {
            [saveContext setAndSaveUsernameFullPaths:DSIdentityUsernameStatus_PreorderRegistrationPending];
            break;
        }
        case dash_spv_platform_document_usernames_UsernameStatus_Preordered:
            [saveContext setAndSaveUsernameFullPaths:DSIdentityUsernameStatus_Preordered];
            break;
        case dash_spv_platform_document_usernames_UsernameStatus_RegistrationPending:
            [saveContext setAndSaveUsernameFullPaths:DSIdentityUsernameStatus_RegistrationPending];
            break;
        case dash_spv_platform_document_usernames_UsernameStatus_Confirmed:
            [saveContext setAndSaveUsernameFullPaths:DSIdentityUsernameStatus_Confirmed];
            break;
        default:
            break;
    }
    dash_spv_platform_document_usernames_UsernameStatus_destroy(status);
}

@implementation DSIdentity (Username)

- (NSMutableDictionary<NSString *,NSDictionary *> *)usernameStatuses {
    return objc_getAssociatedObject(self, &usernameStatusesKey);
}
- (void)setUsernameStatuses:(NSMutableDictionary<NSString *, NSDictionary *> *)usernameStatuses {
    objc_setAssociatedObject(self, &usernameStatusesKey, usernameStatuses, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSMutableDictionary<NSString *,NSData *> *)usernameSalts {
    return objc_getAssociatedObject(self, &usernameSaltsKey);
}
- (void)setUsernameSalts:(NSMutableDictionary<NSString *, NSData *> *)usernameSalts {
    objc_setAssociatedObject(self, &usernameSaltsKey, usernameSalts, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSMutableDictionary<NSString *,NSData *> *)usernameDomains {
    return objc_getAssociatedObject(self, &usernameDomainsKey);
}
- (void)setUsernameDomains:(NSMutableDictionary<NSString *, NSData *> *)usernameDomains {
    objc_setAssociatedObject(self, &usernameDomainsKey, usernameDomains, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)setupUsernames {
    self.usernameStatuses = [NSMutableDictionary dictionary];
    self.usernameSalts = [NSMutableDictionary dictionary];
}
- (void)setupUsernames:(NSMutableDictionary *)statuses salts:(NSMutableDictionary *)salts {
    self.usernameStatuses = statuses;
    self.usernameSalts = salts;
}

- (void)applyUsernameEntitiesFromIdentityEntity:(DSBlockchainIdentityEntity *)identityEntity {
    for (DSBlockchainIdentityUsernameEntity *usernameEntity in identityEntity.usernames) {
        NSData *salt = usernameEntity.salt;
        NSString *domain = usernameEntity.domain;
        NSString *username = usernameEntity.stringValue;
        uint16_t status = usernameEntity.status;
        NSString *fullPath = [self fullPathForUsername:username inDomain:domain];
        if (salt) {
            [self.usernameStatuses setObject:@{
                BLOCKCHAIN_USERNAME_PROPER: username,
                BLOCKCHAIN_USERNAME_DOMAIN: domain ? domain : @"",
                BLOCKCHAIN_USERNAME_STATUS: @(status),
                BLOCKCHAIN_USERNAME_SALT: salt
            }
                                      forKey:fullPath];
            [self.usernameSalts setObject:salt forKey:username];
        } else {
            [self.usernameStatuses setObject:@{
                BLOCKCHAIN_USERNAME_PROPER: username,
                BLOCKCHAIN_USERNAME_DOMAIN: domain ? domain : @"",
                BLOCKCHAIN_USERNAME_STATUS: @(status)
            }
                                      forKey:fullPath];
        }
    }
}

- (void)collectUsernameEntitiesIntoIdentityEntityInContext:(DSBlockchainIdentityEntity *)identityEntity
                                                   context:(NSManagedObjectContext *)context {
    for (NSString *usernameFullPath in self.usernameStatuses) {
        DSBlockchainIdentityUsernameEntity *usernameEntity = [DSBlockchainIdentityUsernameEntity managedObjectInBlockedContext:context];
        usernameEntity.status = [self statusOfUsernameFullPath:usernameFullPath];
        usernameEntity.stringValue = [self usernameOfUsernameFullPath:usernameFullPath];
        usernameEntity.domain = [self domainOfUsernameFullPath:usernameFullPath];
        usernameEntity.blockchainIdentity = identityEntity;
        [identityEntity addUsernamesObject:usernameEntity];
        [identityEntity setDashpayUsername:usernameEntity];
    }
}

// MARK: Usernames

- (void)addDashpayUsername:(NSString *)username
                      save:(BOOL)save {
    [self addUsername:username
             inDomain:@"dash"
               status:DSIdentityUsernameStatus_Initial
                 save:save
    registerOnNetwork:YES];
}

- (void)addUsername:(NSString *)username
           inDomain:(NSString *)domain
               save:(BOOL)save {
    [self addUsername:username
             inDomain:domain
               status:DSIdentityUsernameStatus_Initial
                 save:save
    registerOnNetwork:YES];
}

- (void)addUsername:(NSString *)username
           inDomain:(NSString *)domain
             status:(DSIdentityUsernameStatus)status
               save:(BOOL)save
  registerOnNetwork:(BOOL)registerOnNetwork {
    NSString *fullPath = [self fullPathForUsername:username inDomain:domain];
    [self.usernameStatuses setObject:@{
        BLOCKCHAIN_USERNAME_STATUS: @(DSIdentityUsernameStatus_Initial),
        BLOCKCHAIN_USERNAME_PROPER: username,
        BLOCKCHAIN_USERNAME_DOMAIN: domain}
                              forKey:fullPath];
    if (save)
        dispatch_async(self.identityQueue, ^{
            [self saveNewUsername:username
                         inDomain:domain
                           status:DSIdentityUsernameStatus_Initial
                        inContext:self.platformContext];
            if (registerOnNetwork && self.registered && status != DSIdentityUsernameStatus_Confirmed)
                [self registerUsernamesWithCompletion:^(BOOL success, NSError *_Nonnull error) {}];
        });
}

- (DSIdentityUsernameStatus)statusOfUsername:(NSString *)username
                                    inDomain:(NSString *)domain {
    return [self statusOfUsernameFullPath:[self fullPathForUsername:username inDomain:domain]];
}

- (DSIdentityUsernameStatus)statusOfDashpayUsername:(NSString *)username {
    return [self statusOfUsernameFullPath:[self fullPathForUsername:username inDomain:@"dash"]];
}

- (DSIdentityUsernameStatus)statusOfUsernameFullPath:(NSString *)usernameFullPath {
    return [[[self.usernameStatuses objectForKey:usernameFullPath] objectForKey:BLOCKCHAIN_USERNAME_STATUS] unsignedIntegerValue];
}

- (NSString *)usernameOfUsernameFullPath:(NSString *)usernameFullPath {
    return [[self.usernameStatuses objectForKey:usernameFullPath] objectForKey:BLOCKCHAIN_USERNAME_PROPER];
}

- (NSString *)domainOfUsernameFullPath:(NSString *)usernameFullPath {
    return [[self.usernameStatuses objectForKey:usernameFullPath] objectForKey:BLOCKCHAIN_USERNAME_DOMAIN];
}

- (NSString *)fullPathForUsername:(NSString *)username
                         inDomain:(NSString *)domain {
    return [[username lowercaseString] stringByAppendingFormat:@".%@", [domain lowercaseString]];
}

- (NSArray<NSString *> *)dashpayUsernameFullPaths {
    return [self.usernameStatuses allKeys];
}

- (NSArray<NSString *> *)dashpayUsernames {
    NSMutableArray *usernameArray = [NSMutableArray array];
    for (NSString *usernameFullPath in self.usernameStatuses) {
        [usernameArray addObject:[self usernameOfUsernameFullPath:usernameFullPath]];
    }
    return [usernameArray copy];
}

- (NSArray<NSString *> *)unregisteredUsernameFullPaths {
    return [self usernameFullPathsWithStatus:DSIdentityUsernameStatus_Initial];
}

- (NSArray<NSString *> *)usernameFullPathsWithStatus:(DSIdentityUsernameStatus)usernameStatus {
    NSMutableArray *unregisteredUsernames = [NSMutableArray array];
    for (NSString *username in self.usernameStatuses) {
        NSDictionary *usernameInfo = self.usernameStatuses[username];
        DSIdentityUsernameStatus status = [usernameInfo[BLOCKCHAIN_USERNAME_STATUS] unsignedIntegerValue];
        if (status == usernameStatus)
            [unregisteredUsernames addObject:username];
    }
    return [unregisteredUsernames copy];
}

//- (NSArray<NSString *> *)preorderedUsernameFullPaths {
//    NSMutableArray *unregisteredUsernames = [NSMutableArray array];
//    for (NSString *username in self.usernameStatuses) {
//        NSDictionary *usernameInfo = self.usernameStatuses[username];
//        DSIdentityUsernameStatus status = [usernameInfo[BLOCKCHAIN_USERNAME_STATUS] unsignedIntegerValue];
//        if (status == DSIdentityUsernameStatus_Preordered)
//            [unregisteredUsernames addObject:username];
//    }
//    return [unregisteredUsernames copy];
//}

// MARK: Username Helpers

- (NSData *)saltForUsernameFullPath:(NSString *)usernameFullPath
                           saveSalt:(BOOL)saveSalt
                          inContext:(NSManagedObjectContext *)context {
    NSData *salt;
    if ([self statusOfUsernameFullPath:usernameFullPath] == DSIdentityUsernameStatus_Initial || !(salt = [self.usernameSalts objectForKey:usernameFullPath])) {
        salt = uint256_data(uint256_random);
        [self.usernameSalts setObject:salt forKey:usernameFullPath];
        if (saveSalt)
            [self saveUsername:[self usernameOfUsernameFullPath:usernameFullPath]
                      inDomain:[self domainOfUsernameFullPath:usernameFullPath]
                        status:[self statusOfUsernameFullPath:usernameFullPath]
                          salt:salt
                    commitSave:YES
                     inContext:context];
    } else {
        salt = [self.usernameSalts objectForKey:usernameFullPath];
    }
    return salt;
}

- (NSMutableDictionary<NSString *, NSData *> *)saltedDomainHashesForUsernameFullPaths:(NSArray *)usernameFullPaths
                                                                            inContext:(NSManagedObjectContext *)context {
    NSMutableDictionary *mSaltedDomainHashes = [NSMutableDictionary dictionary];
    for (NSString *unregisteredUsernameFullPath in usernameFullPaths) {
        NSMutableData *saltedDomain = [NSMutableData data];
        NSData *salt = [self saltForUsernameFullPath:unregisteredUsernameFullPath saveSalt:YES inContext:context];
        NSData *usernameDomainData = [unregisteredUsernameFullPath dataUsingEncoding:NSUTF8StringEncoding];
        [saltedDomain appendData:salt];
        [saltedDomain appendData:usernameDomainData];
        mSaltedDomainHashes[unregisteredUsernameFullPath] = uint256_data([saltedDomain SHA256_2]);
        [self.usernameSalts setObject:salt forKey:unregisteredUsernameFullPath];
    }
    return [mSaltedDomainHashes copy];
}

- (void)saveNewUsername:(NSString *)username
               inDomain:(NSString *)domain
                 status:(DSIdentityUsernameStatus)status
              inContext:(NSManagedObjectContext *)context {
    NSAssert([username containsString:@"."] == FALSE, @"This is most likely an error");
    NSAssert(domain, @"Domain must not be nil");
    if (self.isTransient || !self.isActive) return;
    [context performBlockAndWait:^{
        DSBlockchainIdentityEntity *entity = [self identityEntityInContext:context];
        DSBlockchainIdentityUsernameEntity *usernameEntity = [DSBlockchainIdentityUsernameEntity managedObjectInBlockedContext:context];
        usernameEntity.status = status;
        usernameEntity.stringValue = username;
        usernameEntity.salt = [self saltForUsernameFullPath:[self fullPathForUsername:username inDomain:domain] saveSalt:NO inContext:context];
        usernameEntity.domain = domain;
        [entity addUsernamesObject:usernameEntity];
        [entity setDashpayUsername:usernameEntity];
        [context ds_save];
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSIdentityDidUpdateUsernameStatusNotification
                                                                object:nil
                                                              userInfo:@{
                DSChainManagerNotificationChainKey: self.chain,
                DSIdentityKey: self
            }];
        });
    }];
}

- (void)setUsernameFullPaths:(NSArray *)usernameFullPaths
                    toStatus:(DSIdentityUsernameStatus)status {
    for (NSString *string in usernameFullPaths) {
        NSMutableDictionary *usernameStatusDictionary = [[self.usernameStatuses objectForKey:string] mutableCopy];
        if (!usernameStatusDictionary)
            usernameStatusDictionary = [NSMutableDictionary dictionary];
        usernameStatusDictionary[BLOCKCHAIN_USERNAME_STATUS] = @(status);
        [self.usernameStatuses setObject:[usernameStatusDictionary copy] forKey:string];
    }
}

- (void)setAndSaveUsernameFullPaths:(NSArray *)usernameFullPaths
                           toStatus:(DSIdentityUsernameStatus)status
                          inContext:(NSManagedObjectContext *)context {
    [self setUsernameFullPaths:usernameFullPaths toStatus:status];
    [self saveUsernamesInDictionary:[self.usernameStatuses dictionaryWithValuesForKeys:usernameFullPaths] toStatus:status inContext:context];
}

- (void)saveUsernameFullPaths:(NSArray *)usernameFullPaths
                     toStatus:(DSIdentityUsernameStatus)status
                    inContext:(NSManagedObjectContext *)context {
    [self saveUsernamesInDictionary:[self.usernameStatuses dictionaryWithValuesForKeys:usernameFullPaths] toStatus:status inContext:context];
}

- (void)saveUsernamesInDictionary:(NSDictionary<NSString *, NSDictionary *> *)fullPathUsernamesDictionary
                         toStatus:(DSIdentityUsernameStatus)status
                        inContext:(NSManagedObjectContext *)context {
    if (self.isTransient || !self.isActive) return;
    [context performBlockAndWait:^{
        for (NSString *fullPathUsername in fullPathUsernamesDictionary) {
            NSString *username = [fullPathUsernamesDictionary[fullPathUsername] objectForKey:BLOCKCHAIN_USERNAME_PROPER];
            NSString *domain = [fullPathUsernamesDictionary[fullPathUsername] objectForKey:BLOCKCHAIN_USERNAME_DOMAIN];
            [self saveUsername:username inDomain:domain status:status salt:nil commitSave:NO inContext:context];
        }
        [context ds_save];
    }];
}

- (void)saveUsernameFullPath:(NSString *)usernameFullPath
                      status:(DSIdentityUsernameStatus)status
                        salt:(NSData *)salt
                  commitSave:(BOOL)commitSave
                   inContext:(NSManagedObjectContext *)context {
    if (self.isTransient || !self.isActive) return;
    [context performBlockAndWait:^{
        DSBlockchainIdentityEntity *entity = [self identityEntityInContext:context];
        NSSet *usernamesPassingTest = [entity.usernames objectsPassingTest:^BOOL(DSBlockchainIdentityUsernameEntity *_Nonnull obj, BOOL *_Nonnull stop) {
            BOOL isEqual = [[self fullPathForUsername:obj.stringValue inDomain:obj.domain] isEqualToString:usernameFullPath];
            if (isEqual) *stop = YES;
            return isEqual;
        }];
        if ([usernamesPassingTest count]) {
            NSAssert([usernamesPassingTest count] == 1, @"There should never be more than 1");
            DSBlockchainIdentityUsernameEntity *usernameEntity = [usernamesPassingTest anyObject];
            usernameEntity.status = status;
            if (salt)
                usernameEntity.salt = salt;
            if (commitSave)
                [context ds_save];
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:DSIdentityDidUpdateUsernameStatusNotification
                                                                    object:nil
                                                                  userInfo:@{
                    DSChainManagerNotificationChainKey: self.chain,
                    DSIdentityKey: self,
                    DSIdentityUsernameKey: usernameEntity.stringValue,
                    DSIdentityUsernameDomainKey: usernameEntity.domain
                }];
            });
        }
    }];
}

- (void)saveUsername:(NSString *)username
            inDomain:(NSString *)domain
              status:(DSIdentityUsernameStatus)status
                salt:(NSData *)salt
          commitSave:(BOOL)commitSave
           inContext:(NSManagedObjectContext *)context {
    if (self.isTransient || !self.isActive) return;
    [context performBlockAndWait:^{
        DSBlockchainIdentityEntity *entity = [self identityEntityInContext:context];
        NSSet *usernamesPassingTest = [entity.usernames objectsPassingTest:^BOOL(DSBlockchainIdentityUsernameEntity *_Nonnull obj, BOOL *_Nonnull stop) {
            BOOL isEqual = [obj.stringValue isEqualToString:username];
            if (isEqual) *stop = YES;
            return isEqual;
        }];
        if ([usernamesPassingTest count]) {
            NSAssert([usernamesPassingTest count] == 1, @"There should never be more than 1");
            DSBlockchainIdentityUsernameEntity *usernameEntity = [usernamesPassingTest anyObject];
            usernameEntity.status = status;
            if (salt)
                usernameEntity.salt = salt;
            if (commitSave)
                [context ds_save];
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:DSIdentityDidUpdateUsernameStatusNotification
                                                                    object:nil
                                                                  userInfo:@{
                    DSChainManagerNotificationChainKey: self.chain,
                    DSIdentityKey: self,
                    DSIdentityUsernameKey: username,
                    DSIdentityUsernameDomainKey: domain
                }];
            });
        }
    }];
}



- (void)fetchUsernamesInContext:(NSManagedObjectContext *)context
                 withCompletion:(void (^)(BOOL success, NSError *error))completion
              onCompletionQueue:(dispatch_queue_t)completionQueue {
    NSMutableString *debugInfo = [NSMutableString stringWithFormat:@"%@: fetchUsernamesInContext", self.logPrefix];
    DSLog(@"%@", debugInfo);
    DPContract *contract = [DSDashPlatform sharedInstanceForChain:self.chain].dpnsContract;
    if (contract.contractState != DPContractState_Registered) {
        DSLog(@"%@: ERROR: %@", debugInfo, ERROR_DPNS_CONTRACT_NOT_REGISTERED);
        if (completion) dispatch_async(completionQueue, ^{ completion(NO, ERROR_DPNS_CONTRACT_NOT_REGISTERED); });
        return;
    }
    
    DMaybeDocumentsMap *result = dash_spv_platform_document_manager_DocumentsManager_stream_dpns_documents_for_identity_with_user_id_using_contract(self.chain.sharedRuntime, self.chain.shareCore.documentsManager->obj, u256_ctor_u(self.uniqueID), contract.raw_contract, DRetryLinear(DEFAULT_FETCH_USERNAMES_RETRY_COUNT), DNotFoundAsAnError(), 1000);
    if (result->error) {
        NSError *error = [NSError ffi_from_platform_error:result->error];
        DMaybeDocumentsMapDtor(result);
        DSLog(@"%@: ERROR: %@", debugInfo, error);
        if (completion) dispatch_async(completionQueue, ^{ completion(NO, error); });
        return;
    }
    DDocumentsMap *documents = result->ok;
    if (documents->count == 0) {
        DMaybeDocumentsMapDtor(result);
        DSLog(@"%@: ERROR: No documents", debugInfo);
        if (completion) dispatch_async(completionQueue, ^{ completion(YES, nil); });
        return;
    }
    [debugInfo appendFormat:@"docs: %lu", documents->count];
    for (int i = 0; i < documents->count; i++) {
        DDocument *document = documents->values[i];
        switch (document->tag) {
            case dpp_document_Document_V0: {
                NSString *username = DGetTextDocProperty(document, @"label");
                NSString *lowercaseUsername = DGetTextDocProperty(document, @"normalizedLabel");
                NSString *domain = DGetTextDocProperty(document, @"normalizedParentDomainName");
                [debugInfo appendFormat:@"\t%i: %@ -- %@ -- %@", i, username, lowercaseUsername, domain];

                if (username && lowercaseUsername && domain) {
                    NSMutableDictionary *usernameStatusDictionary = [[self.usernameStatuses objectForKey:[self fullPathForUsername:lowercaseUsername inDomain:domain]] mutableCopy];
                    BOOL isNew = FALSE;
                    if (!usernameStatusDictionary) {
                        usernameStatusDictionary = [NSMutableDictionary dictionary];
                        isNew = TRUE;
                        usernameStatusDictionary[BLOCKCHAIN_USERNAME_DOMAIN] = domain;
                        usernameStatusDictionary[BLOCKCHAIN_USERNAME_PROPER] = username;
                    }
                    usernameStatusDictionary[BLOCKCHAIN_USERNAME_STATUS] = @(DSIdentityUsernameStatus_Confirmed);
                    [self.usernameStatuses setObject:[usernameStatusDictionary copy] forKey:[self fullPathForUsername:username inDomain:domain]];
                    if (isNew) {
                        [self saveNewUsername:username
                                     inDomain:domain
                                       status:DSIdentityUsernameStatus_Confirmed
                                    inContext:context];
                    } else {
                        [self saveUsername:username
                                  inDomain:domain
                                    status:DSIdentityUsernameStatus_Confirmed
                                      salt:nil
                                commitSave:YES
                                 inContext:context];
                    }
                }

                break;
            }
            default:
                break;
        }
    }
    DSLog(@"%@: OK", debugInfo);
    DMaybeDocumentsMapDtor(result);
    if (completion) dispatch_async(completionQueue, ^{ completion(YES, nil); });
}

- (void)registerUsernamesWithCompletion:(void (^_Nullable)(BOOL success, NSError *error))completion {
    [self registerUsernamesAtStage:DSIdentityUsernameStatus_Initial
                         inContext:self.platformContext completion:completion
                 onCompletionQueue:dispatch_get_main_queue()];
}

- (void)registerUsernamesAtStage:(DSIdentityUsernameStatus)status
                       inContext:(NSManagedObjectContext *)context
                      completion:(void (^_Nullable)(BOOL success, NSError *error))completion
               onCompletionQueue:(dispatch_queue_t)completionQueue {
    NSMutableString *debugInfo = [NSMutableString stringWithFormat:@"[%@]: registerUsernamesAtStage [%lu]", self.logPrefix, (unsigned long) status];
    DSLog(@"%@", debugInfo);
    switch (status) {
        case DSIdentityUsernameStatus_Initial: {
            [debugInfo appendString:@" (Initial)"];
            NSArray *usernameFullPaths = [self usernameFullPathsWithStatus:DSIdentityUsernameStatus_Initial];
            [debugInfo appendFormat:@" usernameFullPaths: %@\n", usernameFullPaths];
            if (usernameFullPaths.count) {
                NSData *entropyData = uint256_random_data;
                NSDictionary<NSString *, NSData *> *saltedDomainHashesForUsernameFullPaths = [self saltedDomainHashesForUsernameFullPaths:usernameFullPaths inContext:context];
                [debugInfo appendFormat:@" saltedDomainHashesForUsernameFullPaths: %@\n", saltedDomainHashesForUsernameFullPaths];
                if (![saltedDomainHashesForUsernameFullPaths count]) {
                    DSLog(@"%@ ERROR: No usernamePreorderDocuments", debugInfo);
                    if (completion) dispatch_async(completionQueue, ^{ completion(NO, nil); });
                    return;
                }
                uintptr_t i = 0;
                Vec_u8 **salted_domain_hashes_values = malloc(sizeof(Vec_u8 *) * saltedDomainHashesForUsernameFullPaths.count);
                for (NSData *saltedDomainHashData in [saltedDomainHashesForUsernameFullPaths allValues]) {
                    salted_domain_hashes_values[i] = bytes_ctor(saltedDomainHashData);
                    i++;
                }
                if (!self.keysCreated) {
                    uint32_t index;
                    [self createNewKeyOfType:DKeyKindECDSA() saveKey:!self.wallet.isTransient returnIndex:&index];
                }
                DMaybeOpaqueKey *private_key = [self privateKeyAtIndex:self.currentMainKeyIndex ofType:self.currentMainKeyType];
                DSUsernameFullPathSaveContext *saveContext = [DSUsernameFullPathSaveContext contextWithUsernames:usernameFullPaths forIdentity:self inContext:context];
                Fn_ARGS_std_os_raw_c_void_dash_spv_platform_document_usernames_UsernameStatus_RTRN_ save_callback = { .caller = &usernames_save_context_caller };
                DPContract *contract = [DSDashPlatform sharedInstanceForChain:self.chain].dpnsContract;
                DMaybeStateTransitionProofResult *result = dash_spv_platform_PlatformSDK_register_preordered_salted_domain_hashes_for_username_full_paths(self.chain.sharedRuntime, self.chain.sharedPlatformObj, contract.raw_contract, u256_ctor_u(self.uniqueID), Vec_Vec_u8_ctor(i, salted_domain_hashes_values), u256_ctor(entropyData), private_key->ok, ((__bridge void *)(saveContext)), save_callback);
                if (result->error) {
                    NSError *error = [NSError ffi_from_platform_error:result->error];
                    DMaybeStateTransitionProofResultDtor(result);
                    DSLog(@"%@: ERROR: %@", debugInfo, error);
                    if (completion) dispatch_async(completionQueue, ^{ completion(NO, error); });
                    return;
                }
                DMaybeStateTransitionProofResultDtor(result);
                DSLog(@"%@: OK", debugInfo);
                if (completion)
                    dispatch_async(self.identityQueue, ^{
                        [self registerUsernamesAtStage:DSIdentityUsernameStatus_PreorderRegistrationPending
                                             inContext:context
                                            completion:completion
                                     onCompletionQueue:completionQueue];
                    });
            } else {
                DSLog(@"%@: Ok (No usernameFullPaths)", debugInfo);
                [self registerUsernamesAtStage:DSIdentityUsernameStatus_PreorderRegistrationPending
                                     inContext:context
                                    completion:completion
                             onCompletionQueue:completionQueue];
            }
            break;
        }
        case DSIdentityUsernameStatus_PreorderRegistrationPending: {
            [debugInfo appendString:@" (PreorderRegistrationPending)"];
            NSArray *usernameFullPaths = [self usernameFullPathsWithStatus:DSIdentityUsernameStatus_PreorderRegistrationPending];
            NSDictionary<NSString *, NSData *> *saltedDomainHashes = [self saltedDomainHashesForUsernameFullPaths:usernameFullPaths inContext:context];
            [debugInfo appendFormat:@" username full paths (PreorderRegistrationPending): %@, saltedDomainHashes: %@", usernameFullPaths, saltedDomainHashes];
            if (saltedDomainHashes.count) {
                Vec_Vec_u8 *vec_hashes = [NSArray ffi_to_vec_vec_u8:[saltedDomainHashes allValues]];
                DMaybeDocumentsMap *result = dash_spv_platform_document_salted_domain_hashes_SaltedDomainHashesManager_preorder_salted_domain_hashes_stream(self.chain.sharedRuntime, self.chain.shareCore.saltedDomainHashes->obj, vec_hashes, DRetryLinear(4), dash_spv_platform_document_salted_domain_hashes_SaltedDomainHashValidator_None_ctor(), 100);
                BOOL allFound = NO;
                if (result->error) {
                    NSError *error = [NSError ffi_from_platform_error:result->error];
                    DMaybeDocumentsMapDtor(result);
                    DSLog(@"%@: ERROR: %@", debugInfo, error);
                    if (completion) dispatch_async(self.identityQueue, ^{ completion(allFound, error); });
                    return;
                }
                for (NSString *usernameFullPath in saltedDomainHashes) {
                    NSData *saltedDomainHashData = saltedDomainHashes[usernameFullPath];
                    DDocumentsMap *documents = result->ok;
                    for (int i = 0; i < documents->count; i++) {
                        allFound &= [self processSaltedDomainHashDocument:usernameFullPath
                                                                     hash:saltedDomainHashData
                                                                 document:documents->values[i]
                                                                inContext:context];
                    }
                }
                DSLog(@"%@: OK: allFound: %u", debugInfo, allFound);
                DMaybeDocumentsMapDtor(result);
                if (completion)
                    dispatch_async(self.identityQueue, ^{
                        if (allFound) {
                            [self registerUsernamesAtStage:DSIdentityUsernameStatus_Preordered
                                                 inContext:context
                                                completion:completion
                                         onCompletionQueue:completionQueue];
                        } else {
                            //todo: This needs to be done per username and not for all usernames
                            [self setAndSaveUsernameFullPaths:usernameFullPaths
                                                     toStatus:DSIdentityUsernameStatus_Initial
                                                    inContext:context];
                            [self registerUsernamesAtStage:DSIdentityUsernameStatus_Initial
                                                 inContext:context
                                                completion:completion
                                         onCompletionQueue:completionQueue];
                        }
                    });
            } else {
                DSLog(@"%@: OK (No saltedDomainHashes)", debugInfo);
                [self registerUsernamesAtStage:DSIdentityUsernameStatus_Preordered
                                     inContext:context
                                    completion:completion
                             onCompletionQueue:completionQueue];
            }
            break;
        }
        case DSIdentityUsernameStatus_Preordered: {
            [debugInfo appendString:@" (Preordered)"];
            NSArray *usernameFullPaths = [self usernameFullPathsWithStatus:DSIdentityUsernameStatus_Preordered];
            [debugInfo appendFormat:@" username full paths (Preordered): %@", usernameFullPaths];
            if (usernameFullPaths.count) {
                NSError *error = nil;
                NSData *entropyData = uint256_random_data;
                NSDictionary<NSString *, NSData *> *saltedDomainHashesForUsernameFullPaths = [self saltedDomainHashesForUsernameFullPaths:usernameFullPaths inContext:context];
                if (![saltedDomainHashesForUsernameFullPaths count]) {
                    DSLog(@"%@ ERROR: No username preorder documents", debugInfo);
                    if (completion) dispatch_async(completionQueue, ^{ completion(NO, error); });
                    return;
                }

                uintptr_t i = 0;
                DValue **values_values = malloc(sizeof(Vec_platform_value_Value *) * saltedDomainHashesForUsernameFullPaths.count);
                for (NSString *usernameFullPath in saltedDomainHashesForUsernameFullPaths) {
                    NSString *username = [self usernameOfUsernameFullPath:usernameFullPath];
                    NSString *domain = [self domainOfUsernameFullPath:usernameFullPath];
                    Tuple_platform_value_Value_platform_value_Value **values = malloc(sizeof(Tuple_platform_value_Value_platform_value_Value *) * 6);
                    Tuple_platform_value_Value_platform_value_Value **records = malloc(sizeof(Tuple_platform_value_Value_platform_value_Value *) * 1);
                    Tuple_platform_value_Value_platform_value_Value **subdomain_rules = malloc(sizeof(Tuple_platform_value_Value_platform_value_Value *) * 1);
                    records[0] = Tuple_platform_value_Value_platform_value_Value_ctor(platform_value_Value_Text_ctor((char *) [@"identity" UTF8String]), platform_value_Value_Bytes_ctor(bytes_ctor(uint256_data(self.uniqueID))));
                    subdomain_rules[0] = Tuple_platform_value_Value_platform_value_Value_ctor(platform_value_Value_Text_ctor((char *) [@"allowSubdomains" UTF8String]), platform_value_Value_Bool_ctor(false));
                    values[0] = Tuple_platform_value_Value_platform_value_Value_ctor(platform_value_Value_Text_ctor((char *) [@"label" UTF8String]), platform_value_Value_Text_ctor((char *) [username UTF8String]));
                    values[1] = Tuple_platform_value_Value_platform_value_Value_ctor(platform_value_Value_Text_ctor((char *) [@"normalizedLabel" UTF8String]), platform_value_Value_Text_ctor((char *) [[username lowercaseString] UTF8String]));
                    values[2] = Tuple_platform_value_Value_platform_value_Value_ctor(platform_value_Value_Text_ctor((char *) [@"normalizedParentDomainName" UTF8String]), platform_value_Value_Text_ctor((char *) [domain UTF8String]));
                    values[3] = Tuple_platform_value_Value_platform_value_Value_ctor(platform_value_Value_Text_ctor((char *) [@"preorderSalt" UTF8String]), platform_value_Value_Bytes_ctor(bytes_ctor([self.usernameSalts objectForKey:usernameFullPath])));
                    values[4] = Tuple_platform_value_Value_platform_value_Value_ctor(platform_value_Value_Text_ctor((char *) [@"records" UTF8String]), platform_value_Value_Map_ctor(platform_value_value_map_ValueMap_ctor(Vec_Tuple_platform_value_Value_platform_value_Value_ctor(1, records))));
                    values[5] = Tuple_platform_value_Value_platform_value_Value_ctor(platform_value_Value_Text_ctor((char *) [@"subdomainRules" UTF8String]), platform_value_Value_Map_ctor(platform_value_value_map_ValueMap_ctor(Vec_Tuple_platform_value_Value_platform_value_Value_ctor(1, subdomain_rules))));
                    values_values[i] = platform_value_Value_Map_ctor(platform_value_value_map_ValueMap_ctor(Vec_Tuple_platform_value_Value_platform_value_Value_ctor(6, values)));
                    i++;
                }
                if (!self.keysCreated) {
                    uint32_t index;
                    [self createNewKeyOfType:DKeyKindECDSA() saveKey:!self.wallet.isTransient returnIndex:&index];
                }
                DMaybeOpaqueKey *private_key = [self privateKeyAtIndex:self.currentMainKeyIndex ofType:self.currentMainKeyType];
                DSUsernameFullPathSaveContext *saveContext = [DSUsernameFullPathSaveContext contextWithUsernames:usernameFullPaths forIdentity:self inContext:context];
                Fn_ARGS_std_os_raw_c_void_dash_spv_platform_document_usernames_UsernameStatus_RTRN_ save_callback = { .caller = &usernames_save_context_caller };
                DPContract *contract = [DSDashPlatform sharedInstanceForChain:self.chain].dpnsContract;
                DMaybeStateTransitionProofResult *result = dash_spv_platform_PlatformSDK_register_username_domains_for_username_full_paths(self.chain.sharedRuntime, self.chain.sharedPlatformObj, contract.raw_contract, u256_ctor_u(self.uniqueID), Vec_platform_value_Value_ctor(i, values_values), u256_ctor(entropyData), private_key->ok, ((__bridge void *)(saveContext)), save_callback);
                if (result->error) {
                    NSError *error = [NSError ffi_from_platform_error:result->error];
                    DMaybeStateTransitionProofResultDtor(result);
                    DSLog(@"%@: ERROR: %@", debugInfo, error);
                    if (completion) dispatch_async(completionQueue, ^{ completion(NO, error); });
                    return;
                }
                DMaybeStateTransitionProofResultDtor(result);
                DSLog(@"%@: OK", debugInfo);
                if (completion)
                    dispatch_async(completionQueue, ^{
                        [self registerUsernamesAtStage:DSIdentityUsernameStatus_RegistrationPending
                                             inContext:context
                                            completion:completion
                                     onCompletionQueue:completionQueue];
                    });
            } else {
                DSLog(@"%@: OK (No usernameFullPaths)", debugInfo);
                [self registerUsernamesAtStage:DSIdentityUsernameStatus_RegistrationPending
                                     inContext:context
                                    completion:completion
                             onCompletionQueue:completionQueue];
            }
            break;
        }
        case DSIdentityUsernameStatus_RegistrationPending: {
            [debugInfo appendString:@" (RegistrationPending)"];
            NSArray *usernameFullPaths = [self usernameFullPathsWithStatus:DSIdentityUsernameStatus_RegistrationPending];
            [debugInfo appendFormat:@" username full paths (RegistrationPending): %@", usernameFullPaths];
            if (usernameFullPaths.count) {
                NSMutableDictionary *domains = [NSMutableDictionary dictionary];
                for (NSString *usernameFullPath in usernameFullPaths) {
                    NSArray *components = [usernameFullPath componentsSeparatedByString:@"."];
                    NSString *domain = @"";
                    NSString *name = components[0];
                    if (components.count > 1)
                        domain = [[components subarrayWithRange:NSMakeRange(1, components.count - 1)] componentsJoinedByString:@"."];
                    if (!domains[domain])
                        domains[domain] = [NSMutableArray array];
                    [domains[domain] addObject:name];
                }
                __block BOOL finished = FALSE;
                __block NSUInteger countAllFound = 0;
                __block NSUInteger countReturned = 0;
                for (NSString *domain in domains) {
                    NSArray<NSString *> *usernames = domains[domain];
                    DPContract *contract = [DSDashPlatform sharedInstanceForChain:self.chain].dpnsContract;
                    Vec_String *usernames_vec = [NSArray ffi_to_vec_of_string:usernames];
                    DMaybeDocumentsMap *result = dash_spv_platform_document_usernames_UsernamesManager_stream_usernames_with_contract(self.chain.sharedRuntime, self.chain.shareCore.usernames->obj, (char *)[domain UTF8String], usernames_vec, contract.raw_contract, DRetryLinear(5), dash_spv_platform_document_usernames_UsernameValidator_None_ctor(), 5 * NSEC_PER_SEC);
                    
                    if (result->error) {
                        NSError *error = [NSError ffi_from_platform_error:result->error];
                        DMaybeDocumentsMapDtor(result);
                        DSLog(@"%@: ERROR: %@", debugInfo, error);
                        dispatch_async(completionQueue, ^{ completion(FALSE, error); });
                        return;
                    }
                    DDocumentsMap *documents = result->ok;
                    BOOL allDomainFound = NO;
                    
                    for (NSString *username in usernames) {
                        for (int i = 0; i < documents->count; i++) {
                            DDocument *document = documents->values[i];
                            NSString *normalizedLabel = DGetTextDocProperty(document, @"normalizedLabel");
                            NSString *label = DGetTextDocProperty(document, @"label");
                            NSString *normalizedParentDomainName = DGetTextDocProperty(document, @"normalizedParentDomainName");
                            BOOL equal = [normalizedLabel isEqualToString:[username lowercaseString]];
                            DSLog(@"%@: %u: %@ == %@", debugInfo, equal, normalizedLabel, [username lowercaseString]);
                            allDomainFound &= equal;

                            if (equal) {
                                NSMutableDictionary *usernameStatusDictionary = [[self.usernameStatuses objectForKey:username] mutableCopy];
                                if (!usernameStatusDictionary) {
                                    usernameStatusDictionary = [NSMutableDictionary dictionary];
                                    usernameStatusDictionary[BLOCKCHAIN_USERNAME_DOMAIN] = normalizedParentDomainName;
                                    usernameStatusDictionary[BLOCKCHAIN_USERNAME_PROPER] = label;
                                }
                                usernameStatusDictionary[BLOCKCHAIN_USERNAME_STATUS] = @(DSIdentityUsernameStatus_Confirmed);
                                [self.usernameStatuses setObject:[usernameStatusDictionary copy]
                                                          forKey:[self fullPathForUsername:username inDomain:@"dash"]];
                                [self saveUsername:username
                                          inDomain:normalizedParentDomainName
                                            status:DSIdentityUsernameStatus_Confirmed
                                              salt:nil
                                        commitSave:YES
                                         inContext:context];
                            }
                        }
                    }
                    DMaybeDocumentsMapDtor(result);
                    if (allDomainFound)
                        countAllFound++;
                    countReturned++;
                    if (countReturned == domains.count) {
                        finished = TRUE;
                        if (countAllFound == domains.count) {
                            dispatch_async(completionQueue, ^{ completion(YES, nil); });
                        } else {
                            //todo: This needs to be done per username and not for all usernames
                            [self setAndSaveUsernameFullPaths:usernameFullPaths
                                                     toStatus:DSIdentityUsernameStatus_Preordered
                                                    inContext:context];
                            [self registerUsernamesAtStage:DSIdentityUsernameStatus_Preordered
                                                 inContext:context
                                                completion:completion
                                         onCompletionQueue:completionQueue];
                        }
                        if (completion)
                            completion(countAllFound == domains.count, nil);
                    }
                }
                DSLog(@"%@: OK: all found (%lu) == domains (%lu)", debugInfo, countAllFound, domains.count);
                if (completion)
                    completion(countAllFound == domains.count, nil);
            } else if (completion) {
                DSLog(@"%@: OK (No usernameFullPaths)", debugInfo);
                dispatch_async(completionQueue, ^{ completion(YES, nil); });
            }
            break;
        }
        default:
            if (completion) dispatch_async(completionQueue, ^{ completion(NO, nil); });
            break;
    }
}


- (BOOL)processSaltedDomainHashDocument:(NSString *)usernameFullPath
                                   hash:(NSData *)hash
                               document:(DDocument *)document
                              inContext:(NSManagedObjectContext  *)context {
    switch (document->tag) {
        case dpp_document_Document_V0: {
            NSData *saltedDomainHash = DGetBytesDocProperty(document, @"saltedDomainHash");
            if ([saltedDomainHash isEqualToData:hash]) {
                NSMutableDictionary *usernameStatusDictionary = [[self.usernameStatuses objectForKey:usernameFullPath] mutableCopy];
                if (!usernameStatusDictionary)
                    usernameStatusDictionary = [NSMutableDictionary dictionary];
                usernameStatusDictionary[BLOCKCHAIN_USERNAME_STATUS] = @(DSIdentityUsernameStatus_Preordered);
                [self.usernameStatuses setObject:[usernameStatusDictionary copy]
                                          forKey:usernameFullPath];
                [self saveUsernameFullPath:usernameFullPath
                                    status:DSIdentityUsernameStatus_Preordered
                                      salt:nil
                                commitSave:YES
                                 inContext:context];
                return YES;
            }
            break;
        }
        default:
            break;
    }
    return NO;
}

@end
