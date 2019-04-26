//
//  DSQuorumEntryEntity+CoreDataProperties.m
//  DashSync
//
//  Created by Sam Westrich on 4/25/19.
//
//

#import "DSQuorumEntryEntity+CoreDataProperties.h"

@implementation DSQuorumEntryEntity (CoreDataProperties)

+ (NSFetchRequest<DSQuorumEntryEntity *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"DSQuorumEntryEntity"];
}

@dynamic quorumHashData;
@dynamic quorumPublicKeyData;
@dynamic quorumThresholdSignatureData;
@dynamic quorumVerificationVectorHashData;
@dynamic signersCount;
@dynamic allCommitmentAggregatedSignatureData;
@dynamic llmqType;
@dynamic validMembersCount;
@dynamic commitmentTransaction;
@dynamic chain;
@dynamic signersBitset;
@dynamic validMembersBitset;
@dynamic commitmentHashData;
@dynamic version;

@end
