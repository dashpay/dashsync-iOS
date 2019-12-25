//
//  DSBlockchainIdentityCloseTransitionEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 8/29/18.
//
//

#import "DSBlockchainIdentityCloseTransactionEntity+CoreDataClass.h"
#import "DSBlockchainIdentityCloseTransition.h"
#import "DSTransactionFactory.h"
#import "NSData+Bitcoin.h"

@implementation DSBlockchainIdentityCloseTransitionEntity

- (instancetype)setAttributesFromTransaction:(DSTransaction *)tx
{
    [self.managedObjectContext performBlockAndWait:^{
        [super setAttributesFromTransaction:tx];
        DSBlockchainIdentityCloseTransaction * blockchainIdentityCloseTransaction = (DSBlockchainIdentityCloseTransaction*)tx;
        self.specialTransactionVersion = blockchainIdentityCloseTransaction.blockchainIdentityCloseTransactionVersion;
        self.registrationTransactionHash = [NSData dataWithUInt256:blockchainIdentityCloseTransaction.registrationTransactionHash];
        self.creditFee = blockchainIdentityCloseTransaction.creditFee;
        self.payloadSignature = blockchainIdentityCloseTransaction.payloadSignature;
    }];
    
    return self;
}

- (DSTransaction *)transactionForChain:(DSChain*)chain
{
    DSBlockchainIdentityCloseTransition * transaction = (DSBlockchainIdentityCloseTransaction *)[super transactionForChain:chain];
    transaction.type = DSTransactionType_SubscriptionCloseAccount;
    [self.managedObjectContext performBlockAndWait:^{
        transaction.blockchainIdentityCloseTransactionVersion = self.specialTransactionVersion;
        transaction.registrationTransactionHash = self.registrationTransactionHash.UInt256;
        transaction.creditFee = self.creditFee;
        transaction.payloadSignature = self.payloadSignature;
    }];
    
    return transaction;
}

-(Class)transactionClass {
    return [DSBlockchainIdentityCloseTransition class];
}

@end
