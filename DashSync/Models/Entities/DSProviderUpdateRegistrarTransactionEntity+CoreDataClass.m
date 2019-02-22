//
//  DSProviderUpdateRegistrarTransactionEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 2/22/19.
//
//

#import "DSProviderUpdateRegistrarTransactionEntity+CoreDataClass.h"
#import "DSProviderUpdateRegistrarTransaction.h"
#import "DSTransactionFactory.h"
#import "NSData+Bitcoin.h"

@implementation DSProviderUpdateRegistrarTransactionEntity

- (instancetype)setAttributesFromTransaction:(DSTransaction *)tx
{
    [self.managedObjectContext performBlockAndWait:^{
        [super setAttributesFromTransaction:tx];
        DSProviderUpdateRegistrarTransaction * providerUpdateRegistrarTransaction = (DSProviderUpdateRegistrarTransaction*)tx;
        self.specialTransactionVersion = providerUpdateRegistrarTransaction.providerUpdateRegistrarTransactionVersion;
        self.providerMode = providerUpdateRegistrarTransaction.providerMode;
        self.operatorKey = [NSData dataWithUInt384:providerUpdateRegistrarTransaction.operatorKey];
        self.scriptPayout = providerUpdateRegistrarTransaction.scriptPayout;
        self.payloadSignature = providerUpdateRegistrarTransaction.payloadSignature;
        self.votingKeyHash = [NSData dataWithUInt160:providerUpdateRegistrarTransaction.votingKeyHash];
    }];
    
    return self;
}

- (DSTransaction *)transactionForChain:(DSChain*)chain
{
    DSProviderUpdateRegistrarTransaction * transaction = (DSProviderUpdateRegistrarTransaction *)[super transactionForChain:chain];
    transaction.type = DSTransactionType_ProviderUpdateRegistrar;
    [self.managedObjectContext performBlockAndWait:^{
        transaction.providerUpdateRegistrarTransactionVersion = self.specialTransactionVersion;
        transaction.providerMode = self.providerMode;
        transaction.operatorKey = self.operatorKey.UInt384;
        transaction.scriptPayout = self.scriptPayout;
        transaction.payloadSignature = self.payloadSignature;
        transaction.votingKeyHash = self.votingKeyHash.UInt160;
    }];
    
    return transaction;
}

-(Class)transactionClass {
    return [DSProviderUpdateRegistrarTransaction class];
}

@end
