//
//  DSFriendRequestEntity+CoreDataClass.h
//  DashSync
//
//  Created by Sam Westrich on 3/24/19.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class DSContactEntity, DSTransitionEntity,DSDerivationPathEntity,DSAccountEntity;

NS_ASSUME_NONNULL_BEGIN

@interface DSFriendRequestEntity : NSManagedObject

@end

NS_ASSUME_NONNULL_END

#import "DSFriendRequestEntity+CoreDataProperties.h"
