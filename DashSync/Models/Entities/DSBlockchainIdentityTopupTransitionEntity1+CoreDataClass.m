//
//  DSBlockchainIdentityTopupTransitionEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 8/27/18.
//
//

#import "DSBlockchainIdentityTopupTransitionEntity+CoreDataClass.h"
#import "DSBlockchainIdentityTopupTransition.h"
#import "DSTransactionFactory.h"
#import "NSData+Bitcoin.h"

@implementation DSBlockchainIdentityTopupTransitionEntity

- (instancetype)setAttributesFromTransaction:(DSTransaction *)tx
{
    [self.managedObjectContext performBlockAndWait:^{
        [super setAttributesFromTransaction:tx];
        DSBlockchainIdentityTopupTransition * blockchainIdentityTopupTransaction = (DSBlockchainIdentityTopupTransition*)tx;
        self.specialTransactionVersion = blockchainIdentityTopupTransaction.blockchainIdentityTopupTransactionVersion;
        self.registrationTransactionHash = [NSData dataWithUInt256:blockchainIdentityTopupTransaction.registrationTransactionHash];
    }];
    
    return self;
}

- (DSTransaction *)transactionForChain:(DSChain*)chain
{
    DSBlockchainIdentityTopupTransition * transaction = (DSBlockchainIdentityTopupTransition *)[super transactionForChain:chain];
    transaction.type = DSTransactionType_SubscriptionTopUp;
    [self.managedObjectContext performBlockAndWait:^{
        transaction.blockchainIdentityTopupTransactionVersion = self.specialTransactionVersion;
        transaction.registrationTransactionHash = self.registrationTransactionHash.UInt256;
    }];
    
    return transaction;
}

-(Class)transactionClass {
    return [DSBlockchainIdentityTopupTransition class];
}


@end
