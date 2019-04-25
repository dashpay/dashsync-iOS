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

- (BOOL)applyMessage:(NSData *)message atOffset:(uint32_t*)offset onChain:(DSChain *)chain
{
    NSUInteger length = message.length;
    uint32_t off = *offset;
    
    
    if (length - off < 1) return nil;
    self.llmqType = [message UInt8AtOffset:off];
    off += 1;
    
    if (length - off < 32) return nil;
    self.quorumHash = [message UInt256AtOffset:off];
    off += 32;
    
    if (length - off < 1) return nil;
    NSNumber * signersCountLengthSize = nil;
    self.signersCount = (uint32_t)[message varIntAtOffset:off length:&signersCountLengthSize];
    off += signersCountLengthSize.unsignedLongValue;
    
    uint16_t signersBufferLength = ((self.signersCount +7)/8);
    
    if (length - off < signersBufferLength) return nil;
    self.signersBitset = [message subdataWithRange:NSMakeRange(off, signersBufferLength)];
    off += signersBufferLength;
    
    if (length - off < 1) return nil;
    NSNumber * validMembersCountLengthSize = nil;
    self.validMembersCount = (uint32_t)[message varIntAtOffset:off length:&validMembersCountLengthSize];
    off += validMembersCountLengthSize.unsignedLongValue;
    
    uint16_t validMembersCountBufferLength = ((self.validMembersCount +7)/8);
    
    if (length - off < validMembersCountBufferLength) return nil;
    self.validMembersBitset = [message subdataWithRange:NSMakeRange(off, validMembersCountBufferLength)];
    off += validMembersCountBufferLength;
    
    if (length - off < 48) return nil;
    self.quorumPublicKey = [message UInt384AtOffset:off];
    off += 48;
    
    if (length - off < 32) return nil;
    self.quorumVerificationVectorHash = [message UInt256AtOffset:off];
    off += 32;
    
    if (length - off < 96) return nil;
    self.quorumThresholdSignature = [message UInt768AtOffset:off];
    off += 96;
    
    if (length - off < 96) return nil;
    self.allCommitmentAggregatedSignature = [message UInt768AtOffset:off];
    off += 96;
    
    *offset = off;
    
    return self;
}

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
