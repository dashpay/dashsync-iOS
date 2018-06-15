//
//  DSGovernanceVoteHashEntity+CoreDataClass.h
//  DashSync
//
//  Created by Sam Westrich on 6/15/18.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class DSChainEntity, DSGovernanceVoteEntity;

NS_ASSUME_NONNULL_BEGIN

@interface DSGovernanceVoteHashEntity : NSManagedObject

+(NSArray*)governanceVoteHashEntitiesWithHashes:(NSOrderedSet*)governanceVoteHashes onChain:(DSChainEntity*)chainEntity;
+(void)updateTimestampForGovernanceVoteHashEntitiesWithGovernanceVoteHashes:(NSOrderedSet*)governanceVoteHashes onChain:(DSChainEntity*)chainEntity;
+(void)removeOldest:(NSUInteger)count onChain:(DSChainEntity*)chainEntity;
+(NSUInteger)countAroundNowOnChain:(DSChainEntity*)chainEntity;
+(NSUInteger)standaloneCountInLast3hoursOnChain:(DSChainEntity*)chainEntity;

@end

NS_ASSUME_NONNULL_END

#import "DSGovernanceVoteHashEntity+CoreDataProperties.h"
