//
//  DSQuorumCommitmentTransactionEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 4/24/19.
//
//

#import "DSQuorumCommitmentTransactionEntity+CoreDataProperties.h"

@implementation DSQuorumCommitmentTransactionEntity (CoreDataProperties)

+ (NSFetchRequest<DSQuorumCommitmentTransactionEntity *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"DSQuorumCommitmentTransactionEntity"];
}

@dynamic quorumCommitmentHeight;
@dynamic llmqType;
@dynamic quorumHash;
@dynamic signersCount;
@dynamic membersCount;
@dynamic quorumPublicKey;
@dynamic quorumVerificationVectorHash;
@dynamic quorumThresholdSignature;
@dynamic allCommitmentAggregatedSignature;

@end
