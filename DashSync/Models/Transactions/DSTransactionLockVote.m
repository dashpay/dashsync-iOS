//
//  DSTransactionLockVote.m
//  DashSync
//
//  Created by Sam Westrich on 11/20/18.
//

#import "DSTransactionLockVote.h"
#import "DSChain.h"
#import "NSData+Bitcoin.h"
#import "DSSporkManager.h"
#import "DSChainManager.h"

@interface DSTransactionLockVote()

@property (nonatomic, strong) DSChain * chain;
@property (nonatomic, assign) UInt256 transactionHash;
@property (nonatomic, assign) DSUTXO transactionOutpoint;
@property (nonatomic, assign) DSUTXO masternodeOutpoint;
@property (nonatomic, assign) UInt256 quorumHash;
@property (nonatomic, assign) UInt256 confirmedHash;
@property (nonatomic, assign) UInt768 signature;

@end

@implementation DSTransactionLockVote

+ (instancetype)transactionLockVoteWithMessage:(NSData *)message onChain:(DSChain*)chain {
    return [[self alloc] initWithMessage:message onChain:chain];
}

- (instancetype)init {
    if (! (self = [super init])) return nil;
    NSAssert(FALSE, @"this method is not supported");
    return self;
}

- (instancetype)initOnChain:(DSChain*)chain
{
    if (! (self = [super init])) return nil;
    
    self.chain = chain;
    return self;
}

//transaction hash (32)
//transaction outpoint (36)
//masternode outpoint (36)
//if spork 15 is active
//  quorum hash 32
//  confirmed hash 32
//masternode signature
//   size - varint
//   signature 65 or 96 depending on spork 15
- (instancetype)initWithMessage:(NSData *)message onChain:(DSChain *)chain
{
    if (! (self = [self initOnChain:chain])) return nil;
    if (![chain.chainManager.sporkManager deterministicMasternodeListEnabled]) return nil;
    uint32_t off = 0;
    
    @autoreleasepool {
        self.chain = chain;
        self.transactionHash = [message UInt256AtOffset:off]; // tx
        off += sizeof(UInt256);
        
        //not unspent, but same format
        DSUTXO transactionOutpoint;
        transactionOutpoint.hash = [message UInt256AtOffset:off]; // tx outpoint
        off += sizeof(UInt256);
        transactionOutpoint.n = [message UInt32AtOffset:off]; // tx outpoint
        off += sizeof(uint32_t);
        self.transactionOutpoint = transactionOutpoint;
        
        DSUTXO masternodeOutpoint;
        masternodeOutpoint.hash = [message UInt256AtOffset:off]; // tx outpoint
        off += sizeof(UInt256);
        masternodeOutpoint.n = [message UInt32AtOffset:off]; // tx outpoint
        off += sizeof(uint32_t);
        self.masternodeOutpoint = masternodeOutpoint;
        
        self.quorumHash = [message UInt256AtOffset:off]; // quorum hash
        off += sizeof(UInt256);
        
        self.confirmedHash = [message UInt256AtOffset:off]; // confirmedHash hash
        off += sizeof(UInt256);
        
        NSNumber * signatureLength = nil;
        uint64_t signatureSize = [message varIntAtOffset:off length:&signatureLength]; // confirmedHash hash
        off += [signatureLength integerValue];
        if (signatureSize != 96) return nil;
        self.signature = [message UInt768AtOffset:off];
    }
    
    return self;
}

@end
