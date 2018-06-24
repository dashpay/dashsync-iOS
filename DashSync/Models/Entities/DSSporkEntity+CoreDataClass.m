//
//  DSSporkEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 5/28/18.
//
//

#import "DSSporkEntity+CoreDataClass.h"
#import "DSSpork.h"
#import "DSChain.h"
#import "DSChainEntity+CoreDataClass.h"
#import "NSManagedObject+Sugar.h"

@implementation DSSporkEntity

- (void)setAttributesFromSpork:(DSSpork *)spork
{
    [self.managedObjectContext performBlockAndWait:^{
        self.identifier = spork.identifier;
        self.signature = spork.signature;
        self.timeSigned = spork.timeSigned;
        self.value = spork.value;
        self.chain = [DSChainEntity chainEntityForType:spork.chain.chainType devnetIdentifier:spork.chain.devnetIdentifier checkpoints:nil];
    }];
}

+ (NSArray<DSSporkEntity*>*)sporksOnChain:(DSChainEntity*)chainEntity {
    __block NSArray * sporksOnChain;
    [chainEntity.managedObjectContext performBlockAndWait:^{
        sporksOnChain = [self objectsMatching:@"(chain == %@)",chainEntity];
    }];
    return sporksOnChain;
}

+ (void)deleteSporksOnChain:(DSChainEntity*)chainEntity {
    [chainEntity.managedObjectContext performBlockAndWait:^{
        NSArray * sporksToDelete = [self objectsMatching:@"(chain == %@)",chainEntity];
        for (DSSporkEntity * sporkEntity in sporksToDelete) {
            [chainEntity.managedObjectContext deleteObject:sporkEntity];
        }
    }];
}

@end
