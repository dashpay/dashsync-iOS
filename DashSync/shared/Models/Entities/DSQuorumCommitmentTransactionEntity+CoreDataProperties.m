//
//  DSQuorumCommitmentTransactionEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 4/25/19.
//
//

#import "DSQuorumCommitmentTransactionEntity+CoreDataProperties.h"

@implementation DSQuorumCommitmentTransactionEntity (CoreDataProperties)

+ (NSFetchRequest<DSQuorumCommitmentTransactionEntity *> *)fetchRequest {
    return [NSFetchRequest fetchRequestWithEntityName:@"DSQuorumCommitmentTransactionEntity"];
}

@dynamic quorumCommitmentHeight;
@dynamic entry;

@end
