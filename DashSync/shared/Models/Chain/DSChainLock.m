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

@property (nonatomic, assign) uint32_t height;
@property (nonatomic, assign) UInt256 blockHash;
@property (nonatomic, assign) UInt768 signature;
@property (nonatomic, strong) DSChain *chain;
@property (nonatomic, assign) UInt256 requestID;
@property (nonatomic, strong) NSArray *inputOutpoints;
@property (nonatomic, assign) BOOL signatureVerified;
@property (nonatomic, assign) BOOL quorumVerified;
//@property (nonatomic, strong) DSQuorumEntry *intendedQuorum;
@property (nonatomic, assign) u384 *intendedQuorumPublicKey;
@property (nonatomic, assign) BOOL saved;

@end

@implementation DSChainLock
- (void)dealloc {
    if (self.intendedQuorumPublicKey) {
        u384_dtor(self.intendedQuorumPublicKey);
    }
}
// message can be either a merkleblock or header message
+ (instancetype)chainLockWithMessage:(NSData *)message onChain:(DSChain *)chain {
    return [[self alloc] initWithMessage:message onChain:chain];
}

- (instancetype)initWithMessage:(NSData *)message onChain:(DSChain *)chain {
    if (!(self = [self init])) return nil;
    if (message.length < 132) return nil;
    NSUInteger off = 0;

    _height = [message UInt32AtOffset:off];
    off += sizeof(uint32_t);
    _blockHash = [message UInt256AtOffset:off];
    off += sizeof(UInt256);
    _signature = [message UInt768AtOffset:off];
    off += sizeof(UInt768);
    self.chain = chain;

    DSLog(@"[%@] the chain lock signature received for height %d (sig %@) (blockhash %@)", chain.name, self.height, uint768_hex(_signature), uint256_hex(_blockHash));

    return self;
}

- (instancetype)initOnChain:(DSChain *)chain {
    if (!(self = [super init])) return nil;

    self.chain = chain;

    return self;
}

- (instancetype)initWithBlockHash:(UInt256)blockHash
                        signature:(UInt768)signature
                signatureVerified:(BOOL)signatureVerified
                   quorumVerified:(BOOL)quorumVerified
                          onChain:(DSChain *)chain {
    if (!(self = [self initOnChain:chain])) return nil;
    self.blockHash = blockHash;
    self.signatureVerified = signatureVerified;
    self.quorumVerified = quorumVerified;
    self.saved = YES; //this is coming already from the persistant store and not from the network
    return self;
}

- (UInt256)requestID {
    if (uint256_is_not_zero(_requestID)) return _requestID;
    NSMutableData *data = [NSMutableData data];
    [data appendString:@"clsig"];
    [data appendUInt32:self.height];
    _requestID = [data SHA256_2];
    DSLog(@"[%@] the chain lock request ID is %@ for height %d", self.chain.name, uint256_hex(_requestID), self.height);
    return _requestID;
}

- (BOOL)verifySignatureAgainstQuorum:(DLLMQEntry *)quorumEntry {
    u256 *request_id = u256_ctor_u(self.requestID);
    u256 *block_hash = u256_ctor_u(self.blockHash);
    u768 *sig = u768_ctor_u(self.signature);
    u256 *sign_id = DLLMQEntrySignID(quorumEntry, request_id, block_hash);
    bool verified = DLLMQEntryVerifySignature(quorumEntry, sign_id, sig);
    return verified;
}

//- (DSQuorumEntry *)findSigningQuorumReturnMasternodeList:(DSMasternodeList **)returnMasternodeList {
//    DSQuorumEntry *foundQuorum = nil;
//    for (DSMasternodeList *masternodeList in self.chain.chainManager.masternodeManager.recentMasternodeLists) {
//        for (DSQuorumEntry *quorumEntry in [[masternodeList quorumsOfType:quorum_type_for_chain_locks(self.chain.chainType)] allValues]) {
//            BOOL signatureVerified = [self verifySignatureAgainstQuorum:quorumEntry];
//            if (signatureVerified) {
//                foundQuorum = quorumEntry;
//                if (returnMasternodeList) *returnMasternodeList = masternodeList;
//                break;
//            }
//        }
//        if (foundQuorum) break;
//    }
//    return foundQuorum;
//}

- (BOOL)verifySignatureWithQuorumOffset:(uint32_t)offset {
    DLLMQEntry *quorumEntry = [self.chain.chainManager.masternodeManager quorumEntryForChainLockRequestID:[self requestID] forBlockHeight:self.height - offset];
    if (quorumEntry && quorumEntry->verified) {
        u256 *request_id = u256_ctor_u(self.requestID);
        u256 *block_hash = u256_ctor_u(self.blockHash);
        u768 *sig = u768_ctor_u(self.signature);
        u256 *sign_id = DLLMQEntrySignID(quorumEntry, request_id, block_hash);
        self.signatureVerified = DLLMQEntryVerifySignature(quorumEntry, sign_id, sig);

        if (!self.signatureVerified) {
            DSLog(@"[%@] unable to verify signature with offset %d", self.chain.name, offset);
        } else {
            DSLog(@"[%@] signature verified with offset %d", self.chain.name, offset);
        }

    } else if (quorumEntry) {
        DSLog(@"[%@] quorum entry %@ found but is not yet verified", self.chain.name,
              [NSString stringWithUTF8String:DLLMQEntryHashHex(quorumEntry)]);
    } else {
        DSLog(@"[%@] no quorum entry found", self.chain.name);
    }
    if (self.signatureVerified) {
        self.intendedQuorumPublicKey = quorumEntry->public_key;
        self.quorumVerified = quorumEntry->verified;
        //We should also set the chain's last chain lock
        if (!self.chain.lastChainLock || self.chain.lastChainLock.height < self.height) {
            self.chain.lastChainLock = self;
        }
    } else if (quorumEntry && quorumEntry->verified && offset == 8) {
        //try again a few blocks more in the past
        DSLog(@"[%@] trying with offset 0", self.chain.name);
        return [self verifySignatureWithQuorumOffset:0];
    } else if (quorumEntry && quorumEntry->verified && offset == 0) {
        //try again a few blocks more in the future
        DSLog(@"[%@] trying with offset 16", self.chain.name);
        return [self verifySignatureWithQuorumOffset:16];
    }
    DSLog(@"[%@] returning chain lock signature verified %d with offset %d", self.chain.name, self.signatureVerified, offset);
    return self.signatureVerified;
}

- (BOOL)verifySignature {
    return [self verifySignatureWithQuorumOffset:8];
}

- (void)saveInitial {
    if (_saved) return;
    //saving here will only create, not update.
    NSManagedObjectContext *context = [NSManagedObjectContext chainContext];
    [context performBlockAndWait:^{ // add the transaction to core data
        if ([DSChainLockEntity countObjectsInContext:context matching:@"merkleBlock.blockHash == %@", uint256_data(self.blockHash)] == 0) {
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
        NSArray *chainLocks = [DSChainLockEntity objectsInContext:context matching:@"merkleBlock.blockHash == %@", uint256_data(self.blockHash)];

        DSChainLockEntity *chainLockEntity = [chainLocks firstObject];
        if (chainLockEntity) {
            chainLockEntity.validSignature = TRUE;
            [context ds_save];
        }
    }];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<DSChainLock:%@:%u:%@>", self.chain.name, self.height, self.signatureVerified ? @"Verified" : @"Not Verified"];
}


@end
