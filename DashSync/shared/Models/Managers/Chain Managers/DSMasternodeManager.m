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

#define SAVE_MASTERNODE_DIFF_TO_FILE (0 && DEBUG)
#define SAVE_MASTERNODE_DIFF_ERROR_TO_FILE (1 && DEBUG)
#define SAVE_ERROR_STATE (0 && DEBUG)
#define RESTORE_FROM_CHECKPOINT (0 && DEBUG)


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
@property (nonatomic) BOOL hasHandledQrInfoPipeline;
@property (nonatomic) BOOL isPendingValidation;

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
    return [NSString stringWithFormat:@"[%@] [MasternodeManager]", self.chain.name];
}

- (BOOL)hasCurrentMasternodeListInLast30Days {
    DMasternodeList *list = self.currentMasternodeList;
    BOOL has = list && [[NSDate date] timeIntervalSince1970] - [self.chain timestampForBlockHeight:list->known_height] < DAY_TIME_INTERVAL * 30;
    if (list)
        DMasternodeListDtor(list);
    return has;
}


#pragma mark - DSMasternodeListServiceDelegate


// always from chain.networkingQueue
- (void)masternodeListServiceEmptiedRetrievalQueue:(DSMasternodeListService *)service {
    if (!self.isPendingValidation) {
        [self.chain.chainManager.syncState removeSyncKind:DSSyncStateExtKind_Masternodes];
        [self.chain.chainManager chainFinishedSyncingMasternodeListsAndQuorums:self.chain];
    }
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
    return lastHeight == UINT32_MAX || lastHeight < self.chain.lastTerminalBlockHeight;
}

- (BOOL)isQRInfoOutdated {
    return dash_spv_masternode_processor_processing_processor_MasternodeProcessor_is_qr_info_outdated(self.processor, self.chain.lastTerminalBlockHeight);
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
    SocketAddr *addr = DSocketAddrFrom(u128_ctor_u(IPAddress), port);
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
- (void)writeToDisk:(NSString *)location data:(NSData *)data {
    DSLog(@"%@ •-• File %@ saved", self.logPrefix, location);
    [data saveToFile:location inDirectory:NSCachesDirectory];
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

#if RESTORE_FROM_CHECKPOINT
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
#endif

// always from chain.networkingQueue
- (BOOL)restoreState {
    [self.chain.chainManager.syncState.masternodeListSyncInfo addSyncKind:DSMasternodeListSyncStateKind_Checkpoints];
    BOOL restored = [self restoreEngine];
    if (!restored) {
        DSLog(@"%@ No Engine Stored", self.logPrefix);
        #if RESTORE_FROM_CHECKPOINT
        // TODO: checkpoints don't work anymore, since old protocol version support was dropped
        restored = [self restoreFromCheckpoint];
        if (!restored)
            DSLog(@"%@ No Checkpoint Stored", self.logPrefix);
        #endif
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
    self.chain.chainManager.syncState.masternodeListSyncInfo.lastListHeight = DCurrentMasternodeListBlockHeight(self.processor);
    self.chain.chainManager.syncState.masternodeListSyncInfo.storedCount = (uint32_t) DKnownMasternodeListsCount(self.processor);
    [self.chain.chainManager.syncState.masternodeListSyncInfo removeSyncKind:DSMasternodeListSyncStateKind_Checkpoints];
    [self.chain.chainManager notifySyncStateChanged];
    return restored;
}

- (NSSet<NSData *> *)blockHashesUsedByMasternodeLists {
    std_collections_Map_keys_u32_values_u8_arr_32 *result = dash_spv_masternode_processor_processing_processor_MasternodeProcessor_known_block_hashes(self.processor);
    NSMutableSet<NSData *> *blockHashes = [NSMutableSet setWithCapacity:result->count];
    for (int i = 0; i < result->count; i++) {
        [blockHashes addObject:NSDataFromPtr(result->values[i])];
    }
    std_collections_Map_keys_u32_values_u8_arr_32_destroy(result);
    return blockHashes;
}

- (void)setUp {
    dispatch_async(self.chain.networkingQueue, ^{
        [self restoreState];
    });
    [DSLocalMasternodeEntity loadLocalMasternodesInContext:self.managedObjectContext onChainEntity:[self.chain chainEntityInContext:self.managedObjectContext]];
}

- (void)reloadMasternodeLists {
    DProcessorClear(self.processor);
    [self notify:DSCurrentMasternodeListDidChangeNotification userInfo:@{
        DSChainManagerNotificationChainKey: self.chain,
        DSMasternodeManagerNotificationMasternodeListKey: [NSNull null]
    }];
    dispatch_async(self.chain.networkingQueue, ^{
        [self.chain.chainManager notifyMasternodeSyncStateChange:UINT32_MAX storedCount:0];
        [self restoreState];
    });
}

- (DMasternodeList *)currentMasternodeList {
    return dash_spv_masternode_processor_processing_processor_MasternodeProcessor_current_masternode_list(self.processor);
}

- (void)wipeMasternodeInfo {
    DSLog(@"%@ wipeMasternodeInfo", self.logPrefix);
    DProcessorClear(self.processor);
    [self.masternodeListDiffService cleanAllLists];
    [self.quorumRotationService cleanAllLists];
    dash_spv_masternode_processor_processing_processor_MasternodeProcessor_reinit_engine(self.processor, self.chain.chainType, [self.chain createDiffConfig]);
    uint32_t lastListHeight = DCurrentMasternodeListBlockHeight(self.processor);
    uint32_t storedCount = (uint32_t) DKnownMasternodeListsCount(self.processor);
    DMasternodeList *current_list = [self currentMasternodeList];
    dispatch_async(self.chain.networkingQueue, ^{
//        [self.chain.chainManager.syncState.masternodeListSyncInfo resetSyncKind];
        self.chain.chainManager.syncState.masternodeListSyncInfo.queueCount = 0;
        self.chain.chainManager.syncState.masternodeListSyncInfo.queueMaxAmount = 0;
        self.chain.chainManager.syncState.masternodeListSyncInfo.lastListHeight = lastListHeight;
        self.chain.chainManager.syncState.masternodeListSyncInfo.storedCount = storedCount;
        [self.chain.chainManager notifySyncStateChanged];

        [self notifyCurrentListChanged:current_list];
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

// always from chain.networkingQueue
- (void)startSync {
    DSLog(@"%@ [Start]", self.logPrefix);
    self.isSyncing = YES;
    if (!self.isRestored)
        [self restoreState];
    [self getRecentMasternodeList];
    [self.chain.chainManager.syncState addSyncKind:DSSyncStateExtKind_Masternodes];
}

// always from chain.networkingQueue
- (void)stopSync {
    DSLog(@"%@ [Stop]", self.logPrefix);
    self.isSyncing = NO;
    [self cancelMasternodeListTimer];
    if (self.chain.isRotatedQuorumsPresented)
        [self.quorumRotationService stop];
    [self.masternodeListDiffService stop];
    
    self.chain.chainManager.syncState.masternodeListSyncInfo.queueCount = 0;
    self.chain.chainManager.syncState.masternodeListSyncInfo.queueMaxAmount = 0;
    [self.chain.chainManager.syncState.masternodeListSyncInfo resetSyncKind];
    [self.chain.chainManager.syncState removeSyncKind:DSSyncStateExtKind_Masternodes];
    [self.chain.chainManager notifySyncStateChanged];
}

- (void)getRecentMasternodeList {
    DSLog(@"%@ getRecentMasternodeList at tip (qr %u)", self.logPrefix, self.chain.isRotatedQuorumsPresented);
    DSMerkleBlock *merkleBlock = [self.chain blockFromChainTip:0];
    if (!merkleBlock) {
        // sometimes it happens while rescan
        DSLog(@"%@ getRecentMasternodeList: (no block exist) for tip", self.logPrefix);
        return;
    }
    NSData *blockHash = uint256_data(merkleBlock.blockHash);
    if (!self.isPendingValidation && (!self.hasHandledQrInfoPipeline || [self isQRInfoOutdated])) {
        [self.quorumRotationService getRecent:blockHash];
    }
    if (!self.isPendingValidation && self.hasHandledQrInfoPipeline && [self isMasternodeListOutdated]) {
        
        NSUInteger newCount = [self.masternodeListDiffService addToRetrievalQueue:blockHash];
        NSUInteger maxAmount = self.masternodeListDiffService.retrievalQueueMaxAmount;
        [self.masternodeListDiffService dequeueMasternodeListRequest];
        dispatch_async(self.chain.networkingQueue, ^{
            self.chain.chainManager.syncState.masternodeListSyncInfo.queueCount = (uint32_t) newCount;
            self.chain.chainManager.syncState.masternodeListSyncInfo.queueMaxAmount = (uint32_t) maxAmount;
            [self.chain.chainManager notifySyncStateChanged];
        });

        
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
                if (timeElapsed > safetyDelay && !self.isPendingValidation) {
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

- (void)issueWithMasternodeListFromPeer:(DSPeer *)peer {
    [self.chain.chainManager chain:self.chain badMasternodeListReceivedFromPeer:peer];
    NSArray *faultyPeers = [[NSUserDefaults standardUserDefaults] arrayForKey:CHAIN_FAULTY_DML_MASTERNODE_PEERS];
    if (faultyPeers.count >= MAX_FAULTY_DML_PEERS) {
        DSLog(@"%@ Exceeded max failures for masternode list, starting from scratch", self.logPrefix);
        //no need to remove local masternodes
        [self.masternodeListDiffService cleanListsRetrievalQueue];
        [self.quorumRotationService cleanListsRetrievalQueue];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:CHAIN_FAULTY_DML_MASTERNODE_PEERS];
        dispatch_async(self.chain.networkingQueue, ^{
            self.chain.chainManager.syncState.masternodeListSyncInfo.queueCount = 0;
            self.chain.chainManager.syncState.masternodeListSyncInfo.queueMaxAmount = 0;
            [self.chain.chainManager notifySyncStateChanged];
        });

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

- (void)printEngineStatus {
    dash_spv_masternode_processor_processing_processor_MasternodeProcessor_print_engine_status(self.processor);
}

- (NSError *_Nullable)verifyQuorums {
#if defined(DASHCORE_QUORUM_VALIDATION)
    DSLog(@"%@: Quorums Verification: Started", self.logPrefix);
    Result_ok_bool_err_dashcore_sml_quorum_validation_error_QuorumValidationError *result = dash_spv_masternode_processor_processing_processor_MasternodeProcessor_verify_current_masternode_list_quorums(self.processor);
    if (result->error) {
        NSError *quorumValidationError = [NSError ffi_from_quorum_validation_error:result->error];
        DSLog(@"%@ Quorums Verification: Error: %@", self.logPrefix, quorumValidationError.description);
        Result_ok_bool_err_dashcore_sml_quorum_validation_error_QuorumValidationError_destroy(result);
        return quorumValidationError;
    }
    DSLog(@"%@: Quorums Verification: Ok", self.logPrefix);
    Result_ok_bool_err_dashcore_sml_quorum_validation_error_QuorumValidationError_destroy(result);
#else
    DSLog(@"%@: Quorums Verification: Disabled", self.logPrefix);
#endif
    return nil;
}

- (void)peer:(DSPeer *)peer relayedMasternodeDiffMessage:(NSData *)message {
    //DSLog(@"%@ [%@:%d] mnlistdiff: received: %@", self.logPrefix, peer.host, peer.port, uint256_hex(message.SHA256));
    @synchronized (self.masternodeListDiffService) {
        self.masternodeListDiffService.timedOutAttempt = 0;
    }
    dispatch_async(self.processingQueue, ^{
        dispatch_group_enter(self.processingGroup);
        Slice_u8 *message_slice = slice_ctor(message);
        DMnDiffResult *result = DMnDiffFromMessage(self.processor, message_slice, nil, self.hasHandledQrInfoPipeline);
        
        if (result->error) {
            NSError *error = [NSError ffi_from_processing_error:result->error];
            DSLog(@"%@ mnlistdiff: Error: %@", self.logPrefix, error.description);
            switch (result->error->tag) {
                case dash_spv_masternode_processor_processing_processor_processing_error_ProcessingError_MissingLists:
                case dash_spv_masternode_processor_processing_processor_processing_error_ProcessingError_LocallyStored:
                    break;
                case dash_spv_masternode_processor_processing_processor_processing_error_ProcessingError_InvalidResult:
                    [self.masternodeListDiffService cleanRequestsInRetrieval];
                    [self.masternodeListDiffService dequeueMasternodeListRequest];
                default:
                    [self issueWithMasternodeListFromPeer:peer];
                    break;
            }
            #if SAVE_MASTERNODE_DIFF_ERROR_TO_FILE
            [self writeToDisk:[NSString stringWithFormat:@"MNL_ERR__%d_%f.dat", peer.version, [NSDate timeIntervalSinceReferenceDate]] data:message];
            #endif
            DMnDiffResultDtor(result);
            dispatch_group_leave(self.processingGroup);
            return;
        }

        [[NSUserDefaults standardUserDefaults] removeObjectForKey:CHAIN_FAULTY_DML_MASTERNODE_PEERS];
        if (self.isSyncing) {
            u256 *base_block_hash = dashcore_hash_types_BlockHash_inner(result->ok->o_0);
            u256 *block_hash = dashcore_hash_types_BlockHash_inner(result->ok->o_1);
            UInt256 baseBlockHash = u256_cast(base_block_hash);
            UInt256 blockHash = u256_cast(block_hash);
            DSLog(@"%@ MNLISTDIFF: OK: %@", self.logPrefix, uint256_hex(blockHash));
            #if SAVE_MASTERNODE_DIFF_TO_FILE
            [self writeToDisk:[NSString stringWithFormat:@"MNL_%@_%@__%d.dat", uint256_hex(baseBlockHash), uint256_hex(blockHash), peer.version] data:message];
            #endif
            u256_dtor(base_block_hash);
            u256_dtor(block_hash);
            uint32_t newCount = (uint32_t) [self.masternodeListDiffService removeFromRetrievalQueue:uint256_data(blockHash)];
            uint32_t maxQueueCount = (uint32_t) [self.masternodeListDiffService retrievalQueueMaxAmount];
            [self.masternodeListDiffService removeRequestInRetrievalForBaseBlockHash:baseBlockHash blockHash:blockHash];
            
            if ([self.masternodeListDiffService hasActiveQueue]) {
                uint32_t lastListHeight = DCurrentMasternodeListBlockHeight(self.processor);
                uint32_t storedCount = (uint32_t) DKnownMasternodeListsCount(self.processor);

                DMasternodeList *current_list = [self currentMasternodeList];
                dispatch_async(self.chain.networkingQueue, ^{
                    self.chain.chainManager.syncState.masternodeListSyncInfo.queueCount = newCount;
                    self.chain.chainManager.syncState.masternodeListSyncInfo.queueMaxAmount = maxQueueCount;
                    self.chain.chainManager.syncState.masternodeListSyncInfo.lastListHeight = lastListHeight;
                    self.chain.chainManager.syncState.masternodeListSyncInfo.storedCount = storedCount;
                    [self.chain.chainManager notifySyncStateChanged];
                    [self notifyCurrentListChanged:current_list];
                });
                [self.masternodeListDiffService dequeueMasternodeListRequest];
            } else if (self.isPendingValidation) {
                dispatch_async(self.chain.networkingQueue, ^{
                    self.chain.chainManager.syncState.masternodeListSyncInfo.queueCount = newCount;
                    self.chain.chainManager.syncState.masternodeListSyncInfo.queueMaxAmount = maxQueueCount;
                    [self.chain.chainManager.syncState.masternodeListSyncInfo removeSyncKind:DSMasternodeListSyncStateKind_QrInfo];
                    [self.chain.chainManager.syncState.masternodeListSyncInfo removeSyncKind:DSMasternodeListSyncStateKind_Diffs];
                    [self.chain.chainManager.syncState.masternodeListSyncInfo addSyncKind:DSMasternodeListSyncStateKind_Quorums];
                    [self.chain.chainManager notifySyncStateChanged];
                });
                NSError *quorumValidationError = [self verifyQuorums];
                if (quorumValidationError) {
                    dispatch_async(self.chain.networkingQueue, ^{
                        [self.chain.chainManager.syncState.masternodeListSyncInfo removeSyncKind:DSMasternodeListSyncStateKind_Quorums];
                        [self.chain.chainManager notifySyncStateChanged];
                    });
                } else {
                    [self finishIntitialQrInfoPipeline];
                }
            } else {
                uint32_t lastListHeight = DCurrentMasternodeListBlockHeight(self.processor);
                uint32_t storedCount = (uint32_t) DKnownMasternodeListsCount(self.processor);
                DMasternodeList *current_list = [self currentMasternodeList];
                dispatch_async(self.chain.networkingQueue, ^{
                    self.chain.chainManager.syncState.masternodeListSyncInfo.queueCount = newCount;
                    self.chain.chainManager.syncState.masternodeListSyncInfo.queueMaxAmount = maxQueueCount;
                    self.chain.chainManager.syncState.masternodeListSyncInfo.lastListHeight = lastListHeight;
                    self.chain.chainManager.syncState.masternodeListSyncInfo.storedCount = storedCount;
                    [self.chain.chainManager.syncState.masternodeListSyncInfo removeSyncKind:DSMasternodeListSyncStateKind_Diffs];
                    [self.chain.chainManager notifySyncStateChanged];
                    [self notifyCurrentListChanged:current_list];
                });
            }
        }
        DMnDiffResultDtor(result);
        dispatch_group_leave(self.processingGroup);
    });
}

- (void)tryToProcessQrInfo:(DSPeer *)peer message:(NSData *)message attempt:(uint8_t)attempt {
    __block NSUInteger numOfAttempt = attempt;
        dispatch_async(self.processingQueue, ^{
            dispatch_group_enter(self.processingGroup);
            Slice_u8 *slice_msg = slice_ctor(message);
            
            DQRInfoResult *result = dash_spv_masternode_processor_processing_processor_MasternodeProcessor_process_qr_info_result_from_message(self.processor, slice_msg, false, true);
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
                                if (attempt < 3) {
                                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), self.processingQueue, ^{
                                        numOfAttempt++;
                                        [self tryToProcessQrInfo:peer message:message attempt:attempt];
                                    });
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
            #if SAVE_MASTERNODE_DIFF_ERROR_TO_FILE
                [self writeToDisk:[NSString stringWithFormat:@"QRINFO_ERR_%d_%f.dat", peer.version, [NSDate timeIntervalSinceReferenceDate]] data:message];
            #endif
            #if SAVE_ERROR_STATE
                Result_ok_Vec_u8_err_dash_spv_masternode_processor_processing_processor_processing_error_ProcessingError *bincode = dash_spv_masternode_processor_processing_processor_MasternodeProcessor_serialize_engine(self.processor);
                if (bincode->error) {
                    NSError *error = [NSError ffi_from_processing_error:bincode->error];
                    DSLog(@"%@ Engine: Error: %@", self.logPrefix, error);
                } else {
                    [self writeToDisk:ENGINE_STORAGE_LOCATION(self.chain) data:NSDataFromPtr(bincode->ok)];
                }
                Result_ok_Vec_u8_err_dash_spv_masternode_processor_processing_processor_processing_error_ProcessingError_destroy(bincode);
            #endif
                
                DQRInfoResultDtor(result);
                dispatch_group_leave(self.processingGroup);
                return;
            }
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:CHAIN_FAULTY_DML_MASTERNODE_PEERS];
            std_collections_BTreeSet_dashcore_hash_types_BlockHash *missed_hashes = result->ok;
            
            DSLog(@"%@ QRINFO: OK: %u", self.logPrefix, (uint32_t) missed_hashes->count);
            #if SAVE_MASTERNODE_DIFF_TO_FILE
                [self writeToDisk:[NSString stringWithFormat:@"QRINFO_MISSED_%d_%f.dat", peer.version, [NSDate timeIntervalSinceReferenceDate]] data:message];
            #endif

            if (missed_hashes->count > 0) {
                self.isPendingValidation = YES;
                [self.quorumRotationService cleanAllLists];
                NSArray<NSData *> *missedHashes = [NSArray ffi_from_block_hash_btree_set:missed_hashes];
                NSUInteger newCount = [self.masternodeListDiffService addToRetrievalQueueArray:missedHashes];
                NSUInteger maxAmount = self.masternodeListDiffService.retrievalQueueMaxAmount;
                dispatch_async(self.chain.networkingQueue, ^{
                    [self.chain.chainManager.syncState.masternodeListSyncInfo addSyncKind:DSMasternodeListSyncStateKind_Diffs];
                    self.chain.chainManager.syncState.masternodeListSyncInfo.queueCount = (uint32_t) newCount;
                    self.chain.chainManager.syncState.masternodeListSyncInfo.queueMaxAmount = (uint32_t) maxAmount;
                    [self.chain.chainManager notifySyncStateChanged];
                });
                [self.masternodeListDiffService dequeueMasternodeListRequest];
            } else {
                dispatch_async(self.chain.networkingQueue, ^{
                    [self.chain.chainManager.syncState.masternodeListSyncInfo addSyncKind:DSMasternodeListSyncStateKind_Quorums];
                    [self.chain.chainManager notifySyncStateChanged];
                });
                NSError *quorumValidationError = [self verifyQuorums];
                if (quorumValidationError) {
                    dispatch_async(self.chain.networkingQueue, ^{
                        [self.chain.chainManager.syncState.masternodeListSyncInfo removeSyncKind:DSMasternodeListSyncStateKind_Quorums];
                        [self.chain.chainManager notifySyncStateChanged];
                    });
                } else {
                    [self finishIntitialQrInfoPipeline];
                }
            }

            DQRInfoResultDtor(result);
            dispatch_group_leave(self.processingGroup);
        });
}

- (void)finishIntitialQrInfoPipeline {
    self.hasHandledQrInfoPipeline = YES;
    self.isPendingValidation = NO;
    DMasternodeList *current_list = [self currentMasternodeList];
    uint32_t lastListHeight = DCurrentMasternodeListBlockHeight(self.processor);
    uint32_t storedCount = (uint32_t) DKnownMasternodeListsCount(self.processor);
    [self.quorumRotationService cleanAllLists];
    dispatch_async(self.chain.networkingQueue, ^{
        [self.chain.chainManager.syncState.masternodeListSyncInfo removeSyncKind:DSMasternodeListSyncStateKind_Quorums];
        [self.chain.chainManager.syncState.masternodeListSyncInfo removeSyncKind:DSMasternodeListSyncStateKind_QrInfo];
        self.chain.chainManager.syncState.masternodeListSyncInfo.lastListHeight = lastListHeight;
        self.chain.chainManager.syncState.masternodeListSyncInfo.storedCount = storedCount;
        [self.chain.chainManager notifySyncStateChanged];
        [self.chain.chainManager.transactionManager checkWaitingForQuorums];
        [self notifyCurrentListChanged:current_list];
    });
    [self.quorumRotationService dequeueMasternodeListRequest];
}

- (void)peer:(DSPeer *)peer relayedQuorumRotationInfoMessage:(NSData *)message {
    //DSLog(@"%@ [%@:%d] qrinfo: received: %@", self.logPrefix, peer.host, peer.port, uint256_hex(message.SHA256));
    @synchronized (self.quorumRotationService) {
        self.quorumRotationService.timedOutAttempt = 0;
    }
    [self tryToProcessQrInfo:peer message:message attempt:0];
}

// MARK: - Meta information

- (void)checkPingTimesForCurrentMasternodeListInContext:(NSManagedObjectContext *)context
                                         withCompletion:(void (^)(NSMutableDictionary<NSData *, NSNumber *> *pingTimes, NSMutableDictionary<NSData *, NSError *> *errors))completion {
    // TODO: this is not supported yet
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

- (uintptr_t)currentQuorumsOfType:(DLLMQType)type {
    return dash_spv_masternode_processor_processing_processor_MasternodeProcessor_current_quorums_of_type_count(self.processor, &type);
    
}
- (uintptr_t)currentValidQuorumsOfType:(DLLMQType)type {
    return dash_spv_masternode_processor_processing_processor_MasternodeProcessor_current_valid_quorums_of_type_count(self.processor, &type);
}


- (NSError *_Nullable)requestMasternodeListForBlockHeight:(uint32_t)blockHeight {
    DSMerkleBlock *merkleBlock = [self.chain blockAtHeight:blockHeight];
    if (!merkleBlock)
        return [NSError errorWithDomain:@"DashSync" code:600 userInfo:@{NSLocalizedDescriptionKey: @"Unknown block"}];
    [self requestMasternodeListForBlockHash:uint256_data(merkleBlock.blockHash)];
    return nil;
}
- (void)requestMasternodeListForBlockHash:(NSData *)blockHash {
    NSUInteger newCount = [self.masternodeListDiffService addToRetrievalQueue:blockHash];
    NSUInteger maxAmount = self.masternodeListDiffService.retrievalQueueMaxAmount;
    dispatch_async(self.chain.networkingQueue, ^{
        [self.chain.chainManager.syncState.masternodeListSyncInfo addSyncKind:DSMasternodeListSyncStateKind_Diffs];
        self.chain.chainManager.syncState.masternodeListSyncInfo.queueCount = (uint32_t) newCount;
        self.chain.chainManager.syncState.masternodeListSyncInfo.queueMaxAmount = (uint32_t) maxAmount;
        [self.chain.chainManager notifySyncStateChanged];
    });
    [self.masternodeListDiffService dequeueMasternodeListRequest];

}
- (void)requestMasternodeListForBaseBlockHash:(NSData *)baseBlockHash blockHash:(NSData *)blockHash {
    NSUInteger maxAmount = self.masternodeListDiffService.retrievalQueueMaxAmount;
    NSUInteger newCount = [self.masternodeListDiffService addToRetrievalQueueArray:@[baseBlockHash, blockHash]];
    dispatch_async(self.chain.networkingQueue, ^{
        [self.chain.chainManager.syncState.masternodeListSyncInfo addSyncKind:DSMasternodeListSyncStateKind_Diffs];
        self.chain.chainManager.syncState.masternodeListSyncInfo.queueCount = (uint32_t) newCount;
        self.chain.chainManager.syncState.masternodeListSyncInfo.queueMaxAmount = (uint32_t) maxAmount;
        [self.chain.chainManager notifySyncStateChanged];
    });
    [self.masternodeListDiffService dequeueMasternodeListRequest];
}

- (void)notifyCurrentListChanged:(DMasternodeList *_Nullable)list {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DSCurrentMasternodeListDidChangeNotification object:nil userInfo:@{
            DSChainManagerNotificationChainKey: self.chain,
            DSMasternodeManagerNotificationMasternodeListKey: list ? [NSValue valueWithPointer:list] : [NSNull null]
        }];
        [[NSNotificationCenter defaultCenter] postNotificationName:DSMasternodeListDidChangeNotification object:nil userInfo:@{
            DSChainManagerNotificationChainKey: self.chain,
        }];
        [[NSNotificationCenter defaultCenter] postNotificationName:DSQuorumListDidChangeNotification object:nil userInfo:@{
            DSChainManagerNotificationChainKey: self.chain,
        }];
    });

}

@end
