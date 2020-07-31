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
#import "NSMutableData+Dash.h"
#import "NSData+Dash.h"

@interface DSFullBlock()

@property (nonatomic,strong) NSMutableArray <DSTransaction*>* mTransactions;

@end

@implementation DSFullBlock

-(instancetype)initWithCoinbaseTransaction:(DSCoinbaseTransaction*)coinbaseTransaction transactions:(NSSet<DSTransaction*>*)transactions previousBlockHash:(UInt256)previousBlockHash previousBlocks:(NSDictionary*)previousBlocks timestamp:(uint32_t)timestamp height:(uint32_t)height onChain:(DSChain *)chain {
    if (!(self = [super initWithVersion:2 timestamp:timestamp height:height onChain:chain])) return nil;
    NSMutableSet * totalTransactionsSet = [transactions mutableCopy];
    [totalTransactionsSet addObject:coinbaseTransaction];
    self.totalTransactions = (uint32_t)[totalTransactionsSet count];
    if (!transactions.count) {
        self.merkleRoot = coinbaseTransaction.txHash;
    }
    self.prevBlock = previousBlockHash;
    self.mTransactions = [[transactions allObjects] mutableCopy];
    [self.mTransactions addObject:coinbaseTransaction];
    NSMutableArray <NSValue*>* mTxHashes = [NSMutableArray array];
    for (DSTransaction * transaction in self.mTransactions) {
        [mTxHashes addObject:uint256_obj(transaction.txHash)];
    }
    self.txHashes = [mTxHashes copy];
    [self setTargetWithPreviousBlocks:previousBlocks];
    return self;
}

-(NSArray<DSTransaction*>*)transactions {
    return [_mTransactions copy];
}

-(void)setTargetWithPreviousBlocks:(NSDictionary*)previousBlocks {
    if (self.height <= self.chain.minimumDifficultyBlocks) {
        self.target = self.chain.maxProofOfWorkTarget;
    } else {
        self.target = [self darkGravityWaveTargetWithPreviousBlocks:previousBlocks];
    }
}

- (NSMutableData *)preNonceMutableData
{
    NSMutableData *d = [NSMutableData data];
    
    [d appendUInt32:self.version];
    [d appendUInt256:self.prevBlock];
    [d appendUInt256:self.merkleRoot];
    [d appendUInt32:self.timestamp];
    [d appendUInt32:self.target];
    return d;
}

#define LOG_MINING_BEST_TRIES 0

-(BOOL)mineBlockAfterBlock:(DSBlock*)block withNonceOffset:(uint32_t)nonceOffset withTimeout:(NSTimeInterval)timeout rAttempts:(uint64_t*)rAttempts {
    BOOL found = false;
    self.prevBlock = block.blockHash;
    NSMutableData * preNonceMutableData = [self preNonceMutableData];
    uint32_t i = 0;
    UInt256 fullTarget = setCompactLE(block.target);
    DSDLog(@"Trying to mine a block at height %d with target %@", block.height, uint256_bin(fullTarget));
#if LOG_MINING_BEST_TRIES
    UInt256 bestTry = UINT256_MAX;
#endif
    do {
        NSMutableData * d = [preNonceMutableData mutableCopy];
        [d appendUInt32:i];
        UInt256 potentialBlockHash = d.x11;
        
        if (!uint256_sup(potentialBlockHash, fullTarget)) {
            //We found a block
            DSDLog(@"A Block was found %@ %@",uint256_bin(fullTarget),uint256_bin(potentialBlockHash));
            self.blockHash = potentialBlockHash;
            found = TRUE;
            break;
        }
#if LOG_MINING_BEST_TRIES
        else if (uint256_sup(bestTry,potentialBlockHash)) {
            DSDLog(@"New best try (%d) found for target %@ %@",i,uint256_bin(fullTarget),uint256_bin(potentialBlockHash));
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
