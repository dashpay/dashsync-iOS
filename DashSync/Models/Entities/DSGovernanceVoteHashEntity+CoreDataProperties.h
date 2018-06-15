//
//  DSGovernanceVoteHashEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 6/15/18.
//
//

#import "DSGovernanceVoteHashEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSGovernanceVoteHashEntity (CoreDataProperties)

+ (NSFetchRequest<DSGovernanceVoteHashEntity *> *)fetchRequest;

@property (nullable, nonatomic, retain) NSData *governanceVoteHash;
@property (nullable, nonatomic, copy) NSNumber *timestamp;
@property (nullable, nonatomic, retain) DSGovernanceVoteEntity *governanceVote;
@property (nullable, nonatomic, retain) DSChainEntity *chain;

@end

NS_ASSUME_NONNULL_END
