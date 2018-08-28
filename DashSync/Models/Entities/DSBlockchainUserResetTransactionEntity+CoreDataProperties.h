//
//  DSBlockchainUserResetTransactionEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 8/29/18.
//
//

#import "DSBlockchainUserResetTransactionEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSBlockchainUserResetTransactionEntity (CoreDataProperties)

+ (NSFetchRequest<DSBlockchainUserResetTransactionEntity *> *)fetchRequest;

@property (assign, nonatomic) uint64_t creditFee;
@property (nullable, nonatomic, retain) NSData *oldPubKeyPayloadSignature;
@property (nullable, nonatomic, retain) NSData *previousBlockchainUserTransactionHash;
@property (nullable, nonatomic, retain) NSData *registrationTransactionHash;
@property (nullable, nonatomic, retain) NSData *replacementPublicKey;

@end

NS_ASSUME_NONNULL_END
