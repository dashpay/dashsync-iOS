//
//  DSGovernanceVoteEntity+CoreDataProperties.h
//  DashSync
//
//  Created by Sam Westrich on 6/15/18.
//
//

#import "DSGovernanceVoteEntity+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface DSGovernanceVoteEntity (CoreDataProperties)

+ (NSFetchRequest<DSGovernanceVoteEntity *> *)fetchRequest;

@property (nonatomic, assign) uint32_t outcome;
@property (nonatomic, assign) uint32_t signal;
@property (nonatomic, assign) uint64_t timestampCreated;
@property (nullable, nonatomic, retain) NSData *signature;
@property (nullable, nonatomic, retain) NSData *masternodeUTXO;
@property (nullable, nonatomic, retain) DSGovernanceVoteHashEntity *governanceVoteHash;
@property (nullable, nonatomic, retain) DSGovernanceObjectEntity *governanceObject;
@property (nullable, nonatomic, retain) DSMasternodeBroadcastEntity *masternode;

@end

NS_ASSUME_NONNULL_END
