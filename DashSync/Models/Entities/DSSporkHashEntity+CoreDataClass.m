//
//  DSSporkHashEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 7/17/18.
//
//

#import "DSSporkHashEntity+CoreDataClass.h"
#import "NSManagedObject+Sugar.h"
#import "DSChainEntity+CoreDataClass.h"

@implementation DSSporkHashEntity

+(DSSporkHashEntity*)sporkHashEntityWithHash:(NSData*)sporkHash onChainEntity:(DSChainEntity*)chainEntity {
    return [[self sporkHashEntitiesWithHash:[NSOrderedSet orderedSetWithObject:sporkHash] onChainEntity:chainEntity] firstObject];
}

+(NSArray*)sporkHashEntitiesWithHash:(NSOrderedSet*)sporkHashes onChainEntity:(DSChainEntity*)chainEntity {
    NSAssert(chainEntity, @"chain entity is not set");
    NSMutableArray * rArray = [NSMutableArray arrayWithCapacity:sporkHashes.count];
    for (NSData * sporkHash in sporkHashes) {
        NSArray * sporkHashesFromDisk = [self objectsInContext:chainEntity.managedObjectContext matching:@"sporkHash = %@",sporkHash];
        if ([sporkHashesFromDisk count]) {
            [rArray addObject:[sporkHashesFromDisk firstObject]];
        } else {
            DSSporkHashEntity * sporkHashEntity = [self managedObjectInContext:chainEntity.managedObjectContext];
            sporkHashEntity.sporkHash = sporkHash;
            sporkHashEntity.chain = chainEntity;
            [rArray addObject:sporkHashEntity];
        }
    }
    return [rArray copy];
}

+(NSArray*)standaloneSporkHashEntitiesOnChainEntity:(DSChainEntity*)chainEntity {
    NSFetchRequest * fetchRequest = [self fetchReq];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"chain == %@ && spork = nil",chainEntity]];
    NSArray * standaloneHashes = [self fetchObjects:fetchRequest inContext:chainEntity.managedObjectContext];
    return standaloneHashes;
}

@end
