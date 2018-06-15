//
//  DSGovernanceVoteEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 6/15/18.
//
//

#import "DSGovernanceVoteEntity+CoreDataClass.h"
#import "DSGovernanceVoteHashEntity+CoreDataClass.h"
#import "NSManagedObject+Sugar.h"
#import "DSChainEntity+CoreDataClass.h"
#import "NSData+Dash.h"
#import "DSGovernanceVote.h"

@implementation DSGovernanceVoteEntity

- (void)setAttributesFromGovernanceVote:(DSGovernanceVote *)governanceVote forHashEntity:(DSGovernanceVoteHashEntity*)hashEntity {
    [self.managedObjectContext performBlockAndWait:^{
        self.governanceVoteHash = hashEntity;
        self.outcome = governanceVote.outcome;
        self.signal = governanceVote.signal;
        self.signature = governanceVote.signature;
    }];
}

+ (NSUInteger)countForChain:(DSChainEntity*)chain {
    __block NSUInteger count = 0;
    [chain.managedObjectContext performBlockAndWait:^{
        NSFetchRequest * fetchRequest = [DSGovernanceVoteEntity fetchReq];
        [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"governanceVoteHash.chain = %@",chain]];
        count = [DSGovernanceVoteEntity countObjects:fetchRequest];
    }];
    return count;
}

-(DSGovernanceVote*)governanceVote {
    __block DSGovernanceVote *governanceVote = nil;
    
    [self.managedObjectContext performBlockAndWait:^{
        DSChainEntity * chain = [self.governanceVoteHash chain];
        UInt256 governanceVoteHash = *(UInt256*)self.governanceVoteHash.governanceVoteHash.bytes;
        UInt256 parentHash = *(UInt256*)self.parentHash.bytes;
        governanceVote = [[DSGovernanceVote alloc] initWithParentHash:parentHash voteOutcome:self.outcome voteSignal:self.signal governanceVoteHash:governanceVoteHash onChain:[chain chain]];
    }];
    
    return governanceVote;
}

@end
