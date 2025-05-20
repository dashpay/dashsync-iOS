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

//@protocol DSDAPINetworkServiceRequest;

typedef void (^IdentitiesSuccessCompletionBlock)(NSArray<DSIdentity *> *_Nullable identities);
typedef void (^IdentitiesCompletionBlock)(BOOL success, NSArray<DSIdentity *> *_Nullable identities, NSArray<NSError *> *errors);
typedef void (^IdentityCompletionBlock)(BOOL success, DSIdentity *_Nullable identity, NSError *_Nullable error);
typedef void (^DashpayUserInfosCompletionBlock)(BOOL success, NSDictionary<NSData *, DSTransientDashpayUser *> *_Nullable dashpayUserInfosByIdentityUniqueId, NSError *_Nullable error);
typedef void (^DashpayUserInfoCompletionBlock)(BOOL success, DSTransientDashpayUser *_Nullable dashpayUserInfo, NSError *_Nullable error);

@interface DSIdentitiesManager : NSObject <DSChainIdentitiesDelegate>

@property (nonatomic, readonly) DSChain *chain;

/*! @brief Returns the timestamp of the last time identities were synced.  */
@property (nonatomic, readonly) NSTimeInterval lastSyncedIndentitiesTimestamp;


- (instancetype)initWithChain:(DSChain *)chain;

//- (void)registerForeignIdentity:(DSIdentity *)identity;

//- (DSIdentity *)foreignIdentityWithUniqueId:(UInt256)uniqueId;
//
//- (DSIdentity *)foreignIdentityWithUniqueId:(UInt256)uniqueId createIfMissing:(BOOL)addIfMissing inContext:(NSManagedObjectContext *_Nullable)context;

- (NSArray *)unsyncedIdentities;
//- (void)syncPlatformWithCompletion:(IdentitiesSuccessCompletionBlock)completion;

- (void)syncIdentitiesWithCompletion:(IdentitiesSuccessCompletionBlock)completion;

//- (void)retrieveAllIdentitiesChainStates:(IdentitiesSuccessCompletionBlock)completion;

- (void)checkAssetLockTransactionForPossibleNewIdentity:(DSAssetLockTransaction *)transaction;

- (void)searchIdentityByDashpayUsername:(NSString *)name
                         withCompletion:(IdentityCompletionBlock)completion;

- (void)searchIdentityByName:(NSString *)namePrefix
                    inDomain:(NSString *)domain
              withCompletion:(IdentityCompletionBlock)completion;

- (void)searchIdentitiesByDashpayUsernamePrefix:(NSString *)namePrefix
                        queryDashpayProfileInfo:(BOOL)queryDashpayProfileInfo
                                 withCompletion:(IdentitiesCompletionBlock)completion;

- (void)searchIdentitiesByDashpayUsernamePrefix:(NSString *)namePrefix
                                     startAfter:(NSData* _Nullable)startAfter
                                          limit:(uint32_t)limit
                        queryDashpayProfileInfo:(BOOL)queryDashpayProfileInfo
                                 withCompletion:(IdentitiesCompletionBlock)completion;

- (void)searchIdentitiesByNamePrefix:(NSString *)namePrefix
                          startAfter:(NSData* _Nullable)startAfter
                               limit:(uint32_t)limit
                      withCompletion:(IdentitiesCompletionBlock)completion;

//- (void)fetchProfileForIdentity:(DSIdentity *)identity
//                 withCompletion:(DashpayUserInfoCompletionBlock)completion
//              onCompletionQueue:(dispatch_queue_t)completionQueue;

- (void)searchIdentitiesByDPNSRegisteredIdentityUniqueID:(NSData *)userID
                                          withCompletion:(IdentitiesCompletionBlock)completion;


- (NSString *)logPrefix;

@end

NS_ASSUME_NONNULL_END
