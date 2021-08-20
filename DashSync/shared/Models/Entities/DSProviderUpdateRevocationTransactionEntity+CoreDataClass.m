//
//  DSProviderUpdateRevocationTransactionEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 2/26/19.
//
//

#import "DSProviderUpdateRevocationTransaction.h"
#import "DSProviderUpdateRevocationTransactionEntity+CoreDataClass.h"
#import "DSTransactionFactory.h"
#import "NSData+Dash.h"

@implementation DSProviderUpdateRevocationTransactionEntity

- (instancetype)setAttributesFromTransaction:(DSTransaction *)tx {
    [self.managedObjectContext performBlockAndWait:^{
        [super setAttributesFromTransaction:tx];
        DSProviderUpdateRevocationTransaction *providerUpdateRevocationTransaction = (DSProviderUpdateRevocationTransaction *)tx;
        self.specialTransactionVersion = providerUpdateRevocationTransaction.providerUpdateRevocationTransactionVersion;
        self.reason = providerUpdateRevocationTransaction.reason;
        self.payloadSignature = providerUpdateRevocationTransaction.payloadSignature;
        self.providerRegistrationTransactionHash = [NSData dataWithUInt256:providerUpdateRevocationTransaction.providerRegistrationTransactionHash];
    }];

    return self;
}

- (DSTransaction *)transactionForChain:(DSChain *)chain {
    DSProviderUpdateRevocationTransaction *transaction = (DSProviderUpdateRevocationTransaction *)[super transactionForChain:chain];
    transaction.type = DSTransactionType_ProviderUpdateRevocation;
    [self.managedObjectContext performBlockAndWait:^{
        transaction.providerUpdateRevocationTransactionVersion = self.specialTransactionVersion;
        transaction.providerRegistrationTransactionHash = self.providerRegistrationTransactionHash.UInt256;
        transaction.reason = self.reason;
        transaction.payloadSignature = self.payloadSignature;
    }];

    return transaction;
}

- (Class)transactionClass {
    return [DSProviderUpdateRevocationTransaction class];
}

@end
