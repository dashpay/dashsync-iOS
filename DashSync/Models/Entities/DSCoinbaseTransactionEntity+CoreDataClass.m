//
//  DSCoinbaseTransactionEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 2/23/19.
//
//

#import "DSCoinbaseTransactionEntity+CoreDataClass.h"
#import "DSCoinbaseTransaction.h"
#import "DSTransactionFactory.h"
#import "NSData+Bitcoin.h"

@implementation DSCoinbaseTransactionEntity

- (instancetype)setAttributesFromTransaction:(DSTransaction *)tx
{
    [self.managedObjectContext performBlockAndWait:^{
        [super setAttributesFromTransaction:tx];
        DSCoinbaseTransaction * coinbaseTransaction = (DSCoinbaseTransaction*)tx;
        self.specialTransactionVersion = coinbaseTransaction.coinbaseTransactionVersion;
        self.height = coinbaseTransaction.height;
        self.merkleRootMNList = uint256_data(coinbaseTransaction.merkleRootMNList);
    }];
    
    return self;
}

- (DSTransaction *)transactionForChain:(DSChain*)chain
{
    DSCoinbaseTransaction * transaction = (DSCoinbaseTransaction *)[super transactionForChain:chain];
    transaction.type = DSTransactionType_Coinbase;
    [self.managedObjectContext performBlockAndWait:^{
        transaction.coinbaseTransactionVersion = self.specialTransactionVersion;
        transaction.height = self.height;
        transaction.merkleRootMNList = self.merkleRootMNList.UInt256;
    }];
    
    return transaction;
}

-(Class)transactionClass {
    return [DSCoinbaseTransaction class];
}

@end
