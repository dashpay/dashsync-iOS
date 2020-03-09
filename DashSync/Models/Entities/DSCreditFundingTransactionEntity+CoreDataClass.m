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
#import "DSWallet.h"

@implementation DSCreditFundingTransactionEntity

- (Class)transactionClass {
    return [DSCreditFundingTransaction class];
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
