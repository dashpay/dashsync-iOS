//
//  DSBlockchainIdentityCloseTransitionEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 12/25/19.
//
//

#import "DSBlockchainIdentityCloseTransition.h"
#import "DSBlockchainIdentityCloseTransitionEntity+CoreDataClass.h"

@implementation DSBlockchainIdentityCloseTransitionEntity

- (instancetype)setAttributesFromTransition:(DSTransition *)transition {
    [self.managedObjectContext performBlockAndWait:^{
        [super setAttributesFromTransition:transition];
        DSBlockchainIdentityCloseTransition *blockchainIdentityCloseTransition = (DSBlockchainIdentityCloseTransition *)transition;
        //TODO: add attributes here if needed
    }];

    return self;
}

- (DSTransition *)transitionForChain:(DSChain *)chain {
    DSBlockchainIdentityCloseTransition *transition = (DSBlockchainIdentityCloseTransition *)[super transitionForChain:chain];
    //    transition.type = DSTransactionType_SubscriptionCloseAccount;
    [self.managedObjectContext performBlockAndWait:^{
        //        transition.blockchainIdentityCloseTransactionVersion = self.specialTransactionVersion;
        //        transition.registrationTransactionHash = self.registrationTransactionHash.UInt256;
        //        transition.creditFee = self.creditFee;
        //        transition.payloadSignature = self.payloadSignature;
    }];

    return transition;
}

- (Class)transitionClass {
    return [DSBlockchainIdentityCloseTransition class];
}

@end
