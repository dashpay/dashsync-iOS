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

-(DSGovernanceObject*)governanceObject {
    __block DSGovernanceObject *governanceObject = nil;
    
    [self.managedObjectContext performBlockAndWait:^{
        DSChainEntity * chain = [self.governanceObjectHash chain];
        UInt256 governanceObjectHash = *(UInt256*)self.governanceObjectHash.governanceObjectHash.bytes;
        UInt256 parentHash = *(UInt256*)self.parentHash.bytes;
        UInt256 collateralHash = *(UInt256*)self.collateralHash.bytes;
        governanceObject = [[DSGovernanceObject alloc] initWithType:self.type governanceMessage:self.governanceMessage parentHash:parentHash revision:self.revision timestamp:self.timestamp signature:self.signature collateralHash:collateralHash governanceObjectHash:governanceObjectHash identifier:self.identifier amount:self.amount startEpoch:self.startEpoch endEpoch:self.endEpoch paymentAddress:self.paymentAddress url:self.url onChain:[chain chain]];
    }];
    
    return governanceObject;
}


@end
