//
//  DSTransactionHashEntity+CoreDataClass.h
//  DashSync
//
//  Created by Sam Westrich on 7/23/18.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class DSChainEntity, DSTransactionEntity;

NS_ASSUME_NONNULL_BEGIN

@interface DSTransactionHashEntity : NSManagedObject

+(NSArray*)standaloneTransactionHashEntitiesOnChain:(DSChainEntity*)chainEntity;
+ (void)deleteTransactionHashesOnChain:(DSChainEntity*)chainEntity;

@end

NS_ASSUME_NONNULL_END

#import "DSTransactionHashEntity+CoreDataProperties.h"
