//
//  DSQuorumEntryEntity+CoreDataProperties.h
//  Dash-PLCrashReporter
//
//  Created by Sam Westrich on 6/14/19.
//
//

//#import "DSQuorumEntry.h"
#import "DSQuorumEntryEntity+CoreDataClass.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSQuorumEntryEntity (CoreDataProperties)

+ (NSFetchRequest<DSQuorumEntryEntity *> *)fetchRequest;

@property (nonatomic, assign) int16_t llmqType;
@property (nonatomic, assign) int16_t version;
@property (nonatomic, assign) int32_t validMembersCount;
@property (nonatomic, assign) int32_t signersCount;
@property (nonatomic, assign) int32_t quorumIndex;
@property (nonatomic, assign) BOOL verified;
@property (nullable, nonatomic, retain) NSData *allCommitmentAggregatedSignatureData;
@property (nullable, nonatomic, retain) NSData *commitmentHashData;
@property (nullable, nonatomic, retain) NSData *quorumHashData;
@property (nullable, nonatomic, retain) NSData *quorumPublicKeyData;
@property (nullable, nonatomic, retain) NSData *quorumThresholdSignatureData;
@property (nullable, nonatomic, retain) NSData *quorumVerificationVectorHashData;
@property (nullable, nonatomic, retain) NSData *signersBitset;
@property (nullable, nonatomic, retain) NSData *validMembersBitset;
@property (nullable, nonatomic, retain) DSMerkleBlockEntity *block;
@property (nullable, nonatomic, retain) DSChainEntity *chain;
@property (nullable, nonatomic, retain) DSQuorumCommitmentTransactionEntity *commitmentTransaction;
@property (nullable, nonatomic, retain) NSSet<DSInstantSendLockEntity *> *instantSendLocks;
@property (nullable, nonatomic, retain) NSSet<DSChainLockEntity *> *chainLocks;
@property (nullable, nonatomic, retain) NSSet<DSMasternodeListEntity *> *referencedByMasternodeLists;

@end

@interface DSQuorumEntryEntity (CoreDataGeneratedAccessors)

- (void)addInstantSendLocksObject:(DSInstantSendLockEntity *)value;
- (void)removeInstantSendLocksObject:(DSInstantSendLockEntity *)value;
- (void)addInstantSendLocks:(NSSet<DSInstantSendLockEntity *> *)values;
- (void)removeInstantSendLocks:(NSSet<DSInstantSendLockEntity *> *)values;

- (void)addChainLocksObject:(DSChainLockEntity *)value;
- (void)removeChainLocksObject:(DSChainLockEntity *)value;
- (void)addChainLocks:(NSSet<DSChainLockEntity *> *)values;
- (void)removeChainLocks:(NSSet<DSChainLockEntity *> *)values;

- (void)addUsedByMasternodeListsObject:(DSMasternodeListEntity *)value;
- (void)removeUsedByMasternodeListsObject:(DSMasternodeListEntity *)value;
- (void)addUsedByMasternodeLists:(NSSet<DSMasternodeListEntity *> *)values;
- (void)removeUsedByMasternodeLists:(NSSet<DSMasternodeListEntity *> *)values;

@end

NS_ASSUME_NONNULL_END
