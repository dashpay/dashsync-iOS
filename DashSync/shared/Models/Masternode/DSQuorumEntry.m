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

+ (instancetype)potentialQuorumEntryWithData:(NSData *)data dataOffset:(uint32_t)dataOffset onChain:(DSChain *)chain {
    return [[DSQuorumEntry alloc] initWithMessage:data
                                       dataOffset:dataOffset
                                          onChain:chain];
}

- (instancetype)initWithMessage:(NSData *)message dataOffset:(uint32_t)dataOffset onChain:(DSChain *)chain {
    if (!(self = [super init])) return nil;
    NSUInteger length = message.length;
    uint32_t off = dataOffset;

    if (length - off < 2) return nil;
    self.version = [message UInt16AtOffset:off];
    off += 2;

    if (length - off < 1) return nil;
    self.llmqType = [message UInt8AtOffset:off];
    off += 1;

    if (length - off < 32) return nil;
    self.quorumHash = [message UInt256AtOffset:off];
    off += 32;

    if (length - off < 1) return nil;
    NSNumber *signersCountLengthSize = nil;
    self.signersCount = (uint32_t)[message varIntAtOffset:off length:&signersCountLengthSize];
    off += signersCountLengthSize.unsignedLongValue;

    uint16_t signersBufferLength = ((self.signersCount + 7) / 8);

    if (length - off < signersBufferLength) return nil;
    self.signersBitset = [message subdataWithRange:NSMakeRange(off, signersBufferLength)];
    off += signersBufferLength;

    if (length - off < 1) return nil;
    NSNumber *validMembersCountLengthSize = nil;
    self.validMembersCount = (uint32_t)[message varIntAtOffset:off length:&validMembersCountLengthSize];
    off += validMembersCountLengthSize.unsignedLongValue;

    uint16_t validMembersCountBufferLength = ((self.validMembersCount + 7) / 8);

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

    self.length = off - dataOffset;

    self.quorumEntryHash = [self.toData SHA256_2];

    self.chain = chain;
    self.verified = FALSE;

    return self;
}

- (instancetype)initWithVersion:(uint16_t)version type:(DSLLMQType)type quorumHash:(UInt256)quorumHash quorumPublicKey:(UInt384)quorumPublicKey quorumEntryHash:(UInt256)quorumEntryHash verified:(BOOL)verified onChain:(DSChain *)chain {
    if (!(self = [super init])) return nil;

    self.llmqType = type;
    self.version = version;
    self.quorumHash = quorumHash;
    self.quorumPublicKey = quorumPublicKey;
    self.quorumEntryHash = quorumEntryHash;
    self.verified = verified;
    self.chain = chain;
    self.saved = TRUE;

    return self;
}
- (instancetype)initWithEntry:(QuorumEntry *)entry onChain:(DSChain *)chain {
    if (!(self = [super init])) return nil;
    self.allCommitmentAggregatedSignature = [NSData dataWithBytes:entry->quorum_hash length:96].UInt768;
    if (entry->commitment_hash_exists) {
        self.commitmentHash = [NSData dataWithBytes:entry->commitment_hash length:32].UInt256;
    }
    self.length = (uint32_t)entry->length;
    self.llmqType = (DSLLMQType)entry->llmq_type;
    self.quorumEntryHash = [NSData dataWithBytes:entry->quorum_entry_hash length:32].UInt256;
    self.quorumHash = [NSData dataWithBytes:entry->quorum_hash length:32].UInt256;
    self.quorumPublicKey = [NSData dataWithBytes:entry->quorum_public_key length:48].UInt384;
    self.quorumThresholdSignature = [NSData dataWithBytes:entry->quorum_threshold_signature length:96].UInt768;
    self.quorumVerificationVectorHash = [NSData dataWithBytes:entry->quorum_verification_vector_hash length:32].UInt256;
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
        _commitmentHash = [[self commitmentData] SHA256_2];
    }
    return _commitmentHash;
}

- (NSData *)commitmentData {
    NSMutableData *data = [NSMutableData data];
    [data appendVarInt:self.llmqType];
    [data appendUInt256:self.quorumHash];
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

- (BOOL)validateWithMasternodeList:(DSMasternodeList *)masternodeList blockHeightLookup:(uint32_t (^)(UInt256 blockHash))blockHeightLookup {
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
            DSBLSKey *masternodePublicKey = [DSBLSKey keyWithPublicKey:[masternodeEntry operatorPublicKeyAtBlockHeight:blockHeight]];
            [publicKeyArray addObject:masternodePublicKey];
#if SAVE_QUORUM_ERROR_PUBLIC_KEY_ARRAY_TO_FILE
            [proTxHashForPublicKeys setObject:uint256_data(masternodeEntry.providerRegistrationTransactionHash)
                                       forKey:uint384_data(masternodePublicKey.publicKey)];
#endif
        }
        i++;
    }

    BOOL allCommitmentAggregatedSignatureValidated = [DSBLSKey verifySecureAggregated:self.commitmentHash signature:self.allCommitmentAggregatedSignature withPublicKeys:publicKeyArray];


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
            NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
            NSString *documentsDirectory = [paths objectAtIndex:0];
            NSString *dataPath = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"MNL_QUORUM_ERROR_KEYS_%d.txt", masternodeList.height]];

            // Save it into file system
            [message writeToFile:dataPath atomically:YES];
        }
#endif
#if SAVE_MNL_ERROR_TO_FILE
        {
            NSMutableData *message = [NSMutableData data];
            for (DSSimplifiedMasternodeEntry *simplifiedMasternodeEntry in allMasternodes) {
                NSString *line = [NSString stringWithFormat:@"%@ -> %@\n", uint256_hex(simplifiedMasternodeEntry.providerRegistrationTransactionHash), [simplifiedMasternodeEntry isValidAtBlockHeight:masternodeList.height] ? @"VALID" : @"NOT VALID"];
                [message appendData:[line dataUsingEncoding:NSUTF8StringEncoding]];
            }
            NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
            NSString *documentsDirectory = [paths objectAtIndex:0];
            NSString *dataPath = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"MNL_QUORUM_ERROR_MNS_%d.txt", masternodeList.height]];

            // Save it into file system
            [message writeToFile:dataPath atomically:YES];
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
            NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
            NSString *documentsDirectory = [paths objectAtIndex:0];
            NSString *dataPath = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"MNL_QUORUM_NO_ERROR_KEYS_%d.txt", masternodeList.height]];

            // Save it into file system
            [message writeToFile:dataPath atomically:YES];
        }
#endif
#if SAVE_MNL_ERROR_TO_FILE
        if (MASTERNODELIST_HEIGHT_TO_SAVE_DATA == masternodeList.height) {
            NSMutableData *message = [NSMutableData data];
            for (DSSimplifiedMasternodeEntry *simplifiedMasternodeEntry in allMasternodes) {
                NSString *line = [NSString stringWithFormat:@"%@ -> %@\n", uint256_hex(simplifiedMasternodeEntry.providerRegistrationTransactionHash), [simplifiedMasternodeEntry isValidAtBlockHeight:masternodeList.height] ? @"VALID" : @"NOT VALID"];
                [message appendData:[line dataUsingEncoding:NSUTF8StringEncoding]];
            }
            NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
            NSString *documentsDirectory = [paths objectAtIndex:0];
            NSString *dataPath = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"MNL_QUORUM_NO_ERROR_MNS_%d.txt", masternodeList.height]];

            // Save it into file system
            [message writeToFile:dataPath atomically:YES];
        }
#endif
    }
#endif

    //The sig must validate against the commitmentHash and all public keys determined by the signers bitvector. This is an aggregated BLS signature verification.

    BOOL quorumSignatureValidated = [DSBLSKey verify:self.commitmentHash signature:self.quorumThresholdSignature withPublicKey:self.quorumPublicKey];

    if (!quorumSignatureValidated) {
        DSLog(@"Issue with quorumSignatureValidated");
        return NO;
    }

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
