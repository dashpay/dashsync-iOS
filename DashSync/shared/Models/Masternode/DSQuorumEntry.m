//
//  DSQuorumEntry.m
//  DashSync
//
//  Created by Sam Westrich on 4/25/19.
//

#import "DSQuorumEntry.h"
#import "DSBLSKey.h"
#import "DSBlock.h"
#import "DSChainManager.h"
#import "DSMasternodeList.h"
#import "DSMasternodeManager.h"
#import "DSMerkleBlock.h"
#import "DSQuorumEntryEntity+CoreDataClass.h"
#import "DSSimplifiedMasternodeEntry.h"
#import "NSData+Dash.h"
#import "NSManagedObject+Sugar.h"
#import "NSMutableData+Dash.h"

@interface DSQuorumEntry ()

@property (nonatomic, assign) uint16_t version;
@property (nonatomic, assign) UInt256 quorumHash;
@property (nonatomic, assign) uint32_t quorumIndex;
@property (nonatomic, assign) UInt384 quorumPublicKey;
@property (nonatomic, assign) UInt768 quorumThresholdSignature;
@property (nonatomic, assign) UInt256 quorumVerificationVectorHash;
@property (nonatomic, assign) UInt768 allCommitmentAggregatedSignature;
@property (nonatomic, assign) int32_t signersCount;
@property (nonatomic, assign) DSLLMQType llmqType;
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
    [copy setQuorumIndex:self.quorumIndex];
    [copy setQuorumPublicKey:self.quorumPublicKey];
    [copy setQuorumThresholdSignature:self.quorumThresholdSignature];
    [copy setQuorumVerificationVectorHash:self.quorumVerificationVectorHash];
    [copy setAllCommitmentAggregatedSignature:self.allCommitmentAggregatedSignature];
    [copy setSignersCount:self.signersCount];
    [copy setLlmqType:self.llmqType];
    [copy setValidMembersCount:self.validMembersCount];
    [copy setQuorumEntryHash:self.quorumEntryHash];
    [copy setCommitmentHash:self.commitmentHash];
    [copy setLength:self.length];

    [copy setChain:self.chain];

    return copy;
}

- (instancetype)initWithVersion:(uint16_t)version type:(DSLLMQType)type quorumHash:(UInt256)quorumHash quorumIndex:(uint32_t)quorumIndex quorumPublicKey:(UInt384)quorumPublicKey quorumEntryHash:(UInt256)quorumEntryHash verified:(BOOL)verified onChain:(DSChain *)chain {
    if (!(self = [super init])) return nil;

    self.llmqType = type;
    self.version = version;
    self.quorumHash = quorumHash;
    self.quorumIndex = quorumIndex;
    self.quorumPublicKey = quorumPublicKey;
    self.quorumEntryHash = quorumEntryHash;
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
    self.length = (uint32_t)entry->length;
    self.llmqType = (DSLLMQType)entry->llmq_type;
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
    if (self.version == LLMQ_INDEXED_VERSION)
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
    if (self.version == LLMQ_INDEXED_VERSION)
        [data appendUInt32:self.quorumIndex];
    [data appendVarInt:self.validMembersCount];
    [data appendData:self.validMembersBitset];
    [data appendUInt384:self.quorumPublicKey];
    [data appendUInt256:self.quorumVerificationVectorHash];
    return data;
}

- (uint32_t)quorumThreshold {
    switch (self.llmqType) { //!OCLINT
        case DSLLMQType_50_60:
            return 30;
        case DSLLMQType_400_60:
            return 240;
        case DSLLMQType_400_85:
            return 340;
        case DSLLMQType_100_67:
            return 67;
        case DSLLMQType_5_60:
            return 3;
        case DSLLMQType_10_60:
            return 6;
        case DSLLMQType_60_80:
            return 48;
        default:
            NSAssert(FALSE, @"Unknown llmq type");
            return UINT32_MAX;
    }
}

- (UInt256)llmqQuorumHash {
    NSMutableData *data = [NSMutableData data];
    [data appendVarInt:self.llmqType];
    [data appendUInt256:self.quorumHash];
    return [data SHA256_2];
}

- (BOOL)validateWithMasternodeList:(DSMasternodeList *)masternodeList {
    return [self validateWithMasternodeList:masternodeList
                          blockHeightLookup:^uint32_t(UInt256 blockHash) {
                              DSMerkleBlock *block = [self.chain blockForBlockHash:blockHash];
                              if (!block) {
                                  DSLog(@"Unknown block %@", uint256_reverse_hex(blockHash));
                                  NSAssert(block, @"block should be known");
                              }
                              return block.height;
                          }];
}

- (BOOL)validateWithMasternodeList:(DSMasternodeList *)masternodeList blockHeightLookup:(BlockHeightFinder)blockHeightLookup {
    if (!masternodeList) {
        DSLog(@"Trying to validate a quorum without a masternode list");
        return NO;
    }

    //The quorumHash must match the current DKG session
    //todo
    //The byte size of the signers and validMembers bitvectors must match “(quorumSize + 7) / 8”
    if (self.signersBitset.length != (self.signersCount + 7) / 8) {
        DSLog(@"Error: The byte size of the signers bitvectors (%lu) must match “(quorumSize + 7) / 8 (%d)", (unsigned long)self.signersBitset.length, (self.signersCount + 7) / 8);
        return NO;
    }
    if (self.validMembersBitset.length != (self.validMembersCount + 7) / 8) {
        DSLog(@"Error: The byte size of the validMembers bitvectors (%lu) must match “(quorumSize + 7) / 8 (%d)", (unsigned long)self.validMembersBitset.length, (self.validMembersCount + 7) / 8);
        return NO;
    }

    //No out-of-range bits should be set in byte representation of the signers and validMembers bitvectors
    uint32_t signersOffset = self.signersCount / 8;
    uint8_t signersLastByte = [self.signersBitset UInt8AtOffset:signersOffset];
    uint8_t signersMask = UINT8_MAX >> (8 - signersOffset) << (8 - signersOffset);
    if (signersLastByte & signersMask) {
        DSLog(@"Error: No out-of-range bits should be set in byte representation of the signers bitvector");
        return NO;
    }

    uint32_t validMembersOffset = self.validMembersCount / 8;
    uint8_t validMembersLastByte = [self.validMembersBitset UInt8AtOffset:validMembersOffset];
    uint8_t validMembersMask = UINT8_MAX >> (8 - validMembersOffset) << (8 - validMembersOffset);
    if (validMembersLastByte & validMembersMask) {
        DSLog(@"Error: No out-of-range bits should be set in byte representation of the validMembers bitvector");
        return NO;
    }

    //The number of set bits in the signers and validMembers bitvectors must be at least >= quorumThreshold
    if ([self.signersBitset trueBitsCount] < [self quorumThreshold]) {
        DSLog(@"Error: The number of set bits in the signers bitvector %llu must be at least >= quorumThreshold %d", [self.signersBitset trueBitsCount], [self quorumThreshold]);
        return NO;
    }
    if ([self.validMembersBitset trueBitsCount] < [self quorumThreshold]) {
        DSLog(@"Error: The number of set bits in the validMembers bitvector %llu must be at least >= quorumThreshold %d", [self.validMembersBitset trueBitsCount], [self quorumThreshold]);
        return NO;
    }

    //The quorumSig must validate against the quorumPublicKey and the commitmentHash. As this is a recovered threshold signature, normal signature verification can be performed, without the need of the full quorum verification vector. The commitmentHash is calculated in the same way as in the commitment phase.

#define LOG_COMMITMENT_DATA (0 && DEBUG)
#define SAVE_QUORUM_ERROR_PUBLIC_KEY_ARRAY_TO_FILE (0 && DEBUG)
#define SAVE_MNL_ERROR_TO_FILE (0 && DEBUG)
#define MASTERNODELIST_HEIGHT_TO_SAVE_DATA 1377216

    NSArray<DSSimplifiedMasternodeEntry *> *masternodes = [masternodeList validMasternodesForQuorumModifier:self.llmqQuorumHash quorumCount:[DSQuorumEntry quorumSizeForType:self.llmqType] blockHeightLookup:blockHeightLookup];
#if SAVE_MNL_ERROR_TO_FILE
    NSArray<DSSimplifiedMasternodeEntry *> *allMasternodes = [masternodeList allMasternodesForQuorumModifier:self.llmqQuorumHash quorumCount:[DSQuorumEntry quorumSizeForType:self.llmqType] blockHeightLookup:blockHeightLookup];
#endif
    NSMutableArray<DSBLSKey *> *publicKeyArray = [NSMutableArray array];
    uint32_t i = 0;
    uint32_t blockHeight = blockHeightLookup(masternodeList.blockHash);
#if SAVE_QUORUM_ERROR_PUBLIC_KEY_ARRAY_TO_FILE
    NSMutableDictionary<NSData *, NSData *> *proTxHashForPublicKeys = [NSMutableDictionary dictionary];
#endif
    for (DSSimplifiedMasternodeEntry *masternodeEntry in masternodes) {
        if ([self.signersBitset bitIsTrueAtLEIndex:i]) {
            UInt384 pkData = [masternodeEntry operatorPublicKeyAtBlockHeight:blockHeight];
            //                        NSLog(@"validateQuorumCallback addPublicKey: %@", uint384_hex(pkData));
            DSBLSKey *masternodePublicKey = [DSBLSKey keyWithPublicKey:pkData];
            [publicKeyArray addObject:masternodePublicKey];
#if SAVE_QUORUM_ERROR_PUBLIC_KEY_ARRAY_TO_FILE
            [proTxHashForPublicKeys setObject:uint256_data(masternodeEntry.providerRegistrationTransactionHash)
                                       forKey:uint384_data(masternodePublicKey.publicKey)];
#endif
        }
        i++;
    }

    BOOL allCommitmentAggregatedSignatureValidated = [DSBLSKey verifySecureAggregated:self.commitmentHash signature:self.allCommitmentAggregatedSignature withPublicKeys:publicKeyArray];

    //    NSLog(@"validateQuorumCallback verifySecureAggregated = %i, with: commitmentHash: %@, allCommitmentAggregatedSignature: %@, publicKeys: %lu", allCommitmentAggregatedSignatureValidated, uint256_hex(self.commitmentHash), uint768_hex(self.allCommitmentAggregatedSignature), [publicKeyArray count]);

    if (!allCommitmentAggregatedSignatureValidated) {
        DSLog(@"Issue with allCommitmentAggregatedSignatureValidated for quorum of type %d quorumHash %@ llmqHash %@ commitmentHash %@ signersBitset %@ (%d signers) at height %u", self.llmqType, uint256_hex(self.commitmentHash), uint256_hex(self.quorumHash), uint256_hex(self.commitmentHash), self.signersBitset.hexString, self.signersCount, masternodeList.height);
#if SAVE_QUORUM_ERROR_PUBLIC_KEY_ARRAY_TO_FILE
        {
            NSMutableData *message = [NSMutableData data];
            for (DSBLSKey *publicKey in publicKeyArray) {
                NSData *publicKeyData = publicKey.publicKeyData;
                NSString *line = [NSString stringWithFormat:@"%@ -> %@\n", [proTxHashForPublicKeys[publicKeyData] hexString], [publicKeyData hexString]];
                [message appendData:[line dataUsingEncoding:NSUTF8StringEncoding]];
            }
            NSString *fileName = [NSString stringWithFormat:@"MNL_QUORUM_ERROR_KEYS_%d.txt", masternodeList.height];
            [message saveToFile:fileName inDirectory:NSCachesDirectory];
        }
#endif
#if SAVE_MNL_ERROR_TO_FILE
        {
            NSMutableData *message = [NSMutableData data];
            for (DSSimplifiedMasternodeEntry *simplifiedMasternodeEntry in allMasternodes) {
                NSString *line = [NSString stringWithFormat:@"%@ -> %@\n", uint256_hex(simplifiedMasternodeEntry.providerRegistrationTransactionHash), [simplifiedMasternodeEntry isValidAtBlockHeight:masternodeList.height] ? @"VALID" : @"NOT VALID"];
                [message appendData:[line dataUsingEncoding:NSUTF8StringEncoding]];
            }
            NSString *fileName = [NSString stringWithFormat:@"MNL_QUORUM_ERROR_MNS_%d.txt", masternodeList.height];
            [message saveToFile:fileName inDirectory:NSCachesDirectory];
        }
#endif
        return NO;
    }
#if LOG_COMMITMENT_DATA || SAVE_QUORUM_ERROR_PUBLIC_KEY_ARRAY_TO_FILE || SAVE_MNL_ERROR_TO_FILE
    else {
#if LOG_COMMITMENT_DATA
        DSLog(@"No Issue with Checking allCommitmentAggregatedSignatureValidated for quorum of type %d quorumHash %@ llmqHash %@ commitmentHash %@ signersBitset %@ (%d signers) at height %u", self.llmqType, uint256_hex(self.commitmentHash), uint256_hex(self.quorumHash), uint256_hex(self.commitmentHash), self.signersBitset.hexString, self.signersCount, masternodeList.height);
#endif
#if SAVE_QUORUM_ERROR_PUBLIC_KEY_ARRAY_TO_FILE
        if (MASTERNODELIST_HEIGHT_TO_SAVE_DATA == masternodeList.height) {
            NSMutableData *message = [NSMutableData data];
            for (DSBLSKey *publicKey in publicKeyArray) {
                NSData *publicKeyData = publicKey.publicKeyData;
                NSString *line = [NSString stringWithFormat:@"%@ -> %@\n", [proTxHashForPublicKeys[publicKeyData] hexString], [publicKeyData hexString]];
                [message appendData:[line dataUsingEncoding:NSUTF8StringEncoding]];
            }
            NSString *fileName = [NSString stringWithFormat:@"MNL_QUORUM_NO_ERROR_KEYS_%d.txt", masternodeList.height];
            [message saveToFile:fileName inDirectory:NSCachesDirectory];
        }
#endif
#if SAVE_MNL_ERROR_TO_FILE
        if (MASTERNODELIST_HEIGHT_TO_SAVE_DATA == masternodeList.height) {
            NSMutableData *message = [NSMutableData data];
            for (DSSimplifiedMasternodeEntry *simplifiedMasternodeEntry in allMasternodes) {
                NSString *line = [NSString stringWithFormat:@"%@ -> %@\n", uint256_hex(simplifiedMasternodeEntry.providerRegistrationTransactionHash), [simplifiedMasternodeEntry isValidAtBlockHeight:masternodeList.height] ? @"VALID" : @"NOT VALID"];
                [message appendData:[line dataUsingEncoding:NSUTF8StringEncoding]];
            }
            NSString *fileName = [NSString stringWithFormat:@"MNL_QUORUM_NO_ERROR_MNS_%d.txt", masternodeList.height];
            [message saveToFile:fileName inDirectory:NSCachesDirectory];
        }
#endif
    }
#endif

    //The sig must validate against the commitmentHash and all public keys determined by the signers bitvector. This is an aggregated BLS signature verification.

    BOOL quorumSignatureValidated = [DSBLSKey verify:self.commitmentHash signature:self.quorumThresholdSignature withPublicKey:self.quorumPublicKey];
    //    NSLog(@"validateQuorumCallback verify = %i, with: commitmentHash: %@, quorumThresholdSignature: %@, quorumPublicKey: %@", quorumSignatureValidated, uint256_hex(self.commitmentHash), uint768_hex(self.quorumThresholdSignature), uint384_hex(self.quorumPublicKey));

    if (!quorumSignatureValidated) {
        DSLog(@"Issue with quorumSignatureValidated");
        return NO;
    }
    //    NSLog(@"validateQuorumCallback true");

    self.verified = YES;

    return YES;
}

- (DSQuorumEntryEntity *)matchingQuorumEntryEntityInContext:(NSManagedObjectContext *)context {
    return [DSQuorumEntryEntity anyObjectInContext:context matching:@"quorumPublicKeyData == %@", uint384_data(self.quorumPublicKey)];
}

- (UInt256)orderingHashForRequestID:(UInt256)requestID forQuorumType:(DSLLMQType)quorumType {
    NSMutableData *data = [NSMutableData data];
    [data appendVarInt:quorumType];
    [data appendUInt256:self.quorumHash];
    [data appendUInt256:requestID];
    return [data SHA256_2];
}

+ (uint32_t)quorumSizeForType:(DSLLMQType)type {
    switch (type) { //!OCLINT
        case DSLLMQType_5_60:
            return 5;
        case DSLLMQType_10_60:
            return 10;
        case DSLLMQType_50_60:
            return 50;
        case DSLLMQType_400_60:
            return 400;
        case DSLLMQType_400_85:
            return 400;
        case DSLLMQType_100_67:
            return 100;
        case DSLLMQType_60_80:
            return 60;
        default:
            NSAssert(FALSE, @"Unknown quorum type");
            return 50;
    }
}

- (NSString *)description {
    uint32_t height = [self.chain heightForBlockHash:self.quorumHash];
    return [[super description] stringByAppendingString:[NSString stringWithFormat:@" - %u", height]];
}

- (NSString *)debugDescription {
    uint32_t height = [self.chain heightForBlockHash:self.quorumHash];
    return [[super debugDescription] stringByAppendingString:[NSString stringWithFormat:@" - %u", height]];
}

- (BOOL)isEqual:(id)object {
    if (self == object) return YES;
    if (![object isKindOfClass:[DSQuorumEntry class]]) return NO;
    return uint256_eq(self.quorumEntryHash, ((DSQuorumEntry *)object).quorumEntryHash);
}

- (NSUInteger)hash {
    return [uint256_data(self.quorumEntryHash) hash];
}

@end
