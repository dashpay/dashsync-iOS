//
//  DSMerkleBlock.m
//  DashSync
//
//  Created by Aaron Voisine for BreadWallet on 10/22/13.
//  Copyright (c) 2013 Aaron Voisine <voisine@gmail.com>
//  Copyright (c) 2018 Dash Core Group <contact@dash.org>
//  Updated by Quantum Explorer on 05/11/18.
//  Copyright (c) 2018 Quantum Explorer <quantum@dash.org>
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

#import "DSMerkleBlock.h"
#import "NSMutableData+Dash.h"
#import "NSData+Bitcoin.h"
#import "NSData+Dash.h"
#import "DSChain.h"
#import "NSDate+Utils.h"
#import "DSChainLock.h"

#define MAX_TIME_DRIFT    (2*60*60)     // the furthest in the future a block is allowed to be timestamped
#define LOG_MERKLE_BLOCKS 0
#define LOG_MERKLE_BLOCKS_FULL (LOG_MERKLE_BLOCKS && 1)

// from https://en.bitcoin.it/wiki/Protocol_specification#Merkle_Trees
// Merkle trees are binary trees of hashes. Merkle trees in bitcoin use a double SHA-256, the SHA-256 hash of the
// SHA-256 hash of something. If, when forming a row in the tree (other than the root of the tree), it would have an odd
// number of elements, the final double-hash is duplicated to ensure that the row has an even number of hashes. First
// form the bottom row of the tree with the ordered double-SHA-256 hashes of the byte streams of the transactions in the
// block. Then the row above it consists of half that number of hashes. Each entry is the double-SHA-256 of the 64-byte
// concatenation of the corresponding two hashes below it in the tree. This procedure repeats recursively until we reach
// a row consisting of just a single double-hash. This is the merkle root of the tree.
//
// from https://github.com/bitcoin/bips/blob/master/bip-0037.mediawiki#Partial_Merkle_branch_format
// The encoding works as follows: we traverse the tree in depth-first order, storing a bit for each traversed node,
// signifying whether the node is the parent of at least one matched leaf txid (or a matched txid itself). In case we
// are at the leaf level, or this bit is 0, its merkle node hash is stored, and its children are not explored further.
// Otherwise, no hash is stored, but we recurse into both (or the only) child branch. During decoding, the same
// depth-first traversal is performed, consuming bits and hashes as they written during encoding.
//
// example tree with three transactions, where only tx2 is matched by the bloom filter:
//
//     merkleRoot
//      /     \
//    m1       m2
//   /  \     /  \
// tx1  tx2 tx3  tx3
//
// flag bits (little endian): 00001011 [merkleRoot = 1, m1 = 1, tx1 = 0, tx2 = 1, m2 = 0, byte padding = 000]
// hashes: [tx1, tx2, m2]

inline static int ceil_log2(int x)
{
    int r = (x & (x - 1)) ? 1 : 0;
    
    while ((x >>= 1) != 0) r++;
    return r;
}

@interface DSMerkleBlock ()

@property (nonatomic, assign) UInt256 blockHash;
@property (nonatomic, assign) uint32_t version;
@property (nonatomic, assign) UInt256 prevBlock;
@property (nonatomic, assign) UInt256 merkleRoot;
@property (nonatomic, assign) uint32_t timestamp; // time interval since unix epoch
@property (nonatomic, assign) uint32_t target;
@property (nonatomic, assign) uint32_t nonce;
@property (nonatomic, assign) uint32_t totalTransactions;
@property (nonatomic, assign) BOOL chainLocked;
@property (nonatomic, assign) BOOL hasUnverifiedChainLock;
@property (nonatomic, strong) DSChainLock * chainLockAwaitingProcessing;
@property (nonatomic, strong) NSData *hashes;
@property (nonatomic, strong) NSData *flags;
@property (nonatomic, strong) DSChain * chain;
@property (nonatomic, strong) NSArray *txHashes; // the matched tx hashes in the block
@property (nonatomic, assign, getter = isValid) BOOL valid;
@property (nonatomic, assign, getter = isMerkleTreeValid) BOOL merkleTreeValid;
@property (nonatomic, strong, getter = toData) NSData *data;

@end

@implementation DSMerkleBlock

// message can be either a merkleblock or header message
+ (instancetype)blockWithMessage:(NSData *)message onChain:(DSChain *)chain
{
    return [[self alloc] initWithMessage:message onChain:chain];
}

- (instancetype)initWithMessage:(NSData *)message onChain:(DSChain *)chain
{
    if (! (self = [self init])) return nil;
    if (message.length < 80) return nil;
    NSNumber * l = nil;
    NSUInteger off = 0, len = 0;
    NSMutableData *d = [NSMutableData data];
    
    _version = [message UInt32AtOffset:off];
    off += sizeof(uint32_t);
    _prevBlock = [message UInt256AtOffset:off];
    off += sizeof(UInt256);
    _merkleRoot = [message UInt256AtOffset:off];
    off += sizeof(UInt256);
    _timestamp = [message UInt32AtOffset:off];
    off += sizeof(uint32_t);
    _target = [message UInt32AtOffset:off];
    off += sizeof(uint32_t);
    _nonce = [message UInt32AtOffset:off];
    off += sizeof(uint32_t);
    _totalTransactions = [message UInt32AtOffset:off];
    off += sizeof(uint32_t);
    len = (NSUInteger)[message varIntAtOffset:off length:&l]*sizeof(UInt256);
    off += l.unsignedIntegerValue;
    _hashes = (off + len > message.length) ? nil : [message subdataWithRange:NSMakeRange(off, len)];
    off += len;
    _flags = [message dataAtOffset:off length:&l];
    _height = BLOCK_UNKNOWN_HEIGHT;
    
    [d appendUInt32:_version];
    [d appendBytes:&_prevBlock length:sizeof(_prevBlock)];
    [d appendBytes:&_merkleRoot length:sizeof(_merkleRoot)];
    [d appendUInt32:_timestamp];
    [d appendUInt32:_target];
    [d appendUInt32:_nonce];
    _blockHash = d.x11;
    self.chain = chain;
    
#if LOG_MERKLE_BLOCKS || LOG_MERKLE_BLOCKS_FULL
#if LOG_MERKLE_BLOCKS_FULL
    DSDLog(@"%d - merkle block %@ (%@) has %d transactions",_height,[NSData dataWithUInt256:_blockHash].hexString,message.hexString,_totalTransactions);
#else
    DSDLog(@"%d - merkle block %@ has %d transactions",_height,[NSData dataWithUInt256:_blockHash].hexString,_totalTransactions);
#endif
#endif
    
    return self;
}

- (instancetype)initWithBlockHash:(UInt256)blockHash merkleRoot:(UInt256)merkleRoot totalTransactions:(uint32_t)totalTransactions hashes:(NSData *)hashes flags:(NSData *)flags
{
    if (! (self = [self init])) return nil;
    
    _blockHash = blockHash;
    _merkleRoot = merkleRoot;
    _totalTransactions = totalTransactions;
    _hashes = hashes;
    _flags = flags;
    return self;
}

- (instancetype)initWithBlockHash:(UInt256)blockHash onChain:(DSChain*)chain version:(uint32_t)version prevBlock:(UInt256)prevBlock
                       merkleRoot:(UInt256)merkleRoot timestamp:(uint32_t)timestamp target:(uint32_t)target nonce:(uint32_t)nonce
                totalTransactions:(uint32_t)totalTransactions hashes:(NSData *)hashes flags:(NSData *)flags height:(uint32_t)height
{
    if (! (self = [self init])) return nil;
    
    _blockHash = blockHash;
    _version = version;
    _prevBlock = prevBlock;
    _merkleRoot = merkleRoot;
    _timestamp = timestamp;
    _target = target;
    _nonce = nonce;
    _totalTransactions = totalTransactions;
    _hashes = hashes;
    _flags = flags;
    _height = height;
    self.chain = chain;
    
    return self;
}

-(BOOL)isMerkleTreeValid {
    NSMutableData *d = [NSMutableData data];
    UInt256 merkleRoot;
    int hashIdx = 0, flagIdx = 0;
    NSValue *root = [self _walk:&hashIdx :&flagIdx :0 :^id (id hash, BOOL flag) {
        return hash;
    } :^id (id left, id right) {
        UInt256 l, r;
        
        if (! right) right = left; // if right branch is missing, duplicate left branch
        [left getValue:&l];
        [right getValue:&r];
        d.length = 0;
        [d appendBytes:&l length:sizeof(l)];
        [d appendBytes:&r length:sizeof(r)];
        return uint256_obj(d.SHA256_2);
    }];
    
    [root getValue:&merkleRoot];
    //DSDLog(@"%@ - %@",uint256_hex(merkleRoot),uint256_hex(_merkleRoot));
    if (_totalTransactions > 0 && ! uint256_eq(merkleRoot, _merkleRoot)) return NO; // merkle root check failed
    return YES;
}

// true if merkle tree and timestamp are valid
// NOTE: This only checks if the block difficulty matches the difficulty target in the header. It does not check if the
// target is correct for the block's height in the chain. Use verifyDifficultyFromPreviousBlock: for that.
- (BOOL)isValid
{
    if (![self isMerkleTreeValid]) return NO;
    
    // check if timestamp is too far in future
    //TODO: use estimated network time instead of system time (avoids timejacking attacks and misconfigured time)
    if (_timestamp > [NSDate timeIntervalSince1970] + MAX_TIME_DRIFT) return NO;
    
    return YES;
}

- (NSData *)toData
{
    NSMutableData *d = [NSMutableData data];
    
    [d appendUInt32:_version];
    [d appendBytes:&_prevBlock length:sizeof(_prevBlock)];
    [d appendBytes:&_merkleRoot length:sizeof(_merkleRoot)];
    [d appendUInt32:_timestamp];
    [d appendUInt32:_target];
    [d appendUInt32:_nonce];
    
    if (_totalTransactions > 0) {
        [d appendUInt32:_totalTransactions];
        [d appendVarInt:_hashes.length/sizeof(UInt256)];
        [d appendData:_hashes];
        [d appendVarInt:_flags.length];
        [d appendData:_flags];
    }
    
    return d;
}

// true if the given tx hash is included in the block
- (BOOL)containsTxHash:(UInt256)txHash
{
    for (NSUInteger i = 0; i < _hashes.length/sizeof(UInt256); i += sizeof(UInt256)) {
        DSDLog(@"transaction Hash %@",[NSData dataWithUInt256:[_hashes UInt256AtOffset:i]].hexString);
        DSDLog(@"looking for %@",[NSData dataWithUInt256:txHash].hexString);
        if (uint256_eq(txHash, [_hashes UInt256AtOffset:i])) return YES;
    }
    
    return NO;
}

// returns an array of the matched tx hashes
- (NSArray *)txHashes
{
    int hashIdx = 0, flagIdx = 0;
    NSArray *txHashes =
    [self _walk:&hashIdx :&flagIdx :0 :^id (id hash, BOOL flag) {
        return (flag && hash) ? @[hash] : @[];
    } :^id (id left, id right) {
        return [left arrayByAddingObjectsFromArray:right];
    }];
    
    return txHashes;
}


- (BOOL)verifyDifficultyWithPreviousBlocks:(NSMutableDictionary *)previousBlocks
{
    uint32_t darkGravityWaveTarget = [self darkGravityWaveTargetWithPreviousBlocks:previousBlocks];
    int32_t diff = self.target - darkGravityWaveTarget;
    if (abs(diff) > 1) {
        DSDLog(@"weird difficulty for block at height %u (off by %u)",self.height,diff);
    }
    return (abs(diff) < 2); //the core client is less precise with a rounding error that can sometimes cause a problem. We are very rarely 1 off
}

-(int32_t)darkGravityWaveTargetWithPreviousBlocks:(NSMutableDictionary *)previousBlocks {
    /* current difficulty formula, darkcoin - based on DarkGravity v3, original work done by evan duffield, modified for iOS */
    DSMerkleBlock *previousBlock = previousBlocks[uint256_obj(self.prevBlock)];
    
    int32_t nActualTimespan = 0;
    int64_t lastBlockTime = 0;
    uint32_t blockCount = 0;
    UInt256 sumTargets = UINT256_ZERO;
    
    if (uint256_is_zero(_prevBlock) || previousBlock.height == 0 || previousBlock.height < DGW_PAST_BLOCKS_MIN + (self.chain.isDevnetAny?1:0)) {
        // This is the first block or the height is < PastBlocksMin
        // Return minimal required work. (1e0ffff0)
        return self.chain.maxProofOfWork;
    }
    
    if (self.chain.allowMinDifficultyBlocks) {
        // recent block is more than 2 hours old
        if (self.timestamp > (previousBlock.timestamp + 2 * 60 * 60)) {
            return self.chain.maxProofOfWork;
        }
        // recent block is more than 10 minutes old
        if (self.timestamp > (previousBlock.timestamp + 2.5 * 60 * 4)) {
            UInt256 previousTarget = setCompact(previousBlock.target);
            
            UInt256 newTarget = uInt256MultiplyUInt32(previousTarget, 10);
            uint32_t compact = getCompact(newTarget);
            if (compact > self.chain.maxProofOfWork){
                compact = self.chain.maxProofOfWork;
            }
            return compact;
        }
    }
    
    DSMerkleBlock *currentBlock = previousBlock;
    // loop over the past n blocks, where n == PastBlocksMax
    for (blockCount = 1; currentBlock && currentBlock.height > 0 && blockCount<=DGW_PAST_BLOCKS_MAX; blockCount++) {
        
        // Calculate average difficulty based on the blocks we iterate over in this for loop
        if(blockCount <= DGW_PAST_BLOCKS_MIN) {
            UInt256 currentTarget = setCompact(currentBlock.target);
            //if (self.height == 1070917)
            //DSDLog(@"%d",currentTarget);
            if (blockCount == 1) {
                sumTargets = uInt256Add(currentTarget,currentTarget);
            } else {
                sumTargets = uInt256Add(sumTargets,currentTarget);
            }
        }
        
        // If this is the second iteration (LastBlockTime was set)
        if(lastBlockTime > 0){
            // Calculate time difference between previous block and current block
            int64_t currentBlockTime = currentBlock.timestamp;
            int64_t diff = ((lastBlockTime) - (currentBlockTime));
            // Increment the actual timespan
            nActualTimespan += diff;
        }
        // Set lastBlockTime to the block time for the block in current iteration
        lastBlockTime = currentBlock.timestamp;
        
        if (previousBlock == NULL) { assert(currentBlock); break; }
        currentBlock = previousBlocks[uint256_obj(currentBlock.prevBlock)];
    }
    UInt256 blockCount256 = ((UInt256) { .u64 = { blockCount, 0, 0, 0 } });
    // darkTarget is the difficulty
    UInt256 darkTarget = uInt256Divide(sumTargets,blockCount256);
    
    // nTargetTimespan is the time that the CountBlocks should have taken to be generated.
    uint32_t nTargetTimespan = (blockCount - 1)* (60 * 2.5);
    
    // Limit the re-adjustment to 3x or 0.33x
    // We don't want to increase/decrease diff too much.
    if (nActualTimespan < nTargetTimespan/3.0f)
        nActualTimespan = nTargetTimespan/3.0f;
    if (nActualTimespan > nTargetTimespan*3.0f)
        nActualTimespan = nTargetTimespan*3.0f;
    
    // Calculate the new difficulty based on actual and target timespan.
    darkTarget = uInt256Divide(uInt256MultiplyUInt32(darkTarget,nActualTimespan),((UInt256) { .u64 = { nTargetTimespan, 0, 0, 0 } }));
    
    int32_t compact = getCompact(darkTarget);
    
    // If calculated difficulty is lower than the minimal diff, set the new difficulty to be the minimal diff.
    if (compact > self.chain.maxProofOfWork){
        compact = self.chain.maxProofOfWork;
    }
    
    // Return the new diff.
    return compact;
}

// v14

-(void)setChainLockedWithChainLock:(DSChainLock*)chainLock {
    self.chainLocked = chainLock.signatureVerified;
    self.hasUnverifiedChainLock = (chainLock && !chainLock.signatureVerified);
    if (self.hasUnverifiedChainLock) {
        self.chainLockAwaitingProcessing = chainLock;
    } else {
        self.chainLockAwaitingProcessing = nil;
    }
    if (!chainLock.saved) {
        [chainLock save];
    }
}

// recursively walks the merkle tree in depth first order, calling leaf(hash, flag) for each stored hash, and
// branch(left, right) with the result from each branch
- (id)_walk:(int *)hashIdx :(int *)flagIdx :(int)depth :(id (^)(id, BOOL))leaf :(id (^)(id, id))branch
{
    if ((*flagIdx)/8 >= _flags.length || (*hashIdx + 1)*sizeof(UInt256) > _hashes.length) return leaf(nil, NO);
    
    BOOL flag = (((const uint8_t *)_flags.bytes)[*flagIdx/8] & (1 << (*flagIdx % 8)));
    
    (*flagIdx)++;
    
    if (! flag || depth == ceil_log2(_totalTransactions)) {
        UInt256 hash = [_hashes UInt256AtOffset:(*hashIdx)*sizeof(UInt256)];
        
        (*hashIdx)++;
        return leaf(uint256_obj(hash), flag);
    }
    
    id left = [self _walk:hashIdx :flagIdx :depth + 1 :leaf :branch];
    id right = [self _walk:hashIdx :flagIdx :depth + 1 :leaf :branch];
    
    return branch(left, right);
}

- (NSUInteger)hash
{
    if (uint256_is_zero(_blockHash)) return super.hash;
    return *(const NSUInteger *)&_blockHash;
}

- (BOOL)isEqual:(id)obj
{
    return self == obj || ([obj isKindOfClass:[DSMerkleBlock class]] && uint256_eq([obj blockHash], _blockHash));
}

-(NSString*)description {
    return [NSString stringWithFormat:@"Block H:%u - <%@>",self.height,uint256_hex(self.blockHash)];
}

-(id)copyWithZone:(NSZone *)zone {
    DSMerkleBlock * copy = [[[self class] alloc] init];
    copy.blockHash = self.blockHash;
    copy.height = self.height;
    copy.version = self.version;
    copy.prevBlock = self.prevBlock;
    copy.merkleRoot = self.merkleRoot;
    copy.timestamp = self.timestamp;
    copy.target = self.target;
    copy.nonce = self.nonce;
    copy.totalTransactions = self.totalTransactions;
    copy.hashes = [self.hashes copyWithZone:zone];
    copy.txHashes = [self.txHashes copyWithZone:zone];
    copy.flags = [self.flags copyWithZone:zone];
    copy.valid = self.valid;
    copy.merkleTreeValid = self.isMerkleTreeValid;
    copy.data = [self.data copyWithZone:zone];
    return copy;
}

@end
