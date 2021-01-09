//
//  DSQuorumCommitmentTransaction.m
//  DashSync
//
//  Created by Sam Westrich on 4/24/19.
//

#import "DSQuorumCommitmentTransaction.h"
#import "DSKey.h"
#import "DSQuorumCommitmentTransactionEntity+CoreDataClass.h"
#import "DSTransactionFactory.h"
#import "NSData+Bitcoin.h"
#import "NSMutableData+Dash.h"
#import "NSString+Dash.h"

@implementation DSQuorumCommitmentTransaction

- (instancetype)initWithMessage:(NSData *)message onChain:(DSChain *)chain {
    if (!(self = [super initWithMessage:message onChain:chain])) return nil;
    self.type = DSTransactionType_QuorumCommitment;
    NSUInteger length = message.length;
    uint32_t off = self.payloadOffset;

    if (length - off < 1) return nil;
    NSNumber *payloadLengthSize = nil;
    uint64_t payloadLength = [message varIntAtOffset:off length:&payloadLengthSize];
    off += payloadLengthSize.unsignedLongValue;

    if (length - off < 2) return nil;
    self.quorumCommitmentTransactionVersion = [message UInt16AtOffset:off];
    off += 2;

    if (length - off < 4) return nil;
    self.quorumCommitmentHeight = [message UInt32AtOffset:off];
    off += 4;

    if (length - off < 2) return nil;
    self.qfCommitVersion = [message UInt16AtOffset:off];
    off += 2;

    if (length - off < 1) return nil;
    self.llmqType = [message UInt8AtOffset:off];
    off += 1;

    if (length - off < 32) return nil;
    self.quorumHash = [message UInt256AtOffset:off];
    off += 32;

    if (length - off < 1) return nil;
    NSNumber *signersCountLengthSize = nil;
    self.signersCount = [message varIntAtOffset:off length:&signersCountLengthSize];
    off += signersCountLengthSize.unsignedLongValue;

    uint16_t signersBufferLength = ((self.signersCount + 7) / 8);

    if (length - off < signersBufferLength) return nil;
    self.signersBitset = [message subdataWithRange:NSMakeRange(off, signersBufferLength)];
    off += signersBufferLength;

    if (length - off < 1) return nil;
    NSNumber *validMembersCountLengthSize = nil;
    self.validMembersCount = [message varIntAtOffset:off length:&validMembersCountLengthSize];
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

    self.payloadOffset = off;

    //todo verify inputs hash

    if ([self payloadData].length != payloadLength) return nil;
    self.txHash = self.data.SHA256_2;

    return self;
}


- (instancetype)initWithInputHashes:(NSArray *)hashes inputIndexes:(NSArray *)indexes inputScripts:(NSArray *)scripts inputSequences:(NSArray *)inputSequences outputAddresses:(NSArray *)addresses outputAmounts:(NSArray *)amounts quorumCommitmentTransactionVersion:(uint16_t)version quorumCommitmentHeight:(uint32_t)quorumCommitmentHeight llmqType:(uint8_t)llmqType quorumHash:(UInt256)quorumHash signersCount:(uint16_t)signersCount signersBitset:(NSData *)signersBitset validMembersCount:(uint16_t)validMembersCount validMembersBitset:(NSData *)validMembersBitset quorumPublicKey:(UInt384)quorumPublicKey quorumVerificationVectorHash:(UInt256)quorumVerificationVectorHash quorumThresholdSignature:(UInt768)quorumThresholdSignature allCommitmentAggregatedSignature:(UInt768)allCommitmentAggregatedSignature onChain:(DSChain *_Nonnull)chain {
    if (!(self = [super initWithInputHashes:hashes inputIndexes:indexes inputScripts:scripts inputSequences:inputSequences outputAddresses:addresses outputAmounts:amounts onChain:chain])) return nil;
    self.type = DSTransactionType_QuorumCommitment;
    self.version = SPECIAL_TX_VERSION;
    self.quorumCommitmentTransactionVersion = version;
    self.quorumCommitmentHeight = quorumCommitmentHeight;
    self.llmqType = llmqType;
    self.quorumHash = quorumHash;
    self.signersCount = signersCount;
    self.signersBitset = signersBitset;
    self.validMembersCount = validMembersCount;
    self.validMembersBitset = validMembersBitset;
    self.quorumPublicKey = quorumPublicKey;
    self.quorumVerificationVectorHash = quorumVerificationVectorHash;
    self.quorumThresholdSignature = quorumThresholdSignature;
    self.allCommitmentAggregatedSignature = allCommitmentAggregatedSignature;

    return self;
}

- (NSData *)payloadData {
    NSMutableData *data = [NSMutableData data];
    [data appendUInt16:self.quorumCommitmentTransactionVersion];
    [data appendUInt32:self.quorumCommitmentHeight];
    [data appendUInt16:self.qfCommitVersion];
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

- (NSData *)toDataWithSubscriptIndex:(NSUInteger)subscriptIndex {
    NSMutableData *data = [[super toDataWithSubscriptIndex:subscriptIndex] mutableCopy];
    [data appendVarInt:self.payloadData.length];
    [data appendData:[self payloadData]];
    if (subscriptIndex != NSNotFound) [data appendUInt32:SIGHASH_ALL];
    return data;
}


- (size_t)size {
    if (!uint256_is_zero(self.txHash)) return self.data.length;
    return [super size] + [NSMutableData sizeOfVarInt:self.payloadData.length] + ([self payloadData].length);
}

- (BOOL)transactionTypeRequiresInputs {
    return NO;
}

- (Class)entityClass {
    return [DSQuorumCommitmentTransactionEntity class];
}

@end
