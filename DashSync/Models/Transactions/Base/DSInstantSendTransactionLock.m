//
//  DSInstantSendTransactionLock.m
//  DashSync
//
//  Created by Sam Westrich on 4/5/19.
//

#import "DSInstantSendTransactionLock.h"
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
#import "DSInstantSendLockEntity+CoreDataClass.h"
#import "NSManagedObject+Sugar.h"
#import "DSBLSKey.h"

@interface DSInstantSendTransactionLock()

@property (nonatomic, strong) DSChain * chain;
@property (nonatomic, assign) UInt256 transactionHash;
@property (nonatomic, assign) UInt256 requestID;
@property (nonatomic, assign) UInt256 instantSendTransactionLockHash;
@property (nonatomic, strong) NSArray * inputOutpoints;
@property (nonatomic, assign) BOOL signatureVerified;
@property (nonatomic, assign) BOOL quorumVerified;
@property (nonatomic, strong) NSArray<DSSimplifiedMasternodeEntry*>* intendedQuorum;
@property (nonatomic, assign) BOOL saved;
@property (nonatomic, assign) UInt768 signature;

@end

@implementation DSInstantSendTransactionLock

+ (instancetype)instantSendTransactionLockWithMessage:(NSData *)message onChain:(DSChain*)chain {
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


-(UInt256)calculateInstantSendTransactionLockHash {
    //hash calculation
    NSMutableData * hashImportantData = [NSMutableData data];
    [hashImportantData appendVarInt:self.inputOutpoints.count];
    for (NSData * inputOutpoint in self.inputOutpoints) {
        [hashImportantData appendUTXO:inputOutpoint.transactionOutpoint];
    }
    [hashImportantData appendUInt256:self.transactionHash];
    return hashImportantData.SHA256_2;
}

-(UInt256)instantSendTransactionLockHash {
    if (uint256_is_zero(_instantSendTransactionLockHash)) {
        _instantSendTransactionLockHash = [self calculateInstantSendTransactionLockHash];
    }
    return _instantSendTransactionLockHash;
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
    if (![chain.chainManager.sporkManager deterministicMasternodeListEnabled] || ![chain.chainManager.sporkManager llmqInstantSendEnabled]) return nil;
    uint32_t off = 0;
    NSNumber * l = 0;
    uint64_t count = 0;
    self.signatureVerified = NO;
    self.quorumVerified = NO;
    @autoreleasepool {
        self.chain = chain;
        
        
        count = [message varIntAtOffset:off length:&l]; // input count

        off += l.unsignedIntegerValue;
        NSMutableArray * mutableInputOutpoints = [NSMutableArray array];
        for (NSUInteger i = 0; i < count; i++) { // inputs
            DSUTXO outpoint = [message transactionOutpointAtOffset:off];
            off += 36;
            [mutableInputOutpoints addObject:dsutxo_data(outpoint)];
        }
        self.inputOutpoints = [mutableInputOutpoints copy];
        
        self.transactionHash = [message UInt256AtOffset:off]; // tx
        //DSDLog(@"transactionHash is %@",uint256_reverse_hex(self.transactionHash));
        off += sizeof(UInt256);
        
        self.signature = [message UInt768AtOffset:off];
        NSAssert(!uint768_is_zero(self.signature), @"signature must be set");
        self.instantSendTransactionLockHash = [self instantSendTransactionLockHash];
    }
    
    return self;
}

- (instancetype)initWithTransactionHash:(UInt256)transactionHash withInputOutpoints:(NSArray*)inputOutpoints signatureVerified:(BOOL)signatureVerified quorumVerified:(BOOL)quorumVerified onChain:(DSChain*)chain {
    if (! (self = [self initOnChain:chain])) return nil;
    self.transactionHash = transactionHash;
    self.inputOutpoints = inputOutpoints;
    self.signatureVerified = signatureVerified;
    self.quorumVerified = quorumVerified;
    self.saved = YES; //this is coming already from the persistant store and not from the network
    return self;
}


-(UInt256)requestID {
    if (!uint256_is_zero(_requestID)) return _requestID;
    NSMutableData * data = [NSMutableData data];
    [data appendString:@"islock"];
    [data appendVarInt:self.inputOutpoints.count];
    for (NSData * input in self.inputOutpoints) {
        [data appendUTXO:[input transactionOutpoint]];
    }
    _requestID = [data SHA256_2];
    return _requestID;
}

- (BOOL)verifySignature {
    UInt384 publicKey = [self.chain.chainManager.masternodeManager quorumPublicKeyForInstantSendRequestID:[self requestID]];
    DSBLSKey * blsKey = [DSBLSKey blsKeyWithPublicKey:publicKey onChain:self.chain];
    DSDLog(@"verifying signature %@ with public key %@ for transaction hash %@",[NSData dataWithUInt768:self.signature].hexString, [NSData dataWithUInt384:publicKey].hexString, [NSData dataWithUInt256:self.transactionHash].hexString);
    self.signatureVerified = [blsKey verify:self.transactionHash signature:self.signature];
    return self.signatureVerified;
}



-(void)save {
    if (_saved) return;
    //saving here will only create, not update.
    NSManagedObjectContext * context = [DSTransactionEntity context];
    [context performBlockAndWait:^{ // add the transaction to core data
        [DSChainEntity setContext:context];
        [DSInstantSendLockEntity setContext:context];
        [DSTransactionHashEntity setContext:context];
        if ([DSInstantSendLockEntity countObjectsMatching:@"instantSendLockHash == %@", uint256_data(self.instantSendTransactionLockHash)] == 0) {
            DSInstantSendLockEntity * instantSendLockEntity = [DSInstantSendLockEntity managedObject];
            [instantSendLockEntity setAttributesFromInstantSendTransactionLock:self];
            [DSInstantSendLockEntity saveContext];
        }
    }];
    self.saved = YES;
}

@end
