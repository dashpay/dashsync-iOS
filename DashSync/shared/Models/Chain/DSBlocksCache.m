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

#import "BigIntTypes.h"
#import "DSBlocksCache.h"
#import "DSMerkleBlock.h"
#import "NSData+Dash.h"

@interface DSBlocksCache ()

@property (nonatomic, strong) DSBlock *lastSyncBlock, *lastTerminalBlock, *lastOrphan;
@property (nonatomic, strong) NSMutableDictionary<NSValue *, DSBlock *> *mSyncBlocks, *mTerminalBlocks, *mOrphans;
@property (nonatomic, assign) uint32_t lastPersistedChainSyncBlockHeight;
@property (nonatomic, assign) UInt256 lastPersistedChainSyncBlockHash;
@property (nonatomic, assign) NSTimeInterval lastPersistedChainSyncBlockTimestamp;
@property (nonatomic, assign) UInt256 lastPersistedChainSyncBlockChainWork;

@end

@implementation DSBlocksCache

- (instancetype)init {
    if (!(self = [super init])) return nil;
    self.mOrphans = [NSMutableDictionary dictionary];
    self.mSyncBlocks = [NSMutableDictionary dictionary];
    self.mTerminalBlocks = [NSMutableDictionary dictionary];
    return self;
}

- (NSDictionary<NSValue *, DSBlock *> *)orphans {
    return [self.mOrphans copy];
}

- (NSDictionary *)recentBlocks {
    return [[self mSyncBlocks] copy];
}

- (void)resetLastSyncBlock {
    _lastSyncBlock = nil;
}

- (void)setSyncBlockFromCheckpoint:(DSCheckpoint *)checkpoint forChain:(DSChain *)chain {
    if (self.mSyncBlocks[uint256_obj(checkpoint.blockHash)]) {
        _lastSyncBlock = self.mSyncBlocks[uint256_obj(checkpoint.blockHash)];
    } else {
        _lastSyncBlock = [[DSMerkleBlock alloc] initWithCheckpoint:checkpoint onChain:chain];
        self.mSyncBlocks[uint256_obj(checkpoint.blockHash)] = _lastSyncBlock;
    }
    if (_lastSyncBlock) {
        DSLog(@"[%@] last sync block at height %d chosen from checkpoints (hash is %@)", 
              [chain name],
              _lastSyncBlock.height,
              [NSData dataWithUInt256:_lastSyncBlock.blockHash].hexString);
    }
}


- (void)setLastSyncBlockFromCheckpoints:(DSCheckpoint *)checkpoint forChain:(DSChain *)chain {
    
}

- (DSBlock *)lastSyncBlockWithUseCheckpoints:(BOOL)useCheckpoints forChain:(DSChain *)chain {
    if (_lastSyncBlock) return _lastSyncBlock;
    
    if (!_lastSyncBlock && uint256_is_not_zero(self.lastPersistedChainSyncBlockHash) && uint256_is_not_zero(self.lastPersistedChainSyncBlockChainWork) && self.lastPersistedChainSyncBlockHeight != BLOCK_UNKNOWN_HEIGHT) {
        _lastSyncBlock = [[DSMerkleBlock alloc] initWithVersion:2 blockHash:self.lastPersistedChainSyncBlockHash prevBlock:UINT256_ZERO timestamp:self.lastPersistedChainSyncBlockTimestamp height:self.lastPersistedChainSyncBlockHeight chainWork:self.lastPersistedChainSyncBlockChainWork onChain:self];
    }
    
    if (!_lastSyncBlock && useCheckpoints) {
        DSLog(@"[%@] No last Sync Block, setting it from checkpoints", self.name);
        [self setLastSyncBlockFromCheckpoints];
    }
    
    return _lastSyncBlock;
}

// MARK: - Heights

- (NSTimeInterval)lastSyncBlockTimestamp {
    return _lastSyncBlock ? _lastSyncBlock.timestamp : (self.lastPersistedChainSyncBlockTimestamp ? self.lastPersistedChainSyncBlockTimestamp : self.lastSyncBlock.timestamp);
}

- (uint32_t)lastSyncBlockHeight {
    @synchronized (_lastSyncBlock) {
        if (_lastSyncBlock) {
            return _lastSyncBlock.height;
        } else if (self.lastPersistedChainSyncBlockHeight) {
            return self.lastPersistedChainSyncBlockHeight;
        } else {
            return self.lastSyncBlock.height;
        }
    }
}

- (UInt256)lastSyncBlockHash {
    return _lastSyncBlock ? _lastSyncBlock.blockHash : (uint256_is_not_zero(self.lastPersistedChainSyncBlockHash) ? self.lastPersistedChainSyncBlockHash : self.lastSyncBlock.blockHash);
}

- (UInt256)lastSyncBlockChainWork {
    return _lastSyncBlock ? _lastSyncBlock.chainWork : (uint256_is_not_zero(self.lastPersistedChainSyncBlockChainWork) ? self.lastPersistedChainSyncBlockChainWork : self.lastSyncBlock.chainWork);
}

- (uint32_t)lastTerminalBlockHeight {
    return self.lastTerminalBlock.height;
}

- (void)setLastPersistedSyncBlockHeight:(uint32_t)blockHeight
                              blockHash:(UInt256)blockHash
                              timestamp:(NSTimeInterval)timestamp
                              chainWork:(UInt256)chainWork {
    self.lastPersistedChainSyncBlockHeight = blockHeight;
    self.lastPersistedChainSyncBlockHash = blockHash;
    self.lastPersistedChainSyncBlockTimestamp = timestamp;
    self.lastPersistedChainSyncBlockChainWork = chainWork;
}


@end
