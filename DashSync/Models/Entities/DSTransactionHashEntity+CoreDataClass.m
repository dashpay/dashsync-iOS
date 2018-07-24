//
//  DSTransactionHashEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 7/23/18.
//
//

#import "DSTransactionHashEntity+CoreDataClass.h"
#import "NSManagedObject+Sugar.h"

@implementation DSTransactionHashEntity

+(NSArray*)standaloneTransactionHashEntitiesOnChain:(DSChainEntity*)chainEntity {
    NSFetchRequest * fetchRequest = [self fetchReq];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"chain == %@ && transaction = nil",chainEntity]];
    NSArray * standaloneHashes = [self fetchObjects:fetchRequest];
    return standaloneHashes;
}

@end
