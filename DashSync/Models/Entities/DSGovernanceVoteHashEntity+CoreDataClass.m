//
//  DSGovernanceVoteHashEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 6/15/18.
//
//

#import "DSGovernanceVoteHashEntity+CoreDataClass.h"
#import "DSGovernanceObjectEntity+CoreDataClass.h"
#import "DSGovernanceObjectHashEntity+CoreDataClass.h"
#import "DSChainEntity+CoreDataClass.h"
#import "NSManagedObject+Sugar.h"

@implementation DSGovernanceVoteHashEntity

+(NSArray*)governanceVoteHashEntitiesWithHashes:(NSOrderedSet*)governanceVoteHashes forGovernanceObjectEntity:(DSGovernanceObjectEntity*)governanceObjectEntity {
    NSAssert(governanceObjectEntity, @"governance object entity is not set");
    NSMutableArray * rArray = [NSMutableArray arrayWithCapacity:governanceVoteHashes.count];
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    for (NSData * governanceVoteHash in governanceVoteHashes) {
        DSGovernanceVoteHashEntity * governanceVoteHashEntity = [self managedObjectInBlockedContext:governanceObjectEntity.managedObjectContext];
        governanceVoteHashEntity.governanceVoteHash = governanceVoteHash;
        governanceVoteHashEntity.timestamp = now;
        governanceVoteHashEntity.chain = governanceObjectEntity.governanceObjectHash.chain;
        governanceVoteHashEntity.governanceObject = governanceObjectEntity;
        [rArray addObject:governanceVoteHashEntity];
    }
    return [rArray copy];
}

+(void)updateTimestampForGovernanceVoteHashEntitiesWithGovernanceVoteHashes:(NSOrderedSet*)governanceVoteHashes forGovernanceObjectEntity:(DSGovernanceObjectEntity*)governanceObjectEntity {
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    NSArray * entitiesToUpdate = [self objectsInContext:governanceObjectEntity.managedObjectContext matching:@"(governanceObject == %@) && (governanceVoteHash in %@)",governanceObjectEntity,governanceVoteHashes];
    for (DSGovernanceVoteHashEntity * entityToUpdate in entitiesToUpdate) {
        entityToUpdate.timestamp = now;
    }
}

+(void)removeOldest:(NSUInteger)count hashesNotIn:(NSSet*)governanceVoteHashes forGovernanceObjectEntity:(DSGovernanceObjectEntity*)governanceObjectEntity {
    NSFetchRequest * fetchRequest = [self fetchReq];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"(governanceObject == %@) && (governanceVoteHash in %@)",governanceObjectEntity.managedObjectContext,governanceVoteHashes]];
    [fetchRequest setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:TRUE]]];
    NSArray * oldObjects = [self fetchObjects:fetchRequest inContext:governanceObjectEntity.managedObjectContext];
    NSUInteger remainingToDeleteCount = count;
    for (NSManagedObject *obj in oldObjects) {
        [governanceObjectEntity.managedObjectContext deleteObject:obj];
        remainingToDeleteCount--;
        if (!remainingToDeleteCount) break;
    }
}

+(NSUInteger)countAroundNowOnChainEntity:(DSChainEntity*)chainEntity {
    NSTimeInterval aMinuteAgo = [[NSDate date] timeIntervalSince1970] - 60;
    return [self countObjectsInContext:chainEntity.managedObjectContext matching:@"chain == %@ && timestamp > %@",chainEntity,@(aMinuteAgo)];
}

+(NSUInteger)standaloneCountInLast3hoursOnChainEntity:(DSChainEntity*)chainEntity {
    NSTimeInterval threeHoursAgo = [[NSDate date] timeIntervalSince1970] - 10800;
    return [self countObjectsInContext:chainEntity.managedObjectContext matching:@"chain == %@ && timestamp > %@ && governanceVote == nil",chainEntity,@(threeHoursAgo)];
}

+ (void)deleteHashesOnChainEntity:(DSChainEntity*)chainEntity {
    [chainEntity.managedObjectContext performBlockAndWait:^{
        NSArray * hashesToDelete = [self objectsInContext:chainEntity.managedObjectContext matching:@"(chain == %@)",chainEntity];
        for (DSGovernanceVoteHashEntity * governanceVoteHashEntity in hashesToDelete) {
            [chainEntity.managedObjectContext deleteObject:governanceVoteHashEntity];
        }
    }];
}

@end
