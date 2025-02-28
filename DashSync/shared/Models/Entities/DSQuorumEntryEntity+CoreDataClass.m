//
//  DSQuorumEntryEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 4/25/19.
//
//

#import "DSChain+Protected.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSKeyManager.h"
#import "DSMerkleBlockEntity+CoreDataClass.h"
#import "DSQuorumEntryEntity+CoreDataClass.h"
#import "NSData+Dash.h"
#import "NSManagedObject+Sugar.h"
#import "NSMutableData+Dash.h"

@implementation DSQuorumEntryEntity


+ (instancetype)quorumEntryEntityFromPotentialQuorumEntry:(DLLMQEntry *)potentialQuorumEntry
                                                inContext:(NSManagedObjectContext *)context
                                                  onChain:(DSChain *)chain {
    NSData *quorumHash = NSDataFromPtr(potentialQuorumEntry->llmq_hash);
    int16_t llmqType = dash_spv_crypto_network_llmq_type_LLMQType_index(potentialQuorumEntry->llmq_type);
    DSMerkleBlockEntity *block = [DSMerkleBlockEntity merkleBlockEntityForBlockHash:quorumHash inContext:context];
    DSQuorumEntryEntity *quorumEntryEntity = nil;
    if (block) {
        quorumEntryEntity = [[block.usedByQuorums filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"quorumHashData == %@ && llmqType == %@ ", quorumHash, @(llmqType)]] anyObject];
    } else {
        quorumEntryEntity = [DSQuorumEntryEntity anyObjectInContext:context matching:@"quorumHashData == %@ && llmqType == %@ ", quorumHash, @(llmqType)];
    }
    if (!quorumEntryEntity) {
        if (potentialQuorumEntry->saved) { //it was deleted in the meantime, and should be ignored
            return nil;
        } else {
            quorumEntryEntity = [DSQuorumEntryEntity managedObjectInBlockedContext:context];
            [quorumEntryEntity setAttributesFromPotentialQuorumEntry:potentialQuorumEntry onBlock:block onChain:chain];
        }
    } else {
        [quorumEntryEntity updateAttributesFromPotentialQuorumEntry:potentialQuorumEntry onBlock:block];
    }
    return quorumEntryEntity;
}

+ (instancetype)quorumEntryEntityFromPotentialQuorumEntryForMerging:(DLLMQEntry *)potentialQuorumEntry
                                                          inContext:(NSManagedObjectContext *)context
                                                            onChain:(DSChain *)chain {
    NSData *quorumHash = NSDataFromPtr(potentialQuorumEntry->llmq_hash);
    int16_t llmqType = dash_spv_crypto_network_llmq_type_LLMQType_index(potentialQuorumEntry->llmq_type);
    DSMerkleBlockEntity *block = [DSMerkleBlockEntity merkleBlockEntityForBlockHash:quorumHash inContext:context];
    DSQuorumEntryEntity *quorumEntryEntity = nil;
    if (block) {
        quorumEntryEntity = [[block.usedByQuorums filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"quorumHashData == %@ && llmqType == %@ ", quorumHash, @(llmqType)]] anyObject];
    } else {
        quorumEntryEntity = [DSQuorumEntryEntity anyObjectInContext:context matching:@"quorumHashData == %@ && llmqType == %@ ", quorumHash, @(llmqType)];
    }
    if (!quorumEntryEntity) {
        if (potentialQuorumEntry->saved && dash_spv_crypto_llmq_entry_LLMQEntry_is_verified(potentialQuorumEntry)) {
            return nil;
        } else {
            quorumEntryEntity = [DSQuorumEntryEntity managedObjectInBlockedContext:context];
            [quorumEntryEntity setAttributesFromPotentialQuorumEntry:potentialQuorumEntry onBlock:block onChain:chain];
        }
    } else {
        [quorumEntryEntity updateAttributesFromPotentialQuorumEntry:potentialQuorumEntry onBlock:block];
    }
    return quorumEntryEntity;
}

- (void)setAttributesFromPotentialQuorumEntry:(DLLMQEntry *)potentialQuorumEntry
                                      onBlock:(DSMerkleBlockEntity *)block
                                      onChain:(DSChain *)chain {
    self.verified = (block != nil) && dash_spv_crypto_llmq_entry_LLMQEntry_is_verified(potentialQuorumEntry);
    self.block = block;
    self.quorumHash = u256_cast(potentialQuorumEntry->llmq_hash);
    self.quorumPublicKey = u384_cast(potentialQuorumEntry->public_key);
    self.quorumThresholdSignature = u768_cast(potentialQuorumEntry->threshold_signature);
    self.quorumVerificationVectorHash = u256_cast(potentialQuorumEntry->verification_vector_hash);
    self.signersCount = (int32_t) potentialQuorumEntry->signers->count;
    self.signersBitset = NSDataFromPtr(potentialQuorumEntry->signers->bitset);
    self.validMembersCount = (int32_t) potentialQuorumEntry->valid_members->count;
    self.validMembersBitset = NSDataFromPtr(potentialQuorumEntry->valid_members->bitset);
    self.llmqType = (int16_t)dash_spv_crypto_network_llmq_type_LLMQType_index(potentialQuorumEntry->llmq_type);
    self.version = dash_spv_crypto_llmq_version_LLMQVersion_index(potentialQuorumEntry->version);
    self.allCommitmentAggregatedSignature = u768_cast(potentialQuorumEntry->all_commitment_aggregated_signature);
    self.commitmentHashData = NSDataFromPtr(potentialQuorumEntry->entry_hash);
    self.quorumIndex = potentialQuorumEntry->index;
    self.chain = [chain chainEntityInContext:self.managedObjectContext];
    potentialQuorumEntry->saved = TRUE;
    // TODO: make sure the cache is updated with "saved" flag
}

- (void)updateAttributesFromPotentialQuorumEntry:(DLLMQEntry *)potentialQuorumEntry
                                         onBlock:(DSMerkleBlockEntity *)block {
    if (!self.verified)
        self.verified = block != nil && dash_spv_crypto_llmq_entry_LLMQEntry_is_verified(potentialQuorumEntry);
    if (!self.block)
        self.block = block;
}

- (UInt256)quorumHash {
    return self.quorumHashData.UInt256;
}

- (void)setQuorumHash:(UInt256)quorumHash {
    self.quorumHashData = [NSData dataWithUInt256:quorumHash];
}

- (UInt384)quorumPublicKey {
    return self.quorumPublicKeyData.UInt384;
}

- (void)setQuorumPublicKey:(UInt384)quorumPublicKey {
    self.quorumPublicKeyData = [NSData dataWithUInt384:quorumPublicKey];
}

- (UInt768)quorumThresholdSignature {
    return self.quorumThresholdSignatureData.UInt768;
}

- (void)setQuorumThresholdSignature:(UInt768)quorumThresholdSignature {
    self.quorumThresholdSignatureData = [NSData dataWithUInt768:quorumThresholdSignature];
}

- (UInt768)allCommitmentAggregatedSignature {
    return self.allCommitmentAggregatedSignatureData.UInt768;
}

- (void)setAllCommitmentAggregatedSignature:(UInt768)allCommitmentAggregatedSignature {
    self.allCommitmentAggregatedSignatureData = [NSData dataWithUInt768:allCommitmentAggregatedSignature];
}

- (UInt256)quorumVerificationVectorHash {
    return self.quorumVerificationVectorHashData.UInt256;
}

- (void)setQuorumVerificationVectorHash:(UInt256)quorumVerificationVectorHash {
    self.quorumVerificationVectorHashData = [NSData dataWithUInt256:quorumVerificationVectorHash];
}

//- (UInt256)commitmentHash {
//    return self.commitmentHashData.UInt256;
//}
//
//- (void)setCommitmentHash:(UInt256)commitmentHash {
//    self.commitmentHashData = [NSData dataWithUInt256:commitmentHash];
//}

//+ (void)deleteHavingQuorumHashes:(NSArray *)quorumHashes onChainEntity:(DSChainEntity *)chainEntity {
//    NSArray *hashesToDelete = [self objectsInContext:chainEntity.managedObjectContext matching:@"(chain == %@) && (quorumHashData IN %@)", chainEntity, quorumHashes];
//    for (DSQuorumEntryEntity *quorumEntryEntity in hashesToDelete) {
//        [chainEntity.managedObjectContext deleteObject:quorumEntryEntity];
//    }
//}

+ (void)deleteAllOnChainEntity:(DSChainEntity *)chainEntity {
    NSArray *hashesToDelete = [self objectsInContext:chainEntity.managedObjectContext matching:@"(chain == %@)", chainEntity];
    for (DSQuorumEntryEntity *quorumEntryEntity in hashesToDelete) {
        [chainEntity.managedObjectContext deleteObject:quorumEntryEntity];
    }
}

//+ (DSQuorumEntryEntity *)quorumEntryForHash:(NSData *)quorumEntryHash onChainEntity:(DSChainEntity *)chainEntity {
//    /// Seems to be unused or quorumEntryHash must be changed into commitmentHash ?
//    NSArray *objects = [self objectsInContext:chainEntity.managedObjectContext matching:@"(chain == %@) && (commitmentHash == %@)", chainEntity, quorumEntryHash];
//    return [objects firstObject];
//}

- (UInt256)orderingHashForRequestID:(UInt256)requestID {
    NSMutableData *data = [NSMutableData data];
    [data appendVarInt:1];
    [data appendUInt256:self.quorumHash];
    [data appendUInt256:requestID];
    return [data SHA256_2];
}

//- (DSQuorumEntry *)quorumEntry {
//    return [[DSQuorumEntry alloc] initWithVersion:self.version type:self.llmqType quorumHash:self.quorumHash quorumIndex:self.quorumIndex signersCount:self.signersCount signersBitset:self.signersBitset validMembersCount:self.validMembersCount validMembersBitset:self.validMembersBitset quorumPublicKey:self.quorumPublicKey quorumVerificationVectorHash:self.quorumVerificationVectorHash quorumThresholdSignature:self.quorumThresholdSignature allCommitmentAggregatedSignature:self.allCommitmentAggregatedSignature quorumEntryHash:self.commitmentHash onChain:self.chain.chain];
//}
//
@end
