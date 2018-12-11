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
#import "DSMasternodeManager.h"
#import "DSSimplifiedMasternodeEntry.h"
#import "NSMutableData+Dash.h"

@interface DSTransactionLockVote()

@property (nonatomic, strong) DSChain * chain;
@property (nonatomic, assign) UInt256 transactionHash;
@property (nonatomic, assign) DSUTXO transactionOutpoint;
@property (nonatomic, assign) DSUTXO masternodeOutpoint;
@property (nonatomic, assign) UInt256 quorumHash;
@property (nonatomic, assign) UInt256 confirmedHash;
@property (nonatomic, assign) UInt768 signature;
@property (nonatomic, assign) UInt256 transactionLockHash;
@property (nonatomic, assign) BOOL signatureVerified;
@property (nonatomic, readonly) DSSimplifiedMasternodeEntry * masternode;

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

-(UInt256)calculateTransactionLockHash {
    //hash calculation
    NSMutableData * hashImportantData = [NSMutableData data];
    [hashImportantData appendUInt256:self.transactionHash];
    [hashImportantData appendUTXO:self.transactionOutpoint];
    [hashImportantData appendUTXO:self.masternodeOutpoint];
    [hashImportantData appendUInt256:self.quorumHash];
    [hashImportantData appendUInt256:self.confirmedHash];
    return hashImportantData.SHA256_2;
}

-(UInt256)transactionLockHash {
    if (uint256_is_zero(_transactionLockHash)) {
        _transactionLockHash = [self calculateTransactionLockHash];
    }
    return _transactionLockHash;
}

-(DSSimplifiedMasternodeEntry*)masternode {
    DSMasternodeManager * masternodeManager = self.chain.chainManager.masternodeManager;
    return [masternodeManager masternodeHavingProviderRegistrationTransactionHash:uint256_data(self.masternodeOutpoint.hash)];
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
        self.transactionLockHash = [self transactionLockHash];
    }
    
    return self;
}

- (BOOL)verifySignature {
    if (!self.masternode) return NO;
    
    self.signatureVerified = [self.masternode verifySignature:self.signature forMessageDigest:self.transactionLockHash];
    return self.signatureVerified;
}

@end
