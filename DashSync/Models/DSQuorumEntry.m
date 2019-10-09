//
//  DSQuorumEntry.m
//  DashSync
//
//  Created by Sam Westrich on 4/25/19.
//

#import "DSQuorumEntry.h"
#import "NSData+Bitcoin.h"
#import "NSMutableData+Dash.h"
#import "DSChainManager.h"
#import "DSMasternodeManager.h"
#import "DSBLSKey.h"
#import "DSSimplifiedMasternodeEntry.h"
#import "DSMasternodeList.h"
#import "DSQuorumEntryEntity+CoreDataClass.h"
#import "NSManagedObject+Sugar.h"

@interface DSQuorumEntry()

@property (nonatomic, assign) uint16_t version;
@property (nonatomic, assign) UInt256 quorumHash;
@property (nonatomic, assign) UInt384 quorumPublicKey;
@property (nonatomic, assign) UInt768 quorumThresholdSignature;
@property (nonatomic, assign) UInt256 quorumVerificationVectorHash;
@property (nonatomic, assign) UInt768 allCommitmentAggregatedSignature;
@property (nonatomic, assign) int32_t signersCount;
@property (nonatomic, assign) DSLLMQType llmqType;
@property (nonatomic, assign) int32_t validMembersCount;
@property (nonatomic, strong) NSData * signersBitset;
@property (nonatomic, strong) NSData * validMembersBitset;
@property (nonatomic, assign) UInt256 quorumEntryHash;
@property (nonatomic, assign) UInt256 commitmentHash;
@property (nonatomic, assign) uint32_t length;
@property (nonatomic, strong) DSChain * chain;
@property (nonatomic, assign) BOOL verified;

@end

@implementation DSQuorumEntry

- (id)copyWithZone:(NSZone *)zone
{
    DSQuorumEntry * copy = [[[self class] alloc] init];

    if (copy) {
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
        
        
    }

    return copy;
}

+(instancetype)potentialQuorumEntryWithData:(NSData*)data dataOffset:(uint32_t)dataOffset onChain:(DSChain*)chain {
    return [[DSQuorumEntry alloc] initWithMessage:data dataOffset:dataOffset
                                            onChain:chain];
}

-(instancetype)initWithMessage:(NSData*)message dataOffset:(uint32_t)dataOffset onChain:(DSChain*)chain {
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
    
    self.length = off - dataOffset;
    
    self.quorumEntryHash = [self.toData SHA256_2];
    
    self.chain = chain;
    self.verified = FALSE;
    
    return self;
}

-(instancetype)initWithVersion:(uint16_t)version type:(DSLLMQType)type quorumHash:(UInt256)quorumHash quorumPublicKey:(UInt384)quorumPublicKey commitmentHash:(UInt256)commitmentHash verified:(BOOL)verified onChain:(DSChain*)chain {
    if (!(self = [super init])) return nil;
    
    self.llmqType = type;
    self.version = version;
    self.quorumHash = quorumHash;
    self.quorumPublicKey = quorumPublicKey;
    self.quorumEntryHash = commitmentHash;
    self.verified = verified;
    self.chain = chain;
    
    return self;
}

-(NSData*)toData {
    NSMutableData * data = [NSMutableData data];
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

-(UInt256)commitmentHash {
    if (uint256_is_zero(_commitmentHash)) {
        _commitmentHash = [[self commitmentData] SHA256_2];
    }
    return _commitmentHash;
}

-(NSData*)commitmentData {
    
        NSMutableData * data = [NSMutableData data];
        [data appendVarInt:self.llmqType];
        [data appendUInt256:self.quorumHash];
        [data appendVarInt:self.validMembersCount];
        [data appendData:self.validMembersBitset];
        [data appendUInt384:self.quorumPublicKey];
        [data appendUInt256:self.quorumVerificationVectorHash];
    return data;
}

-(uint32_t)quorumThreshold {
    switch (self.llmqType) {
        case 1:
            return 30;
            break;
        case 2:
            return 240;
            break;
        case 3:
            return 340;
            break;
        case 100:
            return 3;
            break;
        default:
            NSAssert(FALSE, @"Unknown llmq type");
            return UINT32_MAX;
            break;
    }
}

-(UInt256)llmqQuorumHash {
    NSMutableData * data = [NSMutableData data];
    [data appendVarInt:self.llmqType];
    [data appendUInt256:self.quorumHash];
    return [data SHA256_2];
}

-(BOOL)validateWithMasternodeList:(DSMasternodeList*)masternodeList {
    
    if (!masternodeList) {
        DSDLog(@"Trying to validate a quorum without a masternode list");
        return NO;
    }
    
    //The quorumHash must match the current DKG session
    //todo
    
    //The byte size of the signers and validMembers bitvectors must match “(quorumSize + 7) / 8”
    if (self.signersBitset.length != (self.signersCount + 7)/8) return NO;
    if (self.validMembersBitset.length != (self.validMembersCount + 7)/8) return NO;
    
    //No out-of-range bits should be set in byte representation of the signers and validMembers bitvectors
    uint32_t signersOffset = self.signersCount/8;
    uint8_t signersLastByte = [self.signersBitset UInt8AtOffset:signersOffset];
    uint8_t signersMask = UINT8_MAX >> (8 - signersOffset) << (8 - signersOffset);
    if (signersLastByte & signersMask) return NO;
    
    uint32_t validMembersOffset = self.validMembersCount/8;
    uint8_t validMembersLastByte = [self.validMembersBitset UInt8AtOffset:validMembersOffset];
    uint8_t validMembersMask = UINT8_MAX >> (8 - validMembersOffset) << (8 - validMembersOffset);
    if (validMembersLastByte & validMembersMask) return NO;
    
    //The number of set bits in the signers and validMembers bitvectors must be at least >= quorumThreshold
    
    if ([self.signersBitset trueBitsCount] < [self quorumThreshold]) return NO;
    if ([self.validMembersBitset trueBitsCount] < [self quorumThreshold]) return NO;
    
    //The quorumSig must validate against the quorumPublicKey and the commitmentHash. As this is a recovered threshold signature, normal signature verification can be performed, without the need of the full quorum verification vector. The commitmentHash is calculated in the same way as in the commitment phase.
    
    NSArray<DSSimplifiedMasternodeEntry*> * masternodes = [masternodeList masternodesForQuorumModifier:self.llmqQuorumHash quorumCount:[DSQuorumEntry quorumSizeForType:self.llmqType]];
    NSMutableArray * publicKeyArray = [NSMutableArray array];
    uint32_t i = 0;
    DSMerkleBlock * block = [self.chain blockForBlockHash:masternodeList.blockHash];
    for (DSSimplifiedMasternodeEntry * masternodeEntry in masternodes) {
        if ([self.signersBitset bitIsTrueAtIndex:i]) {
            DSBLSKey * masternodePublicKey = [DSBLSKey blsKeyWithPublicKey:[masternodeEntry operatorPublicKeyAtBlock:block] onChain:self.chain];
            [publicKeyArray addObject:masternodePublicKey];
        }
        i++;
    }
    
    BOOL allCommitmentAggregatedSignatureValidated = [DSBLSKey verifySecureAggregated:self.commitmentHash signature:self.allCommitmentAggregatedSignature withPublicKeys:publicKeyArray];
    
    if (!allCommitmentAggregatedSignatureValidated) {
        DSDLog(@"Issue with allCommitmentAggregatedSignatureValidated for quorum at height %u",masternodeList.height);
        return NO;
    }
    
    //The sig must validate against the commitmentHash and all public keys determined by the signers bitvector. This is an aggregated BLS signature verification.
    
    BOOL quorumSignatureValidated = [DSBLSKey verify:self.commitmentHash signature:self.quorumThresholdSignature withPublicKey:self.quorumPublicKey];
    
    if (!quorumSignatureValidated) {
        DSDLog(@"Issue with quorumSignatureValidated");
        return NO;
    }
    
    self.verified = YES;
    
    return YES;
        
}

-(DSQuorumEntryEntity*)matchingQuorumEntryEntity {
    return [DSQuorumEntryEntity anyObjectMatching:@"quorumPublicKeyData == %@",uint384_data(self.quorumPublicKey)];
}

- (UInt256)orderingHashForRequestID:(UInt256)requestID {
    NSMutableData * data = [NSMutableData data];
    [data appendVarInt:1];
    [data appendUInt256:self.quorumHash];
    [data appendUInt256:requestID];
    return [data SHA256_2];
}

+(uint32_t)quorumSizeForType:(DSLLMQType)type {
    switch (type) {
        case DSLLMQType_5_60:
            return 5;
        case DSLLMQType_50_60:
            return 50;
        case DSLLMQType_400_60:
            return 400;
        case DSLLMQType_400_85:
            return 400;
        default:
            NSAssert(FALSE, @"Unknown quorum type");
            return 50;
            break;
    }
}

-(NSString*)description {
    uint32_t height = [self.chain heightForBlockHash:self.quorumHash];
    return [[super description] stringByAppendingString:[NSString stringWithFormat:@" - %u",height]];
}

-(NSString*)debugDescription {
    uint32_t height = [self.chain heightForBlockHash:self.quorumHash];
    return [[super debugDescription] stringByAppendingString:[NSString stringWithFormat:@" - %u",height]];
}

-(BOOL)isEqual:(id)object {
    if (self == object) return YES;
    if (![object isKindOfClass:[DSQuorumEntry class]]) return NO;
    return uint256_eq(self.quorumEntryHash, ((DSQuorumEntry*)object).quorumEntryHash);
}

-(NSUInteger)hash {
    return [uint256_data(self.quorumEntryHash) hash];
}

@end
