//
//  DSBlockchainUserTopupTransactionEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 8/27/18.
//
//

#import "DSBlockchainUserTopupTransactionEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSBlockchainUserTopupTransactionEntity (CoreDataProperties)

+ (NSFetchRequest<DSBlockchainUserTopupTransactionEntity *> *)fetchRequest;

@property (nullable, nonatomic, retain) NSData *registrationTransactionHash;

@end

NS_ASSUME_NONNULL_END
