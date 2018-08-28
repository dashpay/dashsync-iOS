//
//  DSBlockchainUserTopupTransactionEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 8/27/18.
//
//

#import "DSBlockchainUserTopupTransactionEntity+CoreDataClass.h"
#import "DSBlockchainUserTopupTransaction.h"
#import "DSTransactionFactory.h"
#import "NSData+Bitcoin.h"

@implementation DSBlockchainUserTopupTransactionEntity

- (instancetype)setAttributesFromTx:(DSTransaction *)tx
{
    [self.managedObjectContext performBlockAndWait:^{
        [super setAttributesFromTx:tx];
        DSBlockchainUserTopupTransaction * blockchainUserTopupTransaction = (DSBlockchainUserTopupTransaction*)tx;
        self.specialTransactionVersion = blockchainUserTopupTransaction.blockchainUserTopupTransactionVersion;
        self.registrationTransactionHash = [NSData dataWithUInt256:blockchainUserTopupTransaction.registrationTransactionHash];
    }];
    
    return self;
}

- (DSTransaction *)transactionForChain:(DSChain*)chain
{
    DSBlockchainUserTopupTransaction * transaction = (DSBlockchainUserTopupTransaction *)[super transactionForChain:chain];
    transaction.type = DSTransactionType_SubscriptionTopUp;
    [self.managedObjectContext performBlockAndWait:^{
        transaction.blockchainUserTopupTransactionVersion = self.specialTransactionVersion;
        transaction.registrationTransactionHash = self.registrationTransactionHash.UInt256;
    }];
    
    return transaction;
}

-(Class)transactionClass {
    return [DSBlockchainUserTopupTransaction class];
}


@end
