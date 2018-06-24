//
//  DSGovernanceVoteHashEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 6/15/18.
//
//

#import "DSGovernanceVoteHashEntity+CoreDataClass.h"
#import "DSChainEntity+CoreDataClass.h"
#import "NSManagedObject+Sugar.h"

@implementation DSGovernanceVoteHashEntity

+(NSArray*)governanceVoteHashEntitiesWithHashes:(NSOrderedSet*)governanceVoteHashes onChain:(DSChainEntity*)chainEntity {
    NSAssert(chainEntity, @"chain entity is not set");
    NSMutableArray * rArray = [NSMutableArray arrayWithCapacity:governanceVoteHashes.count];
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    for (NSData * governanceVoteHash in governanceVoteHashes) {
        DSGovernanceVoteHashEntity * governanceVoteHashEntity = [self managedObject];
        governanceVoteHashEntity.governanceVoteHash = governanceVoteHash;
        governanceVoteHashEntity.timestamp = now;
        governanceVoteHashEntity.chain = chainEntity;
        [rArray addObject:governanceVoteHashEntity];
    }
    return [rArray copy];
}

+(void)updateTimestampForGovernanceVoteHashEntitiesWithGovernanceVoteHashes:(NSOrderedSet*)governanceVoteHashes onChain:(DSChainEntity*)chainEntity {
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    NSArray * entitiesToUpdate = [self objectsMatching:@"governanceVoteHash in %@",governanceVoteHashes];
    for (DSGovernanceVoteHashEntity * entityToUpdate in entitiesToUpdate) {
        entityToUpdate.timestamp = now;
    }
}

+(void)removeOldest:(NSUInteger)count onChain:(DSChainEntity*)chainEntity {
    NSFetchRequest * fetchRequest = [self fetchReq];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"chain == %@",chainEntity]];
    [fetchRequest setFetchLimit:count];
    [fetchRequest setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:TRUE]]];
    NSArray * oldObjects = [self fetchObjects:fetchRequest];
    for (NSManagedObject *obj in oldObjects) {
        [self.context deleteObject:obj];
    }
}

+(NSUInteger)countAroundNowOnChain:(DSChainEntity*)chainEntity {
    NSTimeInterval aMinuteAgo = [[NSDate date] timeIntervalSince1970] - 60;
    return [self countObjectsMatching:@"chain == %@ && timestamp > %@",chainEntity,@(aMinuteAgo)];
}

+(NSUInteger)standaloneCountInLast3hoursOnChain:(DSChainEntity*)chainEntity {
    NSTimeInterval threeHoursAgo = [[NSDate date] timeIntervalSince1970] - 10800;
    return [self countObjectsMatching:@"chain == %@ && timestamp > %@ && governanceVote == nil",chainEntity,@(threeHoursAgo)];
}

+ (void)deleteHashesOnChain:(DSChainEntity*)chainEntity {
    [chainEntity.managedObjectContext performBlockAndWait:^{
        NSArray * hashesToDelete = [self objectsMatching:@"(chain == %@)",chainEntity];
        for (DSGovernanceVoteHashEntity * governanceVoteHashEntity in hashesToDelete) {
            [chainEntity.managedObjectContext deleteObject:governanceVoteHashEntity];
        }
    }];
}

@end
