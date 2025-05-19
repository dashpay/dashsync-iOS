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
@property (nonatomic, readonly) NSUInteger dashpayUsernameCount;
/*! @brief Related to DPNS. This is the list of usernames that are associated to the identity in the domain "dash". These usernames however might not yet be registered or might be invalid. This can be used in tandem with the statusOfUsername: method */
@property (nonatomic, readonly) NSArray<NSString *> *dashpayUsernames;

- (void)applyUsernameEntitiesFromIdentityEntity:(DSBlockchainIdentityEntity *)identityEntity;
- (void)collectUsernameEntitiesIntoIdentityEntityInContext:(DSBlockchainIdentityEntity *)identityEntity
                                                   context:(NSManagedObjectContext *)context;
- (void)addDashpayUsername:(NSString *)username;
- (void)addDashpayUsername:(NSString *)username save:(BOOL)save;
- (void)addConfirmedUsername:(NSString *)username
                    inDomain:(NSString *)domain;

- (void)addUsername:(NSString *)username
           inDomain:(NSString *)domain
             status:(DUsernameStatus)status;
- (void)addUsername:(NSString *)username
           inDomain:(NSString *)domain
               save:(BOOL)save;
- (void)addUsername:(NSString *)username
           inDomain:(NSString *)domain
             status:(DUsernameStatus)status
               save:(BOOL)save
  registerOnNetwork:(BOOL)registerOnNetwork;
- (DUsernameStatus *_Nullable)statusOfUsername:(NSString *)username
                             inDomain:(NSString *)domain;
- (DUsernameStatus *_Nullable)statusOfDashpayUsername:(NSString *)username;
- (void)registerUsernamesWithCompletion:(void (^_Nullable)(BOOL success, NSArray<NSError *> *errors))completion;

- (void)fetchUsernamesInContext:(NSManagedObjectContext *)context
                 withCompletion:(void (^)(BOOL success, NSError *error))completion
              onCompletionQueue:(dispatch_queue_t)completionQueue;

//- (void)setAndSaveUsernameFullPaths:(NSArray *)usernameFullPaths
//                           toStatus:(DUsernameStatus *)status
//                          inContext:(NSManagedObjectContext *)context;

- (BOOL)hasDashpayUsername:(NSString *)username;

- (void)notifyUsernameUpdate:(nullable NSDictionary *)userInfo;

@end

NS_ASSUME_NONNULL_END
