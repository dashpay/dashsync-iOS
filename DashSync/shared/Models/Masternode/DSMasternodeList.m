//
//  DSMasternodeList.m
//  DashSync
//
//  Created by Sam Westrich on 5/20/19.
//

#import "DSMasternodeList.h"
#import "BigIntTypes.h"
#import "DSChain.h"
#import "DSKeyManager.h"
#import "DSMerkleBlock.h"
#import "DSMutableOrderedDataKeyDictionary.h"
#import "DSPeer.h"
//#import "DSQuorumEntry.h"
//#import "DSSimplifiedMasternodeEntry.h"
#import "NSData+DSHash.h"
#import "NSData+Dash.h"
#import "NSManagedObject+Sugar.h"
#import "NSMutableData+Dash.h"

// from https://en.bitcoin.it/wiki/Protocol_specification#Merkle_Trees
// Merkle trees are binary trees of hashes. Merkle trees in bitcoin use a double SHA-256, the SHA-256 hash of the
// SHA-256 hash of something. If, when forming a row in the tree (other than the root of the tree), it would have an odd
// number of elements, the final double-hash is duplicated to ensure that the row has an even number of hashes. First
// form the bottom row of the tree with the ordered double-SHA-256 hashes of the byte streams of the transactions in the
// block. Then the row above it consists of half that number of hashes. Each entry is the double-SHA-256 of the 64-byte
// concatenation of the corresponding two hashes below it in the tree. This procedure repeats recursively until we reach
// a row consisting of just a single double-hash. This is the merkle root of the tree.
//
// from https://github.com/bitcoin/bips/blob/master/bip-0037.mediawiki#Partial_Merkle_branch_format
// The encoding works as follows: we traverse the tree in depth-first order, storing a bit for each traversed node,
// signifying whether the node is the parent of at least one matched leaf txid (or a matched txid itself). In case we
// are at the leaf level, or this bit is 0, its merkle node hash is stored, and its children are not explored further.
// Otherwise, no hash is stored, but we recurse into both (or the only) child branch. During decoding, the same
// depth-first traversal is performed, consuming bits and hashes as they written during encoding.
//
// example tree with three transactions, where only tx2 is matched by the bloom filter:
//
//     merkleRoot
//      /     \
//    m1       m2
//   /  \     /  \
// tx1  tx2 tx3  tx3
//
// flag bits (little endian): 00001011 [merkleRoot = 1, m1 = 1, tx1 = 0, tx2 = 1, m2 = 0, byte padding = 000]
// hashes: [tx1, tx2, m2]

//@interface DSMasternodeList ()
//
//@property (nonatomic, assign, nullable) DMasternodeList *list;
//
////@property (nonatomic, strong) NSMutableDictionary<NSData *, DSSimplifiedMasternodeEntry *> *mSimplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash;
//@property (nonatomic, strong) DSChain *chain;
////@property (nonatomic, assign) UInt256 blockHash;
////@property (nonatomic, assign) UInt256 masternodeMerkleRoot;
////@property (nonatomic, assign) UInt256 quorumMerkleRoot;
////@property (nonatomic, assign) uint32_t knownHeight;
////@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSMutableDictionary<NSData *, DSQuorumEntry *> *> *mQuorums;
//
//@end
//
//@implementation DSMasternodeList
//+ (instancetype)masternodeListWithStruct:(DMasternodeList *)masternodeList onChain:(DSChain *)chain {
//    DSMasternodeList *list = [[super alloc] init];
//    list.list = masternodeList;
//    list.chain = chain;
//    return list;
//}
//
//+ (instancetype)masternodeListWithSimplifiedMasternodeEntries:(NSArray<DSSimplifiedMasternodeEntry *> *)simplifiedMasternodeEntries
//                                                quorumEntries:(NSArray<DSQuorumEntry *> *)quorumEntries
//                                                  atBlockHash:(UInt256)blockHash
//                                                atBlockHeight:(uint32_t)blockHeight
//                                 withMasternodeMerkleRootHash:(UInt256)masternodeMerkleRootHash
//                                     withQuorumMerkleRootHash:(UInt256)quorumMerkleRootHash
//                                                      onChain:(DSChain *)chain {
//    NSMutableDictionary *masternodeDictionary = [NSMutableDictionary dictionary];
//    for (DSSimplifiedMasternodeEntry *entry in simplifiedMasternodeEntries) {
//        masternodeDictionary[uint256_data(entry.providerRegistrationTransactionHash).reverse] = entry;
//    }
//    NSMutableDictionary *quorumDictionary = [NSMutableDictionary dictionary];
//    for (DSQuorumEntry *entry in quorumEntries) {
//        NSMutableDictionary *quorumDictionaryForType = [quorumDictionary objectForKey:@(entry.llmqType)];
//        if (!quorumDictionaryForType) {
//            quorumDictionaryForType = [NSMutableDictionary dictionary];
//            quorumDictionary[@(entry.llmqType)] = quorumDictionaryForType;
//        }
//        quorumDictionaryForType[uint256_data(entry.quorumHash)] = entry;
//    }
//    return [[self alloc] initWithSimplifiedMasternodeEntriesDictionary:masternodeDictionary quorumEntriesDictionary:quorumDictionary atBlockHash:blockHash atBlockHeight:blockHeight withMasternodeMerkleRootHash:masternodeMerkleRootHash withQuorumMerkleRootHash:quorumMerkleRootHash onChain:chain];
//}

//+ (instancetype)masternodeListWithSimplifiedMasternodeEntriesDictionary:(NSDictionary<NSData *, DSSimplifiedMasternodeEntry *> *)simplifiedMasternodeEntries quorumEntriesDictionary:(NSDictionary<NSNumber *, NSDictionary<NSData *, DSQuorumEntry *> *> *)quorumEntries atBlockHash:(UInt256)blockHash atBlockHeight:(uint32_t)blockHeight withMasternodeMerkleRootHash:(UInt256)masternodeMerkleRootHash withQuorumMerkleRootHash:(UInt256)quorumMerkleRootHash onChain:(DSChain *)chain {
//    return [[self alloc] initWithSimplifiedMasternodeEntriesDictionary:simplifiedMasternodeEntries quorumEntriesDictionary:quorumEntries atBlockHash:blockHash atBlockHeight:blockHeight withMasternodeMerkleRootHash:masternodeMerkleRootHash withQuorumMerkleRootHash:quorumMerkleRootHash onChain:chain];
//}

//- (instancetype)initWithSimplifiedMasternodeEntriesDictionary:(NSDictionary<NSData *, DSSimplifiedMasternodeEntry *> *)simplifiedMasternodeEntries quorumEntriesDictionary:(NSDictionary<NSNumber *, NSDictionary<NSData *, DSQuorumEntry *> *> *)quorumEntries atBlockHash:(UInt256)blockHash atBlockHeight:(uint32_t)blockHeight withMasternodeMerkleRootHash:(UInt256)masternodeMerkleRootHash withQuorumMerkleRootHash:(UInt256)quorumMerkleRootHash onChain:(DSChain *)chain {
//    NSParameterAssert(chain);
//    
//    
//
//    if (!(self = [super init])) return nil;
////    self.list = dash_spv_masternode_processor_models_masternode_list_MasternodeList_ctor(<#struct dash_spv_crypto_crypto_byte_util_UInt256 *block_hash#>, <#uint32_t known_height#>, <#struct dash_spv_crypto_crypto_byte_util_UInt256 *masternode_merkle_root#>, <#struct dash_spv_crypto_crypto_byte_util_UInt256 *llmq_merkle_root#>, <#struct std_collections_Map_keys_dash_spv_crypto_crypto_byte_util_UInt256_values_dash_spv_masternode_processor_models_masternode_entry_MasternodeEntry *masternodes#>, <#struct std_collections_Map_keys_dash_spv_crypto_network_llmq_type_LLMQType_values_std_collections_Map_keys_dash_spv_crypto_crypto_byte_util_UInt256_values_dash_spv_crypto_llmq_entry_LLMQEntry *quorums#>)
////    self.masternodeMerkleRoot = masternodeMerkleRootHash;
////    self.quorumMerkleRoot = quorumMerkleRootHash;
////    self.knownHeight = blockHeight;
//    self.chain = chain;
////    self.blockHash = blockHash;
////    self.mSimplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash = [simplifiedMasternodeEntries mutableCopy];
////    self.mQuorums = [quorumEntries mutableCopy];
//    return self;
//}
//
//- (UInt256)masternodeMerkleRoot {
//    if (uint256_is_zero(_masternodeMerkleRoot)) {
//        return [self masternodeMerkleRootWithBlockHeightLookup:^uint32_t(UInt256 blockHash) {
//            return [self.chain heightForBlockHash:blockHash];
//        }];
//    }
//    return _masternodeMerkleRoot;
//}
//
//- (UInt256)masternodeMerkleRootWithBlockHeightLookup:(BlockHeightFinder)blockHeightLookup {
//    if (uint256_is_zero(_masternodeMerkleRoot)) {
//        self.masternodeMerkleRoot = [self calculateMasternodeMerkleRootWithBlockHeightLookup:blockHeightLookup];
//    }
//    return _masternodeMerkleRoot;
//}
//
//- (NSArray *)providerTxOrderedHashes {
//    struct Vec_dash_spv_crypto_crypto_byte_util_UInt256 *hashes = dash_spv_masternode_processor_models_masternode_list_MasternodeList_provider_tx_ordered_hashes(self.list);
//    NSArray *proTxHashes = [self.mSimplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash allKeys];
//    proTxHashes = [proTxHashes sortedArrayUsingComparator:^NSComparisonResult(id _Nonnull obj1, id _Nonnull obj2) {
//        UInt256 hash1 = *(UInt256 *)((NSData *)obj1).bytes;
//        UInt256 hash2 = *(UInt256 *)((NSData *)obj2).bytes;
//        return uint256_sup(hash1, hash2) ? NSOrderedDescending : NSOrderedAscending;
//    }];
//    return proTxHashes;
//}
//
//- (NSArray<NSData *> *)hashesForMerkleRootWithBlockHeightLookup:(BlockHeightFinder)blockHeightLookup {
//    if (!self.list) return nil;
//    uint32_t height = blockHeightLookup(self.blockHash);
//    
//    struct Vec_u8_32 *pro_tx_hashes = dash_spv_masternode_processor_models_masternode_list_MasternodeList_provider_tx_ordered_hashes((struct dash_spv_masternode_processor_models_masternode_list_MasternodeList *) self.list);
//    if (!pro_tx_hashes) return nil;
//    
////    NSArray *proTxHashes = [self providerTxOrderedHashes];
//    NSMutableArray *simplifiedMasternodeListByRegistrationTransactionHashHashes = [NSMutableArray array];
//    if (height == UINT32_MAX) {
//        DSLog(@"Block height lookup queried an unknown block %@", uint256_hex(self.blockHash));
//        return nil; //this should never happen
//    }
////    self.list->masternodes
//    for (int i = 0; i < pro_tx_hashes->count; i++) {
//        u256 *hash = pro_tx_hashes->values[i];
//        DMasternodeEntry *entry = masternode_list_map_by_key(self.list, hash);
//        u256 *entry_hash = dash_spv_masternode_processor_models_masternode_entry_MasternodeEntry_entry_hash_at(entry, height);
//        
//    }
//    for (NSData *proTxHash in proTxHashes) {
//        DSSimplifiedMasternodeEntry *simplifiedMasternodeEntry = [self.mSimplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash objectForKey:proTxHash];
//        UInt256 simplifiedMasternodeEntryHash = [simplifiedMasternodeEntry simplifiedMasternodeEntryHashAtBlockHeight:height];
//        [simplifiedMasternodeListByRegistrationTransactionHashHashes addObject:uint256_data(simplifiedMasternodeEntryHash)];
//    }
//    return simplifiedMasternodeListByRegistrationTransactionHashHashes;
//}
//
//- (NSDictionary<NSData *, NSData *> *)hashDictionaryForMerkleRootWithBlockHeightLookup:(BlockHeightFinder)blockHeightLookup {
//    NSArray *proTxHashes = [self providerTxOrderedHashes];
//
//    NSMutableDictionary *simplifiedMasternodeListByRegistrationTransactionHashHashes = [NSMutableDictionary dictionary];
//    uint32_t height = blockHeightLookup(self.blockHash);
//    if (height == UINT32_MAX) {
//        DSLog(@"Block height lookup queried an unknown block %@", uint256_hex(self.blockHash));
//        return nil; //this should never happen
//    }
//    for (NSData *proTxHash in proTxHashes) {
//        DSSimplifiedMasternodeEntry *simplifiedMasternodeEntry = [self.mSimplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash objectForKey:proTxHash];
//        UInt256 simplifiedMasternodeEntryHash = [simplifiedMasternodeEntry simplifiedMasternodeEntryHashAtBlockHeight:height];
//        simplifiedMasternodeListByRegistrationTransactionHashHashes[proTxHash] = uint256_data(simplifiedMasternodeEntryHash);
//    }
//    return simplifiedMasternodeListByRegistrationTransactionHashHashes;
//}
//
//- (UInt256)calculateMasternodeMerkleRootWithBlockHeightLookup:(BlockHeightFinder)blockHeightLookup {
//    NSArray *hashes = [self hashesForMerkleRootWithBlockHeightLookup:blockHeightLookup];
//    if (hashes == nil || hashes.count == 0) {
//        return UINT256_ZERO;
//    }
//    NSData *data = [NSData merkleRootFromHashes:hashes];
//    if (data == nil || data.length == 0) {
//        return UINT256_ZERO;
//    }
//    return [data UInt256];
//}
//
//- (UInt256)quorumMerkleRoot {
//    if (uint256_is_zero(_quorumMerkleRoot)) {
//        NSMutableArray *llmqCommitmentHashes = [NSMutableArray array];
//        for (NSNumber *number in self.mQuorums) {
//            for (DSQuorumEntry *quorumEntry in [self.mQuorums[number] allValues]) {
//                [llmqCommitmentHashes addObject:uint256_data(quorumEntry.quorumEntryHash)];
//            }
//        }
//        NSArray *sortedLlmqHashes = [llmqCommitmentHashes sortedArrayUsingComparator:^NSComparisonResult(id _Nonnull obj1, id _Nonnull obj2) {
//            UInt256 hash1 = uint256_reverse([(NSData *)obj1 UInt256]);
//            UInt256 hash2 = uint256_reverse([(NSData *)obj2 UInt256]);
//            return uint256_sup(hash1, hash2) ? NSOrderedDescending : NSOrderedAscending;
//        }];
//        self.quorumMerkleRoot = [[NSData merkleRootFromHashes:sortedLlmqHashes] UInt256];
//    }
//    return _quorumMerkleRoot;
//}
//
//
//- (DSMutableOrderedDataKeyDictionary *)calculateScores:(UInt256)modifier {
//    NSMutableDictionary<NSData *, id> *scores = [NSMutableDictionary dictionary];
//    for (NSData *registrationTransactionHash in self.mSimplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash) {
//        DSSimplifiedMasternodeEntry *simplifiedMasternodeEntry = self.mSimplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash[registrationTransactionHash];
//        if (uint256_is_zero(simplifiedMasternodeEntry.confirmedHash)) {
//            continue;
//        }
//        NSMutableData *data = [NSMutableData data];
//        [data appendData:[NSData dataWithUInt256:simplifiedMasternodeEntry.confirmedHashHashedWithProviderRegistrationTransactionHash].reverse];
//        [data appendData:[NSData dataWithUInt256:modifier].reverse];
//        UInt256 score = data.SHA256;
//        scores[[NSData dataWithUInt256:score]] = simplifiedMasternodeEntry;
//    }
//    DSMutableOrderedDataKeyDictionary *rankedScores = [[DSMutableOrderedDataKeyDictionary alloc] initWithMutableDictionary:scores keyAscending:YES];
//    [rankedScores addIndex:@"providerRegistrationTransactionHash"];
//    return rankedScores;
//}
//
//- (UInt256)masternodeScore:(DSSimplifiedMasternodeEntry *)simplifiedMasternodeEntry modifier:(UInt256)modifier atBlockHeight:(uint32_t)blockHeight {
//    NSParameterAssert(simplifiedMasternodeEntry);
//
//    if (uint256_is_zero([simplifiedMasternodeEntry confirmedHashAtBlockHeight:blockHeight])) {
//        return UINT256_ZERO;
//    }
//    NSMutableData *data = [NSMutableData data];
//    [data appendData:[NSData dataWithUInt256:[simplifiedMasternodeEntry confirmedHashHashedWithProviderRegistrationTransactionHashAtBlockHeight:blockHeight]]];
//    [data appendData:[NSData dataWithUInt256:modifier]];
//    return data.SHA256;
//}
//
//- (NSDictionary<NSData *, id> *)scoreDictionaryForQuorumModifier:(UInt256)quorumModifier atBlockHeight:(uint32_t)blockHeight {
//    NSMutableDictionary<NSData *, id> *scoreDictionary = [NSMutableDictionary dictionary];
//    for (NSData *registrationTransactionHash in self.mSimplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash) {
//        DSSimplifiedMasternodeEntry *simplifiedMasternodeEntry = self.mSimplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash[registrationTransactionHash];
//        UInt256 score = [self masternodeScore:simplifiedMasternodeEntry modifier:quorumModifier atBlockHeight:blockHeight];
//        if (uint256_is_zero(score)) continue;
//        scoreDictionary[[NSData dataWithUInt256:score]] = simplifiedMasternodeEntry;
//    }
//    return scoreDictionary;
//}
//
//- (NSArray *)scoresForQuorumModifier:(UInt256)quorumModifier atBlockHeight:(uint32_t)blockHeight {
//    NSDictionary<NSData *, id> *scoreDictionary = [self scoreDictionaryForQuorumModifier:quorumModifier atBlockHeight:blockHeight];
//    NSArray *scores = [[scoreDictionary allKeys] sortedArrayUsingComparator:^NSComparisonResult(id _Nonnull obj1, id _Nonnull obj2) {
//        UInt256 hash1 = *(UInt256 *)((NSData *)obj1).bytes;
//        UInt256 hash2 = *(UInt256 *)((NSData *)obj2).bytes;
//        return uint256_sup(hash1, hash2) ? NSOrderedAscending : NSOrderedDescending;
//    }];
//    return scores;
//}
//
//- (NSArray<DSSimplifiedMasternodeEntry *> *)validMasternodesForQuorumModifier:(UInt256)quorumModifier quorumCount:(NSUInteger)quorumCount {
//    return [self validMasternodesForQuorumModifier:quorumModifier
//                                       quorumCount:quorumCount
//                                 blockHeight:^uint32_t(UInt256 blockHash) {
//                                     DSMerkleBlock *block = [self.chain blockForBlockHash:blockHash];
//                                     if (!block) {
//                                         DSLog(@"Unknown block %@", uint256_reverse_hex(blockHash));
//                                         NSAssert(block, @"block should be known");
//                                     }
//                                     return block.height;
//                                 }(self.blockHash)];
//}
//
//- (NSArray<DSSimplifiedMasternodeEntry *> *)allMasternodesForQuorumModifier:(UInt256)quorumModifier quorumCount:(NSUInteger)quorumCount blockHeightLookup:(BlockHeightFinder)blockHeightLookup {
//    uint32_t blockHeight = blockHeightLookup(self.blockHash);
//    NSDictionary<NSData *, id> *scoreDictionary = [self scoreDictionaryForQuorumModifier:quorumModifier atBlockHeight:blockHeight];
//    NSArray *scores = [[scoreDictionary allKeys] sortedArrayUsingComparator:^NSComparisonResult(id _Nonnull obj1, id _Nonnull obj2) {
//        UInt256 hash1 = *(UInt256 *)((NSData *)obj1).bytes;
//        UInt256 hash2 = *(UInt256 *)((NSData *)obj2).bytes;
//        return uint256_sup(hash1, hash2) ? NSOrderedAscending : NSOrderedDescending;
//    }];
//    NSMutableArray *masternodes = [NSMutableArray array];
//    NSUInteger masternodesInListCount = self.mSimplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash.count;
//    for (int i = 0; i < masternodesInListCount && i < scores.count; i++) {
//        NSData *score = scores[i];
//        DSSimplifiedMasternodeEntry *masternode = scoreDictionary[score];
//        [masternodes addObject:masternode];
//    }
//    return masternodes;
//}
//
//- (NSArray<DSSimplifiedMasternodeEntry *> *)validMasternodesForQuorumModifier:(UInt256)quorumModifier quorumCount:(NSUInteger)quorumCount blockHeight:(uint32_t)blockHeight {
//    NSDictionary<NSData *, id> *scoreDictionary = [self scoreDictionaryForQuorumModifier:quorumModifier atBlockHeight:blockHeight];
//    NSArray *scores = [[scoreDictionary allKeys] sortedArrayUsingComparator:^NSComparisonResult(id _Nonnull obj1, id _Nonnull obj2) {
//        UInt256 hash1 = *(UInt256 *)((NSData *)obj1).bytes;
//        UInt256 hash2 = *(UInt256 *)((NSData *)obj2).bytes;
//        return uint256_sup(hash1, hash2) ? NSOrderedAscending : NSOrderedDescending;
//    }];
//    NSMutableArray *masternodes = [NSMutableArray array];
//    NSUInteger masternodesInListCount = self.mSimplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash.count;
//    for (int i = 0; i < masternodesInListCount && i < scores.count; i++) {
//        NSData *score = scores[i];
//        DSSimplifiedMasternodeEntry *masternode = scoreDictionary[score];
//        if ([masternode isValidAtBlockHeight:blockHeight]) {
//            [masternodes addObject:masternode];
//        }
//        if (masternodes.count == quorumCount) break;
//    }
//    return masternodes;
//}
//
//- (NSArray *)simplifiedMasternodeEntries {
////    self.list->
//    return self.mSimplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash.allValues;
//}
//
//- (NSArray *)reversedRegistrationTransactionHashes {
//    return self.mSimplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash.allKeys;
//}
//
//- (uint64_t)masternodeCount {
//    return dash_spv_masternode_processor_models_masternode_list_MasternodeList_masternode_count(self.list);
////    return [self.mSimplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash count];
//}
//
//- (uint64_t)validMasternodeCount {
//    
//    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"isValid == TRUE"];
//    return [[self.mSimplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash allValues] filteredArrayUsingPredicate:predicate].count;
//}
//
//- (NSUInteger)quorumsCount {
//    return dash_spv_masternode_processor_models_masternode_list_MasternodeList_quorums_count(self.list);
//    NSUInteger count = 0;
//    for (NSNumber *type in self.mQuorums) {
//        count += self.mQuorums[type].count;
//    }
//    return count;
//}
//
//- (NSUInteger)quorumsCountOfType:(DLLMQType)type {
//    
//    return self.mQuorums[@(type)].count;
//}
//
//- (NSDictionary *)quorumsOfType:(DLLMQType)type {
//    return self.mQuorums[@(type)];
//}
//
//- (NSUInteger)validQuorumsCount {
//    NSUInteger count = 0;
//    for (NSNumber *type in self.mQuorums) {
//        for (NSData *quorumHashData in self.mQuorums[type]) {
//            DSQuorumEntry *quorum = self.mQuorums[type][quorumHashData];
//            if (quorum.verified) count++;
//        }
//    }
//    return count;
//}
//
//- (NSUInteger)validQuorumsCountOfType:(DLLMQType)type {
//    NSUInteger count = 0;
//    for (NSData *quorumHashData in self.mQuorums[@(type)]) {
//        DSQuorumEntry *quorum = self.mQuorums[@(type)][quorumHashData];
//        if (quorum.verified) count++;
//    }
//    return count;
//}
//
//
//- (NSDictionary *)quorums {
//    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
//    NSMutableDictionary<NSNumber *, NSMutableDictionary<NSData *, DSQuorumEntry *> *> *q = [self.mQuorums copy];
//    for (NSNumber *number in q) {
//        dictionary[number] = [q objectForKey:number];
//    }
//    return [dictionary copy];
//}
//
//- (NSDictionary *)simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash {
//    return [self.mSimplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash copy];
//}
//
//- (uint32_t)height {
//    if (!self.knownHeight || self.knownHeight == UINT32_MAX) {
//        self.knownHeight = [self.chain heightForBlockHash:self.blockHash];
//    }
//    return self.knownHeight;
//}
//
/*
 - (BOOL)validateQuorumsWithMasternodeLists:(NSDictionary *)masternodeLists {
    for (DSQuorumEntry *quorum in self.quorums) {
        BOOL verified = quorum.verified;
        if (!verified) {
            DSMasternodeList *quorumMasternodeList = masternodeLists[uint256_data(quorum.quorumHash)];
            BOOL valid = [quorum validateWithMasternodeList:quorumMasternodeList];
            if (!valid) return FALSE;
        }
    }
    return TRUE;
}
*/
//
//- (void)saveToJsonFile:(NSString *)fileName {
////    return;
//    NSMutableArray<NSString *> *json_nodes = [NSMutableArray arrayWithCapacity:self.masternodeCount];
//    NSArray *proTxHashes = [self providerTxOrderedHashes];
//    for (NSData *proTxHash in proTxHashes) {
//        DSSimplifiedMasternodeEntry *entry = self.simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash[proTxHash];
//        NSString *json_node = [NSString stringWithFormat:@"{\n\"proRegTxHash\": \"%@\", \n\"confirmedHash\": \"%@\", \n\"service\": \"%@\", \n\"pubKeyOperator\": \"%@\", \n\"votingAddress\": \"%@\", \n\"isValid\": %s, \n\"updateHeight\": %@, \n\"knownConfirmedAtHeight\": %@\n}",
//                               uint256_hex(entry.providerRegistrationTransactionHash),
//                               uint256_hex(entry.confirmedHash),
//                               uint128_hex(entry.address),
//                               uint384_hex(entry.operatorPublicKey),
//                               uint160_data(entry.keyIDVoting).base58String,
//                               entry.isValid ? "true" : "false", @(entry.updateHeight), @(entry.knownConfirmedAtHeight)];
//        [json_nodes addObject:json_node];
//    }
//    NSMutableArray<NSString *> *json_quorums = [NSMutableArray arrayWithCapacity:self.quorumsCount];
//    NSArray *llmqTypes = [[self.mQuorums allKeys] sortedArrayUsingComparator:^NSComparisonResult(NSNumber* n1, NSNumber* n2) {
//        return [n1 compare:n2];
//    }];
//    for (NSNumber *llmqType in llmqTypes) {
//        NSMutableDictionary *quorumsForMasternodeType = self.mQuorums[llmqType];
//        NSArray *llmqHashes = [quorumsForMasternodeType allKeys];
//        llmqHashes = [llmqHashes sortedArrayUsingComparator:^NSComparisonResult(id _Nonnull obj1, id _Nonnull obj2) {
//            UInt256 hash1 = *(UInt256 *)((NSData *)obj1).bytes;
//            UInt256 hash2 = *(UInt256 *)((NSData *)obj2).bytes;
//            return uint256_sup(hash1, hash2) ? NSOrderedDescending : NSOrderedAscending;
//        }];
//        for (NSData *quorumHash in llmqHashes) {
//            DSQuorumEntry *entry = quorumsForMasternodeType[quorumHash];
//            NSString *json_quorum = [NSString stringWithFormat:@"{\n\"version\": %@, \n\"llmqType\": %@, \n\"quorumHash\": \"%@\", \n\"quorumIndex\": %@, \n\"signersCount\": %@, \n\"signers\": \"%@\", \n\"validMembersCount\": %@, \n\"validMembers\": \"%@\", \n\"quorumPublicKey\": \"%@\", \n\"quorumVvecHash\": \"%@\", \n\"quorumSig\": \"%@\", \n\"membersSig\": \"%@\"\n}",
//                                     @(entry.version),
//                                     @(entry.llmqType),
//                                     uint256_hex(entry.quorumHash),
//                                     @(entry.quorumIndex),
//                                     @(entry.signersCount),
//                                     [entry signersBitset].hexString,
//                                     @(entry.validMembersCount),
//                                     [entry validMembersBitset].hexString,
//                                     uint384_hex(entry.quorumPublicKey),
//                                     uint256_hex(entry.quorumVerificationVectorHash),
//                                     uint768_hex(entry.quorumThresholdSignature),
//                                     uint768_hex(entry.allCommitmentAggregatedSignature)];
//            
//            [json_quorums addObject:json_quorum];
//        }
//    }
//    NSString *nodes = [NSString stringWithFormat:@"\n\"mnList\": [%@]", [json_nodes componentsJoinedByString:@","]];
//    NSString *quorums = [NSString stringWithFormat:@"\n\"newQuorums\": [%@]", [json_quorums componentsJoinedByString:@","]];
//    NSString *list = [NSString stringWithFormat:@"{\n\"blockHash\":\"%@\", \n\"knownHeight\":%@, \n\"masternodeMerkleRoot\":\"%@\", \n\"quorumMerkleRoot\":\"%@\", \n%@, \n%@\n}", uint256_hex(self.blockHash), @(self.knownHeight), uint256_hex(self.masternodeMerkleRoot), uint256_hex(self.quorumMerkleRoot), nodes, quorums];
//    NSData* data = [list dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
//    [data saveToFile:fileName inDirectory:NSCachesDirectory];
//    DSLog(@"•-• File %@ saved", fileName);
//}
//
//- (void)saveToJsonFileExtended:(NSString *)fileName {
//    NSMutableArray<NSString *> *json_nodes = [NSMutableArray arrayWithCapacity:self.masternodeCount];
//    NSArray *proTxHashes = [self providerTxOrderedHashes];
//    for (NSData *proTxHash in proTxHashes) {
//        DSSimplifiedMasternodeEntry *entry = self.simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash[proTxHash];
//        NSMutableArray<NSString *> *json_prev_public_keys = [NSMutableArray arrayWithCapacity:entry.previousOperatorPublicKeys.count];
//        for (DSBlock *block in entry.previousOperatorPublicKeys) {
//            [json_prev_public_keys addObject:[NSString stringWithFormat:@"{\n\"block_height\":%u, \n\"block_hash\":\"%@\", \n\"public_key\":\"%@\"\n}", block.height, uint256_hex(block.blockHash), ((NSData *)entry.previousOperatorPublicKeys[block]).hexString]];
//        }
//        NSMutableArray<NSString *> *json_prev_entry_hashes = [NSMutableArray arrayWithCapacity:entry.previousSimplifiedMasternodeEntryHashes.count];
//        for (DSBlock *block in entry.previousSimplifiedMasternodeEntryHashes) {
//            [json_prev_entry_hashes addObject:[NSString stringWithFormat:@"{\n\"block_height\":%u, \n\"block_hash\":\"%@\", \n\"entry_hash\":\"%@\"\n}", block.height, uint256_hex(block.blockHash), ((NSData *)entry.previousSimplifiedMasternodeEntryHashes[block]).hexString]];
//        }
//        NSMutableArray<NSString *> *json_prev_validities = [NSMutableArray arrayWithCapacity:entry.previousValidity.count];
//        for (DSBlock *block in entry.previousValidity) {
//            [json_prev_validities addObject:[NSString stringWithFormat:@"{\n\"block_height\":%u, \n\"block_hash\":\"%@\", \n\"is_valid\":\%s\n}", block.height, uint256_hex(block.blockHash), ((NSNumber *) entry.previousValidity[block]).boolValue ? "true" : "false"]];
//        }
//
//        NSString *json_node = [NSString stringWithFormat:@"{\n\"provider_registration_transaction_hash\": \"%@\", \n\"confirmed_hash\": \"%@\", \n\"confirmed_hash_hashed_with_provider_registration_transaction_hash\": \"%@\", \n\"socket_address\": {\n\"ip_address\":\"%@\",\n\"port\":%@\n}, \n\"operator_public_key\": \"%@\", \n\"previous_operator_public_keys\": [\n%@\n], \n\"previous_entry_hashes\": [\n%@\n], \n\"previous_validity\": [\n%@\n], \n\"known_confirmed_at_height\": %@, \n\"update_height\": %@, \n\"key_id_voting\": \"%@\", \n\"isValid\": %s, \n\"entry_hash\": \"%@\"\n}",
//                               uint256_hex(entry.providerRegistrationTransactionHash),
//                               uint256_hex(entry.confirmedHash),
//                               uint256_hex(entry.confirmedHashHashedWithProviderRegistrationTransactionHash),
//                               uint128_hex(entry.address),
//                               @(entry.port),
//                               uint384_hex(entry.operatorPublicKey),
//                               [NSString stringWithFormat:@"%@", [json_prev_public_keys componentsJoinedByString:@","]],
//                               [NSString stringWithFormat:@"%@", [json_prev_entry_hashes componentsJoinedByString:@","]],
//                               [NSString stringWithFormat:@"%@", [json_prev_validities componentsJoinedByString:@","]],
//                               @(entry.knownConfirmedAtHeight),
//                               @(entry.updateHeight),
//                               uint160_data(entry.keyIDVoting).base58String,
//                               entry.isValid ? "true" : "false",
//                               uint256_hex(entry.simplifiedMasternodeEntryHash)];
//        [json_nodes addObject:json_node];
//    }
//    NSMutableArray<NSString *> *json_quorums = [NSMutableArray arrayWithCapacity:self.quorumsCount];
//    NSArray *llmqTypes = [[self.mQuorums allKeys] sortedArrayUsingComparator:^NSComparisonResult(NSNumber* n1, NSNumber* n2) {
//        return [n1 compare:n2];
//    }];
//    for (NSNumber *llmqType in llmqTypes) {
//        NSMutableDictionary *quorumsForMasternodeType = self.mQuorums[llmqType];
//        NSArray *llmqHashes = [quorumsForMasternodeType allKeys];
//        llmqHashes = [llmqHashes sortedArrayUsingComparator:^NSComparisonResult(id _Nonnull obj1, id _Nonnull obj2) {
//            UInt256 hash1 = *(UInt256 *)((NSData *)obj1).bytes;
//            UInt256 hash2 = *(UInt256 *)((NSData *)obj2).bytes;
//            return uint256_sup(hash1, hash2) ? NSOrderedDescending : NSOrderedAscending;
//        }];
//        for (NSData *quorumHash in llmqHashes) {
//            DSQuorumEntry *entry = quorumsForMasternodeType[quorumHash];
//            NSString *json_quorum = [NSString stringWithFormat:@"{\n\"version\": %@, \n\"llmqType\": %@, \n\"quorumHash\": \"%@\", \n\"quorumIndex\": %@, \n\"signersCount\": %@, \n\"signers\": \"%@\", \n\"validMembersCount\": %@, \n\"validMembers\": \"%@\", \n\"quorumPublicKey\": \"%@\", \n\"quorumVvecHash\": \"%@\", \n\"quorumSig\": \"%@\", \n\"membersSig\": \"%@\"\n}",
//                                     @(entry.version),
//                                     @(entry.llmqType),
//                                     uint256_hex(entry.quorumHash),
//                                     @(entry.quorumIndex),
//                                     @(entry.signersCount),
//                                     [entry signersBitset].hexString,
//                                     @(entry.validMembersCount),
//                                     [entry validMembersBitset].hexString,
//                                     uint384_hex(entry.quorumPublicKey),
//                                     uint256_hex(entry.quorumVerificationVectorHash),
//                                     uint768_hex(entry.quorumThresholdSignature),
//                                     uint768_hex(entry.allCommitmentAggregatedSignature)];
//            
//            [json_quorums addObject:json_quorum];
//        }
//    }
//    NSString *nodes = [NSString stringWithFormat:@"\n\"mnList\": [%@]", [json_nodes componentsJoinedByString:@","]];
//    NSString *quorums = [NSString stringWithFormat:@"\n\"newQuorums\": [%@]", [json_quorums componentsJoinedByString:@","]];
//    NSString *list = [NSString stringWithFormat:@"{\n\"blockHash\":\"%@\", \n\"knownHeight\":%@, \n\"masternodeMerkleRoot\":\"%@\", \n\"quorumMerkleRoot\":\"%@\", \n%@, \n%@\n}", uint256_hex(self.blockHash), @(self.knownHeight), uint256_hex(self.masternodeMerkleRoot), uint256_hex(self.quorumMerkleRoot), nodes, quorums];
//    NSData* data = [list dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
//    [data saveToFile:fileName inDirectory:NSCachesDirectory];
//    DSLog(@"•-• File %@ saved", fileName);
//}
//
//- (NSString *)description {
//    return [[super description] stringByAppendingString:[NSString stringWithFormat:@" {%u}", self.height]];
//}
//
//- (NSString *)debugDescription {
////    [self saveToJsonFile];
//    return [[super debugDescription] stringByAppendingString:[NSString stringWithFormat:@" {%u}", self.height]];
//}
//
//- (NSDictionary *)compareWithPrevious:(DSMasternodeList *)other {
//    return [self compareWithPrevious:other
//                   blockHeightLookup:^uint32_t(UInt256 blockHash) {
//                       return [self.chain heightForBlockHash:blockHash];
//                   }];
//}
//
//- (NSDictionary *)compareWithPrevious:(DSMasternodeList *)other blockHeightLookup:(BlockHeightFinder)blockHeightLookup {
//    return [self compare:other usingOurString:@"current" usingTheirString:@"previous" blockHeightLookup:blockHeightLookup];
//}
//
//- (NSDictionary *)compare:(DSMasternodeList *)other {
//    return [self compare:other
//        blockHeightLookup:^uint32_t(UInt256 blockHash) {
//            return [self.chain heightForBlockHash:blockHash];
//        }];
//}
//
//- (NSDictionary *)compare:(DSMasternodeList *)other blockHeightLookup:(BlockHeightFinder)blockHeightLookup {
//    return [self compare:other usingOurString:@"ours" usingTheirString:@"theirs" blockHeightLookup:blockHeightLookup];
//}
//
//- (NSDictionary *)listOfChangedNodesComparedTo:(DSMasternodeList *)previous {
//    NSMutableArray *added = [NSMutableArray array];
//    NSMutableArray *removed = [NSMutableArray array];
//    NSMutableArray *addedValidity = [NSMutableArray array];
//    NSMutableArray *removedValidity = [NSMutableArray array];
//    for (NSData *data in self.simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash) {
//        DSSimplifiedMasternodeEntry *currentEntry = self.simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash[data];
//        DSSimplifiedMasternodeEntry *previousEntry = previous.simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash[data];
//        if (currentEntry && !previousEntry) {
//            [added addObject:currentEntry];
//        } else if ([currentEntry isValidAtBlockHeight:self.height] && ![previousEntry isValidAtBlockHeight:previous.height]) {
//            [addedValidity addObject:currentEntry];
//        } else if (![currentEntry isValidAtBlockHeight:self.height] && [previousEntry isValidAtBlockHeight:previous.height]) {
//            [removedValidity addObject:currentEntry];
//        }
//    }
//
//    for (NSData *data in previous.simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash) {
//        DSSimplifiedMasternodeEntry *currentEntry = self.simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash[data];
//        DSSimplifiedMasternodeEntry *previousEntry = previous.simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash[data];
//        if (!currentEntry && previousEntry) {
//            [removed addObject:previousEntry];
//        }
//    }
//
//    return @{MASTERNODE_LIST_ADDED_NODES: added, MASTERNODE_LIST_REMOVED_NODES: removed, MASTERNODE_LIST_ADDED_VALIDITY: addedValidity, MASTERNODE_LIST_REMOVED_VALIDITY: removedValidity};
//}
//
//- (NSDictionary *)compare:(DSMasternodeList *)other usingOurString:(NSString *)ours usingTheirString:(NSString *)theirs blockHeightLookup:(BlockHeightFinder)blockHeightLookup {
//    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
//    for (NSData *data in self.simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash) {
//        DSSimplifiedMasternodeEntry *ourEntry = self.simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash[data];
//        DSSimplifiedMasternodeEntry *theirEntry = other.simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash[data];
//        if (ourEntry && theirEntry) {
//            NSDictionary *entryComparison = [ourEntry compare:theirEntry ourBlockHash:self.blockHash theirBlockHash:other.blockHash usingOurString:ours usingTheirString:theirs blockHeightLookup:blockHeightLookup];
//            if (entryComparison.count) {
//                dictionary[data] = entryComparison;
//            }
//        } else if (ourEntry) {
//            dictionary[data] = @{@"absent": uint256_hex(ourEntry.providerRegistrationTransactionHash)};
//        }
//    }
//    return dictionary;
//}

//- (NSDictionary *)toDictionaryUsingBlockHeightLookup:(BlockHeightFinder)blockHeightLookup {
//    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
//    for (NSData *data in self.simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash) {
//        DSSimplifiedMasternodeEntry *ourEntry = self.simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash[data];
//        if (ourEntry) {
//            NSDictionary *entryDictionary = [ourEntry toDictionaryAtBlockHash:self.blockHash usingBlockHeightLookup:blockHeightLookup];
//            dictionary[[data base64String]] = entryDictionary;
//        }
//    }
//    return dictionary;
//}
//
//- (DSQuorumEntry *)quorumEntryForLockRequestID:(UInt256)requestID ofQuorumType:(DLLMQType)quorumType {
//    NSArray *quorumsForLock = [self.quorums[@(quorumType)] allValues];
//    UInt256 lowestValue = UINT256_MAX;
//    DSQuorumEntry *firstQuorum = nil;
//    for (DSQuorumEntry *quorumEntry in quorumsForLock) {
//        UInt256 orderingHash = uint256_reverse([quorumEntry orderingHashForRequestID:requestID forQuorumType:quorumType]);
//        if (uint256_sup(lowestValue, orderingHash)) {
//            lowestValue = orderingHash;
//            firstQuorum = quorumEntry;
//        }
//    }
//    return firstQuorum;
//}


//- (DLLMQEntry *_Nullable)quorumEntryForPlatformWithQuorumHash:(UInt256)quorumHash
//                                                 ofQuorumType:(DLLMQType)quorumType {
//    u256 *quorum_hash = u256_ctor_u(quorumHash);
//    return dash_spv_masternode_processor_models_masternode_list_MasternodeList_platform_llmq_with_quorum_hash(self.list, quorum_hash, &quorumType);
//
////    NSArray *quorumsForPlatform = [self.quorums[@(quorumType)] allValues];
////    for (DSQuorumEntry *quorumEntry in quorumsForPlatform) {
////        if (uint256_eq(quorumEntry.quorumHash, quorumHash)) {
////            return quorumEntry;
////        }
////        NSAssert(!uint256_eq(quorumEntry.quorumHash, uint256_reverse(quorumHash)), @"these should not be inversed");
////    }
////    return nil;
//}
//
//- (DLLMQEntry *)quorumEntryForPlatformWithQuorumHash:(UInt256)quorumHash {
//    return [self quorumEntryForPlatformWithQuorumHash:quorumHash ofQuorumType:quorum_type_for_platform(self.chain.chainType)];
//}

//- (NSArray<DSQuorumEntry *> *)quorumEntriesRankedForInstantSendRequestID:(UInt256)requestID {
////    ordered_quorums_for_is_lock
//    dash_spv_crypto_network_chain_type_ChainType_as_crate_fermented_types_dash_spv_crypto_network_chain_type_dash_spv_crypto_network_chain_type_IHaveChainSettings(self.chain.chainType);
//    dash_spv_crypto_network_chain_type_ChainType_chain_locks_type(self.chain.chainType);
//    
//    DLLMQType quorumType = quorum_type_for_chain_locks(self.chain.chainType);
//    NSArray *quorumsForIS = [self.quorums[@(quorumType)] allValues];
//    NSMutableDictionary *orderedQuorumDictionary = [NSMutableDictionary dictionary];
//    for (DSQuorumEntry *quorumEntry in quorumsForIS) {
//        UInt256 orderingHash = uint256_reverse([quorumEntry orderingHashForRequestID:requestID forQuorumType:quorumType]);
//        orderedQuorumDictionary[quorumEntry] = uint256_data(orderingHash);
//    }
//    NSArray *orderedQuorums = [orderedQuorumDictionary keysSortedByValueUsingComparator:^NSComparisonResult(id _Nonnull obj1, id _Nonnull obj2) {
//        return uint256_sup([obj1 UInt256], [obj2 UInt256]) ? NSOrderedDescending : NSOrderedAscending;
//    }];
//    return orderedQuorums;
//}

//- (NSArray<DSPeer *> *)peers:(uint32_t)peerCount withConnectivityNonce:(uint64_t)connectivityNonce {
//    Vec_dash_spv_masternode_processor_common_socket_address_SocketAddress *vec =
//    dash_spv_masternode_processor_models_masternode_list_MasternodeList_peer_addresses_with_connectivity_nonce(self.list, connectivityNonce, peerCount);
//    NSMutableArray *mArray = [NSMutableArray array];
//    for (int i = 0; i < vec->count; i++) {
//        dash_spv_masternode_processor_common_socket_address_SocketAddress *address = vec->values[i];
//        u128 *arr = address->ip_address;
//        UInt128 addr = NSDataFromPtr(arr).UInt128;
//        
//        
////        UInt128 addr = [NSData dataWithBytes:(const void *)arr->values length:arr->count].UInt128;
//        DSPeer *peer = [[DSPeer alloc] initWithAddress:addr andPort:address->port onChain:self.chain];
//        [mArray addObject:peer ];
//    }
//    Vec_dash_spv_masternode_processor_common_socket_address_SocketAddress_destroy(vec);
//    
//    
////    NSArray<NSData *> *registrationTransactionHashes = [self.mSimplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash allKeys];
////    NSArray<NSData *> *sortedHashes = [registrationTransactionHashes sortedArrayUsingComparator:^NSComparisonResult(NSData *_Nonnull obj1, NSData *_Nonnull obj2) {
////        UInt256 hash1 = [[[obj1 mutableCopy] appendUInt64:connectivityNonce] blake3];
////        UInt256 hash2 = [[[obj2 mutableCopy] appendUInt64:connectivityNonce] blake3];
////        return uint256_sup(hash1, hash2) ? NSOrderedDescending : NSOrderedAscending;
////    }];
////    NSMutableArray *mArray = [NSMutableArray array];
////    for (uint32_t i = 0; i < MIN(peerCount, self.mSimplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash.count); i++) {
////        DSSimplifiedMasternodeEntry *masternodeEntry = self.mSimplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash[sortedHashes[i]];
////        if (masternodeEntry.isValid) {
////            DSPeer *peer = [[DSPeer alloc] initWithAddress:masternodeEntry.address andPort:masternodeEntry.port onChain:masternodeEntry.chain];
////            [mArray addObject:peer];
////        }
////    }
//    return mArray;
//}
//
//- (DSSimplifiedMasternodeEntry *)masternodeForRegistrationHash:(UInt256)registrationHash {
//    return self.simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash[uint256_data(registrationHash)];
//}
//
//- (BOOL)hasUnverifiedNonRotatedQuorums {
//    return dash_spv_masternode_processor_models_masternode_list_MasternodeList_has_unverified_regular_quorums(self.list, self.chain.chainType);
//}
//
//- (BOOL)hasUnverifiedRotatedQuorums {
//    return dash_spv_masternode_processor_models_masternode_list_MasternodeList_has_unverified_rotated_quorums(self.list, self.chain.chainType);
//}
//
//- (DSQuorumEntry *_Nullable)quorumEntryOfType:(DLLMQType)llmqType withQuorumHash:(UInt256)quorumHash {
//    NSDictionary *quorums = [self quorumsOfType:llmqType];
//    for (NSData *hash in quorums) {
//        DSQuorumEntry *entry = quorums[hash];
//        if (uint256_eq(entry.quorumHash, quorumHash)) {
//            return entry;
//        }
//    }
//    return NULL;
//}
//
//- (DSMasternodeList *)mergedWithMasternodeList:(DSMasternodeList *)masternodeList {
//    for (NSData *proTxHash in self.simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash) {
//        DSSimplifiedMasternodeEntry *entry = self.simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash[proTxHash];
//        DSSimplifiedMasternodeEntry *newEntry = masternodeList.simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash[proTxHash];
//        [entry mergedWithSimplifiedMasternodeEntry:newEntry atBlockHeight:masternodeList.height];
//    }
//    for (NSNumber *quorumType in self.mQuorums) {
//        NSDictionary<NSData *, DSQuorumEntry *> *quorumsOfType = self.quorums[quorumType];
//        for (NSData *quorumHash in quorumsOfType) {
//            DSQuorumEntry *entry = quorumsOfType[quorumHash];
//            if (!entry.verified) {
//                
//                DSQuorumEntry *quorumEntry = [masternodeList quorumEntryOfType:(DLLMQType)quorumType.unsignedIntegerValue withQuorumHash:entry.quorumHash];
//                if (quorumEntry.verified) {
//                    [entry mergedWithQuorumEntry:quorumEntry];
//                }
//            }
//        }
//    }
//    return self;
//}
//
//@end
