//
//  DSInstantSendLockEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 4/7/19.
//
//

#import "DSInstantSendLockEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSInstantSendLockEntity (CoreDataProperties)

+ (NSFetchRequest<DSInstantSendLockEntity *> *)fetchRequest;

@property (nonatomic) BOOL fromValidQuorum;
@property (nullable, nonatomic, retain) NSArray *inputsOutpoints;
@property (nullable, nonatomic, retain) NSData *transactionHash;
@property (nullable, nonatomic, retain) NSData *instantSendLockHash;
@property (nullable, nonatomic, retain) NSData *signature;
@property (nullable, nonatomic, retain) DSChainEntity *chain;
@property (nullable, nonatomic, retain) DSTransactionEntity *transaction;
@property (nullable, nonatomic, retain) DSSimplifiedMasternodeEntryEntity *simplifiedMasternodeEntries;

@end

NS_ASSUME_NONNULL_END
