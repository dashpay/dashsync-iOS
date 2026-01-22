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
#import "DSChain.h"
#import "DSChainLock.h"
#import "DSKeyManager.h"
#import "DSMerkleTree.h"
#import "NSData+DSHash.h"
#import "NSData+Dash.h"
#import "NSDate+Utils.h"
#import "NSMutableData+Dash.h"

#define LOG_MERKLE_BLOCKS 0
#define LOG_MERKLE_BLOCKS_FULL (LOG_MERKLE_BLOCKS && 1)

@interface DSMerkleBlock ()

@property (nonatomic, strong) DSMerkleTree *merkleTree;

@end

@implementation DSMerkleBlock

// message can be either a merkleblock or header message
+ (instancetype)merkleBlockWithMessage:(NSData *)message onChain:(DSChain *)chain {
    return [[self alloc] initWithMessage:message onChain:chain];
}

- (instancetype)initWithMessage:(NSData *)message onChain:(DSChain *)chain {
    if (!(self = [self init])) return nil;
    if (message.length < 80) return nil;
    NSNumber *l = nil;
    NSUInteger off = 0, len = 0;

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
    len = (NSUInteger)[message varIntAtOffset:off length:&l] * sizeof(UInt256);
    off += l.unsignedIntegerValue;
    NSData *hashes = (off + len > message.length) ? nil : [message subdataWithRange:NSMakeRange(off, len)];
    off += len;
    NSData *flags = [message dataAtOffset:off length:&l];
    self.merkleTree = [[DSMerkleTree alloc] initWithHashes:hashes flags:flags treeElementCount:self.totalTransactions hashFunction:DSMerkleTreeHashFunction_SHA256_2];
    self.height = BLOCK_UNKNOWN_HEIGHT;

    NSMutableData *d = [NSMutableData data];
    [d appendUInt32:self.version];
    [d appendUInt256:prevBlock];
    [d appendUInt256:merkleRoot];
    [d appendUInt32:self.timestamp];
    [d appendUInt32:self.target];
    [d appendUInt32:self.nonce];
    self.blockHash = [DSKeyManager x11:d];
    self.chain = chain;

    return self;
}

- (instancetype)initWithBlockHash:(UInt256)blockHash merkleRoot:(UInt256)merkleRoot totalTransactions:(uint32_t)totalTransactions hashes:(NSData *)hashes flags:(NSData *)flags {
    if (!(self = [self init])) return nil;

    self.blockHash = blockHash;
    self.merkleRoot = merkleRoot;
    self.totalTransactions = totalTransactions;
    self.merkleTree = [[DSMerkleTree alloc] initWithHashes:hashes flags:flags treeElementCount:self.totalTransactions hashFunction:DSMerkleTreeHashFunction_SHA256_2];
    self.chainLocked = FALSE;
    return self;
}

- (instancetype)initWithVersion:(uint32_t)version blockHash:(UInt256)blockHash prevBlock:(UInt256)prevBlock
                     merkleRoot:(UInt256)merkleRoot
                      timestamp:(uint32_t)timestamp
                         target:(uint32_t)target
                      chainWork:(UInt256)aggregateWork
                          nonce:(uint32_t)nonce
              totalTransactions:(uint32_t)totalTransactions
                         hashes:(NSData *)hashes
                          flags:(NSData *)flags
                         height:(uint32_t)height
                      chainLock:(DSChainLock *)chainLock
                        onChain:(DSChain *)chain {
    if (!(self = [self initWithBlockHash:blockHash merkleRoot:merkleRoot totalTransactions:totalTransactions hashes:hashes flags:flags])) return nil;

    self.version = version;
    self.prevBlock = prevBlock;
    self.merkleRoot = merkleRoot;
    self.timestamp = timestamp;
    self.target = target;
    self.nonce = nonce;
    self.height = height;
    self.chainWork = aggregateWork;
    [self setChainLockedWithChainLock:chainLock];
    self.chain = chain;

    return self;
}

- (NSData *)toData {
    NSMutableData *d = [[super toData] mutableCopy];

    if (self.totalTransactions > 0) {
        [d appendUInt32:self.totalTransactions];
        [d appendVarInt:self.merkleTree.hashes.length / sizeof(UInt256)];
        [d appendData:self.merkleTree.hashes];
        [d appendCountedData:self.merkleTree.flags];
    }

    return d;
}

// true if the given tx hash is included in the block
- (BOOL)containsTxHash:(UInt256)txHash {
    return [self.merkleTree containsHash:txHash];
}

// returns an array of the matched tx hashes
- (NSArray *)transactionHashes {
    return [self.merkleTree elementHashes];
}


- (BOOL)isMerkleTreeValid {
    return [self.merkleTree merkleTreeHasRoot:self.merkleRoot];
}

- (id)copyWithZone:(NSZone *)zone {
    DSMerkleBlock *copy = [[[self class] alloc] init];
    copy.blockHash = self.blockHash;
    copy.height = self.height;
    copy.version = self.version;
    copy.prevBlock = self.prevBlock;
    copy.merkleRoot = self.merkleRoot;
    copy.timestamp = self.timestamp;
    copy.target = self.target;
    copy.nonce = self.nonce;
    copy.totalTransactions = self.totalTransactions;
    copy.merkleTree = [self.merkleTree copyWithZone:zone];
    copy.transactionHashes = [self.transactionHashes copyWithZone:zone];

    copy.valid = self.valid;
    copy.merkleTreeValid = self.isMerkleTreeValid;
    copy.data = [self.data copyWithZone:zone];
    copy.chainWork = self.chainWork;
    return copy;
}


@end
