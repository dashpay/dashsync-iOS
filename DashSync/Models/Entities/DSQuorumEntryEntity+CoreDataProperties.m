//
//  DSQuorumEntryEntity+CoreDataProperties.m
//  Dash-PLCrashReporter
//
//  Created by Sam Westrich on 6/14/19.
//
//

#import "DSQuorumEntryEntity+CoreDataProperties.h"

@implementation DSQuorumEntryEntity (CoreDataProperties)

+ (NSFetchRequest<DSQuorumEntryEntity *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"DSQuorumEntryEntity"];
}

@dynamic allCommitmentAggregatedSignatureData;
@dynamic commitmentHashData;
@dynamic llmqType;
@dynamic quorumHashData;
@dynamic quorumPublicKeyData;
@dynamic quorumThresholdSignatureData;
@dynamic quorumVerificationVectorHashData;
@dynamic signersBitset;
@dynamic signersCount;
@dynamic validMembersBitset;
@dynamic validMembersCount;
@dynamic verified;
@dynamic version;
@dynamic block;
@dynamic chain;
@dynamic commitmentTransaction;
@dynamic instantSendLocks;
@dynamic referencedByMasternodeLists;

@end
