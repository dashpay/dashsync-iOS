//
//  DSTransactionLockVoteEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 1/9/19.
//
//

#import "DSTransactionLockVoteEntity+CoreDataProperties.h"

@implementation DSTransactionLockVoteEntity (CoreDataProperties)

+ (NSFetchRequest<DSTransactionLockVoteEntity *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"DSTransactionLockVoteEntity"];
}

@dynamic transactionLockVoteHash;
@dynamic fromValidQuorum;
@dynamic signatureIsValid;
@dynamic blockHash;
@dynamic inputHash;
@dynamic inputIndex;
@dynamic transactionHash;
@dynamic masternodeOutpointHash;
@dynamic masternodeOutpointIndex;
@dynamic masternodeProviderTransactionHash;
@dynamic simplifiedMasternodeEntry;
@dynamic transaction;
@dynamic quorumModifierHash;
@dynamic chain;

@end
