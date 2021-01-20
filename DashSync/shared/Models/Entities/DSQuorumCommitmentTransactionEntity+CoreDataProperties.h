//
//  DSQuorumCommitmentTransactionEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 4/25/19.
//
//

#import "DSQuorumCommitmentTransactionEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSQuorumCommitmentTransactionEntity (CoreDataProperties)

+ (NSFetchRequest<DSQuorumCommitmentTransactionEntity *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSNumber *quorumCommitmentHeight;
@property (nullable, nonatomic, retain) DSQuorumEntryEntity *entry;

@end

NS_ASSUME_NONNULL_END
