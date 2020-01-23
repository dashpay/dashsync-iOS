//
//  DSTransitionEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 12/25/19.
//
//

#import "DSTransitionEntity+CoreDataClass.h"
#import "DSTransition+Protected.h"
#import "DSBlockchainIdentityEntity+CoreDataClass.h"
#import "NSData+Bitcoin.h"
#import "NSManagedObject+Sugar.h"
#import "DSChainEntity+CoreDataClass.h"


@implementation DSTransitionEntity

- (instancetype)setAttributesFromTransition:(DSTransition *)transition
{
    [self.managedObjectContext performBlockAndWait:^{
        self.version = transition.version;
        self.type = transition.type;
        self.blockchainIdentityUniqueIdData = uint256_data(transition.blockchainIdentityUniqueId);
        DSBlockchainIdentityEntity * identity = [[DSBlockchainIdentityEntity objectsMatching:@"uniqueId == %@",self.blockchainIdentityUniqueIdData] firstObject];
        NSAssert(identity, @"Identity must exist when saving a transition.");
        self.blockchainIdentity = identity;
        self.creditFee = transition.creditFee;
        self.createdTimestamp = transition.createdTimestamp;
        self.registeredTimestamp = transition.registeredTimestamp;
        self.creditFee = transition.creditFee;
        self.signatureData = transition.signatureData;
    }];
    
    return self;
}

- (DSTransition *)transitionForChain:(DSChain*)chain
{
    
    if (!chain) chain = [self.blockchainIdentity.chain chain];
    DSTransition *transition = [[[self transitionClass] alloc] initOnChain:chain];
    
    [self.managedObjectContext performBlockAndWait:^{
        transition.transitionHash = self.transitionHashData.UInt256;
        transition.saved = TRUE;
        transition.createdTimestamp = self.createdTimestamp;
        transition.registeredTimestamp = self.registeredTimestamp;
        transition.creditFee = self.creditFee;
        transition.signatureData = self.signatureData;
    }];
    
    return transition;
}

-(UInt256)blockchainIdentityUniqueId {
    return [self.blockchainIdentityUniqueIdData UInt256];
}

-(UInt256)transitionHash {
    return [self.transitionHashData UInt256];
}

-(Class)transitionClass {
    return [DSTransition class];
}

@end
