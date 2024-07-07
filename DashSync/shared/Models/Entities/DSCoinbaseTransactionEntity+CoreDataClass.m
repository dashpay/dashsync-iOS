//
//  DSCoinbaseTransactionEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 2/23/19.
//
//

#import "DSCoinbaseTransaction.h"
#import "DSCoinbaseTransactionEntity+CoreDataClass.h"
#import "DSTransactionFactory.h"
#import "NSData+Dash.h"

@implementation DSCoinbaseTransactionEntity

- (instancetype)setAttributesFromTransaction:(DSTransaction *)tx {
    [self.managedObjectContext performBlockAndWait:^{
        [super setAttributesFromTransaction:tx];
        DSCoinbaseTransaction *coinbaseTransaction = (DSCoinbaseTransaction *)tx;
        self.specialTransactionVersion = coinbaseTransaction.coinbaseTransactionVersion;
        self.height = coinbaseTransaction.height;
        self.merkleRootMNList = uint256_data(coinbaseTransaction.merkleRootMNList);
        if (self.specialTransactionVersion >= COINBASE_TX_CORE_19) {
            self.merkleRootLLMQList = uint256_data(coinbaseTransaction.merkleRootLLMQList);
            if (self.specialTransactionVersion >= COINBASE_TX_CORE_20) {
                self.bestCLHeightDiff = (uint32_t) coinbaseTransaction.bestCLHeightDiff;
                self.bestCLSignature = uint768_data(coinbaseTransaction.bestCLSignature);
                self.creditPoolBalance = coinbaseTransaction.creditPoolBalance;
            }
        }
    }];

    return self;
}

- (DSTransaction *)transactionForChain:(DSChain *)chain {
    DSCoinbaseTransaction *transaction = (DSCoinbaseTransaction *)[super transactionForChain:chain];
    transaction.type = DSTransactionType_Coinbase;
    [self.managedObjectContext performBlockAndWait:^{
        transaction.coinbaseTransactionVersion = self.specialTransactionVersion;
        transaction.height = self.height;
        transaction.merkleRootMNList = self.merkleRootMNList.UInt256;
        
        if (self.specialTransactionVersion >= COINBASE_TX_CORE_19) {
            transaction.merkleRootLLMQList = self.merkleRootLLMQList.UInt256;
            if (self.specialTransactionVersion >= COINBASE_TX_CORE_20) {
                transaction.bestCLHeightDiff = self.bestCLHeightDiff;
                transaction.bestCLSignature = self.bestCLSignature.UInt768;
                transaction.creditPoolBalance = self.creditPoolBalance;
            }
        }
    }];

    return transaction;
}



- (Class)transactionClass {
    return [DSCoinbaseTransaction class];
}

@end
