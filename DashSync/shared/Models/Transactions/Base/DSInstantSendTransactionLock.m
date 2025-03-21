//
//  DSInstantSendTransactionLock.m
//  DashSync
//
//  Created by Sam Westrich on 4/5/19.
//

#import "DSInstantSendTransactionLock.h"
#import "DSChain.h"
#import "DSChain+Params.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSChainManager.h"
#import "DSInstantSendLockEntity+CoreDataClass.h"
#import "DSMasternodeManager.h"
#import "DSSporkManager.h"
#import "DSTransactionEntity+CoreDataClass.h"
#import "DSTransactionHashEntity+CoreDataClass.h"
#import "NSData+Dash.h"
#import "NSManagedObject+Sugar.h"
#import "NSMutableData+Dash.h"

@interface DSInstantSendTransactionLock ()

@property (nonatomic, strong) DSChain *chain;
@property (nonatomic, assign) DInstantLock *lock;
@property (nonatomic, assign) BOOL signatureVerified;
@property (nonatomic, assign) BOOL quorumVerified;
@property (nonatomic, assign) BOOL saved;

@end

@implementation DSInstantSendTransactionLock

- (void)dealloc {
    if (_lock) {
        DInstantLockDtor(_lock);
        _lock = NULL;
    }
}

+ (instancetype)instantSendTransactionLockWithNonDeterministicMessage:(NSData *)message onChain:(DSChain *)chain {
    return [[self alloc] initWithMessage:message onChain:chain];
}

+ (instancetype)instantSendTransactionLockWithDeterministicMessage:(NSData *)message onChain:(DSChain *)chain {
    return [[self alloc] initWithMessage:message onChain:chain];
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

- (instancetype)initWithMessage:(NSData *)message onChain:(DSChain *)chain {
    if (!(self = [self initOnChain:chain])) return nil;
    if (![chain.chainManager.sporkManager deterministicMasternodeListEnabled] || ![chain.chainManager.sporkManager llmqInstantSendEnabled]) return nil;
    self.lock = dash_spv_masternode_processor_processing_instant_lock_from_message(slice_ctor(message));
    return self;
}

- (uint8_t)version {
    return dashcore_ephemerealdata_instant_lock_InstantLock_get_version(self.lock);
}

- (NSData *)transactionHashData {
    u256 *tx_hash = dash_spv_masternode_processor_processing_instant_lock_tx_hash(self.lock);
    NSData *data = NSDataFromPtr(tx_hash);
    u256_dtor(tx_hash);
    return data;
}

- (NSData *)signatureData {
    u768 *sig = dash_spv_masternode_processor_processing_instant_lock_signature(self.lock);
    NSData *data = NSDataFromPtr(sig);
    u768_dtor(sig);
    return data;
}

- (NSData *)cycleHashData {
    u256 *cycle_hash = dash_spv_masternode_processor_processing_instant_lock_cycle_hash(self.lock);
    NSData *data = NSDataFromPtr(cycle_hash);
    u256_dtor(cycle_hash);
    return data;
}

- (DOutPoints *)inputOutpoints {
    return dash_spv_masternode_processor_processing_instant_lock_outpoints(self.lock);
}

- (DOutPoint *)inputOutpointAtIndex:(uintptr_t)index {
    return dash_spv_masternode_processor_processing_instant_lock_outpoint_at_index(self.lock, index);
}

- (NSData *)toData {
    if (self.lock) {
        Vec_u8 *result = dash_spv_masternode_processor_processing_instant_lock_to_message(self.lock);
        NSData *data = NSDataFromPtr(result);
        Vec_u8_destroy(result);
        return data;
    }
    return nil;
}

- (instancetype)initWithTransactionHash:(NSData *)transactionHash
                     withInputOutpoints:(NSArray *)inputOutpoints
                                version:(uint8_t)version
                              signature:(NSData *)signature
                              cycleHash:(NSData *)cycleHash
                      signatureVerified:(BOOL)signatureVerified
                         quorumVerified:(BOOL)quorumVerified
                                onChain:(DSChain *)chain {
    if (!(self = [self initOnChain:chain])) return nil;
    NSUInteger inputsCount = inputOutpoints.count;
    DOutPoint **values = malloc(sizeof(DOutPoint *) * inputsCount);
    for (int i = 0; i < inputsCount; i++) {
        NSData *inputBytes = inputOutpoints[i];
        values[i] = DOutPointFromMessage(slice_ctor(inputBytes));
    }
    DOutPoints *inputs = DOutPointsCtor(inputsCount, values);
    
    DTxid *txid = DTxidCtor(u256_ctor(transactionHash));
    DCycleHash *chash = dashcore_hash_types_CycleHash_ctor(u256_ctor(cycleHash));
    self.lock = DInstantLockCtor(version, inputs, txid, chash, DBLSSignatureCtor(u768_ctor(signature)));
    self.signatureVerified = signatureVerified;
    self.quorumVerified = quorumVerified;
    self.saved = YES; //this is coming already from the persistant store and not from the network
    return self;
}


- (BOOL)verifySignature {
    if (self.lock) {
#if defined(DASHCORE_MESSAGE_VERIFICATION)
        DMessageVerificationResult *result = dash_spv_masternode_processor_processing_processor_MasternodeProcessor_verify_is_lock(self.chain.sharedProcessorObj, self.lock);
        BOOL verified = result->ok;
        DMessageVerificationResultDtor(result);
        return verified;
#else
        return YES;
#endif
    } else {
        return NO;
    }
//    return [self verifySignatureWithQuorumOffset:8];
}

- (void)saveInitial {
    if (_saved) return;

    NSManagedObjectContext *context = self.chain.chainManagedObjectContext;
    //saving here will only create, not update.
    [context performBlockAndWait:^{ // add the transaction to core data
        if ([DSInstantSendLockEntity countObjectsInContext:context matching:@"transaction.transactionHash.txHash == %@", [self transactionHashData]] == 0) {
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
        NSArray *instantSendLocks = [DSInstantSendLockEntity objectsInContext:context matching:@"transaction.transactionHash.txHash == %@", [self transactionHashData]];
        DSInstantSendLockEntity *instantSendLockEntity = [instantSendLocks firstObject];
        if (instantSendLockEntity) {
            instantSendLockEntity.validSignature = TRUE;
            [context ds_save];
        }
    }];
}
@end
