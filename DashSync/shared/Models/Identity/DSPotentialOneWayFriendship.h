//
//  Created by Sam Westrich
//  Copyright © 2019 Dash Core Group. All rights reserved.
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

#import "BigIntTypes.h"
#import "dash_shared_core.h"
#import "DSKeyManager.h"
#import "DSDashPlatform.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class DSIdentity, DSAccount, DSFriendRequestEntity, DSPotentialContact, DSDashpayUserEntity, DSIncomingFundsDerivationPath, DSDerivationPathEntity;

@interface DSPotentialOneWayFriendship : NSObject

@property (nonatomic, readonly) DSAccount *account;
@property (nonatomic, readonly) DSIdentity *destinationIdentity;
@property (nonatomic, readonly) DSIdentity *sourceIdentity; //this is the holder of the contacts, not the destination
@property (nonatomic, readonly) NSTimeInterval createdAt;
@property (nonatomic, readonly) DSIncomingFundsDerivationPath *derivationPath;
@property (nonatomic, readonly) uint32_t sourceKeyIndex;
@property (nonatomic, readonly) uint32_t destinationKeyIndex;
@property (nonatomic, readonly) UInt256 destinationIdentityUniqueId;

- (instancetype)initWithDestinationIdentity:(DSIdentity *)destinationIdentity
                        destinationKeyIndex:(uint32_t)destinationKeyIndex
                             sourceIdentity:(DSIdentity *)sourceIdentity
                             sourceKeyIndex:(uint32_t)sourceKeyIndex
                                    account:(DSAccount *)account;

- (instancetype)initWithDestinationIdentity:(DSIdentity *)destinationIdentity
                        destinationKeyIndex:(uint32_t)destinationKeyIndex
                             sourceIdentity:(DSIdentity *)sourceIdentity
                             sourceKeyIndex:(uint32_t)sourceKeyIndex
                                    account:(DSAccount *)account
                                  createdAt:(NSTimeInterval)createdAt;

//-(DSFriendRequestEntity*)outgoingFriendRequest;

- (DSFriendRequestEntity *)outgoingFriendRequestForDashpayUserEntity:(DSDashpayUserEntity *)dashpayUserEntity
                                                         atTimestamp:(NSTimeInterval)timestamp;

- (DSDerivationPathEntity *)storeExtendedPublicKeyAssociatedWithFriendRequest:(DSFriendRequestEntity *)entity
                                                                    inContext:(NSManagedObjectContext *)context;
- (DSDerivationPathEntity *)storeExtendedPublicKeyAssociatedWithFriendRequest:(DSFriendRequestEntity *)entity;

- (void)createDerivationPathAndSaveExtendedPublicKeyWithCompletion:(void (^)(BOOL success, DSIncomingFundsDerivationPath *incomingFundsDerivationPath))completion;

- (void)encryptExtendedPublicKeyWithCompletion:(void (^)(BOOL success))completion;

- (DValue *)toValue;

@end

NS_ASSUME_NONNULL_END
