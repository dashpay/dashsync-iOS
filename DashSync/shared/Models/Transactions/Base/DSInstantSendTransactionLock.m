//
//  DSInstantSendTransactionLock.m
//  DashSync
//
//  Created by Sam Westrich on 4/5/19.
//

#import "DSInstantSendTransactionLock.h"
#import "DSBLSKey.h"
#import "DSChain.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSChainManager.h"
#import "DSInstantSendLockEntity+CoreDataClass.h"
#import "DSMasternodeList.h"
#import "DSMasternodeManager.h"
#import "DSQuorumEntry.h"
#import "DSSimplifiedMasternodeEntry.h"
#import "DSSporkManager.h"
#import "DSTransactionEntity+CoreDataClass.h"
#import "DSTransactionHashEntity+CoreDataClass.h"
#import "NSData+Dash.h"
#import "NSManagedObject+Sugar.h"
#import "NSMutableData+Dash.h"

@interface DSInstantSendTransactionLock ()

@property (nonatomic, strong) DSChain *chain;
@property (nonatomic, assign) uint8_t version;
@property (nonatomic, assign) UInt256 transactionHash;
@property (nonatomic, assign) UInt256 requestID;
@property (nonatomic, assign) UInt256 cycleHash;
@property (nonatomic, strong) NSArray *inputOutpoints;
@property (nonatomic, assign) BOOL signatureVerified;
@property (nonatomic, assign) BOOL quorumVerified;
@property (nonatomic, strong) DSQuorumEntry *intendedQuorum;
@property (nonatomic, assign) BOOL saved;
@property (nonatomic, assign) UInt768 signature;

@end

@implementation DSInstantSendTransactionLock

+ (instancetype)instantSendTransactionLockWithNonDeterministicMessage:(NSData *)message onChain:(DSChain *)chain {
    return [[self alloc] initWithNonDeterministicMessage:message onChain:chain];
}

+ (instancetype)instantSendTransactionLockWithDeterministicMessage:(NSData *)message onChain:(DSChain *)chain {
    return [[self alloc] initWithDeterministicMessage:message onChain:chain];
}

- (instancetype)init {
    if (!(self = [super init])) return nil;
    NSAssert(FALSE, @"this method is not supported");
    return self;
}

- (instancetype)initOnChain:(DSChain *)chain {
    if (!(self = [super init])) return nil;

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
- (instancetype)initWithNonDeterministicMessage:(NSData *)message onChain:(DSChain *)chain {
    if (!(self = [self initOnChain:chain])) return nil;
    if (![chain.chainManager.sporkManager deterministicMasternodeListEnabled] || ![chain.chainManager.sporkManager llmqInstantSendEnabled]) return nil;
    uint32_t off = 0;
    NSNumber *l = 0;
    uint64_t count = 0;
    self.signatureVerified = NO;
    self.quorumVerified = NO;
    @autoreleasepool {
        self.chain = chain;


        count = [message varIntAtOffset:off length:&l]; // input count

        off += l.unsignedIntegerValue;
        NSMutableArray *mutableInputOutpoints = [NSMutableArray array];
        for (NSUInteger i = 0; i < count; i++) { // inputs
            DSUTXO outpoint = [message transactionOutpointAtOffset:off];
            off += 36;
            [mutableInputOutpoints addObject:dsutxo_data(outpoint)];
        }
        self.inputOutpoints = [mutableInputOutpoints copy];

        self.transactionHash = [message UInt256AtOffset:off]; // tx
        //DSLogPrivate(@"transactionHash is %@",uint256_reverse_hex(self.transactionHash));
        off += sizeof(UInt256);

        self.signature = [message UInt768AtOffset:off];
        NSAssert(uint768_is_not_zero(self.signature), @"signature must be set");
    }

    return self;
}

- (instancetype)initWithDeterministicMessage:(NSData *)message onChain:(DSChain *)chain {
    if (!(self = [self initOnChain:chain])) return nil;
    if (![chain.chainManager.sporkManager deterministicMasternodeListEnabled] || ![chain.chainManager.sporkManager llmqInstantSendEnabled]) return nil;
    NSUInteger off = 0;
    NSNumber *l = 0;
    uint64_t count = 0;
    self.version = [message readUInt8AtOffset:&off];
    self.signatureVerified = NO;
    self.quorumVerified = NO;
    @autoreleasepool {
        self.chain = chain;


        count = [message varIntAtOffset:off length:&l]; // input count

        off += l.unsignedIntegerValue;
        NSMutableArray *mutableInputOutpoints = [NSMutableArray array];
        for (NSUInteger i = 0; i < count; i++) { // inputs
            DSUTXO outpoint = [message transactionOutpointAtOffset:off];
            off += 36;
            [mutableInputOutpoints addObject:dsutxo_data(outpoint)];
        }
        self.inputOutpoints = [mutableInputOutpoints copy];

        self.transactionHash = [message readUInt256AtOffset:&off]; // tx
        //DSLogPrivate(@"transactionHash is %@",uint256_reverse_hex(self.transactionHash));

        self.cycleHash = [message readUInt256AtOffset:&off]; // tx
        
        self.signature = [message UInt768AtOffset:off];
        NSAssert(uint768_is_not_zero(self.signature), @"signature must be set");
    }

    return self;
}

- (NSData *)toData {
    NSMutableData *mData = [NSMutableData data];
    [mData appendVarInt:self.inputOutpoints.count];
    for (NSData *inputOutpoints in self.inputOutpoints) {
        [mData appendUTXO:inputOutpoints.transactionOutpoint];
    }
    [mData appendUInt256:self.transactionHash];
    [mData appendUInt768:self.signature];
    return [mData copy];
}

- (instancetype)initWithTransactionHash:(UInt256)transactionHash withInputOutpoints:(NSArray *)inputOutpoints signature:(UInt768)signature signatureVerified:(BOOL)signatureVerified quorumVerified:(BOOL)quorumVerified onChain:(DSChain *)chain {
    if (!(self = [self initOnChain:chain])) return nil;
    self.transactionHash = transactionHash;
    self.inputOutpoints = inputOutpoints;
    self.signatureVerified = signatureVerified;
    self.signature = signature;
    self.quorumVerified = quorumVerified;
    self.saved = YES; //this is coming already from the persistant store and not from the network
    return self;
}


- (UInt256)requestID {
    if (uint256_is_not_zero(_requestID)) return _requestID;
    NSMutableData *data = [NSMutableData data];
    [data appendString:@"islock"];
    [data appendVarInt:self.inputOutpoints.count];
    for (NSData *input in self.inputOutpoints) {
        [data appendData:input];
    }
    _requestID = [data SHA256_2];
    DSLogPrivate(@"the request ID is %@", uint256_hex(_requestID));
    return _requestID;
}

- (UInt256)signIDForQuorumEntry:(DSQuorumEntry *)quorumEntry {
    NSMutableData *data = [NSMutableData data];
    [data appendVarInt:self.chain.quorumTypeForISLocks];
    [data appendUInt256:quorumEntry.quorumHash];
    [data appendUInt256:self.requestID];
    [data appendUInt256:self.transactionHash];
    return [data SHA256_2];
}

- (BOOL)verifySignatureAgainstQuorum:(DSQuorumEntry *)quorumEntry {
    UInt384 publicKey = quorumEntry.quorumPublicKey;
    DSBLSKey *blsKey = [DSBLSKey keyWithPublicKey:publicKey];
    UInt256 signId = [self signIDForQuorumEntry:quorumEntry];
    DSLogPrivate(@"verifying is lock signature %@ with public key %@ for transaction hash %@ against quorum %@", [NSData dataWithUInt768:self.signature].hexString, [NSData dataWithUInt384:publicKey].hexString, [NSData dataWithUInt256:self.transactionHash].hexString, quorumEntry);
    return [blsKey verify:signId signature:self.signature];
}

- (DSQuorumEntry *)findSigningQuorumReturnMasternodeList:(DSMasternodeList **)returnMasternodeList {
    DSQuorumEntry *foundQuorum = nil;
    DSLLMQType ISLockQuorumType = [self.chain quorumTypeForISLocks];
    for (DSMasternodeList *masternodeList in [self.chain.chainManager.masternodeManager.recentMasternodeLists copy]) {
        for (DSQuorumEntry *quorumEntry in [[masternodeList quorumsOfType:ISLockQuorumType] allValues]) {
            BOOL signatureVerified = [self verifySignatureAgainstQuorum:quorumEntry];
            if (signatureVerified) {
                foundQuorum = quorumEntry;
                if (returnMasternodeList) *returnMasternodeList = masternodeList;
                break;
            }
        }
        if (foundQuorum) break;
    }
    return foundQuorum;
}

- (BOOL)verifySignatureWithQuorumOffset:(uint32_t)offset {
    DSQuorumEntry *quorumEntry = [self.chain.chainManager.masternodeManager quorumEntryForInstantSendRequestID:[self requestID] withBlockHeightOffset:offset];
    if (quorumEntry && quorumEntry.verified) {
        self.signatureVerified = [self verifySignatureAgainstQuorum:quorumEntry];
        if (!self.signatureVerified) {
            DSLog(@"unable to verify IS signature with offset %d", offset);
        } else {
            DSLog(@"IS signature verified with offset %d", offset);
        }

    } else if (quorumEntry) {
        DSLog(@"quorum entry %@ found but is not yet verified", uint256_hex(quorumEntry.quorumHash));
    } else {
        DSLog(@"no quorum entry found");
    }
    if (self.signatureVerified) {
        self.intendedQuorum = quorumEntry;
    } else if (quorumEntry.verified && offset == 8) {
        //try again a few blocks more in the past
        DSLog(@"trying with offset 0");
        return [self verifySignatureWithQuorumOffset:0];
    } else if (quorumEntry.verified && offset == 0) {
        //try again a few blocks more in the future
        DSLog(@"trying with offset 16");
        return [self verifySignatureWithQuorumOffset:16];
    }
    DSLog(@"returning signature verified %d with offset %d", self.signatureVerified, offset);
    return self.signatureVerified;
}

- (BOOL)verifySignature {
    return TRUE;
    //
    return [self verifySignatureWithQuorumOffset:8];
}

- (void)saveInitial {
    if (_saved) return;

    NSManagedObjectContext *context = self.chain.chainManagedObjectContext;
    //saving here will only create, not update.
    [context performBlockAndWait:^{ // add the transaction to core data
        if ([DSInstantSendLockEntity countObjectsInContext:context matching:@"transaction.transactionHash.txHash == %@", uint256_data(self.transactionHash)] == 0) {
            [DSInstantSendLockEntity instantSendLockEntityFromInstantSendLock:self inContext:context];
            [context ds_save];
        }
    }];
    self.saved = YES;
}

- (void)saveSignatureValid {
    if (!_saved) {
        [self saveInitial];
        return;
    };
    //saving here will only create, not update.
    NSManagedObjectContext *context = [NSManagedObjectContext chainContext];
    [context performBlockAndWait:^{ // add the transaction to core data
        NSArray *instantSendLocks = [DSInstantSendLockEntity objectsInContext:context matching:@"transaction.transactionHash.txHash == %@", uint256_data(self.transactionHash)];

        DSInstantSendLockEntity *instantSendLockEntity = [instantSendLocks firstObject];
        if (instantSendLockEntity) {
            instantSendLockEntity.validSignature = TRUE;
            [context ds_save];
        }
    }];
}
@end
