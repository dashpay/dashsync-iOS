//
//  DSGovernanceVoteEntity+CoreDataClass.h
//  DashSync
//
//  Created by Sam Westrich on 6/15/18.
//
//

#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

@class DSGovernanceObjectEntity, DSGovernanceVoteHashEntity, DSSimplifiedMasternodeEntry, DSChainEntity, DSGovernanceVote;

NS_ASSUME_NONNULL_BEGIN

@interface DSGovernanceVoteEntity : NSManagedObject

- (void)setAttributesFromGovernanceVote:(DSGovernanceVote *)governanceVote forHashEntity:(DSGovernanceVoteHashEntity *)hashEntity;
+ (NSUInteger)countForChainEntity:(DSChainEntity *_Nonnull)chain;
+ (NSUInteger)countForGovernanceObjectEntity:(DSGovernanceObjectEntity *)governanceObject;
- (DSGovernanceVote *)governanceVote;

@end

NS_ASSUME_NONNULL_END

#import "DSGovernanceVoteEntity+CoreDataProperties.h"
