//
//  DSTransactionHashEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 7/23/18.
//
//

#import "DSChain.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSTransactionHashEntity+CoreDataClass.h"
#import "NSManagedObject+Sugar.h"

@implementation DSTransactionHashEntity

+ (NSArray *)standaloneTransactionHashEntitiesOnChain:(DSChainEntity *)chainEntity {
    NSFetchRequest *fetchRequest = [self fetchReq];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"chain == %@ && transaction = nil", chainEntity]];
    NSArray *standaloneHashes = [self fetchObjects:fetchRequest];
    return standaloneHashes;
}

+ (void)deleteTransactionHashesOnChain:(DSChainEntity *)chainEntity {
    [chainEntity.managedObjectContext performBlockAndWait:^{
        NSArray *transactionsToDelete = [self objectsMatching:@"(chain == %@)", chainEntity];
        for (DSTransactionHashEntity *transaction in transactionsToDelete) {
            [chainEntity.managedObjectContext deleteObject:transaction];
        }
    }];
}

@end
