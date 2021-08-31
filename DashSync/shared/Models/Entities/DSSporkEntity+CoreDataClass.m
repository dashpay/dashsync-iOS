//
//  DSSporkEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 5/28/18.
//
//

#import "DSChain+Protected.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSSpork.h"
#import "DSSporkEntity+CoreDataClass.h"
#import "DSSporkHashEntity+CoreDataClass.h"
#import "NSData+Dash.h"
#import "NSManagedObject+Sugar.h"

@implementation DSSporkEntity

- (void)setAttributesFromSpork:(DSSpork *)spork withSporkHash:(DSSporkHashEntity *)sporkHash {
    [self.managedObjectContext performBlockAndWait:^{
        self.identifier = spork.identifier;
        self.signature = spork.signature;
        self.timeSigned = spork.timeSigned;
        self.value = spork.value;
        if (sporkHash) {
            self.sporkHash = sporkHash;
        } else {
            self.sporkHash = [DSSporkHashEntity sporkHashEntityWithHash:[NSData dataWithUInt256:spork.sporkHash] onChainEntity:[spork.chain chainEntityInContext:self.managedObjectContext]];
        }

        NSAssert(self.sporkHash, @"There should be a spork hash");
    }];
}

+ (NSArray<DSSporkEntity *> *)sporksonChainEntity:(DSChainEntity *)chainEntity {
    __block NSArray *sporksOnChain;
    [chainEntity.managedObjectContext performBlockAndWait:^{
        sporksOnChain = [self objectsInContext:chainEntity.managedObjectContext matching:@"(sporkHash.chain == %@)", chainEntity];
    }];
    return sporksOnChain;
}

+ (void)deleteSporksOnChainEntity:(DSChainEntity *)chainEntity {
    [chainEntity.managedObjectContext performBlockAndWait:^{
        NSArray *sporksToDelete = [self objectsInContext:chainEntity.managedObjectContext matching:@"(sporkHash.chain == %@)", chainEntity];
        for (DSSporkEntity *sporkEntity in sporksToDelete) {
            [chainEntity.managedObjectContext deleteObject:sporkEntity];
        }
    }];
}

@end
