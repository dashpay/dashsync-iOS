//
//  DSInstantSendLockEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 5/19/19.
//
//

#import "DSInstantSendLockEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSInstantSendLockEntity (CoreDataProperties)

+ (NSFetchRequest<DSInstantSendLockEntity *> *)fetchRequest;

@property (nullable, nonatomic, retain) NSData *signature;
@property (assign, nonatomic) BOOL validSignature;
@property (nullable, nonatomic, retain) DSTransactionEntity *transaction;
@property (nullable, nonatomic, retain) DSQuorumEntryEntity *quorum;

@end

NS_ASSUME_NONNULL_END
