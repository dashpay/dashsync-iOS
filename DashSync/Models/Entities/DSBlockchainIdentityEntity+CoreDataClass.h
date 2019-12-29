//
//  DSBlockchainIdentityEntity+CoreDataClass.h
//  DashSync
//
//  Created by Sam Westrich on 12/29/19.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class DSBlockchainIdentityKeyPathEntity, DSContactEntity, DSTransitionEntity;

NS_ASSUME_NONNULL_BEGIN

@interface DSBlockchainIdentityEntity : NSManagedObject

@end

NS_ASSUME_NONNULL_END

#import "DSBlockchainIdentityEntity+CoreDataProperties.h"
