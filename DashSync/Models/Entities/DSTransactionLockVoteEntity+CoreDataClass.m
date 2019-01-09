//
//  DSTransactionLockVoteEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 1/9/19.
//
//

#import "DSTransactionLockVoteEntity+CoreDataClass.h"
#import "DSTransactionLockVote.h"
#import "BigIntTypes.h"
#import "NSMutableData+Dash.h"
#import "NSData+Bitcoin.h"
#import "DSSimplifiedMasternodeEntry.h"
#import "DSTransactionEntity+CoreDataClass.h"
#import "NSManagedObject+Sugar.h"
#import "DSChainEntity+CoreDataClass.h"

@implementation DSTransactionLockVoteEntity

- (instancetype)setAttributesFromTransactionLockVote:(DSTransactionLockVote *)transactionLockVote
{
    [self.managedObjectContext performBlockAndWait:^{
        self.transactionHash = uint256_data(transactionLockVote.transactionHash);
        self.quorumModifierHash = uint256_data(transactionLockVote.quorumModifierHash);
        self.transactionLockVoteHash = uint256_data(transactionLockVote.transactionLockVoteHash);
        self.fromValidQuorum = transactionLockVote.quorumVerified;
        self.signatureIsValid = transactionLockVote.signatureVerified;
        self.blockHash = uint256_data(transactionLockVote.quorumVerifiedAtBlockHash);
        self.simplifiedMasternodeEntry = transactionLockVote.masternode.simplifiedMasternodeEntryEntity;
        self.chain = transactionLockVote.chain.chainEntity;
        DSTransactionEntity * transactionEntity = [DSTransactionEntity anyObjectMatching:@"transactionHash.txHash == %@", uint256_data(transactionLockVote.transactionHash)];
        self.transaction = transactionEntity;
        self.masternodeProviderTransactionHash = uint256_data(transactionLockVote.masternodeProviderTransactionHash);
        self.masternodeOutpointHash = uint256_data(transactionLockVote.masternodeOutpoint.hash);
        self.masternodeOutpointIndex = (uint32_t)transactionLockVote.masternodeOutpoint.n;
        self.inputIndex = (uint32_t)transactionLockVote.transactionOutpoint.n;
        self.inputHash = uint256_data(transactionLockVote.transactionOutpoint.hash);
    }];
    
    return self;
}

- (DSTransactionLockVote *)transactionLockVoteForChain:(DSChain*)chain
{
    if (!chain) chain = [self.chain chain];
    DSUTXO input;
    input.hash = self.inputHash.UInt256;
    input.n = self.inputIndex;
    DSUTXO masternodeOutpoint;
    masternodeOutpoint.hash = self.masternodeOutpointHash.UInt256;
    masternodeOutpoint.n = self.masternodeOutpointIndex;
    
    DSTransactionLockVote * transactionLockVote = [[DSTransactionLockVote alloc] initWithTransactionHash:self.transactionHash.UInt256 transactionOutpoint:input masternodeOutpoint:masternodeOutpoint masternodeProviderTransactionHash:self.masternodeProviderTransactionHash.UInt256 quorumModifierHash:self.quorumModifierHash.UInt256 quorumVerifiedAtBlockHash:self.blockHash.UInt256 signatureVerified:self.signatureIsValid quorumVerified:self.fromValidQuorum onChain:chain];
    
    return transactionLockVote;
}

@end
