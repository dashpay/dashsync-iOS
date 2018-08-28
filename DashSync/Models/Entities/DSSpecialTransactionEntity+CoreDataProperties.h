//
//  DSSpecialTransactionEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 8/27/18.
//
//

#import "DSSpecialTransactionEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSSpecialTransactionEntity (CoreDataProperties)

+ (NSFetchRequest<DSSpecialTransactionEntity *> *)fetchRequest;

@property (nonatomic, assign) uint16_t specialTransactionVersion;

@end

NS_ASSUME_NONNULL_END
