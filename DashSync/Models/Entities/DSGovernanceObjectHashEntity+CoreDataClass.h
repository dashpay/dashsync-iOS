//
//  DSGovernanceObjectHashEntity+CoreDataClass.h
//  DashSync
//
//  Created by Sam Westrich on 6/14/18.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class DSChainEntity, DSGovernanceObjectEntity;

NS_ASSUME_NONNULL_BEGIN

@interface DSGovernanceObjectHashEntity : NSManagedObject

+(DSGovernanceObjectHashEntity*)governanceObjectHashEntityWithHash:(NSData*)governanceObjectHash onChainEntity:(DSChainEntity*)chainEntity;
+(NSArray*)governanceObjectHashEntitiesWithHashes:(NSOrderedSet*)governanceObjectHashes onChainEntity:(DSChainEntity*)chainEntity;
+(void)updateTimestampForGovernanceObjectHashEntitiesWithGovernanceObjectHashes:(NSOrderedSet*)governanceObjectHashes onChainEntity:(DSChainEntity*)chainEntity;
+(void)removeOldest:(NSUInteger)count onChainEntity:(DSChainEntity*)chainEntity;
+(NSUInteger)countAroundNowOnChainEntity:(DSChainEntity*)chainEntity;
+(NSUInteger)standaloneCountInLast3hoursOnChainEntity:(DSChainEntity*)chainEntity;
+(void)deleteHashesOnChainEntity:(DSChainEntity*)chainEntity;

@end

NS_ASSUME_NONNULL_END

#import "DSGovernanceObjectHashEntity+CoreDataProperties.h"
