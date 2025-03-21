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
#import "DSLocalMasternodeEntity+CoreDataClass.h"
#import "DSMasternodeListService+Protected.h"
#import "DSMasternodeListDiffService.h"
#import "DSQuorumRotationService.h"
#import "DSMerkleBlock.h"
#import "DSMerkleBlockEntity+CoreDataClass.h"
#import "DSOptionsManager.h"
#import "DSPeerManager+Protected.h"
#import "DSTransactionManager+Protected.h"
#import "NSArray+Dash.h"
#import "NSError+Dash.h"
#import "NSError+Platform.h"
#import "NSSet+Dash.h"
#import "NSObject+Notification.h"

#define ENGINE_STORAGE_LOCATION(chain) [NSString stringWithFormat:@"MNL_ENGINE_%@.dat", chain.name]

#define SAVE_MASTERNODE_DIFF_TO_FILE (1 && DEBUG)


@interface DSMasternodeManager ()

@property (nonatomic, strong) DSChain *chain;
@property (nonatomic, strong) DSMasternodeListDiffService *masternodeListDiffService;
@property (nonatomic, strong) DSQuorumRotationService *quorumRotationService;
@property (nonatomic, assign) NSTimeInterval timeIntervalForMasternodeRetrievalSafetyDelay;
@property (nonatomic, assign) uint32_t rotatedQuorumsActivationHeight;
@property (nonatomic, strong) dispatch_group_t processingGroup;
@property (nonatomic, strong) dispatch_queue_t processingQueue;
@property (nonatomic, strong) dispatch_source_t masternodeListTimer;
@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;
@property (nonatomic) BOOL isSyncing;
@property (nonatomic) BOOL isRestored;

@end


@implementation DSMasternodeManager

- (instancetype)initWithChain:(DSChain *)chain {
    NSParameterAssert(chain);
    if (!(self = [super init])) return nil;
    _chain = chain;
    self.masternodeListDiffService = [[DSMasternodeListDiffService alloc] initWithChain:chain];
    self.quorumRotationService = [[DSQuorumRotationService alloc] initWithChain:chain];
    _rotatedQuorumsActivationHeight = UINT32_MAX;
    _processingGroup = dispatch_group_create();
    _processingQueue = dispatch_queue_create([[NSString stringWithFormat:@"org.dashcore.dashsync.processing.%@", uint256_data(self.chain.genesisHash).shortHexString] UTF8String], DISPATCH_QUEUE_SERIAL);
    self.managedObjectContext = chain.chainManagedObjectContext;
    return self;
}

- (MasternodeProcessor *)processor {
    return self.chain.sharedProcessorObj;
}

- (NSString *)logPrefix {
    return [NSString stringWithFormat:@"[%@] [MasternodeManager] ", self.chain.name];
}

- (BOOL)hasCurrentMasternodeListInLast30Days {
    DMasternodeList *list = self.currentMasternodeList;
    BOOL has = list && [[NSDate date] timeIntervalSince1970] - [self.chain timestampForBlockHeight:list->known_height] < DAY_TIME_INTERVAL * 30;
    if (list)
        DMasternodeListDtor(list);
    return has;
}


#pragma mark - DSMasternodeListServiceDelegate


- (void)masternodeListServiceEmptiedRetrievalQueue:(DSMasternodeListService *)service {
//    BOOL has_last_queried_list_at_tip = dash_spv_masternode_processor_processing_processor_cache_MasternodeProcessorCache_has_last_queried_qr_masternode_list_at_h(self.cache);
//    uintptr_t mndiff_count = DMnDiffQueueCount(self.cache);
//    uintptr_t qrinfo_count = DQrInfoQueueCount(self.cache);
//    DSLog(@"%@ Masternode List Service emptied retrieval queue: mndiff: %lu, qrinfo: %lu tip queried? %u ", self.logPrefix, mndiff_count, qrinfo_count, has_last_queried_list_at_tip);
//    DSLog(@"•••••••••••••••••••••••••••••••••••••••••••••••••••••••••••");
//    dash_spv_masternode_processor_processing_processor_cache_MasternodeProcessorCache_print_description(self.cache);
//    DSLog(@"•••••••••••••••••••••••••••••••••••••••••••••••••••••••••••");
//    if (!mndiff_count) {
//        if (!qrinfo_count)
//            [self.store removeOldMasternodeLists];
//        if (has_last_queried_list_at_tip) {
//            [self.chain.chainManager chainFinishedSyncingMasternodeListsAndQuorums:self.chain];
//        }
//    }
}


// MARK: - Helpers

- (NSUInteger)knownMasternodeListsCount {
    return DKnownMasternodeListsCount(self.processor);
}

- (uint32_t)lastMasternodeListBlockHeight {
    return DCurrentMasternodeListBlockHeight(self.processor);
}

- (uint32_t)heightForBlockHash:(UInt256)blockhash {
    return [self.chain heightForBlockHash:blockhash];
}

- (BOOL)isMasternodeListOutdated {
    uint32_t lastHeight = self.lastMasternodeListBlockHeight;
    return lastHeight == UINT32_MAX || lastHeight < self.chain.lastTerminalBlockHeight - 8;
}

- (DMasternodeEntry *)masternodeHavingProviderRegistrationTransactionHash:(NSData *)providerRegistrationTransactionHash {
    NSParameterAssert(providerRegistrationTransactionHash);
    dashcore_hash_types_ProTxHash *pro_tx_hash = dashcore_hash_types_ProTxHash_ctor(u256_ctor(providerRegistrationTransactionHash));
    return dash_spv_masternode_processor_processing_processor_MasternodeProcessor_current_masternode_list_masternode_with_pro_reg_tx_hash(self.processor, pro_tx_hash);
}

- (NSUInteger)simplifiedMasternodeEntryCount {
    return dash_spv_masternode_processor_processing_processor_MasternodeProcessor_current_masternode_list_masternode_count(self.processor);
}

- (NSUInteger)activeQuorumsCount {
    return dash_spv_masternode_processor_processing_processor_MasternodeProcessor_current_masternode_list_quorum_count(self.processor);
}

- (BOOL)hasMasternodeAtLocation:(UInt128)IPAddress port:(uint32_t)port {
    u128 *addr = u128_ctor_u(IPAddress);
    BOOL result = dash_spv_masternode_processor_processing_processor_MasternodeProcessor_has_masternode_at_location(self.processor, addr, port);
    return result;
}
- (DMasternodeEntry *)masternodeAtLocation:(UInt128)IPAddress port:(uint32_t)port {
    SocketAddr *addr = dash_spv_masternode_processor_processing_socket_addr_v4_ctor(u128_ctor_u(IPAddress), port);
    return dash_spv_masternode_processor_processing_processor_MasternodeProcessor_masternode_at_location(self.processor, addr);
}

- (NSUInteger)masternodeListRetrievalQueueCount {
    return [self.masternodeListDiffService retrievalQueueCount];
}

- (NSUInteger)masternodeListRetrievalQueueMaxAmount {
    return [self.masternodeListDiffService retrievalQueueMaxAmount];
}

- (BOOL)currentMasternodeListIsInLast24Hours {
    DMasternodeList *list = self.currentMasternodeList;
    if (!list) return NO;
    u256 *block_hash = dashcore_hash_types_BlockHash_inner(list->block_hash);
    DSBlock *block = [self.chain blockForBlockHash:u256_cast(block_hash)];
    u256_dtor(block_hash);
    DMasternodeListDtor(list);
    if (!block) return NO;
    NSTimeInterval currentTimestamp = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval delta = currentTimestamp - block.timestamp;
    return fabs(delta) < DAY_TIME_INTERVAL;
}


// MARK: - Set Up and Tear Down

- (NSData *)readFromDisk:(NSString *)location {
    NSString *bundlePath = [[NSBundle bundleForClass:self.class] pathForResource:@"DashSync" ofType:@"bundle"];
    NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
    NSString *filePath = [bundle pathForResource:location ofType:@"dat"];
    return filePath ? [NSData dataWithContentsOfFile:filePath] : nil;
}

- (BOOL)restoreEngine {
    NSData *engineBytes = [self readFromDisk:ENGINE_STORAGE_LOCATION(self.chain)];
    if (engineBytes) {
        Slice_u8 *bytes = slice_ctor(engineBytes);
        DMnEngineDeserializationResult *result = dash_spv_masternode_processor_processing_processor_MasternodeProcessor_deserialize_engine(self.processor, bytes);
        BOOL success = !result->error;
        if (success) {
            DSLog(@"%@ restoreEngine: Ok: (%lu bytes)", self.logPrefix, result->ok[0]);
        } else {
            DSLog(@"%@ restoreEngine: Error: %@", self.logPrefix, [NSError ffi_from_processing_error:result->error]);
        }
        DMnEngineDeserializationResultDtor(result);
        return success;
        
    } else {
        return NO;
    }
}

- (BOOL)restoreFromCheckpoint {
    DSCheckpoint *checkpoint = [self.chain lastCheckpointHavingMasternodeList];
    if (!checkpoint || !checkpoint.masternodeListName || [checkpoint.masternodeListName isEqualToString:@""])
        return NO;
    NSData *message = [self readFromDisk:checkpoint.masternodeListName];
    if (!message)
        return NO;
    Slice_u8 *message_slice = slice_ctor(message);
    DMnDiffResult *result = DMnDiffFromMessage(self.processor, message_slice, nil, false);
    
    if (result->error) {
        NSError *error = [NSError ffi_from_processing_error:result->error];
        DSLog(@"%@ processRequestFromFileForBlockHash Error: %@", self.logPrefix, error);
        DMnDiffResultDtor(result);
        return NO;
    }
    DMnDiffResultDtor(result);
    return YES;
}

- (BOOL)restoreState {
    BOOL restored = [self restoreEngine];
    if (!restored) {
        DSLog(@"%@ No Engine Stored", self.logPrefix);
//        restored = [self restoreFromCheckpoint];
//        if (!restored)
//            DSLog(@"%@ No Checkpoint Stored", self.logPrefix);
    }
    if (restored) {
        DMasternodeList *current_list = [self currentMasternodeList];
        DSLog(@"%@ Engine restored: %u/%u", self.logPrefix, restored, current_list ? current_list->known_height : 0);

        [self notify:DSCurrentMasternodeListDidChangeNotification userInfo:@{
            DSChainManagerNotificationChainKey: self.chain,
            DSMasternodeManagerNotificationMasternodeListKey: current_list ? [NSValue valueWithPointer:current_list] : [NSNull null]
        }];
        self.isRestored = YES;
    }
    return restored;
}

- (NSSet<NSData *> *)blockHashesUsedByMasternodeLists {
    Vec_u8_32 *result = dash_spv_masternode_processor_processing_processor_MasternodeProcessor_used_block_hashes(self.processor);
    NSSet<NSData *> *blockHashes = [NSSet ffi_from_vec_u256:result];
    Vec_u8_32_destroy(result);
    return blockHashes;
}

- (void)setUp {
    [self restoreState];
    [DSLocalMasternodeEntity loadLocalMasternodesInContext:self.managedObjectContext onChainEntity:[self.chain chainEntityInContext:self.managedObjectContext]];
}

- (void)reloadMasternodeLists {
    DProcessorClear(self.processor);
    [self.chain.chainManager notifyMasternodeSyncStateChange:UINT32_MAX storedCount:0];
    [self restoreState];
}

- (BOOL)hasBlockForBlockHash:(NSData *)blockHashData {
    UInt256 blockHash = blockHashData.UInt256;
    BOOL hasBlock = [self.chain blockForBlockHash:blockHash] != nil;
    if (!hasBlock) {
        hasBlock = [DSMerkleBlockEntity hasBlocksWithHash:blockHash inContext:self.managedObjectContext];
    }
    if (!hasBlock && self.chain.isTestnet) {
        //We can trust insight if on testnet
        [self.chain blockUntilGetInsightForBlockHash:blockHash];
        hasBlock = !![[self.chain insightVerifiedBlocksByHashDictionary] objectForKey:blockHashData];
    }
    return hasBlock;
}


//- (DMasternodeList *)reloadMasternodeListsWithBlockHeightLookup:(BlockHeightFinder)blockHeightLookup {
//    DProcessorClear(self.processor);
//    [self.chain.chainManager notifyMasternodeSyncStateChange:UINT32_MAX storedCount:0];
//
//    return [self loadMasternodeListsWithBlockHeightLookup:blockHeightLookup];
//}

- (DMasternodeList *)currentMasternodeList {
    return dash_spv_masternode_processor_processing_processor_MasternodeProcessor_current_masternode_list(self.processor);
}

//- (void)loadFileDistributedMasternodeLists {
//    BOOL syncMasternodeLists = [[DSOptionsManager sharedInstance] syncType] & DSSyncType_MasternodeList;
//    BOOL useCheckpointMasternodeLists = [[DSOptionsManager sharedInstance] useCheckpointMasternodeLists];
//    if (!syncMasternodeLists || !useCheckpointMasternodeLists)
//        return;
//    DMasternodeList *list = self.currentMasternodeList;
//    if (list) {
//        DMasternodeListDtor(list);
//        return;
//    }
//    DSCheckpoint *checkpoint = [self.chain lastCheckpointHavingMasternodeList];
//    if (!checkpoint ||
//        self.chain.lastTerminalBlockHeight < checkpoint.height ||
//        [self masternodeListForBlockHash:checkpoint.blockHash withBlockHeightLookup:nil]) {
//        return;
//    }
//    DSLog(@"%@ processRequestFromFileForBlockHash -> %@", self.logPrefix, uint256_hex(checkpoint.blockHash));
//    BOOL exist = [self processRequestFromFileForBlockHash:checkpoint.blockHash];
//    if (exist) {
////        TODO: re-implement
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
//
////        self.masternodeListDiffService.currentMasternodeList = result->ok->masternode_list;
//    }
//}

- (void)wipeMasternodeInfo {
    DSLog(@"%@ wipeMasternodeInfo", self.logPrefix);
    DProcessorClear(self.processor);
    [self.masternodeListDiffService cleanAllLists];
    [self.quorumRotationService cleanAllLists];
    [self.chain.chainManager notifyMasternodeSyncStateChange:UINT32_MAX storedCount:0];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DSMasternodeListDidChangeNotification
                                                            object:nil
                                                          userInfo:@{
            DSChainManagerNotificationChainKey: self.chain
        }];
        [[NSNotificationCenter defaultCenter] postNotificationName:DSQuorumListDidChangeNotification
                                                            object:nil
                                                          userInfo:@{
            DSChainManagerNotificationChainKey: self.chain
        }];
    });
}

// MARK: - Masternode List Helpers

- (DMasternodeList *)masternodeListForBlockHash:(UInt256)blockHash {
    return [self masternodeListForBlockHash:blockHash withBlockHeightLookup:nil];
}

- (DMasternodeList *)masternodeListForBlockHash:(UInt256)blockHash
                          withBlockHeightLookup:(BlockHeightFinder)blockHeightLookup {
    u256 *block_hash = u256_ctor_u(blockHash);
    DMasternodeList *list = DMasternodeListForBlockHash(self.processor, block_hash);
    return list;
}

// MARK: - Requesting Masternode List

- (void)startSync {
    DSLog(@"%@ [Start]", self.logPrefix);
    self.isSyncing = YES;
    if (!self.isRestored)
        [self restoreState];
    [self getRecentMasternodeList];
}

- (void)stopSync {
    DSLog(@"%@ [Stop]", self.logPrefix);
    self.isSyncing = NO;
    [self cancelMasternodeListTimer];

    if (self.chain.isRotatedQuorumsPresented) {
        [self.quorumRotationService stop];
    }
    [self.masternodeListDiffService stop];
}

- (void)getRecentMasternodeList {
    DSLog(@"%@ getRecentMasternodeList at tip (qr %u)", self.logPrefix, self.chain.isRotatedQuorumsPresented);
    DSMerkleBlock *merkleBlock = [self.chain blockFromChainTip:0];
    if (!merkleBlock) {
        // sometimes it happens while rescan
        DSLog(@"%@ getRecentMasternodeList: (no block exist) for tip", self.logPrefix);
        return;
    }
    [self.quorumRotationService getRecent:merkleBlock.blockHash];
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

- (BOOL)processRequestFromFileForBlockHash:(UInt256)blockHash {
    DSCheckpoint *checkpoint = [self.chain checkpointForBlockHash:blockHash];
    if (!checkpoint || !checkpoint.masternodeListName || [checkpoint.masternodeListName isEqualToString:@""])
        return NO;
    NSData *message = [self readFromDisk:checkpoint.masternodeListName];
    if (!message)
        return NO;
    Slice_u8 *message_slice = slice_ctor(message);
    DMnDiffResult *result = dash_spv_masternode_processor_processing_processor_MasternodeProcessor_process_mn_list_diff_result_from_message(self.processor, message_slice, nil, false);
    
    if (result->error) {
        NSError *error = [NSError ffi_from_processing_error:result->error];
        DSLog(@"%@ processRequestFromFileForBlockHash Error: %@", self.logPrefix, error);
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

- (void)issueWithMasternodeListFromPeer:(DSPeer *)peer {
    [self.chain.chainManager chain:self.chain badMasternodeListReceivedFromPeer:peer];
    NSArray *faultyPeers = [[NSUserDefaults standardUserDefaults] arrayForKey:CHAIN_FAULTY_DML_MASTERNODE_PEERS];
    if (faultyPeers.count >= MAX_FAULTY_DML_PEERS) {
        DSLog(@"%@ Exceeded max failures for masternode list, starting from scratch", self.logPrefix);
        //no need to remove local masternodes
        [self.masternodeListDiffService cleanListsRetrievalQueue];
        [self.quorumRotationService cleanListsRetrievalQueue];
//        [self.store deleteAllOnChain];
//        [self.store removeOldMasternodeLists];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:CHAIN_FAULTY_DML_MASTERNODE_PEERS];
        [self.chain.masternodeManager getRecentMasternodeList];
    } else {
        if (!faultyPeers) {
            faultyPeers = @[peer.location];
        } else if (![faultyPeers containsObject:peer.location]) {
            faultyPeers = [faultyPeers arrayByAddingObject:peer.location];
        }
        [[NSUserDefaults standardUserDefaults] setObject:faultyPeers forKey:CHAIN_FAULTY_DML_MASTERNODE_PEERS];
        DSLog(@"%@ Failure %lu for masternode list from peer: %@", self.logPrefix, (unsigned long)faultyPeers.count, peer);
        [self.quorumRotationService dequeueMasternodeListRequest];
    }
    [self.chain.chainManager notify:DSMasternodeListDiffValidationErrorNotification userInfo:@{DSChainManagerNotificationChainKey: self.chain}];
}


- (void)peer:(DSPeer *)peer relayedMasternodeDiffMessage:(NSData *)message {
    DSLog(@"%@ [%@:%d] mnlistdiff: received: %@", self.logPrefix, peer.host, peer.port, uint256_hex(message.SHA256));
    @synchronized (self.masternodeListDiffService) {
        self.masternodeListDiffService.timedOutAttempt = 0;
    }
    dispatch_async(self.processingQueue, ^{
        dispatch_group_enter(self.processingGroup);
        Slice_u8 *message_slice = slice_ctor(message);
        
        DMnDiffResult *result = DMnDiffFromMessage(self.processor, message_slice, nil, true);

        if (result->error) {
            NSError *error = [NSError ffi_from_processing_error:result->error];
            DSLog(@"%@ mnlistdiff: Error: %@", self.logPrefix, error.description);
            switch (result->error->tag) {
                case dash_spv_masternode_processor_processing_processor_processing_error_ProcessingError_MissingLists:
                case dash_spv_masternode_processor_processing_processor_processing_error_ProcessingError_LocallyStored:
                    break;
                case dash_spv_masternode_processor_processing_processor_processing_error_ProcessingError_InvalidResult:
                    [self.masternodeListDiffService cleanRequestsInRetrieval];
                    DSLog(@"%@ mnlistdiff: InvalidResult -> dequeueMasternodeListRequest (mn)", self.chain.name);
                    [self.masternodeListDiffService dequeueMasternodeListRequest];
                default:
                    [self issueWithMasternodeListFromPeer:peer];
                    break;
            }
//#if SAVE_MASTERNODE_DIFF_TO_FILE
//        NSString *fileName = [NSString stringWithFormat:@"MNL_ERR__%d.dat", peer.version];
//        DSLog(@"%@ •-• File %@ saved", self.logPrefix, fileName);
//        [message saveToFile:fileName inDirectory:NSCachesDirectory];
//#endif

            DMnDiffResultDtor(result);
            dispatch_group_leave(self.processingGroup);
            return;
        }
        if (self.isSyncing) {
            u256 *block_hash = dashcore_hash_types_BlockHash_inner(result->ok->o_1);
            NSData *blockHashData = NSDataFromPtr(block_hash);
            u256_dtor(block_hash);
            [self.masternodeListDiffService removeFromRetrievalQueue:blockHashData];
            [self.masternodeListDiffService dequeueMasternodeListRequest];
            if (![self.masternodeListDiffService retrievalQueueCount])
                [self.chain.chainManager.transactionManager checkWaitingForQuorums];
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:CHAIN_FAULTY_DML_MASTERNODE_PEERS];

//            [self.masternodeListDiffService updateAfterProcessingMasternodeListWithBlockHash:masternodeListBlockHashData fromPeer:peer];
        }
//#if SAVE_MASTERNODE_DIFF_TO_FILE
//        u256 *base_block_hash = result->ok->o_0;
//        uint32_t base_block_height = DHeightForBlockHash(self.processor, base_block_hash);
//        uint32_t block_height = DHeightForBlockHash(self.processor, block_hash);
//        NSString *fileName = [NSString stringWithFormat:@"MNL_%@_%@__%d.dat", @(base_block_height), @(block_height), peer.version];
//        DSLog(@"%@ •-• File %@ saved", self.logPrefix, fileName);
//        [message saveToFile:fileName inDirectory:NSCachesDirectory];
//#endif
//        DMnDiffResultDtor(result);
        DMnDiffResultDtor(result);

        dispatch_group_leave(self.processingGroup);
    });
}

- (void)saveMessage:(NSData *)message name:(NSString *)fileName {
    DSLog(@"%@ •-• File %@ saved", self.logPrefix, fileName);
    [message saveToFile:fileName inDirectory:NSCachesDirectory];
}

- (void)tryToProcessQrInfo:(DSPeer *)peer message:(NSData *)message attempt:(uint8_t)attempt {
    //    uint32_t protocol_version = peer ? peer.version : self.chain.protocolVersion;
    __block NSUInteger numOfAttempt = attempt;
        dispatch_async(self.processingQueue, ^{
            dispatch_group_enter(self.processingGroup);
            Slice_u8 *slice_msg = slice_ctor(message);
            
            DQRInfoResult *result = dash_spv_masternode_processor_processing_processor_MasternodeProcessor_process_qr_info_result_from_message(self.processor, slice_msg, true);
            if (result->error) {
                NSError *error = [NSError ffi_from_processing_error:result->error];
                DSLog(@"%@ qrinfo: Error: %@", self.logPrefix, error);
                switch (result->error->tag) {
                    case dash_spv_masternode_processor_processing_processor_processing_error_ProcessingError_InvalidResult:
                        [self issueWithMasternodeListFromPeer:peer];
                        break;
                    case dash_spv_masternode_processor_processing_processor_processing_error_ProcessingError_LocallyStored:
                        [self.quorumRotationService cleanListsRetrievalQueue];
                        break;
                    case dash_spv_masternode_processor_processing_processor_processing_error_ProcessingError_UnknownBlockHash:
                        break;
                    case dash_spv_masternode_processor_processing_processor_processing_error_ProcessingError_QuorumValidationError:
                        switch (result->error->quorum_validation_error->tag) {
                            case dashcore_sml_quorum_validation_error_QuorumValidationError_RequiredBlockNotPresent: {
                                dashcore_hash_types_BlockHash *unknown_block_hash = result->error->quorum_validation_error->required_block_not_present;
                                // TODO: it can be tip so we can wait for 300ms and try again
                                if (attempt < 3) {
                                    sleep(10);
                                    numOfAttempt++;
                                    dispatch_group_leave(self.processingGroup);
                                    [self tryToProcessQrInfo:peer message:message attempt:attempt];
                                }
                                break;
                            }
                            default:
                                break;
                        }
                        break;
                    default:
                        break;
                }
    //        #if SAVE_MASTERNODE_DIFF_TO_FILE
    //                NSString *fileName = [NSString stringWithFormat:@"QRINFO_ERR_%d.dat", peer.version];
    //                DSLog(@"%@ •-• File %@ saved", self.logPrefix, fileName);
    //                [message saveToFile:fileName inDirectory:NSCachesDirectory];
    //        #endif

                DQRInfoResultDtor(result);
                dispatch_group_leave(self.processingGroup);
                return;
            }
            std_collections_BTreeSet_dashcore_hash_types_BlockHash *missed_hashes = result->ok;
            
            if (missed_hashes->count > 0) {
                NSArray<NSData *> *missedHashes = [NSArray ffi_from_block_hash_btree_set:missed_hashes];
                [self.masternodeListDiffService addToRetrievalQueueArray:missedHashes];
            }

    //#if SAVE_MASTERNODE_DIFF_TO_FILE
    //        u256 *base_block_hash = result->ok->o_0;
    //        uint32_t base_block_height = DHeightForBlockHash(self.processor, base_block_hash);
    //        uint32_t block_height = DHeightForBlockHash(self.processor, block_hash);
    //        NSString *fileName = [NSString stringWithFormat:@"QRINFO_%@_%@__%d.dat", @(base_block_height), @(block_height), peer.version];
    //        DSLog(@"%@ •-• File %@ saved", self.logPrefix, fileName);
    //        [message saveToFile:fileName inDirectory:NSCachesDirectory];
    //#endif
    //        [self.quorumRotationService updateAfterProcessingMasternodeListWithBlockHash:NSDataFromPtr(block_hash) fromPeer:peer];
            
            [self.quorumRotationService cleanListsRetrievalQueue];
            [self.quorumRotationService dequeueMasternodeListRequest];
            if (missed_hashes->count == 0)
                [self.chain.chainManager.transactionManager checkWaitingForQuorums];
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:CHAIN_FAULTY_DML_MASTERNODE_PEERS];

            
            DQRInfoResultDtor(result);
            dispatch_group_leave(self.processingGroup);
        });
}

- (void)peer:(DSPeer *)peer relayedQuorumRotationInfoMessage:(NSData *)message {
    DSLog(@"%@ [%@:%d] qrinfo: received: %@", self.logPrefix, peer.host, peer.port, uint256_hex(message.SHA256));
    @synchronized (self.quorumRotationService) {
        self.quorumRotationService.timedOutAttempt = 0;
    }
    
    [self tryToProcessQrInfo:peer message:message attempt:0];
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
