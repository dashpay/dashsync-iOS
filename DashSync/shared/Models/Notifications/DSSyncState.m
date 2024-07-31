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

@implementation DSMasternodeListSyncState
- (id)copyWithZone:(NSZone *)zone {
    DSMasternodeListSyncState *copy = [[[self class] alloc] init];
    copy.retrievalQueueCount = self.retrievalQueueCount;
    copy.retrievalQueueMaxAmount = self.retrievalQueueMaxAmount;
    copy.storedCount = self.storedCount;
    copy.lastBlockHeight = self.lastBlockHeight;
    return copy;
}
- (NSString *)description {
    return [NSString stringWithFormat:@"%u/%u/%u/%u",
            self.retrievalQueueCount,
            self.retrievalQueueMaxAmount,
            self.storedCount,
            self.lastBlockHeight];
}
@end

@implementation DSSyncState

- (instancetype)initWithSyncPhase:(DSChainSyncPhase)phase {
    if (!(self = [super init])) return nil;
    self.syncPhase = phase;
    self.masternodeListSyncInfo = [[DSMasternodeListSyncState alloc] init];
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    DSSyncState *copy = [[[self class] alloc] init];
    copy.syncPhase = self.syncPhase;
    copy.hasDownloadPeer = self.hasDownloadPeer;
    copy.peerManagerConnected = self.peerManagerConnected;
    copy.estimatedBlockHeight = self.estimatedBlockHeight;
    copy.chainSyncStartHeight = self.chainSyncStartHeight;
    copy.lastSyncBlockHeight = self.lastSyncBlockHeight;
    copy.terminalSyncStartHeight = self.terminalSyncStartHeight;
    copy.lastTerminalBlockHeight = self.lastTerminalBlockHeight;
    copy.masternodeListSyncInfo = [self.masternodeListSyncInfo copy];
    return copy;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"SyncState: { phase: %u, peer: %u, connected: %u, estimated: %u, chain: [%u/%u/%f] headers: [%u/%u/%f], mn: [%@/%u/%f]  == %f",
            self.syncPhase,
            self.hasDownloadPeer,
            self.peerManagerConnected,
            self.estimatedBlockHeight,
            self.chainSyncStartHeight,
            self.lastSyncBlockHeight,
            self.chainSyncProgress,
            self.terminalSyncStartHeight,
            self.lastTerminalBlockHeight,
            self.terminalHeaderSyncProgress,
            self.masternodeListSyncInfo,
            self.masternodeListsToSync,
            self.masternodeListProgress,
            self.combinedSyncProgress
    ];
}

- (double)masternodeListProgress {
    uint32_t amountLeft = self.masternodeListSyncInfo.retrievalQueueCount;
    uint32_t maxAmount = self.masternodeListSyncInfo.retrievalQueueMaxAmount;
    uint32_t lastBlockHeight = self.masternodeListSyncInfo.lastBlockHeight;
    uint32_t estimatedBlockHeight = self.estimatedBlockHeight;
    return amountLeft ? MAX(MIN((maxAmount - amountLeft) / maxAmount, 1), 0) : lastBlockHeight != UINT32_MAX && estimatedBlockHeight != 0 && lastBlockHeight + 16 >= estimatedBlockHeight;
}

- (double)chainSyncProgress {
    uint32_t chainSyncStartHeight = self.chainSyncStartHeight;
    uint32_t lastSyncBlockHeight = self.lastSyncBlockHeight;
    uint32_t estimatedBlockHeight = self.estimatedBlockHeight;
    if (!self.hasDownloadPeer && chainSyncStartHeight == 0)
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
    if (!self.hasDownloadPeer && terminalSyncStartHeight == 0)
        return 0.0;
    else if (lastTerminalBlockHeight >= estimatedBlockHeight)
        return 1.0;
    else
        return MIN(1.0, MAX(0.0, 0.1 + 0.9 * (terminalSyncStartHeight > lastTerminalBlockHeight ? lastTerminalBlockHeight / estimatedBlockHeight : (lastTerminalBlockHeight - terminalSyncStartHeight) / (estimatedBlockHeight - terminalSyncStartHeight))));
}

- (uint32_t)masternodeListsToSync {
    uint32_t estimatedBlockHeight = self.estimatedBlockHeight;
    uint32_t amountLeft = self.masternodeListSyncInfo.retrievalQueueCount;
    uint32_t lastMasternodeListHeight = self.masternodeListSyncInfo.lastBlockHeight;
    uint32_t maxAmount = self.masternodeListSyncInfo.retrievalQueueMaxAmount;
    uint32_t storedCount = self.masternodeListSyncInfo.storedCount;
    uint32_t masternodeListsToSync;
    if (!([[DSOptionsManager sharedInstance] syncType] & DSSyncType_MasternodeList))
        masternodeListsToSync = 0;
    else if (!maxAmount || storedCount <= 1) // 1 because there might be a default
        masternodeListsToSync = (lastMasternodeListHeight == UINT32_MAX || estimatedBlockHeight < lastMasternodeListHeight)
        ? 32
        : MIN(32, (uint32_t)ceil((estimatedBlockHeight - lastMasternodeListHeight) / 24.0f));
    else
        masternodeListsToSync = amountLeft;

    return masternodeListsToSync;
}
/**
 * A unit of weight is the time it would take to sync 1000 blocks;
 * terminal headers are 4 times faster the blocks
 * the first masternode list is worth 20000 blocks
 * each masternode list after that is worth 2000 blocks
 */
- (double)combinedSyncProgress {
    uint32_t estimatedBlockHeight = self.estimatedBlockHeight;
    uint32_t lastTerminalBlockHeight = self.lastTerminalBlockHeight;
    uint32_t lastSyncBlockHeight = self.lastSyncBlockHeight;
    double chainWeight = lastSyncBlockHeight >= estimatedBlockHeight ? 0 : estimatedBlockHeight - lastSyncBlockHeight;
    double terminalWeight = lastTerminalBlockHeight >= estimatedBlockHeight ? 0 : (estimatedBlockHeight - lastTerminalBlockHeight) / 4;
    uint32_t listsToSync = [self masternodeListsToSync];
    double masternodeWeight = listsToSync ? (20000 + 2000 * (listsToSync - 1)) : 0;
    double totalWeight = chainWeight + terminalWeight + masternodeWeight;
    if (totalWeight == 0) {
        return self.peerManagerConnected && self.hasDownloadPeer ? 1 : 0;
    } else {
        double terminalProgress = self.terminalHeaderSyncProgress * (terminalWeight / totalWeight);
        double chainProgress = self.chainSyncProgress * (chainWeight / totalWeight);
        double masternodesProgress = self.masternodeListProgress * (masternodeWeight / totalWeight);
        double progress = terminalProgress + masternodesProgress + chainProgress;
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
        && self.masternodeListSyncInfo.retrievalQueueCount > 0
        && self.syncPhase == DSChainSyncPhase_Synced;
}

- (BOOL)atTheEndOfInitialTerminalBlocksAndSyncingMasternodeList {
    // We give a 6 block window, just in case a new block comes in
    return self.lastTerminalBlockHeight + 6 >= self.estimatedBlockHeight
        && self.masternodeListSyncInfo.retrievalQueueCount > 0
        && self.syncPhase == DSChainSyncPhase_InitialTerminalBlocks;
}

@end

