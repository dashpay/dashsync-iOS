//
//  DSChainEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 12/31/19.
//
//

#import "DSChainEntity+CoreDataProperties.h"

@implementation DSChainEntity (CoreDataProperties)

+ (NSFetchRequest<DSChainEntity *> *)fetchRequest {
    return [NSFetchRequest fetchRequestWithEntityName:@"DSChainEntity"];
}

@dynamic baseBlockHash;
@dynamic checkpoints;
@dynamic devnetIdentifier;
@dynamic totalGovernanceObjectsCount;
@dynamic type;
@dynamic accounts;
@dynamic blocks;
@dynamic contacts;
@dynamic derivationPaths;
@dynamic governanceObjectHashes;
@dynamic peers;
@dynamic quorums;
@dynamic simplifiedMasternodeEntries;
@dynamic sporks;
@dynamic transactionHashes;
@dynamic votes;
@dynamic identities;
@dynamic syncBlockHash;
@dynamic syncBlockHeight;
@dynamic syncLocators;
@dynamic syncBlockTimestamp;
@dynamic lastChainLock;
@dynamic syncBlockChainWork;

@end
