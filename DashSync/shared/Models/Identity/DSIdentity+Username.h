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
#import "DSBlockchainIdentityEntity+CoreDataClass.h"
#import "DSBlockchainIdentityUsernameEntity+CoreDataClass.h"
#import "DSIdentity.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSIdentity (Username)

/*! @brief Related to DPNS. This is the list of usernames with their .dash domain that are associated to the identity in the domain "dash". These usernames however might not yet be registered or might be invalid. This can be used in tandem with the statusOfUsername: method */
@property (nonatomic, readonly) NSArray<NSString *> *dashpayUsernameFullPaths;

/*! @brief Related to DPNS. This is the list of usernames that are associated to the identity in the domain "dash". These usernames however might not yet be registered or might be invalid. This can be used in tandem with the statusOfUsername: method */
@property (nonatomic, readonly) NSArray<NSString *> *dashpayUsernames;

- (void)setupUsernames;
- (void)setupUsernames:(NSMutableDictionary *)statuses
                 salts:(NSMutableDictionary *)salts;

- (void)applyUsernameEntitiesFromIdentityEntity:(DSBlockchainIdentityEntity *)identityEntity;
- (void)collectUsernameEntitiesIntoIdentityEntityInContext:(DSBlockchainIdentityEntity *)identityEntity
                                                   context:(NSManagedObjectContext *)context;

- (void)addDashpayUsername:(NSString *)username save:(BOOL)save;
- (void)addUsername:(NSString *)username inDomain:(NSString *)domain save:(BOOL)save;
- (void)addUsername:(NSString *)username inDomain:(NSString *)domain status:(DSIdentityUsernameStatus)status save:(BOOL)save registerOnNetwork:(BOOL)registerOnNetwork;
- (DSIdentityUsernameStatus)statusOfUsername:(NSString *)username inDomain:(NSString *)domain;
- (DSIdentityUsernameStatus)statusOfDashpayUsername:(NSString *)username;
- (void)registerUsernamesWithCompletion:(void (^_Nullable)(BOOL success, NSError *error))completion;
- (void)fetchUsernamesWithCompletion:(void (^_Nullable)(BOOL success, NSError *error))completion;

- (NSArray<NSString *> *)unregisteredUsernameFullPaths;
- (NSArray<NSString *> *)usernameFullPathsWithStatus:(DSIdentityUsernameStatus)usernameStatus;

- (void)fetchUsernamesInContext:(NSManagedObjectContext *)context
                 withCompletion:(void (^)(BOOL success, NSError *error))completion
              onCompletionQueue:(dispatch_queue_t)completionQueue;

- (void)fetchUsernamesInContext:(NSManagedObjectContext *)context
                     retryCount:(uint32_t)retryCount
                 withCompletion:(void (^)(BOOL success, NSError *error))completion
              onCompletionQueue:(dispatch_queue_t)completionQueue;

@end

NS_ASSUME_NONNULL_END
