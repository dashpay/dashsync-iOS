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

#import <Foundation/Foundation.h>
#import "DSIdentity.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSIdentity (Profile)

// MARK: - Dashpay

/*! @brief This is a helper to easily get the avatar path of the matching dashpay user. */
@property (nonatomic, readonly, nullable) NSString *avatarPath;

/*! @brief This is a helper to easily get the avatar fingerprint of the matching dashpay user. */
@property (nonatomic, readonly) NSData *avatarFingerprint;

/*! @brief This is a helper to easily get the avatar hash of the matching dashpay user. */
@property (nonatomic, readonly, nullable) NSData *avatarHash;

/*! @brief This is a helper to easily get the display name of the matching dashpay user. */
@property (nonatomic, readonly, nullable) NSString *displayName;

/*! @brief This is a helper to easily get the public message of the matching dashpay user. */
@property (nonatomic, readonly, nullable) NSString *publicMessage;

/*! @brief This is a helper to easily get the last time the profile was updated of the matching dashpay user. */
@property (nonatomic, readonly) uint64_t dashpayProfileUpdatedAt;

/*! @brief This is a helper to easily get the creation time of the profile of the matching dashpay user. */
@property (nonatomic, readonly) uint64_t dashpayProfileCreatedAt;

- (void)fetchProfileWithCompletion:(void (^_Nullable)(BOOL success, NSError *error))completion;
- (void)updateDashpayProfileWithDisplayName:(NSString *)displayName;
- (void)updateDashpayProfileWithPublicMessage:(NSString *)publicMessage;

- (void)updateDashpayProfileWithAvatarURLString:(NSString *)avatarURLString;
- (void)updateDashpayProfileWithAvatarURLString:(NSString *)avatarURLString
                                     avatarHash:(NSData *)avatarHash
                              avatarFingerprint:(NSData *)avatarFingerprint;
- (void)updateDashpayProfileWithDisplayName:(NSString *)displayName
                              publicMessage:(NSString *)publicMessage;
#if TARGET_OS_IOS
- (void)updateDashpayProfileWithAvatarImage:(UIImage *)avatarImage
                                 avatarData:(NSData *)data
                            avatarURLString:(NSString *)avatarURLString;
- (void)updateDashpayProfileWithDisplayName:(NSString *)displayName
                              publicMessage:(NSString *)publicMessage
                                avatarImage:(UIImage *)avatarImage
                                 avatarData:(NSData *)data
                            avatarURLString:(NSString *)avatarURLString;
#else
- (void)updateDashpayProfileWithAvatarImage:(NSImage *)avatarImage
                                 avatarData:(NSData *)data
                            avatarURLString:(NSString *)avatarURLString;
- (void)updateDashpayProfileWithDisplayName:(NSString *)displayName
                              publicMessage:(NSString *)publicMessage
                                avatarImage:(NSImage *)avatarImage
                                 avatarData:(NSData *)data
                            avatarURLString:(NSString *)avatarURLString;
#endif
- (void)updateDashpayProfileWithDisplayName:(NSString *)displayName
                              publicMessage:(NSString *)publicMessage
                            avatarURLString:(NSString *)avatarURLString;
- (void)updateDashpayProfileWithDisplayName:(NSString *)displayName
                              publicMessage:(NSString *)publicMessage
                            avatarURLString:(NSString *)avatarURLString
                                 avatarHash:(NSData *)avatarHash
                          avatarFingerprint:(NSData *)avatarFingerprint;
//- (void)signedProfileDocumentTransitionInContext:(NSManagedObjectContext *)context
//                                  withCompletion:(void (^)(DSTransition *transition, BOOL cancelled, NSError *error))completion;
- (void)signAndPublishProfileWithCompletion:(void (^)(BOOL success, BOOL cancelled, NSError *error))completion;


- (void)fetchProfileInContext:(NSManagedObjectContext *)context
               withCompletion:(void (^)(BOOL success, NSError *error))completion
            onCompletionQueue:(dispatch_queue_t)completionQueue;

- (void)applyProfileChanges:(DSTransientDashpayUser *)transientDashpayUser
                  inContext:(NSManagedObjectContext *)context
                saveContext:(BOOL)saveContext
                 completion:(void (^_Nullable)(BOOL success, NSError *_Nullable error))completion
          onCompletionQueue:(dispatch_queue_t)completionQueue;

@end

NS_ASSUME_NONNULL_END
