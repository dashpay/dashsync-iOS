//
//  DSCreditFundingTransactionEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 12/31/19.
//
//

#import "DSCreditFundingTransactionEntity+CoreDataProperties.h"

@implementation DSCreditFundingTransactionEntity (CoreDataProperties)

+ (NSFetchRequest<DSCreditFundingTransactionEntity *> *)fetchRequest {
    return [NSFetchRequest fetchRequestWithEntityName:@"DSCreditFundingTransactionEntity"];
}

@dynamic blockchainIdentity;

@end
