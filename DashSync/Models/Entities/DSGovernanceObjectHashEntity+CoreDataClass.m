//
//  DSGovernanceObjectHashEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 6/14/18.
//
//

#import "DSGovernanceObjectHashEntity+CoreDataClass.h"
#import "DSChainEntity+CoreDataClass.h"
#import "NSManagedObject+Sugar.h"

@implementation DSGovernanceObjectHashEntity

+(DSGovernanceObjectHashEntity*)governanceObjectHashEntityWithHash:(NSData*)governanceObjectHash onChainEntity:(DSChainEntity*)chainEntity {
    return [[self governanceObjectHashEntitiesWithHashes:[NSOrderedSet orderedSetWithObject:governanceObjectHash] onChainEntity:chainEntity] firstObject];
}

+(NSArray*)governanceObjectHashEntitiesWithHashes:(NSOrderedSet*)governanceObjectHashes onChainEntity:(DSChainEntity*)chainEntity {
    NSAssert(chainEntity, @"chain entity is not set");
    NSMutableArray * rArray = [NSMutableArray arrayWithCapacity:governanceObjectHashes.count];
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    for (NSData * governanceObjectHash in governanceObjectHashes) {
        DSGovernanceObjectHashEntity * governanceObjectHashEntity = [self managedObjectInContext:chainEntity.managedObjectContext];
        governanceObjectHashEntity.governanceObjectHash = governanceObjectHash;
        governanceObjectHashEntity.timestamp = now;
        governanceObjectHashEntity.chain = chainEntity;
        [rArray addObject:governanceObjectHashEntity];
    }
    return [rArray copy];
}

+(void)updateTimestampForGovernanceObjectHashEntitiesWithGovernanceObjectHashes:(NSOrderedSet*)governanceObjectHashes onChainEntity:(DSChainEntity*)chainEntity {
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    NSArray * entitiesToUpdate = [self objectsInContext:chainEntity.managedObjectContext matching:@"governanceObjectHash in %@",governanceObjectHashes];
    for (DSGovernanceObjectHashEntity * entityToUpdate in entitiesToUpdate) {
        entityToUpdate.timestamp = now;
    }
}

+(void)removeOldest:(NSUInteger)count onChainEntity:(DSChainEntity*)chainEntity {
    NSFetchRequest * fetchRequest = [self fetchReq];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"chain == %@",chainEntity]];
    [fetchRequest setFetchLimit:count];
    [fetchRequest setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:TRUE]]];
    NSArray * oldObjects = [self fetchObjects:fetchRequest inContext:chainEntity.managedObjectContext];
    for (NSManagedObject *obj in oldObjects) {
        [chainEntity.managedObjectContext deleteObject:obj];
    }
}

+(NSUInteger)countAroundNowOnChainEntity:(DSChainEntity*)chainEntity {
    NSTimeInterval aMinuteAgo = [[NSDate date] timeIntervalSince1970] - 60;
    return [self countObjectsInContext:chainEntity.managedObjectContext matching:@"chain == %@ && timestamp > %@",chainEntity,@(aMinuteAgo)];
}

+(NSUInteger)standaloneCountInLast3hoursOnChainEntity:(DSChainEntity*)chainEntity {
    NSTimeInterval threeHoursAgo = [[NSDate date] timeIntervalSince1970] - 10800;
    return [self countObjectsInContext:chainEntity.managedObjectContext matching:@"chain == %@ && timestamp > %@ && governanceObject == nil",chainEntity,@(threeHoursAgo)];
}

+ (void)deleteHashesOnChainEntity:(DSChainEntity*)chainEntity {
    [chainEntity.managedObjectContext performBlockAndWait:^{
        NSArray * hashesToDelete = [self objectsInContext:chainEntity.managedObjectContext matching:@"(chain == %@)",chainEntity];
        for (DSGovernanceObjectHashEntity * governanceObjectHashEntity in hashesToDelete) {
            [chainEntity.managedObjectContext deleteObject:governanceObjectHashEntity];
        }
    }];
}

@end
