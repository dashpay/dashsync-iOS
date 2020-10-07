//
//  DSBlockchainIdentityEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 12/31/19.
//
//

#import "DSBlockchainIdentityEntity+CoreDataClass.h"
#import "DSBlockchainIdentity+Protected.h"
#import "DSChainEntity+CoreDataClass.h"
#import "NSManagedObject+Sugar.h"

@implementation DSBlockchainIdentityEntity

+(void)deleteBlockchainIdentitiesOnChainEntity:(DSChainEntity*)chainEntity {
    [chainEntity.managedObjectContext performBlockAndWait:^{
        NSArray * blockchainIdentitiesToDelete = [self objectsInContext:chainEntity.managedObjectContext matching:@"(chain == %@)",chainEntity];
        for (DSBlockchainIdentityEntity * blockchainIdentity in blockchainIdentitiesToDelete) {
            [chainEntity.managedObjectContext deleteObject:blockchainIdentity];
        }
    }];
}

-(DSBlockchainIdentity*)blockchainIdentity {
    return [[DSBlockchainIdentity alloc] initWithBlockchainIdentityEntity:self];
}

@end
