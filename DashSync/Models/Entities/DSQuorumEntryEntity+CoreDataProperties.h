//
//  DSQuorumEntryEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 4/25/19.
//
//

#import "DSQuorumEntryEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSQuorumEntryEntity (CoreDataProperties)

+ (NSFetchRequest<DSQuorumEntryEntity *> *)fetchRequest;

@property (nullable, nonatomic, retain) NSData *quorumHashData;
@property (nullable, nonatomic, retain) NSData *quorumPublicKeyData;
@property (nullable, nonatomic, retain) NSData *quorumThresholdSignatureData;
@property (nullable, nonatomic, retain) NSData *quorumVerificationVectorHashData;
@property (nonatomic, assign) int32_t signersCount;
@property (nullable, nonatomic, retain) NSData *allCommitmentAggregatedSignatureData;
@property (nonatomic, assign) int16_t llmqType;
@property (nonatomic, assign) int32_t membersCount;
@property (nullable, nonatomic, retain) DSQuorumCommitmentTransactionEntity *commitmentTransaction;
@property (nullable, nonatomic, retain) DSChainEntity *chain;

@end

NS_ASSUME_NONNULL_END
