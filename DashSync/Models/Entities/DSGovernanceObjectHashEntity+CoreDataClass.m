//
//  DSGovernanceObjectHashEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 6/14/18.
//
//

#import "DSGovernanceObjectHashEntity+CoreDataClass.h"
#import "NSManagedObject+Sugar.h"

@implementation DSGovernanceObjectHashEntity

+(NSArray*)governanceObjectHashEntitiesWithHashes:(NSOrderedSet*)governanceObjectHashes onChain:(DSChainEntity*)chainEntity {
    NSMutableArray * rArray = [NSMutableArray arrayWithCapacity:governanceObjectHashes.count];
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    for (NSData * governanceObjectHash in governanceObjectHashes) {
        DSGovernanceObjectHashEntity * governanceObjectHashEntity = [self managedObject];
        governanceObjectHashEntity.governanceObjectHash = governanceObjectHash;
        governanceObjectHashEntity.timestamp = now;
        governanceObjectHashEntity.chain = chainEntity;
        [rArray addObject:governanceObjectHashEntity];
    }
    return [rArray copy];
}

+(void)updateTimestampForGovernanceObjectHashEntitiesWithGovernanceObjectHashes:(NSOrderedSet*)governanceObjectHashes onChain:(DSChainEntity*)chainEntity {
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    NSArray * entitiesToUpdate = [self objectsMatching:@"governanceObjectHash in %@",governanceObjectHashes];
    for (DSGovernanceObjectHashEntity * entityToUpdate in entitiesToUpdate) {
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
    return [self countObjectsMatching:@"chain == %@ && timestamp > %@ && governanceObject == nil",chainEntity,@(threeHoursAgo)];
}

@end
