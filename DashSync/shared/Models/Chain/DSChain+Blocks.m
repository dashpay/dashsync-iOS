//  
//  Created by Vladimir Pirogov
//  Copyright © 2024 Dash Core Group. All rights reserved.
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

#import <Foundation/Foundation.h>
#import "DSChain+Protected.h"
#import "DSBlocksCache.h"
#import "DSBlocksCache+Protected.h"

@interface DSChain ()

@end

@implementation DSChain (Blocks)

- (uint32_t)estimatedBlockHeight {
    return [self.blocksCache estimatedBlockHeight];
}

- (void)blockUntilGetInsightForBlockHash:(UInt256)blockHash {
    [self.blocksCache blockUntilGetInsightForBlockHash:blockHash];
}

- (NSTimeInterval)timestampForBlockHeight:(uint32_t)blockHeight {
    return [self.blocksCache timestampForBlockHeight:blockHeight];
}

- (DSBlock *_Nullable)blockAtHeight:(uint32_t)height {
    return [self.blocksCache blockAtHeight:height];
}

- (DSBlock *)blockAtHeightOrLastTerminal:(uint32_t)height {
    return [self.blocksCache blockAtHeightOrLastTerminal:height];
}

- (DSMerkleBlock *_Nullable)blockForBlockHash:(UInt256)blockHash {
    return [self.blocksCache blockForBlockHash:blockHash];
}

- (DSBlock *)recentTerminalBlockForBlockHash:(UInt256)blockHash {
    return [self.blocksCache recentTerminalBlockForBlockHash:blockHash];
}
- (DSBlock *_Nullable)blockFromChainTip:(NSUInteger)blocksAgo {
    return [self.blocksCache blockFromChainTip:blocksAgo];
}

- (uint32_t)heightForBlockHash:(UInt256)blockhash {
    return [self.blocksCache heightForBlockHash:blockhash];
}

- (uint32_t)quickHeightForBlockHash:(UInt256)blockhash {
    return [self.blocksCache quickHeightForBlockHash:blockhash];
}

- (NSArray<NSData *> *)blockLocatorArrayOnOrBeforeTimestamp:(NSTimeInterval)timestamp
                               includeInitialTerminalBlocks:(BOOL)includeHeaders {
    return [self.blocksCache blockLocatorArrayOnOrBeforeTimestamp:timestamp includeInitialTerminalBlocks:includeHeaders];
}

- (BOOL)addChainLock:(DSChainLock *)chainLock {
    return [self.blocksCache addChainLock:chainLock];
}
- (BOOL)blockHeightChainLocked:(uint32_t)height {
    return [self.blocksCache blockHeightChainLocked:height];
}

- (BOOL)addBlock:(DSBlock *)block receivedAsHeader:(BOOL)isHeaderOnly fromPeer:(DSPeer *_Nullable)peer {
    return [self.blocksCache addBlock:block receivedAsHeader:isHeaderOnly fromPeer:peer];
}
- (void)removeEstimatedBlockHeightOfPeer:(DSPeer *)peer {
    [self.blocksCache removeEstimatedBlockHeightOfPeer:peer];
}

- (BOOL)addMinedFullBlock:(DSFullBlock *)block {
    return [self.blocksCache addMinedFullBlock:block];
}
@end
