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
#import "DSChain+Checkpoint.h"
#import "DSChain+Params.h"
#import "DSChain+Protected.h"
#import "DSChainManager+Protected.h"
#import "DSCheckpoint.h"
#import "DSMasternodeListService+Protected.h"
#import "DSMasternodeListDiffService.h"
#import "DSQuorumRotationService.h"
#import "DSMerkleBlock.h"
#import "DSOptionsManager.h"
#import "NSError+Dash.h"

#define SAVE_MASTERNODE_DIFF_TO_FILE (0 && DEBUG)
#define DSFullLog(FORMAT, ...) printf("%s\n", [[NSString stringWithFormat:FORMAT, ##__VA_ARGS__] UTF8String])


@interface DSMasternodeManager ()

@property (nonatomic, strong) DSChain *chain;
@property (nonatomic, strong) DSMasternodeListStore *store;
@property (nonatomic, strong) DSMasternodeListDiffService *masternodeListDiffService;
@property (nonatomic, strong) DSQuorumRotationService *quorumRotationService;
@property (nonatomic, assign) NSTimeInterval timeIntervalForMasternodeRetrievalSafetyDelay;

@property (nonatomic, assign) uint32_t rotatedQuorumsActivationHeight;
@property (nonatomic, strong) dispatch_group_t processingGroup;
@property (nonatomic, strong) dispatch_queue_t processingQueue;
@property (nonatomic, strong) dispatch_source_t masternodeListTimer;
@property (nonatomic) BOOL isSyncing;
@end


@implementation DSMasternodeManager

- (BOOL)hasCurrentMasternodeListInLast30Days {
    if (self.currentMasternodeList && (!self.currentMasternodeList->obj->known_height || self.currentMasternodeList->obj->known_height == UINT32_MAX)) {
        self.currentMasternodeList->obj->known_height = [self.chain heightForBlockHash:u256_cast(self.currentMasternodeList->obj->block_hash)];
    }
    return self.currentMasternodeList && [[NSDate date] timeIntervalSince1970] - [self.chain timestampForBlockHeight:self.currentMasternodeList->obj->known_height] < DAY_TIME_INTERVAL * 30;
}

- (instancetype)initWithChain:(DSChain *)chain {
    NSParameterAssert(chain);
    if (!(self = [super init])) return nil;
    _chain = chain;
    _store = [[DSMasternodeListStore alloc] initWithChain:chain];
    self.masternodeListDiffService = [[DSMasternodeListDiffService alloc] initWithChain:chain store:_store];
    self.quorumRotationService = [[DSQuorumRotationService alloc] initWithChain:chain store:_store];
    _rotatedQuorumsActivationHeight = UINT32_MAX;
    _processingGroup = dispatch_group_create();
    _processingQueue = dispatch_queue_create([[NSString stringWithFormat:@"org.dashcore.dashsync.processing.%@", uint256_data(self.chain.genesisHash).shortHexString] UTF8String], DISPATCH_QUEUE_SERIAL);
    return self;
}

- (MasternodeProcessor *)processor {
    return self.chain.shareCore.processor->obj;
}
- (MasternodeProcessorCache *)cache {
    return self.chain.shareCore.cache->obj;
}


#pragma mark - DSMasternodeListServiceDelegate

- (BOOL)masternodeListServiceDidRequestFileFromBlockHash:(DSMasternodeListService *)service blockHash:(UInt256)blockHash {
    return [self processRequestFromFileForBlockHash:blockHash];
}
//
//- (void)masternodeListServiceExceededMaxFailuresForMasternodeList:(DSMasternodeListService *)service blockHash:(UInt256)blockHash {
//    [self.store removeOldMasternodeLists];
//}
//
- (void)masternodeListServiceEmptiedRetrievalQueue:(DSMasternodeListService *)service {
    if (![self.masternodeListDiffService retrievalQueueCount]) {
        if (![self.quorumRotationService retrievalQueueCount]) {
            [self.store removeOldMasternodeLists];
        }
        if (dash_spv_masternode_processor_processing_processor_cache_MasternodeProcessorCache_has_last_queried_qr_masternode_list_at_tip(self.chain.shareCore.cache->obj)) {
            [self.chain.chainManager chainFinishedSyncingMasternodeListsAndQuorums:self.chain];
        }
    }
}


// MARK: - Helpers

- (NSUInteger)knownMasternodeListsCount {
    return DKnownMasternodeListsCount(self.chain.shareCore.cache->obj);
}

- (uint32_t)earliestMasternodeListBlockHeight {
    return dash_spv_masternode_processor_processing_processor_MasternodeProcessor_earliest_masternode_list_block_height(self.processor);
}

- (uint32_t)lastMasternodeListBlockHeight {
    return DLastMasternodeListBlockHeight(self.processor);
}

- (uint32_t)heightForBlockHash:(UInt256)blockhash {
    u256 *block_hash = u256_ctor_u(blockhash);
    return DHeightForBlockHash(self.processor, block_hash);
}

- (BOOL)isMasternodeListOutdated {
    uint32_t lastHeight = self.lastMasternodeListBlockHeight;
    return lastHeight == UINT32_MAX || lastHeight < self.chain.lastTerminalBlockHeight - 8;
}

- (DMasternodeEntry *)masternodeHavingProviderRegistrationTransactionHash:(NSData *)providerRegistrationTransactionHash {
    NSParameterAssert(providerRegistrationTransactionHash);
    u256 *pro_reg_tx_hash = u256_ctor(providerRegistrationTransactionHash);
    DMasternodeEntry *entry = masternode_by_pro_reg_tx_hash(self.currentMasternodeList->obj->masternodes, pro_reg_tx_hash);
    return entry;
}

- (NSUInteger)simplifiedMasternodeEntryCount {
    return self.currentMasternodeList ? dash_spv_masternode_processor_models_masternode_list_MasternodeList_masternode_count(self.currentMasternodeList->obj) : 0;
}

- (NSUInteger)activeQuorumsCount {
    return self.currentMasternodeList ? dash_spv_masternode_processor_models_masternode_list_MasternodeList_quorums_count(self.currentMasternodeList->obj) : 0;
}

- (BOOL)hasMasternodeAtLocation:(UInt128)IPAddress port:(uint32_t)port {
    u128 *addr = u128_ctor_u(IPAddress);
    BOOL result = dash_spv_masternode_processor_models_masternode_list_MasternodeList_has_masternode_at_location(self.currentMasternodeList->obj, addr, (uint16_t) port);
    return result;
}

- (NSUInteger)masternodeListRetrievalQueueCount {
    return [self.masternodeListDiffService retrievalQueueCount];
}

- (NSUInteger)masternodeListRetrievalQueueMaxAmount {
    return [self.masternodeListDiffService retrievalQueueMaxAmount];
}

- (BOOL)currentMasternodeListIsInLast24Hours {
    if (!self.currentMasternodeList) {
        return NO;
    }
    DSBlock *block = [self.chain blockForBlockHash:u256_cast(self.currentMasternodeList->obj->block_hash)];
    if (!block) return FALSE;
    NSTimeInterval currentTimestamp = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval delta = currentTimestamp - block.timestamp;
    return fabs(delta) < DAY_TIME_INTERVAL;
}


// MARK: - Set Up and Tear Down

- (void)setUp {
    [self.store setUp];
    [self loadFileDistributedMasternodeLists];
}

- (DArcMasternodeList *_Nullable)reloadMasternodeLists {
    return [self reloadMasternodeListsWithBlockHeightLookup:^uint32_t(UInt256 blockHash) {
        return [self.chain heightForBlockHash:blockHash];
    }];
}

- (DArcMasternodeList *)reloadMasternodeListsWithBlockHeightLookup:(BlockHeightFinder)blockHeightLookup {
    dash_spv_masternode_processor_processing_processor_cache_MasternodeProcessorCache_clear(self.chain.shareCore.cache->obj);
    [self.chain.chainManager notifyMasternodeSyncStateChange:UINT32_MAX storedCount:0];

    return [self.store loadMasternodeListsWithBlockHeightLookup:blockHeightLookup];
}

- (DArcMasternodeList *)currentMasternodeList {
    return dash_spv_masternode_processor_processing_processor_MasternodeProcessor_current_masternode_list(self.chain.masternodeManager.processor, self.chain.isRotatedQuorumsPresented);
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
    BOOL exist = [self processRequestFromFileForBlockHash:checkpoint.blockHash];
    if (exist) {
//        TODO: re-implement
//        dispatch_async(dispatch_get_main_queue(), ^{
//            [[NSNotificationCenter defaultCenter] postNotificationName:DSCurrentMasternodeListDidChangeNotification
//                                                                object:nil
//                                                              userInfo:@{
//                DSChainManagerNotificationChainKey: self.chain,
//                DSMasternodeManagerNotificationMasternodeListKey: self.currentMasternodeList
//                ? [NSValue valueWithPointer:dash_spv_masternode_processor_processing_processor_cache_MasternodeProcessorCache_get_last_queried_mn_masternode_list(self.processorCache)]
//                    : [NSNull null]
//            }];
//        });

//        self.masternodeListDiffService.currentMasternodeList = result->ok->masternode_list;
    }
}

- (void)wipeMasternodeInfo {
    DSLog(@"[%@] wipeMasternodeInfo", self.chain.name);
    dash_spv_masternode_processor_processing_processor_cache_MasternodeProcessorCache_clear(self.chain.shareCore.cache->obj);
    [self.masternodeListDiffService cleanAllLists];
    [self.quorumRotationService cleanAllLists];
    [self.chain.chainManager notifyMasternodeSyncStateChange:UINT32_MAX storedCount:0];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DSMasternodeListDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey: self.chain}];
        [[NSNotificationCenter defaultCenter] postNotificationName:DSQuorumListDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey: self.chain}];
    });
}

// MARK: - Masternode List Helpers

- (DArcMasternodeList *)masternodeListForBlockHash:(UInt256)blockHash {
    return [self masternodeListForBlockHash:blockHash withBlockHeightLookup:nil];
}

- (DArcMasternodeList *)masternodeListForBlockHash:(UInt256)blockHash
                             withBlockHeightLookup:(BlockHeightFinder)blockHeightLookup {
    u256 *block_hash = u256_ctor_u(blockHash);
    DArcMasternodeList *list = dash_spv_masternode_processor_processing_processor_MasternodeProcessor_masternode_list_for_block_hash(self.processor, block_hash);
    return list;
}

- (DArcMasternodeList *)masternodeListBeforeBlockHash:(UInt256)blockHash {
    u256 *arr = u256_ctor_u(blockHash);
    DArcMasternodeList *list = dash_spv_masternode_processor_processing_processor_MasternodeProcessor_masternode_list_before_block_hash(self.processor, arr);
    return list;
}

// MARK: - Requesting Masternode List

- (void)startSync {
    DSLog(@"[%@] [DSMasternodeManager] startSync", self.chain.name);
    self.isSyncing = YES;
    [self getRecentMasternodeList];
}

- (void)stopSync {
    DSLog(@"[%@] [DSMasternodeManager] stopSync", self.chain.name);
    self.isSyncing = NO;
    [self cancelMasternodeListTimer];
    dash_spv_masternode_processor_processing_processor_cache_MasternodeProcessorCache_clear_current_lists(self.chain.shareCore.cache->obj);
    if (self.chain.isRotatedQuorumsPresented) {
        [self.quorumRotationService stop];
    }
    [self.masternodeListDiffService stop];
}

- (void)getRecentMasternodeList {
    DSLog(@"[%@] getRecentMasternodeList at tip", self.chain.name);
    [self.masternodeListDiffService getRecentMasternodeList];
    if (self.chain.isRotatedQuorumsPresented) {
        [self.quorumRotationService getRecentMasternodeList];
    }

}

// the safety delay checks to see if this was called in the last n seconds.
- (void)getCurrentMasternodeListWithSafetyDelay:(uint32_t)safetyDelay {
    self.timeIntervalForMasternodeRetrievalSafetyDelay = [[NSDate date] timeIntervalSince1970];
    [self cancelMasternodeListTimer];
    @synchronized (self) {
        self.masternodeListTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.chain.networkingQueue);
        if (self.masternodeListTimer) {
            dispatch_source_set_timer(self.masternodeListTimer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(safetyDelay * NSEC_PER_SEC)), DISPATCH_TIME_FOREVER, 1ull * NSEC_PER_SEC);
            dispatch_source_set_event_handler(self.masternodeListTimer, ^{
                NSTimeInterval timeElapsed = [[NSDate date] timeIntervalSince1970] - self.timeIntervalForMasternodeRetrievalSafetyDelay;
                if (timeElapsed > safetyDelay) {
                    [self getRecentMasternodeList];
                }
            });
            dispatch_resume(self.masternodeListTimer);
        }
    }
}
- (void)cancelMasternodeListTimer {
    @synchronized (self) {
        if (self.masternodeListTimer) {
            dispatch_source_cancel(self.masternodeListTimer);
            self.masternodeListTimer = nil;
        }
    }
}

- (BOOL)requestMasternodeListForBlockHeight:(uint32_t)blockHeight error:(NSError **)error {
    DSMerkleBlock *merkleBlock = [self.chain blockAtHeight:blockHeight];
    if (!merkleBlock) {
        if (error) {
            *error = [NSError errorWithCode:600 localizedDescriptionKey:@"Unknown block"];
        }
        return FALSE;
    }
    UInt256 blockHash = merkleBlock.blockHash;
    u256 *block_hash = u256_ctor_u(blockHash);
    dash_spv_masternode_processor_processing_processor_cache_MasternodeProcessorCache_set_last_queried_block_hash(self.chain.shareCore.cache->obj, block_hash);
    dash_spv_masternode_processor_processing_processor_cache_MasternodeProcessorCache_add_block_hash_for_list_needing_quorums_validated(self.chain.shareCore.cache->obj, block_hash);
    dash_spv_masternode_processor_processing_processor_MasternodeProcessor_add_to_mn_list_retrieval_queue(self.chain.shareCore.processor->obj, block_hash);
    [self.masternodeListDiffService dequeueMasternodeListRequest];
    return TRUE;
}

- (BOOL)processRequestFromFileForBlockHash:(UInt256)blockHash {
    DSCheckpoint *checkpoint = [self.chain checkpointForBlockHash:blockHash];
    if (!checkpoint || !checkpoint.masternodeListName || [checkpoint.masternodeListName isEqualToString:@""]) {
        return NO;
    }
    NSString *bundlePath = [[NSBundle bundleForClass:self.class] pathForResource:@"DashSync" ofType:@"bundle"];
    NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
    NSString *masternodeListName = checkpoint.masternodeListName;
    NSString *filePath = [bundle pathForResource:masternodeListName ofType:@"dat"];
    if (!filePath) {
        return NO;
    }
    NSData *message = [NSData dataWithContentsOfFile:filePath];

    if (!message) {
        return NO;
    }
    Slice_u8 *message_slice = slice_ctor(message);
    DMnDiffResult *result = dash_spv_masternode_processor_processing_processor_MasternodeProcessor_mn_list_diff_result_from_file(self.processor, message_slice, [checkpoint protocolVersion]);

    DSMerkleBlock *block = [self.chain blockForBlockHash:blockHash];
    if (result->error) {
        DSLog(@"[%@] ProcessingError while reading %@ for block at height %u with merkleRoot %@", self.chain.name, masternodeListName, block.height, uint256_hex(block.merkleRoot));
        DMnDiffResultDtor(result);
       return NO;
    }
    DMnDiffResultDtor(result);
    return YES;
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

- (void)peer:(DSPeer *)peer relayedMasternodeDiffMessage:(NSData *)message {
    DSLog(@"[%@: %@:%d] •••• -> received mnlistdiff: %@", self.chain.name, peer.host, peer.port, uint256_hex(message.SHA256));
    @synchronized (self.masternodeListDiffService) {
        self.masternodeListDiffService.timedOutAttempt = 0;
    }
    dispatch_async(self.processingQueue, ^{
        dispatch_group_enter(self.processingGroup);
        SLICE *message_slice = slice_ctor(message);
        DMnDiffResult *result = dash_spv_masternode_processor_processing_processor_MasternodeProcessor_mn_list_diff_result_from_message(self.processor, message_slice, false, peer ? peer.version : self.chain.protocolVersion, false, ((__bridge void *)(peer)));
        
        if (result->error) {
            uint8_t error_index = DProcessingErrorIndex(result->error);

            DSLog(@"[%@] Processing status (mndiff): %ul", self.chain.name, error_index);
            switch (error_index) {
                case dash_spv_masternode_processor_processing_processing_error_ProcessingError_MissingLists:
                    break;
                case dash_spv_masternode_processor_processing_processing_error_ProcessingError_InvalidResult:
                    [self.masternodeListDiffService cleanRequestsInRetrieval];
                    [self.masternodeListDiffService dequeueMasternodeListRequest];
                default:
                    [self.masternodeListDiffService issueWithMasternodeListFromPeer:peer];
                    break;
            }
            DMnDiffResultDtor(result);
            dispatch_group_leave(self.processingGroup);
            return;
        }
        u256 *block_hash = result->ok->o_1;
        NSData *masternodeListBlockHashData = NSDataFromPtr(block_hash);
        bool has_added_rotated_quorums = result->ok->o_2;
        UInt256 masternodeListBlockHash = u256_cast(block_hash);
        if (has_added_rotated_quorums && !self.chain.isRotatedQuorumsPresented) {
            uint32_t masternodeListBlockHeight = [self heightForBlockHash:masternodeListBlockHash];
            self.chain.isRotatedQuorumsPresented = YES;
            self.rotatedQuorumsActivationHeight = masternodeListBlockHeight;
            if (self.isSyncing) {
                dash_spv_masternode_processor_processing_processor_MasternodeProcessor_add_to_qr_info_retrieval_queue(self.chain.shareCore.processor->obj, block_hash);
                [self.quorumRotationService dequeueMasternodeListRequest];
            }
        }
        if (self.isSyncing)
            [self.masternodeListDiffService updateAfterProcessingMasternodeListWithBlockHash:masternodeListBlockHashData fromPeer:peer];

#if SAVE_MASTERNODE_DIFF_TO_FILE
        u256 *base_block_hash = result->ok->o_0;
        uint32_t base_block_height = DHeightForBlockHash(self.chain.shareCore.processor->obj, base_block_hash);
        uint32_t block_height = DHeightForBlockHash(self.chain.shareCore.processor->obj, block_hash);
        NSString *fileName = [NSString stringWithFormat:@"MNL_%@_%@__%d.dat", @(base_block_height), @(block_height), peer.version];
        DSLog(@"[%@] •-• File %@ saved", self.chain.name, fileName);
        [message saveToFile:fileName inDirectory:NSCachesDirectory];
#endif
        DMnDiffResultDtor(result);
        dispatch_group_leave(self.processingGroup);
    });
}

- (void)peer:(DSPeer *)peer relayedQuorumRotationInfoMessage:(NSData *)message {
    DSLog(@"[%@: %@:%d] •••• -> received qrinfo: %@", self.chain.name, peer.host, peer.port, uint256_hex(message.SHA256));
    @synchronized (self.quorumRotationService) {
        self.quorumRotationService.timedOutAttempt = 0;
    }
    uint32_t protocol_version = peer ? peer.version : self.chain.protocolVersion;
    dispatch_async(self.processingQueue, ^{
        dispatch_group_enter(self.processingGroup);
        SLICE *slice_msg = slice_ctor(message);
        DQRInfoResult *result = dash_spv_masternode_processor_processing_processor_MasternodeProcessor_qr_info_result_from_message(self.processor, slice_msg, false, protocol_version, self.chain.isRotatedQuorumsPresented, false, ((__bridge void *)(peer)));
        if (result->error || !result->ok) {
            uint8_t index = DProcessingErrorIndex(result->error);
            DSLog(@"[%@] •••• Processing status (qrinfo): %u", self.chain.name, index);
            DQRInfoResultDtor(result);
            if (index == dash_spv_masternode_processor_processing_processing_error_ProcessingError_InvalidResult) {
                [self.quorumRotationService issueWithMasternodeListFromPeer:peer];
            }
            dispatch_group_leave(self.processingGroup);
            return;
        }
        u256 *block_hash = result->ok->o_1;

#if SAVE_MASTERNODE_DIFF_TO_FILE
        u256 *base_block_hash = result->ok->o_0;
        uint32_t base_block_height = DHeightForBlockHash(self.chain.shareCore.processor->obj, base_block_hash);
        uint32_t block_height = DHeightForBlockHash(self.chain.shareCore.processor->obj, block_hash);
        NSString *fileName = [NSString stringWithFormat:@"QRINFO_%@_%@__%d.dat", @(base_block_height), @(block_height), peer.version];
        DSLog(@"[%@] •-• File %@ saved", self.chain.name, fileName);
        [message saveToFile:fileName inDirectory:NSCachesDirectory];
#endif
        [self.quorumRotationService updateAfterProcessingMasternodeListWithBlockHash:NSDataFromPtr(block_hash) fromPeer:peer];
        DQRInfoResultDtor(result);
        dispatch_group_leave(self.processingGroup);
    });
}

+ (void)saveMasternodeList:(DArcMasternodeList *)masternodeList
                   toChain:(DSChain *)chain
 havingModifiedMasternodes:(DMasternodeEntryMap *)modifiedMasternodes
       createUnknownBlocks:(BOOL)createUnknownBlocks
                 inContext:(NSManagedObjectContext *)context
                completion:(void (^)(NSError *error))completion {
    NSError *err = [DSMasternodeListStore saveMasternodeList:masternodeList
                                      toChain:chain
                    havingModifiedMasternodes:modifiedMasternodes
                          createUnknownBlocks:createUnknownBlocks
                                    inContext:context];
    completion(err);
}

// MARK: - Quorums

- (DLLMQEntry *)quorumEntryForChainLockRequestID:(UInt256)requestID
                           withBlockHeightOffset:(uint32_t)blockHeightOffset {
    DSMerkleBlock *merkleBlock = [self.chain blockFromChainTip:blockHeightOffset];
    return [self quorumEntryForChainLockRequestID:requestID forMerkleBlock:merkleBlock];
}

- (DLLMQEntry *)quorumEntryForChainLockRequestID:(UInt256)requestID
                                  forBlockHeight:(uint32_t)blockHeight {
    DSMerkleBlock *merkleBlock = [self.chain blockAtHeight:blockHeight];
    return [self quorumEntryForChainLockRequestID:requestID forMerkleBlock:merkleBlock];
}

- (DLLMQEntry *)quorumEntryForChainLockRequestID:(UInt256)requestID
                                  forMerkleBlock:(DSMerkleBlock *)merkleBlock {
    u256 *request_id = u256_ctor_u(requestID);
    u256 *block_hash = u256_ctor_u(merkleBlock.blockHash);
    DLLMQEntry *entry = dash_spv_masternode_processor_processing_processor_MasternodeProcessor_quorum_entry_for_chain_lock_request_id(self.processor, request_id, block_hash, merkleBlock.height);
    return entry;
}

- (DLLMQEntry *)quorumEntryForInstantSendRequestID:(UInt256)requestID
                             withBlockHeightOffset:(uint32_t)blockHeightOffset {
    DSMerkleBlock *merkleBlock = [self.chain blockFromChainTip:blockHeightOffset];
    u256 *request_id = u256_ctor_u(requestID);
    u256 *block_hash = u256_ctor_u(merkleBlock.blockHash);
    DLLMQEntry *entry = dash_spv_masternode_processor_processing_processor_MasternodeProcessor_quorum_entry_for_instant_send_request_id(self.processor, request_id, block_hash, merkleBlock.height);
    return entry;
}

- (DLLMQEntry *)quorumEntryForPlatformHavingQuorumHash:(UInt256)quorumHash
                                        forBlockHeight:(uint32_t)blockHeight {
    u256 *quorum_hash = u256_ctor_u(quorumHash);
    DLLMQEntry *entry = dash_spv_masternode_processor_processing_processor_MasternodeProcessor_quorum_entry_for_platform_having_quorum_hash(self.processor, quorum_hash, blockHeight);
    return entry;
}

// MARK: - Meta information

- (void)checkPingTimesForCurrentMasternodeListInContext:(NSManagedObjectContext *)context
                                         withCompletion:(void (^)(NSMutableDictionary<NSData *, NSNumber *> *pingTimes, NSMutableDictionary<NSData *, NSError *> *errors))completion {
//    __block NSArray<DSSimplifiedMasternodeEntry *> *entries = self.currentMasternodeList.simplifiedMasternodeEntries;
//    [self.chain.chainManager.DAPIClient checkPingTimesForMasternodes:entries
//                                                          completion:^(NSMutableDictionary<NSData *, NSNumber *> *_Nonnull pingTimes, NSMutableDictionary<NSData *, NSError *> *_Nonnull errors) {
//        [self.store savePlatformPingInfoForEntries:entries inContext:context];
//        if (completion != nil) {
//            dispatch_async(dispatch_get_main_queue(), ^{
//                completion(pingTimes, errors);
//            });
//        }
//    }];

}

@end
