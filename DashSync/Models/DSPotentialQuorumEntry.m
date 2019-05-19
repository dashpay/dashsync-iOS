//
//  DSPotentialQuorumEntry.m
//  DashSync
//
//  Created by Sam Westrich on 4/25/19.
//

#import "DSPotentialQuorumEntry.h"
#import "NSData+Bitcoin.h"
#import "NSMutableData+Dash.h"
#import "DSChainManager.h"
#import "DSMasternodeManager.h"
#import "DSBLSKey.h"
#import "DSSimplifiedMasternodeEntry.h"

@interface DSPotentialQuorumEntry()

@property (nonatomic, assign) uint16_t version;
@property (nonatomic, assign) UInt256 quorumHash;
@property (nonatomic, assign) UInt384 quorumPublicKey;
@property (nonatomic, assign) UInt768 quorumThresholdSignature;
@property (nonatomic, assign) UInt256 quorumVerificationVectorHash;
@property (nonatomic, assign) UInt768 allCommitmentAggregatedSignature;
@property (nonatomic, assign) int32_t signersCount;
@property (nonatomic, assign) int16_t llmqType;
@property (nonatomic, assign) int32_t validMembersCount;
@property (nonatomic, strong) NSData * signersBitset;
@property (nonatomic, strong) NSData * validMembersBitset;
@property (nonatomic, assign) UInt256 commitmentHash;
@property (nonatomic, assign) uint32_t length;
@property (nonatomic, strong) DSChain * chain;
@property (nonatomic, assign) BOOL verified;

@end

@implementation DSPotentialQuorumEntry


+(instancetype)potentialQuorumEntryWithData:(NSData*)data dataOffset:(uint32_t)dataOffset onChain:(DSChain*)chain {
    return [[DSPotentialQuorumEntry alloc] initWithMessage:data dataOffset:dataOffset
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
    
    self.commitmentHash = [self.toData SHA256_2];
    
    self.chain = chain;
    
    self.verified = FALSE;
    
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

-(BOOL)validateWithMasternodeList:(NSMutableDictionary*)dictionary {
    
    DSMasternodeManager * masternodeManager = self.chain.chainManager.masternodeManager;
    
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
    
    NSArray<DSSimplifiedMasternodeEntry*> * masternodes = [masternodeManager masternodesForQuorumHash:self.llmqQuorumHash quorumCount:50];
    NSMutableArray * publicKeyArray = [NSMutableArray array];
    uint32_t i = 0;
    for (DSSimplifiedMasternodeEntry * masternodeEntry in masternodes) {
        if ([self.signersBitset bitIsTrueAtIndex:i] && [self.validMembersBitset bitIsTrueAtIndex:i]) {
            DSBLSKey * masternodePublicKey = [DSBLSKey blsKeyWithPublicKey:masternodeEntry.operatorPublicKey onChain:self.chain];
            [publicKeyArray addObject:masternodePublicKey];
        }
        i++;
    }
    DSBLSKey * blsKey = [DSBLSKey blsKeyByAggregatingPublicKeys:publicKeyArray onChain:self.chain];
    
    BOOL quorumSignatureValidated = [blsKey verify:self.commitmentHash signature:self.quorumThresholdSignature];
    
    if (!quorumSignatureValidated) return NO;
    
    //The sig must validate against the commitmentHash and all public keys determined by the signers bitvector. This is an aggregated BLS signature verification.
    
    //todo
    
    self.verified = YES;
    
    return YES;
        
}

@end
