//
//  DSBlockchainIdentityResetTransactionEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 8/29/18.
//
//

#import "DSBlockchainIdentityResetTransactionEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSBlockchainIdentityResetTransactionEntity (CoreDataProperties)

+ (NSFetchRequest<DSBlockchainIdentityResetTransactionEntity *> *)fetchRequest;

@property (assign, nonatomic) uint64_t creditFee;
@property (nullable, nonatomic, retain) NSData *oldPubKeyPayloadSignature;
@property (nullable, nonatomic, retain) NSData *previousBlockchainIdentityTransactionHash;
@property (nullable, nonatomic, retain) NSData *registrationTransactionHash;
@property (nullable, nonatomic, retain) NSData *replacementPublicKey;

@end

NS_ASSUME_NONNULL_END
