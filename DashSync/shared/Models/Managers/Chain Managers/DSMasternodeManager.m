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
#import "DSMasternodeDiffMessageContext.h"
#import "DSMasternodeManager+LocalMasternode.h"
#import "DSMasternodeManager+Mndiff.h"
#import "DSMasternodeService.h"
#import "DSMasternodeStore.h"
#import "DSMasternodeStore+Protected.h"
#import "DSMerkleBlock.h"
#import "DSMnDiffProcessingResult.h"
#import "DSOptionsManager.h"
#import "DSPeer.h"
#import "DSPeerManager+Protected.h"
#import "DSSimplifiedMasternodeEntry.h"
#import "DSTransactionManager+Protected.h"

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
@property (nonatomic, strong) DSMasternodeService *service;
@property (nonatomic, strong) DSMasternodeList *masternodeListAwaitingQuorumValidation;
@property (nonatomic, strong) NSMutableSet *masternodeListQueriesNeedingQuorumsValidated;
@property (nonatomic, assign) UInt256 lastQueriedBlockHash; //last by height, not by time queried
@property (nonatomic, strong) NSData *processingMasternodeListDiffHashes;
@property (nonatomic, assign) NSTimeInterval timeIntervalForMasternodeRetrievalSafetyDelay;
@property (nonatomic, assign) uint16_t timedOutAttempt;
@property (nonatomic, assign) uint16_t timeOutObserverTry;

@end

@implementation DSMasternodeManager

- (DSMasternodeList *)currentMasternodeList {
    return [self.store currentMasternodeList];
}

- (instancetype)initWithChain:(DSChain *)chain {
    NSParameterAssert(chain);

    if (!(self = [super init])) return nil;
    _chain = chain;
    _masternodeListQueriesNeedingQuorumsValidated = [NSMutableSet set];
    self.store = [[DSMasternodeStore alloc] initWithChain:chain];
    self.service = [[DSMasternodeService alloc] initWithChain:chain blockHeightLookup:^uint32_t(UInt256 blockHash) {
        return [self heightForBlockHash:blockHash];
    }];
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
    return [self.service masternodeListRetrievalQueueCount];
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
    return [self.store currentMasternodeListIsInLast24Hours];
}


// MARK: - Set Up and Tear Down

- (void)setUp {
    [self.store setUp];
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
        ![self masternodeListForBlockHash:checkpoint.blockHash withBlockHeightLookup:nil])
        [self processRequestFromFileForBlockHash:checkpoint.blockHash completion:^(BOOL success, DSMasternodeList *masternodeList) {
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
    [self wipeLocalMasternodeInfo];
    self.masternodeListAwaitingQuorumValidation = nil;
    [self.service cleanAllLists];
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
    [self.service addToMasternodeRetrievalQueue:masternodeBlockHashData];
}

- (void)addToMasternodeRetrievalQueueArray:(NSArray *)masternodeBlockHashDataArray {
    [self.service addToMasternodeRetrievalQueueArray:masternodeBlockHashDataArray];
}

- (void)startTimeOutObserver {
    __block NSSet *masternodeListsInRetrieval = [self.service.masternodeListsInRetrieval copy];
    __block NSUInteger masternodeListCount = [self knownMasternodeListsCount];
    self.timeOutObserverTry++;
    __block uint16_t timeOutObserverTry = self.timeOutObserverTry;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20 * (self.timedOutAttempt + 1) * NSEC_PER_SEC)), self.chain.networkingQueue, ^{
        if (!self.masternodeListRetrievalQueueCount) return;
        if (self.timeOutObserverTry != timeOutObserverTry) return;
        
        NSMutableSet *leftToGet = [masternodeListsInRetrieval mutableCopy];
        [leftToGet intersectSet:self.service.masternodeListsInRetrieval];
        if (self.processingMasternodeListDiffHashes) {
            [leftToGet removeObject:self.processingMasternodeListDiffHashes];
        }
        
        if ((masternodeListCount == [self knownMasternodeListsCount]) && [masternodeListsInRetrieval isEqualToSet:leftToGet]) {
            DSLog(@"TimedOut");
            self.timedOutAttempt++;
            [self.peerManager.downloadPeer disconnect];
            [self.service cleanListsInRetrieval];
            [self dequeueMasternodeListRequest];
        } else {
            [self startTimeOutObserver];
        }
    });
}

- (void)dequeueMasternodeListRequest {
    DSLog(@"Dequeued Masternode List Request");
    [self.service fetchMasternodeListsToRetrieve:^(NSOrderedSet<NSData *> *listsToRetrieve) {
        for (NSData *blockHashData in listsToRetrieve) {
            NSUInteger pos = [listsToRetrieve indexOfObject:blockHashData];
            //we should check the associated block still exists
            if ([self hasBlockForBlockHash:blockHashData]) {
                //there is the rare possibility we have the masternode list as a checkpoint, so lets first try that
                UInt256 blockHash = blockHashData.UInt256;
                [self processRequestFromFileForBlockHash:blockHash completion:^(BOOL success, DSMasternodeList * _Nonnull masternodeList) {
                    
                    if (success) {
                        if (!KEEP_OLD_QUORUMS && uint256_eq(self.lastQueriedBlockHash, masternodeList.blockHash)) {
                            [self.store removeOldMasternodeLists];
                        }
                        if (![self.service masternodeListRetrievalQueueCount]) {
                            [self.chain.chainManager.transactionManager checkWaitingForQuorums];
                        }
                        //we already had it
                        [self.service.masternodeListRetrievalQueue removeObject:blockHashData];
                    } else {
                        //we need to go get it
                        UInt256 previousMasternodeAlreadyKnownBlockHash = [self.store closestKnownBlockHashForBlockHash:blockHash];
                        UInt256 previousMasternodeInQueueBlockHash = (pos ? [listsToRetrieve objectAtIndex:pos - 1].UInt256 : UINT256_ZERO);
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
                        [self.service.masternodeListsInRetrieval addObject:uint512_data(concat)];
                    }
                }];
            } else {
                DSLog(@"Missing block (%@)", blockHashData.hexString);
                [self.service.masternodeListRetrievalQueue removeObject:blockHashData];
            }
        }
        [self startTimeOutObserver];
    }];
}

- (void)getRecentMasternodeList:(NSUInteger)blocksAgo withSafetyDelay:(uint32_t)safetyDelay {
    @synchronized(self.service.masternodeListRetrievalQueue) {
        DSMerkleBlock *merkleBlock = [self.chain blockFromChainTip:blocksAgo];
        if ([self.service.masternodeListRetrievalQueue lastObject] &&
            uint256_eq(merkleBlock.blockHash, [self.service.masternodeListRetrievalQueue lastObject].UInt256)) {
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
        [self.masternodeListQueriesNeedingQuorumsValidated addObject:blockHash];
        DSLog(@"Getting masternode list %u", merkleBlock.height);
        BOOL emptyRequestQueue = !self.masternodeListRetrievalQueueCount;
        [self addToMasternodeRetrievalQueue:blockHash];
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
    @synchronized(self.service.masternodeListRetrievalQueue) {
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
    [self dequeueMasternodeListRequest];
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
    NSData *blockHashData = uint256_data(blockHash);
    [self.masternodeListQueriesNeedingQuorumsValidated addObject:blockHashData];
    //this is safe
    [self getMasternodeListsForBlockHashes:[NSOrderedSet orderedSetWithObject:blockHashData]];
    return TRUE;
}

- (void)processRequestFromFileForBlockHash:(UInt256)blockHash completion:(void (^)(BOOL success, DSMasternodeList *masternodeList))completion {
    NSData *message = [self.store messageFromFileForBlockHash:blockHash];
    if (!message) {
        completion(NO, nil);
        return;
    }
    __block DSMerkleBlock *block = [self.chain blockForBlockHash:blockHash];
    DSMasternodeList *baseMasternodeList = nil;
    [self processMasternodeDiffMessage:message
                    baseMasternodeList:baseMasternodeList
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
        __block DSMasternodeList *masternodeList = result.masternodeList;
        [self.store updateMasternodeList:masternodeList addedMasternodes:result.addedMasternodes modifiedMasternodes:result.modifiedMasternodes addedQuorums:result.addedQuorums completion:^(NSError * _Nonnull error) {
            completion(YES, masternodeList);
        }];
    }];
}


// MARK: - Deterministic Masternode List Sync

-(DSBlock *)lastBlockForBlockHash:(UInt256)blockHash fromPeer:(DSPeer *)peer {
    DSBlock *lastBlock = nil;
    if ([self.chain heightForBlockHash:blockHash]) {
        lastBlock = [[peer.chain terminalBlocks] objectForKey:uint256_obj(blockHash)];
        if (!lastBlock && [peer.chain allowInsightBlocksForVerification]) {
            lastBlock = [[peer.chain insightVerifiedBlocksByHashDictionary] objectForKey:uint256_data(blockHash)];
            if (!lastBlock && peer.chain.isTestnet) {
                //We can trust insight if on testnet
                [self.service blockUntilAddInsight:blockHash];
                lastBlock = [[peer.chain insightVerifiedBlocksByHashDictionary] objectForKey:uint256_data(blockHash)];
            }
        }
    } else {
        lastBlock = [peer.chain recentTerminalBlockForBlockHash:blockHash];
    }
    return lastBlock;
}

-(BOOL)hasBlockForBlockHash:(NSData *)blockHashData {
    UInt256 blockHash = blockHashData.UInt256;
    BOOL hasBlock = ([self.chain blockForBlockHash:blockHash] != nil);
    if (!hasBlock) {
        hasBlock = [self.store hasBlocksWithHash:blockHash];
    }
    if (!hasBlock && self.chain.isTestnet) {
        //We can trust insight if on testnet
        [self.service blockUntilAddInsight:blockHash];
        hasBlock = !![[self.chain insightVerifiedBlocksByHashDictionary] objectForKey:blockHashData];
    }
    return hasBlock;
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
    UInt256 baseBlockHash = [message readUInt256AtOffset:&offset];
    if (length - offset < 32) return;
    UInt256 blockHash = [message readUInt256AtOffset:&offset];

#if SAVE_MASTERNODE_DIFF_TO_FILE
    NSString *fileName = [NSString stringWithFormat:@"MNL_%@_%@.dat", @([self heightForBlockHash:baseBlockHash]), @([self heightForBlockHash:blockHash])];
    [message saveToFile:fileName inDirectory:NSCachesDirectory];
#endif

    NSData *blockHashData = uint256_data(blockHash);
    UInt512 concat = uint512_concat(baseBlockHash, blockHash);
    NSData *blockHashDiffsData = uint512_data(concat);
    
    if (![self.service removeListInRetrievalForKey:blockHashDiffsData] ||
        [self.store hasMasternodeListAt:blockHashData]) {
        return;
    }
    DSLog(@"relayed masternode diff with baseBlockHash %@ (%u) blockHash %@ (%u)", uint256_reverse_hex(baseBlockHash), [self heightForBlockHash:baseBlockHash], blockHashData.reverse.hexString, [self heightForBlockHash:blockHash]);
    DSMasternodeList *baseMasternodeList = [self masternodeListForBlockHash:baseBlockHash];
    if (!baseMasternodeList &&
        !uint256_eq(self.chain.genesisHash, baseBlockHash) &&
        uint256_is_not_zero(baseBlockHash)) {
        //this could have been deleted in the meantime, if so rerequest
        [self issueWithMasternodeListFromPeer:peer];
        DSLog(@"No base masternode list");
        return;
    }
    DSBlock *lastBlock = [self lastBlockForBlockHash:blockHash fromPeer:peer];
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
        NSData *masternodeListBlockHashData = uint256_data(masternodeList.blockHash);
        if (![self.service.masternodeListRetrievalQueue containsObject:masternodeListBlockHashData]) {
            //We most likely wiped data in the meantime
            [self.service cleanListsInRetrieval];
            [self dequeueMasternodeListRequest];
            return;
        }
        if (result.foundCoinbase && result.validCoinbase && result.rootMNListValid && result.rootQuorumListValid && result.validQuorums) {
            NSOrderedSet *neededMissingMasternodeLists = result.neededMissingMasternodeLists;
            DSLog(@"Valid masternode list found at height %u", [self heightForBlockHash:blockHash]);
            //yay this is the correct masternode list verified deterministically for the given block
            NSData *blockHashData = uint256_data(blockHash);
            if ([neededMissingMasternodeLists count] && [self.masternodeListQueriesNeedingQuorumsValidated containsObject:blockHashData]) {
                DSLog(@"Last masternode list is missing previous masternode lists for quorum validation");
                self.processingMasternodeListDiffHashes = nil;
                //This is the current one, get more previous masternode lists we need to verify quorums
                self.masternodeListAwaitingQuorumValidation = masternodeList;
                [self.service.masternodeListRetrievalQueue removeObject:blockHashData];
                NSMutableOrderedSet *neededMasternodeLists = [neededMissingMasternodeLists mutableCopy];
                [neededMasternodeLists addObject:blockHashData]; //also get the current one again
                [self getMasternodeListsForBlockHashes:neededMasternodeLists];
            } else {
                [self processValidMasternodeList:masternodeList havingAddedMasternodes:result.addedMasternodes modifiedMasternodes:result.modifiedMasternodes addedQuorums:result.addedQuorums];
                NSAssert([self.service.masternodeListRetrievalQueue containsObject:masternodeListBlockHashData], @"This should still be here");
                self.processingMasternodeListDiffHashes = nil;
                [self.service.masternodeListRetrievalQueue removeObject:masternodeListBlockHashData];
                [self dequeueMasternodeListRequest];
                // check for instant send locks that were awaiting a quorum
                if (![self.service.masternodeListRetrievalQueue count]) {
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
    UInt256 baseBlockHash = [message readUInt256AtOffset:&offset];
    if (length - offset < 32) return;
    UInt256 blockHash = [message readUInt256AtOffset:&offset];
    NSData *blockHashData = uint256_data(blockHash);
    UInt512 concat = uint512_concat(baseBlockHash, blockHash);
    NSData *blockHashDiffsData = uint512_data(concat);
    
    if (![self.service removeListInRetrievalForKey:blockHashDiffsData] ||
        [self.store hasMasternodeListAt:blockHashData]) {
        return;
    }
    DSMasternodeList *baseMasternodeList = [self masternodeListForBlockHash:baseBlockHash];
    if (!baseMasternodeList &&
        !uint256_eq(self.chain.genesisHash, baseBlockHash) &&
        uint256_is_not_zero(baseBlockHash)) {
        //this could have been deleted in the meantime, if so rerequest
        [self issueWithMasternodeListFromPeer:peer];
        return;
    }
    DSBlock *lastBlock = [self lastBlockForBlockHash:blockHash fromPeer:peer];
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
        NSData *masternodeListBlockHashData = uint256_data(masternodeList.blockHash);
        if (![self.service.masternodeListRetrievalQueue containsObject:masternodeListBlockHashData]) {
            [self.service cleanListsInRetrieval];
            [self dequeueMasternodeListRequest];
            return;
        }
        if (result.foundCoinbase && result.validCoinbase && result.rootMNListValid && result.rootQuorumListValid && result.validQuorums) {
            NSOrderedSet *neededMissingMasternodeLists = result.neededMissingMasternodeLists;
            NSData *blockHashData = uint256_data(blockHash);
            if ([neededMissingMasternodeLists count] && [self.masternodeListQueriesNeedingQuorumsValidated containsObject:blockHashData]) {
                self.processingMasternodeListDiffHashes = nil;
                self.masternodeListAwaitingQuorumValidation = masternodeList;
                [self.service.masternodeListRetrievalQueue removeObject:blockHashData];
                NSMutableOrderedSet *neededMasternodeLists = [neededMissingMasternodeLists mutableCopy];
                [neededMasternodeLists addObject:blockHashData]; //also get the current one again
                [self getMasternodeListsForBlockHashes:neededMasternodeLists];
            } else {
                [self processValidMasternodeList:masternodeList havingAddedMasternodes:result.addedMasternodes modifiedMasternodes:result.modifiedMasternodes addedQuorums:result.addedQuorums];
                self.processingMasternodeListDiffHashes = nil;
                [self.service.masternodeListRetrievalQueue removeObject:masternodeListBlockHashData];
                [self dequeueMasternodeListRequest];
                if (![self.service.masternodeListRetrievalQueue count]) {
                    [self.chain.chainManager.transactionManager checkWaitingForQuorums];
                }
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:CHAIN_FAULTY_DML_MASTERNODE_PEERS];
            }
        } else {
            self.processingMasternodeListDiffHashes = nil;
            [self issueWithMasternodeListFromPeer:peer];
        }
    }];
}

- (void)processMasternodeDiffMessage:(NSData *)message baseMasternodeList:(DSMasternodeList  *)baseMasternodeList lastBlock:(DSBlock *)lastBlock useInsightAsBackup:(BOOL)useInsightAsBackup completion:(void (^)(DSMnDiffProcessingResult *result))completion {
    DSMasternodeDiffMessageContext *mndiffContext = [[DSMasternodeDiffMessageContext alloc] init];
    [mndiffContext setBaseMasternodeList:baseMasternodeList];
    [mndiffContext setLastBlock:(DSMerkleBlock *)lastBlock];
    [mndiffContext setUseInsightAsBackup:useInsightAsBackup];
    [mndiffContext setChain:self.chain];
    [mndiffContext setMasternodeListLookup:^DSMasternodeList *(UInt256 blockHash) {
        return [self masternodeListForBlockHash:blockHash withBlockHeightLookup:nil];
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
        return [self masternodeListForBlockHash:blockHash withBlockHeightLookup:nil];
    }];
    [mndiffContext setBlockHeightLookup:^uint32_t(UInt256 blockHash) {
        return [self heightForBlockHash:blockHash];
    }];
    [DSMasternodeManager processQRInfoMessage:message baseBlockHashesCount:baseBlockHashesCount withContext:mndiffContext completion:completion];
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
        [self saveMasternodeList:masternodeList havingModifiedMasternodes:modifiedMasternodes addedQuorums:addedQuorums];
    }
    if (!KEEP_OLD_QUORUMS && uint256_eq(self.lastQueriedBlockHash, masternodeList.blockHash)) {
        [self.store removeOldMasternodeLists];
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
        if (!error || !self.masternodeListRetrievalQueueCount) { //if it is 0 then we most likely have wiped chain info
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

- (void)issueWithMasternodeListFromPeer:(DSPeer *)peer {
    [self.peerManager peerMisbehaving:peer errorMessage:@"Issue with Deterministic Masternode list"];
    NSArray *faultyPeers = [[NSUserDefaults standardUserDefaults] arrayForKey:CHAIN_FAULTY_DML_MASTERNODE_PEERS];
    if (faultyPeers.count >= MAX_FAULTY_DML_PEERS) {
        DSLog(@"Exceeded max failures for masternode list, starting from scratch");
        //no need to remove local masternodes
        [self.service.masternodeListRetrievalQueue removeAllObjects];
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
    return [self.store quorumEntryForInstantSendRequestID:requestID withBlockHeightOffset:blockHeightOffset];
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
    return [self.store quorumEntryForPlatformHavingQuorumHash:quorumHash forBlockHeight:blockHeight];
}

- (DSQuorumEntry *)quorumEntryForChainLockRequestID:(UInt256)requestID forMerkleBlock:(DSMerkleBlock *)merkleBlock {
    return [self.store quorumEntryForChainLockRequestID:requestID forMerkleBlock:merkleBlock];
}

// MARK: - Meta information

- (void)checkPingTimesForCurrentMasternodeListInContext:(NSManagedObjectContext *)context withCompletion:(void (^)(NSMutableDictionary<NSData *, NSNumber *> *pingTimes, NSMutableDictionary<NSData *, NSError *> *errors))completion {
    [self.store checkPingTimesForMasternodesInContext:context withCompletion:completion];
}

@end
