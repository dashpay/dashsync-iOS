//
//  DSGovernanceVoteEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 6/15/18.
//
//

#import "DSChainEntity+CoreDataClass.h"
#import "DSGovernanceObject.h"
#import "DSGovernanceObjectEntity+CoreDataClass.h"
#import "DSGovernanceVote.h"
#import "DSGovernanceVoteEntity+CoreDataClass.h"
#import "DSGovernanceVoteHashEntity+CoreDataClass.h"
#import "DSSimplifiedMasternodeEntryEntity+CoreDataClass.h"
#import "NSData+Dash.h"
#import "NSManagedObject+Sugar.h"

@implementation DSGovernanceVoteEntity

- (void)setAttributesFromGovernanceVote:(DSGovernanceVote *)governanceVote forHashEntity:(DSGovernanceVoteHashEntity *)hashEntity {
    [self.managedObjectContext performBlockAndWait:^{
        self.governanceVoteHash = hashEntity;
        self.outcome = governanceVote.outcome;
        self.signal = governanceVote.signal;
        self.signature = governanceVote.signature;
        self.parentHash = [NSData dataWithUInt256:governanceVote.parentHash];
        NSData *masternodeHashData = [NSData dataWithUInt256:governanceVote.masternodeUTXO.hash];
        self.masternodeHash = masternodeHashData;
        self.masternodeIndex = (uint32_t)governanceVote.masternodeUTXO.n;
        NSArray *matchingMasternodeEntities = [DSSimplifiedMasternodeEntryEntity objectsInContext:self.managedObjectContext matching:@"utxoHash == %@ && utxoIndex == %@", masternodeHashData, @(governanceVote.masternodeUTXO.n)];
        if ([matchingMasternodeEntities count]) {
            self.masternode = [matchingMasternodeEntities firstObject];
        }
    }];
}

+ (NSUInteger)countForGovernanceObjectEntity:(DSGovernanceObjectEntity *)governanceObjectEntity {
    __block NSUInteger count = 0;
    [governanceObjectEntity.managedObjectContext performBlockAndWait:^{
        NSFetchRequest *fetchRequest = [DSGovernanceVoteEntity fetchReq];
        [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"governanceVoteHash.governanceObject = %@", governanceObjectEntity]];
        count = [DSGovernanceVoteEntity countObjects:fetchRequest inContext:governanceObjectEntity.managedObjectContext];
    }];
    return count;
}

+ (NSUInteger)countForChainEntity:(DSChainEntity *)chain {
    __block NSUInteger count = 0;
    [chain.managedObjectContext performBlockAndWait:^{
        NSFetchRequest *fetchRequest = [DSGovernanceVoteEntity fetchReq];
        [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"governanceVoteHash.chain = %@", chain]];
        count = [DSGovernanceVoteEntity countObjects:fetchRequest inContext:chain.managedObjectContext];
    }];
    return count;
}

- (DSGovernanceVote *)governanceVote {
    __block DSGovernanceVote *governanceVote = nil;

    [self.managedObjectContext performBlockAndWait:^{
        DSChainEntity *chain = [self.governanceVoteHash chain];
        UInt256 parentHash = *(UInt256 *)self.parentHash.bytes;
        DSUTXO masternodeUTXO;
        masternodeUTXO.hash = *(UInt256 *)self.masternodeHash.bytes;
        masternodeUTXO.n = self.masternodeIndex;
        governanceVote = [[DSGovernanceVote alloc] initWithParentHash:parentHash forMasternodeUTXO:masternodeUTXO voteOutcome:self.outcome voteSignal:self.signal createdAt:self.timestampCreated signature:self.signature onChain:[chain chain]];
    }];

    return governanceVote;
}

@end
