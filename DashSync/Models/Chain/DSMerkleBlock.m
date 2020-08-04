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
#import "DSBlock+Protected.h"
#import "NSMutableData+Dash.h"
#import "NSData+Bitcoin.h"
#import "NSData+Dash.h"
#import "DSChain.h"
#import "NSDate+Utils.h"
#import "DSChainLock.h"

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

@property (nonatomic, strong) NSData *hashes;
@property (nonatomic, strong) NSData *flags;

@end

@implementation DSMerkleBlock

// message can be either a merkleblock or header message
+ (instancetype)merkleBlockWithMessage:(NSData *)message onChain:(DSChain *)chain
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
    
    self.version = [message UInt32AtOffset:off];
    off += sizeof(uint32_t);
    UInt256 prevBlock = [message UInt256AtOffset:off];
    self.prevBlock = prevBlock;
    off += sizeof(UInt256);
    UInt256 merkleRoot = [message UInt256AtOffset:off];
    self.merkleRoot = merkleRoot;
    off += sizeof(UInt256);
    self.timestamp = [message UInt32AtOffset:off];
    off += sizeof(uint32_t);
    self.target = [message UInt32AtOffset:off];
    off += sizeof(uint32_t);
    self.nonce = [message UInt32AtOffset:off];
    off += sizeof(uint32_t);
    self.totalTransactions = [message UInt32AtOffset:off];
    off += sizeof(uint32_t);
    len = (NSUInteger)[message varIntAtOffset:off length:&l]*sizeof(UInt256);
    off += l.unsignedIntegerValue;
    _hashes = (off + len > message.length) ? nil : [message subdataWithRange:NSMakeRange(off, len)];
    off += len;
    _flags = [message dataAtOffset:off length:&l];
    self.height = BLOCK_UNKNOWN_HEIGHT;
    
    [d appendUInt32:self.version];
    [d appendUInt256:prevBlock];
    [d appendUInt256:merkleRoot];
    [d appendUInt32:self.timestamp];
    [d appendUInt32:self.target];
    [d appendUInt32:self.nonce];
    self.blockHash = d.x11;
    self.chain = chain;
    
#if LOG_MERKLE_BLOCKS || LOG_MERKLE_BLOCKS_FULL
#if LOG_MERKLE_BLOCKS_FULL
    DSDLog(@"%d - merkle block %@ (%@) has %d transactions",self.height,uint256_hex(self.blockHash),message.hexString,self.totalTransactions);
#else
    DSDLog(@"%d - merkle block %@ has %d transactions",self.height,uint256_hex(self.blockHash),self.totalTransactions);
#endif
#endif
    
    return self;
}

- (instancetype)initWithBlockHash:(UInt256)blockHash merkleRoot:(UInt256)merkleRoot totalTransactions:(uint32_t)totalTransactions hashes:(NSData *)hashes flags:(NSData *)flags
{
    if (! (self = [self init])) return nil;
    
    self.blockHash = blockHash;
    self.merkleRoot = merkleRoot;
    self.totalTransactions = totalTransactions;
    _hashes = hashes;
    _flags = flags;
    self.chainLocked = FALSE;
    return self;
}

- (instancetype)initWithVersion:(uint32_t)version blockHash:(UInt256)blockHash prevBlock:(UInt256)prevBlock
                     merkleRoot:(UInt256)merkleRoot timestamp:(uint32_t)timestamp target:(uint32_t)target aggregateWork:(UInt256)aggregateWork nonce:(uint32_t)nonce totalTransactions:(uint32_t)totalTransactions hashes:(NSData *)hashes flags:(NSData *)flags height:(uint32_t)height chainLock:(DSChainLock*)chainLock onChain:(DSChain*)chain
{
    if (! (self = [self initWithBlockHash:blockHash merkleRoot:merkleRoot totalTransactions:totalTransactions hashes:hashes flags:flags])) return nil;
    
    self.version = version;
    self.prevBlock = prevBlock;
    self.merkleRoot = merkleRoot;
    self.timestamp = timestamp;
    self.target = target;
    self.nonce = nonce;
    self.height = height;
    [self setChainLockedWithChainLock:chainLock];
    self.chain = chain;
    
    return self;
}

- (NSData *)toData
{
    NSMutableData *d = [[super toData] mutableCopy];
    
    if (self.totalTransactions > 0) {
        [d appendUInt32:self.totalTransactions];
        [d appendVarInt:self.hashes.length/sizeof(UInt256)];
        [d appendData:self.hashes];
        [d appendVarInt:_flags.length];
        [d appendData:_flags];
    }
    
    return d;
}

// true if the given tx hash is included in the block
- (BOOL)containsTxHash:(UInt256)txHash
{
    for (NSUInteger i = 0; i < self.hashes.length/sizeof(UInt256); i += sizeof(UInt256)) {
        DSDLog(@"transaction Hash %@",[NSData dataWithUInt256:[self.hashes UInt256AtOffset:i]].hexString);
        DSDLog(@"looking for %@",[NSData dataWithUInt256:txHash].hexString);
        if (uint256_eq(txHash, [self.hashes UInt256AtOffset:i])) return YES;
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


-(BOOL)isMerkleTreeValid {
    NSMutableData *d = [NSMutableData data];
    UInt256 merkleRoot = UINT256_ZERO;
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
    if (self.totalTransactions > 0 && ! uint256_eq(merkleRoot, self.merkleRoot)) return NO; // merkle root check failed
    return YES;
}

// recursively walks the merkle tree in depth first order, calling leaf(hash, flag) for each stored hash, and
// branch(left, right) with the result from each branch
- (id)_walk:(int *)hashIdx :(int *)flagIdx :(int)depth :(id (^)(id, BOOL))leaf :(id (^)(id, id))branch
{
    if ((*flagIdx)/8 >= _flags.length || (*hashIdx + 1)*sizeof(UInt256) > _hashes.length) return leaf(nil, NO);
    
    BOOL flag = (((const uint8_t *)_flags.bytes)[*flagIdx/8] & (1 << (*flagIdx % 8)));
    
    (*flagIdx)++;
    
    if (! flag || depth == ceil_log2(self.totalTransactions)) {
        UInt256 hash = [_hashes UInt256AtOffset:(*hashIdx)*sizeof(UInt256)];
        
        (*hashIdx)++;
        return leaf(uint256_obj(hash), flag);
    }
    
    id left = [self _walk:hashIdx :flagIdx :depth + 1 :leaf :branch];
    id right = [self _walk:hashIdx :flagIdx :depth + 1 :leaf :branch];
    
    return branch(left, right);
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
