//
//  DSMasternodeManager.m
//  DashSync
//
//  Created by Sam Westrich on 6/7/18.
//  Copyright (c) 2018 Dash Core Group <contact@dash.org>
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

#import "DSMasternodeManager.h"
#import "DSChain+Protected.h"
#import "DSChainManager+Protected.h"
#import "DSCheckpoint.h"
#import "DSGetMNListDiffRequest.h"
#import "DSGetQRInfoRequest.h"
#import "DSMasternodeProcessorContext.h"
#import "DSMasternodeListService+Protected.h"
#import "DSMasternodeListStore+Protected.h"
#import "DSMasternodeManager+LocalMasternode.h"
#import "DSMasternodeManager+Mndiff.h"
#import "DSMerkleBlock.h"
#import "DSMnDiffProcessingResult.h"
#import "DSOperationQueue.h"
#import "DSOptionsManager.h"
#import "DSPeer.h"
#import "DSPeerManager+Protected.h"
#import "DSQRInfoProcessingResult.h"
#import "DSSimplifiedMasternodeEntry.h"
#import "DSTransactionManager+Protected.h"
#import "NSError+Dash.h"

#define SAVE_MASTERNODE_DIFF_TO_FILE (1 && DEBUG)
#define DSFullLog(FORMAT, ...) printf("%s\n", [[NSString stringWithFormat:FORMAT, ##__VA_ARGS__] UTF8String])


@interface DSMasternodeManager ()

@property (nonatomic, strong) DSChain *chain;
@property (nonatomic, strong) DSMasternodeListStore *store;
@property (nonatomic, strong) DSMasternodeListDiffService *masternodeListDiffService;
@property (nonatomic, strong) DSQuorumRotationService *quorumRotationService;
@property (nonatomic, assign) NSTimeInterval timeIntervalForMasternodeRetrievalSafetyDelay;

@property (nonatomic, assign, nullable) MasternodeProcessor *processor;
@property (nonatomic, assign, nullable) MasternodeProcessorCache *processorCache;

@property (nonatomic, assign) uint32_t rotatedQuorumsActivationHeight;
@property (nonatomic, strong) dispatch_group_t processingGroup;
@property (nonatomic, strong) dispatch_queue_t processingQueue;

@end


@implementation DSMasternodeManager

- (void)dealloc {
    [self destroyProcessors];
}

- (void)destroyProcessors {
    [DSMasternodeManager unregisterProcessor:self.processor];
    [DSMasternodeManager destroyProcessorCache:self.processorCache];
    _processor = nil;
    _processorCache = nil;
}

- (BOOL)hasCurrentMasternodeListInLast30Days {
    return self.currentMasternodeList && [[NSDate date] timeIntervalSince1970] - [self.chain timestampForBlockHeight:self.currentMasternodeList.height] < DAY_TIME_INTERVAL * 30;
}

- (instancetype)initWithChain:(DSChain *)chain {
    NSParameterAssert(chain);
    if (!(self = [super init])) return nil;
    _chain = chain;
    _store = [[DSMasternodeListStore alloc] initWithChain:chain];
    self.masternodeListDiffService = [[DSMasternodeListDiffService alloc] initWithChain:chain store:_store delegate:self];
    self.quorumRotationService = [[DSQuorumRotationService alloc] initWithChain:chain store:_store delegate:self];
    _rotatedQuorumsActivationHeight = UINT32_MAX;
    _processor = [DSMasternodeManager registerProcessor];
    _processorCache = [DSMasternodeManager createProcessorCache];
    _processingGroup = dispatch_group_create();
    _processingQueue = dispatch_queue_create([[NSString stringWithFormat:@"org.dashcore.dashsync.processing.%@", uint256_data(self.chain.genesisHash).shortHexString] UTF8String], DISPATCH_QUEUE_SERIAL);
    return self;
}

#pragma mark - DSMasternodeListServiceDelegate

- (DSMasternodeList *__nullable)masternodeListSerivceDidRequestFileFromBlockHash:(DSMasternodeListService *)service blockHash:(UInt256)blockHash {
    return [self processRequestFromFileForBlockHash:blockHash];
}

- (void)masternodeListSerivceExceededMaxFailuresForMasternodeList:(DSMasternodeListService *)service blockHash:(UInt256)blockHash {
    [self removeOutdatedMasternodeListsBeforeBlockHash:blockHash];
}

- (void)masternodeListSerivceEmptiedRetrievalQueue:(DSMasternodeListService *)service {
    if (![self.masternodeListDiffService retrievalQueueCount]) {
        if (![self.quorumRotationService retrievalQueueCount])
            [self removeOutdatedMasternodeListsBeforeBlockHash:self.store.lastQueriedBlockHash];
        [self.chain.chainManager chainFinishedSyncingMasternodeListsAndQuorums:self.chain];
    }
}


// MARK: - Helpers

- (NSArray *)recentMasternodeLists {
    return [self.store recentMasternodeLists];
}

- (NSUInteger)knownMasternodeListsCount {
    return [self.store knownMasternodeListsCount];
}

- (uint32_t)earliestMasternodeListBlockHeight {
    return [self.store earliestMasternodeListBlockHeight];
}

- (uint32_t)lastMasternodeListBlockHeight {
    return [self.store lastMasternodeListBlockHeight];
}

- (uint32_t)heightForBlockHash:(UInt256)blockhash {
    return [self.store heightForBlockHash:blockhash];
}

- (DSSimplifiedMasternodeEntry *)masternodeHavingProviderRegistrationTransactionHash:(NSData *)providerRegistrationTransactionHash {
    NSParameterAssert(providerRegistrationTransactionHash);
    return [self.currentMasternodeList.simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash objectForKey:providerRegistrationTransactionHash];
}

- (NSUInteger)simplifiedMasternodeEntryCount {
    return [self.currentMasternodeList masternodeCount];
}

- (NSUInteger)activeQuorumsCount {
    return [self.currentMasternodeList quorumsCount];
}

- (BOOL)hasMasternodeAtLocation:(UInt128)IPAddress port:(uint32_t)port {
    for (DSSimplifiedMasternodeEntry *simplifiedMasternodeEntry in [self.currentMasternodeList.simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash allValues]) {
        if (uint128_eq(simplifiedMasternodeEntry.address, IPAddress) && simplifiedMasternodeEntry.port == port) {
            return YES;
        }
    }
    return NO;
}

- (NSUInteger)masternodeListRetrievalQueueCount {
    return [self.masternodeListDiffService retrievalQueueCount];
}

- (NSUInteger)masternodeListRetrievalQueueMaxAmount {
    return [self.masternodeListDiffService retrievalQueueMaxAmount];
}

- (uint32_t)estimatedMasternodeListsToSync {
    BOOL syncMasternodeLists = ([[DSOptionsManager sharedInstance] syncType] & DSSyncType_MasternodeList);
    if (!syncMasternodeLists) {
        return 0;
    }
    double amountLeft = self.masternodeListRetrievalQueueCount;
    double maxAmount = self.masternodeListRetrievalQueueMaxAmount;
    if (!maxAmount || self.store.masternodeListsByBlockHash.count <= 1) { //1 because there might be a default
        return self.store.masternodeListsToSync;
    }
    return amountLeft;
}

- (double)masternodeListAndQuorumsSyncProgress {
    double amountLeft = self.masternodeListRetrievalQueueCount;
    double maxAmount = self.masternodeListRetrievalQueueMaxAmount;
    if (!amountLeft) {
        return self.store.masternodeListsAndQuorumsIsSynced;
    }
    double progress = MAX(MIN((maxAmount - amountLeft) / maxAmount, 1), 0);
    return progress;
}

- (BOOL)currentMasternodeListIsInLast24Hours {
    if (!self.currentMasternodeList) {
        return NO;
    }
    DSBlock *block = [self.chain blockForBlockHash:self.currentMasternodeList.blockHash];
    if (!block) return FALSE;
    NSTimeInterval currentTimestamp = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval delta = currentTimestamp - block.timestamp;
    return fabs(delta) < DAY_TIME_INTERVAL;

}


// MARK: - Set Up and Tear Down

- (void)setUp {
    __weak typeof(self) weakSelf = self;
    [self.store setUp:^(DSMasternodeList * _Nonnull masternodeList) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        strongSelf.masternodeListDiffService.currentMasternodeList = masternodeList;
    }];
    [self loadFileDistributedMasternodeLists];
}

- (DSMasternodeList *_Nullable)reloadMasternodeLists {
    return [self reloadMasternodeListsWithBlockHeightLookup:nil];
}

- (DSMasternodeList *_Nullable)reloadMasternodeListsWithBlockHeightLookup:(BlockHeightFinder)blockHeightLookup {
    [self clearProcessorCache];
    [self.store removeAllMasternodeLists];
    return [self.store loadMasternodeListsWithBlockHeightLookup:blockHeightLookup];
}

- (DSMasternodeList *)currentMasternodeList {
    if (!self.chain.isRotatedQuorumsPresented) {
        return self.masternodeListDiffService.currentMasternodeList;
    } else {
        UInt256 lastMnlistDiffBlockHash = self.masternodeListDiffService.currentMasternodeList.blockHash;
        UInt256 lastQrInfoDiffBlockHash = self.quorumRotationService.currentMasternodeList.blockHash;
        return [self heightForBlockHash:lastMnlistDiffBlockHash] > [self heightForBlockHash:lastQrInfoDiffBlockHash] ? self.masternodeListDiffService.currentMasternodeList : self.quorumRotationService.currentMasternodeList;
    }
}

- (void)loadFileDistributedMasternodeLists {
    BOOL syncMasternodeLists = [[DSOptionsManager sharedInstance] syncType] & DSSyncType_MasternodeList;
    BOOL useCheckpointMasternodeLists = [[DSOptionsManager sharedInstance] useCheckpointMasternodeLists];
    if (!syncMasternodeLists ||
        !useCheckpointMasternodeLists ||
        self.currentMasternodeList) {
        return;
    }
    DSCheckpoint *checkpoint = [self.chain lastCheckpointHavingMasternodeList];
    if (!checkpoint ||
        self.chain.lastTerminalBlockHeight < checkpoint.height ||
        [self masternodeListForBlockHash:checkpoint.blockHash withBlockHeightLookup:nil]) {
        return;
    }
    DSMasternodeList *masternodeList = [self processRequestFromFileForBlockHash:checkpoint.blockHash];
    if (masternodeList) {
        self.masternodeListDiffService.currentMasternodeList = masternodeList;
    }
}

- (DSMasternodeList *)loadMasternodeListAtBlockHash:(NSData *)blockHash withBlockHeightLookup:(BlockHeightFinder)blockHeightLookup {
    return [self.store loadMasternodeListAtBlockHash:blockHash withBlockHeightLookup:blockHeightLookup];
}

- (void)wipeMasternodeInfo {
    DSLog(@"wipeMasternodeInfo");
    [self clearProcessorCache];
    [self.store removeAllMasternodeLists];
    [self.masternodeListDiffService cleanAllLists];
    [self.quorumRotationService cleanAllLists];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DSMasternodeListDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey: self.chain}];
        [[NSNotificationCenter defaultCenter] postNotificationName:DSQuorumListDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey: self.chain}];
    });
}

// MARK: - LLMQ Snapshot List Helpers
- (DSQuorumSnapshot *_Nullable)quorumSnapshotForBlockHeight:(uint32_t)blockHeight {
    DSBlock *block = [self.chain blockAtHeight:blockHeight];
    if (!block) {
        DSLog(@"No block for snapshot at height: %ul: ", blockHeight);
        return nil;
    }
    return [self.store.cachedQuorumSnapshots objectForKey:uint256_data(block.blockHash)];
}

- (DSQuorumSnapshot *_Nullable)quorumSnapshotForBlockHash:(UInt256)blockHash {
    return [self.store.cachedQuorumSnapshots objectForKey:uint256_data(blockHash)];
}

- (BOOL)saveQuorumSnapshot:(DSQuorumSnapshot *)snapshot {
    [self.store.cachedQuorumSnapshots setObject:snapshot forKey:uint256_data(snapshot.blockHash)];
    return YES;
}

- (BOOL)saveMasternodeList:(DSMasternodeList *)masternodeList forBlockHash:(UInt256)blockHash {
    /// TODO: need to properly store in CoreData or wait for rust SQLite
    DSLog(@"••• addMasternodeList (saveMasternodeList) -> %@: %@", uint256_hex(blockHash), masternodeList);
    [self.store.masternodeListsByBlockHash setObject:masternodeList forKey:uint256_data(blockHash)];
    return YES;
}

// MARK: - Masternode List Helpers

- (DSMasternodeList *)masternodeListForBlockHash:(UInt256)blockHash {
    return [self masternodeListForBlockHash:blockHash withBlockHeightLookup:nil];
}

- (DSMasternodeList *)masternodeListForBlockHash:(UInt256)blockHash withBlockHeightLookup:(BlockHeightFinder)blockHeightLookup {
    return [self.store masternodeListForBlockHash:blockHash withBlockHeightLookup:blockHeightLookup];
}

- (DSMasternodeList *)masternodeListBeforeBlockHash:(UInt256)blockHash {
    return [self.store masternodeListBeforeBlockHash:blockHash];
}

// MARK: - Requesting Masternode List

- (void)startSync {
    [self getRecentMasternodeList];
}

- (void)getRecentMasternodeList {
    DSLog(@"getRecentMasternodeList at tip");
    [self.masternodeListDiffService getRecentMasternodeList];
    if (self.chain.isRotatedQuorumsPresented) {
        [self.quorumRotationService getRecentMasternodeList];
    }

}

// the safety delay checks to see if this was called in the last n seconds.
- (void)getCurrentMasternodeListWithSafetyDelay:(uint32_t)safetyDelay {
    self.timeIntervalForMasternodeRetrievalSafetyDelay = [[NSDate date] timeIntervalSince1970];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(safetyDelay * NSEC_PER_SEC)), self.chain.networkingQueue, ^{
        NSTimeInterval timeElapsed = [[NSDate date] timeIntervalSince1970] - self.timeIntervalForMasternodeRetrievalSafetyDelay;
        if (timeElapsed > safetyDelay) {
            [self getRecentMasternodeList];
        }
    });
}

- (void)getMasternodeListsForBlockHashes:(NSOrderedSet *)blockHashes {
    [self.masternodeListDiffService populateRetrievalQueueWithBlockHashes:blockHashes];
}

- (BOOL)requestMasternodeListForBlockHeight:(uint32_t)blockHeight error:(NSError **)error {
    DSMerkleBlock *merkleBlock = [self.chain blockAtHeight:blockHeight];
    if (!merkleBlock) {
        if (error) {
            *error = [NSError errorWithCode:600 localizedDescriptionKey:@"Unknown block"];
        }
        return FALSE;
    }
    [self requestMasternodeListForBlockHash:merkleBlock.blockHash];
    return TRUE;
}

- (BOOL)requestMasternodeListForBlockHash:(UInt256)blockHash {
    self.store.lastQueriedBlockHash = blockHash;
    NSData *blockHashData = uint256_data(blockHash);
    [self.store.masternodeListQueriesNeedingQuorumsValidated addObject:blockHashData];
    // this is safe
    [self getMasternodeListsForBlockHashes:[NSOrderedSet orderedSetWithObject:blockHashData]];
    return TRUE;
}

- (DSMasternodeList *__nullable)processRequestFromFileForBlockHash:(UInt256)blockHash {
    NSData *message = [self.store messageFromFileForBlockHash:blockHash];
    if (!message) {
        return NULL;
    }
    MerkleBlockFinder blockFinder = ^DSMerkleBlock *(UInt256 blockHash) {
        return [self.chain blockForBlockHash:blockHash];
    };
    DSMasternodeProcessorContext *context = [self createDiffMessageContext:NO isFromSnapshot:YES isDIP0024:NO peer:nil merkleRootLookup:^UInt256(UInt256 blockHash) {
        return blockFinder(blockHash).merkleRoot;
    }];
    DSMnDiffProcessingResult *result = [self processMasternodeDiffMessage:message withContext:context];
    
    __block DSMerkleBlock *block = blockFinder(blockHash);
    if (![result isValid]) {
        DSLog(@"Invalid File for block at height %u with merkleRoot %@ (foundCoinbase %@ | validQuorums %@ | rootMNListValid %@ | rootQuorumListValid %@)", block.height, uint256_hex(block.merkleRoot), result.foundCoinbase?@"Yes":@"No", result.validQuorums?@"Yes":@"No", result.rootMNListValid?@"Yes":@"No", result.rootQuorumListValid?@"Yes":@"No");
        return NULL;
    }
    // valid Coinbase might be false if no merkle block
    if (block && !result.validCoinbase) {
        DSLog(@"Invalid Coinbase for block at height %u with merkleRoot %@", block.height, uint256_hex(block.merkleRoot));
        return NULL;
    }
    DSMasternodeList *masternodeList = result.masternodeList;
    [self.store saveMasternodeList:masternodeList
                  addedMasternodes:result.addedMasternodes
               modifiedMasternodes:result.modifiedMasternodes
                      addedQuorums:result.addedQuorums
                        completion:^(NSError *_Nonnull error) {
        DSLog(@"MNL Saved from file");
    }];
    return masternodeList;
}


// MARK: - Deterministic Masternode List Sync

- (DSBlock *)lastBlockForBlockHash:(UInt256)blockHash fromPeer:(DSPeer *)peer {
    DSBlock *lastBlock = nil;
    if ([self.chain heightForBlockHash:blockHash]) {
        lastBlock = [[peer.chain terminalBlocks] objectForKey:uint256_obj(blockHash)];
        if (!lastBlock && [peer.chain allowInsightBlocksForVerification]) {
            NSData *blockHashData = uint256_data(blockHash);
            lastBlock = [[peer.chain insightVerifiedBlocksByHashDictionary] objectForKey:blockHashData];
            if (!lastBlock && peer.chain.isTestnet) {
                //We can trust insight if on testnet
                [self.chain blockUntilGetInsightForBlockHash:blockHash];
                lastBlock = [[peer.chain insightVerifiedBlocksByHashDictionary] objectForKey:blockHashData];
            }
        }
    } else {
        lastBlock = [peer.chain recentTerminalBlockForBlockHash:blockHash];
    }
    return lastBlock;
}

- (NSString *)logListSet:(NSOrderedSet<NSData *> *)list {
    NSString *str = @"\n";
    for (NSData *blockHashData in list) {
        str = [str stringByAppendingString:[NSString stringWithFormat:@"•••• -> %d: %@,\n", [self heightForBlockHash:blockHashData.UInt256], blockHashData.hexString]];
    }
    return str;
}

- (void)removeOutdatedMasternodeListsBeforeBlockHash:(UInt256)blockHash {
    DSMasternodeList *qrinfoMasternodeList = self.quorumRotationService.masternodeListAtH4C;
    if (!qrinfoMasternodeList) {
        qrinfoMasternodeList = self.quorumRotationService.masternodeListAtH3C;
    }
    DSMasternodeList *diffMasternodeList = self.masternodeListDiffService.currentMasternodeList;
    uint32_t heightToDelete = UINT32_MAX;
    if (diffMasternodeList) {
        heightToDelete = diffMasternodeList.height;
        NSData *oldestHashInDiffQueue = [self.masternodeListDiffService.retrievalQueue firstObject];
        if (oldestHashInDiffQueue) {
            uint32_t oldestHeight = [self heightForBlockHash:oldestHashInDiffQueue.UInt256];
            if (heightToDelete > oldestHeight) {
                heightToDelete = oldestHeight;
            }
        }
    } else {
        // Don't remove if we didn't get updates from mnlistdiff
        return;
    }
    if (qrinfoMasternodeList) {
        if (heightToDelete > qrinfoMasternodeList.height) {
            heightToDelete = qrinfoMasternodeList.height;
        }
        NSData *oldestHashInQRInfoQueue = [self.quorumRotationService.retrievalQueue firstObject];
        if (oldestHashInQRInfoQueue) {
            uint32_t oldestHeight = [self heightForBlockHash:oldestHashInQRInfoQueue.UInt256];
            if (heightToDelete > oldestHeight) {
                heightToDelete = oldestHeight;
            }
        }
    } else {
        // Don't remove if we didn't get updates from qrinfo
        return;
    }
    if (heightToDelete > 0 && heightToDelete != UINT32_MAX) {
        DSLog(@"--> removeOldMasternodeLists (removeOutdatedMasternodeListsBeforeBlockHash): %u (%u, %u)", heightToDelete, diffMasternodeList.height, qrinfoMasternodeList.height);
        uint32_t h = heightToDelete - 50;
        NSDictionary *lists = [[self.store masternodeListsByBlockHash] copy];
        for (NSData *proRegTxHashData in lists) {
            DSMasternodeList *list = lists[proRegTxHashData];
            if (list.height < h) {
                [self removeMasternodeListFromCacheAtBlockHash:list.blockHash];
            }
        }
        [self.store removeOldMasternodeLists:heightToDelete];
    }
}

- (void)processMasternodeListDiffResult:(DSMnDiffProcessingResult *)result forPeer:(DSPeer *)peer skipPresenceInRetrieval:(BOOL)skipPresenceInRetrieval completion:(void (^)(void))completion {
    DSMasternodeList *masternodeList = result.masternodeList;
    DSLog(@"•••• processMasternodeListDiffResult: isValid: %d validCoinbase: %d", [result isValid], result.validCoinbase);
    if ([self.masternodeListDiffService shouldProcessDiffResult:result skipPresenceInRetrieval:skipPresenceInRetrieval]) {
        NSOrderedSet *neededMissingMasternodeLists = result.neededMissingMasternodeLists;
        DSLog(@"•••• processMasternodeListDiffResult: missingMasternodeLists: %@", [self logListSet:neededMissingMasternodeLists]);
        UInt256 masternodeListBlockHash = masternodeList.blockHash;
        NSData *masternodeListBlockHashData = uint256_data(masternodeListBlockHash);
        if ([neededMissingMasternodeLists count] && [self.store.masternodeListQueriesNeedingQuorumsValidated containsObject:masternodeListBlockHashData]) {
            [self.masternodeListDiffService removeFromRetrievalQueue:masternodeListBlockHashData];
            [self processMissingMasternodeLists:neededMissingMasternodeLists forMasternodeList:masternodeList];
            completion();
        } else {
            if (uint256_eq(self.store.lastQueriedBlockHash, masternodeListBlockHash)) {
                self.masternodeListDiffService.currentMasternodeList = masternodeList;
                [self.store.masternodeListQueriesNeedingQuorumsValidated removeObject:masternodeListBlockHashData];
            }
            DSLog(@"••• updateStoreWithMasternodeList: %u: %@ (%@)", masternodeList.height, uint256_hex(masternodeListBlockHash), uint256_reverse_hex(masternodeListBlockHash));
            [self updateStoreWithMasternodeList:masternodeList addedMasternodes:result.addedMasternodes modifiedMasternodes:result.modifiedMasternodes addedQuorums:result.addedQuorums completion:^(NSError *error) {
                if ([result hasRotatedQuorumsForChain:self.chain] && !self.chain.isRotatedQuorumsPresented) {
                    uint32_t masternodeListBlockHeight = [self heightForBlockHash:masternodeListBlockHash];
                    DSLog(@"•••• processMasternodeListDiffResult: rotated quorums are presented at height %u: %@, so we'll switch into consuming qrinfo", masternodeListBlockHeight, uint256_hex(masternodeListBlockHash));
                    self.chain.isRotatedQuorumsPresented = YES;
                    self.rotatedQuorumsActivationHeight = masternodeListBlockHeight;
                    [self.quorumRotationService addToRetrievalQueue:masternodeListBlockHashData];
                    [self.quorumRotationService dequeueMasternodeListRequest];
                }
                [self.masternodeListDiffService updateAfterProcessingMasternodeListWithBlockHash:masternodeListBlockHashData fromPeer:peer];
                completion();
            }];
        }
    } else {
        [self.masternodeListDiffService issueWithMasternodeListFromPeer:peer];
        completion();
    }
}
- (void)processQRInfoResult:(DSQRInfoProcessingResult *)result forPeer:(DSPeer *)peer completion:(void (^)(void))completion {
    
    DSMnDiffProcessingResult *mnListDiffResultAtTip = result.mnListDiffResultAtTip;
    DSMnDiffProcessingResult *mnListDiffResultAtH = result.mnListDiffResultAtH;
    DSMnDiffProcessingResult *mnListDiffResultAtHC = result.mnListDiffResultAtHC;
    DSMnDiffProcessingResult *mnListDiffResultAtH2C = result.mnListDiffResultAtH2C;
    DSMnDiffProcessingResult *mnListDiffResultAtH3C = result.mnListDiffResultAtH3C;
    DSMnDiffProcessingResult *mnListDiffResultAtH4C = result.mnListDiffResultAtH4C;
    DSLog(@"•••• processQRInfoResult tip: %d", [mnListDiffResultAtTip isValid]);

    NSOrderedSet *missingMasternodeListsAtTip = mnListDiffResultAtTip.neededMissingMasternodeLists;
    NSOrderedSet *missingMasternodeListsAtH = mnListDiffResultAtH.neededMissingMasternodeLists;
    NSOrderedSet *missingMasternodeListsAtHC = mnListDiffResultAtHC.neededMissingMasternodeLists;
    NSOrderedSet *missingMasternodeListsAtH2C = mnListDiffResultAtH2C.neededMissingMasternodeLists;
    NSOrderedSet *missingMasternodeListsAtH3C = mnListDiffResultAtH3C.neededMissingMasternodeLists;
    NSOrderedSet *missingMasternodeListsAtH4C = mnListDiffResultAtH4C.neededMissingMasternodeLists;

    NSMutableOrderedSet *missingMasternodeLists = [NSMutableOrderedSet orderedSet];
    [missingMasternodeLists addObjectsFromArray:[missingMasternodeListsAtTip array]];
    [missingMasternodeLists addObjectsFromArray:[missingMasternodeListsAtH array]];
    [missingMasternodeLists addObjectsFromArray:[missingMasternodeListsAtHC array]];
    [missingMasternodeLists addObjectsFromArray:[missingMasternodeListsAtH2C array]];
    [missingMasternodeLists addObjectsFromArray:[missingMasternodeListsAtH3C array]];
    [missingMasternodeLists addObjectsFromArray:[missingMasternodeListsAtH4C array]];
    DSLog(@"•••• processQRInfoResult: missingMasternodeLists: %@", [self logListSet:missingMasternodeLists]);
    
    DSMasternodeList *masternodeListAtTip = mnListDiffResultAtTip.masternodeList;
    DSMasternodeList *masternodeListAtH = mnListDiffResultAtH.masternodeList;
    DSMasternodeList *masternodeListAtHC = mnListDiffResultAtHC.masternodeList;
    DSMasternodeList *masternodeListAtH2C = mnListDiffResultAtH2C.masternodeList;
    DSMasternodeList *masternodeListAtH3C = mnListDiffResultAtH3C.masternodeList;
    DSMasternodeList *masternodeListAtH4C = mnListDiffResultAtH4C.masternodeList;
    self.quorumRotationService.masternodeListAtTip = masternodeListAtTip;
    self.quorumRotationService.masternodeListAtH = masternodeListAtH;
    self.quorumRotationService.masternodeListAtHC = masternodeListAtHC;
    self.quorumRotationService.masternodeListAtH2C = masternodeListAtH2C;
    self.quorumRotationService.masternodeListAtH3C = masternodeListAtH3C;
    self.quorumRotationService.masternodeListAtH4C = masternodeListAtH4C;
    UInt256 blockHashAtTip = masternodeListAtTip.blockHash;
    UInt256 blockHashAtH = masternodeListAtH.blockHash;
    UInt256 blockHashAtHC = masternodeListAtHC.blockHash;
    UInt256 blockHashAtH2C = masternodeListAtH2C.blockHash;
    UInt256 blockHashAtH3C = masternodeListAtH3C.blockHash;
    UInt256 blockHashAtH4C = masternodeListAtH4C.blockHash;
    NSData *blockHashDataAtTip = uint256_data(blockHashAtTip);
    NSData *blockHashDataAtH = uint256_data(blockHashAtH);
    NSData *blockHashDataAtHC = uint256_data(blockHashAtHC);
    NSData *blockHashDataAtH2C = uint256_data(blockHashAtH2C);
    NSData *blockHashDataAtH3C = uint256_data(blockHashAtH3C);
    NSData *blockHashDataAtH4C = uint256_data(blockHashAtH4C);
    if (![self.quorumRotationService shouldProcessDiffResult:mnListDiffResultAtH4C skipPresenceInRetrieval:YES]) {
        [self.quorumRotationService issueWithMasternodeListFromPeer:peer];
    } else if (![missingMasternodeListsAtH4C count] || ![self.store.masternodeListQueriesNeedingQuorumsValidated containsObject:blockHashDataAtH4C]) {
        DSLog(@"••• updateStoreWithMasternodeList (h-4c): %u: %@ (%@)", masternodeListAtH4C.height, uint256_hex(blockHashAtH4C), uint256_reverse_hex(blockHashAtH4C));
        [self updateStoreWithMasternodeList:masternodeListAtH4C addedMasternodes:mnListDiffResultAtH4C.addedMasternodes modifiedMasternodes:mnListDiffResultAtH4C.modifiedMasternodes addedQuorums:mnListDiffResultAtH4C.addedQuorums completion:^(NSError *error) {}];
    }
    if (![self.quorumRotationService shouldProcessDiffResult:mnListDiffResultAtH3C skipPresenceInRetrieval:YES]) {
        [self.quorumRotationService issueWithMasternodeListFromPeer:peer];
    } else if (![missingMasternodeListsAtH3C count] || ![self.store.masternodeListQueriesNeedingQuorumsValidated containsObject:blockHashDataAtH3C]) {
        DSLog(@"••• updateStoreWithMasternodeList (h-3c): %u: %@ (%@)", masternodeListAtH3C.height, uint256_hex(blockHashAtH3C), uint256_reverse_hex(blockHashAtH3C));
        [self updateStoreWithMasternodeList:masternodeListAtH3C addedMasternodes:mnListDiffResultAtH3C.addedMasternodes modifiedMasternodes:mnListDiffResultAtH3C.modifiedMasternodes addedQuorums:mnListDiffResultAtH3C.addedQuorums completion:^(NSError *error) {}];
    }
    if (![self.quorumRotationService shouldProcessDiffResult:mnListDiffResultAtH2C skipPresenceInRetrieval:YES]) {
        [self.quorumRotationService issueWithMasternodeListFromPeer:peer];
    } else if (![missingMasternodeListsAtH2C count] || ![self.store.masternodeListQueriesNeedingQuorumsValidated containsObject:blockHashDataAtH2C]) {
        DSLog(@"••• updateStoreWithMasternodeList (h-2c): %u: %@ (%@)", masternodeListAtH2C.height, uint256_hex(blockHashAtH2C), uint256_reverse_hex(blockHashAtH2C));
        [self updateStoreWithMasternodeList:masternodeListAtH2C addedMasternodes:mnListDiffResultAtH2C.addedMasternodes modifiedMasternodes:mnListDiffResultAtH2C.modifiedMasternodes addedQuorums:mnListDiffResultAtH2C.addedQuorums completion:^(NSError *error) {}];
    }
    if (![self.quorumRotationService shouldProcessDiffResult:mnListDiffResultAtHC skipPresenceInRetrieval:YES]) {
        [self.quorumRotationService issueWithMasternodeListFromPeer:peer];
    } else if (![missingMasternodeListsAtHC count] || ![self.store.masternodeListQueriesNeedingQuorumsValidated containsObject:blockHashDataAtHC]) {
        DSLog(@"••• updateStoreWithMasternodeList (h-c): %u: %@ (%@)", masternodeListAtHC.height, uint256_hex(blockHashAtHC), uint256_reverse_hex(blockHashAtHC));
        [self updateStoreWithMasternodeList:masternodeListAtHC addedMasternodes:mnListDiffResultAtHC.addedMasternodes modifiedMasternodes:mnListDiffResultAtHC.modifiedMasternodes addedQuorums:mnListDiffResultAtHC.addedQuorums completion:^(NSError *error) {}];
    }
    if (![self.quorumRotationService shouldProcessDiffResult:mnListDiffResultAtH skipPresenceInRetrieval:YES]) {
        [self.quorumRotationService issueWithMasternodeListFromPeer:peer];
    } else if (![missingMasternodeListsAtH count] || ![self.store.masternodeListQueriesNeedingQuorumsValidated containsObject:blockHashDataAtH]) {
        DSLog(@"••• updateStoreWithMasternodeList (h): %u: %@ (%@)", masternodeListAtH.height, uint256_hex(blockHashAtH), uint256_reverse_hex(blockHashAtH));
        [self updateStoreWithMasternodeList:masternodeListAtH addedMasternodes:mnListDiffResultAtH.addedMasternodes modifiedMasternodes:mnListDiffResultAtH.modifiedMasternodes addedQuorums:mnListDiffResultAtH.addedQuorums completion:^(NSError *error) {}];
    }

    if (![self.quorumRotationService shouldProcessDiffResult:mnListDiffResultAtTip skipPresenceInRetrieval:YES]) {
        [self.quorumRotationService issueWithMasternodeListFromPeer:peer];
    } else {
        if ([missingMasternodeListsAtTip count] && [self.store.masternodeListQueriesNeedingQuorumsValidated containsObject:blockHashDataAtTip]) {
            [self.quorumRotationService removeFromRetrievalQueue:blockHashDataAtTip];
            [self processMissingMasternodeLists:missingMasternodeLists forMasternodeList:masternodeListAtTip];
        } else {
            if (uint256_eq(self.store.lastQueriedBlockHash, blockHashAtTip)) {
                self.quorumRotationService.currentMasternodeList = masternodeListAtTip;
                [self.store.masternodeListQueriesNeedingQuorumsValidated removeObject:blockHashDataAtTip];
            }
            DSLog(@"••• updateStoreWithMasternodeList (tip): %u: %@ (%@)", masternodeListAtTip.height, uint256_hex(blockHashAtTip), uint256_reverse_hex(blockHashAtTip));
            [self updateStoreWithMasternodeList:masternodeListAtTip addedMasternodes:mnListDiffResultAtTip.addedMasternodes modifiedMasternodes:mnListDiffResultAtTip.modifiedMasternodes addedQuorums:mnListDiffResultAtTip.addedQuorums completion:^(NSError *error) {}];
            [self.quorumRotationService updateAfterProcessingMasternodeListWithBlockHash:blockHashDataAtTip fromPeer:peer];
        }
    }
        
    [self.store saveQuorumSnapshot:result.snapshotAtHC toChain:self.chain completion:^(NSError * _Nonnull error) {}];
    [self.store saveQuorumSnapshot:result.snapshotAtH2C toChain:self.chain completion:^(NSError * _Nonnull error) {}];
    [self.store saveQuorumSnapshot:result.snapshotAtH3C toChain:self.chain completion:^(NSError * _Nonnull error) {}];
    [self.store saveQuorumSnapshot:result.snapshotAtH4C toChain:self.chain completion:^(NSError * _Nonnull error) {}];
    
    for (DSMnDiffProcessingResult *diffResult in result.mnListDiffList) {
        DSLog(@"•••• -> processed qrinfo +++ %u..%u %@ .. %@", [self heightForBlockHash:diffResult.baseBlockHash], [self heightForBlockHash:diffResult.blockHash], uint256_hex(diffResult.baseBlockHash), uint256_hex(diffResult.blockHash));
        DSMasternodeList *diffMasternodeList = diffResult.masternodeList;
        UInt256 diffBlockHash = diffMasternodeList.blockHash;
        NSData *diffBlockHashData = uint256_data(diffBlockHash);
        if (![self.quorumRotationService shouldProcessDiffResult:diffResult skipPresenceInRetrieval:YES]) {
            [self.quorumRotationService issueWithMasternodeListFromPeer:peer];
        } else if (![diffResult.neededMissingMasternodeLists count] || ![self.store.masternodeListQueriesNeedingQuorumsValidated containsObject:diffBlockHashData]) {
            [self updateStoreWithMasternodeList:diffMasternodeList addedMasternodes:diffResult.addedMasternodes modifiedMasternodes:diffResult.modifiedMasternodes addedQuorums:diffResult.addedQuorums completion:^(NSError *error) {}];
        }
    }
    for (DSQuorumSnapshot *snapshot in result.snapshotList) {
        [self.store saveQuorumSnapshot:snapshot toChain:self.chain completion:^(NSError * _Nonnull error) {}];
    }
    
    for (DSQuorumEntry *entry in result.lastQuorumPerIndex) {
        [self.store.activeQuorums setObject:entry forKey:uint256_data(entry.llmqQuorumHash)];
    }
}

- (void)processMissingMasternodeLists:(NSOrderedSet *)neededMissingMasternodeLists forMasternodeList:(DSMasternodeList *)masternodeList {
    UInt256 masternodeListBlockHash = masternodeList.blockHash;
    NSData *masternodeListBlockHashData = uint256_data(masternodeListBlockHash);
    self.store.masternodeListAwaitingQuorumValidation = masternodeList;
    NSMutableOrderedSet *neededMasternodeLists = [neededMissingMasternodeLists mutableCopy];
    [neededMasternodeLists addObject:masternodeListBlockHashData]; //also get the current one again
    [self getMasternodeListsForBlockHashes:neededMasternodeLists];
}

- (void)updateStoreWithMasternodeList:(DSMasternodeList *)masternodeList addedMasternodes:(NSDictionary *)addedMasternodes modifiedMasternodes:(NSDictionary *)modifiedMasternodes addedQuorums:(NSDictionary *)addedQuorums completion:(void (^)(NSError *error))completion {
    UInt256 masternodeListBlockHash = masternodeList.blockHash;
    if (uint256_eq(self.store.masternodeListAwaitingQuorumValidation.blockHash, masternodeListBlockHash)) {
        self.store.masternodeListAwaitingQuorumValidation = nil;
    }
//    NSData *blockHashData = uint256_data(masternodeListBlockHash);
//    DSLog(@"•••• store (%d) masternode list at: %u: %@", [self.store hasMasternodeListAt:blockHashData], [self heightForBlockHash:masternodeListBlockHash], uint256_hex(masternodeListBlockHash));
    
//    if ([self.store hasMasternodeListAt:blockHashData]) {
//         in rare race conditions this might already exist
//         but also as we can get it from different sources
//         with different quorums verification status
//
//        completion(NULL);
//        return;
//    }
    [self.store saveMasternodeList:masternodeList
                  addedMasternodes:addedMasternodes
               modifiedMasternodes:modifiedMasternodes
                      addedQuorums:addedQuorums
                        completion:^(NSError *error) {
        completion(error);
        if (!error || !([self.masternodeListDiffService retrievalQueueCount] + [self.quorumRotationService retrievalQueueCount])) { //if it is 0 then we most likely have wiped chain info
            return;
        }
        [self wipeMasternodeInfo];
        dispatch_async(self.chain.networkingQueue, ^{
            [self getRecentMasternodeList];
        });
    }];

}

- (void)peer:(DSPeer *)peer relayedMasternodeDiffMessage:(NSData *)message {
    DSLog(@"•••• -> received mnlistdiff: %@", uint256_hex(message.SHA256));
    self.masternodeListDiffService.timedOutAttempt = 0;
    dispatch_async(self.processingQueue, ^{
        dispatch_group_enter(self.processingGroup);
        DSMasternodeProcessorContext *ctx = [self createDiffMessageContext:self.chain.isTestnet isFromSnapshot:NO isDIP0024:NO peer:peer merkleRootLookup:^UInt256(UInt256 blockHash) {
            DSBlock *lastBlock = [self lastBlockForBlockHash:blockHash fromPeer:peer];
            if (!lastBlock) {
                [self.masternodeListDiffService issueWithMasternodeListFromPeer:peer];
                DSLog(@"Last Block missing");
                return UINT256_ZERO;
            }
            return lastBlock.merkleRoot;
        }];
        [self processMasternodeDiffWith:message context:ctx completion:^(DSMnDiffProcessingResult * _Nonnull result) {
            UInt256 baseBlockHash = result.baseBlockHash;
            UInt256 blockHash = result.blockHash;
            DSLog(@"•••• -> processed mnlistdiff %u..%u %@ .. %@", [self heightForBlockHash:baseBlockHash], [self heightForBlockHash:blockHash], uint256_hex(baseBlockHash), uint256_hex(blockHash));
        #if SAVE_MASTERNODE_DIFF_TO_FILE
            NSString *fileName = [NSString stringWithFormat:@"MNL_%@_%@.dat", @([self heightForBlockHash:baseBlockHash]), @([self heightForBlockHash:blockHash])];
            DSLog(@"•-• File %@ saved", fileName);
            [message saveToFile:fileName inDirectory:NSCachesDirectory];
        #endif
            if (result.errorStatus) {
                DSLog(@"Processing status: %ul", result.errorStatus);
                dispatch_group_leave(self.processingGroup);
                return;
            }
            [self processMasternodeListDiffResult:result forPeer:peer skipPresenceInRetrieval:NO completion:^{
                dispatch_group_leave(self.processingGroup);
            }];
        }];
    });
}

- (void)peer:(DSPeer *)peer relayedQuorumRotationInfoMessage:(NSData *)message {
    DSLog(@"•••• -> received qrinfo: %@", uint256_hex(message.SHA256));
    self.quorumRotationService.timedOutAttempt = 0;
    dispatch_async(self.processingQueue, ^{
        dispatch_group_enter(self.processingGroup);
        MerkleRootFinder merkleRootLookup = ^UInt256(UInt256 blockHash) {
            DSBlock *lastBlock = [self lastBlockForBlockHash:blockHash fromPeer:peer];
            if (!lastBlock) {
                [self.quorumRotationService issueWithMasternodeListFromPeer:peer];
                DSLog(@"Last Block missing");
                return UINT256_ZERO;
            }
            return lastBlock.merkleRoot;
        };
        DSMasternodeProcessorContext *ctx = [self createDiffMessageContext:self.chain.isTestnet isFromSnapshot:NO isDIP0024:YES peer:peer merkleRootLookup:merkleRootLookup];
        [self processQRInfoWith:message context:ctx completion:^(DSQRInfoProcessingResult * _Nonnull result) {
            if (result.errorStatus) {
                DSLog(@"•••• Processing status: %u", result.errorStatus);
                dispatch_group_leave(self.processingGroup);
                return;
            }
            UInt256 baseBlockHash = result.mnListDiffResultAtTip.baseBlockHash;
            UInt256 blockHash = result.mnListDiffResultAtTip.blockHash;
            DSLog(@"•••• -> processed qrinfo tip %u..%u %@ .. %@", [self heightForBlockHash:baseBlockHash], [self heightForBlockHash:blockHash], uint256_hex(baseBlockHash), uint256_hex(blockHash));
            DSLog(@"•••• -> processed qrinfo h %u..%u %@ .. %@", [self heightForBlockHash:result.mnListDiffResultAtH.baseBlockHash], [self heightForBlockHash:result.mnListDiffResultAtH.blockHash], uint256_hex(result.mnListDiffResultAtH.baseBlockHash), uint256_hex(result.mnListDiffResultAtH.blockHash));
            DSLog(@"•••• -> processed qrinfo h-c %u..%u %@ .. %@", [self heightForBlockHash:result.mnListDiffResultAtHC.baseBlockHash], [self heightForBlockHash:result.mnListDiffResultAtHC.blockHash], uint256_hex(result.mnListDiffResultAtHC.baseBlockHash), uint256_hex(result.mnListDiffResultAtHC.blockHash));
            DSLog(@"•••• -> processed qrinfo h-2c %u..%u %@ .. %@", [self heightForBlockHash:result.mnListDiffResultAtH2C.baseBlockHash], [self heightForBlockHash:result.mnListDiffResultAtH2C.blockHash], uint256_hex(result.mnListDiffResultAtH2C.baseBlockHash), uint256_hex(result.mnListDiffResultAtH2C.blockHash));
            DSLog(@"•••• -> processed qrinfo h-3c %u..%u %@ .. %@", [self heightForBlockHash:result.mnListDiffResultAtH3C.baseBlockHash], [self heightForBlockHash:result.mnListDiffResultAtH3C.blockHash], uint256_hex(result.mnListDiffResultAtH3C.baseBlockHash), uint256_hex(result.mnListDiffResultAtH3C.blockHash));
            if (result.extraShare) {
                DSLog(@"•••• -> processed qrinfo h-4c %u..%u %@ .. %@", [self heightForBlockHash:result.mnListDiffResultAtH4C.baseBlockHash], [self heightForBlockHash:result.mnListDiffResultAtH4C.blockHash], uint256_hex(result.mnListDiffResultAtH4C.baseBlockHash), uint256_hex(result.mnListDiffResultAtH4C.blockHash));
            }
    #if SAVE_MASTERNODE_DIFF_TO_FILE
            NSString *fileName = [NSString stringWithFormat:@"QRINFO_%@_%@.dat", @([self heightForBlockHash:baseBlockHash]), @([self heightForBlockHash:blockHash])];
            DSLog(@"•-• File %@ saved", fileName);
            [message saveToFile:fileName inDirectory:NSCachesDirectory];
    #endif
            [self processQRInfoResult:result forPeer:peer completion:^{
                dispatch_group_leave(self.processingGroup);
            }];
        }];
    });
}

- (DSMasternodeProcessorContext *)createDiffMessageContext:(BOOL)useInsightAsBackup isFromSnapshot:(BOOL)isFromSnapshot isDIP0024:(BOOL)isDIP0024 peer:(DSPeer *_Nullable)peer merkleRootLookup:(MerkleRootFinder)merkleRootLookup {
    DSMasternodeProcessorContext *mndiffContext = [[DSMasternodeProcessorContext alloc] init];
    [mndiffContext setUseInsightAsBackup:useInsightAsBackup];
    [mndiffContext setIsFromSnapshot:isFromSnapshot];
    [mndiffContext setIsDIP0024:isDIP0024];
    [mndiffContext setChain:self.chain];
    [mndiffContext setPeer:peer];
    [mndiffContext setMasternodeListLookup:^DSMasternodeList *(UInt256 blockHash) {
        return [self masternodeListForBlockHash:blockHash withBlockHeightLookup:nil];
    }];
    [mndiffContext setBlockHeightLookup:^uint32_t(UInt256 blockHash) {
        return [self heightForBlockHash:blockHash];
    }];
    [mndiffContext setMerkleRootLookup:merkleRootLookup];
    return mndiffContext;
}

- (BOOL)hasMasternodeListCurrentlyBeingSaved {
    return [self.store hasMasternodeListCurrentlyBeingSaved];
}

+ (void)saveMasternodeList:(DSMasternodeList *)masternodeList toChain:(DSChain *)chain havingModifiedMasternodes:(NSDictionary *)modifiedMasternodes addedQuorums:(NSDictionary *)addedQuorums createUnknownBlocks:(BOOL)createUnknownBlocks inContext:(NSManagedObjectContext *)context completion:(void (^)(NSError *error))completion {
    [DSMasternodeListStore saveMasternodeList:masternodeList toChain:chain havingModifiedMasternodes:modifiedMasternodes addedQuorums:addedQuorums createUnknownBlocks:createUnknownBlocks inContext:context completion:completion];
}

// MARK: - Quorums

- (DSQuorumEntry *)quorumEntryForChainLockRequestID:(UInt256)requestID withBlockHeightOffset:(uint32_t)blockHeightOffset {
    DSMerkleBlock *merkleBlock = [self.chain blockFromChainTip:blockHeightOffset];
    return [self quorumEntryForChainLockRequestID:requestID forMerkleBlock:merkleBlock];
}

- (DSQuorumEntry *)quorumEntryForChainLockRequestID:(UInt256)requestID forBlockHeight:(uint32_t)blockHeight {
    DSMerkleBlock *merkleBlock = [self.chain blockAtHeight:blockHeight];
    return [self quorumEntryForChainLockRequestID:requestID forMerkleBlock:merkleBlock];
}

- (DSQuorumEntry *)quorumEntryForChainLockRequestID:(UInt256)requestID forMerkleBlock:(DSMerkleBlock *)merkleBlock {
    return [self.store quorumEntryForChainLockRequestID:requestID forMerkleBlock:merkleBlock];
}

- (DSQuorumEntry *)quorumEntryForInstantSendRequestID:(UInt256)requestID withBlockHeightOffset:(uint32_t)blockHeightOffset {
    return [self.store quorumEntryForInstantSendRequestID:requestID forMerkleBlock:[self.chain blockFromChainTip:blockHeightOffset]];
}

- (DSQuorumEntry *)quorumEntryForPlatformHavingQuorumHash:(UInt256)quorumHash forBlockHeight:(uint32_t)blockHeight {
    return [self.store quorumEntryForPlatformHavingQuorumHash:quorumHash forBlockHeight:blockHeight];
}

// MARK: - Meta information

- (void)checkPingTimesForCurrentMasternodeListInContext:(NSManagedObjectContext *)context withCompletion:(void (^)(NSMutableDictionary<NSData *, NSNumber *> *pingTimes, NSMutableDictionary<NSData *, NSError *> *errors))completion {
    __block NSArray<DSSimplifiedMasternodeEntry *> *entries = self.currentMasternodeList.simplifiedMasternodeEntries;
    [self.chain.chainManager.DAPIClient checkPingTimesForMasternodes:entries
                                                          completion:^(NSMutableDictionary<NSData *, NSNumber *> *_Nonnull pingTimes, NSMutableDictionary<NSData *, NSError *> *_Nonnull errors) {
        [self.store savePlatformPingInfoForEntries:entries inContext:context];
        if (completion != nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(pingTimes, errors);
            });
        }
    }];

}

@end
