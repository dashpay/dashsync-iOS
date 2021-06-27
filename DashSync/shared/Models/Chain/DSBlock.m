//
//  Created by Sam Westrich
//  Copyright © 2020 Dash Core Group. All rights reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://opensource.org/licenses/MIT
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "DSBlock+Protected.h"
#import "DSChain.h"
#import "DSChainLock.h"
#import "DSCheckpoint.h"
#import "NSData+Bitcoin.h"
#import "NSData+Dash.h"
#import "NSDate+Utils.h"
#import "NSMutableData+Dash.h"

#define MAX_TIME_DRIFT (2 * 60 * 60) // the furthest in the future a block is allowed to be timestamped

@implementation DSBlock

- (instancetype)initWithBlockHash:(UInt256)blockHash height:(uint32_t)height onChain:(DSChain *)chain {
    if (!(self = [self init])) return nil;
    _height = height;
    _blockHash = blockHash;

    self.chain = chain;

    return self;
}

- (instancetype)initWithVersion:(uint32_t)version timestamp:(uint32_t)timestamp height:(uint32_t)height onChain:(DSChain *)chain {
    if (!(self = [self init])) return nil;
    _height = height;
    _version = version;
    _timestamp = timestamp;

    self.chain = chain;

    return self;
}

- (instancetype)initWithVersion:(uint32_t)version blockHash:(UInt256)blockHash prevBlock:(UInt256)prevBlock timestamp:(uint32_t)timestamp height:(uint32_t)height chainWork:(UInt256)chainWork onChain:(DSChain *)chain {
    if (!(self = [self initWithVersion:version timestamp:timestamp height:height onChain:chain])) return nil;
    _blockHash = blockHash;
    _prevBlock = prevBlock;
    _chainWork = chainWork;
    return self;
}

- (instancetype)initWithVersion:(uint32_t)version blockHash:(UInt256)blockHash prevBlock:(UInt256)prevBlock timestamp:(uint32_t)timestamp merkleRoot:(UInt256)merkleRoot target:(uint32_t)target chainWork:(UInt256)chainWork height:(uint32_t)height onChain:(DSChain *)chain {
    if (!(self = [self initWithVersion:version blockHash:blockHash prevBlock:prevBlock timestamp:timestamp height:height chainWork:chainWork onChain:chain])) return nil;
    _merkleRoot = merkleRoot;
    _target = target;
    return self;
}

- (instancetype)initWithCheckpoint:(DSCheckpoint *)checkpoint onChain:(DSChain *)chain {
    NSAssert(uint256_is_not_zero(checkpoint.chainWork), @"Chain work must be set");
    if (!(self = [self initWithVersion:2 blockHash:checkpoint.blockHash prevBlock:UINT256_ZERO timestamp:checkpoint.timestamp merkleRoot:checkpoint.merkleRoot target:checkpoint.target chainWork:checkpoint.chainWork height:checkpoint.height onChain:chain])) return nil;
    NSAssert(uint256_is_not_zero(self.chainWork), @"block should have aggregate work set");
    return self;
}

- (NSValue *)prevBlockValue {
    if (!_prevBlockValue) {
        _prevBlockValue = uint256_obj(self.prevBlock);
    }
    return _prevBlockValue;
}

- (NSValue *)blockHashValue {
    if (!_blockHashValue) {
        _blockHashValue = uint256_obj(self.blockHash);
    }
    return _blockHashValue;
}

// true if merkle tree and timestamp are valid
// NOTE: This only checks if the block difficulty matches the difficulty target in the header. It does not check if the
// target is correct for the block's height in the chain. Use verifyDifficultyFromPreviousBlock: for that.
- (BOOL)isValid {
    if (![self isMerkleTreeValid]) return NO;

    // check if timestamp is too far in future
    //TODO: use estimated network time instead of system time (avoids timejacking attacks and misconfigured time)
    if (_timestamp > [NSDate timeIntervalSince1970] + MAX_TIME_DRIFT) return NO;

    return YES;
}

- (NSData *)toData {
    NSMutableData *d = [NSMutableData data];

    [d appendUInt32:_version];
    [d appendUInt256:_prevBlock];
    [d appendUInt256:_merkleRoot];
    [d appendUInt32:_timestamp];
    [d appendUInt32:_target];
    [d appendUInt32:_nonce];

    return d;
}

- (BOOL)canCalculateDifficultyWithPreviousBlocks:(NSDictionary *)previousBlocks {
    DSBlock *previousBlock = previousBlocks[uint256_obj(self.prevBlock)];
    if (!previousBlock) {
        return FALSE;
    }
    if (uint256_is_zero(_prevBlock) || previousBlock.height == 0 || previousBlock.height < DGW_PAST_BLOCKS_MIN + (self.chain.isDevnetAny ? 1 : 0)) {
        return TRUE;
    }
    if (self.chain.allowMinDifficultyBlocks) {
        // recent block is more than 2 hours old
        if (self.timestamp > (previousBlock.timestamp + 2 * 60 * 60)) {
            return TRUE;
        }
        // recent block is more than 10 minutes old
        if (self.timestamp > (previousBlock.timestamp + 2.5 * 60 * 4)) {
            return TRUE;
        }
    }
    DSBlock *currentBlock = previousBlock;
    uint32_t blockCount = 0;
    // loop over the past n blocks, where n == PastBlocksMax
    for (blockCount = 1; currentBlock && currentBlock.height > 0 && blockCount <= DGW_PAST_BLOCKS_MAX; blockCount++) {
        if (previousBlock == nil) {
            assert(currentBlock);
            break;
        }
        currentBlock = previousBlocks[uint256_obj(currentBlock.prevBlock)];
        if (!currentBlock) {
            DSLog(@"Could not retrieve previous block");
            return FALSE;
        }
    }
    return TRUE;
}

- (BOOL)verifyDifficultyWithPreviousBlocks:(NSDictionary *)previousBlocks rDifficulty:(uint32_t *)difficulty {
    uint32_t darkGravityWaveTarget = [self darkGravityWaveTargetWithPreviousBlocks:previousBlocks];
    if (difficulty) {
        *difficulty = darkGravityWaveTarget;
    }
    int32_t diff = self.target - darkGravityWaveTarget;
    if (abs(diff) > 1) {
        DSLog(@"weird difficulty for block at height %u with target %@ (off by %u)", self.height, uint256_hex(setCompactBE(self.target)), diff);
    }
    return (abs(diff) < 2); //the core client is less precise with a rounding error that can sometimes cause a problem. We are very rarely 1 off
}

- (int32_t)darkGravityWaveTargetWithPreviousBlocks:(NSDictionary *)previousBlocks {
    /* current difficulty formula, darkcoin - based on DarkGravity v3, original work done by evan duffield, modified for iOS */
    DSBlock *previousBlock = previousBlocks[uint256_obj(self.prevBlock)];

    int32_t nActualTimespan = 0;
    int64_t lastBlockTime = 0;
    uint32_t blockCount = 0;
    UInt256 sumTargets = UINT256_ZERO;

    if (uint256_is_zero(_prevBlock) || previousBlock.height == 0 || previousBlock.height < DGW_PAST_BLOCKS_MIN + (self.chain.isDevnetAny ? 1 : 0)) {
        // This is the first block or the height is < PastBlocksMin
        // Return minimal required work. (1e0ffff0)
        return self.chain.maxProofOfWorkTarget;
    }

    if (self.chain.allowMinDifficultyBlocks) {
        // recent block is more than 2 hours old
        if (self.timestamp > (previousBlock.timestamp + 2 * 60 * 60)) {
            DSLog(@"Our block is way ahead of previous block %d > %d", self.timestamp, previousBlock.timestamp);
            return self.chain.maxProofOfWorkTarget;
        }
        // recent block is more than 10 minutes old
        if (self.timestamp > (previousBlock.timestamp + 2.5 * 60 * 4)) {
            //DSLog(@"Our block is over 10 minutes old %d > %d", self.timestamp, previousBlock.timestamp);
            UInt256 previousTarget = setCompactLE(previousBlock.target);

            UInt256 newTarget = uInt256MultiplyUInt32LE(previousTarget, 10);
            uint32_t compact = getCompactLE(newTarget);
            if (compact > self.chain.maxProofOfWorkTarget) {
                DSLog(@"Setting desired target to max proof of work");
                compact = self.chain.maxProofOfWorkTarget;
            }
            return compact;
        }
    }

    DSBlock *currentBlock = previousBlock;
    // loop over the past n blocks, where n == PastBlocksMax
    for (blockCount = 1; currentBlock && currentBlock.height > 0 && blockCount <= DGW_PAST_BLOCKS_MAX; blockCount++) {
        // Calculate average difficulty based on the blocks we iterate over in this for loop
        if (blockCount <= DGW_PAST_BLOCKS_MIN) {
            UInt256 currentTarget = setCompactLE(currentBlock.target);
            //DSLog(@"currentTarget for block %d is %@", currentBlock.height, uint256_hex(currentTarget));
            //if (self.height == 1070917)
            //DSLog(@"%d",currentTarget);
            if (blockCount == 1) {
                sumTargets = uInt256AddLE(currentTarget, currentTarget);
            } else {
                sumTargets = uInt256AddLE(sumTargets, currentTarget);
            }
            //DSLog(@"sumTarget for block %d is %@", currentBlock.height, uint256_hex(sumTargets));
        }

        // If this is the second iteration (LastBlockTime was set)
        if (lastBlockTime > 0) {
            // Calculate time difference between previous block and current block
            int64_t currentBlockTime = currentBlock.timestamp;
            int64_t diff = ((lastBlockTime) - (currentBlockTime));
            // Increment the actual timespan
            nActualTimespan += diff;
        }
        // Set lastBlockTime to the block time for the block in current iteration
        lastBlockTime = currentBlock.timestamp;

        if (previousBlock == nil) {
            assert(currentBlock);
            break;
        }
        DSBlock *oldCurrentBlock = currentBlock;
        currentBlock = previousBlocks[uint256_obj(currentBlock.prevBlock)];
        if (!currentBlock) {
            DSLog(@"Block %d missing for dark gravity wave calculation", oldCurrentBlock.height - 1);
        }
    }
    UInt256 blockCount256 = ((UInt256){.u64 = {blockCount, 0, 0, 0}});
    // darkTarget is the difficulty
    //DSLog(@"SumTargets for block %d is %@, blockCount is %@", self.height, uint256_hex(sumTargets), uint256_hex(blockCount256));
    UInt256 darkTarget = uInt256DivideLE(sumTargets, blockCount256);

    // nTargetTimespan is the time that the CountBlocks should have taken to be generated.
    uint32_t nTargetTimespan = (blockCount - 1) * (60 * 2.5);

    //DSLog(@"Original dark target for block %d is %@", self.height, uint256_hex(darkTarget));
    //DSLog(@"Max proof of work is %@", uint256_hex(self.chain.maxProofOfWork));
    // Limit the re-adjustment to 3x or 0.33x
    // We don't want to increase/decrease diff too much.
    if (nActualTimespan < nTargetTimespan / 3.0f)
        nActualTimespan = nTargetTimespan / 3.0f;
    if (nActualTimespan > nTargetTimespan * 3.0f)
        nActualTimespan = nTargetTimespan * 3.0f;


    darkTarget = uInt256MultiplyUInt32LE(darkTarget, nActualTimespan);
    UInt256 nTargetTimespan256 = ((UInt256){.u64 = {nTargetTimespan, 0, 0, 0}});

    //DSLog(@"Middle dark target for block %d is %@", self.height, uint256_hex(darkTarget));
    //DSLog(@"nTargetTimespan256 for block %d is %@", self.height, uint256_hex(nTargetTimespan256));
    // Calculate the new difficulty based on actual and target timespan.
    darkTarget = uInt256DivideLE(darkTarget, nTargetTimespan256);

    //DSLog(@"Final dark target for block %d is %@", self.height, uint256_hex(darkTarget));

    // If calculated difficulty is lower than the minimal diff, set the new difficulty to be the minimal diff.
    if (uint256_sup(darkTarget, self.chain.maxProofOfWork)) {
        DSLog(@"Found a block with minimum difficulty");
        return self.chain.maxProofOfWorkTarget;
    }

    // Return the new diff.
    return getCompactLE(darkTarget);
}

- (BOOL)containsTxHash:(UInt256)txHash {
    NSAssert(NO, @"This should be overridden");
    return NO;
}

// v14

- (void)setChainLockedWithEquivalentBlock:(DSBlock *)block {
    if (uint256_eq(block.blockHash, self.blockHash)) {
        self.chainLocked |= block.chainLocked;
        self.hasUnverifiedChainLock |= block.hasUnverifiedChainLock;
        if (self.hasUnverifiedChainLock) {
            self.chainLockAwaitingProcessing = block.chainLockAwaitingProcessing;
        }
    }
}

- (void)setChainLockedWithChainLock:(DSChainLock *)chainLock {
    if (!chainLock) {
        self.chainLocked = FALSE;
        self.hasUnverifiedChainLock = FALSE;
        return;
    }
    self.chainLocked = chainLock.signatureVerified;
    self.hasUnverifiedChainLock = (chainLock && !chainLock.signatureVerified);
    if (self.hasUnverifiedChainLock) {
        self.chainLockAwaitingProcessing = chainLock;
    } else {
        self.chainLockAwaitingProcessing = nil;
    }
    if (!chainLock.saved) {
        [chainLock saveInitial];
        if (!chainLock.saved) {
            //it is still not saved
            self.chainLockAwaitingSaving = chainLock;
        }
    }
}

- (BOOL)hasChainLockAwaitingSaving {
    return (self.chainLockAwaitingSaving != nil);
}

- (BOOL)saveAssociatedChainLock {
    if (self.hasChainLockAwaitingSaving && !self.chainLockAwaitingSaving.saved) {
        [self.chainLockAwaitingSaving saveInitial];
        if (self.chainLockAwaitingSaving.saved) {
            self.chainLockAwaitingSaving = nil;
            return TRUE;
        } else {
            return FALSE;
        }
    }
    return TRUE;
}

- (NSUInteger)hash {
    if (uint256_is_zero(_blockHash)) return super.hash;
    return *(const NSUInteger *)&_blockHash;
}

- (BOOL)isEqual:(id)obj {
    return self == obj || ([obj isMemberOfClass:[self class]] && uint256_eq([obj blockHash], _blockHash));
}

- (NSString *)description {
    return [NSString stringWithFormat:@"Block H:%u - <%@>", self.height, uint256_hex(self.blockHash)];
}

- (id)copyWithZone:(NSZone *)zone {
    DSBlock *copy = [[[self class] alloc] init];
    copy.blockHash = self.blockHash;
    copy.height = self.height;
    copy.version = self.version;
    copy.prevBlock = self.prevBlock;
    copy.merkleRoot = self.merkleRoot;
    copy.timestamp = self.timestamp;
    copy.target = self.target;
    copy.nonce = self.nonce;
    copy.totalTransactions = self.totalTransactions;
    copy.transactionHashes = [self.transactionHashes copyWithZone:zone];
    copy.valid = self.valid;
    copy.merkleTreeValid = self.isMerkleTreeValid;
    copy.data = [self.data copyWithZone:zone];
    copy.chainWork = self.chainWork;
    return copy;
}

@end
