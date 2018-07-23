//
//  DSTransactionHashEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 7/23/18.
//
//

#import "DSTransactionHashEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSTransactionHashEntity (CoreDataProperties)

+ (NSFetchRequest<DSTransactionHashEntity *> *)fetchRequest;

@property (nonatomic) int32_t blockHeight;
@property (nonatomic) NSTimeInterval timestamp;
@property (nullable, nonatomic, retain) NSData *txHash;
@property (nullable, nonatomic, retain) DSTransactionEntity *transaction;
@property (nullable, nonatomic, retain) DSChainEntity *chain;

@end

NS_ASSUME_NONNULL_END
