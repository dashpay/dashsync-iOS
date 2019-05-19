//
//  DSQuorumEntryEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 4/25/19.
//
//

#import "DSQuorumEntryEntity+CoreDataClass.h"
#import "DSQuorumEntry.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSQuorumEntryEntity (CoreDataProperties)

+ (NSFetchRequest<DSQuorumEntryEntity *> *)fetchRequest;

@property (nullable, nonatomic, retain) NSData *quorumHashData;
@property (nullable, nonatomic, retain) NSData *quorumPublicKeyData;
@property (nullable, nonatomic, retain) NSData *quorumThresholdSignatureData;
@property (nullable, nonatomic, retain) NSData *quorumVerificationVectorHashData;
@property (nonatomic, assign) int32_t signersCount;
@property (nonatomic, assign) BOOL verified;
@property (nullable, nonatomic, retain) NSData *allCommitmentAggregatedSignatureData;
@property (nonatomic, assign) DSLLMQType llmqType;
@property (nonatomic, assign) int16_t version;
@property (nonatomic, assign) int32_t validMembersCount;
@property (nullable, nonatomic, retain) NSData * signersBitset;
@property (nullable, nonatomic, retain) NSData * validMembersBitset;
@property (nullable, nonatomic, retain) DSQuorumCommitmentTransactionEntity *commitmentTransaction;
@property (nullable, nonatomic, retain) DSChainEntity *chain;
@property (nullable, nonatomic, retain) NSData *commitmentHashData;
@property (nonatomic, retain) DSMerkleBlockEntity * block;

@end

NS_ASSUME_NONNULL_END
