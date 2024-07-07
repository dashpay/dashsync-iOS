//
//  DSQuorumEntry.m
//  DashSync
//
//  Created by Sam Westrich on 4/25/19.
//

#import "DSQuorumEntry.h"
#import "DSBlock.h"
#import "DSChain+Blocks.h"
#import "DSChainManager.h"
#import "DSMasternodeList.h"
#import "DSMasternodeList+Mndiff.h"
#import "DSMasternodeManager.h"
#import "DSMerkleBlock.h"
#import "DSQuorumEntry+Mndiff.h"
#import "DSQuorumEntryEntity+CoreDataClass.h"
#import "DSSimplifiedMasternodeEntry.h"
#import "NSData+Dash.h"
#import "NSManagedObject+Sugar.h"
#import "NSMutableData+Dash.h"

@interface DSQuorumEntry ()

@property (nonatomic, assign) uint16_t version;
@property (nonatomic, assign) uint32_t quorumIndex;
@property (nonatomic, assign) UInt256 quorumHash;
@property (nonatomic, assign) UInt384 quorumPublicKey;
@property (nonatomic, assign) UInt768 quorumThresholdSignature;
@property (nonatomic, assign) UInt256 quorumVerificationVectorHash;
@property (nonatomic, assign) UInt768 allCommitmentAggregatedSignature;
@property (nonatomic, assign) int32_t signersCount;
@property (nonatomic, assign) LLMQType llmqType;
@property (nonatomic, assign) int32_t validMembersCount;
@property (nonatomic, strong) NSData *signersBitset;
@property (nonatomic, strong) NSData *validMembersBitset;
@property (nonatomic, assign) UInt256 quorumEntryHash;
@property (nonatomic, assign) UInt256 commitmentHash;
@property (nonatomic, assign) uint32_t length;
@property (nonatomic, strong) DSChain *chain;
@property (nonatomic, assign) BOOL verified;

@end

@implementation DSQuorumEntry

- (id)copyWithZone:(NSZone *)zone {
    DSQuorumEntry *copy = [[[self class] alloc] init];
    if (!copy) return nil;
    // Copy NSObject subclasses
    [copy setSignersBitset:self.signersBitset];
    [copy setValidMembersBitset:self.validMembersBitset];

    // Set primitives
    [copy setVersion:self.version];
    [copy setQuorumHash:self.quorumHash];
    [copy setQuorumPublicKey:self.quorumPublicKey];
    [copy setQuorumThresholdSignature:self.quorumThresholdSignature];
    [copy setQuorumVerificationVectorHash:self.quorumVerificationVectorHash];
    [copy setAllCommitmentAggregatedSignature:self.allCommitmentAggregatedSignature];
    [copy setSignersCount:self.signersCount];
    [copy setLlmqType:self.llmqType];
    [copy setValidMembersCount:self.validMembersCount];
    [copy setQuorumEntryHash:self.quorumEntryHash];
    [copy setCommitmentHash:self.commitmentHash];
//    [copy setLength:self.length];
    [copy setQuorumIndex:self.quorumIndex];
    [copy setChain:self.chain];

    return copy;
}

- (instancetype)initWithVersion:(uint16_t)version
                           type:(LLMQType)type
                     quorumHash:(UInt256)quorumHash
                    quorumIndex:(uint32_t)quorumIndex
                   signersCount:(int32_t)signersCount
                  signersBitset:(NSData *)signersBitset
              validMembersCount:(int32_t)validMembersCount
             validMembersBitset:(NSData *)validMembersBitset
                quorumPublicKey:(UInt384)quorumPublicKey
   quorumVerificationVectorHash:(UInt256)quorumVerificationVectorHash
       quorumThresholdSignature:(UInt768)quorumThresholdSignature
allCommitmentAggregatedSignature:(UInt768)allCommitmentAggregatedSignature
                quorumEntryHash:(UInt256)quorumEntryHash
                        onChain:(DSChain *)chain {
    if (!(self = [super init])) return nil;

    self.llmqType = type;
    self.version = version;
    self.quorumHash = quorumHash;
    self.quorumIndex = quorumIndex;
    self.signersCount = signersCount;
    self.signersBitset = signersBitset;
    self.validMembersCount = validMembersCount;
    self.validMembersBitset = validMembersBitset;
    self.quorumPublicKey = quorumPublicKey;
    self.quorumVerificationVectorHash = quorumVerificationVectorHash;
    self.quorumVerificationVectorHash = quorumVerificationVectorHash;
    self.quorumThresholdSignature = quorumThresholdSignature;
    self.allCommitmentAggregatedSignature = allCommitmentAggregatedSignature;
    self.quorumEntryHash = quorumEntryHash;
    self.chain = chain;

    return self;
}

- (instancetype)initWithVersion:(uint16_t)version type:(LLMQType)type quorumHash:(UInt256)quorumHash quorumIndex:(uint32_t)quorumIndex quorumPublicKey:(UInt384)quorumPublicKey quorumEntryHash:(UInt256)quorumEntryHash verified:(BOOL)verified onChain:(DSChain *)chain {
    if (!(self = [super init])) return nil;

    self.llmqType = type;
    self.version = version;
    self.quorumHash = quorumHash;
    self.quorumPublicKey = quorumPublicKey;
    self.quorumEntryHash = quorumEntryHash;
    self.quorumIndex = quorumIndex;
    self.verified = verified;
    self.chain = chain;
    self.saved = TRUE;

    return self;
}

- (instancetype)initWithEntry:(LLMQEntry *)entry onChain:(DSChain *)chain {
    if (!(self = [super init])) return nil;
    self.allCommitmentAggregatedSignature = *((UInt768 *)entry->all_commitment_aggregated_signature);
    if (entry->commitment_hash) {
        self.commitmentHash = *((UInt256 *)entry->commitment_hash);
    }
    self.llmqType = entry->llmq_type;
    self.quorumEntryHash = *((UInt256 *)entry->entry_hash);
    self.quorumHash = *((UInt256 *)entry->llmq_hash);
    self.quorumPublicKey = *((UInt384 *)entry->public_key);
    self.quorumThresholdSignature = *((UInt768 *)entry->threshold_signature);
    self.quorumVerificationVectorHash = *((UInt256 *)entry->verification_vector_hash);
    self.quorumIndex = entry->index;
    self.saved = entry->saved;
    self.signersBitset = [NSData dataWithBytes:entry->signers_bitset length:entry->signers_bitset_length];
    self.signersCount = (uint32_t)entry->signers_count;
    self.validMembersBitset = [NSData dataWithBytes:entry->valid_members_bitset length:entry->valid_members_bitset_length];
    self.validMembersCount = (uint32_t)entry->valid_members_count;
    self.verified = entry->verified;
    self.version = entry->version;
    self.chain = chain;
    return self;
}

- (NSData *)toData {
    NSMutableData *data = [NSMutableData data];
    [data appendUInt16:self.version];
    [data appendUInt8:self.llmqType];
    [data appendUInt256:self.quorumHash];
    if (self.version == LLMQVersion_Indexed || self.version == LLMQVersion_BLSBasicIndexed)
        [data appendUInt32:self.quorumIndex];
    [data appendVarInt:self.signersCount];
    [data appendData:self.signersBitset];
    [data appendVarInt:self.validMembersCount];
    [data appendData:self.validMembersBitset];
    [data appendUInt384:self.quorumPublicKey];
    [data appendUInt256:self.quorumVerificationVectorHash];
    [data appendUInt768:self.quorumThresholdSignature];
    [data appendUInt768:self.allCommitmentAggregatedSignature];
    return data;
}

- (UInt256)commitmentHash {
    if (uint256_is_zero(_commitmentHash)) {
        NSData *data = [self commitmentData];
        _commitmentHash = [data SHA256_2];
    }
    return _commitmentHash;
}

- (NSData *)commitmentData {
    NSMutableData *data = [NSMutableData data];
    [data appendVarInt:self.llmqType];
    [data appendUInt256:self.quorumHash];
    if (self.version == LLMQVersion_Indexed || self.version == LLMQVersion_BLSBasicIndexed)
        [data appendUInt32:self.quorumIndex];
    [data appendVarInt:self.validMembersCount];
    [data appendData:self.validMembersBitset];
    [data appendUInt384:self.quorumPublicKey];
    [data appendUInt256:self.quorumVerificationVectorHash];
    return data;
}

- (uint32_t)quorumThreshold {
    return quorum_threshold_for_type(self.llmqType);
}

- (BOOL)validateWithMasternodeList:(DSMasternodeList *)masternodeList {
    return [self validateWithMasternodeList:masternodeList
                          blockHeightLookup:^uint32_t(UInt256 blockHash) {
                              DSMerkleBlock *block = [self.chain blockForBlockHash:blockHash];
                              if (!block) {
                                  DSLog(@"[%@] Unknown block %@", self.chain.name, uint256_reverse_hex(blockHash));
                                  NSAssert(block, @"block should be known");
                              }
                              return block.height;
                          }];
}

- (BOOL)validateWithMasternodeList:(DSMasternodeList *)masternodeList blockHeightLookup:(BlockHeightFinder)blockHeightLookup {
    if (!masternodeList) {
        DSLog(@"[%@] Trying to validate a quorum without a masternode list", self.chain.name);
        return NO;
    }
    MasternodeList *list = [masternodeList ffi_malloc];
    LLMQEntry *quorum = [self ffi_malloc];
    BOOL is_valid = validate_masternode_list(list, quorum, blockHeightLookup(masternodeList.blockHash), self.chain.chainType, NULL);
    [DSMasternodeList ffi_free:list];
    [DSQuorumEntry ffi_free:quorum];
    self.verified = is_valid;
    return is_valid;
}

- (DSQuorumEntryEntity *)matchingQuorumEntryEntityInContext:(NSManagedObjectContext *)context {
    return [DSQuorumEntryEntity anyObjectInContext:context matching:@"quorumPublicKeyData == %@", uint384_data(self.quorumPublicKey)];
}

- (UInt256)orderingHashForRequestID:(UInt256)requestID forQuorumType:(LLMQType)quorumType {
    NSMutableData *data = [NSMutableData data];
    [data appendVarInt:quorumType];
    [data appendUInt256:self.quorumHash];
    [data appendUInt256:requestID];
    return [data SHA256_2];
}

+ (uint32_t)quorumSizeForType:(LLMQType)type {
    return quorum_size_for_type(type);
}


- (NSString *)description {
    uint32_t height = [self.chain heightForBlockHash:self.quorumHash];
    return [[super description] stringByAppendingString:[NSString stringWithFormat:@" - %u", height]];
}

- (NSString *)debugDescription {
    uint32_t height = [self.chain heightForBlockHash:self.quorumHash];
    return [[super debugDescription] stringByAppendingString:[NSString stringWithFormat:@" - %u -%u", height, self.version]];
}

- (BOOL)isEqual:(id)object {
    if (self == object) return YES;
    if (![object isKindOfClass:[DSQuorumEntry class]]) return NO;
    return uint256_eq(self.quorumEntryHash, ((DSQuorumEntry *)object).quorumEntryHash);
}

- (NSUInteger)hash {
    return [uint256_data(self.quorumEntryHash) hash];
}

- (void)mergedWithQuorumEntry:(DSQuorumEntry *)quorumEntry {
    self.allCommitmentAggregatedSignature = quorumEntry.allCommitmentAggregatedSignature;
    self.commitmentHash = quorumEntry.commitmentHash;
    self.llmqType = quorumEntry.llmqType;
    self.quorumEntryHash = quorumEntry.quorumEntryHash;
    self.quorumHash = quorumEntry.quorumHash;
    self.quorumPublicKey = quorumEntry.quorumPublicKey;
    self.quorumThresholdSignature = quorumEntry.quorumThresholdSignature;
    self.quorumVerificationVectorHash = quorumEntry.quorumVerificationVectorHash;
    self.quorumIndex = quorumEntry.quorumIndex;
    self.saved = quorumEntry.saved;
    self.signersBitset = quorumEntry.signersBitset;
    self.signersCount = quorumEntry.signersCount;
    self.validMembersBitset = quorumEntry.validMembersBitset;
    self.validMembersCount = quorumEntry.validMembersCount;
    self.verified = quorumEntry.verified;
    self.version = quorumEntry.version;
    self.chain = quorumEntry.chain;
}

- (BOOL)useLegacyBLSScheme {
    return self.version <= 2;
}

@end
