//
//  DSTransitionEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 3/14/19.
//
//

#import "DSTransitionEntity+CoreDataClass.h"
#import "DSTransition.h"
#import "DSTransactionFactory.h"
#import "NSData+Bitcoin.h"

@implementation DSTransitionEntity

- (instancetype)setAttributesFromTransaction:(DSTransaction *)tx
{
    [self.managedObjectContext performBlockAndWait:^{
        [super setAttributesFromTransaction:tx];
        DSTransition * transition = (DSTransition*)tx;
        self.specialTransactionVersion = transition.transitionVersion;
        self.registrationTransactionHash = [NSData dataWithUInt256:transition.registrationTransactionHash];
        self.creditFee = transition.creditFee;
        self.payloadSignature = transition.payloadSignature;
    }];
    
    return self;
}

- (DSTransaction *)transactionForChain:(DSChain*)chain
{
    DSTransition * transaction = (DSTransition *)[super transactionForChain:chain];
    transaction.type = DSTransactionType_Transition;
    [self.managedObjectContext performBlockAndWait:^{
        transaction.transitionVersion = self.specialTransactionVersion;
        transaction.registrationTransactionHash = self.registrationTransactionHash.UInt256;
        transaction.creditFee = self.creditFee;
        transaction.payloadSignature = self.payloadSignature;
    }];
    
    return transaction;
}

-(Class)transactionClass {
    return [DSTransition class];
}

@end
