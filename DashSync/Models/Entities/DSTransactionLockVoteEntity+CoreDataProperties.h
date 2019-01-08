//
//  DSTransactionLockVoteEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 1/9/19.
//
//

#import "DSTransactionLockVoteEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSTransactionLockVoteEntity (CoreDataProperties)

+ (NSFetchRequest<DSTransactionLockVoteEntity *> *)fetchRequest;

@property (nullable, nonatomic, retain) NSData *transactionLockVoteHash;
@property (nonatomic, assign) BOOL fromValidQuorum;
@property (nonatomic, assign) BOOL signatureIsValid;
@property (nullable, nonatomic, retain) NSData *blockHash;
@property (nullable, nonatomic, retain) NSData *inputHash;
@property (nonatomic, assign) uint32_t inputIndex;
@property (nullable, nonatomic, retain) NSData *transactionHash;
@property (nullable, nonatomic, retain) NSData *masternodeOutpointHash;
@property (nonatomic, assign) uint32_t masternodeOutpointIndex;
@property (nullable, nonatomic, retain) NSData *masternodeProviderTransactionHash;
@property (nullable, nonatomic, retain) DSSimplifiedMasternodeEntryEntity *simplifiedMasternodeEntry;
@property (nullable, nonatomic, retain) DSTransactionEntity *transaction;
@property (nullable, nonatomic, retain) DSChainEntity *chain;
@property (nullable, nonatomic, retain) NSData *quorumModifierHash;

@end

NS_ASSUME_NONNULL_END
