//
//  DSBlockchainUserCloseTransactionEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 8/29/18.
//
//

#import "DSBlockchainUserCloseTransactionEntity+CoreDataClass.h"
#import "DSBlockchainUserCloseTransaction.h"
#import "DSTransactionFactory.h"
#import "NSData+Bitcoin.h"

@implementation DSBlockchainUserCloseTransactionEntity

- (instancetype)setAttributesFromTx:(DSTransaction *)tx
{
    [self.managedObjectContext performBlockAndWait:^{
        [super setAttributesFromTx:tx];
        DSBlockchainUserCloseTransaction * blockchainUserCloseTransaction = (DSBlockchainUserCloseTransaction*)tx;
        self.specialTransactionVersion = blockchainUserCloseTransaction.blockchainUserCloseTransactionVersion;
        self.registrationTransactionHash = [NSData dataWithUInt256:blockchainUserCloseTransaction.registrationTransactionHash];
        self.creditFee = blockchainUserCloseTransaction.creditFee;
        self.payloadSignature = blockchainUserCloseTransaction.payloadSignature;
    }];
    
    return self;
}

- (DSTransaction *)transactionForChain:(DSChain*)chain
{
    DSBlockchainUserCloseTransaction * transaction = (DSBlockchainUserCloseTransaction *)[super transactionForChain:chain];
    transaction.type = DSTransactionType_SubscriptionTopUp;
    [self.managedObjectContext performBlockAndWait:^{
        transaction.blockchainUserCloseTransactionVersion = self.specialTransactionVersion;
        transaction.registrationTransactionHash = self.registrationTransactionHash.UInt256;
        transaction.creditFee = self.creditFee;
        transaction.payloadSignature = self.payloadSignature;
    }];
    
    return transaction;
}

-(Class)transactionClass {
    return [DSBlockchainUserCloseTransaction class];
}

@end
