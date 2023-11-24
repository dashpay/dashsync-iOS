//
//  DSCoinbaseTransactionEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 2/23/19.
//
//

#import "DSCoinbaseTransactionEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSCoinbaseTransactionEntity (CoreDataProperties)

+ (NSFetchRequest<DSCoinbaseTransactionEntity *> *)fetchRequest;

@property (assign, nonatomic) uint32_t height;

@property (nullable, nonatomic, retain) NSData *merkleRootMNList;
@property (nullable, nonatomic, retain) NSData *merkleRootLLMQList;

@property (assign, nonatomic) uint32_t bestCLHeightDiff;
@property (nullable, nonatomic, retain) NSData *bestCLSignature;
@property (assign, nonatomic) int64_t creditPoolBalance;

@end

NS_ASSUME_NONNULL_END
