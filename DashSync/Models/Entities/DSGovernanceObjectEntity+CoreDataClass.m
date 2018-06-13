//
//  DSGovernanceObjectEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 6/14/18.
//
//

#import "DSGovernanceObjectEntity+CoreDataClass.h"
#import "DSGovernanceObjectHashEntity+CoreDataClass.h"
#import "NSManagedObject+Sugar.h"
#import "DSChainEntity+CoreDataClass.h"
#import "NSData+Dash.h"

@implementation DSGovernanceObjectEntity

- (void)setAttributesFromGovernanceObject:(DSGovernanceObject *)governanceObject forHashEntity:(DSGovernanceObjectHashEntity*)hashEntity {
    [self.managedObjectContext performBlockAndWait:^{
        self.collateralHash = governanceObject.collateralHash;
        self.parentHash = governanceObject.parentHash;
        self.revision = governanceObject.revision;
        self.signature = governanceObject.signature;
        self.timestamp = governanceObject.timestamp;
        self.type = governanceObject.type;
        self.governanceObjectHash = hashEntity;
    }];
}

+ (NSUInteger)countForChain:(DSChainEntity*)chain {
    __block NSUInteger count = 0;
    [chain.managedObjectContext performBlockAndWait:^{
        NSFetchRequest * fetchRequest = [DSGovernanceObjectEntity fetchReq];
        [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"governanceObjectHash.chain = %@",chain]];
        count = [DSGovernanceObjectEntity countObjects:fetchRequest];
    }];
    return count;
}


@end
