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
        if (salt) {
            [self.usernameStatuses setObject:@{BLOCKCHAIN_USERNAME_PROPER: usernameEntity.stringValue, BLOCKCHAIN_USERNAME_DOMAIN: usernameEntity.domain ? usernameEntity.domain : @"", BLOCKCHAIN_USERNAME_STATUS: @(usernameEntity.status), BLOCKCHAIN_USERNAME_SALT: usernameEntity.salt} forKey:[self fullPathForUsername:usernameEntity.stringValue inDomain:usernameEntity.domain]];
            [self.usernameSalts setObject:usernameEntity.salt forKey:usernameEntity.stringValue];
        } else {
            [self.usernameStatuses setObject:@{BLOCKCHAIN_USERNAME_PROPER: usernameEntity.stringValue, BLOCKCHAIN_USERNAME_DOMAIN: usernameEntity.domain ? usernameEntity.domain : @"", BLOCKCHAIN_USERNAME_STATUS: @(usernameEntity.status)} forKey:[self fullPathForUsername:usernameEntity.stringValue inDomain:usernameEntity.domain]];
        }
    }
}

- (void)collectUsernameEntitiesIntoIdentityEntityInContext:(DSBlockchainIdentityEntity *)identityEntity context:(NSManagedObjectContext *)context {
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
    [self.usernameStatuses setObject:@{
        BLOCKCHAIN_USERNAME_STATUS: @(DSIdentityUsernameStatus_Initial),
        BLOCKCHAIN_USERNAME_PROPER: username,
        BLOCKCHAIN_USERNAME_DOMAIN: domain}
                              forKey:[self fullPathForUsername:username inDomain:domain]];
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

- (NSArray<NSString *> *)preorderedUsernameFullPaths {
    NSMutableArray *unregisteredUsernames = [NSMutableArray array];
    for (NSString *username in self.usernameStatuses) {
        NSDictionary *usernameInfo = self.usernameStatuses[username];
        DSIdentityUsernameStatus status = [usernameInfo[BLOCKCHAIN_USERNAME_STATUS] unsignedIntegerValue];
        if (status == DSIdentityUsernameStatus_Preordered)
            [unregisteredUsernames addObject:username];
    }
    return [unregisteredUsernames copy];
}

// MARK: Username Helpers

- (NSData *)saltForUsernameFullPath:(NSString *)usernameFullPath
                           saveSalt:(BOOL)saveSalt
                          inContext:(NSManagedObjectContext *)context {
    NSData *salt;
    if ([self statusOfUsernameFullPath:usernameFullPath] == DSIdentityUsernameStatus_Initial || !(salt = [self.usernameSalts objectForKey:usernameFullPath])) {
        UInt256 random256 = uint256_random;
        salt = uint256_data(random256);
        [self.usernameSalts setObject:salt forKey:usernameFullPath];
        if (saveSalt)
            [self saveUsername:[self usernameOfUsernameFullPath:usernameFullPath]
                      inDomain:[self domainOfUsernameFullPath:usernameFullPath]
                        status:[self statusOfUsernameFullPath:usernameFullPath]
                          salt:salt
                    commitSave:YES inContext:context];
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
            [[NSNotificationCenter defaultCenter] postNotificationName:DSIdentityDidUpdateUsernameStatusNotification object:nil userInfo:@{DSChainManagerNotificationChainKey: self.chain, DSIdentityKey: self}];
        });
    }];
}

- (void)setUsernameFullPaths:(NSArray *)usernameFullPaths
                    toStatus:(DSIdentityUsernameStatus)status {
    for (NSString *string in usernameFullPaths) {
        NSMutableDictionary *usernameStatusDictionary = [[self.usernameStatuses objectForKey:string] mutableCopy];
        if (!usernameStatusDictionary) {
            usernameStatusDictionary = [NSMutableDictionary dictionary];
        }
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
    if (self.isTransient) return;
    if (!self.isActive) return;
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
    if (self.isTransient) return;
    if (!self.isActive) return;
    [context performBlockAndWait:^{
        DSBlockchainIdentityEntity *entity = [self identityEntityInContext:context];
        NSSet *usernamesPassingTest = [entity.usernames objectsPassingTest:^BOOL(DSBlockchainIdentityUsernameEntity *_Nonnull obj, BOOL *_Nonnull stop) {
            if ([[self fullPathForUsername:obj.stringValue inDomain:obj.domain] isEqualToString:usernameFullPath]) {
                *stop = TRUE;
                return TRUE;
                
            } else {
                return FALSE;
            }
        }];
        if ([usernamesPassingTest count]) {
            NSAssert([usernamesPassingTest count] == 1, @"There should never be more than 1");
            DSBlockchainIdentityUsernameEntity *usernameEntity = [usernamesPassingTest anyObject];
            usernameEntity.status = status;
            if (salt) {
                usernameEntity.salt = salt;
            }
            if (commitSave) {
                [context ds_save];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:DSIdentityDidUpdateUsernameStatusNotification object:nil userInfo:@{
                    DSChainManagerNotificationChainKey: self.chain,
                    DSIdentityKey: self,
                    DSIdentityUsernameKey: usernameEntity.stringValue,
                    DSIdentityUsernameDomainKey: usernameEntity.stringValue}];
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
    if (self.isTransient) return;
    if (!self.isActive) return;
    [context performBlockAndWait:^{
        DSBlockchainIdentityEntity *entity = [self identityEntityInContext:context];
        NSSet *usernamesPassingTest = [entity.usernames objectsPassingTest:^BOOL(DSBlockchainIdentityUsernameEntity *_Nonnull obj, BOOL *_Nonnull stop) {
            if ([obj.stringValue isEqualToString:username]) {
                *stop = TRUE;
                return TRUE;
                
            } else {
                return FALSE;
            }
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



- (void)fetchUsernamesWithCompletion:(void (^)(BOOL, NSError *_Nonnull))completion {
    [self fetchUsernamesInContext:self.platformContext
                   withCompletion:completion
                onCompletionQueue:dispatch_get_main_queue()];
}

- (void)fetchUsernamesInContext:(NSManagedObjectContext *)context
                 withCompletion:(void (^)(BOOL success, NSError *error))completion
              onCompletionQueue:(dispatch_queue_t)completionQueue {
    [self fetchUsernamesInContext:context
                       retryCount:DEFAULT_FETCH_USERNAMES_RETRY_COUNT
                   withCompletion:completion
                onCompletionQueue:completionQueue];
}

- (void)fetchUsernamesInContext:(NSManagedObjectContext *)context
                     retryCount:(uint32_t)retryCount
                 withCompletion:(void (^)(BOOL success, NSError *error))completion
              onCompletionQueue:(dispatch_queue_t)completionQueue {
    [self internalFetchUsernamesInContext:context
                           withCompletion:^(BOOL success, NSError *error) {
        if (!success && retryCount > 0) {
            [self fetchUsernamesInContext:context
                               retryCount:retryCount - 1
                           withCompletion:completion
                        onCompletionQueue:completionQueue];
        } else if (completion) {
            completion(success, error);
        }
    }
                        onCompletionQueue:completionQueue];
}

- (void)internalFetchUsernamesInContext:(NSManagedObjectContext *)context
                         withCompletion:(void (^)(BOOL success, NSError *error))completion
                      onCompletionQueue:(dispatch_queue_t)completionQueue {
    __weak typeof(self) weakSelf = self;
    DPContract *contract = [DSDashPlatform sharedInstanceForChain:self.chain].dpnsContract;
    if (contract.contractState != DPContractState_Registered) {
        if (completion) dispatch_async(completionQueue, ^{ completion(NO, ERROR_DPNS_CONTRACT_NOT_REGISTERED); });
        return;
    }
    DMaybeDocumentsMap *result = dash_spv_platform_document_manager_DocumentsManager_dpns_documents_for_identity_with_user_id_using_contract(self.chain.shareCore.runtime, self.chain.shareCore.documentsManager->obj, u256_ctor_u(self.uniqueID), contract.raw_contract);
    if (result->error) {
        NSError *error = [NSError ffi_from_platform_error:result->error];
        DMaybeDocumentsMapDtor(result);
        if (completion) dispatch_async(completionQueue, ^{ completion(NO, error); });
        return;
    }
    DDocumentsMap *documents = result->ok;
    if (documents->count == 0) {
        DMaybeDocumentsMapDtor(result);
        if (completion) dispatch_async(completionQueue, ^{ completion(YES, nil); });
        return;
    }
    for (int i = 0; i < documents->count; i++) {
        platform_value_types_identifier_Identifier *identifier = documents->keys[i];
        dpp_document_Document *document = documents->values[i];
        switch (document->tag) {
            case dpp_document_Document_V0: {
                dpp_document_v0_DocumentV0 *v0 = document->v0;
                platform_value_Value *username_value = dash_spv_platform_document_get_document_property(document, (char *)[@"label" UTF8String]);
                platform_value_Value *lowercase_username_value = dash_spv_platform_document_get_document_property(document, (char *)[@"normalizedLabel" UTF8String]);
                platform_value_Value *domain_value = dash_spv_platform_document_get_document_property(document, (char *)[@"normalizedParentDomainName" UTF8String]);
                if (username_value && lowercase_username_value && domain_value) {
                    NSString *username = [NSString stringWithCString:username_value->text encoding:NSUTF8StringEncoding];
                    NSString *lowercaseUsername = [NSString stringWithCString:lowercase_username_value->text encoding:NSUTF8StringEncoding];
                    NSString *domain = [NSString stringWithCString:domain_value->text encoding:NSUTF8StringEncoding];
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
    DMaybeDocumentsMapDtor(result);
    if (completion) dispatch_async(completionQueue, ^{ completion(YES, nil); });
//
//    DSDAPIPlatformNetworkService *dapiNetworkService = self.DAPINetworkService;
//    [dapiNetworkService getDPNSDocumentsForIdentityWithUserId:self.uniqueIDData
//                                              completionQueue:self.identityQueue
//                                                      success:^(NSArray<NSDictionary *> *_Nonnull documents) {
//        __strong typeof(weakSelf) strongSelf = weakSelf;
//        if (!strongSelf) {
//            if (completion) dispatch_async(completionQueue, ^{ completion(NO, ERROR_MEM_ALLOC); });
//            return;
//        }
//        if (![documents count]) {
//            if (completion) dispatch_async(completionQueue, ^{ completion(YES, nil); });
//            return;
//        }
//        //todo verify return is true
//        for (NSDictionary *nameDictionary in documents) {
//            NSString *username = nameDictionary[@"label"];
//            NSString *lowercaseUsername = nameDictionary[@"normalizedLabel"];
//            NSString *domain = nameDictionary[@"normalizedParentDomainName"];
//            if (username && lowercaseUsername && domain) {
//                NSMutableDictionary *usernameStatusDictionary = [[self.usernameStatuses objectForKey:[self fullPathForUsername:lowercaseUsername inDomain:domain]] mutableCopy];
//                BOOL isNew = FALSE;
//                if (!usernameStatusDictionary) {
//                    usernameStatusDictionary = [NSMutableDictionary dictionary];
//                    isNew = TRUE;
//                    usernameStatusDictionary[BLOCKCHAIN_USERNAME_DOMAIN] = domain;
//                    usernameStatusDictionary[BLOCKCHAIN_USERNAME_PROPER] = username;
//                }
//                usernameStatusDictionary[BLOCKCHAIN_USERNAME_STATUS] = @(DSIdentityUsernameStatus_Confirmed);
//                [self.usernameStatuses setObject:[usernameStatusDictionary copy] forKey:[self fullPathForUsername:username inDomain:domain]];
//                if (isNew) {
//                    [self saveNewUsername:username
//                                 inDomain:domain
//                                   status:DSIdentityUsernameStatus_Confirmed
//                                inContext:context];
//                } else {
//                    [self saveUsername:username
//                              inDomain:domain
//                                status:DSIdentityUsernameStatus_Confirmed
//                                  salt:nil
//                            commitSave:YES
//                             inContext:context];
//                }
//            }
//        }
//        if (completion) dispatch_async(completionQueue, ^{ completion(YES, nil); });
//    }
//                                                      failure:^(NSError *_Nonnull error) {
//        if (error.code == 12) { //UNIMPLEMENTED, this would mean that we are connecting to an old node
//            [self.DAPIClient removeDAPINodeByAddress:dapiNetworkService.ipAddress];
//            [self fetchUsernamesInContext:context
//                           withCompletion:completion
//                        onCompletionQueue:completionQueue];
//        } else if (completion) {
//            dispatch_async(completionQueue, ^{ completion(NO, error); });
//        }
//    }];
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
    DSLog(@"registerUsernamesAtStage %lu", (unsigned long)status);
    switch (status) {
        case DSIdentityUsernameStatus_Initial: {
            NSArray *usernameFullPaths = [self usernameFullPathsWithStatus:DSIdentityUsernameStatus_Initial];
            if (usernameFullPaths.count) {
                [self registerPreorderedSaltedDomainHashesForUsernameFullPaths:usernameFullPaths
                                                                     inContext:context
                                                                    completion:^(BOOL success, NSError *error) {
                    if (success) {
                        [self registerUsernamesAtStage:DSIdentityUsernameStatus_PreorderRegistrationPending
                                             inContext:context
                                            completion:completion
                                     onCompletionQueue:completionQueue];
                    } else if (completion) {
                        dispatch_async(completionQueue, ^{ completion(NO, error); });
                    }
                }
                                                             onCompletionQueue:self.identityQueue];
            } else {
                [self registerUsernamesAtStage:DSIdentityUsernameStatus_PreorderRegistrationPending
                                     inContext:context
                                    completion:completion
                             onCompletionQueue:completionQueue];
            }
            break;
        }
        case DSIdentityUsernameStatus_PreorderRegistrationPending: {
            NSArray *usernameFullPaths = [self usernameFullPathsWithStatus:DSIdentityUsernameStatus_PreorderRegistrationPending];
            NSDictionary<NSString *, NSData *> *saltedDomainHashes = [self saltedDomainHashesForUsernameFullPaths:usernameFullPaths inContext:context];
            if (saltedDomainHashes.count) {
                [self monitorForDPNSPreorderSaltedDomainHashes:saltedDomainHashes
                                                withRetryCount:4
                                                     inContext:context
                                                    completion:^(BOOL allFound, NSError *error) {
                    if (!error) {
                        if (!allFound) {
                            //todo: This needs to be done per username and not for all usernames
                            [self setAndSaveUsernameFullPaths:usernameFullPaths
                                                     toStatus:DSIdentityUsernameStatus_Initial
                                                    inContext:context];
                            [self registerUsernamesAtStage:DSIdentityUsernameStatus_Initial
                                                 inContext:context
                                                completion:completion
                                         onCompletionQueue:completionQueue];
                        } else {
                            [self registerUsernamesAtStage:DSIdentityUsernameStatus_Preordered
                                                 inContext:context
                                                completion:completion
                                         onCompletionQueue:completionQueue];
                        }
                    } else {
                        if (completion) dispatch_async(completionQueue, ^{ completion(NO, error); });
                    }
                }
                                             onCompletionQueue:self.identityQueue];
            } else {
                [self registerUsernamesAtStage:DSIdentityUsernameStatus_Preordered
                                     inContext:context
                                    completion:completion
                             onCompletionQueue:completionQueue];
            }
            break;
        }
        case DSIdentityUsernameStatus_Preordered: {
            NSArray *usernameFullPaths = [self usernameFullPathsWithStatus:DSIdentityUsernameStatus_Preordered];
            if (usernameFullPaths.count) {
                [self registerUsernameDomainsForUsernameFullPaths:usernameFullPaths
                                                        inContext:context
                                                       completion:^(BOOL success, NSError *error) {
                    if (success) {
                        [self registerUsernamesAtStage:DSIdentityUsernameStatus_RegistrationPending
                                             inContext:context
                                            completion:completion
                                     onCompletionQueue:completionQueue];
                    } else if (completion) {
                        dispatch_async(completionQueue, ^{ completion(NO, error); });
                    }
                }
                                                onCompletionQueue:self.identityQueue];
            } else {
                [self registerUsernamesAtStage:DSIdentityUsernameStatus_RegistrationPending
                                     inContext:context
                                    completion:completion
                             onCompletionQueue:completionQueue];
            }
            break;
        }
        case DSIdentityUsernameStatus_RegistrationPending: {
            NSArray *usernameFullPaths = [self usernameFullPathsWithStatus:DSIdentityUsernameStatus_RegistrationPending];
            if (usernameFullPaths.count) {
                [self monitorForDPNSUsernameFullPaths:usernameFullPaths
                                       withRetryCount:5
                                            inContext:context
                                           completion:^(BOOL allFound, NSError *error) {
                    if (!error) {
                        if (!allFound) {
                            //todo: This needs to be done per username and not for all usernames
                            [self setAndSaveUsernameFullPaths:usernameFullPaths
                                                     toStatus:DSIdentityUsernameStatus_Preordered
                                                    inContext:context];
                            [self registerUsernamesAtStage:DSIdentityUsernameStatus_Preordered
                                                 inContext:context
                                                completion:completion
                                         onCompletionQueue:completionQueue];
                        } else if (completion) { //all were found
                            dispatch_async(completionQueue, ^{ completion(YES, nil); });
                        }
                    } else if (completion) {
                        dispatch_async(completionQueue, ^{ completion(NO, error); });
                    }
                }
                                    onCompletionQueue:completionQueue];
            } else if (completion) {
                dispatch_async(completionQueue, ^{ completion(YES, nil); });
            }
            break;
        }
        default:
            if (completion) dispatch_async(completionQueue, ^{ completion(NO, nil); });
            break;
    }
}

// MARK: Transitions

//Preorder stage
- (void)registerPreorderedSaltedDomainHashesForUsernameFullPaths:(NSArray *)usernameFullPaths
                                                       inContext:(NSManagedObjectContext *)context
                                                      completion:(void (^_Nullable)(BOOL success, NSError *error))completion
                                               onCompletionQueue:(dispatch_queue_t)completionQueue {
    NSError *error = nil;
    NSData *entropyData = uint256_random_data;
    NSMutableArray *usernamePreorderDocuments = [NSMutableArray array];
    NSDictionary<NSString *, NSData *> *saltedDomainHashesForUsernameFullPaths = [self saltedDomainHashesForUsernameFullPaths:usernameFullPaths inContext:context];
    uintptr_t i = 0;
    Vec_u8 **salted_domain_hashes_values = malloc(sizeof(Vec_u8 *) * saltedDomainHashesForUsernameFullPaths.count);
    for (NSData *saltedDomainHashData in [saltedDomainHashesForUsernameFullPaths allValues]) {
        salted_domain_hashes_values[i] = bytes_ctor(saltedDomainHashData);
        i++;
    }
    if (![usernamePreorderDocuments count]) {
        if (completion) dispatch_async(completionQueue, ^{ completion(NO, error); });
        return;
    }
    if (!self.keysCreated) {
        uint32_t index;
        [self createNewKeyOfType:dash_spv_crypto_keys_key_KeyKind_ECDSA_ctor() saveKey:!self.wallet.isTransient returnIndex:&index];
    }
    DMaybeOpaqueKey *private_key = [self privateKeyAtIndex:self.currentMainKeyIndex ofType:self.currentMainKeyType];
    DSUsernameFullPathSaveContext *saveContext = [DSUsernameFullPathSaveContext contextWithUsernames:usernameFullPaths forIdentity:self inContext:context];
    Fn_ARGS_std_os_raw_c_void_dash_spv_platform_document_usernames_UsernameStatus_RTRN_ save_callback = { .caller = &usernames_save_context_caller };
    DPContract *contract = [DSDashPlatform sharedInstanceForChain:self.chain].dpnsContract;
    DMaybeStateTransitionProofResult *result = dash_spv_platform_PlatformSDK_register_preordered_salted_domain_hashes_for_username_full_paths(self.chain.shareCore.runtime, self.chain.shareCore.platform->obj, contract.raw_contract, u256_ctor_u(self.uniqueID), Vec_Vec_u8_ctor(i, salted_domain_hashes_values), u256_ctor(entropyData), private_key->ok, ((__bridge void *)(saveContext)), save_callback);
    if (result->error) {
        NSError *error = [NSError ffi_from_platform_error:result->error];
        DMaybeStateTransitionProofResultDtor(result);
        if (completion) dispatch_async(completionQueue, ^{ completion(NO, error); });
        return;
    }
    DMaybeStateTransitionProofResultDtor(result);
    if (completion) dispatch_async(completionQueue, ^{ completion(YES, nil); });
}

- (void)registerUsernameDomainsForUsernameFullPaths:(NSArray *)usernameFullPaths
                                          inContext:(NSManagedObjectContext *)context
                                         completion:(void (^_Nullable)(BOOL success, NSError *error))completion
                                  onCompletionQueue:(dispatch_queue_t)completionQueue {
    NSError *error = nil;
    NSData *entropyData = uint256_random_data;
    NSMutableArray *usernamePreorderDocuments = [NSMutableArray array];
    NSDictionary<NSString *, NSData *> *saltedDomainHashesForUsernameFullPaths = [self saltedDomainHashesForUsernameFullPaths:usernameFullPaths inContext:context];
    uintptr_t i = 0;
    platform_value_Value **values_values = malloc(sizeof(Vec_platform_value_Value *) * saltedDomainHashesForUsernameFullPaths.count);
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
    if (![usernamePreorderDocuments count]) {
        if (completion) dispatch_async(completionQueue, ^{ completion(NO, error); });
        return;
    }
    if (!self.keysCreated) {
        uint32_t index;
        [self createNewKeyOfType:dash_spv_crypto_keys_key_KeyKind_ECDSA_ctor() saveKey:!self.wallet.isTransient returnIndex:&index];
    }
    DMaybeOpaqueKey *private_key = [self privateKeyAtIndex:self.currentMainKeyIndex ofType:self.currentMainKeyType];
    DSUsernameFullPathSaveContext *saveContext = [DSUsernameFullPathSaveContext contextWithUsernames:usernameFullPaths forIdentity:self inContext:context];
    Fn_ARGS_std_os_raw_c_void_dash_spv_platform_document_usernames_UsernameStatus_RTRN_ save_callback = { .caller = &usernames_save_context_caller };
    DPContract *contract = [DSDashPlatform sharedInstanceForChain:self.chain].dpnsContract;
    Vec_platform_value_Value *values = Vec_platform_value_Value_ctor(i, values_values);
    DMaybeStateTransitionProofResult *result = dash_spv_platform_PlatformSDK_register_username_domains_for_username_full_paths(self.chain.shareCore.runtime, self.chain.shareCore.platform->obj, contract.raw_contract, u256_ctor_u(self.uniqueID), values, u256_ctor(entropyData), private_key->ok, ((__bridge void *)(saveContext)), save_callback);
    if (result->error) {
        NSError *error = [NSError ffi_from_platform_error:result->error];
        DMaybeStateTransitionProofResultDtor(result);
        if (completion) dispatch_async(completionQueue, ^{ completion(NO, error); });
        return;
    }
    DMaybeStateTransitionProofResultDtor(result);
    if (completion) dispatch_async(completionQueue, ^{ completion(YES, nil); });

}




- (void)monitorForDPNSUsernameFullPaths:(NSArray *)usernameFullPaths
                         withRetryCount:(uint32_t)retryCount
                              inContext:(NSManagedObjectContext *)context
                             completion:(void (^)(BOOL allFound, NSError *error))completion
                      onCompletionQueue:(dispatch_queue_t)completionQueue {
    NSMutableDictionary *domains = [NSMutableDictionary dictionary];
    for (NSString *usernameFullPath in usernameFullPaths) {
        NSArray *components = [usernameFullPath componentsSeparatedByString:@"."];
        NSString *domain = @"";
        NSString *name = components[0];
        if (components.count > 1) {
            NSArray *domainComponents = [components subarrayWithRange:NSMakeRange(1, components.count - 1)];
            domain = [domainComponents componentsJoinedByString:@"."];
        }
        if (!domains[domain]) domains[domain] = [NSMutableArray array];
        [domains[domain] addObject:name];
    }
    __block BOOL finished = FALSE;
    __block NSUInteger countAllFound = 0;
    __block NSUInteger countReturned = 0;
    for (NSString *domain in domains) {
        [self monitorForDPNSUsernames:domains[domain]
                             inDomain:domain
                       withRetryCount:retryCount
                            inContext:context
                           completion:^(BOOL allFound, NSError *error) {
            if (finished) return;
            if (error && !finished) {
                finished = TRUE;
                if (completion) completion(NO, error);
                return;
            }
            if (allFound) countAllFound++;
            countReturned++;
            if (countReturned == domains.count) {
                finished = TRUE;
                if (completion) completion(countAllFound == domains.count, nil);
            }
        }
                    onCompletionQueue:completionQueue]; //we can use completion queue directly here
    }
}

- (void)monitorForDPNSUsernames:(NSArray *)usernames
                       inDomain:(NSString *)domain
                 withRetryCount:(uint32_t)retryCount
                      inContext:(NSManagedObjectContext *)context
                     completion:(void (^)(BOOL allFound, NSError *error))completion
              onCompletionQueue:(dispatch_queue_t)completionQueue {
    DPContract *contract = [DSDashPlatform sharedInstanceForChain:self.chain].dpnsContract;
    NSUInteger usernamesCount = usernames.count;
    char **usernames_values = malloc(sizeof(char *) * usernamesCount);
    for (int i = 0; i < usernamesCount; i++) {
        usernames_values[i] = strdup([usernames[i] UTF8String]);
    }
    
    DMaybeDocumentsMap *result = dash_spv_platform_document_usernames_UsernamesManager_stream_usernames_with_contract(self.chain.shareCore.runtime, self.chain.shareCore.usernames->obj, (char *)[domain UTF8String], Vec_String_ctor(usernamesCount, usernames_values), contract.raw_contract, dash_spv_platform_util_RetryStrategy_Linear_ctor(5), dash_spv_platform_document_usernames_UsernameValidator_None_ctor(), 5 * NSEC_PER_SEC);
    
    if (result->error) {
        NSError *error = [NSError ffi_from_platform_error:result->error];
        DMaybeDocumentsMapDtor(result);
        dispatch_async(completionQueue, ^{ completion(FALSE, error); });
        return;
    }
    DDocumentsMap *documents = result->ok;
    
    for (NSString *username in usernames) {
        for (int i = 0; i < documents->count; i++) {
            dpp_document_Document *document = documents->values[i];
            platform_value_Value *normalized_label_value = dash_spv_platform_document_get_document_property(document, (char *) [@"normalizedLabel" UTF8String]);
            platform_value_Value *label_value = dash_spv_platform_document_get_document_property(document, (char *) [@"label" UTF8String]);
            platform_value_Value *domain_value = dash_spv_platform_document_get_document_property(document, (char *) [@"normalizedParentDomainName" UTF8String]);
            NSString *normalizedLabel = [NSString stringWithCString:normalized_label_value->text encoding:NSUTF8StringEncoding];
            NSString *label = [NSString stringWithCString:label_value->text encoding:NSUTF8StringEncoding];
            NSString *normalizedParentDomainName = [NSString stringWithCString:domain_value->text encoding:NSUTF8StringEncoding];
            if ([normalizedLabel isEqualToString:[username lowercaseString]]) {
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
    if (completion) {
        dispatch_async(completionQueue, ^{ completion(YES, nil); });
    }
//
//    
//    __weak typeof(self) weakSelf = self;
//    DSDAPIPlatformNetworkService *dapiNetworkService = self.DAPINetworkService;
//    [dapiNetworkService getDPNSDocumentsForUsernames:usernames
//                                            inDomain:domain
//                                     completionQueue:self.identityQueue
//                                             success:^(id _Nonnull domainDocumentArray) {
//        __strong typeof(weakSelf) strongSelf = weakSelf;
//        if (!strongSelf) return;
//        if ([domainDocumentArray isKindOfClass:[NSArray class]]) {
//            NSMutableArray *usernamesLeft = [usernames mutableCopy];
//            for (NSString *username in usernames) {
//                for (NSDictionary *domainDocument in domainDocumentArray) {
//                    NSString *normalizedLabel = domainDocument[@"normalizedLabel"];
//                    NSString *label = domainDocument[@"label"];
//                    NSString *normalizedParentDomainName = domainDocument[@"normalizedParentDomainName"];
//                    if ([normalizedLabel isEqualToString:[username lowercaseString]]) {
//                        NSMutableDictionary *usernameStatusDictionary = [[self.usernameStatuses objectForKey:username] mutableCopy];
//                        if (!usernameStatusDictionary) {
//                            usernameStatusDictionary = [NSMutableDictionary dictionary];
//                            usernameStatusDictionary[BLOCKCHAIN_USERNAME_DOMAIN] = normalizedParentDomainName;
//                            usernameStatusDictionary[BLOCKCHAIN_USERNAME_PROPER] = label;
//                        }
//                        usernameStatusDictionary[BLOCKCHAIN_USERNAME_STATUS] = @(DSIdentityUsernameStatus_Confirmed);
//                        [self.usernameStatuses setObject:[usernameStatusDictionary copy]
//                                                  forKey:[self fullPathForUsername:username inDomain:@"dash"]];
//                        [strongSelf saveUsername:username
//                                        inDomain:normalizedParentDomainName
//                                          status:DSIdentityUsernameStatus_Confirmed
//                                            salt:nil
//                                      commitSave:YES
//                                       inContext:context];
//                        [usernamesLeft removeObject:username];
//                    }
//                }
//            }
//            if ([usernamesLeft count] && retryCount > 0) {
//                [strongSelf monitorForDPNSUsernames:usernamesLeft
//                                           inDomain:domain
//                                     withRetryCount:retryCount - 1
//                                          inContext:context
//                                         completion:completion
//                                  onCompletionQueue:completionQueue];
//            } else if (completion) {
//                dispatch_async(completionQueue, ^{ completion(![usernamesLeft count], nil); });
//            }
//        } else if (retryCount > 0) {
//            [strongSelf monitorForDPNSUsernames:usernames
//                                       inDomain:domain
//                                 withRetryCount:retryCount - 1
//                                      inContext:context
//                                     completion:completion
//                              onCompletionQueue:completionQueue];
//        } else if (completion) {
//            dispatch_async(completionQueue, ^{ completion(NO, ERROR_MALFORMED_RESPONSE); });
//        }
//    }
//                                             failure:^(NSError *_Nonnull error) {
//        if (error.code == 12) { //UNIMPLEMENTED, this would mean that we are connecting to an old node
//            [self.DAPIClient removeDAPINodeByAddress:dapiNetworkService.ipAddress];
//        }
//        if (retryCount > 0) {
//            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), self.identityQueue, ^{
//                __strong typeof(weakSelf) strongSelf = weakSelf;
//                if (!strongSelf) return;
//                [strongSelf monitorForDPNSUsernames:usernames
//                                           inDomain:domain
//                                     withRetryCount:retryCount - 1
//                                          inContext:context
//                                         completion:completion
//                                  onCompletionQueue:completionQueue];
//            });
//        } else {
//            dispatch_async(completionQueue, ^{ completion(FALSE, error); });
//        }
//    }];
}

- (void)processSaltedDomainHashDocument:(NSString *)usernameFullPath hash:(NSData *)hash document:(dpp_document_Document *)document inContext:(NSManagedObjectContext  *)context {
    switch (document->tag) {
        case dpp_document_Document_V0: {
            platform_value_Value *salted_domain_hash_value = dash_spv_platform_document_get_document_property(document, (char *)[@"saltedDomainHash" UTF8String]);
            NSData *saltedDomainHash = NSDataFromPtr(salted_domain_hash_value->bytes);
            if ([saltedDomainHash isEqualToData:hash]) {
                NSMutableDictionary *usernameStatusDictionary = [[self.usernameStatuses objectForKey:usernameFullPath] mutableCopy];
                if (!usernameStatusDictionary)
                    usernameStatusDictionary = [NSMutableDictionary dictionary];
                usernameStatusDictionary[BLOCKCHAIN_USERNAME_STATUS] = @(DSIdentityUsernameStatus_Preordered);
                [self.usernameStatuses setObject:[usernameStatusDictionary copy] forKey:usernameFullPath];
                [self saveUsernameFullPath:usernameFullPath status:DSIdentityUsernameStatus_Preordered salt:nil commitSave:YES inContext:context];
            }
            break;
        }
        default:
            break;
    }

}

- (void)monitorForDPNSPreorderSaltedDomainHashes:(NSDictionary *)saltedDomainHashes
                                  withRetryCount:(uint32_t)retryCount
                                       inContext:(NSManagedObjectContext *)context
                                      completion:(void (^)(BOOL allFound, NSError *error))completion
                               onCompletionQueue:(dispatch_queue_t)completionQueue {
    
    NSArray *hashes = [saltedDomainHashes allValues];
    NSUInteger hashesCount = [hashes count];
    if (hashesCount == 1) {
        NSData *onlyHash = [hashes firstObject];
        DMaybeDocument *result = dash_spv_platform_document_salted_domain_hashes_SaltedDomainHashesManager_preorder_salted_domain_hash(self.chain.shareCore.runtime, self.chain.shareCore.saltedDomainHashes->obj, bytes_ctor(onlyHash));
        if (result->error) {
            NSError *error = [NSError ffi_from_platform_error:result->error];
            DMaybeDocumentDtor(result);
            if (completion) dispatch_async(completionQueue, ^{ completion(FALSE, error); });
            return;
        }
        NSString *usernameFullPath = [[saltedDomainHashes allKeys] firstObject];
        [self processSaltedDomainHashDocument:usernameFullPath hash:onlyHash document:result->ok inContext:context];
        DMaybeDocumentDtor(result);
    } else {
        Vec_u8 **hashes_values = malloc(sizeof(Vec_u8 *) * hashesCount);
        for (int i = 0; i < hashesCount; i++) {
            NSData *hash = hashes[i];
            hashes_values[i] = bytes_ctor(hash);
        }
        Vec_Vec_u8 *hashes = Vec_Vec_u8_ctor(hashesCount, hashes_values);
        DMaybeDocumentsMap *result = dash_spv_platform_document_salted_domain_hashes_SaltedDomainHashesManager_preorder_salted_domain_hashes(self.chain.shareCore.runtime, self.chain.shareCore.saltedDomainHashes->obj, hashes);
        if (result->error) {
            NSError *error = [NSError ffi_from_platform_error:result->error];
            DMaybeDocumentsMapDtor(result);
            if (completion) dispatch_async(completionQueue, ^{ completion(FALSE, error); });
            return;
        }
        
        indexmap_IndexMap_platform_value_types_identifier_Identifier_Option_dpp_document_Document *index_map = result->ok;
        for (NSString *usernameFullPath in saltedDomainHashes) {
            NSData *saltedDomainHashData = saltedDomainHashes[usernameFullPath];
            for (int i = 0; i < index_map->count; i++) {
                [self processSaltedDomainHashDocument:usernameFullPath hash:saltedDomainHashData document:index_map->values[0] inContext:context];
            }
        }
        DMaybeDocumentsMapDtor(result);
    }
    dispatch_async(completionQueue, ^{ completion(YES, nil); });

    
//    __weak typeof(self) weakSelf = self;
//    DSDAPIPlatformNetworkService *dapiNetworkService = self.DAPINetworkService;
//    [dapiNetworkService getDPNSDocumentsForPreorderSaltedDomainHashes:[saltedDomainHashes allValues]
//                                                      completionQueue:self.identityQueue
//                                                              success:^(id _Nonnull preorderDocumentArray) {
//        __strong typeof(weakSelf) strongSelf = weakSelf;
//        if (!strongSelf) {
//            if (completion) dispatch_async(completionQueue, ^{ completion(NO, ERROR_MEM_ALLOC); });
//            return;
//        }
//        if ([preorderDocumentArray isKindOfClass:[NSArray class]]) {
//            NSMutableArray *usernamesLeft = [[saltedDomainHashes allKeys] mutableCopy];
//            for (NSString *usernameFullPath in saltedDomainHashes) {
//                NSData *saltedDomainHashData = saltedDomainHashes[usernameFullPath];
//                for (NSDictionary *preorderDocument in preorderDocumentArray) {
//                    if ([preorderDocument[@"saltedDomainHash"] isEqualToData:saltedDomainHashData]) {
//                        NSMutableDictionary *usernameStatusDictionary = [[self.usernameStatuses objectForKey:usernameFullPath] mutableCopy];
//                        if (!usernameStatusDictionary)
//                            usernameStatusDictionary = [NSMutableDictionary dictionary];
//                        usernameStatusDictionary[BLOCKCHAIN_USERNAME_STATUS] = @(DSIdentityUsernameStatus_Preordered);
//                        [self.usernameStatuses setObject:[usernameStatusDictionary copy] forKey:usernameFullPath];
//                        [strongSelf saveUsernameFullPath:usernameFullPath status:DSIdentityUsernameStatus_Preordered salt:nil commitSave:YES inContext:context];
//                        [usernamesLeft removeObject:usernameFullPath];
//                    }
//                }
//            }
//            if ([usernamesLeft count] && retryCount > 0) {
//                [strongSelf monitorForDPNSPreorderSaltedDomainHashes:[saltedDomainHashes dictionaryWithValuesForKeys:usernamesLeft]
//                                                      withRetryCount:retryCount - 1
//                                                           inContext:context
//                                                          completion:completion
//                                                   onCompletionQueue:completionQueue];
//            } else if (completion) {
//                dispatch_async(completionQueue, ^{ completion(![usernamesLeft count], nil); });
//            }
//        } else if (retryCount > 0) {
//            [strongSelf monitorForDPNSPreorderSaltedDomainHashes:saltedDomainHashes
//                                                  withRetryCount:retryCount - 1
//                                                       inContext:context
//                                                      completion:completion
//                                               onCompletionQueue:completionQueue];
//        } else if (completion) {
//            dispatch_async(completionQueue, ^{ completion(NO, ERROR_MALFORMED_RESPONSE); });
//        }
//    }
//                                                              failure:^(NSError *_Nonnull error) {
//        if (error.code == 12) { //UNIMPLEMENTED, this would mean that we are connecting to an old node
//            [self.DAPIClient removeDAPINodeByAddress:dapiNetworkService.ipAddress];
//        }
//        if (retryCount > 0) {
//            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), self.identityQueue, ^{
//                __strong typeof(weakSelf) strongSelf = weakSelf;
//                if (!strongSelf) {
//                    if (completion) dispatch_async(completionQueue, ^{ completion(NO, ERROR_MEM_ALLOC); });
//                    return;
//                }
//                [strongSelf monitorForDPNSPreorderSaltedDomainHashes:saltedDomainHashes
//                                                      withRetryCount:retryCount - 1
//                                                           inContext:context
//                                                          completion:completion
//                                                   onCompletionQueue:completionQueue];
//            });
//        } else if (completion) {
//            dispatch_async(completionQueue, ^{ completion(FALSE, error); });
//        }
//    }];
}

@end
