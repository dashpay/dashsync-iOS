//
//  DSQuorumCommitmentTransactionEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 4/24/19.
//
//

#import "DSQuorumCommitmentTransactionEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSQuorumCommitmentTransactionEntity (CoreDataProperties)

+ (NSFetchRequest<DSQuorumCommitmentTransactionEntity *> *)fetchRequest;

@property (nonatomic) int32_t quorumCommitmentHeight;
@property (nonatomic) int16_t llmqType;
@property (nullable, nonatomic, retain) NSData *quorumHash;
@property (nonatomic) int16_t signersCount;
@property (nonatomic) int16_t membersCount;
@property (nullable, nonatomic, retain) NSData *quorumPublicKey;
@property (nullable, nonatomic, retain) NSData *quorumVerificationVectorHash;
@property (nullable, nonatomic, retain) NSData *quorumThresholdSignature;
@property (nullable, nonatomic, retain) NSData *allCommitmentAggregatedSignature;

@end

NS_ASSUME_NONNULL_END
