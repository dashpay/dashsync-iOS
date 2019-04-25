//
//  DSPotentialQuorumEntry.m
//  DashSync
//
//  Created by Sam Westrich on 4/25/19.
//

#import "DSPotentialQuorumEntry.h"
#import "NSData+Bitcoin.h"

@interface DSPotentialQuorumEntry()

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
@property (nonatomic, assign) uint32_t length;

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
    
    return self;
}

@end
