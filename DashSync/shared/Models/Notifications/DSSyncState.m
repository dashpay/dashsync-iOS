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

#import "DSOptionsManager.h"
#import "DSSyncState.h"

NSString * DSSyncStateExtKindDescription(DSSyncStateExtKind kind) {
    NSMutableArray<NSString *> *components = [NSMutableArray array];
    if (FLAG_IS_SET(kind, DSSyncStateExtKind_Peers))
        [components addObject:@"Peers"];
    if (FLAG_IS_SET(kind, DSSyncStateExtKind_Governance))
        [components addObject:@"Governance"];
    if (FLAG_IS_SET(kind, DSSyncStateExtKind_Mempool))
        [components addObject:@"Mempool"];
    if (FLAG_IS_SET(kind, DSSyncStateExtKind_Headers))
        [components addObject:@"Headers"];
    if (FLAG_IS_SET(kind, DSSyncStateExtKind_Masternodes))
        [components addObject:@"Masternodes"];
    if (FLAG_IS_SET(kind, DSSyncStateExtKind_Transactions))
        [components addObject:@"Transactions"];
    if (FLAG_IS_SET(kind, DSSyncStateExtKind_CoinJoin))
        [components addObject:@"CoinJoin"];
    if (FLAG_IS_SET(kind, DSSyncStateExtKind_Platform))
        [components addObject:@"Platform"];
    return [components count] ? [components componentsJoinedByString:@" | "] : @"None";
}

NSString * DSPlatformSyncStateKindDescription(DSPlatformSyncStateKind kind) {
    NSMutableArray<NSString *> *components = [NSMutableArray array];
    if (FLAG_IS_SET(kind, DSPlatformSyncStateKind_KeyHashes))
        [components addObject:@"KeyHashes"];
    if (FLAG_IS_SET(kind, DSPlatformSyncStateKind_Unsynced))
        [components addObject:@"Unsynced"];
    return [components count] ? [components componentsJoinedByString:@" | "] : @"None";
}

NSString * DSPeersSyncStateKindDescription(DSPeersSyncStateKind kind) {
    NSMutableArray<NSString *> *components = [NSMutableArray array];
    if (FLAG_IS_SET(kind, DSPeersSyncStateKind_Selection))
        [components addObject:@"Selection"];
    if (FLAG_IS_SET(kind, DSPeersSyncStateKind_Connecting))
        [components addObject:@"Connecting"];
    return [components count] ? [components componentsJoinedByString:@" | "] : @"None";
}

NSString * DSMasternodeListSyncStateKindDescription(DSMasternodeListSyncStateKind kind) {
    NSMutableArray<NSString *> *components = [NSMutableArray array];
    if (FLAG_IS_SET(kind, DSMasternodeListSyncStateKind_Checkpoints))
        [components addObject:@"Checkpoints"];
    if (FLAG_IS_SET(kind, DSMasternodeListSyncStateKind_Diffs))
        [components addObject:@"Diffs"];
    if (FLAG_IS_SET(kind, DSMasternodeListSyncStateKind_QrInfo))
        [components addObject:@"QrInfo"];
    if (FLAG_IS_SET(kind, DSMasternodeListSyncStateKind_Quorums))
        [components addObject:@"Quorums"];
    
    return [components count] ? [components componentsJoinedByString:@" | "] : @"None";
}

@interface DSMasternodeListSyncState ()
@property (nonatomic, assign) DSMasternodeListSyncStateKind kind;
@end
@implementation DSMasternodeListSyncState

- (id)copyWithZone:(NSZone *)zone {
    DSMasternodeListSyncState *copy = [[[self class] alloc] init];
    copy.queueCount = self.queueCount;
    copy.queueMaxAmount = self.queueMaxAmount;
    copy.storedCount = self.storedCount;
    copy.lastListHeight = self.lastListHeight;
    copy.estimatedBlockHeight = self.estimatedBlockHeight;
    copy.kind = self.kind;
    return copy;
}
- (NSString *)description {
    return [NSString stringWithFormat:@"[%@: %u %u/%u %u/%u = %.2f/%.2f]",
            DSMasternodeListSyncStateKindDescription(self.kind),
            self.lastListHeight,
            self.queueCount,
            self.queueMaxAmount,
            self.storedCount,
            [self listsToSync],
            [self progress], [self weight]];
}
- (uint32_t)listsToSync {
    uint32_t estimatedBlockHeight = self.estimatedBlockHeight;
    uint32_t amountLeft = self.queueCount;
    uint32_t lastMasternodeListHeight = self.lastListHeight;
    uint32_t maxAmount = self.queueMaxAmount;
    uint32_t storedCount = self.storedCount;
    uint32_t masternodeListsToSync;
    if (!([[DSOptionsManager sharedInstance] syncType] & DSSyncType_MasternodeList))
        masternodeListsToSync = 0;
    else if (!maxAmount || storedCount <= 1) // 1 because there might be a default
        masternodeListsToSync = (lastMasternodeListHeight == UINT32_MAX || estimatedBlockHeight < lastMasternodeListHeight)
        ? 24
        : MIN(24, (uint32_t)ceil((estimatedBlockHeight - lastMasternodeListHeight) / 24.0f));
    else
        masternodeListsToSync = amountLeft;

    return masternodeListsToSync;
}

- (double)progress {
    uint32_t amountLeft = self.queueCount;
    uint32_t maxAmount = self.queueMaxAmount;
    uint32_t lastBlockHeight = self.lastListHeight;
    uint32_t estimatedBlockHeight = self.estimatedBlockHeight;
    return amountLeft ? MAX(MIN((maxAmount - amountLeft) / maxAmount, 1), 0) : lastBlockHeight != UINT32_MAX && estimatedBlockHeight != 0 && lastBlockHeight + 16 >= estimatedBlockHeight;
}

- (double)weight {
    uint32_t listsToSync = [self listsToSync];
    return listsToSync ? (200 + 20 * (listsToSync - 1)) : 0;
}

- (void)addSyncKind:(DSMasternodeListSyncStateKind)kind {
    if (!FLAG_IS_SET(_kind, kind)) {
        _kind |= kind;
    }
}

- (void)removeSyncKind:(DSMasternodeListSyncStateKind)kind {
    if (FLAG_IS_SET(_kind, kind)) {
        _kind &= ~kind;
    }
}

- (void)resetSyncKind {
    _kind = DSMasternodeListSyncStateKind_None;
}

- (void)updateWithSyncState:(DMNSyncState *)state {
    switch (state->tag) {
        case DMNSyncStateQueueChanged:
            self.queueCount = (uint32_t) state->queue_changed.count;
            self.queueMaxAmount = (uint32_t) state->queue_changed.max_amount;
            break;
        case DMNSyncStateStoreChanged:
            self.storedCount = (uint32_t) state->store_changed.count;
            self.lastListHeight = state->store_changed.last_block_height;
            break;
//        case DMNSyncStateStubCount:
//            self.stubCount = state->stub_count.count;
        default:
            break;
    }
}

@end

@interface DSPlatformSyncState ()
@property (nonatomic, assign) DSPlatformSyncStateKind kind;
@end

@implementation DSPlatformSyncState
- (id)copyWithZone:(NSZone *)zone {
    DSPlatformSyncState *copy = [[[self class] alloc] init];
    copy.kind = self.kind;
    copy.queueCount = self.queueCount;
    copy.queueMaxAmount = self.queueMaxAmount;
    copy.lastSyncedIndentitiesTimestamp = self.lastSyncedIndentitiesTimestamp;
    return copy;
}
- (void)addSyncKind:(DSPlatformSyncStateKind)kind {
    if (!FLAG_IS_SET(self.kind, kind))
        _kind |= kind;
}

- (void)removeSyncKind:(DSPlatformSyncStateKind)kind {
    if (FLAG_IS_SET(self.kind, kind))
        _kind &= ~kind;
}
- (void)resetSyncKind {
    _kind = DSPlatformSyncStateKind_None;
}

- (BOOL)hasRecentIdentitiesSync {
    return [[NSDate date] timeIntervalSince1970] - self.lastSyncedIndentitiesTimestamp < 30;
}

- (double)progress {
    uint32_t amountLeft = self.queueCount;
    uint32_t maxAmount = self.queueMaxAmount;
    return amountLeft && maxAmount ? MAX(MIN((maxAmount - amountLeft) / maxAmount, 1), 0) : [self hasRecentIdentitiesSync];
}

- (double)weight {
    uint32_t identitiesToSync = self.queueMaxAmount;
    BOOL outdated = ![self hasRecentIdentitiesSync];
    return identitiesToSync ? (20000 + 2000 * (identitiesToSync - 1)) : outdated;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"[%@: %f %u/%u = %.2f/%.2f]", DSPlatformSyncStateKindDescription(self.kind), self.lastSyncedIndentitiesTimestamp, self.queueCount, self.queueMaxAmount, [self progress], [self weight]];
}

@end
@interface DSPeersSyncState ()
@property (nonatomic, assign) DSPeersSyncStateKind kind;
@end

@implementation DSPeersSyncState
- (id)copyWithZone:(NSZone *)zone {
    DSPeersSyncState *copy = [[[self class] alloc] init];
    copy.kind = self.kind;
    copy.hasDownloadPeer = self.hasDownloadPeer;
    copy.peerManagerConnected = self.peerManagerConnected;
    return copy;
}
- (double)progress {
    return self.peerManagerConnected && self.hasDownloadPeer ? 1 : 0;
}

- (void)addSyncKind:(DSPeersSyncStateKind)kind {
    if (!FLAG_IS_SET(self.kind, kind))
        _kind |= kind;
}

- (void)removeSyncKind:(DSPeersSyncStateKind)kind {
    if (FLAG_IS_SET(self.kind, kind))
        _kind &= ~kind;
}
- (void)resetSyncKind {
    _kind = DSPeersSyncStateKind_None;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"[%@: %u/%u]",
            DSPeersSyncStateKindDescription(self.kind),
            self.hasDownloadPeer,
            self.peerManagerConnected];
}

@end

@interface DSSyncState ()
@property (nonatomic, assign) DSSyncStateExtKind extKind;
@end

@implementation DSSyncState

- (instancetype)initWithSyncPhase:(DSChainSyncPhase)phase {
    if (!(self = [super init])) return nil;
    self.syncPhase = phase;
    self.extKind = DSSyncStateExtKind_None;
    self.masternodeListSyncInfo = [[DSMasternodeListSyncState alloc] init];
    self.platformSyncInfo = [[DSPlatformSyncState alloc] init];
    self.peersSyncInfo = [[DSPeersSyncState alloc] init];
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    DSSyncState *copy = [[[self class] alloc] init];
    copy.syncPhase = self.syncPhase;
    copy.extKind = self.extKind;
    copy.estimatedBlockHeight = self.estimatedBlockHeight;
    copy.chainSyncStartHeight = self.chainSyncStartHeight;
    copy.lastSyncBlockHeight = self.lastSyncBlockHeight;
    copy.terminalSyncStartHeight = self.terminalSyncStartHeight;
    copy.lastTerminalBlockHeight = self.lastTerminalBlockHeight;
    copy.masternodeListSyncInfo = [self.masternodeListSyncInfo copy];
    copy.platformSyncInfo = [self.platformSyncInfo copy];
    copy.peersSyncInfo = [self.peersSyncInfo copy];
    return copy;
}

- (BOOL)hasSyncKind:(DSSyncStateExtKind)kind {
    return FLAG_IS_SET(self.extKind, kind);
}

- (void)addSyncKind:(DSSyncStateExtKind)kind {
    if (!FLAG_IS_SET(self.extKind, kind))
        _extKind |= kind;
}

- (void)removeSyncKind:(DSSyncStateExtKind)kind {
    if (FLAG_IS_SET(self.extKind, kind))
        _extKind &= ~kind;
}
- (void)resetSyncKind {
    _extKind = DSSyncStateExtKind_None;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"{ phase: %u, kind: %u, %@, estimated: %u, %@, %@, %@, %@  == %f }",
            self.syncPhase,
            self.extKind,
            self.peersDescription,
            self.estimatedBlockHeight,
            self.chainDescription,
            self.headersDescription,
            self.masternodesDescription,
            self.platformDescription,
            [self progress]
    ];
}

- (NSString *)chainDescription {
    return [NSString stringWithFormat:@"chain: [%u/%u = %.2f/%.2f]", self.chainSyncStartHeight, self.lastSyncBlockHeight, self.chainSyncProgress, self.chainSyncWeight];
}

- (NSString *)headersDescription {
    return [NSString stringWithFormat:@"headers: [%u/%u = %.2f/%.2f]", self.terminalSyncStartHeight, self.lastTerminalBlockHeight, self.terminalHeaderSyncProgress, self.headersSyncWeight];
}

- (NSString *)peersDescription {
    return [NSString stringWithFormat:@"peers: %@", self.peersSyncInfo];
}

- (NSString *)masternodesDescription {
    return [NSString stringWithFormat:@"mn: %@", self.masternodeListSyncInfo];
}

- (NSString *)platformDescription {
    return [NSString stringWithFormat:@"evo: %@", self.platformSyncInfo];
}

- (double)masternodeListProgress {
    return [self.masternodeListSyncInfo progress];
}

- (double)platformProgress {
    return [self.platformSyncInfo progress];
}

- (void)setEstimatedBlockHeight:(uint32_t)estimatedBlockHeight {
    _estimatedBlockHeight = estimatedBlockHeight;
    self.masternodeListSyncInfo.estimatedBlockHeight = estimatedBlockHeight;
}

- (double)chainSyncProgress {
    uint32_t chainSyncStartHeight = self.chainSyncStartHeight;
    uint32_t lastSyncBlockHeight = self.lastSyncBlockHeight;
    uint32_t estimatedBlockHeight = self.estimatedBlockHeight;
    if (!self.peersSyncInfo.hasDownloadPeer && chainSyncStartHeight == 0)
        return 0.0;
    else if (lastSyncBlockHeight >= estimatedBlockHeight)
        return 1.0;
    else if (estimatedBlockHeight == 0)
        return 0.0;
    else if (chainSyncStartHeight > lastSyncBlockHeight)
        return MIN(1.0, MAX(0.0, 0.1 + 0.9 * lastSyncBlockHeight / estimatedBlockHeight));
    double deltaSyncHeight = estimatedBlockHeight - chainSyncStartHeight;
    return deltaSyncHeight == 0 ? 0.0 : MIN(1.0, MAX(0.0, 0.1 + 0.9 * (lastSyncBlockHeight - chainSyncStartHeight) / deltaSyncHeight));
}

- (double)terminalHeaderSyncProgress {
    uint32_t terminalSyncStartHeight = self.terminalSyncStartHeight;
    uint32_t lastTerminalBlockHeight = self.lastTerminalBlockHeight;
    uint32_t estimatedBlockHeight = self.estimatedBlockHeight;
    if (!self.peersSyncInfo.hasDownloadPeer && terminalSyncStartHeight == 0)
        return 0.0;
    else if (lastTerminalBlockHeight >= estimatedBlockHeight)
        return 1.0;
    else
        return MIN(1.0, MAX(0.0, 0.1 + 0.9 * (terminalSyncStartHeight > lastTerminalBlockHeight ? lastTerminalBlockHeight / estimatedBlockHeight : (lastTerminalBlockHeight - terminalSyncStartHeight) / (estimatedBlockHeight - terminalSyncStartHeight))));
}

- (double)chainSyncWeight {
    double weight = self.lastSyncBlockHeight >= self.estimatedBlockHeight ? 0 : self.estimatedBlockHeight - self.lastSyncBlockHeight;
    return weight;
}
- (double)headersSyncWeight {
    double weight = self.lastTerminalBlockHeight >= self.estimatedBlockHeight ? 0 : (self.estimatedBlockHeight - self.lastTerminalBlockHeight) / 4;
    return weight;
}

/**
 * A unit of weight is the time it would take to sync 1000 blocks;
 * terminal headers are 4 times faster the blocks
 * the first masternode list is worth 20000 blocks
 * each masternode list after that is worth 2000 blocks
 */
- (double)progress {
    double chainWeight = [self chainSyncWeight];
    double terminalWeight = [self headersSyncWeight];
    double platformWeight = [self.platformSyncInfo weight];
    double masternodeWeight = [self.masternodeListSyncInfo weight];
    double totalWeight = chainWeight + terminalWeight + masternodeWeight + platformWeight;
    if (totalWeight == 0) {
        return [self.peersSyncInfo progress];
    } else {
        double terminalProgress = self.terminalHeaderSyncProgress * (terminalWeight / totalWeight);
        double chainProgress = self.chainSyncProgress * (chainWeight / totalWeight);
        double masternodesProgress = self.masternodeListProgress * (masternodeWeight / totalWeight);
        double platformProgress = self.platformProgress * (platformWeight / totalWeight);
        double progress = terminalProgress + masternodesProgress + chainProgress + platformProgress;
        if (progress < 0.99995) {
            return progress;
        } else {
            return 1;
        }
    }
}

- (DSSyncStateKind)kind {
    if ([self atTheEndOfSyncBlocksAndSyncingMasternodeList] || [self atTheEndOfInitialTerminalBlocksAndSyncingMasternodeList]) {
        return DSSyncStateKind_Masternodes;
    } else if (self.syncPhase == DSChainSyncPhase_InitialTerminalBlocks) {
        return DSSyncStateKind_Headers;
    } else {
        return DSSyncStateKind_Chain;
    }
    
}

- (BOOL)atTheEndOfSyncBlocksAndSyncingMasternodeList {
    // We give a 6 block window, just in case a new block comes in
    return self.lastSyncBlockHeight + 6 >= self.estimatedBlockHeight
        && self.masternodeListSyncInfo.queueCount > 0
        && self.syncPhase == DSChainSyncPhase_Synced;
}

- (BOOL)atTheEndOfInitialTerminalBlocksAndSyncingMasternodeList {
    // We give a 6 block window, just in case a new block comes in
    return self.lastTerminalBlockHeight + 6 >= self.estimatedBlockHeight
        && self.masternodeListSyncInfo.queueCount > 0
        && self.syncPhase == DSChainSyncPhase_InitialTerminalBlocks;
}

@end

