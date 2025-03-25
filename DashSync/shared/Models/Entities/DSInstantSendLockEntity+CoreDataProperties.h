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
@property (nullable, nonatomic, retain) NSData *cycleHash;
@property (assign, nonatomic) uint8_t version;
@property (assign, nonatomic) BOOL validSignature;
@property (nullable, nonatomic, retain) DSTransactionEntity *transaction;

@end

NS_ASSUME_NONNULL_END
