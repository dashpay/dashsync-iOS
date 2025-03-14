////
////  Created by Vladimir Pirogov
////  Copyright © 2022 Dash Core Group. All rights reserved.
////
////  Licensed under the MIT License (the "License");
////  you may not use this file except in compliance with the License.
////  You may obtain a copy of the License at
////
////  https://opensource.org/licenses/MIT
////
////  Unless required by applicable law or agreed to in writing, software
////  distributed under the License is distributed on an "AS IS" BASIS,
////  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
////  See the License for the specific language governing permissions and
////  limitations under the License.
////
//
//#import "DSMasternodeListStore.h"
//#import "DSAddressEntity+CoreDataClass.h"
//#import "DSChain+Params.h"
//#import "DSChain+Protected.h"
//#import "DSChainManager+Protected.h"
//#import "DSLocalMasternodeEntity+CoreDataClass.h"
//#import "DSMerkleBlockEntity+CoreDataClass.h"
////#import "DSMasternodeListEntity+CoreDataClass.h"
////#import "DSQuorumEntryEntity+CoreDataClass.h"
////#import "DSQuorumSnapshotEntity+CoreDataClass.h"
////#import "DSSimplifiedMasternodeEntryEntity+CoreDataClass.h"
//#import "NSArray+Dash.h"
//#import "NSData+Dash.h"
//#import "NSError+Dash.h"
//
//@interface DSMasternodeListStore ()
//
//@property (nonatomic, strong) DSChain *chain;
//@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;
//@property (nonatomic, strong) dispatch_queue_t masternodeSavingQueue;
//@property (nonatomic, strong) dispatch_group_t savingGroup;
//@end
//
//@implementation DSMasternodeListStore
//
//- (instancetype)initWithChain:(DSChain *)chain {
//    NSParameterAssert(chain);
//    if (!(self = [super init])) return nil;
//    _chain = chain;
//    _masternodeSavingQueue = dispatch_queue_create([[NSString stringWithFormat:@"org.dashcore.dashsync.masternodesaving.%@", chain.uniqueID] UTF8String], DISPATCH_QUEUE_SERIAL);
//    _savingGroup = dispatch_group_create();
//    self.managedObjectContext = chain.chainManagedObjectContext;
//    return self;
//}
//
////-
//
//
////- (void)setUp {
//////    [self deleteEmptyMasternodeLists]; //this is just for sanity purposes
////    DMasternodeList *list = [self loadMasternodeListsWithBlockHeightLookup:^uint32_t(UInt256 blockHash) {
////        return [self.chain heightForBlockHash:blockHash];
////    }];
//////    if (list) {
//////        dash_spv_masternode_processor_processing_processor_cache_MasternodeProcessorCache_set_last_queried_mn_masternode_list(self.chain.sharedCacheObj, list->block_hash);
//////    }
//////    [self removeOldSimplifiedMasternodeEntries];
////    [self loadLocalMasternodes];
////}
//
////- (void)savePlatformPingInfoForEntries:(NSArray<DSSimplifiedMasternodeEntry *> *)entries
////                             inContext:(NSManagedObjectContext *)context {
////    [context performBlockAndWait:^{
////        for (DSSimplifiedMasternodeEntry *entry in entries) {
////            [entry savePlatformPingInfoInContext:context];
////        }
////        NSError *savingError = nil;
////        [context save:&savingError];
////    }];
////}
////
////- (uint32_t)earliestMasternodeListBlockHeight {
////    return dash_spv_masternode_processor_processing_processor_MasternodeProcessor_earliest_masternode_list_block_height(self.chain.sharedProcessorObj);
////}
//
//- (uint32_t)lastMasternodeListBlockHeight {
//    return dash_spv_masternode_processor_processing_processor_MasternodeProcessor_current_masternode_list_height(self.chain.sharedProcessorObj);
//}
//
////- (uint32_t)heightForBlockHash:(UInt256)blockhash {
////    if (uint256_is_zero(blockhash)) return 0;
////    u256 *hash = u256_ctor_u(blockhash);
////    uint32_t cachedHeight = DHeightForBlockHash(self.chain.sharedProcessorObj, hash);
////    return cachedHeight;
////}
//
////- (UInt256)closestKnownBlockHashForBlockHash:(UInt256)blockHash {
////    u256 *block_hash = u256_ctor_u(blockHash);
////    u256 *closest_block_hash = dash_spv_masternode_processor_processing_processor_MasternodeProcessor_closest_known_block_hash_for_block_hash(self.chain.sharedProcessorObj, block_hash);
////    UInt256 known = u256_cast(closest_block_hash);
////    u256_dtor(closest_block_hash);
////    return known;
////}
//
//- (void)deleteAllOnChain {
////    DSLog(@"[%@] DSMasternodeListStore.deleteAllOnChain", self.chain.name);
////    [self.managedObjectContext performBlockAndWait:^{
////        DSChainEntity *chainEntity = [self.chain chainEntityInContext:self.managedObjectContext];
////        [DSSimplifiedMasternodeEntryEntity deleteAllOnChainEntity:chainEntity];
////        [DSQuorumEntryEntity deleteAllOnChainEntity:chainEntity];
////        [DSMasternodeListEntity deleteAllOnChainEntity:chainEntity];
////        [DSQuorumSnapshotEntity deleteAllOnChainEntity:chainEntity];
////        [self.managedObjectContext ds_save];
////    }];
//}
////
////- (void)deleteEmptyMasternodeLists {
////    [self.managedObjectContext performBlockAndWait:^{
////        NSFetchRequest *fetchRequest = [[DSMasternodeListEntity fetchRequest] copy];
////        [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"block.chain == %@ && masternodes.@count == 0", [self.chain chainEntityInContext:self.managedObjectContext]]];
////        NSArray *masternodeListEntities = [DSMasternodeListEntity fetchObjects:fetchRequest inContext:self.managedObjectContext];
////        for (DSMasternodeListEntity *entity in [masternodeListEntities copy]) {
////            DSLog(@"[%@] DSMasternodeListStore.deleteEmptyMasternodeLists: %@: %@", self.chain.name, entity.block, entity);
////            [self.managedObjectContext deleteObject:entity];
////        }
////        [self.managedObjectContext ds_save];
////    }];
////}
//
////- (BOOL)hasBlocksWithHash:(UInt256)blockHash {
////    __block BOOL hasBlock = NO;
////    [self.managedObjectContext performBlockAndWait:^{
////        hasBlock = !![DSMerkleBlockEntity countObjectsInContext:self.managedObjectContext matching:@"blockHash == %@", uint256_data(blockHash)];
////    }];
////    return hasBlock;
////}
//
//- (BOOL)hasBlockForBlockHash:(NSData *)blockHashData {
//    UInt256 blockHash = blockHashData.UInt256;
//    BOOL hasBlock = [self.chain blockForBlockHash:blockHash] != nil;
//    if (!hasBlock) {
//        hasBlock = [DSMerkleBlockEntity hasBlocksWithHash:blockHash inContext:self.managedObjectContext];
//    }
//    if (!hasBlock && self.chain.isTestnet) {
//        //We can trust insight if on testnet
//        [self.chain blockUntilGetInsightForBlockHash:blockHash];
//        hasBlock = !![[self.chain insightVerifiedBlocksByHashDictionary] objectForKey:blockHashData];
//    }
//    return hasBlock;
//}
//
////- (void)loadLocalMasternodes {
////    NSFetchRequest *fetchRequest = [[DSLocalMasternodeEntity fetchRequest] copy];
////    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"providerRegistrationTransaction.transactionHash.chain == %@", [self.chain chainEntityInContext:self.managedObjectContext]]];
////    NSArray *localMasternodeEntities = [DSLocalMasternodeEntity fetchObjects:fetchRequest inContext:self.managedObjectContext];
////    for (DSLocalMasternodeEntity *localMasternodeEntity in localMasternodeEntities) {
////        [localMasternodeEntity loadLocalMasternode]; // lazy loaded into the list
////    }
////}
//
////- (DMasternodeList *)loadMasternodeListAtBlockHash:(NSData *)blockHash
////                             withBlockHeightLookup:(BlockHeightFinder)blockHeightLookup {
////    __block DMasternodeList *masternode_list = nil;
////    DSLog(@"loadMasternodeListAtBlockHash: %@", blockHash.hexString);
////    dispatch_group_enter(self.savingGroup);
////    [self.managedObjectContext performBlockAndWait:^{
////        DSMasternodeListEntity *entity = [DSMasternodeListEntity anyObjectInContext:self.managedObjectContext matching:@"block.chain == %@ && block.blockHash == %@", [self.chain chainEntityInContext:self.managedObjectContext], blockHash];
////        masternode_list = [entity masternodeListWithBlockHeightLookup:blockHeightLookup];
////        DSLog(@"loadMasternodeListAtBlockHash loaded: %p", masternode_list);
////        if (masternode_list)
////            [self.chain.chainManager notifyMasternodeSyncStateChange:self.lastMasternodeListBlockHeight
////                                                         storedCount:DMasternodeListLoaded(self.chain.sharedCacheObj, u256_ctor(blockHash), masternode_list)];
////    }];
////    dispatch_group_leave(self.savingGroup);
////    return masternode_list;
////}
////- (DMasternodeList *)loadMasternodeListsWithBlockHeightLookup:(BlockHeightFinder)blockHeightLookup {
////    __block DMasternodeList *currentList = nil;
////    DSLog(@"[%@] loadMasternodeListsWithBlockHeightLookup", self.chain.name);
////    dispatch_group_enter(self.savingGroup);
////    [self.managedObjectContext performBlockAndWait:^{
////        NSFetchRequest *fetchRequest = [[DSMasternodeListEntity fetchRequest] copy];
////        [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"block.chain == %@", [self.chain chainEntityInContext:self.managedObjectContext]]];
////        [fetchRequest setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"block.height" ascending:YES]]];
////        NSArray *masternodeListEntities = [DSMasternodeListEntity fetchObjects:fetchRequest inContext:self.managedObjectContext];
////        //DSLog(@"[%@] loadMasternodeListsWithBlockHeightLookup: stored count: %lu", self.chain.name, masternodeListEntities.count);
//////        MasternodeProcessorCache *cache = self.chain.sharedCacheObj;
////
////        uint32_t neededMasternodeListHeight = self.chain.lastTerminalBlockHeight - 23; //2*8+7
////        DSLog(@"[%@] loadMasternodeListsWithBlockHeightLookup: needed_height: %u", self.chain.name, neededMasternodeListHeight);
////        for (uint32_t i = (uint32_t)masternodeListEntities.count - 1; i != UINT32_MAX; i--) {
////            DSMasternodeListEntity *masternodeListEntity = [masternodeListEntities objectAtIndex:i];
////            
////            uintptr_t masternode_lists_count = DStoredMasternodeListsCount(cache);
////            DSLog(@"[%@] loadMasternodeListsWithBlockHeightLookup: cache count: %lu at %d", self.chain.name, masternode_lists_count, masternodeListEntity.block.height);
////
////            if ((i == masternodeListEntities.count - 1) || ((masternode_lists_count < 3) && (neededMasternodeListHeight >= masternodeListEntity.block.height))) {
////                //either last one or there are less than 3 (we aim for 3)
////                //we only need a few in memory as new quorums will mostly be verified against recent masternode lists
////                DMasternodeList *list = [masternodeListEntity masternodeListWithBlockHeightLookup:blockHeightLookup];
////                DAddMasternodeList(cache, list->block_hash, list);
////
////                [self.chain.chainManager notifyMasternodeSyncStateChange:self.lastMasternodeListBlockHeight
////                                                             storedCount:DStoredMasternodeListsCount(cache)];
////                DCacheBlockHeight(cache, list->block_hash, masternodeListEntity.block.height);
////                if (i == masternodeListEntities.count - 1) {
////                    if (currentList)
////                        DMasternodeListDtor(currentList);
////                    currentList = list;
////                }
////                neededMasternodeListHeight = masternodeListEntity.block.height - 8;
////            } else {
////                DSMerkleBlockEntity *block = masternodeListEntity.block;
////                uint32_t block_height = block.height;
////                u256 *block_hash = u256_ctor(block.blockHash);
////                DCacheBlockHeight(cache, block_hash, block_height);
////                DAddMasternodeListStub(cache, block_hash);
////            }
////        }
////    }];
////    dispatch_group_leave(self.savingGroup);
////    DSLog(@"[%@] loadMasternodeListsWithBlockHeightLookup: loaded: %p", self.chain.name, currentList);
//////    DMasternodeListPrint(currentList->obj);
////    return currentList;
////}
////
////- (void)removeOldMasternodeLists {
////    uint32_t heightToDelete = dash_spv_masternode_processor_processing_processor_MasternodeProcessor_calculate_outdated_height(self.chain.sharedProcessorObj);
////    if (heightToDelete > 0 && heightToDelete != UINT32_MAX) {
////        uint32_t h = heightToDelete - 50;
////        DRemoveMasternodeListsBefore(self.chain.sharedCacheObj, h);
////        dispatch_group_enter(self.savingGroup);
////        [self.managedObjectContext performBlockAndWait:^{
////            DCache *cache = self.chain.sharedCacheObj;
////            std_collections_HashSet_u8_32 *set = dash_spv_masternode_processor_processing_processor_cache_MasternodeProcessorCache_known_masternode_lists_block_hashes(cache);
////            NSArray<NSData *> *masternodeListBlockHashes = [NSArray ffi_from_hash_set:set];
////            [NSArray ffi_destroy_hash_set:set];
////            @autoreleasepool {
////    //            NSMutableArray *masternodeListBlockHashes = [[self.masternodeListsByBlockHash allKeys] mutableCopy];
////    //            [masternodeListBlockHashes addObjectsFromArray:[self.masternodeListsBlockHashStubs allObjects]];
////                NSArray<DSMasternodeListEntity *> *masternodeListEntities = [DSMasternodeListEntity objectsInContext:self.managedObjectContext matching:@"block.height < %@ && block.blockHash IN %@ && (block.usedByQuorums.@count == 0)", @(h), masternodeListBlockHashes];
////                BOOL removedItems = !!masternodeListEntities.count;
////                for (DSMasternodeListEntity *masternodeListEntity in [masternodeListEntities copy]) {
////                    DSLog(@"[%@] Removing masternodeList at height %u", self.chain.name, masternodeListEntity.block.height);
////                    DSLog(@"[%@] quorums are %@", self.chain.name, masternodeListEntity.block.usedByQuorums);
////                    //A quorum is on a block that can only have one masternode list.
////                    //A block can have one quorum of each type.
////                    //A quorum references the masternode list by it's block
////                    //we need to check if this masternode list is being referenced by a quorum using the inverse of quorum.block.masternodeList
////                    [self.managedObjectContext deleteObject:masternodeListEntity];
////                    NSData *blockHash = masternodeListEntity.block.blockHash;
////                    DRemoveMasternodeList(cache, u256_ctor(blockHash));
////                }
////                if (removedItems) {
////                    
////                    //Now we should delete old quorums
////                    //To do this, first get the last 24 active masternode lists
////                    //Then check for quorums not referenced by them, and delete those
////                    NSArray<DSMasternodeListEntity *> *recentMasternodeLists = [DSMasternodeListEntity objectsSortedBy:@"block.height" ascending:NO offset:0 limit:10 inContext:self.managedObjectContext];
////                    uint32_t oldTime = heightToDelete - 24;
////                    uint32_t oldestBlockHeight = recentMasternodeLists.count ? MIN([recentMasternodeLists lastObject].block.height, oldTime) : oldTime;
////                    NSArray *oldQuorums = [DSQuorumEntryEntity objectsInContext:self.managedObjectContext matching:@"chain == %@ && SUBQUERY(referencedByMasternodeLists, $masternodeList, $masternodeList.block.height > %@).@count == 0", [self.chain chainEntityInContext:self.managedObjectContext], @(oldestBlockHeight)];
////                    for (DSQuorumEntryEntity *unusedQuorumEntryEntity in [oldQuorums copy]) {
////                        [self.managedObjectContext deleteObject:unusedQuorumEntryEntity];
////                    }
////                    [self.managedObjectContext ds_save];
////                    [self.chain.chainManager notifyMasternodeSyncStateChange:self.lastMasternodeListBlockHeight
////                                                                 storedCount:DStoredMasternodeListsCount(cache)];
////                }
////            }
////        }];
////        dispatch_group_leave(self.savingGroup);
////    }
////
////}
////
////- (void)removeOldSimplifiedMasternodeEntries {
////    //this serves both for cleanup, but also for initial migration
////    dispatch_group_enter(self.savingGroup);
////    [self.managedObjectContext performBlockAndWait:^{
////        NSArray<DSSimplifiedMasternodeEntryEntity *> *simplifiedMasternodeEntryEntities = [DSSimplifiedMasternodeEntryEntity objectsInContext:self.managedObjectContext matching:@"masternodeLists.@count == 0"];
////        BOOL deletedSomething = FALSE;
////        NSUInteger deletionCount = 0;
////        for (DSSimplifiedMasternodeEntryEntity *simplifiedMasternodeEntryEntity in [simplifiedMasternodeEntryEntities copy]) {
////            DSLog(@"[%@] removeOldSimplifiedMasternodeEntries: %@", self.chain.name, simplifiedMasternodeEntryEntity.providerRegistrationTransactionHash.hexString);
////            [self.managedObjectContext deleteObject:simplifiedMasternodeEntryEntity];
////            deletedSomething = TRUE;
////            deletionCount++;
////            if ((deletionCount % 3000) == 0)
////                [self.managedObjectContext ds_save];
////        }
////        if (deletedSomething)
////            [self.managedObjectContext ds_save];
////    }];
////    dispatch_group_leave(self.savingGroup);
////}
//
////- (void)notifyMasternodeListUpdate {
////    dispatch_async(dispatch_get_main_queue(), ^{
////        [[NSNotificationCenter defaultCenter] postNotificationName:DSMasternodeListDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey: self.chain}];
////        [[NSNotificationCenter defaultCenter] postNotificationName:DSQuorumListDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey: self.chain}];
////    });
////}
////
////- (nullable NSError *)saveQuorumSnapshot:(DLLMQSnapshot *)quorumSnapshot
////                            forBlockHash:(u256 *)block_hash {
////    if (!quorumSnapshot) {
////        return NULL;
////    }
////    uint32_t blockHeight = DHeightForBlockHash(self.chain.sharedProcessorObj, block_hash);
////    NSData *blockHashData = NSDataFromPtr(block_hash);
////    UInt256 blockHash = blockHashData.UInt256;
////    dispatch_group_enter(self.savingGroup);
////    NSManagedObjectContext *context = self.managedObjectContext;
////    __block NSError *result = nil;
////
////    [context performBlockAndWait:^{
////        @autoreleasepool {
////            BOOL createUnknownBlocks = self.chain.allowInsightBlocksForVerification;
////            DSChainEntity *chainEntity = [self.chain chainEntityInContext:context];
////            DSMerkleBlockEntity *merkleBlockEntity = [DSMerkleBlockEntity merkleBlockEntityForBlockHash:blockHashData inContext:context];
////            if (!merkleBlockEntity) {
////                merkleBlockEntity = [DSMerkleBlockEntity merkleBlockEntityForBlockHashFromCheckpoint:blockHash chain:self.chain inContext:context];
////            }
////            //NSAssert(!merkleBlockEntity || !merkleBlockEntity.quorumSnapshot, @"Merkle block should not have a quorum snapshot already");
////            NSError *error = nil;
////            if (!merkleBlockEntity) {
////                if (createUnknownBlocks) {
////                    merkleBlockEntity = [DSMerkleBlockEntity createMerkleBlockEntityForBlockHash:blockHashData blockHeight:blockHeight chainEntity:chainEntity inContext:context];
////                } else {
////                    DSLog(@"[%@] Merkle block should exist for block hash %@", self.chain.name, blockHashData.hexString);
////                    error = [NSError errorWithCode:600 localizedDescriptionKey:@"Merkle block should exist"];
////                }
////            } else if (merkleBlockEntity.quorumSnapshot) {
////                DSLog(@"[%@] Merkle block already have quorum snapshot for %@", self.chain.name, blockHashData.hexString);
////                error = [NSError errorWithCode:600 localizedDescriptionKey:@"Merkle block should not have a quorum snapshot already"]; // DGaF
////                // skip we're just processing saved snapshot
////                //[merkleBlockEntity.quorumSnapshot updateAttributesFromPotentialQuorumSnapshot:quorumSnapshot onBlock:merkleBlockEntity]
////            }
////            if (error) {
////                [DSQuorumSnapshotEntity deleteAllOnChainEntity:chainEntity];
////            } else {
////                DSQuorumSnapshotEntity *quorumSnapshotEntity = [DSQuorumSnapshotEntity managedObjectInBlockedContext:context];
////                [quorumSnapshotEntity updateAttributesFromPotentialQuorumSnapshot:quorumSnapshot onBlock:merkleBlockEntity];
////                DSLog(@"[%@] Finished saving Quorum Snapshot at height %u: %@", self.chain.name, blockHeight, uint256_hex(blockHash));
////            }
////            error = [context ds_save];
////            result = error;
//////            if (completion) {
//////                completion(error);
//////            }
////        }
////    }];
////    dispatch_group_leave(self.savingGroup);
////    return result;
////}
////
////+ (void)updateMasternodeListEntity:(DSMasternodeListEntity *)masternodeListEntity
////                   withMasternodeList:(DMasternodeList *)masternodeList
////               modifiedMasternodes:(DMasternodeEntryMap *)modifiedMasternodes
////                          atHeight:(uint32_t)height
////                           onChain:(DSChain *)chain
////                     onChainEntity:(DSChainEntity *)chainEntity
////                        inContext:(NSManagedObjectContext *)context {
////    DMasternodeEntryMap *masternode_map = masternodeList->masternodes;
////    DLLMQMap *quorum_map = masternodeList->quorums;
////    u256 *block_hash = masternodeList->block_hash;
////    NSData *mnlBlockHashData = NSDataFromPtr(block_hash);
////    NSArray<DSSimplifiedMasternodeEntryEntity *> *knownSimplifiedMasternodeEntryEntities = [DSSimplifiedMasternodeEntryEntity objectsInContext:context matching:@"chain == %@", chainEntity];
////    //DSLog(@"[%@] MNL knownSimplifiedMasternodeEntryEntities: %lu", chain.name, knownSimplifiedMasternodeEntryEntities.count);
////    NSMutableDictionary *indexedKnownSimplifiedMasternodeEntryEntities = [NSMutableDictionary dictionary];
////    for (DSSimplifiedMasternodeEntryEntity *simplifiedMasternodeEntryEntity in knownSimplifiedMasternodeEntryEntities) {
////        [indexedKnownSimplifiedMasternodeEntryEntities setObject:simplifiedMasternodeEntryEntity forKey:simplifiedMasternodeEntryEntity.providerRegistrationTransactionHash];
////    }
////    NSDictionary<NSData *, DSSimplifiedMasternodeEntryEntity *> *indexedMasternodes = [indexedKnownSimplifiedMasternodeEntryEntities copy];
////    
////    NSMutableSet<NSString *> *votingAddressStrings = [NSMutableSet set];
////    NSMutableSet<NSString *> *operatorAddressStrings = [NSMutableSet set];
////    NSMutableSet<NSString *> *platformNodeAddressStrings = [NSMutableSet set];
////    NSMutableSet<NSData *> *providerRegistrationTransactionHashes = [NSMutableSet set];
////    
////    for (int i = 0; i < masternode_map->count; i++) {
////        DMasternodeEntry *entry = masternode_map->values[i];
////        NSString *votingAddress = [DSKeyManager NSStringFrom:DMasternodeEntryVotingAddress(entry, chain.chainType)];
////        NSString *operatorAddress = [DSKeyManager NSStringFrom:DMasternodeEntryOperatorPublicKeyAddress(entry, chain.chainType)];
////        NSString *platformNodeAddress = [DSKeyManager NSStringFrom:DMasternodeEntryEvoNodeAddress(entry, chain.chainType)];
////        NSData *proRegTxHash = NSDataFromPtr(entry->provider_registration_transaction_hash);
////        [votingAddressStrings addObject:votingAddress];
////        [operatorAddressStrings addObject:operatorAddress];
////        [platformNodeAddressStrings addObject:platformNodeAddress];
////        [providerRegistrationTransactionHashes addObject:proRegTxHash];
////    }
////
////    //this is the initial list sync so lets speed things up a little bit with some optimizations
////    NSDictionary<NSString *, DSAddressEntity *> *votingAddresses = [DSAddressEntity findAddressesAndIndexIn:votingAddressStrings onChain:(DSChain *)chain inContext:context];
////    NSDictionary<NSString *, DSAddressEntity *> *operatorAddresses = [DSAddressEntity findAddressesAndIndexIn:operatorAddressStrings onChain:(DSChain *)chain inContext:context];
////    NSDictionary<NSString *, DSAddressEntity *> *platformNodeAddresses = [DSAddressEntity findAddressesAndIndexIn:platformNodeAddressStrings onChain:(DSChain *)chain inContext:context];
////    NSDictionary<NSData *, DSLocalMasternodeEntity *> *localMasternodes = [DSLocalMasternodeEntity findLocalMasternodesAndIndexForProviderRegistrationHashes:providerRegistrationTransactionHashes inContext:context];
////    NSAssert(masternode_map->count > 0, @"A masternode must have entries to be saved");
////    for (int i = 0; i < masternode_map->count; i++) {
////        DMasternodeEntry *entry = masternode_map->values[i];
////        NSData *proRegTxHash = NSDataFromPtr(entry->provider_registration_transaction_hash);
////
////        DSSimplifiedMasternodeEntryEntity *simplifiedMasternodeEntryEntity = [indexedMasternodes objectForKey:proRegTxHash];
////        if (!simplifiedMasternodeEntryEntity) {
////            simplifiedMasternodeEntryEntity = [DSSimplifiedMasternodeEntryEntity managedObjectInBlockedContext:context];
////            [simplifiedMasternodeEntryEntity setAttributesFromSimplifiedMasternodeEntry:entry
////                                                                          atBlockHeight:height
////                                                                 knownOperatorAddresses:operatorAddresses
////                                                                   knownVotingAddresses:votingAddresses
////                                                                  platformNodeAddresses:platformNodeAddresses
////                                                                       localMasternodes:localMasternodes
////                                                                                onChain:chain
////                                                                          onChainEntity:chainEntity];
////        } else if (entry->update_height >= height) {
////            // it was updated in this masternode list
////            [simplifiedMasternodeEntryEntity updateAttributesFromSimplifiedMasternodeEntry:entry
////                                                                             atBlockHeight:height
////                                                                    knownOperatorAddresses:operatorAddresses
////                                                                      knownVotingAddresses:votingAddresses
////                                                                     platformNodeAddresses:platformNodeAddresses
////                                                                          localMasternodes:localMasternodes
////                                                                                   onChain:chain];
////        }
////        [masternodeListEntity addMasternodesObject:simplifiedMasternodeEntryEntity];
////    }
////    for (int i = 0; i < modifiedMasternodes->count; i++) {
////        DMasternodeEntry *modified = modifiedMasternodes->values[i];
////        NSData *proRegTxHash = NSDataFromPtr(modified->provider_registration_transaction_hash);
////        DSSimplifiedMasternodeEntryEntity *simplifiedMasternodeEntryEntity = [indexedMasternodes objectForKey:proRegTxHash];
////        NSAssert(simplifiedMasternodeEntryEntity, @"this masternode must be present (%@)", proRegTxHash.hexString);
////        [simplifiedMasternodeEntryEntity updateAttributesFromSimplifiedMasternodeEntry:modified
////                                                                         atBlockHeight:height
////                                                                knownOperatorAddresses:operatorAddresses
////                                                                  knownVotingAddresses:votingAddresses
////                                                                 platformNodeAddresses:platformNodeAddresses
////                                                                      localMasternodes:localMasternodes
////                                                                               onChain:chain];
////    }
////
////    for (int i = 0; i < quorum_map->count; i++) {
////        DLLMQMapOfType *quorums_of_type = quorum_map->values[i];
////        for (int j = 0; j < quorums_of_type->count; j++) {
////            DLLMQEntry *potential_entry = quorums_of_type->values[j];
////            DSQuorumEntryEntity *entity = [DSQuorumEntryEntity quorumEntryEntityFromPotentialQuorumEntry:potential_entry inContext:context onChain:chain];
////            if (entity)
////                [masternodeListEntity addQuorumsObject:entity];
////        }
////    }
////    chainEntity.baseBlockHash = mnlBlockHashData;
////
////    
////
////}
////
////+ (nullable NSError *)saveMasternodeList:(DMasternodeList *)list
////                                 toChain:(DSChain *)chain
////               havingModifiedMasternodes:(DMasternodeEntryMap *)modifiedMasternodes
////                     createUnknownBlocks:(BOOL)createUnknownBlocks
////                               inContext:(NSManagedObjectContext *)context {
////    
////    u256 *block_hash = list->block_hash;
////    u256 *masternode_merkle_root = list->masternode_merkle_root;
////    u256 *llmq_merkle_root = list->llmq_merkle_root;
////    UInt256 blockHash = u256_cast(block_hash);
////    uint32_t mnlHeight = list->known_height;
////    DSLog(@"[%@] Queued saving MNL at height %u: %@", chain.name, mnlHeight, uint256_hex(blockHash));
////    __block NSError *result = nil;
////    [context performBlockAndWait:^{
////        //masternodes
////        @autoreleasepool {
////            DSChainEntity *chainEntity = [chain chainEntityInContext:context];
////            NSData *mnlBlockHashData = uint256_data(blockHash);
////            DSMerkleBlockEntity *merkleBlockEntity = [DSMerkleBlockEntity merkleBlockEntityForBlockHash:mnlBlockHashData inContext:context];
////            if (!merkleBlockEntity) {
////                merkleBlockEntity = [DSMerkleBlockEntity merkleBlockEntityForBlockHashFromCheckpoint:blockHash chain:chain inContext:context];
////            }
//////            NSAssert(!merkleBlockEntity || !merkleBlockEntity.masternodeList, @"Merkle block should not have a masternode list already");
////            NSError *error = nil;
////            BOOL shouldMerge = false;
////            if (!merkleBlockEntity) {
////                if (createUnknownBlocks) {
////                    merkleBlockEntity = [DSMerkleBlockEntity createMerkleBlockEntityForBlockHash:mnlBlockHashData blockHeight:mnlHeight chainEntity:chainEntity inContext:context];
////                } else {
////                    DSLog(@"[%@] Merkle block should exist for block hash %@", chain.name, uint256_hex(blockHash));
////                    error = [NSError errorWithCode:600 localizedDescriptionKey:@"Merkle block should exist"];
////                }
////            } else if (merkleBlockEntity.masternodeList) {
////                // NEW: merge masternode list
////                // We merge quorums as they can have different verification status depending on source
////                shouldMerge = true;
////                //error = [NSError errorWithCode:600 localizedDescriptionKey:@"Merkle block should not have a masternode list already"];
////            }
////            if (shouldMerge) {
////                [DSMasternodeListStore updateMasternodeListEntity:merkleBlockEntity.masternodeList
////                                               withMasternodeList:list
////                                              modifiedMasternodes:modifiedMasternodes
////                                                         atHeight:mnlHeight
////                                                          onChain:chain
////                                                    onChainEntity:chainEntity
////                                                        inContext:context];
////                DSLog(@"[%@] Finished merging MNL at height %u: %@", chain.name, mnlHeight, uint256_hex(blockHash));
////
////            } else if (!error) {
////                DSMasternodeListEntity *masternodeListEntity = [DSMasternodeListEntity managedObjectInBlockedContext:context];
////                masternodeListEntity.block = merkleBlockEntity;
////                NSData *mnMerkleRoot, *llmqMerkleRoot;
////                if (masternode_merkle_root) {
////                    UInt256 root = u256_cast(masternode_merkle_root);
////                    if (uint256_is_zero(root)) {
////                        mnMerkleRoot = NSDataFromPtr(DCalcMnMerkleRoot(list, [chain heightForBlockHash:blockHash]));
////                    } else {
////                        mnMerkleRoot = NSDataFromPtr(masternode_merkle_root);
////                    }
////                    
////                } else {
////                    mnMerkleRoot = NSDataFromPtr(DCalcMnMerkleRoot(list, [chain heightForBlockHash:blockHash]));
////                }
////                if (llmq_merkle_root) {
////                    UInt256 root = u256_cast(llmq_merkle_root);
////                    if (uint256_is_zero(root)) {
////                        llmqMerkleRoot = NSDataFromPtr(DCalcLLMQMerkleRoot(list));
////                        if (!llmqMerkleRoot) llmqMerkleRoot = uint256_data(UINT256_ZERO);
////                    } else {
////                        llmqMerkleRoot = NSDataFromPtr(llmq_merkle_root);
////                    }
////                    
////                } else {
////                    llmqMerkleRoot = NSDataFromPtr(DCalcLLMQMerkleRoot(list));
////                    if (!llmqMerkleRoot) llmqMerkleRoot = uint256_data(UINT256_ZERO);
////
////                }
////
////                masternodeListEntity.masternodeListMerkleRoot = mnMerkleRoot;
////                masternodeListEntity.quorumListMerkleRoot = llmqMerkleRoot;
////                [DSMasternodeListStore updateMasternodeListEntity:masternodeListEntity
////                                               withMasternodeList:list
////                                              modifiedMasternodes:modifiedMasternodes
////                                                         atHeight:mnlHeight
////                                                          onChain:chain
////                                                    onChainEntity:chainEntity
////                                                        inContext:context];
////                DSLog(@"[%@] Finished saving MNL at height %u: %@", chain.name, mnlHeight, uint256_hex(blockHash));
////           } else {
////                DSLog(@"[%@] Finished deleting MNL at height %u: %@", chain.name, mnlHeight, uint256_hex(blockHash));
////                chainEntity.baseBlockHash = uint256_data(chain.genesisHash);
////                [DSLocalMasternodeEntity deleteAllOnChainEntity:chainEntity];
////                [DSSimplifiedMasternodeEntryEntity deleteAllOnChainEntity:chainEntity];
////                [DSQuorumEntryEntity deleteAllOnChainEntity:chainEntity];
////            }
////            [context ds_save];
////            result = error;
////        }
////    }];
////    return result;
////}
//
//@end
