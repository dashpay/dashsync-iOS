//
//  DSBlockchainIdentityTopupTransactionEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 8/27/18.
//
//

#import "DSBlockchainIdentityTopupTransactionEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSBlockchainIdentityTopupTransactionEntity (CoreDataProperties)

+ (NSFetchRequest<DSBlockchainIdentityTopupTransactionEntity *> *)fetchRequest;

@property (nullable, nonatomic, retain) NSData *registrationTransactionHash;

@end

NS_ASSUME_NONNULL_END
