//
//  DSChainLock.m
//  DashSync
//
//  Created by Sam Westrich on 11/25/19.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "DSChainLock.h"
#import "DSChain+Params.h"
#import "DSChain+Protected.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSChainLockEntity+CoreDataClass.h"
#import "DSChainManager.h"
#import "DSMasternodeManager.h"
#import "DSMerkleBlockEntity+CoreDataClass.h"
#import "DSSporkManager.h"
#import "NSData+DSHash.h"
#import "NSData+Dash.h"
#import "NSDate+Utils.h"
#import "NSManagedObject+Sugar.h"
#import "NSMutableData+Dash.h"

@interface DSChainLock ()

@property (nonatomic, assign) dashcore_ephemerealdata_chain_lock_ChainLock *lock;
@property (nonatomic, strong) DSChain *chain;
@property (nonatomic, assign) BOOL signatureVerified;
@property (nonatomic, assign) BOOL quorumVerified;
@property (nonatomic, assign) BOOL saved;

@end

@implementation DSChainLock
- (void)dealloc {
    if (_lock != NULL) {
        dashcore_ephemerealdata_chain_lock_ChainLock_destroy(_lock);
        _lock = NULL;
    }
}

// message can be either a merkleblock or header message
+ (instancetype)chainLockWithMessage:(NSData *)message onChain:(DSChain *)chain {
    return [[self alloc] initWithMessage:message onChain:chain];
}

- (instancetype)initWithMessage:(NSData *)message onChain:(DSChain *)chain {
    if (!(self = [self init])) return nil;
    self.lock = dash_spv_masternode_processor_processing_chain_lock_from_message(slice_ctor(message));
    self.chain = chain;
    //DSLog(@"[%@] the chain lock signature received for height %d (sig %@) (blockhash %@)", chain.name, self.height, uint768_hex(self.signature), uint256_hex(_blockHash));
    return self;
}

- (instancetype)initOnChain:(DSChain *)chain {
    if (!(self = [super init])) return nil;

    self.chain = chain;

    return self;
}

- (instancetype)initWithBlockHash:(NSData *)blockHash
                           height:(uint32_t)height
                        signature:(NSData *)signature
                signatureVerified:(BOOL)signatureVerified
                   quorumVerified:(BOOL)quorumVerified
                          onChain:(DSChain *)chain {
    if (!(self = [self initOnChain:chain])) return nil;
    u256 *hash = blockHash ? u256_ctor(blockHash) : u256_ctor_u(UINT256_ZERO);
    u768 *sig = signature ? u768_ctor(signature) : u768_ctor_u(UINT768_ZERO);
    dashcore_hash_types_BlockHash *block_hash = dashcore_hash_types_BlockHash_ctor(hash);
    dashcore_bls_sig_utils_BLSSignature *bls_signature = dashcore_bls_sig_utils_BLSSignature_ctor(sig);
    self.lock = dashcore_ephemerealdata_chain_lock_ChainLock_ctor(height, block_hash, bls_signature);
    self.signatureVerified = signatureVerified;
    self.quorumVerified = quorumVerified;
    self.saved = YES; //this is coming already from the persistant store and not from the network
    return self;
}

- (UInt256)blockHash {
    u256 *block_hash = dash_spv_masternode_processor_processing_chain_lock_block_hash(self.lock);
    UInt256 data = u256_cast(block_hash);
    u256_dtor(block_hash);
    return uint256_reverse(data);
}
- (NSData *)blockHashData {
    u256 *block_hash = dash_spv_masternode_processor_processing_chain_lock_block_hash(self.lock);
    NSData *data = NSDataFromPtr(block_hash);
    u256_dtor(block_hash);
    
    return [data reverse];
}

- (UInt768)signature {
    u768 *sig = dash_spv_masternode_processor_processing_chain_lock_signature(self.lock);
    UInt768 data = u768_cast(sig);
    u768_dtor(sig);
    return data;
}

- (NSData *)signatureData {
    u768 *sig = dash_spv_masternode_processor_processing_chain_lock_signature(self.lock);
    NSData *data = NSDataFromPtr(sig);
    u768_dtor(sig);
    return data;
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
    //return [self verifySignatureWithQuorumOffset:8];
}

- (void)saveInitial {
    if (_saved) return;
    //saving here will only create, not update.
    NSManagedObjectContext *context = [NSManagedObjectContext chainContext];
    [context performBlockAndWait:^{ // add the transaction to core data
        if ([DSChainLockEntity countObjectsInContext:context matching:@"merkleBlock.blockHash == %@", self.blockHashData] == 0) {
            DSChainLockEntity *chainLockEntity = [DSChainLockEntity chainLockEntityForChainLock:self inContext:context];
            if (chainLockEntity) {
                [context ds_save];
                self.saved = YES;
            }
        }
    }];
}

- (void)saveSignatureValid {
    if (!_saved) {
        [self saveInitial];
        return;
    };
    NSManagedObjectContext *context = [NSManagedObjectContext chainContext];
    [context performBlockAndWait:^{ // add the transaction to core data
        NSArray *chainLocks = [DSChainLockEntity objectsInContext:context matching:@"merkleBlock.blockHash == %@", self.blockHashData];

        DSChainLockEntity *chainLockEntity = [chainLocks firstObject];
        if (chainLockEntity) {
            chainLockEntity.validSignature = TRUE;
            [context ds_save];
        }
    }];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<DSChainLock:%@:%u:%@>", self.chain.name, dashcore_ephemerealdata_chain_lock_ChainLock_get_block_height(self.lock), self.signatureVerified ? @"Verified" : @"Not Verified"];
}


@end
