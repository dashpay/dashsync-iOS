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

#import "DSChain.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class DSChain, DSIdentity, DSAssetLockTransaction, DSTransientDashpayUser;

@protocol DSDAPINetworkServiceRequest;

typedef void (^IdentitiesSuccessCompletionBlock)(NSArray<DSIdentity *> *_Nullable identities);
typedef void (^IdentitiesCompletionBlock)(BOOL success, NSArray<DSIdentity *> *_Nullable identities, NSArray<NSError *> *errors);
typedef void (^IdentityCompletionBlock)(BOOL success, DSIdentity *_Nullable identity, NSError *_Nullable error);
typedef void (^DashpayUserInfosCompletionBlock)(BOOL success, NSDictionary<NSData *, DSTransientDashpayUser *> *_Nullable dashpayUserInfosByIdentityUniqueId, NSError *_Nullable error);
typedef void (^DashpayUserInfoCompletionBlock)(BOOL success, DSTransientDashpayUser *_Nullable dashpayUserInfo, NSError *_Nullable error);

@interface DSIdentitiesManager : NSObject <DSChainIdentitiesDelegate>

@property (nonatomic, readonly) DSChain *chain;

/*! @brief Returns the timestamp of the last time identities were synced.  */
@property (nonatomic, readonly) NSTimeInterval lastSyncedIndentitiesTimestamp;

/*! @brief Returns if we synced identities in the last 30 seconds.  */
@property (nonatomic, readonly) BOOL hasRecentIdentitiesSync;

- (instancetype)initWithChain:(DSChain *)chain;

//- (void)registerForeignIdentity:(DSIdentity *)identity;

//- (DSIdentity *)foreignIdentityWithUniqueId:(UInt256)uniqueId;
//
//- (DSIdentity *)foreignIdentityWithUniqueId:(UInt256)uniqueId createIfMissing:(BOOL)addIfMissing inContext:(NSManagedObjectContext *_Nullable)context;

- (NSArray *)unsyncedIdentities;

- (void)syncIdentitiesWithCompletion:(IdentitiesSuccessCompletionBlock)completion;

- (void)retrieveAllIdentitiesChainStates;

- (void)checkAssetLockTransactionForPossibleNewIdentity:(DSAssetLockTransaction *)transaction;

- (id<DSDAPINetworkServiceRequest>)searchIdentityByDashpayUsername:(NSString *)name
                                                    withCompletion:(IdentityCompletionBlock)completion;

- (id<DSDAPINetworkServiceRequest>)searchIdentityByName:(NSString *)namePrefix
                                               inDomain:(NSString *)domain
                                         withCompletion:(IdentityCompletionBlock)completion;

- (id<DSDAPINetworkServiceRequest>)searchIdentitiesByDashpayUsernamePrefix:(NSString *)namePrefix
                                                   queryDashpayProfileInfo:(BOOL)queryDashpayProfileInfo
                                                            withCompletion:(IdentitiesCompletionBlock)completion;

- (id<DSDAPINetworkServiceRequest>)searchIdentitiesByDashpayUsernamePrefix:(NSString *)namePrefix
                                                                startAfter:(NSData* _Nullable)startAfter
                                                                     limit:(uint32_t)limit
                                                   queryDashpayProfileInfo:(BOOL)queryDashpayProfileInfo
                                                            withCompletion:(IdentitiesCompletionBlock)completion;

- (id<DSDAPINetworkServiceRequest>)searchIdentitiesByNamePrefix:(NSString *)namePrefix
                                                     startAfter:(NSData* _Nullable)startAfter
                                                          limit:(uint32_t)limit
                                                 withCompletion:(IdentitiesCompletionBlock)completion;

- (id<DSDAPINetworkServiceRequest>)fetchProfileForIdentity:(DSIdentity *)identity
                                            withCompletion:(DashpayUserInfoCompletionBlock)completion
                                         onCompletionQueue:(dispatch_queue_t)completionQueue;

- (id<DSDAPINetworkServiceRequest>)fetchProfileForIdentity:(DSIdentity *)identity
                                                          retryCount:(uint32_t)retryCount
                                                               delay:(uint32_t)delay
                                                       delayIncrease:(uint32_t)delayIncrease
                                                      withCompletion:(DashpayUserInfoCompletionBlock)completion
                                                   onCompletionQueue:(dispatch_queue_t)completionQueue;

//- (id<DSDAPINetworkServiceRequest>)fetchProfilesForIdentities:(NSArray<NSData *> *)identityUserIds
//                                               withCompletion:(DashpayUserInfosCompletionBlock)completion
//                                            onCompletionQueue:(dispatch_queue_t)completionQueue;
//
- (void)searchIdentitiesByDPNSRegisteredIdentityUniqueID:(NSData *)userID
                                          withCompletion:(IdentitiesCompletionBlock)completion;

- (void)retrieveIdentitiesByKeysUntilSuccessWithCompletion:(IdentitiesSuccessCompletionBlock)completion completionQueue:(dispatch_queue_t)completionQueue;

- (void)retrieveIdentitiesByKeysWithCompletion:(IdentitiesCompletionBlock)completion
                               completionQueue:(dispatch_queue_t)completionQueue;

- (void)fetchNeededNetworkStateInformationForIdentities:(NSArray<DSIdentity *> *)identities
                                         withCompletion:(IdentitiesCompletionBlock)completion
                                        completionQueue:(dispatch_queue_t)completionQueue;

@end

NS_ASSUME_NONNULL_END
