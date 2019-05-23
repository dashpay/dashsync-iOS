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
#import "DSTransactionEntity+CoreDataClass.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSTransactionHashEntity+CoreDataClass.h"
#import "DSTransactionLockVoteEntity+CoreDataClass.h"
#import "NSManagedObject+Sugar.h"
#import "DSMasternodeList.h"

@interface DSTransactionLockVote()

@property (nonatomic, strong) DSChain * chain;
@property (nonatomic, assign) UInt256 transactionHash;
@property (nonatomic, assign) DSUTXO transactionOutpoint;
@property (nonatomic, assign) DSUTXO masternodeOutpoint;
@property (nonatomic, assign) UInt256 masternodeProviderTransactionHash;
@property (nonatomic, assign) UInt256 quorumModifierHash;
@property (nonatomic, assign) UInt256 quorumVerifiedAtBlockHash;
@property (nonatomic, assign) UInt768 signature;
@property (nonatomic, assign) UInt256 transactionLockVoteHash;
@property (nonatomic, assign) BOOL signatureVerified;
@property (nonatomic, assign) BOOL quorumVerified;
@property (nonatomic, assign) BOOL saved;

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

-(UInt256)calculateTransactionLockVoteHash {
    //hash calculation
    NSMutableData * hashImportantData = [NSMutableData data];
    [hashImportantData appendUInt256:self.transactionHash];
    [hashImportantData appendUTXO:self.transactionOutpoint];
    [hashImportantData appendUTXO:self.masternodeOutpoint];
    [hashImportantData appendUInt256:self.quorumModifierHash];
    [hashImportantData appendUInt256:self.masternodeProviderTransactionHash];
    return hashImportantData.SHA256_2;
}

-(UInt256)transactionLockVoteHash {
    if (uint256_is_zero(_transactionLockVoteHash)) {
        _transactionLockVoteHash = [self calculateTransactionLockVoteHash];
    }
    return _transactionLockVoteHash;
}

-(DSSimplifiedMasternodeEntry*)masternode {
    DSMasternodeManager * masternodeManager = self.chain.chainManager.masternodeManager;
    return [masternodeManager masternodeHavingProviderRegistrationTransactionHash:uint256_data(self.masternodeProviderTransactionHash).reverse];
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
    self.signatureVerified = NO;
    self.quorumVerified = NO;
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
        
        self.quorumModifierHash = [message UInt256AtOffset:off]; // quorum hash
        off += sizeof(UInt256);
        
        self.masternodeProviderTransactionHash = [message UInt256AtOffset:off]; // confirmedHash hash
        off += sizeof(UInt256);
        

        
        NSNumber * signatureLength = nil;
        uint64_t signatureSize = [message varIntAtOffset:off length:&signatureLength]; // signature
        off += [signatureLength integerValue];
        if (signatureSize != 96) return nil;
        self.signature = [message UInt768AtOffset:off];
        self.transactionLockVoteHash = [self transactionLockVoteHash];
    }
    
    return self;
}

- (instancetype)initWithTransactionHash:(UInt256)transactionHash transactionOutpoint:(DSUTXO)transactionOutpoint masternodeOutpoint:(DSUTXO)masternodeOutpoint masternodeProviderTransactionHash:(UInt256)masternodeProviderTransactionHash quorumModifierHash:(UInt256)quorumModifierHash quorumVerifiedAtBlockHash:(UInt256)quorumVerifiedAtBlockHash signatureVerified:(BOOL)signatureVerified quorumVerified:(BOOL)quorumVerified onChain:(DSChain*)chain {
    if (! (self = [self initOnChain:chain])) return nil;
    self.transactionHash = transactionHash;
    self.transactionOutpoint = transactionOutpoint;
    self.masternodeOutpoint = masternodeOutpoint;
    self.masternodeProviderTransactionHash = masternodeProviderTransactionHash;
    self.quorumVerifiedAtBlockHash = quorumVerifiedAtBlockHash;
    self.signatureVerified = signatureVerified;
    self.quorumVerified = quorumVerified;
    self.quorumModifierHash = quorumModifierHash;
    self.saved = YES; //this is coming already from the persistant store and not from the network
    return self;
}

- (BOOL)verifySignature {
    if (!self.masternode) return NO;
    
    self.signatureVerified = [self.masternode verifySignature:self.signature forMessageDigest:self.transactionLockVoteHash];
    return self.signatureVerified;
}

- (BOOL)verifySentByIntendedQuorum {
    if (!self.masternode) return NO;
    self.quorumVerified = [self.intendedQuorum containsObject:self.masternode];
    return self.quorumVerified;
}

-(NSArray<DSSimplifiedMasternodeEntry*>*)intendedQuorum {
    if (!self.masternode) return nil;
    DSMasternodeManager * masternodeManager = self.chain.chainManager.masternodeManager;
    return [masternodeManager.currentMasternodeList masternodesForQuorumHash:self.quorumModifierHash quorumCount:10];
}

-(void)save {
    if (_saved) return;
    //saving here will only create, not update.
    NSManagedObjectContext * context = [DSTransactionEntity context];
    [context performBlockAndWait:^{ // add the transaction to core data
        [DSChainEntity setContext:context];
        [DSTransactionLockVoteEntity setContext:context];
        [DSTransactionHashEntity setContext:context];
        if ([DSTransactionLockVoteEntity countObjectsMatching:@"transactionLockVoteHash == %@", uint256_data(self.transactionLockVoteHash)] == 0) {
            DSTransactionLockVoteEntity * transactionLockVoteEntity = [DSTransactionLockVoteEntity managedObject];
            [transactionLockVoteEntity setAttributesFromTransactionLockVote:self];
            [DSTransactionLockVoteEntity saveContext];
        }
    }];
    self.saved = YES;
}

@end
