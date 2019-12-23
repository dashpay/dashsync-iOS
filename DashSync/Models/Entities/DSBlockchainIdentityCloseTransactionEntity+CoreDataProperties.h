//
//  DSBlockchainIdentityCloseTransactionEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 8/29/18.
//
//

#import "DSBlockchainIdentityCloseTransactionEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSBlockchainIdentityCloseTransactionEntity (CoreDataProperties)

+ (NSFetchRequest<DSBlockchainIdentityCloseTransactionEntity *> *)fetchRequest;

@property (assign, nonatomic) uint64_t creditFee;
@property (nullable, nonatomic, retain) NSData *previousBlockchainIdentityTransactionHash;
@property (nullable, nonatomic, retain) NSData *registrationTransactionHash;
@property (nullable, nonatomic, retain) NSData *payloadSignature;

@end

NS_ASSUME_NONNULL_END
