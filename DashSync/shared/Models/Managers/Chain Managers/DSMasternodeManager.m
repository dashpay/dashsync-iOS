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
#import "DSAddressEntity+CoreDataProperties.h"
#import "DSBLSKey.h"
#import "DSChain+Protected.h"
#import "DSChainEntity+CoreDataProperties.h"
#import "DSChainManager+Protected.h"
#import "DSCheckpoint.h"
#import "DSDAPIClient.h"
#import "DSDerivationPath.h"
#import "DSInsightManager.h"
#import "DSLocalMasternode+Protected.h"
#import "DSLocalMasternodeEntity+CoreDataClass.h"
#import "DSMasternodeDiffMessageContext.h"
#import "DSMasternodeList.h"
#import "DSMasternodeListEntity+CoreDataClass.h"
#import "DSMasternodeManager+Mndiff.h"
#import "DSMasternodeStore.h"
#import "DSMasternodeStore+Protected.h"
#import "DSMerkleBlock.h"
#import "DSMerkleBlockEntity+CoreDataClass.h"
#import "DSMutableOrderedDataKeyDictionary.h"
#import "DSOptionsManager.h"
#import "DSPeer.h"
#import "DSPeerManager+Protected.h"
#import "DSPeerManager.h"
#import "DSProviderRegistrationTransaction.h"
#import "DSProviderRegistrationTransactionEntity+CoreDataClass.h"
#import "DSQuorumEntry.h"
#import "DSQuorumEntryEntity+CoreDataClass.h"
#import "DSSimplifiedMasternodeEntry.h"
#import "DSSimplifiedMasternodeEntryEntity+CoreDataClass.h"
#import "DSTransactionFactory.h"
#import "DSTransactionManager+Protected.h"
#import "NSArray+Dash.h"
#import "NSData+Dash.h"
#import "NSData+DSHash.h"
#import "NSDictionary+Dash.h"
#import "NSManagedObject+Sugar.h"
#import "NSMutableData+Dash.h"
#import "NSSet+Dash.h"
#import "NSString+Bitcoin.h"
#import "dash_shared_core.h"

#define FAULTY_DML_MASTERNODE_PEERS @"FAULTY_DML_MASTERNODE_PEERS"
#define CHAIN_FAULTY_DML_MASTERNODE_PEERS [NSString stringWithFormat:@"%@_%@", peer.chain.uniqueID, FAULTY_DML_MASTERNODE_PEERS]
#define MAX_FAULTY_DML_PEERS 2

#define LOG_MASTERNODE_DIFF (0 && DEBUG)
#define KEEP_OLD_QUORUMS 0
#define SAVE_MASTERNODE_DIFF_TO_FILE (0 && DEBUG)
#define DSFullLog(FORMAT, ...) printf("%s\n", [[NSString stringWithFormat:FORMAT, ##__VA_ARGS__] UTF8String])


@interface DSMasternodeManager ()

@property (nonatomic, strong) DSChain *chain;
@property (nonatomic, strong) DSMasternodeStore *store;
@property (nonatomic, strong) DSMasternodeList *masternodeListAwaitingQuorumValidation;
@property (nonatomic, strong) NSMutableSet *masternodeListQueriesNeedingQuorumsValidated;
@property (nonatomic, assign) UInt256 lastQueriedBlockHash; //last by height, not by time queried
@property (nonatomic, strong) NSData *processingMasternodeListDiffHashes;
@property (nonatomic, strong) NSMutableDictionary<NSData *, DSLocalMasternode *> *localMasternodesDictionaryByRegistrationTransactionHash;
@property (nonatomic, strong) NSMutableOrderedSet<NSData *> *masternodeListRetrievalQueue;
@property (nonatomic, assign) NSUInteger masternodeListRetrievalQueueMaxAmount;
@property (nonatomic, strong) NSMutableSet<NSData *> *masternodeListsInRetrieval;
@property (nonatomic, assign) NSTimeInterval timeIntervalForMasternodeRetrievalSafetyDelay;
@property (nonatomic, assign) uint16_t timedOutAttempt;
@property (nonatomic, assign) uint16_t timeOutObserverTry;

@end

@implementation DSMasternodeManager

- (void)blockUntilAddInsight:(UInt256)entryQuorumHash {
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    [[DSInsightManager sharedInstance] blockForBlockHash:uint256_reverse(entryQuorumHash)
                                                 onChain:self.chain
                                              completion:^(DSBlock *_Nullable block, NSError *_Nullable error) {
                                                  if (!error && block) {
                                                      [self.chain addInsightVerifiedBlock:block forBlockHash:entryQuorumHash];
                                                  }
                                                  dispatch_semaphore_signal(sem);
                                              }];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
}

- (DSMasternodeList *)currentMasternodeList {
    return [self.store currentMasternodeList];
}

- (instancetype)initWithChain:(DSChain *)chain {
    NSParameterAssert(chain);

    if (!(self = [super init])) return nil;
    _chain = chain;
    _masternodeListRetrievalQueue = [NSMutableOrderedSet orderedSet];
    _masternodeListsInRetrieval = [NSMutableSet set];
    _masternodeListQueriesNeedingQuorumsValidated = [NSMutableSet set];
    _localMasternodesDictionaryByRegistrationTransactionHash = [NSMutableDictionary dictionary];
    _testingMasternodeListRetrieval = NO;
    self.store = [[DSMasternodeStore alloc] initWithChain:chain];
    self.lastQueriedBlockHash = UINT256_ZERO;
    self.processingMasternodeListDiffHashes = nil;
    _timedOutAttempt = 0;
    _timeOutObserverTry = 0;
    return self;
}

// MARK: - Helpers

- (DSPeerManager *)peerManager {
    return self.chain.chainManager.peerManager;
}

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

- (NSUInteger)simplifiedMasternodeEntryCount {
    return [self.currentMasternodeList masternodeCount];
}

- (NSUInteger)activeQuorumsCount {
    return self.currentMasternodeList.quorumsCount;
}

- (DSSimplifiedMasternodeEntry *)masternodeHavingProviderRegistrationTransactionHash:(NSData *)providerRegistrationTransactionHash {
    NSParameterAssert(providerRegistrationTransactionHash);

    return [self.currentMasternodeList.simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash objectForKey:providerRegistrationTransactionHash];
}

- (BOOL)hasMasternodeAtLocation:(UInt128)IPAddress port:(uint32_t)port {
    DSSimplifiedMasternodeEntry *simplifiedMasternodeEntry = [self.store simplifiedMasternodeEntryForLocation:IPAddress port:port];
    return (!!simplifiedMasternodeEntry);
}

- (NSUInteger)masternodeListRetrievalQueueCount {
    return self.masternodeListRetrievalQueue.count;
}

- (uint32_t)estimatedMasternodeListsToSync {
    BOOL syncMasternodeLists = ([[DSOptionsManager sharedInstance] syncType] & DSSyncType_MasternodeList);
    if (!syncMasternodeLists) {
        return 0;
    }
    double amountLeft = self.masternodeListRetrievalQueue.count;
    double maxAmount = self.masternodeListRetrievalQueueMaxAmount;
    double masternodeListsCount = self.store.masternodeListsByBlockHash.count;
    if (!maxAmount || masternodeListsCount <= 1) { //1 because there might be a default
        if (self.lastMasternodeListBlockHeight == UINT32_MAX) {
            return 32;
        } else {
            float diff = self.chain.estimatedBlockHeight - self.lastMasternodeListBlockHeight;
            if (diff < 0) return 32;
            return MIN(32, (uint32_t)ceil(diff / 24.0f));
        }
    }
    return amountLeft;
}

- (double)masternodeListAndQuorumsSyncProgress {
    double amountLeft = self.masternodeListRetrievalQueue.count;
    double maxAmount = self.masternodeListRetrievalQueueMaxAmount;
    if (!amountLeft) {
        if (self.lastMasternodeListBlockHeight == UINT32_MAX || self.lastMasternodeListBlockHeight < self.chain.estimatedBlockHeight - 16) {
            return 0;
        } else {
            return 1;
        }
    }
    double progress = MAX(MIN((maxAmount - amountLeft) / maxAmount, 1), 0);
    return progress;
}

- (BOOL)currentMasternodeListIsInLast24Hours {
    return [self.store currentMasternodeListIsInLast24Hours];
}


// MARK: - Set Up and Tear Down

- (void)setUp {
    [self.store deleteEmptyMasternodeLists]; //this is just for sanity purposes
    [self loadMasternodeListsWithBlockHeightLookup:nil];
    [self.store removeOldSimplifiedMasternodeEntries];
    [self.store loadLocalMasternodes];
    [self loadFileDistributedMasternodeLists];
}

- (void)reloadMasternodeLists {
    [self reloadMasternodeListsWithBlockHeightLookup:nil];
}

- (void)reloadMasternodeListsWithBlockHeightLookup:(BlockHeightFinder)blockHeightLookup {
    [self.store removeAllMasternodeLists];
    self.currentMasternodeList = nil;
    [self loadMasternodeListsWithBlockHeightLookup:blockHeightLookup];
}

- (void)loadMasternodeListsWithBlockHeightLookup:(BlockHeightFinder)blockHeightLookup {
    [self.store loadMasternodeListsWithBlockHeightLookup:blockHeightLookup];
}

- (void)setCurrentMasternodeList:(DSMasternodeList *)currentMasternodeList {
    [self.store setCurrentMasternodeList:currentMasternodeList];
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
    if (checkpoint &&
        self.chain.lastTerminalBlockHeight >= checkpoint.height &&
        ![self masternodeListForBlockHash:checkpoint.blockHash])
        [self processRequestFromFileForBlockHash:checkpoint.blockHash
                                      completion:^(BOOL success, DSMasternodeList *masternodeList) {
            if (success && masternodeList) {
                self.currentMasternodeList = masternodeList;
            }
        }];
}

- (DSMasternodeList *)loadMasternodeListAtBlockHash:(NSData *)blockHash withBlockHeightLookup:(BlockHeightFinder)blockHeightLookup {
    return [self.store loadMasternodeListAtBlockHash:blockHash withBlockHeightLookup:blockHeightLookup];
}

- (void)wipeMasternodeInfo {
    [self.store removeAllMasternodeLists];
    [self.localMasternodesDictionaryByRegistrationTransactionHash removeAllObjects];
    self.currentMasternodeList = nil;
    self.masternodeListAwaitingQuorumValidation = nil;
    [self.masternodeListRetrievalQueue removeAllObjects];
    [self.masternodeListsInRetrieval removeAllObjects];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DSMasternodeListDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey: self.chain}];
        [[NSNotificationCenter defaultCenter] postNotificationName:DSQuorumListDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey: self.chain}];
    });
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

- (void)addToMasternodeRetrievalQueue:(NSData *)masternodeBlockHashData {
    NSAssert(uint256_is_not_zero(masternodeBlockHashData.UInt256), @"the hash data must not be empty");
    [self.masternodeListRetrievalQueue addObject:masternodeBlockHashData];
    self.masternodeListRetrievalQueueMaxAmount = MAX(self.masternodeListRetrievalQueueMaxAmount, self.masternodeListRetrievalQueue.count);
    [self.masternodeListRetrievalQueue sortUsingComparator:^NSComparisonResult(id _Nonnull obj1, id _Nonnull obj2) {
        NSData *obj1BlockHash = (NSData *)obj1;
        NSData *obj2BlockHash = (NSData *)obj2;
        if ([self heightForBlockHash:obj1BlockHash.UInt256] < [self heightForBlockHash:obj2BlockHash.UInt256]) {
            return NSOrderedAscending;
        } else {
            return NSOrderedDescending;
        }
    }];
}

- (void)addToMasternodeRetrievalQueueArray:(NSArray *)masternodeBlockHashDataArray {
    NSMutableArray *nonEmptyBlockHashes = [NSMutableArray array];
    for (NSData *blockHashData in masternodeBlockHashDataArray) {
        NSAssert(uint256_is_not_zero(blockHashData.UInt256), @"We should not be adding an empty block hash");
        if (uint256_is_not_zero(blockHashData.UInt256)) {
            [nonEmptyBlockHashes addObject:blockHashData];
        }
    }
    [self.masternodeListRetrievalQueue addObjectsFromArray:nonEmptyBlockHashes];
    self.masternodeListRetrievalQueueMaxAmount = MAX(self.masternodeListRetrievalQueueMaxAmount, self.masternodeListRetrievalQueue.count);
    [self.masternodeListRetrievalQueue sortUsingComparator:^NSComparisonResult(id _Nonnull obj1, id _Nonnull obj2) {
        NSData *obj1BlockHash = (NSData *)obj1;
        NSData *obj2BlockHash = (NSData *)obj2;
        if ([self heightForBlockHash:obj1BlockHash.UInt256] < [self heightForBlockHash:obj2BlockHash.UInt256]) {
            return NSOrderedAscending;
        } else {
            return NSOrderedDescending;
        }
    }];
}

- (void)startTimeOutObserver {
    __block NSSet *masternodeListsInRetrieval = [self.masternodeListsInRetrieval copy];
    __block NSUInteger masternodeListCount = [self knownMasternodeListsCount];
    self.timeOutObserverTry++;
    __block uint16_t timeOutObserverTry = self.timeOutObserverTry;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20 * (self.timedOutAttempt + 1) * NSEC_PER_SEC)), self.chain.networkingQueue, ^{
        if (![self.masternodeListRetrievalQueue count]) return;
        if (self.timeOutObserverTry != timeOutObserverTry) return;
        NSMutableSet *leftToGet = [masternodeListsInRetrieval mutableCopy];
        [leftToGet intersectSet:self.masternodeListsInRetrieval];
        if (self.processingMasternodeListDiffHashes) {
            [leftToGet removeObject:self.processingMasternodeListDiffHashes];
        }
        if ((masternodeListCount == [self knownMasternodeListsCount]) && [masternodeListsInRetrieval isEqualToSet:leftToGet]) {
            //Nothing has changed
            DSLog(@"TimedOut");
            //timeout
            self.timedOutAttempt++;
            [self.peerManager.downloadPeer disconnect];
            [self.masternodeListsInRetrieval removeAllObjects];
            [self dequeueMasternodeListRequest];
        } else {
            [self startTimeOutObserver];
        }
    });
}

- (void)dequeueMasternodeListRequest {
    DSLog(@"Dequeued Masternode List Request");
    if (![self.masternodeListRetrievalQueue count]) {
        DSLog(@"No masternode lists in retrieval");
        [self.chain.chainManager chainFinishedSyncingMasternodeListsAndQuorums:self.chain];
        return;
    }
    if ([self.masternodeListsInRetrieval count]) {
        DSLog(@"A masternode list is already in retrieval");
        return;
    }
    if (!self.peerManager.downloadPeer || (self.peerManager.downloadPeer.status != DSPeerStatus_Connected)) {
        if (self.chain.chainManager.syncPhase != DSChainSyncPhase_Offline) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), self.chain.networkingQueue, ^{
                [self dequeueMasternodeListRequest];
            });
        }
        return;
    }
    NSMutableOrderedSet<NSData *> *masternodeListsToRetrieve = [self.masternodeListRetrievalQueue mutableCopy];
    for (NSData *blockHashData in masternodeListsToRetrieve) {
        NSUInteger pos = [masternodeListsToRetrieve indexOfObject:blockHashData];
        UInt256 blockHash = blockHashData.UInt256;
        //we should check the associated block still exists
        __block BOOL hasBlock = ([self.chain blockForBlockHash:blockHash] != nil);
        if (!hasBlock) {
            hasBlock = [self.store hasBlocksWithHash:blockHash];
        }
        if (!hasBlock && self.chain.isTestnet) {
            //We can trust insight if on testnet
            [self blockUntilAddInsight:blockHash];
            hasBlock = !![[self.chain insightVerifiedBlocksByHashDictionary] objectForKey:uint256_data(blockHash)];
        }
        if (hasBlock) {
            //there is the rare possibility we have the masternode list as a checkpoint, so lets first try that
            [self processRequestFromFileForBlockHash:blockHash
                                          completion:^(BOOL success, DSMasternodeList *masternodeList) {
                if (success) {
                    //we already had it
                    [self.masternodeListRetrievalQueue removeObject:uint256_data(blockHash)];
                    return;
                }
                //we need to go get it
                UInt256 previousMasternodeAlreadyKnownBlockHash = [self.store closestKnownBlockHashForBlockHash:blockHash];
                UInt256 previousMasternodeInQueueBlockHash = (pos ? [masternodeListsToRetrieve objectAtIndex:pos - 1].UInt256 : UINT256_ZERO);
                uint32_t previousMasternodeAlreadyKnownHeight = [self heightForBlockHash:previousMasternodeAlreadyKnownBlockHash];
                uint32_t previousMasternodeInQueueHeight = (pos ? [self heightForBlockHash:previousMasternodeInQueueBlockHash] : UINT32_MAX);
                UInt256 previousBlockHash = pos ? (previousMasternodeAlreadyKnownHeight > previousMasternodeInQueueHeight ? previousMasternodeAlreadyKnownBlockHash : previousMasternodeInQueueBlockHash) : previousMasternodeAlreadyKnownBlockHash;
                DSLog(@"Requesting masternode list and quorums from %u to %u (%@ to %@)", [self heightForBlockHash:previousBlockHash], [self heightForBlockHash:blockHash], uint256_reverse_hex(previousBlockHash), uint256_reverse_hex(blockHash));
                NSAssert(([self heightForBlockHash:previousBlockHash] != UINT32_MAX) || uint256_is_zero(previousBlockHash), @"This block height should be known");
                if ([self.chain hasDIP0024Enabled]) {
                    // TODO: optimize qrinfo request queue (up to 4 blocks simultaneously, so we'd make masternodeListsToRetrieve.count%4)
                    NSArray<NSData *> *baseBlockHashes = @[[NSData dataWithUInt256:previousBlockHash]];
                    [self.peerManager.downloadPeer sendGetQuorumRotationInfoForBaseBlockHashes:baseBlockHashes forBlockHash:blockHash];
                } else {
                    [self.peerManager.downloadPeer sendGetMasternodeListFromPreviousBlockHash:previousBlockHash forBlockHash:blockHash];
                }
                UInt512 concat = uint512_concat(previousBlockHash, blockHash);
                [self.masternodeListsInRetrieval addObject:uint512_data(concat)];
            }];
        } else {
            DSLog(@"Missing block (%@)", uint256_reverse_hex(blockHash));
            [self.masternodeListRetrievalQueue removeObject:uint256_data(blockHash)];
        }
    }
    [self startTimeOutObserver];
}

- (void)getRecentMasternodeList:(NSUInteger)blocksAgo withSafetyDelay:(uint32_t)safetyDelay {
    @synchronized(self.masternodeListRetrievalQueue) {
        DSMerkleBlock *merkleBlock = [self.chain blockFromChainTip:blocksAgo];
        if ([self.masternodeListRetrievalQueue lastObject] && uint256_eq(merkleBlock.blockHash, [self.masternodeListRetrievalQueue lastObject].UInt256)) {
            //we are asking for the same as the last one
            return;
        }
        NSData *blockHash = uint256_data(merkleBlock.blockHash);
        if ([self.store.masternodeListsByBlockHash.allKeys containsObject:blockHash]) {
            DSLog(@"Already have that masternode list %u", merkleBlock.height);
            return;
        }
        if ([self.store.masternodeListsBlockHashStubs containsObject:blockHash]) {
            DSLog(@"Already have that masternode list in stub %u", merkleBlock.height);
            return;
        }
        self.lastQueriedBlockHash = merkleBlock.blockHash;
        [self.masternodeListQueriesNeedingQuorumsValidated addObject:uint256_data(merkleBlock.blockHash)];
        DSLog(@"Getting masternode list %u", merkleBlock.height);
        BOOL emptyRequestQueue = ![self.masternodeListRetrievalQueue count];
        [self addToMasternodeRetrievalQueue:uint256_data(merkleBlock.blockHash)];
        if (emptyRequestQueue) {
            [self dequeueMasternodeListRequest];
        }
    }
}

- (void)getCurrentMasternodeListWithSafetyDelay:(uint32_t)safetyDelay {
    if (safetyDelay) {
        //the safety delay checks to see if this was called in the last n seconds.
        self.timeIntervalForMasternodeRetrievalSafetyDelay = [[NSDate date] timeIntervalSince1970];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(safetyDelay * NSEC_PER_SEC)), self.chain.networkingQueue, ^{
            NSTimeInterval timeElapsed = [[NSDate date] timeIntervalSince1970] - self.timeIntervalForMasternodeRetrievalSafetyDelay;
            if (timeElapsed > safetyDelay) {
                [self getCurrentMasternodeListWithSafetyDelay:0];
            }
        });
    } else {
        [self getRecentMasternodeList:0 withSafetyDelay:safetyDelay];
    }
}

- (void)getMasternodeListsForBlockHashes:(NSOrderedSet *)blockHashes {
    @synchronized(self.masternodeListRetrievalQueue) {
        NSArray *orderedBlockHashes = [blockHashes sortedArrayUsingComparator:^NSComparisonResult(NSData *_Nonnull obj1, NSData *_Nonnull obj2) {
            uint32_t height1 = [self heightForBlockHash:obj1.UInt256];
            uint32_t height2 = [self heightForBlockHash:obj2.UInt256];
            return (height1 > height2) ? NSOrderedDescending : NSOrderedAscending;
        }];
        for (NSData *blockHash in orderedBlockHashes) {
            DSLog(@"adding retrieval of masternode list at height %u to queue (%@)", [self heightForBlockHash:blockHash.UInt256], blockHash.reverse.hexString);
        }
        [self addToMasternodeRetrievalQueueArray:orderedBlockHashes];
    }
}

- (BOOL)requestMasternodeListForBlockHeight:(uint32_t)blockHeight error:(NSError **)error {
    DSMerkleBlock *merkleBlock = [self.chain blockAtHeight:blockHeight];
    if (!merkleBlock) {
        if (error) {
            *error = [NSError errorWithDomain:@"DashSync" code:600 userInfo:@{NSLocalizedDescriptionKey: @"Unknown block"}];
        }
        return FALSE;
    }
    [self requestMasternodeListForBlockHash:merkleBlock.blockHash];
    return TRUE;
}

- (BOOL)requestMasternodeListForBlockHash:(UInt256)blockHash {
    self.lastQueriedBlockHash = blockHash;
    [self.masternodeListQueriesNeedingQuorumsValidated addObject:uint256_data(blockHash)];
    //this is safe
    [self getMasternodeListsForBlockHashes:[NSOrderedSet orderedSetWithObject:uint256_data(blockHash)]];
    [self dequeueMasternodeListRequest];
    return TRUE;
}

// MARK: - Deterministic Masternode List Sync

- (void)processRequestFromFileForBlockHash:(UInt256)blockHash completion:(void (^)(BOOL success, DSMasternodeList *masternodeList))completion {
    DSCheckpoint *checkpoint = [self.chain checkpointForBlockHash:blockHash];
    if (!checkpoint || !checkpoint.masternodeListName || [checkpoint.masternodeListName isEqualToString:@""]) {
        DSLog(@"No masternode list checkpoint found at height %u", [self heightForBlockHash:blockHash]);
        completion(NO, nil);
        return;
    }
    NSString *bundlePath = [[NSBundle bundleForClass:self.class] pathForResource:@"DashSync" ofType:@"bundle"];
    NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
    NSString *filePath = [bundle pathForResource:checkpoint.masternodeListName ofType:@"dat"];
    if (!filePath) {
        completion(NO, nil);
        return;
    }
    __block DSMerkleBlock *block = [self.chain blockForBlockHash:blockHash];
    NSData *message = [NSData dataWithContentsOfFile:filePath];
    [self processMasternodeDiffMessage:message
                    baseMasternodeList:nil
                             lastBlock:block
                    useInsightAsBackup:NO
                            completion:^(DSMnDiffProcessingResult *result) {
        if (!result.foundCoinbase || !result.rootMNListValid || !result.rootQuorumListValid || !result.validQuorums) {
            completion(NO, nil);
            DSLog(@"Invalid File for block at height %u with merkleRoot %@", block.height, uint256_hex(block.merkleRoot));
            return;
        }
        //valid Coinbase might be false if no merkle block
        if (block && !result.validCoinbase) {
            DSLog(@"Invalid Coinbase for block at height %u with merkleRoot %@", block.height, uint256_hex(block.merkleRoot));
            completion(NO, nil);
            return;
        }
        DSMasternodeList *masternodeList = result.masternodeList;
        [self.store updateMasternodeList:masternodeList addedMasternodes:result.addedMasternodes modifiedMasternodes:result.modifiedMasternodes addedQuorums:result.addedQuorums completion:^(NSError * _Nonnull error) {
            if (!KEEP_OLD_QUORUMS && uint256_eq(self.lastQueriedBlockHash, masternodeList.blockHash)) {
                [self removeOldMasternodeLists];
            }
            if (![self.masternodeListRetrievalQueue count]) {
                [self.chain.chainManager.transactionManager checkWaitingForQuorums];
            }
            completion(YES, masternodeList);
        }];
    }];
}

- (void)processMasternodeDiffMessage:(NSData *)message baseMasternodeList:(DSMasternodeList *)baseMasternodeList lastBlock:(DSBlock *)lastBlock useInsightAsBackup:(BOOL)useInsightAsBackup completion:(void (^)(DSMnDiffProcessingResult *result))completion {
    DSMasternodeDiffMessageContext *mndiffContext = [[DSMasternodeDiffMessageContext alloc] init];
    [mndiffContext setBaseMasternodeList:baseMasternodeList];
    [mndiffContext setLastBlock:(DSMerkleBlock *)lastBlock];
    [mndiffContext setUseInsightAsBackup:useInsightAsBackup];
    [mndiffContext setChain:self.chain];
    [mndiffContext setMasternodeListLookup:^DSMasternodeList *(UInt256 blockHash) {
        return [self masternodeListForBlockHash:blockHash];
    }];
    [mndiffContext setBlockHeightLookup:^uint32_t(UInt256 blockHash) {
        return [self heightForBlockHash:blockHash];
    }];
    [DSMasternodeManager processMasternodeDiffMessage:message withContext:mndiffContext completion:completion];
}

- (void)processQRInfoMessage:(NSData *)message baseBlockHashesCount:(uint32_t)baseBlockHashesCount baseMasternodeList:(DSMasternodeList *)baseMasternodeList lastBlock:(DSBlock *)lastBlock useInsightAsBackup:(BOOL)useInsightAsBackup completion:(void (^)(DSMnDiffProcessingResult *result))completion {
    DSMasternodeDiffMessageContext *mndiffContext = [[DSMasternodeDiffMessageContext alloc] init];
    [mndiffContext setBaseMasternodeList:baseMasternodeList];
    [mndiffContext setLastBlock:(DSMerkleBlock *)lastBlock];
    [mndiffContext setUseInsightAsBackup:useInsightAsBackup];
    [mndiffContext setChain:self.chain];
    [mndiffContext setMasternodeListLookup:^DSMasternodeList *(UInt256 blockHash) {
        return [self masternodeListForBlockHash:blockHash];
    }];
    [mndiffContext setBlockHeightLookup:^uint32_t(UInt256 blockHash) {
        return [self heightForBlockHash:blockHash];
    }];
    [DSMasternodeManager processQRInfoMessage:message baseBlockHashesCount:baseBlockHashesCount withContext:mndiffContext completion:completion];
}


- (void)peer:(DSPeer *)peer relayedMasternodeDiffMessage:(NSData *)message {
#if LOG_MASTERNODE_DIFF
    DSFullLog(@"Logging masternode DIFF message %@", message.hexString);
    DSLog(@"Logging masternode DIFF message hash %@", [NSData dataWithUInt256:message.SHA256].hexString);
#endif

    self.timedOutAttempt = 0;
    NSUInteger length = message.length;
    NSUInteger offset = 0;
    if (length - offset < 32) return;
    UInt256 baseBlockHash = [message UInt256AtOffset:offset];
    offset += 32;
    if (length - offset < 32) return;
    UInt256 blockHash = [message UInt256AtOffset:offset];
    offset += 32;

#if SAVE_MASTERNODE_DIFF_TO_FILE
    NSString *fileName = [NSString stringWithFormat:@"MNL_%@_%@.dat", @([self heightForBlockHash:baseBlockHash]), @([self heightForBlockHash:blockHash])];
    [message saveToFile:fileName inDirectory:NSCachesDirectory];
#endif

    NSData *blockHashData = uint256_data(blockHash);
    UInt512 concat = uint512_concat(baseBlockHash, blockHash);
    NSData *blockHashDiffsData = uint512_data(concat);
    if (![self.masternodeListsInRetrieval containsObject:blockHashDiffsData]) {
        NSMutableArray *masternodeListsInRetrievalStrings = [NSMutableArray array];
        for (NSData *masternodeListInRetrieval in self.masternodeListsInRetrieval) {
            [masternodeListsInRetrievalStrings addObject:masternodeListInRetrieval.hexString];
        }
        DSLog(@"A masternode list (%@) was received that is not set to be retrieved (%@)", blockHashDiffsData.hexString, [masternodeListsInRetrievalStrings componentsJoinedByString:@", "]);
        return;
    }
    [self.masternodeListsInRetrieval removeObject:blockHashDiffsData];
    if ([self.store.masternodeListsByBlockHash objectForKey:blockHashData]) {
        //we already have this
        DSLog(@"We already have this masternodeList %@ (%u)", blockHashData.reverse.hexString, [self heightForBlockHash:blockHash]);
        return; //no need to do anything more
    }
    if ([self.store.masternodeListsBlockHashStubs containsObject:blockHashData]) {
        //we already have this
        DSLog(@"We already have a stub for %@ (%u)", blockHashData.reverse.hexString, [self heightForBlockHash:blockHash]);
        return; //no need to do anything more
    }
    DSLog(@"relayed masternode diff with baseBlockHash %@ (%u) blockHash %@ (%u)", uint256_reverse_hex(baseBlockHash), [self heightForBlockHash:baseBlockHash], blockHashData.reverse.hexString, [self heightForBlockHash:blockHash]);
    DSMasternodeList *baseMasternodeList = [self masternodeListForBlockHash:baseBlockHash];
    if (!baseMasternodeList && !uint256_eq(self.chain.genesisHash, baseBlockHash) && uint256_is_not_zero(baseBlockHash)) {
        //this could have been deleted in the meantime, if so rerequest
        [self issueWithMasternodeListFromPeer:peer];
        DSLog(@"No base masternode list");
        return;
    }
    DSBlock *lastBlock = nil;
    if ([self.chain heightForBlockHash:blockHash]) {
        lastBlock = [[peer.chain terminalBlocks] objectForKey:uint256_obj(blockHash)];
        if (!lastBlock && [peer.chain allowInsightBlocksForVerification]) {
            lastBlock = [[peer.chain insightVerifiedBlocksByHashDictionary] objectForKey:uint256_data(blockHash)];
            if (!lastBlock && peer.chain.isTestnet) {
                //We can trust insight if on testnet
                [self blockUntilAddInsight:blockHash];
                lastBlock = [[peer.chain insightVerifiedBlocksByHashDictionary] objectForKey:uint256_data(blockHash)];
            }
        }
    } else {
        lastBlock = [peer.chain recentTerminalBlockForBlockHash:blockHash];
    }
    if (!lastBlock) {
        [self issueWithMasternodeListFromPeer:peer];
        DSLog(@"Last Block missing");
        return;
    }
    self.processingMasternodeListDiffHashes = blockHashDiffsData;
    // We can use insight as backup if we are on testnet, we shouldn't otherwise.
    [self processMasternodeDiffMessage:message
                    baseMasternodeList:baseMasternodeList
                             lastBlock:lastBlock
                    useInsightAsBackup:self.chain.isTestnet
                            completion:^(DSMnDiffProcessingResult *result) {
        DSMasternodeList *masternodeList = result.masternodeList;
        if (![self.masternodeListRetrievalQueue containsObject:uint256_data(masternodeList.blockHash)]) {
            //We most likely wiped data in the meantime
            [self.masternodeListsInRetrieval removeAllObjects];
            [self dequeueMasternodeListRequest];
            return;
        }
        if (result.foundCoinbase && result.validCoinbase && result.rootMNListValid && result.rootQuorumListValid && result.validQuorums) {
            NSOrderedSet *neededMissingMasternodeLists = result.neededMissingMasternodeLists;
            DSLog(@"Valid masternode list found at height %u", [self heightForBlockHash:blockHash]);
            //yay this is the correct masternode list verified deterministically for the given block
            if ([neededMissingMasternodeLists count] &&
                [self.masternodeListQueriesNeedingQuorumsValidated containsObject:uint256_data(blockHash)]) {
                DSLog(@"Last masternode list is missing previous masternode lists for quorum validation");
                self.processingMasternodeListDiffHashes = nil;
                //This is the current one, get more previous masternode lists we need to verify quorums
                self.masternodeListAwaitingQuorumValidation = masternodeList;
                [self.masternodeListRetrievalQueue removeObject:uint256_data(blockHash)];
                NSMutableOrderedSet *neededMasternodeLists = [neededMissingMasternodeLists mutableCopy];
                [neededMasternodeLists addObject:uint256_data(blockHash)]; //also get the current one again
                [self getMasternodeListsForBlockHashes:neededMasternodeLists];
                [self dequeueMasternodeListRequest];
            } else {
                [self processValidMasternodeList:masternodeList havingAddedMasternodes:result.addedMasternodes modifiedMasternodes:result.modifiedMasternodes addedQuorums:result.addedQuorums];
                NSAssert([self.masternodeListRetrievalQueue containsObject:uint256_data(masternodeList.blockHash)], @"This should still be here");
                self.processingMasternodeListDiffHashes = nil;
                [self.masternodeListRetrievalQueue removeObject:uint256_data(masternodeList.blockHash)];
                [self dequeueMasternodeListRequest];
                //check for instant send locks that were awaiting a quorum
                if (![self.masternodeListRetrievalQueue count]) {
                    [self.chain.chainManager.transactionManager checkWaitingForQuorums];
                }
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:CHAIN_FAULTY_DML_MASTERNODE_PEERS];
            }
        } else {
            if (!result.foundCoinbase) DSLog(@"Did not find coinbase at height %u", [self heightForBlockHash:blockHash]);
            if (!result.validCoinbase) DSLog(@"Coinbase not valid at height %u", [self heightForBlockHash:blockHash]);
            if (!result.rootMNListValid) DSLog(@"rootMNListValid not valid at height %u", [self heightForBlockHash:blockHash]);
            if (!result.rootQuorumListValid) DSLog(@"rootQuorumListValid not valid at height %u", [self heightForBlockHash:blockHash]);
            if (!result.validQuorums) DSLog(@"validQuorums not valid at height %u", [self heightForBlockHash:blockHash]);
            self.processingMasternodeListDiffHashes = nil;
            [self issueWithMasternodeListFromPeer:peer];
        }
    }];
}

- (void)peer:(DSPeer *)peer relayedQuorumRotationInfoMessage:(NSData *)message {
    self.timedOutAttempt = 0;
    NSUInteger length = message.length;
    NSUInteger offset = 0;
    if (length - offset < 32) return;
    UInt256 baseBlockHash = [message UInt256AtOffset:offset];
    offset += 32;
    if (length - offset < 32) return;
    UInt256 blockHash = [message UInt256AtOffset:offset];
    offset += 32;
    NSData *blockHashData = uint256_data(blockHash);
    UInt512 concat = uint512_concat(baseBlockHash, blockHash);
    NSData *blockHashDiffsData = uint512_data(concat);
    if (![self.masternodeListsInRetrieval containsObject:blockHashDiffsData]) {
        return;
    }
    [self.masternodeListsInRetrieval removeObject:blockHashDiffsData];
    if ([self.store.masternodeListsByBlockHash objectForKey:blockHashData]) {
        //we already have this
        return; //no need to do anything more
    }
    if ([self.store.masternodeListsBlockHashStubs containsObject:blockHashData]) {
        return; //no need to do anything more
    }
    DSMasternodeList *baseMasternodeList = [self masternodeListForBlockHash:baseBlockHash];
    if (!baseMasternodeList && !uint256_eq(self.chain.genesisHash, baseBlockHash) && uint256_is_not_zero(baseBlockHash)) {
        //this could have been deleted in the meantime, if so rerequest
        [self issueWithMasternodeListFromPeer:peer];
        return;
    }
    DSBlock *lastBlock = nil;
    if ([self.chain heightForBlockHash:blockHash]) {
        lastBlock = [[peer.chain terminalBlocks] objectForKey:uint256_obj(blockHash)];
        if (!lastBlock && [peer.chain allowInsightBlocksForVerification]) {
            lastBlock = [[peer.chain insightVerifiedBlocksByHashDictionary] objectForKey:uint256_data(blockHash)];
            if (!lastBlock && peer.chain.isTestnet) {
                //We can trust insight if on testnet
                [self blockUntilAddInsight:blockHash];
                lastBlock = [[peer.chain insightVerifiedBlocksByHashDictionary] objectForKey:uint256_data(blockHash)];
            }
        }
    } else {
        lastBlock = [peer.chain recentTerminalBlockForBlockHash:blockHash];
    }
    if (!lastBlock) {
        [self issueWithMasternodeListFromPeer:peer];
        DSLog(@"Last Block missing");
        return;
    }
    self.processingMasternodeListDiffHashes = blockHashDiffsData;
    // We can use insight as backup if we are on testnet, we shouldn't otherwise.
    [self processQRInfoMessage:message
          baseBlockHashesCount:1
            baseMasternodeList:baseMasternodeList
                     lastBlock:lastBlock
            useInsightAsBackup:self.chain.isTestnet
                    completion:^(DSMnDiffProcessingResult *result) {
        DSMasternodeList *masternodeList = result.masternodeList;
        if (![self.masternodeListRetrievalQueue containsObject:uint256_data(masternodeList.blockHash)]) {
            //We most likely wiped data in the meantime
            [self.masternodeListsInRetrieval removeAllObjects];
            [self dequeueMasternodeListRequest];
            return;
        }
        if (result.foundCoinbase && result.validCoinbase && result.rootMNListValid && result.rootQuorumListValid && result.validQuorums) {
            NSOrderedSet *neededMissingMasternodeLists = result.neededMissingMasternodeLists;
            DSLog(@"Valid masternode list found at height %u", [self heightForBlockHash:blockHash]);
            //yay this is the correct masternode list verified deterministically for the given block
            if ([neededMissingMasternodeLists count] &&
                [self.masternodeListQueriesNeedingQuorumsValidated containsObject:uint256_data(blockHash)]) {
                DSLog(@"Last masternode list is missing previous masternode lists for quorum validation");
                self.processingMasternodeListDiffHashes = nil;
                //This is the current one, get more previous masternode lists we need to verify quorums
                self.masternodeListAwaitingQuorumValidation = masternodeList;
                [self.masternodeListRetrievalQueue removeObject:uint256_data(blockHash)];
                NSMutableOrderedSet *neededMasternodeLists = [neededMissingMasternodeLists mutableCopy];
                [neededMasternodeLists addObject:uint256_data(blockHash)]; //also get the current one again
                [self getMasternodeListsForBlockHashes:neededMasternodeLists];
                [self dequeueMasternodeListRequest];
            } else {
                [self processValidMasternodeList:masternodeList havingAddedMasternodes:result.addedMasternodes modifiedMasternodes:result.modifiedMasternodes addedQuorums:result.addedQuorums];
                NSAssert([self.masternodeListRetrievalQueue containsObject:uint256_data(masternodeList.blockHash)], @"This should still be here");
                self.processingMasternodeListDiffHashes = nil;
                [self.masternodeListRetrievalQueue removeObject:uint256_data(masternodeList.blockHash)];
                [self dequeueMasternodeListRequest];
                //check for instant send locks that were awaiting a quorum
                if (![self.masternodeListRetrievalQueue count]) {
                    [self.chain.chainManager.transactionManager checkWaitingForQuorums];
                }
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:CHAIN_FAULTY_DML_MASTERNODE_PEERS];
            }
        } else {
            if (!result.foundCoinbase) DSLog(@"Did not find coinbase at height %u", [self heightForBlockHash:blockHash]);
            if (!result.validCoinbase) DSLog(@"Coinbase not valid at height %u", [self heightForBlockHash:blockHash]);
            if (!result.rootMNListValid) DSLog(@"rootMNListValid not valid at height %u", [self heightForBlockHash:blockHash]);
            if (!result.rootQuorumListValid) DSLog(@"rootQuorumListValid not valid at height %u", [self heightForBlockHash:blockHash]);
            if (!result.validQuorums) DSLog(@"validQuorums not valid at height %u", [self heightForBlockHash:blockHash]);
            self.processingMasternodeListDiffHashes = nil;
            [self issueWithMasternodeListFromPeer:peer];
        }
    }];
}

- (void)processValidMasternodeList:(DSMasternodeList *)masternodeList havingAddedMasternodes:(NSDictionary *)addedMasternodes modifiedMasternodes:(NSDictionary *)modifiedMasternodes addedQuorums:(NSDictionary *)addedQuorums {
    if (uint256_eq(self.lastQueriedBlockHash, masternodeList.blockHash)) {
        //this is now the current masternode list
        self.currentMasternodeList = masternodeList;
    }
    if (uint256_eq(self.masternodeListAwaitingQuorumValidation.blockHash, masternodeList.blockHash)) {
        self.masternodeListAwaitingQuorumValidation = nil;
    }
    if (!self.store.masternodeListsByBlockHash[uint256_data(masternodeList.blockHash)] &&
        ![self.store.masternodeListsBlockHashStubs containsObject:uint256_data(masternodeList.blockHash)]) {
        //in rare race conditions this might already exist

        NSArray *updatedSimplifiedMasternodeEntries = [addedMasternodes.allValues arrayByAddingObjectsFromArray:modifiedMasternodes.allValues];
        [self.chain updateAddressUsageOfSimplifiedMasternodeEntries:updatedSimplifiedMasternodeEntries];

        [self saveMasternodeList:masternodeList
            havingModifiedMasternodes:modifiedMasternodes
                         addedQuorums:addedQuorums];
    }
    if (!KEEP_OLD_QUORUMS && uint256_eq(self.lastQueriedBlockHash, masternodeList.blockHash)) {
        [self removeOldMasternodeLists];
    }
}

- (BOOL)hasMasternodeListCurrentlyBeingSaved {
    return [self.store hasMasternodeListCurrentlyBeingSaved];
}

- (void)saveMasternodeList:(DSMasternodeList *)masternodeList havingModifiedMasternodes:(NSDictionary *)modifiedMasternodes addedQuorums:(NSDictionary *)addedQuorums {
    [self saveMasternodeList:masternodeList
        havingModifiedMasternodes:modifiedMasternodes
                     addedQuorums:addedQuorums
                       completion:^(NSError *error) {
        if (!error ||
            ![self.masternodeListRetrievalQueue count]) { //if it is 0 then we most likely have wiped chain info
            return;
        }
        [self wipeMasternodeInfo];
        dispatch_async(self.chain.networkingQueue, ^{
            [self getCurrentMasternodeListWithSafetyDelay:0];
        });
    }];
}

- (void)saveMasternodeList:(DSMasternodeList *)masternodeList havingModifiedMasternodes:(NSDictionary *)modifiedMasternodes addedQuorums:(NSDictionary *)addedQuorums completion:(void (^)(NSError *error))completion {
    [self.store saveMasternodeList:masternodeList havingModifiedMasternodes:modifiedMasternodes addedQuorums:addedQuorums completion:completion];
}

+ (void)saveMasternodeList:(DSMasternodeList *)masternodeList toChain:(DSChain *)chain havingModifiedMasternodes:(NSDictionary *)modifiedMasternodes addedQuorums:(NSDictionary *)addedQuorums createUnknownBlocks:(BOOL)createUnknownBlocks inContext:(NSManagedObjectContext *)context completion:(void (^)(NSError *error))completion {
    [DSMasternodeStore saveMasternodeList:masternodeList toChain:chain havingModifiedMasternodes:modifiedMasternodes addedQuorums:addedQuorums createUnknownBlocks:createUnknownBlocks inContext:context completion:completion];
}

- (void)removeOldMasternodeLists {
    [self.store removeOldMasternodeLists];
}

- (void)issueWithMasternodeListFromPeer:(DSPeer *)peer {
    [self.peerManager peerMisbehaving:peer errorMessage:@"Issue with Deterministic Masternode list"];
    NSArray *faultyPeers = [[NSUserDefaults standardUserDefaults] arrayForKey:CHAIN_FAULTY_DML_MASTERNODE_PEERS];
    if (faultyPeers.count >= MAX_FAULTY_DML_PEERS) {
        DSLog(@"Exceeded max failures for masternode list, starting from scratch");
        //no need to remove local masternodes
        [self.masternodeListRetrievalQueue removeAllObjects];
        [self.store deleteAllOnChain];
        [self.store removeOldMasternodeLists];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:CHAIN_FAULTY_DML_MASTERNODE_PEERS];
        [self getCurrentMasternodeListWithSafetyDelay:0];
    } else {
        if (!faultyPeers) {
            faultyPeers = @[peer.location];
        } else if (![faultyPeers containsObject:peer.location]) {
            faultyPeers = [faultyPeers arrayByAddingObject:peer.location];
        }
        [[NSUserDefaults standardUserDefaults] setObject:faultyPeers
                                                  forKey:CHAIN_FAULTY_DML_MASTERNODE_PEERS];
        [self dequeueMasternodeListRequest];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DSMasternodeListDiffValidationErrorNotification object:nil userInfo:@{DSChainManagerNotificationChainKey: self.chain}];
    });
}

// MARK: - Quorums

- (DSQuorumEntry *)quorumEntryForInstantSendRequestID:(UInt256)requestID withBlockHeightOffset:(uint32_t)blockHeightOffset {
    DSMerkleBlock *merkleBlock = [self.chain blockFromChainTip:blockHeightOffset];
    DSMasternodeList *masternodeList = [self masternodeListBeforeBlockHash:merkleBlock.blockHash];
    if (!masternodeList) {
        DSLog(@"No masternode list found yet");
        return nil;
    }
    if (merkleBlock.height - masternodeList.height > 32) {
        DSLog(@"Masternode list for IS is too old (age: %d masternodeList height %d merkle block height %d)", merkleBlock.height - masternodeList.height, masternodeList.height, merkleBlock.height);
        return nil;
    }
    return [masternodeList quorumEntryForInstantSendRequestID:requestID];
}

- (DSQuorumEntry *)quorumEntryForChainLockRequestID:(UInt256)requestID withBlockHeightOffset:(uint32_t)blockHeightOffset {
    DSMerkleBlock *merkleBlock = [self.chain blockFromChainTip:blockHeightOffset];
    return [self quorumEntryForChainLockRequestID:requestID forMerkleBlock:merkleBlock];
}

- (DSQuorumEntry *)quorumEntryForChainLockRequestID:(UInt256)requestID forBlockHeight:(uint32_t)blockHeight {
    DSMerkleBlock *merkleBlock = [self.chain blockAtHeight:blockHeight];
    return [self quorumEntryForChainLockRequestID:requestID forMerkleBlock:merkleBlock];
}

- (DSQuorumEntry *)quorumEntryForPlatformHavingQuorumHash:(UInt256)quorumHash forBlockHeight:(uint32_t)blockHeight {
    DSBlock *block = [self.chain blockAtHeight:blockHeight];
    if (block == nil) {
        if (blockHeight > self.chain.lastTerminalBlockHeight) {
            block = self.chain.lastTerminalBlock;
        } else {
            return nil;
        }
    }
    return [self quorumEntryForPlatformHavingQuorumHash:quorumHash forBlock:block];
}

- (DSQuorumEntry *)quorumEntryForPlatformHavingQuorumHash:(UInt256)quorumHash forBlock:(DSBlock *)block {
    DSMasternodeList *masternodeList = [self masternodeListForBlockHash:block.blockHash];
    if (!masternodeList) {
        masternodeList = [self masternodeListBeforeBlockHash:block.blockHash];
    }
    if (!masternodeList) {
        DSLog(@"No masternode list found yet");
        return nil;
    }
    if (block.height - masternodeList.height > 32) {
        DSLog(@"Masternode list is too old");
        return nil;
    }
    DSQuorumEntry *quorumEntry = [masternodeList quorumEntryForPlatformWithQuorumHash:quorumHash];
    if (quorumEntry == nil) {
        quorumEntry = [self quorumEntryForPlatformHavingQuorumHash:quorumHash forBlockHeight:block.height - 1];
    }
    return quorumEntry;
}


- (DSQuorumEntry *)quorumEntryForChainLockRequestID:(UInt256)requestID forMerkleBlock:(DSMerkleBlock *)merkleBlock {
    DSMasternodeList *masternodeList = [self masternodeListBeforeBlockHash:merkleBlock.blockHash];
    if (!masternodeList) {
        DSLog(@"No masternode list found yet");
        return nil;
    }
    if (merkleBlock.height - masternodeList.height > 24) {
        DSLog(@"Masternode list is too old");
        return nil;
    }
    return [masternodeList quorumEntryForChainLockRequestID:requestID];
}

// MARK: - Meta information

- (void)checkPingTimesForCurrentMasternodeListInContext:(NSManagedObjectContext *)context withCompletion:(void (^)(NSMutableDictionary<NSData *, NSNumber *> *pingTimes, NSMutableDictionary<NSData *, NSError *> *errors))completion {
    __block NSArray<DSSimplifiedMasternodeEntry *> *entries = self.currentMasternodeList.simplifiedMasternodeEntries;
    [self.chain.chainManager.DAPIClient checkPingTimesForMasternodes:entries
                                                          completion:^(NSMutableDictionary<NSData *, NSNumber *> *_Nonnull pingTimes, NSMutableDictionary<NSData *, NSError *> *_Nonnull errors) {
        [context performBlockAndWait:^{
            for (DSSimplifiedMasternodeEntry *entry in entries) {
                [entry savePlatformPingInfoInContext:context];
            }
            NSError *savingError = nil;
            [context save:&savingError];
        }];
        if (completion != nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(pingTimes, errors);
            });
        }
    }];
}

// MARK: - Local Masternodes

- (DSLocalMasternode *)createNewMasternodeWithIPAddress:(UInt128)ipAddress onPort:(uint32_t)port inWallet:(DSWallet *)wallet {
    NSParameterAssert(wallet);
    return [self createNewMasternodeWithIPAddress:ipAddress onPort:port inFundsWallet:wallet inOperatorWallet:wallet inOwnerWallet:wallet inVotingWallet:wallet];
}

- (DSLocalMasternode *)createNewMasternodeWithIPAddress:(UInt128)ipAddress onPort:(uint32_t)port inFundsWallet:(DSWallet *)fundsWallet inOperatorWallet:(DSWallet *)operatorWallet inOwnerWallet:(DSWallet *)ownerWallet inVotingWallet:(DSWallet *)votingWallet {
    DSLocalMasternode *localMasternode = [[DSLocalMasternode alloc] initWithIPAddress:ipAddress onPort:port inFundsWallet:fundsWallet inOperatorWallet:operatorWallet inOwnerWallet:ownerWallet inVotingWallet:votingWallet];
    return localMasternode;
}

- (DSLocalMasternode *)createNewMasternodeWithIPAddress:(UInt128)ipAddress onPort:(uint32_t)port inFundsWallet:(DSWallet *_Nullable)fundsWallet fundsWalletIndex:(uint32_t)fundsWalletIndex inOperatorWallet:(DSWallet *_Nullable)operatorWallet operatorWalletIndex:(uint32_t)operatorWalletIndex inOwnerWallet:(DSWallet *_Nullable)ownerWallet ownerWalletIndex:(uint32_t)ownerWalletIndex inVotingWallet:(DSWallet *_Nullable)votingWallet votingWalletIndex:(uint32_t)votingWalletIndex {
    DSLocalMasternode *localMasternode = [[DSLocalMasternode alloc] initWithIPAddress:ipAddress onPort:port inFundsWallet:fundsWallet fundsWalletIndex:fundsWalletIndex inOperatorWallet:operatorWallet operatorWalletIndex:operatorWalletIndex inOwnerWallet:ownerWallet ownerWalletIndex:ownerWalletIndex inVotingWallet:votingWallet votingWalletIndex:votingWalletIndex];
    return localMasternode;
}

- (DSLocalMasternode *)createNewMasternodeWithIPAddress:(UInt128)ipAddress onPort:(uint32_t)port inFundsWallet:(DSWallet *_Nullable)fundsWallet fundsWalletIndex:(uint32_t)fundsWalletIndex inOperatorWallet:(DSWallet *_Nullable)operatorWallet operatorWalletIndex:(uint32_t)operatorWalletIndex operatorPublicKey:(DSBLSKey *)operatorPublicKey inOwnerWallet:(DSWallet *_Nullable)ownerWallet ownerWalletIndex:(uint32_t)ownerWalletIndex ownerPrivateKey:(DSECDSAKey *)ownerPrivateKey inVotingWallet:(DSWallet *_Nullable)votingWallet votingWalletIndex:(uint32_t)votingWalletIndex votingKey:(DSECDSAKey *)votingKey {
    DSLocalMasternode *localMasternode = [[DSLocalMasternode alloc] initWithIPAddress:ipAddress onPort:port inFundsWallet:fundsWallet fundsWalletIndex:fundsWalletIndex inOperatorWallet:operatorWallet operatorWalletIndex:operatorWalletIndex inOwnerWallet:ownerWallet ownerWalletIndex:ownerWalletIndex inVotingWallet:votingWallet votingWalletIndex:votingWalletIndex];

    if (operatorWalletIndex == UINT32_MAX && operatorPublicKey) {
        [localMasternode forceOperatorPublicKey:operatorPublicKey];
    }

    if (ownerWalletIndex == UINT32_MAX && ownerPrivateKey) {
        [localMasternode forceOwnerPrivateKey:ownerPrivateKey];
    }

    if (votingWalletIndex == UINT32_MAX && votingKey) {
        [localMasternode forceVotingKey:votingKey];
    }

    return localMasternode;
}

- (DSLocalMasternode *)localMasternodeFromSimplifiedMasternodeEntry:(DSSimplifiedMasternodeEntry *)simplifiedMasternodeEntry claimedWithOwnerWallet:(DSWallet *)ownerWallet ownerKeyIndex:(uint32_t)ownerKeyIndex {
    NSParameterAssert(simplifiedMasternodeEntry);
    NSParameterAssert(ownerWallet);

    DSLocalMasternode *localMasternode = [self localMasternodeHavingProviderRegistrationTransactionHash:simplifiedMasternodeEntry.providerRegistrationTransactionHash];

    if (localMasternode) return localMasternode;

    uint32_t votingIndex;
    DSWallet *votingWallet = [simplifiedMasternodeEntry.chain walletHavingProviderVotingAuthenticationHash:simplifiedMasternodeEntry.keyIDVoting foundAtIndex:&votingIndex];

    uint32_t operatorIndex;
    DSWallet *operatorWallet = [simplifiedMasternodeEntry.chain walletHavingProviderOperatorAuthenticationKey:simplifiedMasternodeEntry.operatorPublicKey foundAtIndex:&operatorIndex];

    if (votingWallet || operatorWallet) {
        return [[DSLocalMasternode alloc] initWithIPAddress:simplifiedMasternodeEntry.address onPort:simplifiedMasternodeEntry.port inFundsWallet:nil fundsWalletIndex:0 inOperatorWallet:operatorWallet operatorWalletIndex:operatorIndex inOwnerWallet:ownerWallet ownerWalletIndex:ownerKeyIndex inVotingWallet:votingWallet votingWalletIndex:votingIndex];
    } else {
        return nil;
    }
}

- (DSLocalMasternode *)localMasternodeFromProviderRegistrationTransaction:(DSProviderRegistrationTransaction *)providerRegistrationTransaction save:(BOOL)save {
    NSParameterAssert(providerRegistrationTransaction);

    //First check to see if we have a local masternode for this provider registration hash

    @synchronized(self) {
        DSLocalMasternode *localMasternode = self.localMasternodesDictionaryByRegistrationTransactionHash[uint256_data(providerRegistrationTransaction.txHash)];

        if (localMasternode) {
            //We do
            //todo Update keys
            return localMasternode;
        }
        //We don't
        localMasternode = [[DSLocalMasternode alloc] initWithProviderTransactionRegistration:providerRegistrationTransaction];
        if (localMasternode.noLocalWallet) return nil;
        [self.localMasternodesDictionaryByRegistrationTransactionHash setObject:localMasternode forKey:uint256_data(providerRegistrationTransaction.txHash)];
        if (save) {
            [localMasternode save];
        }
        return localMasternode;
    }
}

- (DSLocalMasternode *)localMasternodeHavingProviderRegistrationTransactionHash:(UInt256)providerRegistrationTransactionHash {
    DSLocalMasternode *localMasternode = self.localMasternodesDictionaryByRegistrationTransactionHash[uint256_data(providerRegistrationTransactionHash)];
    return localMasternode;
}

- (DSLocalMasternode *)localMasternodeUsingIndex:(uint32_t)index atDerivationPath:(DSDerivationPath *)derivationPath {
    NSParameterAssert(derivationPath);
    for (DSLocalMasternode *localMasternode in self.localMasternodesDictionaryByRegistrationTransactionHash.allValues) {
        switch (derivationPath.reference) {
            case DSDerivationPathReference_ProviderFunds:
                if (localMasternode.holdingKeysWallet == derivationPath.wallet && localMasternode.holdingWalletIndex == index) {
                    return localMasternode;
                }
                break;
            case DSDerivationPathReference_ProviderOwnerKeys:
                if (localMasternode.ownerKeysWallet == derivationPath.wallet && localMasternode.ownerWalletIndex == index) {
                    return localMasternode;
                }
                break;
            case DSDerivationPathReference_ProviderOperatorKeys:
                if (localMasternode.operatorKeysWallet == derivationPath.wallet && localMasternode.operatorWalletIndex == index) {
                    return localMasternode;
                }
                break;
            case DSDerivationPathReference_ProviderVotingKeys:
                if (localMasternode.votingKeysWallet == derivationPath.wallet && localMasternode.votingWalletIndex == index) {
                    return localMasternode;
                }
                break;
            default:
                break;
        }
    }
    return nil;
}

- (NSArray<DSLocalMasternode *> *)localMasternodesPreviouslyUsingIndex:(uint32_t)index atDerivationPath:(DSDerivationPath *)derivationPath {
    NSParameterAssert(derivationPath);
    if (derivationPath.reference == DSDerivationPathReference_ProviderFunds || derivationPath.reference == DSDerivationPathReference_ProviderOwnerKeys) {
        return nil;
    }

    NSMutableArray *localMasternodes = [NSMutableArray array];

    for (DSLocalMasternode *localMasternode in self.localMasternodesDictionaryByRegistrationTransactionHash.allValues) {
        switch (derivationPath.reference) {
            case DSDerivationPathReference_ProviderOperatorKeys:
                if (localMasternode.operatorKeysWallet == derivationPath.wallet && [localMasternode.previousOperatorWalletIndexes containsIndex:index]) {
                    [localMasternodes addObject:localMasternode];
                }
                break;
            case DSDerivationPathReference_ProviderVotingKeys:
                if (localMasternode.votingKeysWallet == derivationPath.wallet && [localMasternode.previousVotingWalletIndexes containsIndex:index]) {
                    [localMasternodes addObject:localMasternode];
                }
                break;
            default:
                break;
        }
    }
    return [localMasternodes copy];
}

- (NSUInteger)localMasternodesCount {
    return [self.localMasternodesDictionaryByRegistrationTransactionHash count];
}

- (NSArray<DSLocalMasternode *> *)localMasternodes {
    return [self.localMasternodesDictionaryByRegistrationTransactionHash allValues];
}


@end
