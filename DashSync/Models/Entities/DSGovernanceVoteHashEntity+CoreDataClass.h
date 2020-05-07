//
//  DSGovernanceVoteHashEntity+CoreDataClass.h
//  DashSync
//
//  Created by Sam Westrich on 6/15/18.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class DSChainEntity, DSGovernanceVoteEntity, DSGovernanceObjectEntity;

NS_ASSUME_NONNULL_BEGIN

@interface DSGovernanceVoteHashEntity : NSManagedObject

+(NSArray*)governanceVoteHashEntitiesWithHashes:(NSOrderedSet*)governanceVoteHashes forGovernanceObjectEntity:(DSGovernanceObjectEntity*)governanceObject;
+(void)updateTimestampForGovernanceVoteHashEntitiesWithGovernanceVoteHashes:(NSOrderedSet*)governanceVoteHashes forGovernanceObjectEntity:(DSGovernanceObjectEntity*)governanceObject;
+(void)removeOldest:(NSUInteger)count hashesNotIn:(NSSet*)governanceVoteHashes forGovernanceObjectEntity:(DSGovernanceObjectEntity*)governanceObject;
+(NSUInteger)countAroundNowOnChainEntity:(DSChainEntity*)chainEntity;
+(NSUInteger)standaloneCountInLast3hoursOnChainEntity:(DSChainEntity*)chainEntity;
+(void)deleteHashesOnChainEntity:(DSChainEntity*)chainEntity;

@end

NS_ASSUME_NONNULL_END

#import "DSGovernanceVoteHashEntity+CoreDataProperties.h"
