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
#import "DSFriendRequestEntity+CoreDataClass.h"
#import "DSPotentialContact.h"
#import "DSPotentialOneWayFriendship.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSIdentity (Friendship)

- (void)sendNewFriendRequestToIdentity:(DSIdentity *)identity
                            completion:(void (^)(BOOL success, NSArray<NSError *> *_Nullable errors))completion;
- (void)sendNewFriendRequestToPotentialContact:(DSPotentialContact *)potentialContact
                                    completion:(void (^_Nullable)(BOOL success, NSArray<NSError *> *errors))completion;
- (void)acceptFriendRequestFromIdentity:(DSIdentity *)otherIdentity
                             completion:(void (^)(BOOL success, NSArray<NSError *> *errors))completion;
- (void)acceptFriendRequest:(DSFriendRequestEntity *)friendRequest
                 completion:(void (^_Nullable)(BOOL success, NSArray<NSError *> *errors))completion;
- (void)addFriendshipFromSourceIdentity:(DSIdentity *)sourceIdentity
                         sourceKeyIndex:(uint32_t)sourceKeyIndex
                    toRecipientIdentity:(DSIdentity *)recipientIdentity
                      recipientKeyIndex:(uint32_t)recipientKeyIndex
                            atTimestamp:(NSTimeInterval)timestamp
                              inContext:(NSManagedObjectContext *)context;
- (DSIdentityFriendshipStatus)friendshipStatusForRelationshipWithIdentity:(DSIdentity *)otherIdentity;

@end

NS_ASSUME_NONNULL_END
