//
//  DSBlockchainUserCloseTransactionEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 8/29/18.
//
//

#import "DSBlockchainUserCloseTransactionEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSBlockchainUserCloseTransactionEntity (CoreDataProperties)

+ (NSFetchRequest<DSBlockchainUserCloseTransactionEntity *> *)fetchRequest;

@property (assign, nonatomic) uint64_t creditFee;
@property (nullable, nonatomic, retain) NSData *previousBlockchainUserTransactionHash;
@property (nullable, nonatomic, retain) NSData *registrationTransactionHash;
@property (nullable, nonatomic, retain) NSData *payloadSignature;

@end

NS_ASSUME_NONNULL_END
