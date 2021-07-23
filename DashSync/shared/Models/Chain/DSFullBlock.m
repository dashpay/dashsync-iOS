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

#import "DSFullBlock.h"
#import "DSBlock+Protected.h"
#import "DSChain.h"
#import "DSChainLock.h"
#import "DSTransactionFactory.h"
#import "NSData+Bitcoin.h"
#import "NSData+DSHash.h"
#import "NSDate+Utils.h"
#import "NSMutableData+Dash.h"

@interface DSFullBlock ()

@property (nonatomic, strong) NSMutableArray<DSTransaction *> *mTransactions;

@end

@implementation DSFullBlock

// message can be either a merkleblock or header message
+ (instancetype)fullBlockWithMessage:(NSData *)message onChain:(DSChain *)chain {
    return [[self alloc] initWithMessage:message onChain:chain];
}

- (instancetype)initWithMessage:(NSData *)message onChain:(DSChain *)chain {
    if (!(self = [self init])) return nil;
    if (message.length < 80) return nil;
    NSNumber *l = nil;
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
    len = (NSUInteger)[message varIntAtOffset:off length:&l];
    off += l.unsignedIntegerValue;
    NSMutableArray *transactions = [NSMutableArray array];
    for (int i = 0; i < len; i++) {
        DSTransaction *transaction = [DSTransactionFactory transactionWithMessage:[message subdataWithRange:NSMakeRange(off, message.length - off)] onChain:chain];
        if (!transaction) break;
        [transactions addObject:transaction];
        off += transaction.payloadOffset;
    }
    self.height = BLOCK_UNKNOWN_HEIGHT;

    [d appendUInt32:self.version];
    [d appendUInt256:prevBlock];
    [d appendUInt256:merkleRoot];
    [d appendUInt32:self.timestamp];
    [d appendUInt32:self.target];
    [d appendUInt32:self.nonce];
    self.blockHash = d.x11;
    self.chain = chain;
    self.mTransactions = transactions;
    self.totalTransactions = (uint32_t)transactions.count;

    if (![self isMerkleTreeValid]) {
        DSLog(@"Merkle tree not valid for block");
        return nil;
    }

#if LOG_BLOCKS || LOG_BLOCKS_FULL
#if LOG_BLOCKS_FULL
    DSLog(@"%d - block %@ (%@) has %d transactions", self.height, uint256_hex(self.blockHash), message.hexString, self.totalTransactions);
#else
    DSLog(@"%d - block %@ has %d transactions", self.height, uint256_hex(self.blockHash), self.totalTransactions);
#endif
#endif

    return self;
}

- (instancetype)initWithCoinbaseTransaction:(DSCoinbaseTransaction *)coinbaseTransaction transactions:(NSSet<DSTransaction *> *)transactions previousBlockHash:(UInt256)previousBlockHash previousBlocks:(NSDictionary *)previousBlocks timestamp:(uint32_t)timestamp height:(uint32_t)height onChain:(DSChain *)chain {
    if (!(self = [super initWithVersion:2 timestamp:timestamp height:height onChain:chain])) return nil;
    NSMutableSet *totalTransactionsSet = [transactions mutableCopy];
    [totalTransactionsSet addObject:coinbaseTransaction];
    self.totalTransactions = (uint32_t)[totalTransactionsSet count];
    if (!transactions.count) {
        self.merkleRoot = coinbaseTransaction.txHash;
    }
    self.prevBlock = previousBlockHash;
    self.mTransactions = [[transactions allObjects] mutableCopy];
    [self.mTransactions addObject:coinbaseTransaction];
    NSMutableArray<NSValue *> *mTxHashes = [NSMutableArray array];
    for (DSTransaction *transaction in self.mTransactions) {
        [mTxHashes addObject:uint256_obj(transaction.txHash)];
    }
    self.transactionHashes = [mTxHashes copy];
    [self setTargetWithPreviousBlocks:previousBlocks];
    return self;
}

- (NSArray<DSTransaction *> *)transactions {
    return [_mTransactions copy];
}

- (void)setTargetWithPreviousBlocks:(NSDictionary *)previousBlocks {
    if (self.height <= self.chain.minimumDifficultyBlocks) {
        self.target = self.chain.maxProofOfWorkTarget;
    } else {
        self.target = [self darkGravityWaveTargetWithPreviousBlocks:previousBlocks];
    }
}

- (NSMutableData *)preNonceMutableData {
    NSMutableData *d = [NSMutableData data];

    [d appendUInt32:self.version];
    [d appendUInt256:self.prevBlock];
    [d appendUInt256:self.merkleRoot];
    [d appendUInt32:self.timestamp];
    [d appendUInt32:self.target];
    return d;
}

- (NSArray *)transactionHashes {
    NSMutableArray *mArray = [NSMutableArray array];
    for (DSTransaction *transaction in self.mTransactions) {
        [mArray addObject:uint256_obj(transaction.txHash)];
    }
    return [mArray copy];
}

- (NSArray *)transactionHashesAsData {
    NSMutableArray *mArray = [NSMutableArray array];
    for (DSTransaction *transaction in self.mTransactions) {
        [mArray addObject:uint256_data(transaction.txHash)];
    }
    return [mArray copy];
}

- (BOOL)isMerkleTreeValid {
    UInt256 merkleRoot = [NSData merkleRootFromHashes:[self transactionHashesAsData]].UInt256;
    if (self.totalTransactions > 0 && !uint256_eq(merkleRoot, self.merkleRoot)) return NO; // merkle root check failed
    return YES;
}

#define LOG_MINING_BEST_TRIES 0

- (BOOL)mineBlockAfterBlock:(DSBlock *)block withNonceOffset:(uint32_t)nonceOffset withTimeout:(NSTimeInterval)timeout rAttempts:(uint64_t *)rAttempts {
    BOOL found = false;
    self.prevBlock = block.blockHash;
    NSMutableData *preNonceMutableData = [self preNonceMutableData];
    uint32_t i = 0;
    UInt256 fullTarget = setCompactLE(block.target);
    DSLog(@"Trying to mine a block at height %d with target %@", block.height, uint256_bin(fullTarget));
#if LOG_MINING_BEST_TRIES
    UInt256 bestTry = UINT256_MAX;
#endif
    do {
        NSMutableData *d = [preNonceMutableData mutableCopy];
        [d appendUInt32:i];
        UInt256 potentialBlockHash = d.x11;

        if (!uint256_sup(potentialBlockHash, fullTarget)) {
            //We found a block
            DSLog(@"A Block was found %@ %@", uint256_bin(fullTarget), uint256_bin(potentialBlockHash));
            self.blockHash = potentialBlockHash;
            found = TRUE;
            break;
        }
#if LOG_MINING_BEST_TRIES
        else if (uint256_sup(bestTry, potentialBlockHash)) {
            DSLog(@"New best try (%d) found for target %@ %@", i, uint256_bin(fullTarget), uint256_bin(potentialBlockHash));
            bestTry = potentialBlockHash;
        }
#endif
        i++;
    } while (i != UINT32_MAX);
    if (!found) {
        self.timestamp++;
        return [self mineBlockAfterBlock:block withNonceOffset:0 withTimeout:timeout rAttempts:rAttempts];
    }
    rAttempts += i;
    return found;
}

@end
