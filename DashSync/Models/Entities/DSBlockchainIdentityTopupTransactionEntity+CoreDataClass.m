//
//  DSBlockchainIdentityTopupTransactionEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 8/27/18.
//
//

#import "DSBlockchainIdentityTopupTransactionEntity+CoreDataClass.h"
#import "DSBlockchainIdentityTopupTransaction.h"
#import "DSTransactionFactory.h"
#import "NSData+Bitcoin.h"

@implementation DSBlockchainIdentityTopupTransactionEntity

- (instancetype)setAttributesFromTransaction:(DSTransaction *)tx
{
    [self.managedObjectContext performBlockAndWait:^{
        [super setAttributesFromTransaction:tx];
        DSBlockchainIdentityTopupTransaction * blockchainIdentityTopupTransaction = (DSBlockchainIdentityTopupTransaction*)tx;
        self.specialTransactionVersion = blockchainIdentityTopupTransaction.blockchainIdentityTopupTransactionVersion;
        self.registrationTransactionHash = [NSData dataWithUInt256:blockchainIdentityTopupTransaction.registrationTransactionHash];
    }];
    
    return self;
}

- (DSTransaction *)transactionForChain:(DSChain*)chain
{
    DSBlockchainIdentityTopupTransaction * transaction = (DSBlockchainIdentityTopupTransaction *)[super transactionForChain:chain];
    transaction.type = DSTransactionType_SubscriptionTopUp;
    [self.managedObjectContext performBlockAndWait:^{
        transaction.blockchainIdentityTopupTransactionVersion = self.specialTransactionVersion;
        transaction.registrationTransactionHash = self.registrationTransactionHash.UInt256;
    }];
    
    return transaction;
}

-(Class)transactionClass {
    return [DSBlockchainIdentityTopupTransaction class];
}


@end
