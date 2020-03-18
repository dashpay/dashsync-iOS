//
//  DSCreditFundingTransactionEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 12/31/19.
//
//

#import "DSCreditFundingTransactionEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSCreditFundingTransactionEntity (CoreDataProperties)

+ (NSFetchRequest<DSCreditFundingTransactionEntity *> *)fetchRequest;

@property (nullable, nonatomic, retain) DSBlockchainIdentityEntity *blockchainIdentity;

@end

NS_ASSUME_NONNULL_END
