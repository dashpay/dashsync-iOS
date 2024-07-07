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
#import "DSBIP39Mnemonic.h"
#import "DSBlock.h"
#import "DSBlock+Protected.h"
#import "DSBlocksCache.h"
#import "DSBlocksCache+Protected.h"
#import "DSChain+Params.h"
#import "DSChain+Protected.h"
#import "DSChainConstants.h"
#import "DSChainLock.h"
#import "DSChainManager+Protected.h"
#import "DSFullBlock.h"
#import "DSInsightManager.h"
#import "DSMerkleBlock.h"
#import "DSMerkleBlockEntity+CoreDataProperties.h"
#import "DSOptionsManager.h"
#import "DSPeer.h"
#import "NSData+Dash.h"

#define LOG_PREV_BLOCKS_ON_ORPHAN 0
#define BLOCK_NO_FORK_DEPTH 25

typedef NS_ENUM(uint16_t, DSBlockPosition) {
    DSBlockPosition_Orphan = 0,
    DSBlockPosition_Terminal = 1,
    DSBlockPosition_Sync = 2,
    DSBlockPosition_TerminalSync = DSBlockPosition_Terminal | DSBlockPosition_Sync
};


@interface DSBlocksCache ()

@property (nonatomic, strong) DSCheckpointsCache *checkpointsCache;
@property (nonatomic, strong) DSBlock *lastSyncBlock, *lastTerminalBlock, *lastOrphan;
@property (nonatomic, strong) NSMutableDictionary<NSValue *, DSBlock *> *mSyncBlocks, *mTerminalBlocks, *mOrphans;
@property (nonatomic, readonly) NSMutableDictionary<NSData *, DSBlock *> *insightVerifiedBlocksByHashDictionary;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSMutableArray<DSPeer *> *> *estimatedBlockHeights;

@property (nonatomic, assign) uint32_t bestEstimatedBlockHeight;

//@property (nonatomic, assign) uint32_t lastPersistedChainSyncBlockHeight;
//@property (nonatomic, assign) UInt256 lastPersistedChainSyncBlockHash;
//@property (nonatomic, assign) NSTimeInterval lastPersistedChainSyncBlockTimestamp;
@property (nonatomic, assign) UInt256 lastPersistedChainSyncBlockChainWork;

@property (nonatomic, assign) NSTimeInterval lastNotifiedBlockDidChange;
@property (nonatomic, strong) NSTimer *lastNotifiedBlockDidChangeTimer;

@property (nonatomic, strong) DSChain *chain;
@end

@implementation DSBlocksCache

- (instancetype)init {
    if (!(self = [super init])) return nil;
    
    self.mOrphans = [NSMutableDictionary dictionary];
    self.mSyncBlocks = [NSMutableDictionary dictionary];
    self.mTerminalBlocks = [NSMutableDictionary dictionary];
    self.estimatedBlockHeights = [NSMutableDictionary dictionary];
    self.lastNotifiedBlockDidChange = 0;

    return self;
}

- (instancetype)initWithFirstCheckpoint:(NSArray<DSCheckpoint *> *)checkpoints onChain:(DSChain *)chain {
    if (!(self = [self init])) return nil;
    self.chain = chain;
    self.checkpointsCache = [[DSCheckpointsCache alloc] initWithFirstCheckpoint:checkpoints];
    return self;
}

- (instancetype)initWithDevnet:(DevnetType)devnetType
                   checkpoints:(NSArray<DSCheckpoint *> *)checkpoints
             onProtocolVersion:(uint32_t)protocolVersion
                      forChain:(DSChain *)chain {
    if (!(self = [self init])) return nil;
    self.chain = chain;
    self.checkpointsCache = [[DSCheckpointsCache alloc] initWithDevnet:devnetType checkpoints:checkpoints onProtocolVersion:protocolVersion forChain:chain];
    return self;
}
- (BOOL)isEqual:(id)obj {
    return self == obj || ([obj isKindOfClass:[DSBlocksCache class]] && uint256_eq([obj genesisHash], self.genesisHash));
}


- (UInt256)genesisHash {
    return [self.checkpointsCache genesisHash];
}
- (BOOL)isGenesisExist {
    return [self.checkpointsCache isGenesisExist];
}

- (void)wipeBlockchainInfo {
    @synchronized (_mSyncBlocks) {
        _mSyncBlocks = [NSMutableDictionary dictionary];
    }
    @synchronized (_mTerminalBlocks) {
        _mTerminalBlocks = [NSMutableDictionary dictionary];
    }
    _lastSyncBlock = nil;
    _lastTerminalBlock = nil;
    _lastPersistedChainSyncLocators = nil;
    _lastPersistedChainSyncBlockHash = UINT256_ZERO;
    _lastPersistedChainSyncBlockChainWork = UINT256_ZERO;
    _lastPersistedChainSyncBlockHeight = 0;
    _lastPersistedChainSyncBlockTimestamp = 0;
    [self setLastTerminalBlockFromCheckpoints];
    [self setLastSyncBlockFromCheckpoints];
}

- (void)wipeBlockchainNonTerminalInfo {
    @synchronized (_mSyncBlocks) {
        _mSyncBlocks = [NSMutableDictionary dictionary];
    }
    _lastSyncBlock = nil;
    _lastPersistedChainSyncLocators = nil;
    _lastPersistedChainSyncBlockHash = UINT256_ZERO;
    _lastPersistedChainSyncBlockChainWork = UINT256_ZERO;
    _lastPersistedChainSyncBlockHeight = 0;
    _lastPersistedChainSyncBlockTimestamp = 0;
    [self setLastSyncBlockFromCheckpoints];
}

- (NSDictionary<NSValue *, DSBlock *> *)orphans {
    return [self.mOrphans copy];
}

- (NSDictionary<NSValue *, DSBlock *> *)terminalBlocks {
    return [self.mTerminalBlocks copy];
}

- (NSDictionary *)recentBlocks {
    return [[self mSyncBlocks] copy];
}

- (NSDictionary<NSValue *, DSBlock *> *)mainChainSyncBlocks {
    NSMutableDictionary *mainChainSyncBlocks = [self.mSyncBlocks mutableCopy];
    [mainChainSyncBlocks removeObjectsForKeys:[[self forkChainsSyncBlocks] allKeys]];
    return mainChainSyncBlocks;
}
- (NSDictionary<NSValue *, DSBlock *> *)forkChainsSyncBlocks {
    NSMutableDictionary *forkChainsSyncBlocks = [self.mSyncBlocks mutableCopy];
    DSBlock *b = self.lastSyncBlock;
    NSUInteger count = 0;
    while (b && b.height > 0) {
        b = self.mSyncBlocks[b.prevBlockValue];
        [forkChainsSyncBlocks removeObjectForKey:uint256_obj(b.blockHash)];
        count++;
    }
    return forkChainsSyncBlocks;
}
- (NSDictionary<NSValue *, DSBlock *> *)mainChainTerminalBlocks {
    NSMutableDictionary *mainChainTerminalBlocks = [self.mTerminalBlocks mutableCopy];
    [mainChainTerminalBlocks removeObjectsForKeys:[[self forkChainsTerminalBlocks] allKeys]];
    return mainChainTerminalBlocks;
}

- (NSDictionary<NSValue *, DSBlock *> *)forkChainsTerminalBlocks {
    NSMutableDictionary *forkChainsTerminalBlocks = [self.mTerminalBlocks mutableCopy];
    DSBlock *b = self.lastTerminalBlock;
    NSUInteger count = 0;
    while (b && b.height > 0) {
        b = self.mTerminalBlocks[b.prevBlockValue];
        [forkChainsTerminalBlocks removeObjectForKey:uint256_obj(b.blockHash)];
        count++;
    }
    return forkChainsTerminalBlocks;
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

- (DSBlock *)lastSyncBlockWithUseCheckpoints:(BOOL)useCheckpoints forChain:(DSChain *)chain {
    if (_lastSyncBlock) return _lastSyncBlock;
    
    if (!_lastSyncBlock && uint256_is_not_zero(self.lastPersistedChainSyncBlockHash) && uint256_is_not_zero(self.lastPersistedChainSyncBlockChainWork) && self.lastPersistedChainSyncBlockHeight != BLOCK_UNKNOWN_HEIGHT) {
        _lastSyncBlock = [[DSMerkleBlock alloc] initWithVersion:2 blockHash:self.lastPersistedChainSyncBlockHash prevBlock:UINT256_ZERO timestamp:self.lastPersistedChainSyncBlockTimestamp height:self.lastPersistedChainSyncBlockHeight chainWork:self.lastPersistedChainSyncBlockChainWork onChain:chain];
    }
    
    if (!_lastSyncBlock && useCheckpoints) {
        DSLog(@"[%@] No last Sync Block, setting it from checkpoints", chain.name);
        [self setLastSyncBlockFromCheckpointsForChain:chain];
    }
    
    return _lastSyncBlock;
}
- (void)setLastSyncBlockFromCheckpointsForChain:(DSChain *)chain {
    
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
                              chainWork:(UInt256)chainWork
                               locators:(NSArray *)locators {
    self.lastPersistedChainSyncBlockHeight = blockHeight;
    self.lastPersistedChainSyncBlockHash = blockHash;
    self.lastPersistedChainSyncBlockTimestamp = timestamp;
    self.lastPersistedChainSyncBlockChainWork = chainWork;
    self.lastPersistedChainSyncLocators = locators;
}

- (NSArray *)cacheBlockLocators {
    NSArray *array = [self chainSyncBlockLocatorArray];
    _lastPersistedChainSyncLocators = [self blockLocatorArrayOnOrBeforeTimestamp:BIP39_CREATION_TIME includeInitialTerminalBlocks:NO];
    return array;
}

- (NSDictionary<NSValue *, DSBlock *> *)syncBlocks {
    return [self.mSyncBlocks copy];
}


- (NSMutableDictionary *)mSyncBlocks {
    @synchronized (_mSyncBlocks) {
        if (_mSyncBlocks.count > 0) {
            return _mSyncBlocks;
        }
    
        [self.chain.chainManagedObjectContext performBlockAndWait:^{
            if (self->_mSyncBlocks.count > 0) return;
            if (uint256_is_not_zero(self.lastPersistedChainSyncBlockHash)) {
                self->_mSyncBlocks[uint256_obj(self.lastPersistedChainSyncBlockHash)] = [[DSMerkleBlock alloc] initWithVersion:2
                    blockHash:self.lastPersistedChainSyncBlockHash
                    prevBlock:UINT256_ZERO
                    timestamp:self.lastPersistedChainSyncBlockTimestamp
                    height:self.lastPersistedChainSyncBlockHeight
                    chainWork:self.lastPersistedChainSyncBlockChainWork
                    onChain:self.chain];
            }
            
            for (DSCheckpoint *checkpoint in self.checkpointsCache.checkpoints) { // add checkpoints to the block collection
                UInt256 checkpointHash = checkpoint.blockHash;
                self->_mSyncBlocks[uint256_obj(checkpointHash)] = [[DSBlock alloc] initWithCheckpoint:checkpoint onChain:self.chain];
                [self->_checkpointsCache addCheckpoint:checkpoint];
            }
        }];
        
        return _mSyncBlocks;
    }
}



// MARK: - Blocks
- (DSMerkleBlock *)merkleBlockFromCheckpoint:(DSCheckpoint *)checkpoint {
    return [[DSMerkleBlock alloc] initWithCheckpoint:checkpoint onChain:self.chain];
}

- (DSMerkleBlock *)merkleBlockFromCheckpointBeforeTimestamp:(NSTimeInterval)timestamp {
    DSCheckpoint *checkpoint = [self.checkpointsCache lastCheckpointOnOrBeforeTimestamp:timestamp forChain:self.chain];
    return [self merkleBlockFromCheckpoint:checkpoint];
}

- (DSBlock *)lastChainSyncBlockOnOrBeforeTimestamp:(NSTimeInterval)timestamp {
    DSBlock *b = self.lastSyncBlock;
    NSTimeInterval blockTime = b.timestamp;
    while (b && b.height > 0 && blockTime >= timestamp) {
        b = self.mSyncBlocks[b.prevBlockValue];
    }
    return b ? b : [self merkleBlockFromCheckpointBeforeTimestamp:timestamp];
}

- (DSBlock *)lastBlockOnOrBeforeTimestamp:(NSTimeInterval)timestamp {
    DSBlock *b = self.lastTerminalBlock;
    NSTimeInterval blockTime = b.timestamp;
    BOOL useSyncBlocksNow = (b != _lastTerminalBlock);
    while (b && b.height > 0 && blockTime >= timestamp) {
        if (!useSyncBlocksNow)
            b = useSyncBlocksNow ? self.mSyncBlocks[b.prevBlockValue] : self.mTerminalBlocks[b.prevBlockValue];
        if (!b) {
            useSyncBlocksNow = !useSyncBlocksNow;
            b = useSyncBlocksNow ? self.mSyncBlocks[b.prevBlockValue] : self.mTerminalBlocks[b.prevBlockValue];
        }
    }
    return b ? b : [self merkleBlockFromCheckpointBeforeTimestamp:timestamp];
}

- (void)setLastTerminalBlockFromCheckpoints {
    DSCheckpoint *checkpoint = self.checkpointsCache.terminalHeadersOverrideUseCheckpoint ? self.checkpointsCache.terminalHeadersOverrideUseCheckpoint : [self.checkpointsCache lastCheckpoint];
    if (checkpoint) {
        if (self.mTerminalBlocks[uint256_obj(checkpoint.blockHash)]) {
            _lastTerminalBlock = self.mSyncBlocks[uint256_obj(checkpoint.blockHash)];
        } else {
            _lastTerminalBlock = [self merkleBlockFromCheckpoint:checkpoint];
            self.mTerminalBlocks[uint256_obj(checkpoint.blockHash)] = _lastTerminalBlock;
        }
    }
    
    if (_lastTerminalBlock) {
        DSLog(@"[%@] last terminal block at height %d chosen from checkpoints (hash is %@)", self.chain.name, _lastTerminalBlock.height, [NSData dataWithUInt256:_lastTerminalBlock.blockHash].hexString);
    }
}

- (void)setLastSyncBlockFromCheckpoints {
    DSCheckpoint *checkpoint = nil;
    if (self.checkpointsCache.syncHeadersOverrideUseCheckpoint) {
        checkpoint = self.checkpointsCache.syncHeadersOverrideUseCheckpoint;
    } else if ([[DSOptionsManager sharedInstance] syncFromGenesis]) {
        NSUInteger genesisHeight = [self.chain isDevnetAny] ? 1 : 0;
        checkpoint = self.checkpointsCache.checkpoints[genesisHeight];
    } else if ([[DSOptionsManager sharedInstance] shouldSyncFromHeight]) {
        checkpoint = [self.checkpointsCache lastCheckpointOnOrBeforeHeight:[[DSOptionsManager sharedInstance] syncFromHeight] forChain:self.chain];
    } else {
        NSTimeInterval startSyncTime = [self.chain syncsBlockchain] ? [self.chain earliestWalletCreationTime] : [self.checkpointsCache lastCheckpointTimestamp];
        checkpoint = [self.checkpointsCache lastCheckpointOnOrBeforeTimestamp:(startSyncTime == BIP39_CREATION_TIME) ? BIP39_CREATION_TIME : startSyncTime - HEADER_WINDOW_BUFFER_TIME forChain:self.chain];
    }
    
    if (checkpoint) {
        [self setSyncBlockFromCheckpoint:checkpoint forChain:self.chain];
    }
}

- (DSBlock *)lastSyncBlockDontUseCheckpoints {
    return [self lastSyncBlockWithUseCheckpoints:NO];
}

- (DSBlock *)lastSyncBlock {
    return [self lastSyncBlockWithUseCheckpoints:YES];
}

- (DSBlock *)lastSyncBlockWithUseCheckpoints:(BOOL)useCheckpoints {
    return [self lastSyncBlockWithUseCheckpoints:useCheckpoints forChain:self.chain];
}

// this is used as part of a getblocks or getheaders request
- (NSArray<NSData *> *)blockLocatorArrayForBlock:(DSBlock *)block {
    // append 10 most recent block checkpointHashes, decending, then continue appending, doubling the step back each time,
    // finishing with the genesis block (top, -1, -2, -3, -4, -5, -6, -7, -8, -9, -11, -15, -23, -39, -71, -135, ..., 0)
    NSMutableArray *locators = [NSMutableArray array];
    int32_t step = 1, start = 0;
    DSBlock *b = block;
    uint32_t lastHeight = b.height;
    while (b && b.height > 0) {
        [locators addObject:uint256_data(b.blockHash)];
        lastHeight = b.height;
        if (++start >= 10) step *= 2;
        
        for (int32_t i = 0; b && i < step; i++) {
            b = self.mSyncBlocks[b.prevBlockValue];
            if (!b) b = self.mTerminalBlocks[b.prevBlockValue];
        }
    }
    DSCheckpoint *lastCheckpoint = nil;
    //then add the last checkpoint we know about previous to this block
    for (DSCheckpoint *checkpoint in self.checkpointsCache.checkpoints) {
        if (checkpoint.height < lastHeight && checkpoint.timestamp < b.timestamp) {
            lastCheckpoint = checkpoint;
        } else {
            break;
        }
    }
    if (lastCheckpoint) {
        [locators addObject:uint256_data(lastCheckpoint.blockHash)];
    }
    return locators;
}
- (NSArray<NSData *> *)chainSyncBlockLocatorArray {
    if (_lastSyncBlock && !(_lastSyncBlock.height == 1 && [self.chain isDevnetAny])) {
        return [self blockLocatorArrayForBlock:_lastSyncBlock];
    } else if (!_lastPersistedChainSyncLocators) {
        _lastPersistedChainSyncLocators = [self blockLocatorArrayOnOrBeforeTimestamp:BIP39_CREATION_TIME includeInitialTerminalBlocks:NO];
    }
    return _lastPersistedChainSyncLocators;
}
- (NSArray<NSData *> *)blockLocatorArrayOnOrBeforeTimestamp:(NSTimeInterval)timestamp includeInitialTerminalBlocks:(BOOL)includeHeaders {
    DSBlock *block = includeHeaders ? [self lastBlockOnOrBeforeTimestamp:timestamp] : [self lastChainSyncBlockOnOrBeforeTimestamp:timestamp];
    return [self blockLocatorArrayForBlock:block];
}

- (DSBlock *_Nullable)blockForBlockHash:(UInt256)blockHash {
    DSBlock *b;
    b = self.mSyncBlocks[uint256_obj(blockHash)];
    if (b) return b;
    b = self.mTerminalBlocks[uint256_obj(blockHash)];
    if (b) return b;
    if (![self.chain isMainnet]) {
        return [self.insightVerifiedBlocksByHashDictionary objectForKey:uint256_data(blockHash)];
    }
    return nil;
}

- (DSBlock *)recentTerminalBlockForBlockHash:(UInt256)blockHash {
    DSBlock *b = self.lastTerminalBlock;
    NSUInteger count = 0;
    BOOL useSyncBlocksNow = FALSE;
    while (b && b.height > 0 && !uint256_eq(b.blockHash, blockHash)) {
        if (!useSyncBlocksNow) {
            b = self.mTerminalBlocks[b.prevBlockValue];
        }
        if (!b) {
            useSyncBlocksNow = TRUE;
        }
        if (useSyncBlocksNow) {
            b = self.mSyncBlocks[b.prevBlockValue];
        }
        count++;
    }
    return b;
}

- (DSBlock *)recentSyncBlockForBlockHash:(UInt256)blockHash {
    DSBlock *b = [self lastSyncBlockDontUseCheckpoints];
    while (b && b.height > 0 && !uint256_eq(b.blockHash, blockHash)) {
        b = self.mSyncBlocks[b.prevBlockValue];
    }
    return b;
}

- (DSBlock *)blockAtHeight:(uint32_t)height {
    DSBlock *b = self.lastTerminalBlock;
    while (b && b.height > height) {
        b = self.mTerminalBlocks[b.prevBlockValue];
    }
    if (b.height != height) {
        DSBlock *b = self.lastSyncBlock;
        while (b && b.height > height) {
            b = self.mSyncBlocks[b.prevBlockValue];
        }
        if (b.height != height) return nil;
    }
    return b;
}
- (DSBlock *)blockAtHeightOrLastTerminal:(uint32_t)height {
    DSBlock *block = [self blockAtHeight:height];
    if (block == nil) {
        if (height > self.lastTerminalBlockHeight) {
            block = self.lastTerminalBlock;
        } else {
            return nil;
        }
    }
    return block;
}

- (DSBlock *)blockFromChainTip:(NSUInteger)blocksAgo {
    DSBlock *b = self.lastTerminalBlock;
    NSUInteger count = 0;
    BOOL useSyncBlocksNow = FALSE;
    while (b && b.height > 0 && count < blocksAgo) {
        if (!useSyncBlocksNow) {
            b = self.mTerminalBlocks[b.prevBlockValue];
        }
        if (!b) {
            useSyncBlocksNow = TRUE;
        }
        if (useSyncBlocksNow) {
            b = self.mSyncBlocks[b.prevBlockValue];
        }
        count++;
    }
    return b;
}

- (void)addInsightVerifiedBlock:(DSBlock *)block forBlockHash:(UInt256)blockHash {
    if (![self.chain isMainnet]) {
        if (!self.insightVerifiedBlocksByHashDictionary)
            _insightVerifiedBlocksByHashDictionary = [NSMutableDictionary dictionary];
        [self.insightVerifiedBlocksByHashDictionary setObject:block forKey:uint256_data(blockHash)];
    }
}

// MARK: From Peer

- (BOOL)addMinedFullBlock:(DSFullBlock *)block {
    NSAssert(block.transactionHashes, @"Block must have txHashes");
    NSArray *txHashes = block.transactionHashes;
    
    NSValue *blockHash = uint256_obj(block.blockHash), *prevBlock = uint256_obj(block.prevBlock);
    if (!self.mSyncBlocks[prevBlock] || !self.mTerminalBlocks[prevBlock]) return NO;
    if (!uint256_eq(self.lastSyncBlock.blockHash, self.mSyncBlocks[prevBlock].blockHash)) return NO;
    if (!uint256_eq(self.lastTerminalBlock.blockHash, self.mTerminalBlocks[prevBlock].blockHash)) return NO;
    
    self.mSyncBlocks[blockHash] = block;
    self.lastSyncBlock = block;
    self.mTerminalBlocks[blockHash] = block;
    self.lastTerminalBlock = block;
    
    uint32_t txTime = block.timestamp / 2 + self.mTerminalBlocks[prevBlock].timestamp / 2;
    
    [self.chain setBlockHeight:block.height andTimestamp:txTime forTransactionHashes:txHashes];
    
    if (block.height > self.estimatedBlockHeight) {
        @synchronized (self) {
            _bestEstimatedBlockHeight = block.height;
        }
        [self.chain saveBlockLocators];
        [self.chain saveTerminalBlocks];
        
        // notify that transaction confirmations may have changed
        [self notifyBlocksChanged];
    }
    
    return TRUE;
}

//TRUE if it was added to the end of the chain
- (BOOL)addBlock:(DSBlock *)block receivedAsHeader:(BOOL)isHeaderOnly fromPeer:(DSPeer *)peer {
    NSString *prefix = [NSString stringWithFormat:@"[%@: %@:%d]", self.chain.name, peer.host ? peer.host : @"TEST", peer.port];
    if (peer && !self.chain.chainManager.syncPhase) {
        DSLog(@"%@ Block was received from peer after reset, ignoring it", prefix);
        return FALSE;
    }
    //DSLog(@"a block %@",uint256_hex(block.blockHash));
    //All blocks will be added from same delegateQueue
    NSArray *txHashes = block.transactionHashes;
    
    NSValue *blockHash = uint256_obj(block.blockHash), *prevBlock = uint256_obj(block.prevBlock);
    DSBlock *prev = nil;
    
    DSBlockPosition blockPosition = DSBlockPosition_Orphan;
    DSChainSyncPhase phase = self.chain.chainManager.syncPhase;
    if (phase == DSChainSyncPhase_InitialTerminalBlocks) {
        //In this phase all received blocks are treated as terminal blocks
        prev = self.mTerminalBlocks[prevBlock];
        if (prev) {
            blockPosition = DSBlockPosition_Terminal;
        }
    } else {
        prev = self.mSyncBlocks[prevBlock];
        if (!prev) {
            prev = self.mTerminalBlocks[prevBlock];
            if (prev) {
                blockPosition = DSBlockPosition_Terminal;
            }
        } else if (self.mTerminalBlocks[prevBlock]) {
            //lets see if we are at the chain tip
            if (self.mTerminalBlocks[blockHash]) {
                //we already had this block, we are not at chain tip
                blockPosition = DSBlockPosition_Sync;
            } else {
                //we do not have this block as a terminal block, we are at chain tip
                blockPosition = DSBlockPosition_TerminalSync;
            }
            
        } else {
            blockPosition = DSBlockPosition_Sync;
        }
    }
    
    
    if (!prev) { // header is an orphan
#if LOG_PREV_BLOCKS_ON_ORPHAN
        NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"height" ascending:TRUE];
        for (DSBlock *merkleBlock in [[self.blocks allValues] sortedArrayUsingDescriptors:@[sortDescriptor]]) {
            DSLog(@"%@ printing previous block at height %d : %@", prefix, merkleBlock.height, merkleBlock.blockHashValue);
        }
#endif
        DSLog(@"%@ relayed orphan block %@, previous %@, height %d, last block is %@, lastBlockHeight %d, time %@", prefix,
              uint256_reverse_hex(block.blockHash), uint256_reverse_hex(block.prevBlock), block.height, uint256_reverse_hex(self.lastTerminalBlock.blockHash), self.lastSyncBlockHeight, [NSDate dateWithTimeIntervalSince1970:block.timestamp]);
        
        if (peer) {
            [self.chain.chainManager chain:self.chain receivedOrphanBlock:block fromPeer:peer];
            [peer receivedOrphanBlock];
        }
        
        self.mOrphans[prevBlock] = block; // orphans are indexed by prevBlock instead of blockHash
        self.lastOrphan = block;
        return FALSE;
    }
    
    BOOL syncDone = NO;
    
    @synchronized (block) {
        block.height = prev.height + 1;
    }
    UInt256 target = setCompactLE(block.target);
    NSAssert(uint256_is_not_zero(prev.chainWork), @"previous block should have aggregate work set");
    block.chainWork = uInt256AddLE(prev.chainWork, uInt256AddOneLE(uInt256DivideLE(uint256_inverse(target), uInt256AddOneLE(target))));
    NSAssert(uint256_is_not_zero(block.chainWork), @"block should have aggregate work set");
    uint32_t txTime = block.timestamp / 2 + prev.timestamp / 2;
    
    if ((blockPosition & DSBlockPosition_Terminal) && ((block.height % 10000) == 0 || ((block.height == self.estimatedBlockHeight) && (block.height % 100) == 0))) { //free up some memory from time to time
        //[self saveTerminalBlocks];
        DSBlock *b = block;
        
        for (uint32_t i = 0; b && i < KEEP_RECENT_TERMINAL_BLOCKS; i++) {
            b = self.mTerminalBlocks[b.prevBlockValue];
        }
        NSMutableArray *blocksToRemove = [NSMutableArray array];
        while (b) { // free up some memory
            [blocksToRemove addObject:b.blockHashValue];
            b = self.mTerminalBlocks[b.prevBlockValue];
        }
        [self.mTerminalBlocks removeObjectsForKeys:blocksToRemove];
    }
    if ((blockPosition & DSBlockPosition_Sync) && ((block.height % 1000) == 0)) { //free up some memory from time to time
        DSBlock *b = block;
        
        for (uint32_t i = 0; b && i < KEEP_RECENT_SYNC_BLOCKS; i++) {
            b = self.mSyncBlocks[b.prevBlockValue];
        }
        NSMutableArray *blocksToRemove = [NSMutableArray array];
        while (b) { // free up some memory
            [blocksToRemove addObject:b.blockHashValue];
            b = self.mSyncBlocks[b.prevBlockValue];
        }
        [self.mSyncBlocks removeObjectsForKeys:blocksToRemove];
    }
    
    // verify block difficulty if block is past last checkpoint
    DSCheckpoint *lastCheckpoint = [self.checkpointsCache lastCheckpoint];
    
    DSBlock *equivalentTerminalBlock = nil;
    
    if ((blockPosition & DSBlockPosition_Sync) && (self.lastSyncBlockHeight + 1 >= lastCheckpoint.height)) {
        equivalentTerminalBlock = self.mTerminalBlocks[blockHash];
    }
    
    if (!equivalentTerminalBlock && ((blockPosition & DSBlockPosition_Terminal) || [block canCalculateDifficultyWithPreviousBlocks:self.mSyncBlocks])) { //no need to check difficulty if we already have terminal blocks
        uint32_t foundDifficulty = 0;
        if ((block.height > self.chain.minimumDifficultyBlocks) && (block.height > (lastCheckpoint.height + DGW_PAST_BLOCKS_MAX)) &&
            ![block verifyDifficultyWithPreviousBlocks:(blockPosition & DSBlockPosition_Terminal) ? self.mTerminalBlocks : self.mSyncBlocks rDifficulty:&foundDifficulty]) {
            DSLog(@"%@ relayed block with invalid difficulty height %d target %x foundTarget %x, blockHash: %@", prefix,
                  block.height, block.target, foundDifficulty, blockHash);
            
            if (peer) {
                [self.chain.chainManager chain:self.chain badBlockReceivedFromPeer:peer];
            }
            return FALSE;
        }
        
        UInt256 difficulty = setCompactLE(block.target);
        if (uint256_sup(block.blockHash, difficulty)) {
            DSLog(@"%@ relayed block with invalid block hash %d target %x, blockHash: %@ difficulty: %@", prefix,
                  block.height, block.target, uint256_bin(block.blockHash), uint256_bin(difficulty));
            
            if (peer) {
                [self.chain.chainManager chain:self.chain badBlockReceivedFromPeer:peer];
            }
            return FALSE;
        }
    }
    
    DSCheckpoint *checkpoint = [self.checkpointsCache checkpointForBlockHeight:block.height];
    
    if ((!equivalentTerminalBlock) && (checkpoint && !uint256_eq(block.blockHash, checkpoint.blockHash))) {
        // verify block chain checkpoints
        DSLog(@"%@ relayed a block that differs from the checkpoint at height %d, blockHash: %@, expected: %@",
              prefix, block.height, blockHash, uint256_hex(checkpoint.blockHash));
        if (peer) {
            [self.chain.chainManager chain:self.chain badBlockReceivedFromPeer:peer];
        }
        return FALSE;
    }
    
    BOOL onMainChain = FALSE;
    
    uint32_t h = block.height;
    if ((phase == DSChainSyncPhase_ChainSync || phase == DSChainSyncPhase_Synced) && uint256_eq(block.prevBlock, self.lastSyncBlockHash)) { // new block extends sync chain
        if ((block.height % 1000) == 0 || txHashes.count > 0 || h > peer.lastBlockHeight) {
            DSLog(@"%@ + sync block at: %d: %@", prefix, h, uint256_hex(block.blockHash));
        }
        self.mSyncBlocks[blockHash] = block;
        if (equivalentTerminalBlock && equivalentTerminalBlock.chainLocked && !block.chainLocked) {
            [block setChainLockedWithEquivalentBlock:equivalentTerminalBlock];
        }
        self.lastSyncBlock = block;
        
        if (!equivalentTerminalBlock && uint256_eq(block.prevBlock, self.lastTerminalBlock.blockHash)) {
            if ((h % 1000) == 0 || txHashes.count > 0 || h > peer.lastBlockHeight) {
                DSLog(@"%@ + terminal block (caught up) at: %d: %@", prefix, h, uint256_hex(block.blockHash));
            }
            self.mTerminalBlocks[blockHash] = block;
            self.lastTerminalBlock = block;
        }
        @synchronized(peer) {
            if (peer) {
                peer.currentBlockHeight = h; //might be download peer instead
            }
        }
        if (h == self.estimatedBlockHeight) syncDone = YES;
        [self.chain setBlockHeight:block.height andTimestamp:txTime forTransactionHashes:txHashes];
        onMainChain = TRUE;
        
        DSCheckpoint *checkpoint = [self.checkpointsCache lastCheckpointOnOrBeforeHeight:h forChain:self.chain];

        
        if (checkpoint.height == h ||
            ((h % 1000 == 0) && (h + BLOCK_NO_FORK_DEPTH < self.lastTerminalBlockHeight) && ![self.chain hasMasternodeListCurrentlyBeingSaved])) {
            [self.chain saveBlockLocators];
        }
        
    } else if (uint256_eq(block.prevBlock, self.lastTerminalBlock.blockHash)) { // new block extends terminal chain
        if ((h % 500) == 0 || txHashes.count > 0 || h > peer.lastBlockHeight) {
            DSLog(@"%@ + terminal block at: %d: %@", prefix, h, uint256_hex(block.blockHash));
        }
        self.mTerminalBlocks[blockHash] = block;
        self.lastTerminalBlock = block;
        @synchronized(peer) {
            if (peer) {
                peer.currentBlockHeight = h; //might be download peer instead
            }
        }
        if (h == self.estimatedBlockHeight) syncDone = YES;
        onMainChain = TRUE;
    } else if ((phase == DSChainSyncPhase_ChainSync || phase == DSChainSyncPhase_Synced) && self.mSyncBlocks[blockHash] != nil) { // we already have the block (or at least the header)
        if ((h % 1) == 0 || txHashes.count > 0 || h > peer.lastBlockHeight) {
            DSLog(@"%@ relayed existing sync block at height %d", prefix, h);
        }
        self.mSyncBlocks[blockHash] = block;
        if (equivalentTerminalBlock && equivalentTerminalBlock.chainLocked && !block.chainLocked) {
            [block setChainLockedWithEquivalentBlock:equivalentTerminalBlock];
        }
        
        @synchronized(peer) {
            if (peer) {
                peer.currentBlockHeight = h; //might be download peer instead
            }
        }

        DSBlock *b = self.lastSyncBlock;
        
        while (b && b.height > h) b = self.mSyncBlocks[b.prevBlockValue]; // is block in main chain?
        
        if (b != nil && uint256_eq(b.blockHash, block.blockHash)) { // if it's not on a fork, set block heights for its transactions
            [self.chain setBlockHeight:h andTimestamp:txTime forTransactionHashes:txHashes];
            if (h == self.lastSyncBlockHeight) self.lastSyncBlock = block;
        }
    } else if (self.mTerminalBlocks[blockHash] != nil && (blockPosition & DSBlockPosition_Terminal)) { // we already have the block (or at least the header)
        if ((h % 1) == 0 || txHashes.count > 0 || h > peer.lastBlockHeight) {
            DSLog(@"%@ relayed existing terminal block at height %d (last sync height %d)", prefix, h, self.lastSyncBlockHeight);
        }
        self.mTerminalBlocks[blockHash] = block;
        @synchronized(peer) {
            if (peer) {
                peer.currentBlockHeight = h; //might be download peer instead
            }
        }

        DSBlock *b = self.lastTerminalBlock;
        
        while (b && b.height > h) b = self.mTerminalBlocks[b.prevBlockValue]; // is block in main chain?
        
        if (b != nil && uint256_eq(b.blockHash, block.blockHash)) { // if it's not on a fork, set block heights for its transactions
            [self.chain setBlockHeight:h andTimestamp:txTime forTransactionHashes:txHashes];
            if (h == self.lastTerminalBlockHeight) self.lastTerminalBlock = block;
        }
    } else {                                                // new block is on a fork
        if (h <= [self.checkpointsCache lastCheckpointHeight]) { // fork is older than last checkpoint
            DSLog(@"%@ ignoring block on fork older than most recent checkpoint, fork height: %d, blockHash: %@", prefix, h, blockHash);
            return TRUE;
        }
        
        if (h <= self.chain.lastChainLock.height) {
            DSLog(@"%@ ignoring block on fork when main chain is chainlocked: %d, blockHash: %@", prefix, h, blockHash);
            return TRUE;
        }
        
        DSLog(@"%@ potential chain fork to height %d blockPosition %d", prefix, block.height, blockPosition);
        if (!(blockPosition & DSBlockPosition_Sync)) {
            //this is only a reorg of the terminal blocks
            self.mTerminalBlocks[blockHash] = block;
            if (uint256_supeq(self.lastTerminalBlock.chainWork, block.chainWork)) return TRUE; // if fork is shorter than main chain, ignore it for now
            DSLog(@"%@ found potential chain fork on height %d", prefix, block.height);
            
            DSBlock *b = block, *b2 = self.lastTerminalBlock;
            
            while (b && b2 && !uint256_eq(b.blockHash, b2.blockHash) && !b2.chainLocked) { // walk back to where the fork joins the main chain
                b = self.mTerminalBlocks[b.prevBlockValue];
                if (b.height < b2.height) b2 = self.mTerminalBlocks[b2.prevBlockValue];
            }
            
            if (!uint256_eq(b.blockHash, b2.blockHash) && b2.chainLocked) { //intermediate chain locked block
                DSLog(@"%@ no reorganizing chain to height %d because of chainlock at height %d", prefix, h, b2.height);
                return TRUE;
            }
            
            DSLog(@"%@ reorganizing terminal chain from height %d, new height is %d", prefix, b.height, h);
            
            self.lastTerminalBlock = block;
            @synchronized(peer) {
                if (peer) {
                    peer.currentBlockHeight = h; //might be download peer instead
                }
            }
            if (h == self.estimatedBlockHeight) syncDone = YES;
        } else {
            if (phase == DSChainSyncPhase_ChainSync || phase == DSChainSyncPhase_Synced) {
                self.mTerminalBlocks[blockHash] = block;
            }
            self.mSyncBlocks[blockHash] = block;

            if (equivalentTerminalBlock && equivalentTerminalBlock.chainLocked && !block.chainLocked) {
                [block setChainLockedWithEquivalentBlock:equivalentTerminalBlock];
            }
            
            if (uint256_supeq(self.lastSyncBlock.chainWork, block.chainWork)) return TRUE; // if fork is shorter than main chain, ignore it for now
            DSLog(@"%@ found sync chain fork on height %d", prefix, h);
            if ((phase == DSChainSyncPhase_ChainSync || phase == DSChainSyncPhase_Synced) && !uint256_supeq(self.lastTerminalBlock.chainWork, block.chainWork)) {
                DSBlock *b = block, *b2 = self.lastTerminalBlock;
                
                while (b && b2 && !uint256_eq(b.blockHash, b2.blockHash) && !b2.chainLocked) { // walk back to where the fork joins the main chain
                    b = self.mTerminalBlocks[b.prevBlockValue];
                    if (b.height < b2.height) b2 = self.mTerminalBlocks[b2.prevBlockValue];
                }
                
                if (!uint256_eq(b.blockHash, b2.blockHash) && b2.chainLocked) { //intermediate chain locked block
                    DSLog(@"%@ no reorganizing chain to height %d because of chainlock at height %d", prefix, h, b2.height);
                } else {
                    DSLog(@"%@ reorganizing terminal chain from height %d, new height is %d", prefix, b.height, h);
                    self.lastTerminalBlock = block;
                    @synchronized(peer) {
                        if (peer) {
                            peer.currentBlockHeight = h; //might be download peer instead
                        }
                    }
                }
            }
            
            DSBlock *b = block, *b2 = self.lastSyncBlock;
            
            while (b && b2 && !uint256_eq(b.blockHash, b2.blockHash) && !b2.chainLocked) { // walk back to where the fork joins the main chain
                b = self.mSyncBlocks[b.prevBlockValue];
                if (b.height < b2.height) b2 = self.mSyncBlocks[b2.prevBlockValue];
            }
            
            if (!uint256_eq(b.blockHash, b2.blockHash) && b2.chainLocked) { //intermediate chain locked block
                DSLog(@"%@ no reorganizing sync chain to height %d because of chainlock at height %d", prefix, h, b2.height);
                return TRUE;
            }
            
            DSLog(@"%@ reorganizing sync chain from height %d, new height is %d", prefix, b.height, h);
            [self.chain markTransactionsUnconfirmedAboveBlockHeight:b.height];
            b = block;
            
            while (b.height > b2.height) { // set transaction heights for new main chain
                [self.chain setBlockHeight:b.height andTimestamp:txTime forTransactionHashes:b.transactionHashes];
                b = self.mSyncBlocks[b.prevBlockValue];
                txTime = b.timestamp / 2 + ((DSBlock *)self.mSyncBlocks[b.prevBlockValue]).timestamp / 2;
            }
            
            self.lastSyncBlock = block;
            if (h == self.estimatedBlockHeight) syncDone = YES;
        }
    }
    
    if ((blockPosition & DSBlockPosition_Terminal) && checkpoint && checkpoint == [self.checkpointsCache lastCheckpointHavingMasternodeList]) {
        [self.chain loadFileDistributedMasternodeLists];
    }
    
    BOOL savedBlockLocators = NO;
    BOOL savedTerminalBlocks = NO;
    if (syncDone) { // chain download is complete
        if (blockPosition & DSBlockPosition_Terminal) {
            [self.chain saveTerminalBlocks];
            savedTerminalBlocks = YES;
            if (peer) {
                [self.chain.chainManager chainFinishedSyncingInitialHeaders:self.chain fromPeer:peer onMainChain:onMainChain];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:DSChainInitialHeadersDidFinishSyncingNotification object:nil userInfo:@{DSChainManagerNotificationChainKey: self}];
            });
        }
        if ((blockPosition & DSBlockPosition_Sync) && (phase == DSChainSyncPhase_ChainSync || phase == DSChainSyncPhase_Synced)) {
            //we should only save
            [self.chain saveBlockLocators];
            savedBlockLocators = YES;
            if (peer) {
                [self.chain.chainManager chainFinishedSyncingTransactionsAndBlocks:self.chain fromPeer:peer onMainChain:onMainChain];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:DSChainBlocksDidFinishSyncingNotification object:nil userInfo:@{DSChainManagerNotificationChainKey: self}];
            });
        }
    }
    
    if (((blockPosition & DSBlockPosition_Terminal) && block.height > self.estimatedBlockHeight) || ((blockPosition & DSBlockPosition_Sync) && block.height >= self.lastTerminalBlockHeight)) {
        @synchronized (self) {
            _bestEstimatedBlockHeight = block.height;
        }
        if (peer && (blockPosition & DSBlockPosition_Sync) && !savedBlockLocators) {
            [self.chain saveBlockLocators];
        }
        if ((blockPosition & DSBlockPosition_Terminal) && !savedTerminalBlocks) {
            [self.chain saveTerminalBlocks];
        }
        if (peer) {
            [self.chain.chainManager chain:self.chain wasExtendedWithBlock:block fromPeer:peer];
        }
        
        // notify that transaction confirmations may have changed
        [self setupBlockChangeTimer:^{
            [self notifyBlocksChanged];
        }];
    } else {
        //we should avoid dispatching this message too frequently
        [self setupBlockChangeTimer:^{
            [self notifyBlocksChanged:blockPosition];
        }];
    }
    
    // check if the next block was received as an orphan
    if (block == self.lastTerminalBlock && self.mOrphans[blockHash]) {
        DSBlock *b = self.mOrphans[blockHash];
        
        [self.mOrphans removeObjectForKey:blockHash];
        [self addBlock:b receivedAsHeader:YES fromPeer:peer]; //revisit this
    }
    return TRUE;
}

// MARK: Terminal Blocks
- (NSMutableDictionary *)mTerminalBlocks {
    @synchronized (_mTerminalBlocks) {
        if (_mTerminalBlocks.count > 0) {
            return _mTerminalBlocks;
        }
        [self.chain.chainManagedObjectContext performBlockAndWait:^{
            if (self->_mTerminalBlocks.count > 0) return;
            for (DSCheckpoint *checkpoint in self.checkpointsCache.checkpoints) { // add checkpoints to the block collection
                self->_mTerminalBlocks[uint256_obj(checkpoint.blockHash)] = [[DSBlock alloc] initWithCheckpoint:checkpoint onChain:self.chain];
                [self.checkpointsCache addCheckpoint:checkpoint];
            }
            for (DSMerkleBlockEntity *e in [DSMerkleBlockEntity lastTerminalBlocks:KEEP_RECENT_TERMINAL_BLOCKS onChainEntity:[self.chain chainEntityInContext:self.chain.chainManagedObjectContext]]) {
                @autoreleasepool {
                    DSMerkleBlock *b = e.merkleBlock;
                    if (b) self->_mTerminalBlocks[b.blockHashValue] = b;
                }
            };
        }];
        
        return _mTerminalBlocks;
    }
}

- (DSBlock *)lastTerminalBlock {
    @synchronized (self) {
        if (_lastTerminalBlock) return _lastTerminalBlock;
    }
    [self.chain.chainManagedObjectContext performBlockAndWait:^{
        NSArray *lastTerminalBlocks = [DSMerkleBlockEntity lastTerminalBlocks:1 onChainEntity:[self.chain chainEntityInContext:self.chain.chainManagedObjectContext]];
        DSMerkleBlock *lastTerminalBlock = [[lastTerminalBlocks firstObject] merkleBlock];
        @synchronized (self) {
            self->_lastTerminalBlock = lastTerminalBlock;
            if (lastTerminalBlock) {
                DSLog(@"[%@] last terminal block at height %d recovered from db (hash is %@)", self.chain.name, lastTerminalBlock.height, [NSData dataWithUInt256:lastTerminalBlock.blockHash].hexString);
            }
        }
    }];

    @synchronized (self) {
        if (!_lastTerminalBlock) {
            // if we don't have any headers yet, use the latest checkpoint
            DSCheckpoint *lastCheckpoint = self.checkpointsCache.terminalHeadersOverrideUseCheckpoint ? self.checkpointsCache.terminalHeadersOverrideUseCheckpoint : self.checkpointsCache.lastCheckpoint;
            uint32_t lastSyncBlockHeight = self.lastSyncBlockHeight;
            
            if (lastCheckpoint.height >= lastSyncBlockHeight) {
                [self setLastTerminalBlockFromCheckpoints];
            } else {
                _lastTerminalBlock = self.lastSyncBlock;
            }
        }
        
        if (_lastTerminalBlock.height > self.estimatedBlockHeight) _bestEstimatedBlockHeight = _lastTerminalBlock.height;
        
        return _lastTerminalBlock;
    }
}

- (NSArray *)terminalBlocksLocatorArray {
    NSMutableArray *locators = [NSMutableArray array];
    int32_t step = 1, start = 0;
    DSBlock *b = self.lastTerminalBlock;
    uint32_t lastHeight = b.height;
    NSDictionary *terminalBlocks = [self terminalBlocks];
    while (b && b.height > 0) {
        [locators addObject:uint256_data(b.blockHash)];
        lastHeight = b.height;
        if (++start >= 10) step *= 2;
        
        for (int32_t i = 0; b && i < step; i++) {
            b = terminalBlocks[b.prevBlockValue];
        }
    }
    DSCheckpoint *lastCheckpoint = [self.checkpointsCache lastCheckpointBeforeHeight:lastHeight];
    //then add the last checkpoint we know about previous to this header
    if (lastCheckpoint) {
        [locators addObject:uint256_data(lastCheckpoint.blockHash)];
    }
    return locators;
}


// MARK: Orphans

- (void)clearOrphans {
    [self.mOrphans removeAllObjects]; // clear out orphans that may have been received on an old filter
    self.lastOrphan = nil;
}

// MARK: Chain Locks

- (BOOL)addChainLock:(DSChainLock *)chainLock {
    DSBlock *terminalBlock = self.mTerminalBlocks[uint256_obj(chainLock.blockHash)];
    [terminalBlock setChainLockedWithChainLock:chainLock];
    if ((terminalBlock.chainLocked) && (![self recentTerminalBlockForBlockHash:terminalBlock.blockHash])) {
        //the newly chain locked block is not in the main chain, we will need to reorg to it
        DSLog(@"[%@] Added a chain lock for block %@ that was not on the main terminal chain ending in %@, reorginizing", self.chain.name,  terminalBlock, self.lastSyncBlock);
        //clb chain locked block
        //tbmc terminal block
        DSBlock *clb = terminalBlock, *tbmc = self.lastTerminalBlock;
        BOOL cancelReorg = FALSE;
        
        while (clb && tbmc && !uint256_eq(clb.blockHash, tbmc.blockHash)) { // walk back to where the fork joins the main chain
            if (tbmc.chainLocked) {
                //if a block is already chain locked then do not reorg
                cancelReorg = TRUE;
            }
            if (clb.height < tbmc.height) {
                tbmc = self.mTerminalBlocks[tbmc.prevBlockValue];
            } else if (clb.height > tbmc.height) {
                clb = self.mTerminalBlocks[clb.prevBlockValue];
            } else {
                tbmc = self.mTerminalBlocks[tbmc.prevBlockValue];
                clb = self.mTerminalBlocks[clb.prevBlockValue];
            }
        }
        
        if (cancelReorg) {
            DSLog(@"[%@] Cancelling terminal reorg because block %@ is already chain locked", self.chain.name, tbmc);
        } else {
            DSLog(@"[%@] Reorginizing to height %d", self.chain.name, clb.height);
            
            self.lastTerminalBlock = terminalBlock;
            NSMutableDictionary *forkChainsTerminalBlocks = [[self forkChainsTerminalBlocks] mutableCopy];
            NSMutableArray *addedBlocks = [NSMutableArray array];
            BOOL done = FALSE;
            while (!done) {
                BOOL found = NO;
                for (NSValue *blockHash in forkChainsTerminalBlocks) {
                    if ([addedBlocks containsObject:blockHash]) continue;
                    DSBlock *potentialNextTerminalBlock = self.mTerminalBlocks[blockHash];
                    if (uint256_eq(potentialNextTerminalBlock.prevBlock, self.lastTerminalBlock.blockHash)) {
                        [self addBlock:potentialNextTerminalBlock receivedAsHeader:YES fromPeer:nil];
                        [addedBlocks addObject:blockHash];
                        found = TRUE;
                        break;
                    }
                }
                if (!found) {
                    done = TRUE;
                }
            }
        }
    }
    DSBlock *syncBlock = self.mSyncBlocks[uint256_obj(chainLock.blockHash)];
    [syncBlock setChainLockedWithChainLock:chainLock];
    DSBlock *sbmc = self.lastSyncBlockDontUseCheckpoints;
    if (sbmc && (syncBlock.chainLocked) && ![self recentSyncBlockForBlockHash:syncBlock.blockHash]) { //!OCLINT
        //the newly chain locked block is not in the main chain, we will need to reorg to it
        DSLog(@"[%@] Added a chain lock for block %@ that was not on the main sync chain ending in %@, reorginizing", self.chain.name, syncBlock, self.lastSyncBlock);
        
        //clb chain locked block
        //sbmc sync block main chain
        DSBlock *clb = syncBlock;
        BOOL cancelReorg = FALSE;
        
        while (clb && sbmc && !uint256_eq(clb.blockHash, sbmc.blockHash)) { // walk back to where the fork joins the main chain
            if (sbmc.chainLocked) {
                //if a block is already chain locked then do not reorg
                cancelReorg = TRUE;
            } else if (clb.height < sbmc.height) {
                sbmc = self.mSyncBlocks[sbmc.prevBlockValue];
            } else if (clb.height > sbmc.height) {
                clb = self.mSyncBlocks[clb.prevBlockValue];
            } else {
                sbmc = self.mSyncBlocks[sbmc.prevBlockValue];
                clb = self.mSyncBlocks[clb.prevBlockValue];
            }
        }
        
        if (cancelReorg) {
            DSLog(@"[%@] Cancelling sync reorg because block %@ is already chain locked", self.chain.name, sbmc);
        } else {
            self.lastSyncBlock = syncBlock;
            
            DSLog(@"[%@] Reorginizing to height %d (last sync block %@)", self.chain.name, clb.height, self.lastSyncBlock);
            
            // mark transactions after the join point as unconfirmed
            [self.chain markTransactionsUnconfirmedAboveBlockHeight:clb.height];
            clb = syncBlock;
            
            while (clb.height > sbmc.height) { // set transaction heights for new main chain
                DSBlock *prevBlock = self.mSyncBlocks[clb.prevBlockValue];
                NSTimeInterval txTime = prevBlock ? ((prevBlock.timestamp + clb.timestamp) / 2) : clb.timestamp;
                [self.chain setBlockHeight:clb.height andTimestamp:txTime forTransactionHashes:clb.transactionHashes];
                clb = prevBlock;
            }
            
            NSMutableDictionary *forkChainsTerminalBlocks = [[self forkChainsSyncBlocks] mutableCopy];
            NSMutableArray *addedBlocks = [NSMutableArray array];
            BOOL done = FALSE;
            while (!done) {
                BOOL found = NO;
                for (NSValue *blockHash in forkChainsTerminalBlocks) {
                    if ([addedBlocks containsObject:blockHash]) continue;
                    DSBlock *potentialNextTerminalBlock = self.mSyncBlocks[blockHash];
                    if (uint256_eq(potentialNextTerminalBlock.prevBlock, self.lastSyncBlock.blockHash)) {
                        [self addBlock:potentialNextTerminalBlock receivedAsHeader:NO fromPeer:nil];
                        [addedBlocks addObject:blockHash];
                        found = TRUE;
                        break;
                    }
                }
                if (!found) {
                    done = TRUE;
                }
            }
        }
    }
    return (terminalBlock && terminalBlock.chainLocked) || (syncBlock && syncBlock.chainLocked);
}

- (BOOL)blockHeightChainLocked:(uint32_t)height {
    DSBlock *b = self.lastTerminalBlock;
    NSUInteger count = 0;
    BOOL confirmed = false;
    while (b && b.height > height) {
        b = self.mTerminalBlocks[b.prevBlockValue];
        confirmed |= b.chainLocked;
        count++;
    }
    if (b.height != height) return NO;
    return confirmed;
}


- (uint32_t)quickHeightForBlockHash:(UInt256)blockhash {
    DSCheckpoint *checkpoint = [self.checkpointsCache checkpointForBlockHash:blockhash];
    if (checkpoint) {
        return checkpoint.height;
    }
    @synchronized (_mSyncBlocks) {
        DSBlock *syncBlock = [_mSyncBlocks objectForKey:uint256_obj(blockhash)];
        if (syncBlock && (syncBlock.height != UINT32_MAX)) {
            return syncBlock.height;
        }
    }
    @synchronized (_mTerminalBlocks) {
        DSBlock *terminalBlock = [_mTerminalBlocks objectForKey:uint256_obj(blockhash)];
        if (terminalBlock && (terminalBlock.height != UINT32_MAX)) {
            return terminalBlock.height;
        }
    }

    for (DSCheckpoint *checkpoint in self.checkpointsCache.checkpoints) {
        if (uint256_eq(checkpoint.blockHash, blockhash)) {
            return checkpoint.height;
        }
    }
    //DSLog(@"Requesting unknown quick blockhash %@", uint256_reverse_hex(blockhash));
    return UINT32_MAX;
}

- (uint32_t)heightForBlockHash:(UInt256)blockhash {
    DSCheckpoint *checkpoint = [self.checkpointsCache checkpointForBlockHash:blockhash];
    if (checkpoint) {
        return checkpoint.height;
    }
    @synchronized (_mSyncBlocks) {
        DSBlock *syncBlock = [_mSyncBlocks objectForKey:uint256_obj(blockhash)];
        if (syncBlock && (syncBlock.height != UINT32_MAX)) {
            return syncBlock.height;
        }
    }
    @synchronized (_mTerminalBlocks) {
        DSBlock *terminalBlock = [_mTerminalBlocks objectForKey:uint256_obj(blockhash)];
        if (terminalBlock && (terminalBlock.height != UINT32_MAX)) {
            return terminalBlock.height;
        }
    }

    DSBlock *b = self.lastTerminalBlock;
    
    if (!b) {
        b = self.lastSyncBlock;
    }
    
    while (b && b.height > 0) {
        if (uint256_eq(b.blockHash, blockhash)) {
            return b.height;
        }
        b = self.mTerminalBlocks[b.prevBlockValue];
        if (!b) {
            b = self.mSyncBlocks[b.prevBlockValue];
        }
    }

    for (DSCheckpoint *checkpoint in self.checkpointsCache.checkpoints) {
        if (uint256_eq(checkpoint.blockHash, blockhash)) {
            return checkpoint.height;
        }
    }
    if (![self.chain isMainnet] && [self.insightVerifiedBlocksByHashDictionary objectForKey:uint256_data(blockhash)]) {
        b = [self.insightVerifiedBlocksByHashDictionary objectForKey:uint256_data(blockhash)];
        return b.height;
    }
    //DSLog(@"Requesting unknown blockhash %@ on chain %@ (it's probably being added asyncronously)", uint256_reverse_hex(blockhash), self.name);
    return UINT32_MAX;
}

// seconds since reference date, 00:00:00 01/01/01 GMT
// NOTE: this is only accurate for the last two weeks worth of blocks, other timestamps are estimated from checkpoints
- (NSTimeInterval)timestampForBlockHeight:(uint32_t)blockHeight {
    if (blockHeight == TX_UNCONFIRMED) return (self.lastTerminalBlock.timestamp) + 2.5 * 60; //next block
    
    if (blockHeight >= self.lastTerminalBlockHeight) { // future block, assume 2.5 minutes per block after last block
        return (self.lastTerminalBlock.timestamp) + (blockHeight - self.lastTerminalBlockHeight) * 2.5 * 60;
    }
    
    if (_mTerminalBlocks.count > 0) {
        if (blockHeight >= self.lastTerminalBlockHeight - DGW_PAST_BLOCKS_MAX) { // recent block we have the header for
            DSBlock *block = self.lastTerminalBlock;
            
            while (block && block.height > blockHeight) block = self.mTerminalBlocks[uint256_obj(block.prevBlock)];
            if (block) return block.timestamp;
        }
    } else {
        //load blocks
        [self mTerminalBlocks];
    }
    
    uint32_t h = self.lastSyncBlockHeight, t = self.lastSyncBlock.timestamp;
    
    for (long i = self.checkpointsCache.checkpoints.count - 1; i >= 0; i--) { // estimate from checkpoints
        if (self.checkpointsCache.checkpoints[i].height <= blockHeight) {
            if (h == self.checkpointsCache.checkpoints[i].height) return t;
            t = self.checkpointsCache.checkpoints[i].timestamp + (t - self.checkpointsCache.checkpoints[i].timestamp) *
            (blockHeight - self.checkpointsCache.checkpoints[i].height) / (h - self.checkpointsCache.checkpoints[i].height);
            return t;
        }
        
        h = self.checkpointsCache.checkpoints[i].height;
        t = self.checkpointsCache.checkpoints[i].timestamp;
    }
    
    return self.checkpointsCache.checkpoints[0].timestamp;
}


// MARK:- Estimation

- (uint32_t)estimatedBlockHeight {
    @synchronized (self) {
        if (_bestEstimatedBlockHeight) return _bestEstimatedBlockHeight;
            _bestEstimatedBlockHeight = [self decideFromPeerSoftConsensusEstimatedBlockHeight];
        return _bestEstimatedBlockHeight;
    }
}


- (uint32_t)decideFromPeerSoftConsensusEstimatedBlockHeight {
    uint32_t maxCount = 0;
    uint32_t tempBestEstimatedBlockHeight = 0;
    for (NSNumber *height in [self.estimatedBlockHeights copy]) {
        NSArray *announcers = self.estimatedBlockHeights[height];
        if (announcers.count > maxCount) {
            tempBestEstimatedBlockHeight = [height intValue];
            maxCount = (uint32_t)announcers.count;
        } else if (announcers.count == maxCount && tempBestEstimatedBlockHeight < [height intValue]) {
            //use the latest if deadlocked
            tempBestEstimatedBlockHeight = [height intValue];
        }
    }
    return tempBestEstimatedBlockHeight;
}

- (NSUInteger)countEstimatedBlockHeightAnnouncers {
    NSMutableSet *announcers = [NSMutableSet set];
    for (NSNumber *height in [self.estimatedBlockHeights copy]) {
        NSArray<DSPeer *> *announcersAtHeight = self.estimatedBlockHeights[height];
        [announcers addObjectsFromArray:announcersAtHeight];
    }
    return [announcers count];
}

- (DSBlockEstimationResult)setEstimatedBlockHeight:(uint32_t)estimatedBlockHeight
                                          fromPeer:(DSPeer *)peer
                                thresholdPeerCount:(uint32_t)thresholdPeerCount {
    uint32_t oldEstimatedBlockHeight = self.estimatedBlockHeight;
    
    //remove from other heights
    for (NSNumber *height in [self.estimatedBlockHeights copy]) {
        if ([height intValue] == estimatedBlockHeight) continue;
        NSMutableArray *announcers = self.estimatedBlockHeights[height];
        if ([announcers containsObject:peer]) {
            [announcers removeObject:peer];
        }
        if ((![announcers count]) && (self.estimatedBlockHeights[height])) {
            [self.estimatedBlockHeights removeObjectForKey:height];
        }
    }
    if (![self estimatedBlockHeights][@(estimatedBlockHeight)]) {
        [self estimatedBlockHeights][@(estimatedBlockHeight)] = [NSMutableArray arrayWithObject:peer];
    } else {
        NSMutableArray *peersAnnouncingHeight = [self estimatedBlockHeights][@(estimatedBlockHeight)];
        if (![peersAnnouncingHeight containsObject:peer]) {
            [peersAnnouncingHeight addObject:peer];
        }
    }
    if ([self countEstimatedBlockHeightAnnouncers] > thresholdPeerCount) {
        uint32_t finalEstimatedBlockHeight = [self decideFromPeerSoftConsensusEstimatedBlockHeight];
        if (finalEstimatedBlockHeight > oldEstimatedBlockHeight) {
            _bestEstimatedBlockHeight = finalEstimatedBlockHeight;
            return DSBlockEstimationResult_NewBest;
        } else {
            return DSBlockEstimationResult_None;
        }
    } else {
        return DSBlockEstimationResult_BelowThreshold;
    }
}

- (void)removeEstimatedBlockHeightOfPeer:(DSPeer *)peer {
    for (NSNumber *height in [self.estimatedBlockHeights copy]) {
        NSMutableArray *announcers = self.estimatedBlockHeights[height];
        if ([announcers containsObject:peer]) {
            [announcers removeObject:peer];
        }
        if ((![announcers count]) && (self.estimatedBlockHeights[height])) {
            [self.estimatedBlockHeights removeObjectForKey:height];
        }
        //keep best estimate if no other peers reporting on estimate
        if ([self.estimatedBlockHeights count] && ([height intValue] == _bestEstimatedBlockHeight)) {
            _bestEstimatedBlockHeight = 0;
        }
    }
}

// MARK:- Notification

- (void)setupBlockChangeTimer:(void (^ __nullable)(void))completion {
    //we should avoid dispatching this message too frequently
    NSTimeInterval timestamp = [[NSDate date] timeIntervalSince1970];
    if (!self.lastNotifiedBlockDidChange || (timestamp - self.lastNotifiedBlockDidChange > 0.1)) {
        self.lastNotifiedBlockDidChange = timestamp;
        if (self.lastNotifiedBlockDidChangeTimer) {
            [self.lastNotifiedBlockDidChangeTimer invalidate];
            self.lastNotifiedBlockDidChangeTimer = nil;
        }
        completion();
    } else if (!self.lastNotifiedBlockDidChangeTimer) {
        self.lastNotifiedBlockDidChangeTimer = [NSTimer timerWithTimeInterval:1 repeats:NO block:^(NSTimer *_Nonnull timer) {
            completion();
        }];
        [[NSRunLoop mainRunLoop] addTimer:self.lastNotifiedBlockDidChangeTimer forMode:NSRunLoopCommonModes];
    }
}


- (void)notifyBlocksChanged {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DSChainNewChainTipBlockNotification
                                                            object:nil
                                                          userInfo:@{DSChainManagerNotificationChainKey:self.chain}];
        [[NSNotificationCenter defaultCenter] postNotificationName:DSChainChainSyncBlocksDidChangeNotification
                                                            object:nil
                                                          userInfo:@{DSChainManagerNotificationChainKey:self.chain}];
        [[NSNotificationCenter defaultCenter] postNotificationName:DSChainTerminalBlocksDidChangeNotification
                                                            object:nil
                                                          userInfo:@{DSChainManagerNotificationChainKey:self.chain}];
    });
}

- (void)notifyBlocksChanged:(DSBlockPosition)blockPosition {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (blockPosition & DSBlockPosition_Terminal)
            [[NSNotificationCenter defaultCenter] postNotificationName:DSChainTerminalBlocksDidChangeNotification
                                                                object:nil
                                                              userInfo:@{DSChainManagerNotificationChainKey:self.chain}];
        if (blockPosition & DSBlockPosition_Sync)
            [[NSNotificationCenter defaultCenter] postNotificationName:DSChainChainSyncBlocksDidChangeNotification
                                                                object:nil
                                                              userInfo:@{DSChainManagerNotificationChainKey:self.chain}];
    });
}

// MARK: From Insight on Testnet
- (void)blockUntilGetInsightForBlockHash:(UInt256)blockHash {
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    [[DSInsightManager sharedInstance] blockForBlockHash:blockHash
                                                 onChain:self.chain
                                              completion:^(DSBlock *_Nullable block, NSError *_Nullable error) {
        if (!error && block) {
            [self addInsightVerifiedBlock:block forBlockHash:blockHash];
        }
        dispatch_semaphore_signal(sem);
    }];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
}

- (DSBlock *_Nullable)insightVerifiedBlockWithHash:(UInt256)blockHash {
    NSData *blockHashData = uint256_data(blockHash);
    return [[self insightVerifiedBlocksByHashDictionary] objectForKey:blockHashData];
}

@end
