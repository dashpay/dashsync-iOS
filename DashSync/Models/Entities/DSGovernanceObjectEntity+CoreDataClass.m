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
        self.collateralHash = [NSData dataWithUInt256:governanceObject.collateralHash];
        self.parentHash = [NSData dataWithUInt256:governanceObject.parentHash];
        self.revision = governanceObject.revision;
        self.signature = governanceObject.signature;
        self.timestamp = governanceObject.timestamp;
        self.governanceMessage = governanceObject.governanceMessage;
        self.type = governanceObject.type;
        self.governanceObjectHash = hashEntity;
        self.identifier = governanceObject.identifier;
        self.amount = governanceObject.amount;
        self.startEpoch = governanceObject.startEpoch;
        self.endEpoch = governanceObject.endEpoch;
        self.url = governanceObject.url;
        self.paymentAddress = governanceObject.paymentAddress;
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
