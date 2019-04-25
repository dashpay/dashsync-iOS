//
//  DSQuorumEntryEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 4/25/19.
//
//

#import "DSQuorumEntryEntity+CoreDataClass.h"
#import "NSData+Bitcoin.h"
#import "NSManagedObject+Sugar.h"
#import "DSChainEntity+CoreDataClass.h"

@implementation DSQuorumEntryEntity

-(UInt256)quorumHash {
    return self.quorumHashData.UInt256;
}

-(void)setQuorumHash:(UInt256)quorumHash {
    self.quorumHashData = [NSData dataWithUInt256:quorumHash];
}

-(UInt384)quorumPublicKey {
    return self.quorumPublicKeyData.UInt384;
}

-(void)setQuorumPublicKey:(UInt384)quorumPublicKey {
    self.quorumPublicKeyData = [NSData dataWithUInt384:quorumPublicKey];
}

-(UInt768)quorumThresholdSignature {
    return self.quorumThresholdSignatureData.UInt768;
}

-(void)setQuorumThresholdSignature:(UInt768)quorumThresholdSignature {
    self.quorumThresholdSignatureData = [NSData dataWithUInt768:quorumThresholdSignature];
}

-(UInt768)allCommitmentAggregatedSignature {
    return self.allCommitmentAggregatedSignatureData.UInt768;
}

-(void)setAllCommitmentAggregatedSignature:(UInt768)allCommitmentAggregatedSignature {
    self.allCommitmentAggregatedSignatureData = [NSData dataWithUInt768:allCommitmentAggregatedSignature];
}

-(UInt256)quorumVerificationVectorHash {
    return self.quorumVerificationVectorHashData.UInt256;
}

-(void)setQuorumVerificationVectorHash:(UInt256)quorumVerificationVectorHash {
    self.quorumVerificationVectorHashData = [NSData dataWithUInt256:quorumVerificationVectorHash];
}

+ (void)deleteHavingQuorumHashes:(NSArray*)quorumHashes onChain:(DSChainEntity*)chainEntity {
    NSArray * hashesToDelete = [self objectsMatching:@"(chain == %@) && (quorumHashData IN %@)",chainEntity,quorumHashes];
    for (DSQuorumEntryEntity * quorumEntryEntity in hashesToDelete) {
        [chainEntity.managedObjectContext deleteObject:quorumEntryEntity];
    }
}

+ (void)deleteAllOnChain:(DSChainEntity*)chainEntity {
    NSArray * hashesToDelete = [self objectsMatching:@"(chain == %@)",chainEntity];
    for (DSQuorumEntryEntity * QuorumEntryEntity in hashesToDelete) {
        [chainEntity.managedObjectContext deleteObject:QuorumEntryEntity];
    }
}

+ (DSQuorumEntryEntity*)quorumEntryForHash:(NSData*)quorumEntryHash onChain:(DSChainEntity*)chainEntity {
    NSArray * objects = [self objectsMatching:@"(chain == %@) && (quorumEntryHash == %@)",chainEntity,quorumEntryHash];
    return [objects firstObject];
}

@end
