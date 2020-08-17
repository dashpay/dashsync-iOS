//
//  DSMerkleBlock.h
//  DashSync
//
//  Created by Samuel Westrich for DashSync on July 8th 2020.
//  Copyright (c) 2020 Dash Core Group <contact@dash.org>
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

#import <Foundation/Foundation.h>

#define BLOCK_UNKNOWN_HEIGHT      INT32_MAX
#define DGW_PAST_BLOCKS_MIN 24
#define DGW_PAST_BLOCKS_MAX 24

NS_ASSUME_NONNULL_BEGIN

typedef union _UInt256 UInt256;

@class DSChain, DSChainLock, DSCheckpoint;

@interface DSBlock : NSObject <NSCopying>

@property (nonatomic, readonly) UInt256 blockHash;
@property (nonatomic, readonly) NSValue * blockHashValue;
@property (nonatomic, readonly) uint32_t version;
@property (nonatomic, readonly) UInt256 prevBlock;
@property (nonatomic, readonly) NSValue * prevBlockValue;
@property (nonatomic, readonly) UInt256 merkleRoot;
@property (nonatomic, readonly) uint32_t timestamp; // time interval since unix epoch
@property (nonatomic, readonly) uint32_t target;
@property (nonatomic, readonly) uint32_t nonce;
@property (nonatomic, readonly) uint32_t totalTransactions;
@property (nonatomic, readonly) uint32_t height;
@property (nonatomic, readonly) DSChain *chain;
@property (nonatomic, readonly) BOOL chainLocked;
@property (nonatomic, readonly) UInt256 chainWork;

@property (nonatomic, readonly) NSArray *transactionHashes; // the matched tx hashes in the block

// true if merkle tree and timestamp are valid, and proof-of-work matches the stated difficulty target
// NOTE: This only checks if the block difficulty matches the difficulty target in the header. It does not check if the
// target is correct for the block's height in the chain. Use verifyDifficultyFromPreviousBlock: for that.
@property (nonatomic, readonly, getter = isValid) BOOL valid;
@property (nonatomic, readonly, getter = isMerkleTreeValid) BOOL merkleTreeValid;

@property (nonatomic, readonly, getter = toData) NSData *data;

- (instancetype)initWithVersion:(uint32_t)version blockHash:(UInt256)blockHash prevBlock:(UInt256)prevBlock timestamp:(uint32_t)timestamp height:(uint32_t)height onChain:(DSChain*)chain;

- (instancetype)initWithVersion:(uint32_t)version blockHash:(UInt256)blockHash prevBlock:(UInt256)prevBlock timestamp:(uint32_t)timestamp merkleRoot:(UInt256)merkleRoot target:(uint32_t)target chainWork:(UInt256)aggregateWork height:(uint32_t)height onChain:(DSChain*)chain;

- (instancetype)initWithCheckpoint:(DSCheckpoint*)checkpoint onChain:(DSChain*)chain;

// true if the given tx hash is known to be included in the block
- (BOOL)containsTxHash:(UInt256)txHash;

// Verifies the block difficulty target is correct for the block's position in the chain.
- (BOOL)verifyDifficultyWithPreviousBlocks:(NSDictionary *)previousBlocks rDifficulty:(uint32_t*)difficulty;

- (int32_t)darkGravityWaveTargetWithPreviousBlocks:(NSDictionary *)previousBlocks;

- (void)setChainLockedWithChainLock:(DSChainLock*)chainLock;

- (void)setChainLockedWithEquivalentBlock:(DSBlock*)block;

@end

NS_ASSUME_NONNULL_END
