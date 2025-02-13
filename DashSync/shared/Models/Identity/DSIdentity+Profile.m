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

#import "DSDashpayUserEntity+CoreDataClass.h"
#import "DPContract.h"
#import "DSIdentity+Profile.h"
#import "DSIdentity+Protected.h"
#import "DSIdentity+Username.h"
#import "DSTransientDashpayUser.h"
#import "DSWallet.h"
#import "NSError+Dash.h"
#import "NSError+Platform.h"
#import "NSManagedObject+Sugar.h"
#import <CocoaImageHashing/CocoaImageHashing.h>

#define ERROR_TRANSITION_NO_UPDATE [NSError errorWithCode:500 localizedDescriptionKey:@"Transition had nothing to update"]
#define ERROR_DASHPAY_CONTRACT_NOT_REGISTERED [NSError errorWithCode:500 localizedDescriptionKey:@"Dashpay Contract is not yet registered on network"]
#define ERROR_IDENTITY_NO_LONGER_ACTIVE [NSError errorWithCode:410 localizedDescriptionKey:@"Identity no longer active in wallet"]
#define ERROR_CONTRACT_SETUP [NSError errorWithCode:500 localizedDescriptionKey:@"The Dashpay contract is not properly set up"]

@implementation DSIdentity (Profile)

- (NSString *)avatarPath {
    if (self.transientDashpayUser) {
        return self.transientDashpayUser.avatarPath;
    } else {
        return self.matchingDashpayUserInViewContext.avatarPath;
    }
}

- (NSData *)avatarFingerprint {
    if (self.transientDashpayUser) {
        return self.transientDashpayUser.avatarFingerprint;
    } else {
        return self.matchingDashpayUserInViewContext.avatarFingerprint;
    }
}

- (NSData *)avatarHash {
    if (self.transientDashpayUser) {
        return self.transientDashpayUser.avatarHash;
    } else {
        return self.matchingDashpayUserInViewContext.avatarHash;
    }
}

- (NSString *)displayName {
    if (self.transientDashpayUser) {
        return self.transientDashpayUser.displayName;
    } else {
        return self.matchingDashpayUserInViewContext.displayName;
    }
}

- (NSString *)publicMessage {
    if (self.transientDashpayUser) {
        return self.transientDashpayUser.publicMessage;
    } else {
        return self.matchingDashpayUserInViewContext.publicMessage;
    }
}

- (uint64_t)dashpayProfileUpdatedAt {
    if (self.transientDashpayUser) {
        return self.transientDashpayUser.updatedAt;
    } else {
        return self.matchingDashpayUserInViewContext.updatedAt;
    }
}

- (uint64_t)dashpayProfileCreatedAt {
    if (self.transientDashpayUser) {
        return self.transientDashpayUser.createdAt;
    } else {
        return self.matchingDashpayUserInViewContext.createdAt;
    }
}

// MARK: Profile

- (void)updateDashpayProfileWithDisplayName:(NSString *)displayName {
    [self updateDashpayProfileWithDisplayName:displayName
                                    inContext:self.platformContext];
}

- (void)updateDashpayProfileWithDisplayName:(NSString *)displayName
                                  inContext:(NSManagedObjectContext *)context {
    [context performBlockAndWait:^{
        DSDashpayUserEntity *matchingDashpayUser = [self matchingDashpayUserInContext:context];
        matchingDashpayUser.displayName = displayName;
        if (!matchingDashpayUser.remoteProfileDocumentRevision) {
            matchingDashpayUser.createdAt = [[NSDate date] timeIntervalSince1970] * 1000;
            if (!matchingDashpayUser.originalEntropyData)
                matchingDashpayUser.originalEntropyData = uint256_random_data;
        }
        matchingDashpayUser.updatedAt = [[NSDate date] timeIntervalSince1970] * 1000;
        matchingDashpayUser.localProfileDocumentRevision++;
        [context ds_save];
    }];
}

- (void)updateDashpayProfileWithPublicMessage:(NSString *)publicMessage {
    [self updateDashpayProfileWithPublicMessage:publicMessage
                                      inContext:self.platformContext];
}

- (void)updateDashpayProfileWithPublicMessage:(NSString *)publicMessage
                                    inContext:(NSManagedObjectContext *)context {
    [context performBlockAndWait:^{
        DSDashpayUserEntity *matchingDashpayUser = [self matchingDashpayUserInContext:context];
        matchingDashpayUser.publicMessage = publicMessage;
        if (!matchingDashpayUser.remoteProfileDocumentRevision) {
            matchingDashpayUser.createdAt = [[NSDate date] timeIntervalSince1970] * 1000;
            if (!matchingDashpayUser.originalEntropyData)
                matchingDashpayUser.originalEntropyData = uint256_random_data;
        }
        matchingDashpayUser.updatedAt = [[NSDate date] timeIntervalSince1970] * 1000;
        matchingDashpayUser.localProfileDocumentRevision++;
        [context ds_save];
    }];
}

- (void)updateDashpayProfileWithAvatarURLString:(NSString *)avatarURLString {
    [self updateDashpayProfileWithAvatarURLString:avatarURLString
                                        inContext:self.platformContext];
}

- (void)updateDashpayProfileWithAvatarURLString:(NSString *)avatarURLString
                                      inContext:(NSManagedObjectContext *)context {
    [context performBlockAndWait:^{
        DSDashpayUserEntity *matchingDashpayUser = [self matchingDashpayUserInContext:context];
        matchingDashpayUser.avatarPath = avatarURLString;
        if (!matchingDashpayUser.remoteProfileDocumentRevision) {
            matchingDashpayUser.createdAt = [[NSDate date] timeIntervalSince1970] * 1000;
            if (!matchingDashpayUser.originalEntropyData)
                matchingDashpayUser.originalEntropyData = uint256_random_data;
        }
        matchingDashpayUser.updatedAt = [[NSDate date] timeIntervalSince1970] * 1000;
        matchingDashpayUser.localProfileDocumentRevision++;
        [context ds_save];
    }];
}


- (void)updateDashpayProfileWithDisplayName:(NSString *)displayName
                              publicMessage:(NSString *)publicMessage {
    [self updateDashpayProfileWithDisplayName:displayName
                                publicMessage:publicMessage
                                    inContext:self.platformContext];
}

- (void)updateDashpayProfileWithDisplayName:(NSString *)displayName
                              publicMessage:(NSString *)publicMessage
                                  inContext:(NSManagedObjectContext *)context {
    [context performBlockAndWait:^{
        DSDashpayUserEntity *matchingDashpayUser = [self matchingDashpayUserInContext:context];
        matchingDashpayUser.displayName = displayName;
        matchingDashpayUser.publicMessage = publicMessage;
        if (!matchingDashpayUser.remoteProfileDocumentRevision) {
            matchingDashpayUser.createdAt = [[NSDate date] timeIntervalSince1970] * 1000;
            if (!matchingDashpayUser.originalEntropyData)
                matchingDashpayUser.originalEntropyData = uint256_random_data;
        }
        matchingDashpayUser.updatedAt = [[NSDate date] timeIntervalSince1970] * 1000;
        matchingDashpayUser.localProfileDocumentRevision++;
        [context ds_save];
    }];
}

- (void)updateDashpayProfileWithDisplayName:(NSString *)displayName
                              publicMessage:(NSString *)publicMessage
                            avatarURLString:(NSString *)avatarURLString {
    [self updateDashpayProfileWithDisplayName:displayName
                                publicMessage:publicMessage
                              avatarURLString:avatarURLString
                                    inContext:self.platformContext];
}

- (void)updateDashpayProfileWithDisplayName:(NSString *)displayName
                              publicMessage:(NSString *)publicMessage
                            avatarURLString:(NSString *)avatarURLString
                                  inContext:(NSManagedObjectContext *)context {
    [context performBlockAndWait:^{
        DSDashpayUserEntity *matchingDashpayUser = [self matchingDashpayUserInContext:context];
        matchingDashpayUser.displayName = displayName;
        matchingDashpayUser.publicMessage = publicMessage;
        matchingDashpayUser.avatarPath = avatarURLString;
        if (!matchingDashpayUser.remoteProfileDocumentRevision) {
            matchingDashpayUser.createdAt = [[NSDate date] timeIntervalSince1970] * 1000;
            if (!matchingDashpayUser.originalEntropyData)
                matchingDashpayUser.originalEntropyData = uint256_random_data;
        }
        matchingDashpayUser.updatedAt = [[NSDate date] timeIntervalSince1970] * 1000;
        matchingDashpayUser.localProfileDocumentRevision++;
        [context ds_save];
    }];
}

#if TARGET_OS_IOS

- (void)updateDashpayProfileWithDisplayName:(NSString *)displayName
                              publicMessage:(NSString *)publicMessage
                                avatarImage:(UIImage *)avatarImage
                                 avatarData:(NSData *)data
                            avatarURLString:(NSString *)avatarURLString {
    [self updateDashpayProfileWithDisplayName:displayName
                                publicMessage:publicMessage
                                  avatarImage:avatarImage
                                   avatarData:data
                              avatarURLString:avatarURLString
                                    inContext:self.platformContext];
}

- (void)updateDashpayProfileWithDisplayName:(NSString *)displayName
                              publicMessage:(NSString *)publicMessage
                                avatarImage:(UIImage *)avatarImage
                                 avatarData:(NSData *)avatarData
                            avatarURLString:(NSString *)avatarURLString
                                  inContext:(NSManagedObjectContext *)context {
    NSData *avatarHash = uint256_data(avatarData.SHA256);
    uint64_t fingerprint = [[OSImageHashing sharedInstance] hashImage:avatarImage withProviderId:OSImageHashingProviderDHash];
    [self updateDashpayProfileWithDisplayName:displayName
                                publicMessage:publicMessage
                              avatarURLString:avatarURLString
                                   avatarHash:avatarHash
                            avatarFingerprint:[NSData dataWithUInt64:fingerprint]
                                    inContext:context];
}

- (void)updateDashpayProfileWithAvatarImage:(UIImage *)avatarImage
                                 avatarData:(NSData *)data
                            avatarURLString:(NSString *)avatarURLString {
    [self updateDashpayProfileWithAvatarImage:avatarImage
                                   avatarData:data
                              avatarURLString:avatarURLString
                                    inContext:self.platformContext];
}

- (void)updateDashpayProfileWithAvatarImage:(UIImage *)avatarImage
                                 avatarData:(NSData *)avatarData
                            avatarURLString:(NSString *)avatarURLString
                                  inContext:(NSManagedObjectContext *)context {
    NSData *avatarHash = uint256_data(avatarData.SHA256);
    uint64_t fingerprint = [[OSImageHashing sharedInstance] hashImage:avatarImage withProviderId:OSImageHashingProviderDHash];
    [self updateDashpayProfileWithAvatarURLString:avatarURLString
                                       avatarHash:avatarHash
                                avatarFingerprint:[NSData dataWithUInt64:fingerprint]
                                        inContext:context];
}

#else

- (void)updateDashpayProfileWithDisplayName:(NSString *)displayName
                              publicMessage:(NSString *)publicMessage
                                avatarImage:(NSImage *)avatarImage
                                 avatarData:(NSData *)data
                            avatarURLString:(NSString *)avatarURLString {
    [self updateDashpayProfileWithDisplayName:displayName
                                publicMessage:publicMessage
                                  avatarImage:avatarImage
                                   avatarData:data
                              avatarURLString:avatarURLString
                                    inContext:self.platformContext];
}

- (void)updateDashpayProfileWithDisplayName:(NSString *)displayName
                              publicMessage:(NSString *)publicMessage
                                avatarImage:(NSImage *)avatarImage
                                 avatarData:(NSData *)avatarData
                            avatarURLString:(NSString *)avatarURLString
                                  inContext:(NSManagedObjectContext *)context {
    NSData *avatarHash = uint256_data(avatarData.SHA256);
    uint64_t fingerprint = [[OSImageHashing sharedInstance] hashImage:avatarImage withProviderId:OSImageHashingProviderDHash];
    [self updateDashpayProfileWithDisplayName:displayName
                                publicMessage:publicMessage
                              avatarURLString:avatarURLString
                                   avatarHash:avatarHash
                            avatarFingerprint:[NSData dataWithUInt64:fingerprint]
                                    inContext:context];
}

- (void)updateDashpayProfileWithAvatarImage:(NSImage *)avatarImage
                                 avatarData:(NSData *)data
                            avatarURLString:(NSString *)avatarURLString {
    [self updateDashpayProfileWithAvatarImage:avatarImage
                                   avatarData:data
                              avatarURLString:avatarURLString
                                    inContext:self.platformContext];
}

- (void)updateDashpayProfileWithAvatarImage:(NSImage *)avatarImage
                                 avatarData:(NSData *)avatarData
                            avatarURLString:(NSString *)avatarURLString
                                  inContext:(NSManagedObjectContext *)context {
    NSData *avatarHash = uint256_data(avatarData.SHA256);
    uint64_t fingerprint = [[OSImageHashing sharedInstance] hashImage:avatarImage withProviderId:OSImageHashingProviderDHash];
    [self updateDashpayProfileWithAvatarURLString:avatarURLString
                                       avatarHash:avatarHash
                                avatarFingerprint:[NSData dataWithUInt64:fingerprint]
                                        inContext:context];
}

#endif


- (void)updateDashpayProfileWithDisplayName:(NSString *)displayName
                              publicMessage:(NSString *)publicMessage
                            avatarURLString:(NSString *)avatarURLString
                                 avatarHash:(NSData *)avatarHash
                          avatarFingerprint:(NSData *)avatarFingerprint {
    [self updateDashpayProfileWithDisplayName:displayName
                                publicMessage:publicMessage
                              avatarURLString:avatarURLString
                                   avatarHash:avatarHash
                            avatarFingerprint:avatarFingerprint
                                    inContext:self.platformContext];
}

- (void)updateDashpayProfileWithDisplayName:(NSString *)displayName
                              publicMessage:(NSString *)publicMessage
                            avatarURLString:(NSString *)avatarURLString
                                 avatarHash:(NSData *)avatarHash
                          avatarFingerprint:(NSData *)avatarFingerprint
                                  inContext:(NSManagedObjectContext *)context {
    [context performBlockAndWait:^{
        DSDashpayUserEntity *matchingDashpayUser = [self matchingDashpayUserInContext:context];
        matchingDashpayUser.displayName = displayName;
        matchingDashpayUser.publicMessage = publicMessage;
        matchingDashpayUser.avatarPath = avatarURLString;
        matchingDashpayUser.avatarFingerprint = avatarFingerprint;
        matchingDashpayUser.avatarHash = avatarHash;
        if (!matchingDashpayUser.remoteProfileDocumentRevision) {
            matchingDashpayUser.createdAt = [[NSDate date] timeIntervalSince1970] * 1000;
            if (!matchingDashpayUser.originalEntropyData)
                matchingDashpayUser.originalEntropyData = uint256_random_data;
        }
        matchingDashpayUser.updatedAt = [[NSDate date] timeIntervalSince1970] * 1000;
        matchingDashpayUser.localProfileDocumentRevision++;
        [context ds_save];
    }];
}

- (void)updateDashpayProfileWithAvatarURLString:(NSString *)avatarURLString
                                     avatarHash:(NSData *)avatarHash
                              avatarFingerprint:(NSData *)avatarFingerprint {
    [self updateDashpayProfileWithAvatarURLString:avatarURLString
                                       avatarHash:avatarHash
                                avatarFingerprint:avatarFingerprint
                                        inContext:self.platformContext];
}

- (void)updateDashpayProfileWithAvatarURLString:(NSString *)avatarURLString
                                     avatarHash:(NSData *)avatarHash
                              avatarFingerprint:(NSData *)avatarFingerprint
                                      inContext:(NSManagedObjectContext *)context {
    [context performBlockAndWait:^{
        DSDashpayUserEntity *matchingDashpayUser = [self matchingDashpayUserInContext:context];
        matchingDashpayUser.avatarPath = avatarURLString;
        matchingDashpayUser.avatarFingerprint = avatarFingerprint;
        matchingDashpayUser.avatarHash = avatarHash;
        if (!matchingDashpayUser.remoteProfileDocumentRevision) {
            matchingDashpayUser.createdAt = [[NSDate date] timeIntervalSince1970] * 1000;
            if (!matchingDashpayUser.originalEntropyData)
                matchingDashpayUser.originalEntropyData = uint256_random_data;
        }
        matchingDashpayUser.updatedAt = [[NSDate date] timeIntervalSince1970] * 1000;
        matchingDashpayUser.localProfileDocumentRevision++;
        [context ds_save];
    }];
}

- (void)signAndPublishProfileWithCompletion:(void (^)(BOOL success, BOOL cancelled, NSError *error))completion {
    NSMutableString *debugInfo = [NSMutableString stringWithFormat:@"%@: Sign and publish profile", self.logPrefix];
    DSLog(@"%@", debugInfo);
    NSManagedObjectContext *context = self.platformContext;
    __block uint32_t profileDocumentRevision;
    [context performBlockAndWait:^{
        DSDashpayUserEntity *matchingDashpayUser = [self matchingDashpayUserInContext:context];
        if (matchingDashpayUser.localProfileDocumentRevision > matchingDashpayUser.remoteProfileDocumentRevision)
            matchingDashpayUser.localProfileDocumentRevision = matchingDashpayUser.remoteProfileDocumentRevision + 1;
        profileDocumentRevision = matchingDashpayUser.localProfileDocumentRevision;
        [context ds_save];
    }];
    DSDashpayUserEntity *matchingDashpayUser = [self matchingDashpayUserInContext:context];
    __block dash_spv_platform_models_profile_Profile *profile = nil;
    __block NSData *entropyData = nil, *documentIdentifier = nil;
    if (matchingDashpayUser && matchingDashpayUser.localProfileDocumentRevision) {
        __block Vec_u8 *avatarFingerprint = nil, *avatarHash = nil;
        __block uint64_t updatedAt, createdAt, revision;
        __block char *publicMessage = nil, *avatarUrl = nil, *displayName = nil;
        [context performBlockAndWait:^{
            updatedAt = matchingDashpayUser.updatedAt;
            createdAt = matchingDashpayUser.createdAt;
            revision = matchingDashpayUser.localProfileDocumentRevision;
            if (matchingDashpayUser.publicMessage)
                publicMessage = (char *)[matchingDashpayUser.publicMessage UTF8String];
            if (matchingDashpayUser.avatarPath)
                avatarUrl = (char *)[matchingDashpayUser.avatarPath UTF8String];
            if (matchingDashpayUser.avatarFingerprint)
                avatarFingerprint = bytes_ctor(matchingDashpayUser.avatarFingerprint);
            if (matchingDashpayUser.avatarHash)
                avatarHash = bytes_ctor(matchingDashpayUser.avatarHash);
            if (matchingDashpayUser.displayName)
                publicMessage = (char *)[matchingDashpayUser.displayName UTF8String];
            entropyData = matchingDashpayUser.originalEntropyData;
            documentIdentifier = matchingDashpayUser.documentIdentifier;
        }];
        profile = dash_spv_platform_models_profile_Profile_ctor(updatedAt, createdAt, revision, (char *)[matchingDashpayUser.publicMessage UTF8String], (char *)[matchingDashpayUser.avatarPath UTF8String], avatarFingerprint, avatarHash, displayName);
    } else {
        DSLog(@"%@: ERROR: No user or revision %@", debugInfo, matchingDashpayUser);
        if (completion) completion(nil, NO, ERROR_TRANSITION_NO_UPDATE);
        return;
    }

    if (!self.keysCreated) {
        uint32_t index;
        [self createNewKeyOfType:dash_spv_crypto_keys_key_KeyKind_ECDSA_ctor() saveKey:!self.wallet.isTransient returnIndex:&index];
    }
    DMaybeOpaqueKey *private_key = [self privateKeyAtIndex:self.currentMainKeyIndex ofType:self.currentMainKeyType];
    DPContract *contract = [DSDashPlatform sharedInstanceForChain:self.chain].dashPayContract;
    DMaybeStateTransitionProofResult *result = dash_spv_platform_PlatformSDK_sign_and_publish_profile(self.chain.sharedRuntime, self.chain.shareCore.platform->obj, contract.raw_contract, u256_ctor_u(self.uniqueID), profile, u256_ctor(entropyData), u256_ctor(documentIdentifier), private_key->ok);
    if (result->error) {
        NSError *error = [NSError ffi_from_platform_error:result->error];
        DSLog(@"%@: ERROR: %@", debugInfo, error);
        DMaybeStateTransitionProofResultDtor(result);
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, NO, error); });
        return;
    }
    DMaybeStateTransitionProofResultDtor(result);

    [context performBlockAndWait:^{
        [self matchingDashpayUserInContext:context].remoteProfileDocumentRevision = profileDocumentRevision;
        [context ds_save];
    }];
    DSLog(@"%@: OK", debugInfo);
    if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(YES, NO, nil); });

}

// MARK: Fetching

- (void)fetchProfileWithCompletion:(void (^)(BOOL success, NSError *error))completion {
    dispatch_async(self.identityQueue, ^{
        [self fetchProfileInContext:self.platformContext
                     withCompletion:completion
                  onCompletionQueue:dispatch_get_main_queue()];
    });
}

- (void)fetchProfileInContext:(NSManagedObjectContext *)context
               withCompletion:(void (^)(BOOL success, NSError *error))completion
            onCompletionQueue:(dispatch_queue_t)completionQueue {
    DPContract *dashpayContract = [DSDashPlatform sharedInstanceForChain:self.chain].dashPayContract;
    if ([dashpayContract contractState] != DPContractState_Registered) {
        if (completion) dispatch_async(completionQueue, ^{ completion(NO, ERROR_DASHPAY_CONTRACT_NOT_REGISTERED); });
        return;
    }
    [self.identitiesManager fetchProfileForIdentity:self
                                     withCompletion:^(BOOL success, DSTransientDashpayUser *_Nullable dashpayUserInfo, NSError *_Nullable error) {
        if (!success || error || dashpayUserInfo == nil) {
            if (completion) dispatch_async(completionQueue, ^{ completion(success, error); });
            return;
        }
        [self applyProfileChanges:dashpayUserInfo
                        inContext:context
                      saveContext:YES
                       completion:^(BOOL success, NSError *_Nullable error) {
            if (!success) {
                [self fetchUsernamesInContext:context
                               withCompletion:completion
                            onCompletionQueue:completionQueue];

            } else if (completion) {
                dispatch_async(completionQueue, ^{ completion(success, error); });
            }
            
            
        }
                onCompletionQueue:self.identityQueue];
    }
                                            onCompletionQueue:self.identityQueue];
}


- (void)applyProfileChanges:(DSTransientDashpayUser *)transientDashpayUser
                  inContext:(NSManagedObjectContext *)context
                saveContext:(BOOL)saveContext
                 completion:(void (^)(BOOL success, NSError *error))completion
          onCompletionQueue:(dispatch_queue_t)completionQueue {
    if (![self isActive]) {
        if (completion) dispatch_async(completionQueue, ^{ completion(NO, ERROR_IDENTITY_NO_LONGER_ACTIVE); });
        return;
    }
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.identityQueue, ^{
        [context performBlockAndWait:^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                if (completion) completion(NO, ERROR_MEM_ALLOC);
                return;
            }
            if (![self isActive]) {
                if (completion) dispatch_async(completionQueue, ^{ completion(NO, ERROR_IDENTITY_NO_LONGER_ACTIVE); });
                return;
            }
            DSDashpayUserEntity *contact = [[self identityEntityInContext:context] matchingDashpayUser];
            NSAssert(contact, @"It is weird to get here");
            if (!contact)
                contact = [DSDashpayUserEntity anyObjectInContext:context matching:@"associatedBlockchainIdentity.uniqueID == %@", self.uniqueIDData];
            if (!contact || transientDashpayUser.updatedAt > contact.updatedAt) {
                if (!contact) {
                    contact = [DSDashpayUserEntity managedObjectInBlockedContext:context];
                    contact.chain = [strongSelf.wallet.chain chainEntityInContext:context];
                    contact.associatedBlockchainIdentity = [strongSelf identityEntityInContext:context];
                }
                NSError *error = [contact applyTransientDashpayUser:transientDashpayUser save:saveContext];
                if (error) {
                    if (completion) dispatch_async(completionQueue, ^{ completion(NO, error); });
                    return;
                }
            }
            [self saveProfileTimestamp];
            if (completion) dispatch_async(completionQueue, ^{ completion(YES, nil); });
        }];
    });
}
@end
