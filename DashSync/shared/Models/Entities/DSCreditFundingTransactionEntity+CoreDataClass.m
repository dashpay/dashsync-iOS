//
//  DSCreditFundingTransactionEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 12/31/19.
//
//

#import "DSAccount.h"
#import "DSBlockchainIdentity+Protected.h"
#import "DSBlockchainIdentityEntity+CoreDataClass.h"
#import "DSCreditFundingTransaction.h"
#import "DSCreditFundingTransactionEntity+CoreDataClass.h"
#import "DSInstantSendLockEntity+CoreDataClass.h"
#import "DSTransaction+Protected.h"
#import "DSTransactionFactory.h"
#import "DSWallet.h"

@implementation DSCreditFundingTransactionEntity

- (Class)transactionClass {
    return [DSCreditFundingTransaction class];
}

- (DSTransaction *)transactionForChain:(DSChain *)chain {
    DSCreditFundingTransaction *transaction = (DSCreditFundingTransaction *)[super transactionForChain:chain];
    transaction.type = DSTransactionType_Classic;
    [self.managedObjectContext performBlockAndWait:^{
        transaction.instantSendLockAwaitingProcessing = [self.instantSendLock instantSendTransactionLockForChain:chain];
    }];

    return transaction;
}

//- (instancetype)setAttributesFromTransaction:(DSTransaction *)tx
//{
//    [self.managedObjectContext performBlockAndWait:^{
//        [super setAttributesFromTransaction:tx];
//        DSCreditFundingTransaction * creditFundingTransaction = (DSCreditFundingTransaction *)tx;
//        DSWallet * wallet = tx.account.wallet;
//        DSBlockchainIdentity * identity = [wallet blockchainIdentityForUniqueId:creditFundingTransaction.creditBurnIdentityIdentifier];
//        self.blockchainIdentity = identity.blockchainIdentityEntity;
//    }];
//
//    return self;
//}

@end
