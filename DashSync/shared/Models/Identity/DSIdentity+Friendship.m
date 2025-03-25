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
#import "DSIdentity+ContactRequest.h"
#import "DSIdentity+Friendship.h"
#import "DSIdentity+Profile.h"
#import "DSIdentity+Protected.h"
#import "DSIdentitiesManager+CoreData.h"

#import "DSTransactionManager+Protected.h"
#import "DSTransientDashpayUser.h"
#import "NSError+Dash.h"
#import "NSError+Platform.h"
#import "NSManagedObject+Sugar.h"

#define ERROR_KEY_HANDLING [NSError errorWithCode:501 localizedDescriptionKey:@"Internal key handling error"]
#define ERROR_INCOMPLETE_ACTIONS [NSError errorWithCode:501 localizedDescriptionKey:@"User has actions to complete before being able to use Dashpay"]
#define ERROR_DERIVATION_FRIENDSHIP [NSError errorWithCode:500 localizedDescriptionKey:@"Could not create friendship derivation path"]
#define ERROR_FRIEND_REQUEST_NONE_FOUND [NSError errorWithCode:501 localizedDescriptionKey:@"You can only accept a friend request from identity who has sent you one, and none were found"]
#define ERROR_FRIEND_REQUEST_ACCEPT_FROM_NON_LOCAL_IDENTITY [NSError errorWithCode:501 localizedDescriptionKey:@"Accepting a friend request should only happen from a local identity"]


@implementation DSIdentity (Friendship)

// MARK: Sending a Friend Request

- (void)sendNewFriendRequestToIdentity:(DSIdentity *)identity
                            completion:(void (^)(BOOL success, NSArray<NSError *> *_Nullable errors))completion {
    [self sendNewFriendRequestToIdentity:identity
                               inContext:self.platformContext
                              completion:completion
                       onCompletionQueue:dispatch_get_main_queue()];
}

- (void)sendNewFriendRequestToIdentity:(DSIdentity *)identity
                             inContext:(NSManagedObjectContext *)context
                            completion:(void (^)(BOOL success, NSArray<NSError *> *_Nullable errors))completion
                     onCompletionQueue:(dispatch_queue_t)completionQueue {
    if (identity.isTransient) {
        identity.isTransient = FALSE;
        [self.identitiesManager registerForeignIdentity:identity];
        if (identity.transientDashpayUser) {
            [identity applyProfileChanges:identity.transientDashpayUser
                                inContext:context
                              saveContext:YES
                               completion:^(BOOL success, NSError *_Nullable error) {
                if (success && !error) {
                    DSDashpayUserEntity *dashpayUser = [identity matchingDashpayUserInContext:context];
                    if (identity.transientDashpayUser.revision == dashpayUser.remoteProfileDocumentRevision)
                        identity.transientDashpayUser = nil;
                }
            }
                                  onCompletionQueue:self.identityQueue];
        }
    }
    [identity fetchNeededNetworkStateInformationInContext:context
                                           withCompletion:^(DSIdentityQueryStep failureStep, NSArray<NSError *> *_Nullable errors) {
        if (failureStep && failureStep != DSIdentityQueryStep_Profile) { //if profile fails we can still continue on
            completion(NO, errors);
            return;
        }
        if (![identity isDashpayReady]) {
            dispatch_async(completionQueue, ^{ completion(NO, @[ERROR_INCOMPLETE_ACTIONS]); });
            return;
        }
        uint32_t destinationKeyIndex = [identity firstIndexOfKeyOfType:self.currentMainKeyType createIfNotPresent:NO saveKey:NO];
        uint32_t sourceKeyIndex = [self firstIndexOfKeyOfType:self.currentMainKeyType createIfNotPresent:NO saveKey:NO];
        
        
        if (sourceKeyIndex == UINT32_MAX) { //not found
            //to do register a new key
            NSAssert(FALSE, @"we shouldn't be getting here");
            if (completion) dispatch_async(completionQueue, ^{ completion(NO, @[ERROR_KEY_HANDLING]); });
            return;
        }
        DSPotentialOneWayFriendship *potentialFriendship = [[DSPotentialOneWayFriendship alloc] initWithDestinationIdentity:identity
                                                                                                        destinationKeyIndex:destinationKeyIndex
                                                                                                             sourceIdentity:self
                                                                                                             sourceKeyIndex:sourceKeyIndex
                                                                                                                    account:[self.wallet accountWithNumber:0]];
        [potentialFriendship createDerivationPathAndSaveExtendedPublicKeyWithCompletion:^(BOOL success, DSIncomingFundsDerivationPath *_Nonnull incomingFundsDerivationPath) {
            if (!success) {
                if (completion) dispatch_async(completionQueue, ^{ completion(NO, @[ERROR_KEY_HANDLING]); });
                return;
            }
            BOOL encrypted = [potentialFriendship encryptExtendedPublicKey];
            if (encrypted) {
                [self sendNewFriendRequestMatchingPotentialFriendship:potentialFriendship
                                                            inContext:context
                                                           completion:completion
                                                    onCompletionQueue:completionQueue];
            } else if (completion) {
                dispatch_async(completionQueue, ^{ completion(NO, @[ERROR_KEY_HANDLING]); });
            }
        }];
    }
                                                  onCompletionQueue:self.identityQueue];
}

- (void)sendNewFriendRequestToPotentialContact:(DSPotentialContact *)potentialContact
                                    completion:(void (^)(BOOL success, NSArray<NSError *> *_Nullable errors))completion {
    NSAssert(self.isLocal, @"This should not be performed on a non local blockchain identity");
    if (!self.isLocal) return;
    DMaybeDocumentsMap *result = dash_spv_platform_document_manager_DocumentsManager_dpns_documents_for_username(self.chain.sharedRuntime, self.chain.sharedDocumentsObj, DChar(potentialContact.username));
    if (result->error) {
        NSError *error = [NSError ffi_from_platform_error:result->error];
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, @[error]); });
        DMaybeDocumentsMapDtor(result);
        return;
    }
    DDocument *document = result->ok->values[0];
    DSLog(@"documents for PotentialContact: ");
    dash_spv_platform_document_print_document(document);

    switch (document->tag) {
        case dpp_document_Document_V0: {
            DMaybeIdentity *identity_result = dash_spv_platform_identity_manager_IdentitiesManager_fetch_by_id(self.chain.sharedRuntime, self.chain.sharedIdentitiesObj, document->v0->owner_id);
            if (identity_result->error) {
                NSError *error = [NSError ffi_from_platform_error:identity_result->error];
                DMaybeIdentityDtor(identity_result);
                DMaybeDocumentsMapDtor(result);
                if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, @[error]); });
                return;
            }
            DIdentity *identity = identity_result->ok;
            if (!identity) {
                DMaybeIdentityDtor(identity_result);
                if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, @[ERROR_MALFORMED_RESPONSE]); });
                return;
            }
            switch (identity->tag) {
                case dpp_identity_identity_Identity_V0: {
                    u256 *identity_contact_unique_id = identity->v0->id->_0->_0;
                    UInt256 identityContactUniqueId = u256_cast(identity_contact_unique_id);
                    DSBlockchainIdentityEntity *potentialContactIdentityEntity = [DSBlockchainIdentityEntity anyObjectInContext:self.platformContext matching:@"uniqueID == %@", NSDataFromPtr(identity_contact_unique_id)];
                    DSIdentity *potentialContactIdentity = nil;
                    if (potentialContactIdentityEntity) {
                        potentialContactIdentity = [self.chain identityForUniqueId:identityContactUniqueId];
                        if (!potentialContactIdentity)
                            potentialContactIdentity = [[DSIdentity alloc] initWithIdentityEntity:potentialContactIdentityEntity];
                    } else {
                        potentialContactIdentity = [self.identitiesManager foreignIdentityWithUniqueId:identityContactUniqueId
                                                                                       createIfMissing:YES
                                                                                             inContext:self.platformContext];
                    }
                    [potentialContactIdentity applyIdentity:identity save:YES inContext:self.platformContext];
                    [self sendNewFriendRequestToIdentity:potentialContactIdentity
                                               inContext:self.platformContext
                                              completion:completion
                                       onCompletionQueue:dispatch_get_main_queue()];

                    break;
                }
                    
                default:
                    break;
            }
            break;
        }
        default:
            break;
    }
}

- (void)sendNewFriendRequestMatchingPotentialFriendship:(DSPotentialOneWayFriendship *)potentialFriendship
                                              inContext:(NSManagedObjectContext *)context
                                             completion:(void (^)(BOOL success, NSArray<NSError *> *errors))completion
                                      onCompletionQueue:(dispatch_queue_t)completionQueue {
    NSAssert(self.isLocal, @"This should not be performed on a non local blockchain identity");
    if (!self.isLocal) return;
    DSDashpayUserEntity *destinationDashpayUser = [potentialFriendship.destinationIdentity matchingDashpayUserInContext:context];
    if (!destinationDashpayUser) {
        NSAssert([potentialFriendship.destinationIdentity matchingDashpayUserInContext:context], @"There must be a destination contact if the destination identity is not known");
        return;
    }
    DPContract *contract = [DSDashPlatform sharedInstanceForChain:self.chain].dashPayContract;
    NSData *entropyData = uint256_random_data;
    u256 *identity_id = u256_ctor_u(potentialFriendship.sourceIdentity.uniqueID);
    u256 *entropy = u256_ctor(entropyData);
    DValue *value = [potentialFriendship toValue];
    uint32_t index = 0;
    if (!self.keysCreated) {
        [self createNewKeyOfType:DKeyKindECDSA()
                   securityLevel:DSecurityLevelMaster()
                         purpose:DPurposeAuth()
                         saveKey:!self.wallet.isTransient
                     returnIndex:&index];
    }
    DMaybeOpaqueKey *private_key = [self privateKeyAtIndex:self.currentMainKeyIndex ofType:self.currentMainKeyType];
    DMaybeStateTransitionProofResult *result = dash_spv_platform_PlatformSDK_send_friend_request_with_value(self.chain.sharedRuntime, self.chain.sharedPlatformObj, contract.raw_contract, identity_id, value, entropy, private_key->ok);
    if (result->error) {
        NSError *error = [NSError ffi_from_platform_error:result->error];
        DMaybeStateTransitionProofResultDtor(result);
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, @[error]); });
        return;
    }
    [context performBlockAndWait:^{
        [self addFriendship:potentialFriendship
                  inContext:context
                 completion:^(BOOL success, NSError *error) {}];
    }];
    [self fetchOutgoingContactRequestsInContext:context
                                     startAfter:nil
                                 withCompletion:^(BOOL success, NSArray<NSError *> *_Nonnull errors) {
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(success, errors); });
    }
                              onCompletionQueue:completionQueue];
}

- (void)acceptFriendRequestFromIdentity:(DSIdentity *)otherIdentity
                             completion:(void (^)(BOOL success, NSArray<NSError *> *errors))completion {
    [self acceptFriendRequestFromIdentity:otherIdentity
                                inContext:self.platformContext
                               completion:completion
                        onCompletionQueue:dispatch_get_main_queue()];
}

- (void)acceptFriendRequestFromIdentity:(DSIdentity *)otherIdentity
                              inContext:(NSManagedObjectContext *)context
                             completion:(void (^)(BOOL success, NSArray<NSError *> *errors))completion
                      onCompletionQueue:(dispatch_queue_t)completionQueue {
    NSAssert(self.isLocal, @"This should not be performed on a non local blockchain identity");
    if (!self.isLocal) {
        if (completion) completion(NO, @[ERROR_FRIEND_REQUEST_ACCEPT_FROM_NON_LOCAL_IDENTITY]);
        return;
    }
    
    [context performBlockAndWait:^{
        DSDashpayUserEntity *matchingDashpayUser = [self matchingDashpayUserInContext:context];
        DSFriendRequestEntity *friendRequest = [[matchingDashpayUser.incomingRequests filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"sourceContact.associatedBlockchainIdentity.uniqueID == %@", uint256_data(otherIdentity.uniqueID)]] anyObject];
        if (friendRequest) {
            [self acceptFriendRequest:friendRequest
                           completion:completion
                    onCompletionQueue:completionQueue];
        } else if (completion) {
            completion(NO, @[ERROR_FRIEND_REQUEST_NONE_FOUND]);
        }
    }];
}

- (void)acceptFriendRequest:(DSFriendRequestEntity *)friendRequest
                 completion:(void (^)(BOOL success, NSArray<NSError *> *errors))completion {
    [self acceptFriendRequest:friendRequest
                   completion:completion
            onCompletionQueue:dispatch_get_main_queue()];
}

- (void)acceptFriendRequest:(DSFriendRequestEntity *)friendRequest
                 completion:(void (^)(BOOL success, NSArray<NSError *> *errors))completion
          onCompletionQueue:(dispatch_queue_t)completionQueue {
    NSAssert(self.isLocal, @"This should not be performed on a non local blockchain identity");
    if (!self.isLocal) {
        if (completion) completion(NO, @[ERROR_FRIEND_REQUEST_ACCEPT_FROM_NON_LOCAL_IDENTITY]);
        return;
    }
    DSAccount *account = [self.wallet accountWithNumber:0];
    DSDashpayUserEntity *otherDashpayUser = friendRequest.sourceContact;
    DSIdentity *otherIdentity = [self.chain identityForUniqueId:otherDashpayUser.associatedBlockchainIdentity.uniqueID.UInt256];
    if (!otherIdentity)
        otherIdentity = [[DSIdentity alloc] initWithIdentityEntity:otherDashpayUser.associatedBlockchainIdentity];
    //    DSPotentialContact *contact = [[DSPotentialContact alloc] initWithUsername:friendRequest.sourceContact.username avatarPath:friendRequest.sourceContact.avatarPath
    //                                                                 publicMessage:friendRequest.sourceContact.publicMessage];
    //    [contact setAssociatedIdentityUniqueId:friendRequest.sourceContact.associatedBlockchainIdentity.uniqueID.UInt256];
    //    DSKey * friendsEncyptionKey = [otherIdentity keyOfType:friendRequest.sourceEncryptionPublicKeyIndex atIndex:friendRequest.sourceEncryptionPublicKeyIndex];
    //[DSKey keyWithPublicKeyData:friendRequest.sourceContact.encryptionPublicKey forKeyType:friendRequest.sourceContact.encryptionPublicKeyType onChain:self.chain];
    //    [contact addPublicKey:friendsEncyptionKey atIndex:friendRequest.sourceContact.encryptionPublicKeyIndex];
    //    uint32_t sourceKeyIndex = [self firstIndexOfKeyOfType:friendRequest.sourceContact.encryptionPublicKeyType createIfNotPresent:NO];
    //    if (sourceKeyIndex == UINT32_MAX) { //not found
    //        //to do register a new key
    //        NSAssert(FALSE, @"we shouldn't be getting here");
    //        return;
    //    }
    DSPotentialOneWayFriendship *potentialFriendship = [[DSPotentialOneWayFriendship alloc] initWithDestinationIdentity:otherIdentity destinationKeyIndex:friendRequest.sourceKeyIndex sourceIdentity:self sourceKeyIndex:friendRequest.destinationKeyIndex account:account];
    [potentialFriendship createDerivationPathAndSaveExtendedPublicKeyWithCompletion:^(BOOL success, DSIncomingFundsDerivationPath *_Nonnull incomingFundsDerivationPath) {
        if (success) {
            BOOL encrypted = [potentialFriendship encryptExtendedPublicKey];
            if (!encrypted) {
                if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, @[ERROR_KEY_HANDLING]); });
                return;
            }
            [self sendNewFriendRequestMatchingPotentialFriendship:potentialFriendship
                                                        inContext:friendRequest.managedObjectContext
                                                       completion:completion
                                                onCompletionQueue:completionQueue];
        } else if (completion) {
            completion(NO, @[ERROR_DERIVATION_FRIENDSHIP]);
        }
    }];
}

- (void)addFriendship:(DSPotentialOneWayFriendship *)friendship
            inContext:(NSManagedObjectContext *)context
           completion:(void (^)(BOOL success, NSError *error))completion {
    //DSFriendRequestEntity * friendRequestEntity = [friendship outgoingFriendRequestForDashpayUserEntity:friendship.destinationIdentity.matchingDashpayUser];
    DSFriendRequestEntity *friendRequestEntity = [DSFriendRequestEntity managedObjectInBlockedContext:context];
    friendRequestEntity.sourceContact = [friendship.sourceIdentity matchingDashpayUserInContext:context];
    friendRequestEntity.destinationContact = [friendship.destinationIdentity matchingDashpayUserInContext:context];
    friendRequestEntity.timestamp = friendship.createdAt;
    NSAssert(friendRequestEntity.sourceContact != friendRequestEntity.destinationContact, @"This must be different contacts");
    DSAccountEntity *accountEntity = [DSAccountEntity accountEntityForWalletUniqueID:self.wallet.uniqueIDString index:0 onChain:self.chain inContext:context];
    friendRequestEntity.account = accountEntity;
    [friendRequestEntity finalizeWithFriendshipIdentifier];
    [friendship createDerivationPathAndSaveExtendedPublicKeyWithCompletion:^(BOOL success, DSIncomingFundsDerivationPath *_Nonnull incomingFundsDerivationPath) {
        if (!success) return;
        friendRequestEntity.derivationPath = [friendship storeExtendedPublicKeyAssociatedWithFriendRequest:friendRequestEntity inContext:context];
        DSAccount *account = [self.wallet accountWithNumber:0];
        if (friendship.destinationIdentity.isLocal) { //the destination is also local
            NSAssert(friendship.destinationIdentity.wallet, @"Wallet should be known");
            DSAccount *recipientAccount = [friendship.destinationIdentity.wallet accountWithNumber:0];
            NSAssert(recipientAccount, @"Recipient Wallet should exist");
            [recipientAccount addIncomingDerivationPath:incomingFundsDerivationPath forFriendshipIdentifier:friendRequestEntity.friendshipIdentifier inContext:context];
            if (recipientAccount != account)
                [account addOutgoingDerivationPath:incomingFundsDerivationPath forFriendshipIdentifier:friendRequestEntity.friendshipIdentifier inContext:context];
        } else {
            //todo update outgoing derivation paths to incoming derivation paths as blockchain users come in
            [account addIncomingDerivationPath:incomingFundsDerivationPath forFriendshipIdentifier:friendRequestEntity.friendshipIdentifier inContext:context];
        }
        NSAssert(friendRequestEntity.derivationPath, @"derivation path must be present");
        DSDashpayUserEntity *dashpayUserInChildContext = [self matchingDashpayUserInContext:context];
        [dashpayUserInChildContext addOutgoingRequestsObject:friendRequestEntity];
        if ([[[friendship.destinationIdentity matchingDashpayUserInContext:context].outgoingRequests filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"destinationContact == %@", dashpayUserInChildContext]] count])
            [dashpayUserInChildContext addFriendsObject:[friendship.destinationIdentity matchingDashpayUserInContext:context]];
        NSError *savingError = [context ds_save];
        [self.chain.chainManager.transactionManager updateTransactionsBloomFilter];
        if (completion) completion(savingError ? NO : YES, savingError);
    }];
}

- (void)addFriendshipFromSourceIdentity:(DSIdentity *)sourceIdentity
                         sourceKeyIndex:(uint32_t)sourceKeyIndex
                    toRecipientIdentity:(DSIdentity *)recipientIdentity
                      recipientKeyIndex:(uint32_t)recipientKeyIndex
                            atTimestamp:(NSTimeInterval)timestamp
                              inContext:(NSManagedObjectContext *)context {
    [context performBlockAndWait:^{
        DSAccount *account = [self.wallet accountWithNumber:0];
        DSPotentialOneWayFriendship *realFriendship = [[DSPotentialOneWayFriendship alloc] initWithDestinationIdentity:recipientIdentity destinationKeyIndex:recipientKeyIndex sourceIdentity:self sourceKeyIndex:sourceKeyIndex account:account createdAt:timestamp];
        if (![DSFriendRequestEntity existingFriendRequestEntityWithSourceIdentifier:self.uniqueID destinationIdentifier:recipientIdentity.uniqueID onAccountIndex:account.accountNumber inContext:context]) {
            //it was probably added already
            //this could happen when have 2 blockchain identities in same wallet
            //Identity A gets outgoing contacts
            //Which are the same as Identity B incoming contacts, no need to add the friendships twice
            [self addFriendship:realFriendship inContext:context completion:nil];
        }
    }];
}

- (DSIdentityFriendshipStatus)friendshipStatusForRelationshipWithIdentity:(DSIdentity *)otherIdentity {
    if (!self.matchingDashpayUserInViewContext) return DSIdentityFriendshipStatus_Unknown;
    __block BOOL isIncoming;
    __block BOOL isOutgoing;
    [self.matchingDashpayUserInViewContext.managedObjectContext performBlockAndWait:^{
        isIncoming = ([self.matchingDashpayUserInViewContext.incomingRequests filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"sourceContact.associatedBlockchainIdentity.uniqueID == %@", uint256_data(otherIdentity.uniqueID)]].count > 0);
        isOutgoing = ([self.matchingDashpayUserInViewContext.outgoingRequests filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"destinationContact.associatedBlockchainIdentity.uniqueID == %@", uint256_data(otherIdentity.uniqueID)]].count > 0);
    }];
    return ((isIncoming << 1) | isOutgoing);
}


@end
