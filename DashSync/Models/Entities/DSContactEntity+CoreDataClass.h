//
//  DSContactEntity+CoreDataClass.h
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

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "BigIntTypes.h"
#import <ios-dpp/DashPlatformProtocol.h>
#import "DSPotentialFriendship.h"

@class DSAccountEntity, DSBlockchainIdentityRegistrationTransitionEntity, DSFriendRequestEntity, DSTransitionEntity, DSBlockchainIdentity,DSPotentialFriendship,DSWallet,DSIncomingFundsDerivationPath,DSChainEntity;

NS_ASSUME_NONNULL_BEGIN

@interface DSContactEntity : NSManagedObject

+(void)deleteContactsOnChain:(DSChainEntity*)chainEntity;

@end

NS_ASSUME_NONNULL_END

#import "DSContactEntity+CoreDataProperties.h"
