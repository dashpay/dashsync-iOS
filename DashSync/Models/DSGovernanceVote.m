//
//  DSGovernanceObjectVote.m
//  DashSync
//
//  Created by Sam Westrich on 6/12/18.
//

#import "DSGovernanceVote.h"
#import "NSData+Bitcoin.h"
#import "NSData+Dash.h"
#import "DSChain.h"

@interface DSGovernanceVote()

@property (nonatomic,strong) DSGovernanceObject * governanceObject;
@property (nonatomic,strong) DSMasternodeBroadcast * masternodeBroadcast;
@property (nonatomic,assign) uint32_t outcome;
@property (nonatomic,assign) uint32_t signal;
@property (nonatomic, strong) DSChain * chain;
@property (nonatomic,assign) UInt256 parentHash;
@property (nonatomic,assign) UInt256 governanceVoteHash;

@end

@implementation DSGovernanceVote

// From the reference
//uint256 GetHash() const
//{
//    CHashWriter ss(SER_GETHASH, PROTOCOL_VERSION);
//    ss << vinMasternode;
//    ss << nParentHash;
//    ss << nVoteSignal;
//    ss << nVoteOutcome;
//    ss << nTime;
//    return ss.GetHash();
//}

+(UInt256)hashWithParentHash:(NSData*)parentHashData voteCreationTimestamp:(uint64_t)voteCreationTimestamp voteSignal:(uint32_t)voteSignal voteOutcome:(uint32_t)voteOutcome masternodeUTXO:(DSUTXO)masternodeUTXO {
    //hash calculation
    NSMutableData * hashImportantData = [NSMutableData data];
    
    uint32_t index = (uint32_t)masternodeUTXO.n;
    [hashImportantData appendData:[NSData dataWithUInt256:masternodeUTXO.hash]];
    [hashImportantData appendBytes:&index length:4];
    uint8_t emptyByte = 0;
    uint32_t fullBits = UINT32_MAX;
    [hashImportantData appendBytes:&emptyByte length:1];
    [hashImportantData appendBytes:&fullBits length:4];
    [hashImportantData appendData:parentHashData];
    [hashImportantData appendBytes:&voteSignal length:4];
    [hashImportantData appendBytes:&voteOutcome length:4];
    [hashImportantData appendBytes:&voteCreationTimestamp length:8];

    return hashImportantData.SHA256_2;
}

+(DSGovernanceVote* _Nullable)governanceVoteFromMessage:(NSData * _Nonnull)message onChain:(DSChain* _Nonnull)chain {
    NSUInteger length = message.length;
    NSUInteger offset = 0;
    
    DSUTXO masternodeUTXO;
    if (length - offset < 32) return nil;
    masternodeUTXO.hash = [message UInt256AtOffset:offset];
    offset += 32;
    if (length - offset < 4) return nil;
    masternodeUTXO.n = [message UInt32AtOffset:offset];
    offset += 4;
    if (length - offset < 1) return nil;
    uint8_t sigscriptSize = [message UInt8AtOffset:offset];
    offset += 1;
    if (length - offset < sigscriptSize) return nil;
    //NSData * sigscript = [message subdataWithRange:NSMakeRange(offset, sigscriptSize)];
    offset += sigscriptSize;
    if (length - offset < 4) return nil;
    //uint32_t sequenceNumber = [message UInt32AtOffset:offset];
    offset += 4;
    
    if (length - offset < 32) return nil;
    NSData * parentHashData = [message subdataWithRange:NSMakeRange(offset, 32)];
    UInt256 parentHash = [message UInt256AtOffset:offset];
    offset += 32;
    if (length - offset < 4) return nil;
    uint32_t voteOutcome = [message UInt32AtOffset:offset];
    offset += 4;
    if (length - offset < 4) return nil;
    uint32_t voteSignal = [message UInt32AtOffset:offset];
    offset += 4;
    if (length - offset < 4) return nil;
    uint64_t voteCreationTimestamp = [message UInt64AtOffset:offset];
    offset += 8;
    
    if (length - offset < 1) return nil;
    uint8_t messageSignatureSize = [message UInt8AtOffset:offset];
    offset += 1;
    if (length - offset < messageSignatureSize) return nil;
    NSData * messageSignature = [message subdataWithRange:NSMakeRange(offset, messageSignatureSize)];
    offset+= messageSignatureSize;
    
    
    UInt256 governanceVoteHash = [self hashWithParentHash:parentHashData voteCreationTimestamp:voteCreationTimestamp voteSignal:voteSignal voteOutcome:voteOutcome masternodeUTXO:masternodeUTXO];
    
    DSGovernanceVote * governanceVote = [[DSGovernanceVote alloc] initWithParentHash:parentHash voteOutcome:voteOutcome voteSignal:voteSignal governanceVoteHash:governanceVoteHash onChain:chain];
    return governanceVote;
    
}

-(instancetype)initWithParentHash:(UInt256)parentHash voteOutcome:(uint32_t)voteOutcome voteSignal:(uint32_t)voteSignal governanceVoteHash:(UInt256)governanceVoteHash onChain:(DSChain* _Nonnull)chain {
    if (!(self = [super init])) return nil;
    self.outcome = voteOutcome;
    self.signal = voteSignal;
    self.chain = chain;
    self.parentHash = parentHash;
    self.governanceVoteHash = governanceVoteHash;

    return self;
}

@end
