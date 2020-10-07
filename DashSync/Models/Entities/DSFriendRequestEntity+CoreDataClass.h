//
//  DSFriendRequestEntity+CoreDataClass.h
//  DashSync
//
//  Created by Sam Westrich on 3/24/19.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class DSDashpayUserEntity, DSTransitionEntity, DSDerivationPathEntity, DSAccountEntity, DSChainEntity;

NS_ASSUME_NONNULL_BEGIN

@interface DSFriendRequestEntity : NSManagedObject

-(NSData*)finalizeWithFriendshipIdentifier;
+(void)deleteFriendRequestsOnChainEntity:(DSChainEntity*)chainEntity;

@end

NS_ASSUME_NONNULL_END

#import "DSFriendRequestEntity+CoreDataProperties.h"
