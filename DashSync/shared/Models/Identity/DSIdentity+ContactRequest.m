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
#import "DSAccount.h"
#import "DSAccountEntity+CoreDataClass.h"
#import "DSBlockchainIdentityEntity+CoreDataClass.h"
#import "DSChain+Identity.h"
#import "DSChainManager.h"
#import "DSDashpayUserEntity+CoreDataClass.h"
#import "DSDashPlatform.h"
#import "DSDerivationPathEntity+CoreDataClass.h"
#import "DSFriendRequestEntity+CoreDataClass.h"
#import "DSIdentitiesManager+CoreData.h"
#import "DSIdentity+ContactRequest.h"
#import "DSIdentity+Friendship.h"
#import "DSIdentity+Protected.h"
#import "DSPotentialOneWayFriendship.h"
#import "DSTransactionManager+Protected.h"
#import "NSError+Dash.h"
#import "NSError+Platform.h"
#import "NSManagedObject+Sugar.h"

#define DAPI_DOCUMENT_RESPONSE_COUNT_LIMIT 100
#define DEFAULT_CONTACT_REQUEST_FETCH_RETRIES 5

#define ERROR_DASHPAY_CONTRACT_IMPROPER_SETUP [NSError errorWithCode:500 localizedDescriptionKey:@"The Dashpay contract is not properly set up"]
#define ERROR_IDENTITY_NOT_ACTIVATED [NSError errorWithCode:500 localizedDescriptionKey:@"The blockchain identity hasn't yet been locally activated"]
#define ERROR_IDENTITY_NO_LONGER_ACTIVE [NSError errorWithCode:410 localizedDescriptionKey:@"Identity no longer active in wallet"]
#define ERROR_KEY_FORMAT_DECRYPTION [NSError errorWithCode:500 localizedDescriptionKey:@"Incorrect key format after contact request decryption"]
#define ERROR_DERIVATION_FRIENDSHIP [NSError errorWithCode:500 localizedDescriptionKey:@"Could not create friendship derivation path"]
#define ERROR_CONTACT_REQUEST_KEY_ENCRYPTION [NSError errorWithCode:500 localizedDescriptionKey:@"Contact request extended public key is incorrectly encrypted."]

@implementation DSIdentity (ContactRequest)

- (void)fetchContactRequests:(void (^)(BOOL success, NSArray<NSError *> *errors))completion {
    dispatch_async(self.identityQueue, ^{
        [self fetchContactRequestsInContext:self.platformContext
                             withCompletion:completion
                          onCompletionQueue:dispatch_get_main_queue()];
    });
}


- (void)fetchContactRequestsInContext:(NSManagedObjectContext *)context
                       withCompletion:(void (^)(BOOL success, NSArray<NSError *> *errors))completion
                    onCompletionQueue:(dispatch_queue_t)completionQueue {
    __weak typeof(self) weakSelf = self;
    [self fetchIncomingContactRequestsInContext:context
                                     startAfter:nil
                                 withCompletion:^(BOOL success, NSArray<NSError *> *errors) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            if (completion) completion(NO, @[ERROR_MEM_ALLOC]);
            return;
        }
        if (!success) {
            if (completion) dispatch_async(completionQueue, ^{ completion(success, errors); });
            return;
        }
        [strongSelf fetchOutgoingContactRequestsInContext:context
                                               startAfter:nil
                                           withCompletion:completion
                                        onCompletionQueue:completionQueue];
    }
                              onCompletionQueue:self.identityQueue];
}

- (void)fetchIncomingContactRequests:(void (^_Nullable)(BOOL success, NSArray<NSError *> *errors))completion {
    [self fetchIncomingContactRequestsInContext:self.platformContext
                                     startAfter:nil
                                 withCompletion:completion
                              onCompletionQueue:dispatch_get_main_queue()];
}

- (void)fetchIncomingContactRequestsInContext:(NSManagedObjectContext *)context
                                   startAfter:(NSData*_Nullable)startAfter
                               withCompletion:(void (^)(BOOL success, NSArray<NSError *> *errors))completion
                            onCompletionQueue:(dispatch_queue_t)completionQueue {
    
    NSMutableString *debugInfo = [NSMutableString stringWithFormat:@"%@: fetch incoming contact requests: (startAfter: %@)", self.logPrefix, startAfter ? startAfter.hexString : @"NULL"];
    DPContract *dashpayContract = [DSDashPlatform sharedInstanceForChain:self.chain].dashPayContract;
    if (dashpayContract.contractState != DPContractState_Registered) {
        [debugInfo appendFormat:@" : ERROR: DashPay Contract State: %lu", dashpayContract.contractState];
        DSLog(@"%@", debugInfo);
        if (completion) dispatch_async(completionQueue, ^{ completion(NO, @[ERROR_DASHPAY_CONTRACT_IMPROPER_SETUP]); });
        return;
    }
    NSError *error = nil;
    if (![self activePrivateKeysAreLoadedWithFetchingError:&error]) {
        [debugInfo appendFormat:@" : ERROR: Active private keys are loaded with error: %@", error];
        DSLog(@"%@", debugInfo);
        // The blockchain identity hasn't been intialized on the device, ask the user to activate the blockchain user, this action allows private keys to be cached on the blockchain identity level
        if (completion) dispatch_async(completionQueue, ^{ completion(NO, @[error ? error : ERROR_IDENTITY_NOT_ACTIVATED]); });
        return;
    }
    u256 *user_id = u256_ctor_u(self.uniqueID);
    uint64_t since = self.lastCheckedIncomingContactsTimestamp ? (self.lastCheckedIncomingContactsTimestamp - HOUR_TIME_INTERVAL) : 0;
    BYTES *start_after = startAfter ? bytes_ctor(startAfter) : nil;
    __weak typeof(self) weakSelf = self;
    DMaybeContactRequests *result = dash_spv_platform_document_contact_request_ContactRequestManager_stream_incoming_contact_requests_with_contract(self.chain.sharedRuntime, self.chain.sharedContactsObj, user_id, since, start_after, dashpayContract.raw_contract, DRetryLinear(5), dash_spv_platform_document_contact_request_ContactRequestValidator_None_ctor(), 1000);
    if (result->error) {
        NSError *error = [NSError ffi_from_platform_error:result->error];
        DMaybeContactRequestsDtor(result);
        [debugInfo appendFormat:@" : ERROR: %@", error];
        DSLog(@"%@", debugInfo);
        if (completion) dispatch_async(completionQueue, ^{ completion(NO, @[error]); });
        return;
    }
    
    dispatch_async(self.identityQueue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            [debugInfo appendFormat:@" : ERROR: Lost self context"];
            DSLog(@"%@", debugInfo);
            if (completion) dispatch_async(completionQueue, ^{ completion(NO, @[ERROR_MEM_ALLOC]); });
            return;
        }
        DContactRequests *documents = result->ok;
        NSAssert(completionQueue == self.identityQueue, @"we should be on identity queue");
        __block NSMutableArray<NSValue *> *incomingNewRequests = [NSMutableArray array];
        __block NSMutableArray *rErrors = [NSMutableArray array];
        [context performBlockAndWait:^{
            for (int i = 0; i < documents->count; i++) {
                DContactRequestKind *kind = documents->values[i];
                switch (kind->tag) {
                    case dash_spv_platform_models_contact_request_ContactRequestKind_Incoming: {
                        NSData *identifier = NSDataFromPtr(kind->incoming->owner_id);
                        //we are the recipient, this is an incoming request
                        DSFriendRequestEntity *exist = [DSFriendRequestEntity anyObjectInContext:context matching:@"destinationContact == %@ && sourceContact.associatedBlockchainIdentity.uniqueID == %@", [self matchingDashpayUserInContext:context], identifier];
                        
                        // TODO: memory
                        if (!exist)
                            [incomingNewRequests addObject:[NSValue valueWithPointer:dash_spv_platform_document_contact_request_as_incoming_request(kind)]];
                        break;
                    }
                    default: {
                        //we should not have received this
                        NSAssert(FALSE, @"the contact request needs to be either outgoing or incoming");
                        break;
                    }
                }
            }
        }];
        __block BOOL succeeded = YES;
        dispatch_group_t dispatchGroup = dispatch_group_create();
        if ([incomingNewRequests count]) {
            dispatch_group_enter(dispatchGroup);
            [self handleIncomingRequests:incomingNewRequests
                                 context:context
                              completion:^(BOOL success, NSArray<NSError *> *errors) {
                if (!success) {
                    succeeded = NO;
                    [rErrors addObjectsFromArray:errors];
                }
                dispatch_group_leave(dispatchGroup);
            }
                       onCompletionQueue:completionQueue];
        }
        dispatch_group_notify(dispatchGroup, completionQueue, ^{
            BOOL hasMore = documents->count == DAPI_DOCUMENT_RESPONSE_COUNT_LIMIT;
            if (!hasMore)
                [self.platformContext performBlockAndWait:^{
                    self.lastCheckedIncomingContactsTimestamp = [[NSDate date] timeIntervalSince1970];
                }];
            [debugInfo appendFormat:@" : OK: %u: %@", succeeded, rErrors];
            DSLog(@"%@", debugInfo);
            __block NSData * hasMoreStartAfter = nil;
            if (documents->count > 0) {
                DContactRequestKind *last = documents->values[documents->count-1];
                if (last->incoming)
                    hasMoreStartAfter = NSDataFromPtr(last->incoming->id);
            }
            if (succeeded && hasMoreStartAfter)
                [self fetchIncomingContactRequestsInContext:context
                                                 startAfter:hasMoreStartAfter
                                             withCompletion:completion
                                          onCompletionQueue:completionQueue];
            else if (completion)
                completion(succeeded, [rErrors copy]);
        });
    });
}

- (void)fetchOutgoingContactRequests:(void (^)(BOOL success, NSArray<NSError *> *errors))completion {
    [self fetchOutgoingContactRequestsInContext:self.platformContext
                                     startAfter:nil
                                 withCompletion:completion
                              onCompletionQueue:dispatch_get_main_queue()];
}

- (void)fetchOutgoingContactRequestsInContext:(NSManagedObjectContext *)context
                                   startAfter:(NSData*_Nullable)startAfter
                               withCompletion:(void (^)(BOOL success, NSArray<NSError *> *errors))completion
                            onCompletionQueue:(dispatch_queue_t)completionQueue {
    NSMutableString *debugInfo = [NSMutableString stringWithFormat:@"%@: fetch outgoing contact requests: (startAfter: %@)", self.logPrefix, startAfter ? startAfter.hexString : @"NULL"];
    DPContract *dashpayContract = [DSDashPlatform sharedInstanceForChain:self.chain].dashPayContract;
    if (dashpayContract.contractState != DPContractState_Registered) {
        [debugInfo appendFormat:@" : ERROR: DashPay Contract State: %lu", dashpayContract.contractState];
        DSLog(@"%@", debugInfo);
        if (completion) dispatch_async(completionQueue, ^{ completion(NO, @[ERROR_DASHPAY_CONTRACT_IMPROPER_SETUP]); });
        return;
    }
    NSError *error = nil;
    if (![self activePrivateKeysAreLoadedWithFetchingError:&error]) {
        [debugInfo appendFormat:@" : ERROR: Active private keys are loaded with error: %@", error];
        DSLog(@"%@", debugInfo);
        //The blockchain identity hasn't been intialized on the device, ask the user to activate the blockchain user, this action allows private keys to be cached on the blockchain identity level
        if (completion) dispatch_async(completionQueue, ^{ completion(NO, @[error ? error : ERROR_IDENTITY_NOT_ACTIVATED]); });
        return;
    }
    __weak typeof(self) weakSelf = self;
    
    BYTES *start_after = startAfter ? bytes_ctor(startAfter) : NULL;
    uint64_t since = self.lastCheckedOutgoingContactsTimestamp ? (self.lastCheckedOutgoingContactsTimestamp - HOUR_TIME_INTERVAL) : 0;
    u256 *user_id = u256_ctor_u(self.uniqueID);
    DMaybeContactRequests *result = dash_spv_platform_document_contact_request_ContactRequestManager_stream_outgoing_contact_requests_with_contract(self.chain.sharedRuntime, self.chain.sharedContactsObj, user_id, since, start_after, dashpayContract.raw_contract, DRetryLinear(5), dash_spv_platform_document_contact_request_ContactRequestValidator_None_ctor(), 1000);
    if (result->error) {
        NSError *error = [NSError ffi_from_platform_error:result->error];
        DMaybeContactRequestsDtor(result);
        [debugInfo appendFormat:@" : ERROR: %@", error];
        DSLog(@"%@", debugInfo);
        if (completion) dispatch_async(completionQueue, ^{ completion(NO, @[error]); });
        return;
    }
    
    dispatch_async(self.identityQueue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            [debugInfo appendFormat:@" : ERROR: Lost self context"];
            DSLog(@"%@", debugInfo);
            if (completion) dispatch_async(completionQueue, ^{ completion(NO, @[ERROR_MEM_ALLOC]); });
            return;
        }
        DContactRequests *documents = result->ok;
        NSAssert(completionQueue == self.identityQueue, @"we should be on identity queue");
        __block NSMutableArray<NSValue *> *outgoingNewRequests = [NSMutableArray array];
        __block NSMutableArray *rErrors = [NSMutableArray array];
        [context performBlockAndWait:^{
            for (int i = 0; i < documents->count; i++) {
                DContactRequestKind *kind = documents->values[i];
                switch (kind->tag) {
                    case dash_spv_platform_models_contact_request_ContactRequestKind_Outgoing: {
                        NSData *identifier = NSDataFromPtr(kind->outgoing->recipient);
                        
                        BOOL exist = [DSFriendRequestEntity countObjectsInContext:context matching:@"sourceContact == %@ && destinationContact.associatedBlockchainIdentity.uniqueID == %@", [self matchingDashpayUserInContext:context], identifier];
                        // TODO: memory
                        if (!exist) [outgoingNewRequests addObject:[NSValue valueWithPointer:dash_spv_platform_document_contact_request_as_outgoing_request(kind)]];
                        break;
                    }
                    default: {
                        //we should not have received this
                        NSAssert(FALSE, @"the contact request needs to be either outgoing or incoming");
                        break;
                    }
                }
            }
        }];
        __block BOOL succeeded = YES;
        dispatch_group_t dispatchGroup = dispatch_group_create();
        if ([outgoingNewRequests count]) {
            dispatch_group_enter(dispatchGroup);
            [self handleOutgoingRequests:outgoingNewRequests
                                 context:context
                              completion:^(BOOL success, NSArray<NSError *> *errors) {
                if (!success) {
                    succeeded = NO;
                    [rErrors addObjectsFromArray:errors];
                }
                dispatch_group_leave(dispatchGroup);
            }
                       onCompletionQueue:completionQueue];
        }
        dispatch_group_notify(dispatchGroup, completionQueue, ^{
            BOOL hasMore = documents->count == DAPI_DOCUMENT_RESPONSE_COUNT_LIMIT;
            if (!hasMore)
                [self.platformContext performBlockAndWait:^{
                    self.lastCheckedOutgoingContactsTimestamp = [[NSDate date] timeIntervalSince1970];
                }];
            [debugInfo appendFormat:@" : OK: %u: %@", succeeded, rErrors];
            DSLog(@"%@", debugInfo);
            __block NSData * hasMoreStartAfter = nil;
            if (documents->count > 0) {
                DContactRequestKind *last = documents->values[documents->count-1];
                if (last->outgoing)
                    hasMoreStartAfter = NSDataFromPtr(last->outgoing->id);
            }
            if (succeeded && hasMoreStartAfter)
                [self fetchOutgoingContactRequestsInContext:context
                                                 startAfter:hasMoreStartAfter
                                             withCompletion:completion
                                          onCompletionQueue:completionQueue];
            else if (completion)
                completion(succeeded, [rErrors copy]);
        });
    });
}


- (NSData *)decryptedPublicKeyDataWithKey:(DOpaqueKey *)key
                                  request:(dash_spv_platform_models_contact_request_ContactRequest *)request {
    NSParameterAssert(key);
    DKeyKind *kind = DOpaqueKeyKind(key);
    uint32_t index = uint256_eq(self.uniqueID, u256_cast(request->recipient)) ? request->sender_key_index : request->recipient_key_index;
    DMaybeOpaqueKey *maybe_key = [self privateKeyAtIndex:index ofType:kind];
    NSAssert(maybe_key->ok, @"Key should exist");
    DMaybeKeyData *key_data = dash_spv_crypto_keys_key_OpaqueKey_decrypt_data_vec(maybe_key->ok, key, request->encrypted_public_key);
    NSData *data = key_data->ok ? NSDataFromPtr(key_data->ok) : nil;
    DMaybeKeyDataDtor(key_data);
    DMaybeOpaqueKeyDtor(maybe_key);
    return data;
}

- (void)handleIncomingRequests:(NSArray<NSValue *> *)incomingRequests
                       context:(NSManagedObjectContext *)context
                    completion:(void (^)(BOOL success, NSArray<NSError *> *errors))completion
             onCompletionQueue:(dispatch_queue_t)completionQueue {
    if (!self.isActive) {
        if (completion) dispatch_async(completionQueue, ^{ completion(NO, @[ERROR_IDENTITY_NO_LONGER_ACTIVE]); });
        return;
    }
    [context performBlockAndWait:^{
        __block BOOL succeeded = YES;
        __block NSMutableArray *errors = [NSMutableArray array];
        dispatch_group_t dispatchGroup = dispatch_group_create();
        
        for (NSValue *contactRequest in incomingRequests) {
            DContactRequest *request = contactRequest.pointerValue;
            NSData *senderIdentityUniqueId = NSDataFromPtr(request->owner_id);
            DSBlockchainIdentityEntity *externalIdentityEntity = [DSBlockchainIdentityEntity anyObjectInContext:context matching:@"uniqueID == %@", senderIdentityUniqueId];
            if (!externalIdentityEntity) {
                //no externalBlockchainIdentity exists yet, which means no dashpay user
                dispatch_group_enter(dispatchGroup);
                DSIdentity *senderIdentity = [self.identitiesManager foreignIdentityWithUniqueId:senderIdentityUniqueId.UInt256 createIfMissing:YES inContext:context];
                [senderIdentity fetchNeededNetworkStateInformationInContext:self.platformContext
                                                             withCompletion:^(DSIdentityQueryStep failureStep, NSArray<NSError *> *_Nullable networkErrors) {
                    if (!failureStep) {
                        DOpaqueKey *senderPublicKey = [senderIdentity keyAtIndex:request->sender_key_index];
                        NSData *extendedPublicKeyData = [self decryptedPublicKeyDataWithKey:senderPublicKey request:request];
                        DMaybeOpaqueKey *extendedPublicKey = [DSKeyManager keyWithExtendedPublicKeyData:extendedPublicKeyData ofType:DKeyKindECDSA()];
                        if (!extendedPublicKey) {
                            succeeded = FALSE;
                            [errors addObject:ERROR_KEY_FORMAT_DECRYPTION];
                        } else {
                            DSDashpayUserEntity *senderDashpayUserEntity = [senderIdentity identityEntityInContext:context].matchingDashpayUser;
                            NSAssert(senderDashpayUserEntity, @"The sender should exist");
                            [self addIncomingRequestFromContact:senderDashpayUserEntity
                                           forExtendedPublicKey:extendedPublicKey
                                                    atTimestamp:request->created_at];
                        }
                    } else {
                        [errors addObjectsFromArray:networkErrors];
                    }
                    dispatch_group_leave(dispatchGroup);
                }
                                                          onCompletionQueue:self.identityQueue];
                
            } else {
                if ([self.chain identityForUniqueId:externalIdentityEntity.uniqueID.UInt256]) {
                    //it's also local (aka both contacts are local to this device), we should store the extended public key for the destination
                    DSIdentity *sourceIdentity = [self.chain identityForUniqueId:externalIdentityEntity.uniqueID.UInt256];
                    DSAccount *account = [sourceIdentity.wallet accountWithNumber:0];
                    DSPotentialOneWayFriendship *potentialFriendship = [[DSPotentialOneWayFriendship alloc] initWithDestinationIdentity:self destinationKeyIndex:request->recipient_key_index sourceIdentity:sourceIdentity sourceKeyIndex:request->sender_key_index account:account];
                    if (![DSFriendRequestEntity existingFriendRequestEntityWithSourceIdentifier:sourceIdentity.uniqueID destinationIdentifier:self.uniqueID onAccountIndex:account.accountNumber inContext:context]) {
                        dispatch_group_enter(dispatchGroup);
                        [potentialFriendship createDerivationPathAndSaveExtendedPublicKeyWithCompletion:^(BOOL success, DSIncomingFundsDerivationPath *_Nonnull incomingFundsDerivationPath) {
                            if (success) {
                                DSDashpayUserEntity *matchingDashpayUserInContext = [self matchingDashpayUserInContext:context];
                                DSFriendRequestEntity *friendRequest = [potentialFriendship outgoingFriendRequestForDashpayUserEntity:matchingDashpayUserInContext atTimestamp:request->created_at];
                                [potentialFriendship storeExtendedPublicKeyAssociatedWithFriendRequest:friendRequest];
                                [matchingDashpayUserInContext addIncomingRequestsObject:friendRequest];
                                if ([[friendRequest.sourceContact.incomingRequests filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"sourceContact == %@", matchingDashpayUserInContext]] count])
                                    [matchingDashpayUserInContext addFriendsObject:friendRequest.sourceContact];
                                [account addIncomingDerivationPath:incomingFundsDerivationPath
                                           forFriendshipIdentifier:friendRequest.friendshipIdentifier
                                                         inContext:context];
                                [context ds_save];
                                [self.chain.chainManager.transactionManager updateTransactionsBloomFilter];
                            } else {
                                succeeded = FALSE;
                                [errors addObject:ERROR_DERIVATION_FRIENDSHIP];
                            }
                            dispatch_group_leave(dispatchGroup);
                        }];
                    }
                    
                } else {
                    DSIdentity *sourceIdentity = [[DSIdentity alloc] initWithIdentityEntity:externalIdentityEntity];
                    NSAssert(sourceIdentity, @"This should not be null");
                    if ([sourceIdentity activeKeyCount] > 0 && [sourceIdentity keyAtIndex:request->sender_key_index]) {
                        //the contact already existed, and has an encryption public key set, create the incoming friend request, add a friendship if an outgoing friend request also exists
                        DOpaqueKey *key = [sourceIdentity keyAtIndex:request->sender_key_index];
                        NSData *decryptedExtendedPublicKeyData = [self decryptedPublicKeyDataWithKey:key request:request];
                        NSAssert(decryptedExtendedPublicKeyData, @"Data should be decrypted");
                        DMaybeOpaqueKey *extendedPublicKey = [DSKeyManager keyWithExtendedPublicKeyData:decryptedExtendedPublicKeyData ofType:DKeyKindECDSA()];
                        if (!extendedPublicKey) {
                            succeeded = FALSE;
                            [errors addObject:ERROR_CONTACT_REQUEST_KEY_ENCRYPTION];
                            return;
                        }
                        [self addIncomingRequestFromContact:externalIdentityEntity.matchingDashpayUser
                                       forExtendedPublicKey:extendedPublicKey
                                                atTimestamp:request->created_at];
                        
                        DSDashpayUserEntity *matchingDashpayUserInContext = [self matchingDashpayUserInContext:context];
                        if ([[externalIdentityEntity.matchingDashpayUser.incomingRequests filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"sourceContact == %@", matchingDashpayUserInContext]] count]) {
                            [matchingDashpayUserInContext addFriendsObject:[externalIdentityEntity matchingDashpayUser]];
                            [context ds_save];
                        }
                        
                    } else {
                        //the blockchain identity is already known, but needs to updated to get the right key, create the incoming friend request, add a friendship if an outgoing friend request also exists
                        dispatch_group_enter(dispatchGroup);
                        [sourceIdentity fetchNeededNetworkStateInformationInContext:context
                                                                     withCompletion:^(DSIdentityQueryStep failureStep, NSArray<NSError *> *networkStateInformationErrors) {
                            if (!failureStep) {
                                [context performBlockAndWait:^{
                                    DOpaqueKey *key = [sourceIdentity keyAtIndex:request->sender_key_index];
                                    NSAssert(key, @"key should be known");
                                    NSData *decryptedExtendedPublicKeyData = [self decryptedPublicKeyDataWithKey:key request:request];
                                    NSAssert(decryptedExtendedPublicKeyData, @"Data should be decrypted");
                                    DMaybeOpaqueKey *extendedPublicKey = [DSKeyManager keyWithExtendedPublicKeyData:decryptedExtendedPublicKeyData ofType:DKeyKindECDSA()];
                                    NSAssert(extendedPublicKey, @"A key should be recovered");
                                    [self addIncomingRequestFromContact:externalIdentityEntity.matchingDashpayUser
                                                   forExtendedPublicKey:extendedPublicKey
                                                            atTimestamp:request->created_at];
                                    DSDashpayUserEntity *matchingDashpayUserInContext = [self matchingDashpayUserInContext:context];
                                    if ([[externalIdentityEntity.matchingDashpayUser.incomingRequests filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"sourceContact == %@", matchingDashpayUserInContext]] count]) {
                                        [matchingDashpayUserInContext addFriendsObject:externalIdentityEntity.matchingDashpayUser];
                                        [context ds_save];
                                    }
                                }];
                            } else {
                                succeeded = FALSE;
                                [errors addObjectsFromArray:networkStateInformationErrors];
                            }
                            dispatch_group_leave(dispatchGroup);
                        }
                                                                  onCompletionQueue:self.identityQueue];
                    }
                }
            }
        }
        dispatch_group_notify(dispatchGroup, completionQueue, ^{
            for (NSValue *request in incomingRequests) {
                DContactRequestDtor(request.pointerValue);
            }

            if (completion) completion(succeeded, [errors copy]);
        });
    }];
}

- (void)handleOutgoingRequests:(NSArray<NSValue *> *)outgoingRequests
                       context:(NSManagedObjectContext *)context
                    completion:(void (^)(BOOL success, NSArray<NSError *> *errors))completion
             onCompletionQueue:(dispatch_queue_t)completionQueue {
    if (!self.isActive) {
        if (completion) dispatch_async(completionQueue, ^{ completion(NO, @[ERROR_IDENTITY_NO_LONGER_ACTIVE]); });
        return;
    }
    [context performBlockAndWait:^{
        __block NSMutableArray *errors = [NSMutableArray array];
        __block BOOL succeeded = YES;
        dispatch_group_t dispatchGroup = dispatch_group_create();
        for (NSValue *contactRequest in outgoingRequests) {
            DContactRequest *request = contactRequest.pointerValue;
            
            DSBlockchainIdentityEntity *recipientIdentityEntity = [DSBlockchainIdentityEntity anyObjectInContext:context matching:@"uniqueID == %@", NSDataFromPtr(request->recipient)];
            if (!recipientIdentityEntity) {
                //no contact exists yet
                dispatch_group_enter(dispatchGroup);
                DSIdentity *recipientIdentity = [self.identitiesManager foreignIdentityWithUniqueId:u256_cast(request->recipient)
                                                                                    createIfMissing:YES
                                                                                          inContext:context];
                NSAssert([recipientIdentity identityEntityInContext:context], @"Entity should now exist");
                [recipientIdentity fetchNeededNetworkStateInformationInContext:context
                                                                withCompletion:^(DSIdentityQueryStep failureStep, NSArray<NSError *> *_Nullable networkErrors) {
                    if (!failureStep) {
                        [self addFriendshipFromSourceIdentity:self
                                               sourceKeyIndex:request->sender_key_index
                                          toRecipientIdentity:recipientIdentity
                                            recipientKeyIndex:request->recipient_key_index
                                                  atTimestamp:request->created_at
                                                    inContext:context];
                    } else {
                        succeeded = FALSE;
                        [errors addObjectsFromArray:networkErrors];
                    }
                    dispatch_group_leave(dispatchGroup);
                }
                                                             onCompletionQueue:self.identityQueue];
            } else {
                //the recipient blockchain identity is already known, meaning they had made a friend request to us before, and on another device we had accepted
                //or the recipient blockchain identity is also local to the device
                
                DSWallet *recipientWallet = nil;
                DSIdentity *recipientIdentity = [self.chain identityForUniqueId:recipientIdentityEntity.uniqueID.UInt256
                                                                  foundInWallet:&recipientWallet];
                BOOL isLocal = TRUE;
                if (!recipientIdentity) {
                    //this is not local
                    recipientIdentity = [[DSIdentity alloc] initWithIdentityEntity:recipientIdentityEntity];
                    isLocal = FALSE;
                }
                
                dispatch_group_enter(dispatchGroup);
                [recipientIdentity fetchIfNeededNetworkStateInformation:DSIdentityQueryStep_Profile & DSIdentityQueryStep_Username & DSIdentityQueryStep_Identity
                                                              inContext:context
                                                         withCompletion:^(DSIdentityQueryStep failureStep, NSArray<NSError *> *_Nullable networkErrors) {
                    if (!failureStep) {
                        [self addFriendshipFromSourceIdentity:self
                                               sourceKeyIndex:request->sender_key_index
                                          toRecipientIdentity:recipientIdentity
                                            recipientKeyIndex:request->recipient_key_index
                                                  atTimestamp:request->created_at
                                                    inContext:context];
                    } else {
                        succeeded = FALSE;
                        [errors addObjectsFromArray:networkErrors];
                    }
                    dispatch_group_leave(dispatchGroup);
                }
                                                      onCompletionQueue:self.identityQueue];
            }
        }
        dispatch_group_notify(dispatchGroup, completionQueue, ^{
            for (NSValue *request in outgoingRequests) {
                DContactRequestDtor(request.pointerValue);
            }
            if (completion) completion(succeeded, [errors copy]);
            
        });
    }];
}

- (void)addIncomingRequestFromContact:(DSDashpayUserEntity *)dashpayUserEntity
                 forExtendedPublicKey:(DMaybeOpaqueKey *)extendedPublicKey
                          atTimestamp:(NSTimeInterval)timestamp {
    NSManagedObjectContext *context = dashpayUserEntity.managedObjectContext;
    DSFriendRequestEntity *friendRequestEntity = [DSFriendRequestEntity managedObjectInBlockedContext:context];
    friendRequestEntity.sourceContact = dashpayUserEntity;
    friendRequestEntity.destinationContact = [self matchingDashpayUserInContext:dashpayUserEntity.managedObjectContext];
    friendRequestEntity.timestamp = timestamp;
    NSAssert(friendRequestEntity.sourceContact != friendRequestEntity.destinationContact, @"This must be different contacts");
    DSDerivationPathEntity *derivationPathEntity = [DSDerivationPathEntity managedObjectInBlockedContext:context];
    derivationPathEntity.chain = [self.chain chainEntityInContext:context];
    friendRequestEntity.derivationPath = derivationPathEntity;
    NSAssert(friendRequestEntity.derivationPath, @"There must be a derivation path");
    DSAccount *account = [self.wallet accountWithNumber:0];
    DSAccountEntity *accountEntity = [DSAccountEntity accountEntityForWalletUniqueID:self.wallet.uniqueIDString index:account.accountNumber onChain:self.chain inContext:dashpayUserEntity.managedObjectContext];
    derivationPathEntity.account = accountEntity;
    friendRequestEntity.account = accountEntity;
    [friendRequestEntity finalizeWithFriendshipIdentifier];
    //NSLog(@"->created derivation path entity %@ %@", friendRequestEntity.friendshipIdentifier.hexString, [NSThread callStackSymbols]);
    DSIncomingFundsDerivationPath *derivationPath = [DSIncomingFundsDerivationPath externalDerivationPathWithExtendedPublicKey:extendedPublicKey withDestinationIdentityUniqueId:[self matchingDashpayUserInContext:dashpayUserEntity.managedObjectContext].associatedBlockchainIdentity.uniqueID.UInt256 sourceIdentityUniqueId:dashpayUserEntity.associatedBlockchainIdentity.uniqueID.UInt256 onChain:self.chain];
    derivationPathEntity.publicKeyIdentifier = derivationPath.standaloneExtendedPublicKeyUniqueID;
    [derivationPath storeExternalDerivationPathExtendedPublicKeyToKeyChain];
    //incoming request uses an outgoing derivation path
    [account addOutgoingDerivationPath:derivationPath forFriendshipIdentifier:friendRequestEntity.friendshipIdentifier inContext:dashpayUserEntity.managedObjectContext];
    DSDashpayUserEntity *matchingDashpayUser = [self matchingDashpayUserInContext:dashpayUserEntity.managedObjectContext];
    [matchingDashpayUser addIncomingRequestsObject:friendRequestEntity];
    if ([[friendRequestEntity.sourceContact.incomingRequests filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"sourceContact == %@", matchingDashpayUser]] count])
        [matchingDashpayUser addFriendsObject:friendRequestEntity.sourceContact];
    [context ds_save];
    [self.chain.chainManager.transactionManager updateTransactionsBloomFilter];
}

@end
