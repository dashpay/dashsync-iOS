//
//  DSTransitionEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 3/14/19.
//
//

#import "DSTransitionEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSTransitionEntity (CoreDataProperties)

+ (NSFetchRequest<DSTransitionEntity *> *)fetchRequest;

@property (nullable, nonatomic, retain) NSData *previousSubcriptionHash;
@property (nonatomic, assign) uint64_t creditFee;
@property (nullable, nonatomic, retain) NSData *packetHash;
@property (nullable, nonatomic, retain) NSData *payloadSignature;
@property (nullable, nonatomic, retain) NSData *registrationTransactionHash;
@property (nullable, nonatomic, retain) DSBlockchainIdentityRegistrationTransactionEntity *blockchainIdentityRegistrationTransaction;

@end

NS_ASSUME_NONNULL_END
