//
//  DSBlockchainIdentityEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 12/31/19.
//
//

#import "DSIdentity+Protected.h"
#import "DSBlockchainIdentityEntity+CoreDataClass.h"
#import "DSChainEntity+CoreDataClass.h"
#import "NSManagedObject+Sugar.h"

@implementation DSBlockchainIdentityEntity

+ (void)deleteBlockchainIdentitiesOnChainEntity:(DSChainEntity *)chainEntity {
    [chainEntity.managedObjectContext performBlockAndWait:^{
        NSArray *identitiesToDelete = [self objectsInContext:chainEntity.managedObjectContext matching:@"(chain == %@)", chainEntity];
        for (DSBlockchainIdentityEntity *identity in identitiesToDelete) {
            [chainEntity.managedObjectContext deleteObject:identity];
        }
    }];
}

- (DSIdentity *)identity {
    return [[DSIdentity alloc] initWithIdentityEntity:self];
}

@end
