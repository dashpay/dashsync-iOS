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
#import "DSContactRequest.h"
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
                                           withCompletion:completion
                                        onCompletionQueue:completionQueue];
    }
                              onCompletionQueue:self.identityQueue];
}

- (void)fetchIncomingContactRequests:(void (^_Nullable)(BOOL success, NSArray<NSError *> *errors))completion {
    [self fetchIncomingContactRequestsInContext:self.platformContext
                                 withCompletion:completion
                              onCompletionQueue:dispatch_get_main_queue()];
}

- (void)fetchIncomingContactRequestsInContext:(NSManagedObjectContext *)context
                               withCompletion:(void (^)(BOOL success, NSArray<NSError *> *errors))completion
                            onCompletionQueue:(dispatch_queue_t)completionQueue {
    [self fetchIncomingContactRequestsInContext:context
                                     startAfter:nil
                                    retriesLeft:DEFAULT_CONTACT_REQUEST_FETCH_RETRIES
                                 withCompletion:completion
                              onCompletionQueue:completionQueue];
}

- (void)fetchIncomingContactRequestsInContext:(NSManagedObjectContext *)context
                                   startAfter:(NSData*_Nullable)startAfter
                                  retriesLeft:(int32_t)retriesLeft
                               withCompletion:(void (^)(BOOL success, NSArray<NSError *> *errors))completion
                            onCompletionQueue:(dispatch_queue_t)completionQueue {
    
    [self internalFetchIncomingContactRequestsInContext:context
                                             startAfter:startAfter
                                         withCompletion:^(BOOL success, NSData*_Nullable hasMoreStartAfter, NSArray<NSError *> *errors) {
        if (!success && retriesLeft > 0) {
            [self fetchIncomingContactRequestsInContext:context startAfter:startAfter retriesLeft:retriesLeft - 1 withCompletion:completion onCompletionQueue:completionQueue];
        } else if (success && hasMoreStartAfter) {
            [self fetchIncomingContactRequestsInContext:context startAfter:hasMoreStartAfter retriesLeft:DEFAULT_CONTACT_REQUEST_FETCH_RETRIES withCompletion:completion onCompletionQueue:completionQueue];
        } else if (completion) {
            completion(success, errors);
        }
    }
                                      onCompletionQueue:completionQueue];
}

- (void)internalFetchIncomingContactRequestsInContext:(NSManagedObjectContext *)context
                                           startAfter:(NSData*_Nullable)startAfter
                                       withCompletion:(void (^)(BOOL success, NSData*_Nullable hasMoreStartAfter, NSArray<NSError *> *errors))completion
                                    onCompletionQueue:(dispatch_queue_t)completionQueue {
    DPContract *dashpayContract = [DSDashPlatform sharedInstanceForChain:self.chain].dashPayContract;
    if (dashpayContract.contractState != DPContractState_Registered) {
        if (completion) dispatch_async(completionQueue, ^{ completion(NO, nil, @[ERROR_DASHPAY_CONTRACT_IMPROPER_SETUP]); });
        return;
    }
    NSError *error = nil;
    if (![self activePrivateKeysAreLoadedWithFetchingError:&error]) {
        // The blockchain identity hasn't been intialized on the device, ask the user to activate the blockchain user, this action allows private keys to be cached on the blockchain identity level
        if (completion) dispatch_async(completionQueue, ^{ completion(NO, nil, @[error ? error : ERROR_IDENTITY_NOT_ACTIVATED]); });
        return;
    }
    u256 *user_id = u256_ctor_u(self.uniqueID);
    uint64_t since = self.lastCheckedIncomingContactsTimestamp ? (self.lastCheckedIncomingContactsTimestamp - HOUR_TIME_INTERVAL) : 0;
    BYTES *start_after = startAfter ? bytes_ctor(startAfter) : nil;
    __weak typeof(self) weakSelf = self;
    DMaybeContactRequests *result = dash_spv_platform_document_contact_request_ContactRequestManager_incoming_contact_requests(self.chain.shareCore.runtime, self.chain.shareCore.contactRequests->obj, user_id, since, start_after);
    if (result->error) {
        NSError *error = [NSError ffi_from_platform_error:result->error];
        DMaybeContactRequestsDtor(result);
        if (completion) dispatch_async(completionQueue, ^{ completion(NO, nil, @[error]); });
        return;
    }
    DContactRequests *documents = result->ok;

    dispatch_async(self.identityQueue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            if (completion) dispatch_async(completionQueue, ^{ completion(NO, nil, @[ERROR_MEM_ALLOC]); });
            return;
        }
        [strongSelf handleContactRequestObjects:documents
                                        context:context
                                     completion:^(BOOL success, NSArray<NSError *> *errors) {
            BOOL hasMore = result->ok->count == DAPI_DOCUMENT_RESPONSE_COUNT_LIMIT;
            if (!hasMore)
                [self.platformContext performBlockAndWait:^{
                    self.lastCheckedIncomingContactsTimestamp = [[NSDate date] timeIntervalSince1970];
                }];
            if (completion) {
                dash_spv_platform_models_contact_request_ContactRequestKind *last = documents->values[documents->count-1];
                __block NSData * hasMoreStartAfter = nil;
                if (last->incoming)
                    hasMoreStartAfter = NSDataFromPtr(last->incoming->id);
                else if (last->outgoing)
                    hasMoreStartAfter = NSDataFromPtr(last->outgoing->id);

//                NSData * hasMoreStartAfter = documents.lastObject[@"$id"];
                dispatch_async(completionQueue, ^{ completion(success, hasMoreStartAfter, errors); });
            }
        }
                              onCompletionQueue:self.identityQueue];
    });

//    __weak typeof(self) weakSelf = self;
//    [self.DAPINetworkService getDashpayIncomingContactRequestsForUserId:self.uniqueIDData
//                                                                  since:self.lastCheckedIncomingContactsTimestamp ? (self.lastCheckedIncomingContactsTimestamp - HOUR_TIME_INTERVAL) : 0
//                                                             startAfter:startAfter
//                                                        completionQueue:self.identityQueue
//                                                                success:^(NSArray<NSDictionary *> *_Nonnull documents) {
//        //todo chance the since parameter
//        __strong typeof(weakSelf) strongSelf = weakSelf;
//        if (!strongSelf) {
//            if (completion) dispatch_async(completionQueue, ^{ completion(NO, nil, @[ERROR_MEM_ALLOC]); });
//            return;
//        }
//        
//        dispatch_async(self.identityQueue, ^{
//            [strongSelf handleContactRequestObjects:documents
//                                            context:context
//                                         completion:^(BOOL success, NSArray<NSError *> *errors) {
//                BOOL hasMore = documents.count == DAPI_DOCUMENT_RESPONSE_COUNT_LIMIT;
//                if (!hasMore)
//                    [self.platformContext performBlockAndWait:^{
//                        self.lastCheckedIncomingContactsTimestamp = [[NSDate date] timeIntervalSince1970];
//                    }];
//                if (completion) {
//                    NSData * hasMoreStartAfter = documents.lastObject[@"$id"];
//                    dispatch_async(completionQueue, ^{ completion(success, hasMoreStartAfter, errors); });
//                }
//            }
//                                  onCompletionQueue:self.identityQueue];
//        });
//    }
//                                                                failure:^(NSError *_Nonnull error) {
//        if (completion) dispatch_async(completionQueue, ^{ completion(NO, nil, @[error]); });
//    }];
}

- (void)fetchOutgoingContactRequests:(void (^)(BOOL success, NSArray<NSError *> *errors))completion {
    [self fetchOutgoingContactRequestsInContext:self.platformContext
                                 withCompletion:completion
                              onCompletionQueue:dispatch_get_main_queue()];
}

- (void)fetchOutgoingContactRequestsInContext:(NSManagedObjectContext *)context
                               withCompletion:(void (^)(BOOL success, NSArray<NSError *> *errors))completion
                            onCompletionQueue:(dispatch_queue_t)completionQueue {
    [self fetchOutgoingContactRequestsInContext:context
                                     startAfter:nil
                                    retriesLeft:DEFAULT_CONTACT_REQUEST_FETCH_RETRIES
                                 withCompletion:completion
                              onCompletionQueue:completionQueue];
}

- (void)fetchOutgoingContactRequestsInContext:(NSManagedObjectContext *)context
                                   startAfter:(NSData*_Nullable)startAfter
                                  retriesLeft:(int32_t)retriesLeft
                               withCompletion:(void (^)(BOOL success, NSArray<NSError *> *errors))completion
                            onCompletionQueue:(dispatch_queue_t)completionQueue {
    [self internalFetchOutgoingContactRequestsInContext:context
                                             startAfter:startAfter
                                         withCompletion:^(BOOL success, NSData*_Nullable hasMoreStartAfter, NSArray<NSError *> *errors) {
        if (!success && retriesLeft > 0) {
            [self fetchOutgoingContactRequestsInContext:context startAfter:startAfter retriesLeft:retriesLeft - 1 withCompletion:completion onCompletionQueue:completionQueue];
        } else if (success && hasMoreStartAfter) {
            [self fetchOutgoingContactRequestsInContext:context startAfter:hasMoreStartAfter retriesLeft:DEFAULT_CONTACT_REQUEST_FETCH_RETRIES withCompletion:completion onCompletionQueue:completionQueue];
        } else if (completion) {
            completion(success, errors);
        }
    }
                                      onCompletionQueue:completionQueue];
}

- (void)internalFetchOutgoingContactRequestsInContext:(NSManagedObjectContext *)context
                                           startAfter:(NSData*_Nullable)startAfter
                                       withCompletion:(void (^)(BOOL success, NSData*_Nullable hasMoreStartAfter, NSArray<NSError *> *errors))completion
                                    onCompletionQueue:(dispatch_queue_t)completionQueue {
    DPContract *dashpayContract = [DSDashPlatform sharedInstanceForChain:self.chain].dashPayContract;
    if (dashpayContract.contractState != DPContractState_Registered) {
        if (completion) dispatch_async(completionQueue, ^{ completion(NO, nil, @[ERROR_DASHPAY_CONTRACT_IMPROPER_SETUP]); });
        return;
    }
    NSError *error = nil;
    if (![self activePrivateKeysAreLoadedWithFetchingError:&error]) {
        //The blockchain identity hasn't been intialized on the device, ask the user to activate the blockchain user, this action allows private keys to be cached on the blockchain identity level
        if (completion) dispatch_async(completionQueue, ^{ completion(NO, nil, @[error ? error : ERROR_IDENTITY_NOT_ACTIVATED]); });
        return;
    }
    __weak typeof(self) weakSelf = self;
    
    BYTES *start_after = startAfter ? bytes_ctor(startAfter) : NULL;
    uint64_t since = self.lastCheckedOutgoingContactsTimestamp ? (self.lastCheckedOutgoingContactsTimestamp - HOUR_TIME_INTERVAL) : 0;
    u256 *user_id = u256_ctor_u(self.uniqueID);
    DMaybeContactRequests *result = dash_spv_platform_document_contact_request_ContactRequestManager_outgoing_contact_requests(self.chain.shareCore.runtime, self.chain.shareCore.contactRequests->obj, user_id, since, start_after);
    if (result->error) {
        NSError *error = [NSError ffi_from_platform_error:result->error];
        DMaybeContactRequestsDtor(result);
        if (completion) dispatch_async(completionQueue, ^{ completion(NO, nil, @[error]); });
        return;
    }
    
    dispatch_async(self.identityQueue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        DContactRequests *documents = result->ok;
        [strongSelf handleContactRequestObjects:documents
                                        context:context
                                     completion:^(BOOL success, NSArray<NSError *> *errors) {
            BOOL hasMore = documents->count == DAPI_DOCUMENT_RESPONSE_COUNT_LIMIT;
            if (!hasMore)
                [self.platformContext performBlockAndWait:^{
                    self.lastCheckedOutgoingContactsTimestamp = [[NSDate date] timeIntervalSince1970];
                }];
            dash_spv_platform_models_contact_request_ContactRequestKind *last = documents->values[documents->count-1];
            __block NSData * hasMoreStartAfter = nil;
            if (last->incoming)
                hasMoreStartAfter = NSDataFromPtr(last->incoming->id);
            else if (last->outgoing)
                hasMoreStartAfter = NSDataFromPtr(last->outgoing->id);

            dispatch_async(completionQueue, ^{ completion(success, hasMoreStartAfter, errors); });
        }
                              onCompletionQueue:self.identityQueue];
    });

    
//    [self.DAPINetworkService getDashpayOutgoingContactRequestsForUserId:self.uniqueIDData
//                                                                  since:self.lastCheckedOutgoingContactsTimestamp ? (self.lastCheckedOutgoingContactsTimestamp - HOUR_TIME_INTERVAL) : 0
//                                                             startAfter:startAfter
//                                                        completionQueue:self.identityQueue
//                                                                success:^(NSArray<NSDictionary *> *_Nonnull documents) {
//        //todo chance the since parameter
//        __strong typeof(weakSelf) strongSelf = weakSelf;
//        if (!strongSelf) {
//            if (completion) dispatch_async(completionQueue, ^{ completion(NO, nil, @[ERROR_MEM_ALLOC]); });
//            return;
//        }
//        
//        dispatch_async(self.identityQueue, ^{
//            [strongSelf handleContactRequestObjects:documents
//                                            context:context
//                                         completion:^(BOOL success, NSArray<NSError *> *errors) {
//                BOOL hasMore = documents.count == DAPI_DOCUMENT_RESPONSE_COUNT_LIMIT;
//                if (!hasMore)
//                    [self.platformContext performBlockAndWait:^{
//                        self.lastCheckedOutgoingContactsTimestamp = [[NSDate date] timeIntervalSince1970];
//                    }];
//                __block NSData * hasMoreStartAfter = success?documents.lastObject[@"$id"]:nil;
//                dispatch_async(completionQueue, ^{ completion(success, hasMoreStartAfter, errors); });
//            }
//                                  onCompletionQueue:self.identityQueue];
//        });
//    }
//                                                                failure:^(NSError *_Nonnull error) {
//        if (completion) dispatch_async(completionQueue, ^{ completion(NO, nil, @[error]); });
//    }];
}

// MARK: Response Processing



/// Handle an array of contact requests. This method will split contact requests into either incoming contact requests or outgoing contact requests and then call methods for handling them if applicable.
/// @param rawContactRequests A dictionary of rawContactRequests, these are returned by the network.
/// @param context The managed object context in which to process results.
/// @param completion Completion callback with success boolean.
- (void)handleContactRequestObjects:(DContactRequests *)rawContactRequests
                            context:(NSManagedObjectContext *)context
                         completion:(void (^)(BOOL success, NSArray<NSError *> *errors))completion
                  onCompletionQueue:(dispatch_queue_t)completionQueue {
    NSAssert(completionQueue == self.identityQueue, @"we should be on identity queue");
    __block NSMutableArray<NSValue *> *incomingNewRequests = [NSMutableArray array];
    __block NSMutableArray<NSValue *> *outgoingNewRequests = [NSMutableArray array];
    __block NSMutableArray *rErrors = [NSMutableArray array];
    [context performBlockAndWait:^{
        for (int i = 0; i < rawContactRequests->count; i++) {
            dash_spv_platform_models_contact_request_ContactRequestKind *kind = rawContactRequests->values[i];
            switch (kind->tag) {
                case dash_spv_platform_models_contact_request_ContactRequestKind_Incoming: {
                    NSData *identifier = NSDataFromPtr(kind->incoming->owner_id);
                    //we are the recipient, this is an incoming request
                    DSFriendRequestEntity *exist = [DSFriendRequestEntity anyObjectInContext:context matching:@"destinationContact == %@ && sourceContact.associatedBlockchainIdentity.uniqueID == %@", [self matchingDashpayUserInContext:context], identifier];
                    // TODO: memory
                    if (!exist) [incomingNewRequests addObject:[NSValue valueWithPointer:kind->incoming]];
                    break;
                }
                case dash_spv_platform_models_contact_request_ContactRequestKind_Outgoing: {
                    NSData *identifier = NSDataFromPtr(kind->outgoing->recipient);

                    BOOL exist = [DSFriendRequestEntity countObjectsInContext:context matching:@"sourceContact == %@ && destinationContact.associatedBlockchainIdentity.uniqueID == %@", [self matchingDashpayUserInContext:context], identifier];
                    // TODO: memory
                    if (!exist) [outgoingNewRequests addObject:[NSValue valueWithPointer:kind->outgoing]];
                    break;
                }
                default: {
                    //we should not have received this
                    NSAssert(FALSE, @"the contact request needs to be either outgoing or incoming");
                    break;
                }
            }
        }
//        for (NSDictionary *rawContact in rawContactRequests) {
//            DSContactRequest *contactRequest = [DSContactRequest contactRequestFromDictionary:rawContact onIdentity:self];
//            if (uint256_eq(contactRequest.recipientIdentityUniqueId, self.uniqueID)) {
//                //we are the recipient, this is an incoming request
//                DSFriendRequestEntity *friendRequest = [DSFriendRequestEntity anyObjectInContext:context matching:@"destinationContact == %@ && sourceContact.associatedBlockchainIdentity.uniqueID == %@", [self matchingDashpayUserInContext:context], uint256_data(contactRequest.senderIdentityUniqueId)];
//                if (!friendRequest)
//                    [incomingNewRequests addObject:contactRequest];
//            } else if (uint256_eq(contactRequest.senderIdentityUniqueId, self.uniqueID)) {
//                //we are the sender, this is an outgoing request
//                BOOL isNew = ![DSFriendRequestEntity countObjectsInContext:context matching:@"sourceContact == %@ && destinationContact.associatedBlockchainIdentity.uniqueID == %@", [self matchingDashpayUserInContext:context], [NSData dataWithUInt256:contactRequest.recipientIdentityUniqueId]];
//                if (isNew) [outgoingNewRequests addObject:contactRequest];
//            } else {
//                //we should not have received this
//                NSAssert(FALSE, @"the contact request needs to be either outgoing or incoming");
//            }
//        }
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
    dispatch_group_notify(dispatchGroup, completionQueue, ^{ if (completion) completion(succeeded, [rErrors copy]); });
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
            dash_spv_platform_models_contact_request_ContactRequest *request = contactRequest.pointerValue;
            NSData *senderIdentityUniqueId = NSDataFromPtr(request->owner_id);
            DSBlockchainIdentityEntity *externalIdentityEntity = [DSBlockchainIdentityEntity anyObjectInContext:context matching:@"uniqueID == %@", senderIdentityUniqueId];
            if (!externalIdentityEntity) {
                //no externalBlockchainIdentity exists yet, which means no dashpay user
                dispatch_group_enter(dispatchGroup);
                DSIdentity *senderIdentity = [self.identitiesManager foreignIdentityWithUniqueId:senderIdentityUniqueId.UInt256 createIfMissing:YES inContext:context];
                [senderIdentity fetchNeededNetworkStateInformationInContext:self.platformContext
                                                             withCompletion:^(DSIdentityQueryStep failureStep, NSArray<NSError *> *_Nullable networkErrors) {
                    if (!failureStep) {
                        DMaybeOpaqueKey *senderPublicKey = [senderIdentity keyAtIndex:request->sender_key_index];
                        NSData *extendedPublicKeyData = [self decryptedPublicKeyDataWithKey:senderPublicKey->ok request:request];
                        DMaybeOpaqueKey *extendedPublicKey = [DSKeyManager keyWithExtendedPublicKeyData:extendedPublicKeyData ofType:dash_spv_crypto_keys_key_KeyKind_ECDSA_ctor()];
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
                        DMaybeOpaqueKey *key = [sourceIdentity keyAtIndex:request->sender_key_index];
                        NSData *decryptedExtendedPublicKeyData = [self decryptedPublicKeyDataWithKey:key->ok request:request];
                        NSAssert(decryptedExtendedPublicKeyData, @"Data should be decrypted");
                        dash_spv_crypto_keys_key_KeyKind *kind = dash_spv_crypto_keys_key_KeyKind_ECDSA_ctor();
                        DMaybeOpaqueKey *extendedPublicKey = [DSKeyManager keyWithExtendedPublicKeyData:decryptedExtendedPublicKeyData ofType:kind];
//                        dash_spv_crypto_keys_key_KeyKind_destroy(kind);
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
                                    DMaybeOpaqueKey *key = [sourceIdentity keyAtIndex:request->sender_key_index];
                                    NSAssert(key, @"key should be known");
                                    NSData *decryptedExtendedPublicKeyData = [self decryptedPublicKeyDataWithKey:key->ok request:request];
                                    NSAssert(decryptedExtendedPublicKeyData, @"Data should be decrypted");
                                    DMaybeOpaqueKey *extendedPublicKey = [DSKeyManager keyWithExtendedPublicKeyData:decryptedExtendedPublicKeyData ofType:dash_spv_crypto_keys_key_KeyKind_ECDSA_ctor()];
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
        dispatch_group_notify(dispatchGroup, completionQueue, ^{ if (completion) completion(succeeded, [errors copy]); });
    }];
}

- (NSData *)decryptedPublicKeyDataWithKey:(DOpaqueKey *)key
                                  request:(dash_spv_platform_models_contact_request_ContactRequest *)request {
    NSParameterAssert(key);
    DKeyKind *kind = dash_spv_crypto_keys_key_OpaqueKey_kind(key);
    uint32_t index = uint256_eq(self.uniqueID, *(UInt256 *)request->recipient) ? request->sender_key_index : request->recipient_key_index;
    DMaybeOpaqueKey *maybe_key = [self privateKeyAtIndex:index ofType:kind];
    NSAssert(maybe_key->ok, @"Key should exist");
    DMaybeKeyData *key_data = dash_spv_crypto_keys_key_OpaqueKey_decrypt_data_vec(maybe_key->ok, key, request->encrypted_public_key);
    NSData *data = key_data->ok ? NSDataFromPtr(key_data->ok) : nil;
    DMaybeKeyDataDtor(key_data);
    DMaybeOpaqueKeyDtor(maybe_key);
    return data;
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
        for (DSContactRequest *contactRequest in outgoingRequests) {
            DSBlockchainIdentityEntity *recipientIdentityEntity = [DSBlockchainIdentityEntity anyObjectInContext:context matching:@"uniqueID == %@", uint256_data(contactRequest.recipientIdentityUniqueId)];
            if (!recipientIdentityEntity) {
                //no contact exists yet
                dispatch_group_enter(dispatchGroup);
                DSIdentity *recipientIdentity = [self.identitiesManager foreignIdentityWithUniqueId:contactRequest.recipientIdentityUniqueId
                                                                                    createIfMissing:YES
                                                                                          inContext:context];
                NSAssert([recipientIdentity identityEntityInContext:context], @"Entity should now exist");
                [recipientIdentity fetchNeededNetworkStateInformationInContext:context
                                                                withCompletion:^(DSIdentityQueryStep failureStep, NSArray<NSError *> *_Nullable networkErrors) {
                    if (!failureStep) {
                        [self addFriendshipFromSourceIdentity:self
                                               sourceKeyIndex:contactRequest.senderKeyIndex
                                          toRecipientIdentity:recipientIdentity
                                            recipientKeyIndex:contactRequest.recipientKeyIndex
                                                  atTimestamp:contactRequest.createdAt
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
                                               sourceKeyIndex:contactRequest.senderKeyIndex
                                          toRecipientIdentity:recipientIdentity
                                            recipientKeyIndex:contactRequest.recipientKeyIndex
                                                  atTimestamp:contactRequest.createdAt
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
        dispatch_group_notify(dispatchGroup, completionQueue, ^{ if (completion) completion(succeeded, [errors copy]); });
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
