//
//  DSProviderUpdateServiceTransactionEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 2/21/19.
//
//

#import "DSProviderUpdateServiceTransactionEntity+CoreDataClass.h"
#import "DSProviderUpdateServiceTransaction.h"
#import "DSTransactionFactory.h"
#import "NSData+Bitcoin.h"

@implementation DSProviderUpdateServiceTransactionEntity

- (instancetype)setAttributesFromTransaction:(DSTransaction *)tx
{
    [self.managedObjectContext performBlockAndWait:^{
        [super setAttributesFromTransaction:tx];
        DSProviderUpdateServiceTransaction * providerUpdateServiceTransaction = (DSProviderUpdateServiceTransaction*)tx;
        self.specialTransactionVersion = providerUpdateServiceTransaction.providerUpdateServiceTransactionVersion;
        self.ipAddress = uint128_data(providerUpdateServiceTransaction.ipAddress);
        self.port = providerUpdateServiceTransaction.port;
        self.scriptPayout = providerUpdateServiceTransaction.scriptPayout;
        self.payloadSignature = providerUpdateServiceTransaction.payloadSignature;
    }];
    
    return self;
}

- (DSTransaction *)transactionForChain:(DSChain*)chain
{
    DSProviderUpdateServiceTransaction * transaction = (DSProviderUpdateServiceTransaction *)[super transactionForChain:chain];
    transaction.type = DSTransactionType_ProviderUpdateService;
    [self.managedObjectContext performBlockAndWait:^{
        transaction.providerUpdateServiceTransactionVersion = self.specialTransactionVersion;
        transaction.ipAddress = self.ipAddress.UInt128;
        transaction.port = self.port;
        transaction.scriptPayout = self.scriptPayout;
        transaction.payloadSignature = self.payloadSignature;
    }];
    
    return transaction;
}

-(Class)transactionClass {
    return [DSProviderUpdateServiceTransaction class];
}

@end
