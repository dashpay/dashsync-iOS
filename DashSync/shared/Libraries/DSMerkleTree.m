//  DSMerkleTree.m
//  DashSync
//
//  Parts of code originally created by Aaron Voisine for BreadWallet on 10/22/13.
//  Copyright (c) 2013 Aaron Voisine <voisine@gmail.com>
//  Copyright (c) 2018 Dash Core Group <contact@dash.org>
//  Updated by Quantum Explorer on 07/17/21.
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

#import "DSMerkleTree.h"
#import "NSData+Bitcoin.h"
#import "NSData+Dash.h"
#import "NSMutableData+Dash.h"

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

inline static int ceil_log2(int x) {
    int r = (x & (x - 1)) ? 1 : 0;

    while ((x >>= 1) != 0) r++;
    return r;
}

@interface DSMerkleTree ()

@property (nonatomic, assign) uint32_t treeElementCount;
@property (nonatomic, strong) NSData *hashes;
@property (nonatomic, strong) NSData *flags;
@property (nonatomic, assign) DSMerkleTreeHashFunction hashFunction;

@end

@implementation DSMerkleTree

+ (instancetype)merkleTreeWithData:(NSData *)data treeElementCount:(uint32_t)elementCount hashFunction:(DSMerkleTreeHashFunction)hashFunction {
    NSUInteger off = 0, len = 0;
    uint32_t leafCount = [data UInt32AtOffset:off];
    off += sizeof(uint32_t);
    NSNumber *l = nil;
    len = (NSUInteger)[data varIntAtOffset:off length:&l] * sizeof(UInt256);
    off += l.unsignedIntegerValue;
    NSData *hashes = (off + len > data.length) ? nil : [data subdataWithRange:NSMakeRange(off, len)];
    off += len;
    NSData *flags = [data dataAtOffset:off length:&l];
    if (hashes.length == 0) return nil;
    return [[DSMerkleTree alloc] initWithHashes:hashes flags:flags treeElementCount:elementCount hashFunction:hashFunction];
}

- (instancetype)initWithHashes:(NSData *)hashes flags:(NSData *)flags treeElementCount:(uint32_t)elementCount hashFunction:(DSMerkleTreeHashFunction)hashFunction {
    if (!(self = [self init])) return nil;
    self.hashes = hashes;
    self.flags = flags;
    self.treeElementCount = elementCount;
    self.hashFunction = hashFunction;
    return self;
}

// true if the given tx hash is included in the block
- (BOOL)containsHash:(UInt256)hash {
    for (NSUInteger i = 0; i < self.hashes.length / sizeof(UInt256); i += sizeof(UInt256)) {
        DSLogPrivate(@"hash %@", [NSData dataWithUInt256:[self.hashes UInt256AtOffset:i]].hexString);
        DSLogPrivate(@"looking for %@", [NSData dataWithUInt256:hash].hexString);
        if (uint256_eq(hash, [self.hashes UInt256AtOffset:i])) return YES;
    }

    return NO;
}

// returns an array of the matched tx hashes
- (NSArray *)elementHashes {
    int hashIdx = 0, flagIdx = 0;
    NSArray *hashes =
        [self walkHashIdx:&hashIdx
            flagIdx:&flagIdx
            depth:0
            leaf:^id(id hash, BOOL flag) {
                return (flag && hash) ? @[hash] : @[];
            }
            branch:^id(id left, id right) {
                return [left arrayByAddingObjectsFromArray:right];
            }];

    return hashes;
}

- (id)hashData:(NSMutableData *)data {
    switch (self.hashFunction) {
        case DSMerkleTreeHashFunction_SHA256_2:
            return uint256_obj(data.SHA256_2);
            break;
        case DSMerkleTreeHashFunction_BLAKE2b_160:
            return uint160_obj(data.blake2b_160);
            break;

        default:
            return uint256_obj(data.SHA256_2);
            break;
    }
}

- (UInt256)merkleRoot {
    NSMutableData *d = [NSMutableData data];
    UInt256 merkleRoot = UINT256_ZERO;
    int hashIdx = 0, flagIdx = 0;
    NSValue *root = [self walkHashIdx:&hashIdx
        flagIdx:&flagIdx
        depth:0
        leaf:^id(id hash, BOOL flag) {
            return hash;
        }
        branch:^id(id left, id right) {
            UInt256 l, r;

            if (!right) right = left; // if right branch is missing, duplicate left branch
            [left getValue:&l];
            [right getValue:&r];
            d.length = 0;
            [d appendBytes:&l length:sizeof(l)];
            [d appendBytes:&r length:sizeof(r)];
            return [self hashData:d];
        }];

    [root getValue:&merkleRoot];
    return merkleRoot;
}

- (BOOL)merkleTreeHasRoot:(UInt256)desiredMerkleRoot {
    //DSLog(@"%@ - %@",uint256_hex(merkleRoot),uint256_hex(_merkleRoot));
    if (self.treeElementCount > 0 && !uint256_eq(self.merkleRoot, desiredMerkleRoot)) return NO; // merkle root check failed
    return YES;
}

// recursively walks the merkle tree in depth first order, calling leaf(hash, flag) for each stored hash, and
// branch(left, right) with the result from each branch
- (id)walkHashIdx:(int *)hashIdx flagIdx:(int *)flagIdx
            depth:(int)depth
             leaf:(id (^)(id, BOOL))leaf
           branch:(id (^)(id, id))branch {
    if ((*flagIdx) / 8 >= _flags.length || (*hashIdx + 1) * sizeof(UInt256) > _hashes.length) return leaf(nil, NO);

    BOOL flag = (((const uint8_t *)_flags.bytes)[*flagIdx / 8] & (1 << (*flagIdx % 8)));

    (*flagIdx)++;

    if (!flag || depth == ceil_log2(self.treeElementCount)) {
        UInt256 hash = [_hashes UInt256AtOffset:(*hashIdx) * sizeof(UInt256)];

        (*hashIdx)++;
        return leaf(uint256_obj(hash), flag);
    }

    id left = [self walkHashIdx:hashIdx flagIdx:flagIdx depth:depth + 1 leaf:leaf branch:branch];
    id right = [self walkHashIdx:hashIdx flagIdx:flagIdx depth:depth + 1 leaf:leaf branch:branch];

    return branch(left, right);
}

- (id)copyWithZone:(NSZone *)zone {
    DSMerkleTree *copy = [[[self class] alloc] init];
    copy.treeElementCount = self.treeElementCount;
    copy.hashes = [self.hashes copyWithZone:zone];
    copy.flags = [self.flags copyWithZone:zone];
    return copy;
}

@end
