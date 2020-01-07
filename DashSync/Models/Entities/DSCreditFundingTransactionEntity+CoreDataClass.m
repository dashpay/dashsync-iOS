//
//  DSCreditFundingTransactionEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 12/31/19.
//
//

#import "DSCreditFundingTransactionEntity+CoreDataClass.h"
#import "DSCreditFundingTransaction.h"

@implementation DSCreditFundingTransactionEntity

-(Class)transactionClass {
    return [DSCreditFundingTransaction class];
}

@end
