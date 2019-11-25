//
//  DSChainLockEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 11/25/19.
//
//

#import "DSChainLockEntity+CoreDataClass.h"
#import "DSSimplifiedMasternodeEntry.h"
#import "DSQuorumEntryEntity+CoreDataClass.h"
#import "DSMerkleBlockEntity+CoreDataClass.h"
#import "NSManagedObject+Sugar.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSChainLock.h"
#import "BigIntTypes.h"
#import "NSData+Bitcoin.h"
#import "DSQuorumEntry.h"
#import "DSMerkleBlock.h"

@implementation DSChainLockEntity

- (instancetype)setAttributesFromChainLock:(DSChainLock *)chainLock
{
    [self.managedObjectContext performBlockAndWait:^{
        [DSQuorumEntryEntity setContext:self.managedObjectContext];
        self.validSignature = chainLock.signatureVerified;
        self.signature = [NSData dataWithUInt768:chainLock.signature];
        DSMerkleBlockEntity * merkleBlockEntity = [DSMerkleBlockEntity anyObjectMatching:@"blockHash == %@", uint256_data(chainLock.blockHash)];
        NSAssert(merkleBlockEntity, @"merkle block must exist");
        self.merkleBlock = merkleBlockEntity;
        self.quorum = chainLock.intendedQuorum.matchingQuorumEntryEntity;//the quorum might not yet
    }];
    
    return self;
}

- (DSChainLock *)chainLockForChain:(DSChain*)chain
{
    DSChainLock * chainLock = [[DSChainLock alloc] initWithBlockHash:self.merkleBlock.blockHash.UInt256 signatureVerified:TRUE quorumVerified:TRUE onChain:chain];
    
    return chainLock;
}

@end
