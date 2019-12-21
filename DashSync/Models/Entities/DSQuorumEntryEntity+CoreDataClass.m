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
#import "DSQuorumEntry.h"
#import "DSMerkleBlockEntity+CoreDataClass.h"
#import "NSMutableData+Dash.h"
#import "DSQuorumEntry.h"

@implementation DSQuorumEntryEntity

+(instancetype)quorumEntryEntityFromPotentialQuorumEntry:(DSQuorumEntry *)potentialQuorumEntry {
    DSMerkleBlockEntity * block = [DSMerkleBlockEntity anyObjectMatching:@"blockHash == %@",uint256_data(potentialQuorumEntry.quorumHash)];
    DSQuorumEntryEntity * quorumEntryEntity = nil;
    if (block) {
        quorumEntryEntity = [[block.usedByQuorums filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"quorumHashData == %@ && llmqType == %@ ",uint256_data(potentialQuorumEntry.quorumHash),@(potentialQuorumEntry.llmqType)]] anyObject];
    } else {
        quorumEntryEntity = [DSQuorumEntryEntity anyObjectMatching:@"quorumHashData == %@ && llmqType == %@ ",uint256_data(potentialQuorumEntry.quorumHash),@(potentialQuorumEntry.llmqType)];
    }
    
    if (!quorumEntryEntity) {
        if (potentialQuorumEntry.saved) { //it was deleted in the meantime, and should be ignored
            return nil;
        } else {
            quorumEntryEntity = [DSQuorumEntryEntity managedObject];
            [quorumEntryEntity setAttributesFromPotentialQuorumEntry:potentialQuorumEntry onBlock:block];
        }
    } else {
        [quorumEntryEntity updateAttributesFromPotentialQuorumEntry:potentialQuorumEntry onBlock:block];
    }
    
    return quorumEntryEntity;
}

- (void)setAttributesFromPotentialQuorumEntry:(DSQuorumEntry *)potentialQuorumEntry onBlock:(DSMerkleBlockEntity *) block {
    self.verified = !!block && potentialQuorumEntry.verified;
    self.block = block;
    self.quorumHash = potentialQuorumEntry.quorumHash;
    self.quorumPublicKey = potentialQuorumEntry.quorumPublicKey;
    self.quorumThresholdSignature = potentialQuorumEntry.quorumThresholdSignature;
    self.quorumVerificationVectorHash = potentialQuorumEntry.quorumVerificationVectorHash;
    self.signersCount = potentialQuorumEntry.signersCount;
    self.signersBitset = potentialQuorumEntry.signersBitset;
    self.validMembersCount = potentialQuorumEntry.validMembersCount;
    self.validMembersBitset = potentialQuorumEntry.validMembersBitset;
    self.llmqType = potentialQuorumEntry.llmqType;
    self.version = potentialQuorumEntry.version;
    self.allCommitmentAggregatedSignature = potentialQuorumEntry.allCommitmentAggregatedSignature;
    self.commitmentHash = potentialQuorumEntry.quorumEntryHash;
    self.chain = potentialQuorumEntry.chain.chainEntity;
    potentialQuorumEntry.saved = TRUE;
}

-(void)updateAttributesFromPotentialQuorumEntry:(DSQuorumEntry *)potentialQuorumEntry onBlock:(DSMerkleBlockEntity *) block {
    if (!self.verified) {
        self.verified = !!block && potentialQuorumEntry.verified;
    }
    if (!self.block) {
        self.block = block;
    }
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

-(UInt256)commitmentHash {
    return self.commitmentHashData.UInt256;
}

-(void)setCommitmentHash:(UInt256)commitmentHash {
    self.commitmentHashData = [NSData dataWithUInt256:commitmentHash];
}

+ (void)deleteHavingQuorumHashes:(NSArray*)quorumHashes onChain:(DSChainEntity*)chainEntity {
    NSArray * hashesToDelete = [self objectsMatching:@"(chain == %@) && (quorumHashData IN %@)",chainEntity,quorumHashes];
    for (DSQuorumEntryEntity * quorumEntryEntity in hashesToDelete) {
        [chainEntity.managedObjectContext deleteObject:quorumEntryEntity];
    }
}

+ (void)deleteAllOnChain:(DSChainEntity*)chainEntity {
    NSArray * hashesToDelete = [self objectsMatching:@"(chain == %@)",chainEntity];
    for (DSQuorumEntryEntity * quorumEntryEntity in hashesToDelete) {
        [chainEntity.managedObjectContext deleteObject:quorumEntryEntity];
    }
}

+ (DSQuorumEntryEntity*)quorumEntryForHash:(NSData*)quorumEntryHash onChain:(DSChainEntity*)chainEntity {
    NSArray * objects = [self objectsMatching:@"(chain == %@) && (quorumEntryHash == %@)",chainEntity,quorumEntryHash];
    return [objects firstObject];
}

- (UInt256)orderingHashForRequestID:(UInt256)requestID {
    NSMutableData * data = [NSMutableData data];
    [data appendVarInt:1];
    [data appendUInt256:self.quorumHash];
    [data appendUInt256:requestID];
    return [data SHA256_2];
}

-(DSQuorumEntry*)quorumEntry {
    DSQuorumEntry * quorumEntry = [[DSQuorumEntry alloc] initWithVersion:self.version type:self.llmqType quorumHash:self.quorumHash quorumPublicKey:self.quorumPublicKey commitmentHash:self.commitmentHash verified:self.verified onChain:self.chain.chain];
    return quorumEntry;
}

@end
