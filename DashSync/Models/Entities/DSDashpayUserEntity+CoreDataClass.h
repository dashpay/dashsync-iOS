//
//  DSdashpayUserEntity+CoreDataClass.h
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
#import "DSPotentialOneWayFriendship.h"

typedef NS_ENUM(NSUInteger, DSDashpayUserEntityFriendActivityType) {
    DSDashpayUserEntityFriendActivityType_IncomingTransactions,
    DSDashpayUserEntityFriendActivityType_OutgoingTransactions
};

@class DSAccountEntity, DSFriendRequestEntity, DSTransitionEntity, DSTransientDashpayUser, DSBlockchainIdentity,DSPotentialOneWayFriendship,DSWallet,DSIncomingFundsDerivationPath,DSChainEntity, DSBlockchainIdentityEntity, DPDocument;

NS_ASSUME_NONNULL_BEGIN

@interface DSDashpayUserEntity : NSManagedObject

@property (nonatomic,readonly) NSString * username;

+(void)deleteContactsOnChainEntity:(DSChainEntity*)chainEntity;

//-(DPDocument*)profileDocument;

//-(DPDocument*)contactRequestDocument;

-(NSArray<DSDashpayUserEntity*>*)mostActiveFriends:(DSDashpayUserEntityFriendActivityType)activityType count:(NSUInteger)count ascending:(BOOL)ascending;

-(NSDictionary<NSData*,NSNumber*>*)friendsWithActivityForType:(DSDashpayUserEntityFriendActivityType)activityType count:(NSUInteger)count ascending:(BOOL)ascending;

-(NSError*)applyTransientDashpayUser:(DSTransientDashpayUser*)transientDashpayUser save:(BOOL)save;

@end

NS_ASSUME_NONNULL_END

#import "DSDashpayUserEntity+CoreDataProperties.h"
