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
#import "DSMasternodeList+Mndiff.h"
#import "DSMasternodeListEntity+CoreDataClass.h"
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
#import "DSSimplifiedMasternodeEntry+Mndiff.h"
#import "DSSimplifiedMasternodeEntryEntity+CoreDataClass.h"
#import "DSTransactionFactory.h"
#import "DSTransactionManager+Protected.h"
#import "NSArray+Dash.h"
#import "NSData+DSHash.h"
#import "NSDictionary+Dash.h"
#import "NSManagedObject+Sugar.h"
#import "NSMutableData+Dash.h"
#import "NSString+Bitcoin.h"
#import "mndiff.h"
#import "rust_utils.h"

#define FAULTY_DML_MASTERNODE_PEERS @"FAULTY_DML_MASTERNODE_PEERS"
#define CHAIN_FAULTY_DML_MASTERNODE_PEERS [NSString stringWithFormat:@"%@_%@", peer.chain.uniqueID, FAULTY_DML_MASTERNODE_PEERS]
#define MAX_FAULTY_DML_PEERS 2

#define LOG_MASTERNODE_DIFF (0 && DEBUG)
#define KEEP_OLD_QUORUMS 0
#define SAVE_MASTERNODE_DIFF_TO_FILE (0 && DEBUG)
#define SAVE_MASTERNODE_ERROR_TO_FILE (0 && DEBUG)
#define SAVE_MASTERNODE_NO_ERROR_TO_FILE (0 && DEBUG)
#define DSFullLog(FORMAT, ...) printf("%s\n", [[NSString stringWithFormat:FORMAT, ##__VA_ARGS__] UTF8String])


@interface DSMasternodeManager ()

@property (nonatomic, strong) DSChain *chain;
@property (nonatomic, strong) DSMasternodeList *currentMasternodeList;
@property (nonatomic, strong) DSMasternodeList *masternodeListAwaitingQuorumValidation;
@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, strong) NSMutableSet *masternodeListQueriesNeedingQuorumsValidated;
@property (nonatomic, assign) UInt256 lastQueriedBlockHash; //last by height, not by time queried
@property (nonatomic, strong) NSData *processingMasternodeListDiffHashes;
@property (nonatomic, strong) NSMutableDictionary<NSData *, DSMasternodeList *> *masternodeListsByBlockHash;
@property (nonatomic, strong) NSMutableSet<NSData *> *masternodeListsBlockHashStubs;
@property (nonatomic, strong) NSMutableDictionary<NSData *, NSNumber *> *cachedBlockHashHeights;
@property (nonatomic, strong) NSMutableDictionary<NSData *, DSLocalMasternode *> *localMasternodesDictionaryByRegistrationTransactionHash;
@property (nonatomic, strong) NSMutableOrderedSet<NSData *> *masternodeListRetrievalQueue;
@property (nonatomic, assign) NSUInteger masternodeListRetrievalQueueMaxAmount;
@property (nonatomic, strong) NSMutableSet<NSData *> *masternodeListsInRetrieval;
@property (nonatomic, assign) NSTimeInterval timeIntervalForMasternodeRetrievalSafetyDelay;
@property (nonatomic, assign) uint16_t timedOutAttempt;
@property (nonatomic, assign) uint16_t timeOutObserverTry;
@property (atomic, assign) uint32_t masternodeListCurrentlyBeingSavedCount;
@property (nonatomic, strong) NSDictionary<NSData *, NSString *> *fileDistributedMasternodeLists; //string is the path
@property (nonatomic, strong) dispatch_queue_t masternodeSavingQueue;

@end

@implementation DSMasternodeManager

///////// Test OK, no memory leaks
+ (TestStruct *)wrapTestStruct:(DSTestStructContext *)context {
    NSLog(@"wrapTestStruct: %p", context);
    if (!context) return NULL;
    NSArray<NSData *> *testKeys = context.keys;
    NSUInteger testKeysCount = testKeys.count;
    TestStruct *test_struct = malloc(sizeof(TestStruct));
    NSLog(@"wrapTestStruct: %p", test_struct);
    uint8_t(*hash)[32] = malloc(sizeof(uint8_t(*)[32]));
    memcpy(hash, context.testHash.u8, sizeof(uint8_t(*)[32]));
    test_struct->hash = hash;
    NSLog(@"wrapTestStruct: hash: %p", test_struct->hash);
    test_struct->height = context.height;
    NSLog(@"wrapTestStruct: height: %u", test_struct->height);
    test_struct->keys_count = testKeysCount;
    NSLog(@"wrapTestStruct: height: %lu", test_struct->keys_count);
    uint8_t(**keys)[32] = malloc(testKeysCount * sizeof(uint8_t(*)[32]));
    for (NSUInteger i = 0; i < testKeysCount; i++) {
        NSData *hashData = testKeys[i];
        uint8_t(*hash)[32] = malloc(sizeof(uint8_t[32]));
        memcpy(hash, hashData.bytes, hashData.length);
        NSLog(@"wrapTestStruct: key[%lu]: %p", (unsigned long)i, hash);
        keys[i] = hash;
    }
    test_struct->keys = keys;
    NSLog(@"wrapTestStruct: keys: %p", test_struct->keys);
    return test_struct;
}

+ (void)freeTestStruct:(TestStruct *)test_struct {
    NSLog(@"freeTestStruct: %p", test_struct);
    if (!test_struct) return;
    NSLog(@"freeTestStruct: hash: %p", test_struct->hash);
    if (test_struct->hash)
        free(test_struct->hash);
    NSLog(@"freeTestStruct: keys: %p", test_struct->keys);
    if (test_struct->keys) {
        for (int i = 0; i < test_struct->keys_count; i++) {
            NSLog(@"freeTestStruct: key[%i]: %p", i, test_struct->keys[i]);
            free(test_struct->keys[i]);
        }
        free(test_struct->keys);
    }
    NSLog(@"freeTestStruct: keys: %p", test_struct);
    free(test_struct);
}

///////// Test OK, no memory leaks
+ (void)testStructWithContext:(DSTestStructContext *)context completion:(void (^)(DSTestStructContext *))completion {
    NSLog(@"testStructWithContext #start with %p", context);
    TestStruct *test_struct = [DSMasternodeManager wrapTestStruct:context];
    NSLog(@"testStructWithContext #context wrapped as %p", test_struct);
    TestStruct *result = mndiff_test_struct_create(test_struct);
    NSLog(@"testStructWithContext #result: %p", result);
    [DSMasternodeManager freeTestStruct:test_struct];
    NSLog(@"testStructWithContext #context freed: %p", test_struct);
    DSTestStructContext *newContext = [[DSTestStructContext alloc] initWith:result];
    NSLog(@"testStructWithContext #result unwrapped: %p", newContext);
    mndiff_test_struct_destroy(result);
    NSLog(@"testStructWithContext #destroyed: %p", result);
    completion(newContext);
}


+ (void)testCallbackWithContext:(DSMasternodeDiffMessageContext *)context completion:(void (^)(DSMasternodeList *))completion {
    DSMasternodeList *baseMasternodeList = [context baseMasternodeList];
    MasternodeList *list = [DSMasternodeManager wrapMasternodeList:baseMasternodeList];
    MasternodeList *result = mndiff_test_memory_leaks(list);
    [DSMasternodeManager freeMasternodeList:list];
    DSMasternodeList *masternodeList = [DSMasternodeList masternodeListWith:result onChain:context.chain];
    mndiff_test_memory_leaks_destroy(result);
    completion(masternodeList);
}

const MasternodeList *masternodeListLookupCallback(uint8_t (*block_hash)[32], const void *context) {
    DSMasternodeDiffMessageContext *mndiffContext = (__bridge DSMasternodeDiffMessageContext *)context;
    NSData *data = [NSData dataWithBytes:block_hash length:32];
    DSMasternodeList *list = mndiffContext.masternodeListLookup(data.UInt256);
    NSLog(@"masternodeListLookupCallback.1: %@", list.description);
    MasternodeList *c_list = [DSMasternodeManager wrapMasternodeList:list];
    NSLog(@"masternodeListLookupCallback.2: -> %p", c_list);
    LogEntryHashes(c_list);
    mndiff_block_hash_destroy(block_hash);
    return c_list;
}
void LogEntryHashes(MasternodeList *list) {
    if (!list) return;
    MasternodeEntry **masternodes_values = list->masternodes_values;
    uintptr_t masternodes_count = list->masternodes_count;
    for (NSUInteger i = 0; i < masternodes_count; i++) {
        MasternodeEntry *entry = masternodes_values[i];
        MasternodeEntryHash **previous_masternode_entry_hashes = entry->previous_masternode_entry_hashes;
        uintptr_t previous_masternode_entry_hashes_count = entry->previous_masternode_entry_hashes_count;
        BOOL needLog = previous_masternode_entry_hashes_count > 1;
        for (NSUInteger i = 0; i < previous_masternode_entry_hashes_count; i++) {
            MasternodeEntryHash *masternode_entry_hash = previous_masternode_entry_hashes[i];
            uint32_t blockHeight = masternode_entry_hash->block_height;
            NSData *hash = [NSData dataWithBytes:masternode_entry_hash->hash length:32];
            if (needLog) NSLog(@"logEntryHashes.previous_masternode_entry_hashes[%lu]:%p\n%u:%@", i, masternode_entry_hash, blockHeight, hash.hexString);
        }
    }
}

void masternodeListDestroyCallback(const MasternodeList *masternode_list) {
    NSLog(@"masternodeListDestroyCallback: -> %p", masternode_list);
    LogEntryHashes((MasternodeList *)masternode_list);
    [DSMasternodeManager freeMasternodeList:(MasternodeList *)masternode_list];
}

uint32_t blockHeightListLookupCallback(uint8_t (*block_hash)[32], const void *context) {
    DSMasternodeDiffMessageContext *mndiffContext = (__bridge DSMasternodeDiffMessageContext *)context;
    //NSLog(@"blockHeightListLookupCallback.start %@ %@", context, mndiffContext);
    NSData *data = [NSData dataWithBytes:block_hash length:32];
    uint32_t block_height = mndiffContext.blockHeightLookup(data.UInt256);
    //NSLog(@"blockHeightListLookupCallback.block_height %u", block_height);
    mndiff_block_hash_destroy(block_hash);
    //NSLog(@"blockHeightListLookupCallback.destroyed");
    return block_height;
}

void addInsightLookup(uint8_t (*block_hash)[32], const void *context) {
    DSMasternodeDiffMessageContext *mndiffContext = (__bridge DSMasternodeDiffMessageContext *)context;
    NSData *data = [NSData dataWithBytes:block_hash length:32];
    UInt256 entryQuorumHash = data.UInt256;
    DSChain *chain = mndiffContext.chain;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    [[DSInsightManager sharedInstance] blockForBlockHash:uint256_reverse(entryQuorumHash)
                                                 onChain:chain
                                              completion:^(DSBlock *_Nullable block, NSError *_Nullable error) {
                                                  if (!error && block) {
                                                      [chain addInsightVerifiedBlock:block forBlockHash:entryQuorumHash];
                                                  }
                                                  dispatch_semaphore_signal(sem);
                                              }];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    mndiff_block_hash_destroy(block_hash);
}

bool shouldProcessQuorumType(uint8_t quorum_type, const void *context) {
    DSMasternodeDiffMessageContext *mndiffContext = (__bridge DSMasternodeDiffMessageContext *)context;
    BOOL should = [mndiffContext.chain shouldProcessQuorumOfType:(DSLLMQType)quorum_type];
    return should;
};

bool validateQuorumCallback(QuorumValidationData *data, const void *context) {
    NSMutableArray<DSBLSKey *> *publicKeyArray = [NSMutableArray array];
    for (NSUInteger i = 0; i < data->count; i++) {
        NSData *pkData = [NSData dataWithBytes:data->items[i] length:48];
        //        NSLog(@"validateQuorumCallback addPublicKey: %@", pkData.hexString);
        [publicKeyArray addObject:[DSBLSKey keyWithPublicKey:pkData.UInt384]];
    }
    UInt256 commitmentHash = [NSData dataWithBytes:data->commitment_hash length:32].UInt256;
    UInt768 allCommitmentAggregatedSignature = [NSData dataWithBytes:data->all_commitment_aggregated_signature length:96].UInt768;
    bool allCommitmentAggregatedSignatureValidated = [DSBLSKey verifySecureAggregated:commitmentHash signature:allCommitmentAggregatedSignature withPublicKeys:publicKeyArray];
    //NSLog(@"validateQuorumCallback verifySecureAggregated = %i, with: commitmentHash: %@, allCommitmentAggregatedSignature: %@, publicKeys: %lu", allCommitmentAggregatedSignatureValidated, uint256_hex(commitmentHash), uint768_hex(allCommitmentAggregatedSignature), [publicKeyArray count]);
    if (!allCommitmentAggregatedSignatureValidated) {
        mndiff_quorum_validation_data_destroy(data);
        return false;
    }
    //The sig must validate against the commitmentHash and all public keys determined by the signers bitvector. This is an aggregated BLS signature verification.
    UInt768 quorumThresholdSignature = [NSData dataWithBytes:data->quorum_threshold_signature length:96].UInt768;
    UInt384 quorumPublicKey = [NSData dataWithBytes:data->quorum_public_key length:48].UInt384;
    bool quorumSignatureValidated = [DSBLSKey verify:commitmentHash signature:quorumThresholdSignature withPublicKey:quorumPublicKey];
    //NSLog(@"validateQuorumCallback verify = %i, with: commitmentHash: %@, quorumThresholdSignature: %@, quorumPublicKey: %@", quorumSignatureValidated, uint256_hex(commitmentHash), uint768_hex(quorumThresholdSignature), uint384_hex(quorumPublicKey));
    mndiff_quorum_validation_data_destroy(data);
    if (!quorumSignatureValidated) {
        DSLog(@"Issue with quorumSignatureValidated");
        return false;
    }
    //    NSLog(@"validateQuorumCallback true");
    return true;
};

+ (MasternodeList *)wrapMasternodeList:(DSMasternodeList *)list {
    if (!list) return NULL;
    NSDictionary<NSNumber *, NSDictionary<NSData *, DSQuorumEntry *> *> *quorums = [list quorums];
    NSDictionary<NSData *, DSSimplifiedMasternodeEntry *> *masternodes = [list simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash];
    uintptr_t quorums_count = quorums.count;
    uintptr_t masternodes_count = masternodes.count;
    MasternodeList *masternode_list = malloc(sizeof(MasternodeList));
    uint8_t *quorums_keys = malloc(quorums_count * sizeof(uint8_t));
    LLMQMap **quorums_values = malloc(quorums_count * sizeof(LLMQMap *));
    int i = 0;
    int j = 0;
    for (NSNumber *type in quorums) {
        NSDictionary<NSData *, DSQuorumEntry *> *quorumsMaps = quorums[type];
        uintptr_t quorum_maps_count = quorumsMaps.count;
        LLMQMap *quorums_map = malloc(sizeof(LLMQMap));
        uint8_t(**quorum_of_type_keys)[32] = malloc(quorum_maps_count * sizeof(UInt256 *));
        QuorumEntry **quorum_of_type_values = malloc(quorum_maps_count * sizeof(QuorumEntry *));
        j = 0;
        for (NSData *hash in quorumsMaps) {
            QuorumEntry *quorum_entry = [DSMasternodeManager wrapQuorumEntry:quorumsMaps[hash]];
            uint8_t(*key)[32] = malloc(sizeof(UInt256));
            key = malloc(sizeof(UInt256));
            memcpy(key, hash.bytes, hash.length);
            quorum_of_type_keys[j] = key;
            quorum_of_type_values[j] = quorum_entry;
            j++;
        }
        quorums_map->count = quorum_maps_count;
        quorums_map->keys = quorum_of_type_keys;
        quorums_map->values = quorum_of_type_values;
        uint8_t quorum_type = (uint8_t)[type unsignedIntegerValue];
        quorums_keys[i] = quorum_type;
        quorums_values[i] = quorums_map;
        i++;
    }
    masternode_list->quorums_keys = quorums_keys;
    masternode_list->quorums_values = quorums_values;
    masternode_list->quorums_count = quorums_count;
    uint8_t(**masternodes_keys)[32] = malloc(masternodes_count * sizeof(UInt256 *));
    MasternodeEntry **masternodes_values = malloc(masternodes_count * sizeof(MasternodeEntry *));
    i = 0;
    for (NSData *hash in masternodes) {
        MasternodeEntry *masternode_entry = [DSMasternodeManager wrapMasternodeEntry:masternodes[hash]];
        uint8_t(*key)[32] = malloc(sizeof(UInt256));
        memcpy(key, hash.bytes, hash.length);
        masternodes_keys[i] = key;
        masternodes_values[i] = masternode_entry;
        i++;
    }
    masternode_list->masternodes_keys = masternodes_keys;
    masternode_list->masternodes_values = masternodes_values;
    masternode_list->masternodes_count = masternodes_count;
    masternode_list->block_hash = malloc(sizeof(UInt256));
    memcpy(masternode_list->block_hash, [list blockHash].u8, sizeof(UInt256));
    masternode_list->known_height = [list height];
    masternode_list->masternode_merkle_root = malloc(sizeof(UInt256));
    memcpy(masternode_list->masternode_merkle_root, [list masternodeMerkleRoot].u8, sizeof(UInt256));
    masternode_list->quorum_merkle_root = malloc(sizeof(UInt256));
    memcpy(masternode_list->quorum_merkle_root, [list quorumMerkleRoot].u8, sizeof(UInt256));
    return masternode_list;
}

+ (void)freeMasternodeList:(MasternodeList *)list {
    if (!list) return;
    free(list->block_hash);
    if (list->masternodes_count > 0) {
        for (int i = 0; i < list->masternodes_count; i++) {
            free(list->masternodes_keys[i]);
            [DSMasternodeManager freeMasternodeEntry:list->masternodes_values[i]];
        }
    }
    if (list->masternodes_keys)
        free(list->masternodes_keys);
    if (list->masternodes_values)
        free(list->masternodes_values);
    if (list->quorums_count > 0) {
        for (int i = 0; i < list->quorums_count; i++) {
            LLMQMap *map = list->quorums_values[i];
            for (int j = 0; j < map->count; j++) {
                free(map->keys[j]);
                [DSMasternodeManager freeQuorumEntry:map->values[j]];
            }
            if (map->keys)
                free(map->keys);
            if (map->values)
                free(map->values);
            free(map);
        }
    }
    if (list->quorums_keys)
        free(list->quorums_keys);
    if (list->quorums_values)
        free(list->quorums_values);
    if (list->masternode_merkle_root)
        free(list->masternode_merkle_root);
    if (list->quorum_merkle_root)
        free(list->quorum_merkle_root);
    free(list);
}

+ (QuorumEntry *)wrapQuorumEntry:(DSQuorumEntry *)entry {
    QuorumEntry *quorum_entry = malloc(sizeof(QuorumEntry));
    quorum_entry->all_commitment_aggregated_signature = malloc(sizeof(UInt768));
    memcpy(quorum_entry->all_commitment_aggregated_signature, [entry allCommitmentAggregatedSignature].u8, sizeof(UInt768));
    quorum_entry->commitment_hash = malloc(sizeof(UInt256));
    memcpy(quorum_entry->commitment_hash, [entry commitmentHash].u8, sizeof(UInt256));
    quorum_entry->length = [entry length];
    quorum_entry->llmq_type = [entry llmqType];
    quorum_entry->quorum_entry_hash = malloc(sizeof(UInt256));
    memcpy(quorum_entry->quorum_entry_hash, [entry quorumEntryHash].u8, sizeof(UInt256));
    quorum_entry->quorum_hash = malloc(sizeof(UInt256));
    memcpy(quorum_entry->quorum_hash, [entry quorumHash].u8, sizeof(UInt256));
    quorum_entry->quorum_public_key = malloc(sizeof(UInt384));
    memcpy(quorum_entry->quorum_public_key, [entry quorumPublicKey].u8, sizeof(UInt384));
    quorum_entry->quorum_threshold_signature = malloc(sizeof(UInt768));
    memcpy(quorum_entry->quorum_threshold_signature, [entry quorumThresholdSignature].u8, sizeof(UInt768));
    quorum_entry->quorum_verification_vector_hash = malloc(sizeof(UInt256));
    memcpy(quorum_entry->quorum_verification_vector_hash, [entry quorumVerificationVectorHash].u8, sizeof(UInt256));
    quorum_entry->saved = [entry saved];
    NSData *signers_bitset = [entry signersBitset];
    NSUInteger signers_bitset_length = signers_bitset.length;
    uint8_t *signers = malloc(signers_bitset_length);
    memcpy(signers, signers_bitset.bytes, signers_bitset_length);
    quorum_entry->signers_bitset = signers;
    quorum_entry->signers_bitset_length = signers_bitset_length;
    quorum_entry->signers_count = [entry signersCount];
    NSData *valid_members_bitset = [entry validMembersBitset];
    NSUInteger valid_members_bitset_length = valid_members_bitset.length;
    uint8_t *valid_members = malloc(valid_members_bitset_length);
    memcpy(valid_members, valid_members_bitset.bytes, valid_members_bitset_length);
    quorum_entry->valid_members_bitset = valid_members;
    quorum_entry->valid_members_bitset_length = valid_members_bitset_length;
    quorum_entry->valid_members_count = [entry validMembersCount];
    quorum_entry->verified = [entry verified];
    quorum_entry->version = [entry version];
    return quorum_entry;
}
+ (void)freeQuorumEntry:(QuorumEntry *)entry {
    free(entry->all_commitment_aggregated_signature);
    if (entry->commitment_hash)
        free(entry->commitment_hash);
    free(entry->quorum_entry_hash);
    free(entry->quorum_hash);
    free(entry->quorum_public_key);
    free(entry->quorum_threshold_signature);
    free(entry->quorum_verification_vector_hash);
    free(entry->signers_bitset);
    free(entry->valid_members_bitset);
    free(entry);
}

+ (MasternodeEntry *)wrapMasternodeEntry:(DSSimplifiedMasternodeEntry *)entry {
    uint32_t known_confirmed_at_height = [entry knownConfirmedAtHeight];
    NSDictionary<DSBlock *, NSData *> *previousOperatorPublicKeys = [entry previousOperatorPublicKeys];
    NSDictionary<DSBlock *, NSData *> *previousSimplifiedMasternodeEntryHashes = [entry previousSimplifiedMasternodeEntryHashes];
    NSDictionary<DSBlock *, NSNumber *> *previousValidity = [entry previousValidity];
    MasternodeEntry *masternode_entry = malloc(sizeof(MasternodeEntry));
    masternode_entry->confirmed_hash = malloc(sizeof(UInt256));
    memcpy(masternode_entry->confirmed_hash, [entry confirmedHash].u8, sizeof(UInt256));
    masternode_entry->confirmed_hash_hashed_with_provider_registration_transaction_hash = malloc(sizeof(UInt256));
    memcpy(masternode_entry->confirmed_hash_hashed_with_provider_registration_transaction_hash, [entry confirmedHashHashedWithProviderRegistrationTransactionHash].u8, sizeof(UInt256));
    masternode_entry->is_valid = [entry isValid];
    masternode_entry->key_id_voting = malloc(sizeof(UInt160));
    memcpy(masternode_entry->key_id_voting, [entry keyIDVoting].u8, sizeof(UInt160));
    masternode_entry->known_confirmed_at_height = known_confirmed_at_height;
    masternode_entry->masternode_entry_hash = malloc(sizeof(UInt256));
    memcpy(masternode_entry->masternode_entry_hash, [entry simplifiedMasternodeEntryHash].u8, sizeof(UInt256));
    masternode_entry->operator_public_key = malloc(sizeof(UInt384));
    memcpy(masternode_entry->operator_public_key, [entry operatorPublicKey].u8, sizeof(UInt384));
    NSUInteger previousOperatorPublicKeysCount = [previousOperatorPublicKeys count];
    OperatorPublicKey **previous_operator_public_keys = malloc(previousOperatorPublicKeysCount * sizeof(OperatorPublicKey));
    int i = 0;
    for (DSBlock *block in previousOperatorPublicKeys) {
        NSData *keyData = previousOperatorPublicKeys[block];
        OperatorPublicKey *operator_public_key = malloc(sizeof(OperatorPublicKey));
        memcpy(operator_public_key->key, keyData.bytes, sizeof(UInt384));
        memcpy(operator_public_key->block_hash, block.blockHash.u8, sizeof(UInt256));
        operator_public_key->block_height = block.height;
        previous_operator_public_keys[i] = operator_public_key;
        i++;
    }
    masternode_entry->previous_operator_public_keys = previous_operator_public_keys;
    masternode_entry->previous_operator_public_keys_count = previousOperatorPublicKeysCount;
    NSUInteger previousSimplifiedMasternodeEntryHashesCount = [previousSimplifiedMasternodeEntryHashes count];
    MasternodeEntryHash **previous_masternode_entry_hashes = malloc(previousSimplifiedMasternodeEntryHashesCount * sizeof(MasternodeEntryHash));
    i = 0;
    BOOL shouldLog = previousSimplifiedMasternodeEntryHashes.count > 1;
    for (DSBlock *block in previousSimplifiedMasternodeEntryHashes) {
        NSData *hash = previousSimplifiedMasternodeEntryHashes[block];
        MasternodeEntryHash *masternode_entry_hash = malloc(sizeof(MasternodeEntryHash));
        memcpy(masternode_entry_hash->hash, hash.bytes, sizeof(UInt256));
        memcpy(masternode_entry_hash->block_hash, block.blockHash.u8, sizeof(UInt256));
        masternode_entry_hash->block_height = block.height;
        previous_masternode_entry_hashes[i] = masternode_entry_hash;
        if (shouldLog) NSLog(@"wrap.previous_masternode_entry_hashes[%d]:%p\n%u:%@", i, masternode_entry_hash, masternode_entry_hash->block_height, hash.hexString);
        i++;
    }
    masternode_entry->previous_masternode_entry_hashes = previous_masternode_entry_hashes;
    masternode_entry->previous_masternode_entry_hashes_count = previousSimplifiedMasternodeEntryHashesCount;
    NSUInteger previousValidityCount = [previousValidity count];
    Validity **previous_validity = malloc(previousValidityCount * sizeof(Validity));
    i = 0;
    for (DSBlock *block in previousValidity) {
        NSNumber *flag = previousValidity[block];
        Validity *validity = malloc(sizeof(Validity));
        memcpy(validity->block_hash, block.blockHash.u8, sizeof(UInt256));
        validity->block_height = block.height;
        validity->is_valid = [flag boolValue];
        previous_validity[i] = validity;
        i++;
    }
    masternode_entry->previous_validity = previous_validity;
    masternode_entry->previous_validity_count = previousValidityCount;
    masternode_entry->provider_registration_transaction_hash = malloc(sizeof(UInt256));
    memcpy(masternode_entry->provider_registration_transaction_hash, [entry providerRegistrationTransactionHash].u8, sizeof(UInt256));
    masternode_entry->ip_address = malloc(sizeof(UInt128));
    memcpy(masternode_entry->ip_address, [entry address].u8, sizeof(UInt128));
    masternode_entry->port = [entry port];
    masternode_entry->update_height = [entry updateHeight];
    return masternode_entry;
}

+ (void)freeMasternodeEntry:(MasternodeEntry *)entry {
    int i = 0;
    uintptr_t previous_operator_public_keys_count = entry->previous_operator_public_keys_count;
    if (previous_operator_public_keys_count > 0) {
        for (i = 0; i < previous_operator_public_keys_count; i++) {
            free(entry->previous_operator_public_keys[i]);
        }
        i = 0;
    }
    if (entry->previous_operator_public_keys)
        free(entry->previous_operator_public_keys);
    uintptr_t previous_masternode_entry_hashes_count = entry->previous_masternode_entry_hashes_count;
    if (previous_masternode_entry_hashes_count > 0) {
        BOOL shouldLog = previous_masternode_entry_hashes_count > 1;
        for (i = 0; i < previous_masternode_entry_hashes_count; i++) {
            if (shouldLog) {
                NSLog(@"free.previous_masternode_entry_hashes[%d]:%p\n%u:%@", i, entry->previous_masternode_entry_hashes[i], entry->previous_masternode_entry_hashes[i]->block_height,
                      [NSData dataWithBytes:entry->previous_masternode_entry_hashes[i]->hash length:32].hexString);
                
            }
            free(entry->previous_masternode_entry_hashes[i]);
        }
        i = 0;
    }
    if (entry->previous_masternode_entry_hashes)
        free(entry->previous_masternode_entry_hashes);
    uintptr_t previous_validity_count = entry->previous_validity_count;
    if (previous_validity_count > 0) {
        for (i = 0; i < previous_validity_count; i++) {
            free(entry->previous_validity[i]);
        }
    }
    if (entry->previous_validity)
        free(entry->previous_validity);
    free(entry->confirmed_hash);
    if (entry->confirmed_hash_hashed_with_provider_registration_transaction_hash)
        free(entry->confirmed_hash_hashed_with_provider_registration_transaction_hash);
    free(entry->operator_public_key);
    free(entry->masternode_entry_hash);
    free(entry->ip_address);
    free(entry->key_id_voting);
    free(entry->provider_registration_transaction_hash);
    free(entry);
}

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

- (instancetype)initWithChain:(DSChain *)chain {
    NSParameterAssert(chain);

    if (!(self = [super init])) return nil;
    _masternodeSavingQueue = dispatch_queue_create([[NSString stringWithFormat:@"org.dashcore.dashsync.masternodesaving.%@", chain.uniqueID] UTF8String], DISPATCH_QUEUE_SERIAL);
    _chain = chain;
    _masternodeListRetrievalQueue = [NSMutableOrderedSet orderedSet];
    _masternodeListsInRetrieval = [NSMutableSet set];
    _masternodeListsByBlockHash = [NSMutableDictionary dictionary];
    _masternodeListsBlockHashStubs = [NSMutableSet set];
    _masternodeListQueriesNeedingQuorumsValidated = [NSMutableSet set];
    _cachedBlockHashHeights = [NSMutableDictionary dictionary];
    _localMasternodesDictionaryByRegistrationTransactionHash = [NSMutableDictionary dictionary];
    _testingMasternodeListRetrieval = NO;
    self.managedObjectContext = chain.chainManagedObjectContext;
    self.lastQueriedBlockHash = UINT256_ZERO;
    self.processingMasternodeListDiffHashes = nil;
    _timedOutAttempt = 0;
    _timeOutObserverTry = 0;
    _masternodeListCurrentlyBeingSavedCount = 0;
    return self;
}

// MARK: - Helpers

- (DSPeerManager *)peerManager {
    return self.chain.chainManager.peerManager;
}

- (NSArray *)recentMasternodeLists {
    return [[self.masternodeListsByBlockHash allValues] sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"height" ascending:YES]]];
}

- (NSUInteger)knownMasternodeListsCount {
    NSMutableSet *masternodeListHashes = [NSMutableSet setWithArray:self.masternodeListsByBlockHash.allKeys];
    [masternodeListHashes addObjectsFromArray:[self.masternodeListsBlockHashStubs allObjects]];
    return [masternodeListHashes count];
}

- (uint32_t)earliestMasternodeListBlockHeight {
    uint32_t earliest = UINT32_MAX;
    for (NSData *blockHash in self.masternodeListsBlockHashStubs) {
        earliest = MIN(earliest, [self heightForBlockHash:blockHash.UInt256]);
    }
    for (NSData *blockHash in self.masternodeListsByBlockHash) {
        earliest = MIN(earliest, [self heightForBlockHash:blockHash.UInt256]);
    }
    return earliest;
}

- (uint32_t)lastMasternodeListBlockHeight {
    uint32_t last = 0;
    for (NSData *blockHash in [self.masternodeListsBlockHashStubs copy]) {
        last = MAX(last, [self heightForBlockHash:blockHash.UInt256]);
    }
    for (NSData *blockHash in [self.masternodeListsByBlockHash copy]) {
        last = MAX(last, [self heightForBlockHash:blockHash.UInt256]);
    }
    return last ? last : UINT32_MAX;
}

- (uint32_t)heightForBlockHash:(UInt256)blockhash {
    if (uint256_is_zero(blockhash)) return 0;
    NSNumber *cachedHeightNumber = [self.cachedBlockHashHeights objectForKey:uint256_data(blockhash)];
    if (cachedHeightNumber) return [cachedHeightNumber intValue];
    uint32_t chainHeight = [self.chain heightForBlockHash:blockhash];
    if (chainHeight != UINT32_MAX) [self.cachedBlockHashHeights setObject:@(chainHeight) forKey:uint256_data(blockhash)];
    return chainHeight;
}

- (UInt256)closestKnownBlockHashForBlockHash:(UInt256)blockHash {
    DSMasternodeList *masternodeList = [self masternodeListBeforeBlockHash:blockHash];
    if (masternodeList)
        return masternodeList.blockHash;
    else
        return self.chain.genesisHash;
}

- (NSUInteger)simplifiedMasternodeEntryCount {
    return [self.currentMasternodeList masternodeCount];
}

- (NSUInteger)activeQuorumsCount {
    return self.currentMasternodeList.quorumsCount;
}

- (DSSimplifiedMasternodeEntry *)simplifiedMasternodeEntryForLocation:(UInt128)IPAddress port:(uint16_t)port {
    for (DSSimplifiedMasternodeEntry *simplifiedMasternodeEntry in [self.currentMasternodeList.simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash allValues]) {
        if (uint128_eq(simplifiedMasternodeEntry.address, IPAddress) && simplifiedMasternodeEntry.port == port) {
            return simplifiedMasternodeEntry;
        }
    }
    return nil;
}

- (DSSimplifiedMasternodeEntry *)masternodeHavingProviderRegistrationTransactionHash:(NSData *)providerRegistrationTransactionHash {
    NSParameterAssert(providerRegistrationTransactionHash);

    return [self.currentMasternodeList.simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash objectForKey:providerRegistrationTransactionHash];
}

- (BOOL)hasMasternodeAtLocation:(UInt128)IPAddress port:(uint32_t)port {
    DSSimplifiedMasternodeEntry *simplifiedMasternodeEntry = [self simplifiedMasternodeEntryForLocation:IPAddress port:port];
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
    double masternodeListsCount = self.masternodeListsByBlockHash.count;
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
    if (!self.currentMasternodeList) return FALSE;
    DSBlock *block = [self.chain blockForBlockHash:self.currentMasternodeList.blockHash];
    if (!block) return FALSE;
    NSTimeInterval currentTimestamp = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval delta = currentTimestamp - block.timestamp;
    return fabs(delta) < DAY_TIME_INTERVAL;
}


// MARK: - Set Up and Tear Down

- (void)setUp {
    [self deleteEmptyMasternodeLists]; //this is just for sanity purposes
    [self loadMasternodeLists];
    [self removeOldSimplifiedMasternodeEntries];
    [self loadLocalMasternodes];
    [self loadFileDistributedMasternodeLists];
}

- (void)loadLocalMasternodes {
    NSFetchRequest *fetchRequest = [[DSLocalMasternodeEntity fetchRequest] copy];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"providerRegistrationTransaction.transactionHash.chain == %@", [self.chain chainEntityInContext:self.managedObjectContext]]];
    NSArray *localMasternodeEntities = [DSLocalMasternodeEntity fetchObjects:fetchRequest inContext:self.managedObjectContext];
    for (DSLocalMasternodeEntity *localMasternodeEntity in localMasternodeEntities) {
        [localMasternodeEntity loadLocalMasternode]; // lazy loaded into the list
    }
}

- (void)reloadMasternodeLists {
    [self reloadMasternodeListsWithBlockHeightLookup:nil];
}

- (void)reloadMasternodeListsWithBlockHeightLookup:(uint32_t (^)(UInt256 blockHash))blockHeightLookup {
    [self.masternodeListsByBlockHash removeAllObjects];
    [self.masternodeListsBlockHashStubs removeAllObjects];
    self.currentMasternodeList = nil;
    [self loadMasternodeListsWithBlockHeightLookup:blockHeightLookup];
}

- (void)deleteEmptyMasternodeLists {
    [self.managedObjectContext performBlockAndWait:^{
        NSFetchRequest *fetchRequest = [[DSMasternodeListEntity fetchRequest] copy];
        [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"block.chain == %@ && masternodes.@count == 0", [self.chain chainEntityInContext:self.managedObjectContext]]];
        NSArray *masternodeListEntities = [DSMasternodeListEntity fetchObjects:fetchRequest inContext:self.managedObjectContext];
        for (DSMasternodeListEntity *entity in [masternodeListEntities copy]) {
            [self.managedObjectContext deleteObject:entity];
        }
        [self.managedObjectContext ds_save];
    }];
}

- (void)loadMasternodeLists {
    [self loadMasternodeListsWithBlockHeightLookup:nil];
}

- (void)loadMasternodeListsWithBlockHeightLookup:(uint32_t (^)(UInt256 blockHash))blockHeightLookup {
    [self.managedObjectContext performBlockAndWait:^{
        NSFetchRequest *fetchRequest = [[DSMasternodeListEntity fetchRequest] copy];
        [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"block.chain == %@", [self.chain chainEntityInContext:self.managedObjectContext]]];
        [fetchRequest setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"block.height" ascending:YES]]];
        NSArray *masternodeListEntities = [DSMasternodeListEntity fetchObjects:fetchRequest inContext:self.managedObjectContext];
        NSMutableDictionary *simplifiedMasternodeEntryPool = [NSMutableDictionary dictionary];
        NSMutableDictionary *quorumEntryPool = [NSMutableDictionary dictionary];
        uint32_t neededMasternodeListHeight = self.chain.lastTerminalBlockHeight - 23; //2*8+7
        for (uint32_t i = (uint32_t)masternodeListEntities.count - 1; i != UINT32_MAX; i--) {
            DSMasternodeListEntity *masternodeListEntity = [masternodeListEntities objectAtIndex:i];
            if ((i == masternodeListEntities.count - 1) || ((self.masternodeListsByBlockHash.count < 3) && (neededMasternodeListHeight >= masternodeListEntity.block.height))) { //either last one or there are less than 3 (we aim for 3)
                //we only need a few in memory as new quorums will mostly be verified against recent masternode lists
                DSMasternodeList *masternodeList = [masternodeListEntity masternodeListWithSimplifiedMasternodeEntryPool:[simplifiedMasternodeEntryPool copy] quorumEntryPool:quorumEntryPool withBlockHeightLookup:blockHeightLookup];
                [self.masternodeListsByBlockHash setObject:masternodeList forKey:uint256_data(masternodeList.blockHash)];
                [self.cachedBlockHashHeights setObject:@(masternodeListEntity.block.height) forKey:uint256_data(masternodeList.blockHash)];
                [simplifiedMasternodeEntryPool addEntriesFromDictionary:masternodeList.simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash];
                [quorumEntryPool addEntriesFromDictionary:masternodeList.quorums];
                DSLog(@"Loading Masternode List at height %u for blockHash %@ with %lu entries", masternodeList.height, uint256_hex(masternodeList.blockHash), (unsigned long)masternodeList.simplifiedMasternodeEntries.count);
                if (i == masternodeListEntities.count - 1) {
                    self.currentMasternodeList = masternodeList;
                }
                neededMasternodeListHeight = masternodeListEntity.block.height - 8;
            } else {
                //just keep a stub around
                [self.cachedBlockHashHeights setObject:@(masternodeListEntity.block.height) forKey:masternodeListEntity.block.blockHash];
                [self.masternodeListsBlockHashStubs addObject:masternodeListEntity.block.blockHash];
            }
        }
    }];
}

- (void)setCurrentMasternodeList:(DSMasternodeList *)currentMasternodeList {
    if (self.chain.isEvolutionEnabled) {
        if (!_currentMasternodeList) {
            for (DSSimplifiedMasternodeEntry *masternodeEntry in currentMasternodeList.simplifiedMasternodeEntries) {
                if (masternodeEntry.isValid) {
                    [self.chain.chainManager.DAPIClient addDAPINodeByAddress:masternodeEntry.ipAddressString];
                }
            }
        } else {
            NSDictionary *updates = [currentMasternodeList listOfChangedNodesComparedTo:_currentMasternodeList];
            NSArray *added = updates[MASTERNODE_LIST_ADDED_NODES];
            NSArray *removed = updates[MASTERNODE_LIST_REMOVED_NODES];
            NSArray *addedValidity = updates[MASTERNODE_LIST_ADDED_VALIDITY];
            NSArray *removedValidity = updates[MASTERNODE_LIST_REMOVED_VALIDITY];
            for (DSSimplifiedMasternodeEntry *masternodeEntry in added) {
                if (masternodeEntry.isValid) {
                    [self.chain.chainManager.DAPIClient addDAPINodeByAddress:masternodeEntry.ipAddressString];
                }
            }
            for (DSSimplifiedMasternodeEntry *masternodeEntry in addedValidity) {
                [self.chain.chainManager.DAPIClient addDAPINodeByAddress:masternodeEntry.ipAddressString];
            }
            for (DSSimplifiedMasternodeEntry *masternodeEntry in removed) {
                [self.chain.chainManager.DAPIClient removeDAPINodeByAddress:masternodeEntry.ipAddressString];
            }
            for (DSSimplifiedMasternodeEntry *masternodeEntry in removedValidity) {
                [self.chain.chainManager.DAPIClient removeDAPINodeByAddress:masternodeEntry.ipAddressString];
            }
        }
    }
    bool changed = _currentMasternodeList != currentMasternodeList;
    _currentMasternodeList = currentMasternodeList;
    if (changed) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSCurrentMasternodeListDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey: self.chain, DSMasternodeManagerNotificationMasternodeListKey: self.currentMasternodeList ? self.currentMasternodeList : [NSNull null]}];
        });
    }
}

- (void)loadFileDistributedMasternodeLists {
    BOOL syncMasternodeLists = ([[DSOptionsManager sharedInstance] syncType] & DSSyncType_MasternodeList);
    BOOL useCheckpointMasternodeLists = [[DSOptionsManager sharedInstance] useCheckpointMasternodeLists];
    if (!syncMasternodeLists || !useCheckpointMasternodeLists) return;
    if (!self.currentMasternodeList) {
        DSCheckpoint *checkpoint = [self.chain lastCheckpointHavingMasternodeList];
        if (checkpoint && self.chain.lastTerminalBlockHeight >= checkpoint.height) {
            if (![self masternodeListForBlockHash:checkpoint.blockHash]) {
                [self processRequestFromFileForBlockHash:checkpoint.blockHash
                                              completion:^(BOOL success, DSMasternodeList *masternodeList) {
                                                  if (success && masternodeList) {
                                                      self.currentMasternodeList = masternodeList;
                                                  }
                                              }];
            }
        }
    }
}

- (DSMasternodeList *)loadMasternodeListAtBlockHash:(NSData *)blockHash withBlockHeightLookup:(uint32_t (^_Nullable)(UInt256 blockHash))blockHeightLookup {
    __block DSMasternodeList *masternodeList = nil;
    [self.managedObjectContext performBlockAndWait:^{
        DSMasternodeListEntity *masternodeListEntity = [DSMasternodeListEntity anyObjectInContext:self.managedObjectContext matching:@"block.chain == %@ && block.blockHash == %@", [self.chain chainEntityInContext:self.managedObjectContext], blockHash];
        NSMutableDictionary *simplifiedMasternodeEntryPool = [NSMutableDictionary dictionary];
        NSMutableDictionary *quorumEntryPool = [NSMutableDictionary dictionary];

        masternodeList = [masternodeListEntity masternodeListWithSimplifiedMasternodeEntryPool:[simplifiedMasternodeEntryPool copy] quorumEntryPool:quorumEntryPool withBlockHeightLookup:blockHeightLookup];
        if (masternodeList) {
            [self.masternodeListsByBlockHash setObject:masternodeList forKey:blockHash];
            [self.masternodeListsBlockHashStubs removeObject:blockHash];
            DSLog(@"Loading Masternode List at height %u for blockHash %@ with %lu entries", masternodeList.height, uint256_hex(masternodeList.blockHash), (unsigned long)masternodeList.simplifiedMasternodeEntries.count);
        }
    }];
    return masternodeList;
}

- (void)wipeMasternodeInfo {
    [self.masternodeListsByBlockHash removeAllObjects];
    [self.masternodeListsBlockHashStubs removeAllObjects];
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

- (DSMasternodeList *)masternodeListForBlockHash:(UInt256)blockHash withBlockHeightLookup:(uint32_t (^_Nullable)(UInt256 blockHash))blockHeightLookup {
    DSMasternodeList *masternodeList = [self.masternodeListsByBlockHash objectForKey:uint256_data(blockHash)];
    if (!masternodeList && [self.masternodeListsBlockHashStubs containsObject:uint256_data(blockHash)]) {
        masternodeList = [self loadMasternodeListAtBlockHash:uint256_data(blockHash) withBlockHeightLookup:blockHeightLookup];
    }
    if (!masternodeList) {
        if (blockHeightLookup) {
            DSLog(@"No masternode list at %@ (%d)", uint256_reverse_hex(blockHash), blockHeightLookup(blockHash));
        } else {
            DSLog(@"No masternode list at %@", uint256_reverse_hex(blockHash));
        }
    }
    return masternodeList;
}

- (DSMasternodeList *)masternodeListBeforeBlockHash:(UInt256)blockHash {
    uint32_t minDistance = UINT32_MAX;
    uint32_t blockHeight = [self heightForBlockHash:blockHash];
    DSMasternodeList *closestMasternodeList = nil;
    for (NSData *blockHashData in self.masternodeListsByBlockHash) {
        uint32_t masternodeListBlockHeight = [self heightForBlockHash:blockHashData.UInt256];
        if (blockHeight <= masternodeListBlockHeight) continue;
        uint32_t distance = blockHeight - masternodeListBlockHeight;
        if (distance < minDistance) {
            minDistance = distance;
            closestMasternodeList = self.masternodeListsByBlockHash[blockHashData];
        }
    }
    if (self.chain.isMainnet && closestMasternodeList.height < 1088640 && blockHeight >= 1088640) return nil; //special mainnet case
    return closestMasternodeList;
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
            [self.managedObjectContext performBlockAndWait:^{
                hasBlock = !![DSMerkleBlockEntity countObjectsInContext:self.managedObjectContext matching:@"blockHash == %@", uint256_data(blockHash)];
            }];
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
                if (!success) {
                    //we need to go get it
                    UInt256 previousMasternodeAlreadyKnownBlockHash = [self closestKnownBlockHashForBlockHash:blockHash];
                    UInt256 previousMasternodeInQueueBlockHash = (pos ? [masternodeListsToRetrieve objectAtIndex:pos - 1].UInt256 : UINT256_ZERO);
                    uint32_t previousMasternodeAlreadyKnownHeight = [self heightForBlockHash:previousMasternodeAlreadyKnownBlockHash];
                    uint32_t previousMasternodeInQueueHeight = (pos ? [self heightForBlockHash:previousMasternodeInQueueBlockHash] : UINT32_MAX);
                    UInt256 previousBlockHash = pos ? (previousMasternodeAlreadyKnownHeight > previousMasternodeInQueueHeight ? previousMasternodeAlreadyKnownBlockHash : previousMasternodeInQueueBlockHash) : previousMasternodeAlreadyKnownBlockHash;

                    DSLog(@"Requesting masternode list and quorums from %u to %u (%@ to %@)", [self heightForBlockHash:previousBlockHash], [self heightForBlockHash:blockHash], uint256_reverse_hex(previousBlockHash), uint256_reverse_hex(blockHash));
                    NSAssert(([self heightForBlockHash:previousBlockHash] != UINT32_MAX) || uint256_is_zero(previousBlockHash), @"This block height should be known");
                    [self.peerManager.downloadPeer sendGetMasternodeListFromPreviousBlockHash:previousBlockHash forBlockHash:blockHash];
                    UInt512 concat = uint512_concat(previousBlockHash, blockHash);
                    [self.masternodeListsInRetrieval addObject:uint512_data(concat)];
                } else {
                    //we already had it
                    [self.masternodeListRetrievalQueue removeObject:uint256_data(blockHash)];
                }
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
        if ([self.masternodeListsByBlockHash.allKeys containsObject:uint256_data(merkleBlock.blockHash)]) {
            DSLog(@"Already have that masternode list %u", merkleBlock.height);
            return;
        }
        if ([self.masternodeListsBlockHashStubs containsObject:uint256_data(merkleBlock.blockHash)]) {
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
                            completion:^(BOOL foundCoinbase, BOOL validCoinbase, BOOL rootMNListValid, BOOL rootQuorumListValid, BOOL validQuorums, DSMasternodeList *masternodeList, NSDictionary *addedMasternodes, NSDictionary *modifiedMasternodes, NSDictionary *addedQuorums, NSOrderedSet *neededMissingMasternodeLists) {
                                if (!foundCoinbase || !rootMNListValid || !rootQuorumListValid || !validQuorums) {
                                    completion(NO, nil);
                                    DSLog(@"Invalid File for block at height %u with merkleRoot %@", block.height, uint256_hex(block.merkleRoot));
                                    return;
                                }

                                //valid Coinbase might be false if no merkle block
                                if (block && !validCoinbase) {
                                    DSLog(@"Invalid Coinbase for block at height %u with merkleRoot %@", block.height, uint256_hex(block.merkleRoot));
                                    completion(NO, nil);
                                    return;
                                }

                                if (!self.masternodeListsByBlockHash[uint256_data(masternodeList.blockHash)] && ![self.masternodeListsBlockHashStubs containsObject:uint256_data(masternodeList.blockHash)]) {
                                    //in rare race conditions this might already exist

                                    NSArray *updatedSimplifiedMasternodeEntries = [addedMasternodes.allValues arrayByAddingObjectsFromArray:modifiedMasternodes.allValues];
                                    [self.chain updateAddressUsageOfSimplifiedMasternodeEntries:updatedSimplifiedMasternodeEntries];

                                    [self saveMasternodeList:masternodeList
                                        havingModifiedMasternodes:modifiedMasternodes
                                                     addedQuorums:addedQuorums
                                                       completion:^(NSError *error) {
                                                           if (!KEEP_OLD_QUORUMS && uint256_eq(self.lastQueriedBlockHash, masternodeList.blockHash)) {
                                                               [self removeOldMasternodeLists];
                                                           }

                                                           if (![self.masternodeListRetrievalQueue count]) {
                                                               [self.chain.chainManager.transactionManager checkInstantSendLocksWaitingForQuorums];
                                                               [self.chain.chainManager.transactionManager checkChainLocksWaitingForQuorums];
                                                           }
                                                           completion(YES, masternodeList);
                                                       }];
                                }
                            }];
}


#define TEST_RANDOM_ERROR_IN_MASTERNODE_DIFF 0

- (void)processMasternodeDiffMessage:(NSData *)message baseMasternodeList:(DSMasternodeList *)baseMasternodeList lastBlock:(DSBlock *)lastBlock useInsightAsBackup:(BOOL)useInsightAsBackup completion:(void (^)(BOOL foundCoinbase, BOOL validCoinbase, BOOL rootMNListValid, BOOL rootQuorumListValid, BOOL validQuorums, DSMasternodeList *masternodeList, NSDictionary *addedMasternodes, NSDictionary *modifiedMasternodes, NSDictionary *addedQuorums, NSOrderedSet *neededMissingMasternodeLists))completion {
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


+ (void)processMasternodeDiffMessage:(NSData *)message withContext:(DSMasternodeDiffMessageContext *)context completion:(void (^)(BOOL foundCoinbase, BOOL validCoinbase, BOOL rootMNListValid, BOOL rootQuorumListValid, BOOL validQuorums, DSMasternodeList *masternodeList, NSDictionary *addedMasternodes, NSDictionary *modifiedMasternodes, NSDictionary *addedQuorums, NSOrderedSet *neededMissingMasternodeLists))completion {
    DSChain *chain = context.chain;
    DSMasternodeList *baseMasternodeList = context.baseMasternodeList;
    UInt256 merkleRoot = context.lastBlock.merkleRoot;
    MasternodeList *base_masternode_list = [DSMasternodeManager wrapMasternodeList:baseMasternodeList];
    ///
    MndiffResult *result = mndiff_process(message.bytes, message.length, base_masternode_list, masternodeListLookupCallback, masternodeListDestroyCallback, uint256_data(merkleRoot).bytes, context.useInsightAsBackup, addInsightLookup, shouldProcessQuorumType, validateQuorumCallback, blockHeightListLookupCallback, (__bridge void *)(context));
    [DSMasternodeManager freeMasternodeList:base_masternode_list];
    ///
    BOOL foundCoinbase = result->found_coinbase;
    BOOL validCoinbase = result->valid_coinbase;
    BOOL rootMNListValid = result->root_mn_list_valid;
    BOOL rootQuorumListValid = result->root_quorum_list_valid;
    BOOL validQuorums = result->valid_quorums;
    MasternodeList *result_masternode_list = result->masternode_list;
    DSMasternodeList *masternodeList = [DSMasternodeList masternodeListWith:result_masternode_list onChain:chain];
    uint8_t(**added_masternodes_keys)[32] = result->added_masternodes_keys;
    MasternodeEntry **added_masternodes_values = result->added_masternodes_values;
    uintptr_t added_masternodes_count = result->added_masternodes_count;
    NSMutableDictionary *addedMasternodes = [[NSMutableDictionary alloc] initWithCapacity:added_masternodes_count];
    for (NSUInteger i = 0; i < added_masternodes_count; i++) {
        NSData *hash = [NSData dataWithBytes:added_masternodes_keys[i] length:32];
        MasternodeEntry *entry = added_masternodes_values[i];
        DSSimplifiedMasternodeEntry *simplifiedMasternodeEntry = [DSSimplifiedMasternodeEntry simplifiedEntryWith:entry onChain:chain];
        [addedMasternodes setObject:simplifiedMasternodeEntry forKey:hash];
    }
    uint8_t(**modified_masternodes_keys)[32] = result->modified_masternodes_keys;
    MasternodeEntry **modified_masternodes_values = result->modified_masternodes_values;
    uintptr_t modified_masternodes_count = result->modified_masternodes_count;
    NSMutableDictionary *modifiedMasternodes = [[NSMutableDictionary alloc] initWithCapacity:modified_masternodes_count];
    for (NSUInteger i = 0; i < modified_masternodes_count; i++) {
        NSData *hash = [NSData dataWithBytes:modified_masternodes_keys[i] length:32];
        MasternodeEntry *entry = modified_masternodes_values[i];
        DSSimplifiedMasternodeEntry *simplifiedMasternodeEntry = [DSSimplifiedMasternodeEntry simplifiedEntryWith:entry onChain:chain];
        [modifiedMasternodes setObject:simplifiedMasternodeEntry forKey:hash];
    }
    uint8_t(*added_quorums_keys) = result->added_quorums_keys;
    LLMQMap **added_quorums_values = result->added_quorums_values;
    uintptr_t added_quorums_count = result->added_quorums_count;
    NSMutableDictionary *addedQuorums = [[NSMutableDictionary alloc] initWithCapacity:added_quorums_count];
    for (NSUInteger i = 0; i < added_quorums_count; i++) {
        uint8_t quorum_type = added_quorums_keys[i];
        LLMQMap *llmq_map = added_quorums_values[i];
        NSMutableDictionary *quorumsOfType = [[NSMutableDictionary alloc] initWithCapacity:llmq_map->count];
        for (NSUInteger j = 0; j < llmq_map->count; j++) {
            uint8_t(*h)[32] = llmq_map->keys[j];
            NSData *hash = [NSData dataWithBytes:h length:32];
            QuorumEntry *quorum_entry = llmq_map->values[j];
            DSQuorumEntry *entry = [[DSQuorumEntry alloc] initWithEntry:quorum_entry onChain:chain];
            [quorumsOfType setObject:entry forKey:hash];
        }
        [addedQuorums setObject:quorumsOfType
                         forKey:@((DSLLMQType)quorum_type)];
    }
    uint8_t(**needed_masternode_lists)[32] = result->needed_masternode_lists;
    uintptr_t needed_masternode_lists_count = result->needed_masternode_lists_count;
    NSMutableOrderedSet *neededMissingMasternodeLists = [NSMutableOrderedSet orderedSetWithCapacity:needed_masternode_lists_count];
    for (NSUInteger i = 0; i < needed_masternode_lists_count; i++) {
        NSData *hash = [NSData dataWithBytes:needed_masternode_lists[i] length:32];
        [neededMissingMasternodeLists addObject:hash];
    }
    mndiff_destroy(result);
    NSLog(@"---- PROCESS_START ----");
    NSLog(@"---- masternodeList ----");
    NSLog(@"%@", masternodeList.description);
    NSLog(@"---- addedMasternodes ---- (%lu)", [addedMasternodes count]);
    //    for (NSData *hash in addedMasternodes) {
    //        DSSimplifiedMasternodeEntry *entry = addedMasternodes[hash];
    //        NSLog(@"%@: %@", hash.hexString, entry.description);
    //    }
    NSLog(@"---- modifiedMasternodes ---- (%lu)", [modifiedMasternodes count]);
    //    for (NSData *hash in modifiedMasternodes) {
    //        DSSimplifiedMasternodeEntry *entry = modifiedMasternodes[hash];
    //        NSLog(@"%@: %@", hash.hexString, entry.description);
    //    }
    NSLog(@"---- addedQuorums ---- (%lu)", [addedQuorums count]);
    //    for (NSNumber *type in addedQuorums) {
    //        NSDictionary<NSData *, DSQuorumEntry *> *quorumMap = addedQuorums[type];
    //        NSLog(@"quorums of type: %@ (%lu)", type, [quorumMap count]);
    //        for (NSData *hash in quorumMap) {
    //            DSQuorumEntry *entry = quorumMap[hash];
    //            NSLog(@"%@: %@", hash.hexString, entry.description);
    //        }
    //    }
    NSLog(@"---- neededMasternodeLists ---- (%lu)", [neededMissingMasternodeLists count]);
    //    for (NSData *hash in neededMissingMasternodeLists) {
    //        NSLog(@"%@", hash.hexString);
    //    }
    NSLog(@"---- PROCESS_COMPLETE ----");

    completion(foundCoinbase, validCoinbase, rootMNListValid, rootQuorumListValid, validQuorums, masternodeList, addedMasternodes, modifiedMasternodes, addedQuorums, neededMissingMasternodeLists);
}

/*
+ (void)processMasternodeDiffMessage:(NSData *)message withContext:(DSMasternodeDiffMessageContext *)context completion:(void (^)(BOOL foundCoinbase, BOOL validCoinbase, BOOL rootMNListValid, BOOL rootQuorumListValid, BOOL validQuorums, DSMasternodeList *masternodeList, NSDictionary *addedMasternodes, NSDictionary *modifiedMasternodes, NSDictionary *addedQuorums, NSOrderedSet *neededMissingMasternodeLists))completion {
    void (^failureBlock)(void) = ^{
        completion(NO, NO, NO, NO, NO, nil, nil, nil, nil, nil);
    };

    NSUInteger length = message.length;
    NSUInteger offset = 0;

    if (length - offset < 32) {
        failureBlock();
        return;
    }
    __unused UInt256 baseBlockHash = [message UInt256AtOffset:offset];
    offset += 32;

    if (length - offset < 32) {
        failureBlock();
        return;
    }
    UInt256 blockHash = [message UInt256AtOffset:offset];
    offset += 32;

    if (length - offset < 4) {
        failureBlock();
        return;
    }
    uint32_t totalTransactions = [message UInt32AtOffset:offset];
    offset += 4;

    if (length - offset < 1) {
        failureBlock();
        return;
    }

    NSNumber *merkleHashCountLength;
    NSUInteger merkleHashCount = (NSUInteger)[message varIntAtOffset:offset length:&merkleHashCountLength] * sizeof(UInt256);
    offset += [merkleHashCountLength unsignedLongValue];


    NSData *merkleHashes = [message subdataWithRange:NSMakeRange(offset, merkleHashCount)];
    offset += merkleHashCount;

    NSNumber *merkleFlagCountLength;
    NSUInteger merkleFlagCount = (NSUInteger)[message varIntAtOffset:offset length:&merkleFlagCountLength];
    offset += [merkleFlagCountLength unsignedLongValue];


    NSData *merkleFlags = [message subdataWithRange:NSMakeRange(offset, merkleFlagCount)];
    offset += merkleFlagCount;

    //    NSLog(@"baseBlockHash: %@, blockHash: %@, totalTransactions: %u, merkleHashCount: %lu, merkleFlagCount: %lu",
    //        uint256_hex(baseBlockHash),
    //        uint256_hex(blockHash),
    //        totalTransactions,
    //        (unsigned long)merkleHashCount,
    //        (unsigned long)merkleFlagCount);

    DSCoinbaseTransaction *coinbaseTransaction = (DSCoinbaseTransaction *)[DSTransactionFactory transactionWithMessage:[message subdataWithRange:NSMakeRange(offset, message.length - offset)] onChain:context.chain];
    if (![coinbaseTransaction isMemberOfClass:[DSCoinbaseTransaction class]]) return;
    offset += coinbaseTransaction.payloadOffset;

    //    NSLog(@"CoinbaseTx: (payloadOffset: %u, coinbaseTransactionVersion: %u, height: %d, version: %d, tx_hash: %@, merkle_root_mn_list: %@, merkle_root_llmq_list: %@)",
    //        coinbaseTransaction.payloadOffset,
    //        coinbaseTransaction.coinbaseTransactionVersion,
    //        coinbaseTransaction.height,
    //        coinbaseTransaction.version,
    //        uint256_hex(coinbaseTransaction.txHash),
    //        uint256_hex(coinbaseTransaction.merkleRootMNList),
    //        uint256_hex(coinbaseTransaction.merkleRootLLMQList));

    if (length - offset < 1) {
        failureBlock();
        return;
    }
    NSNumber *deletedMasternodeCountLength;
    uint64_t deletedMasternodeCount = [message varIntAtOffset:offset length:&deletedMasternodeCountLength];
    offset += [deletedMasternodeCountLength unsignedLongValue];

    NSMutableArray *deletedMasternodeHashes = [NSMutableArray array];

    while (deletedMasternodeCount >= 1) {
        if (length - offset < 32) {
            failureBlock();
            return;
        }
        [deletedMasternodeHashes addObject:[NSData dataWithUInt256:[message UInt256AtOffset:offset]].reverse];
        offset += 32;
        deletedMasternodeCount--;
    }

    if (length - offset < 1) {
        failureBlock();
        return;
    }
    NSNumber *addedMasternodeCountLength;
    uint64_t addedMasternodeCount = [message varIntAtOffset:offset length:&addedMasternodeCountLength];
    offset += [addedMasternodeCountLength unsignedLongValue];

    NSMutableDictionary *addedOrModifiedMasternodes = [NSMutableDictionary dictionary];

    uint32_t blockHeight = context.blockHeightLookup(blockHash);

    while (addedMasternodeCount >= 1) {
        if (length - offset < [DSSimplifiedMasternodeEntry payloadLength]) return;
        NSData *data = [message subdataWithRange:NSMakeRange(offset, [DSSimplifiedMasternodeEntry payloadLength])];
        DSSimplifiedMasternodeEntry *simplifiedMasternodeEntry = [DSSimplifiedMasternodeEntry simplifiedMasternodeEntryWithData:data atBlockHeight:blockHeight onChain:context.chain];
        [addedOrModifiedMasternodes setObject:simplifiedMasternodeEntry forKey:[NSData dataWithUInt256:simplifiedMasternodeEntry.providerRegistrationTransactionHash].reverse];
        offset += [DSSimplifiedMasternodeEntry payloadLength];
        addedMasternodeCount--;
    }

    NSMutableDictionary *addedMasternodes = [addedOrModifiedMasternodes mutableCopy];
    if (context.baseMasternodeList) [addedMasternodes removeObjectsForKeys:context.baseMasternodeList.reversedRegistrationTransactionHashes];
    NSMutableSet *modifiedMasternodeKeys;
    if (context.baseMasternodeList) {
        modifiedMasternodeKeys = [NSMutableSet setWithArray:[addedOrModifiedMasternodes allKeys]];
        [modifiedMasternodeKeys intersectSet:[NSSet setWithArray:context.baseMasternodeList.reversedRegistrationTransactionHashes]];
    } else {
        modifiedMasternodeKeys = [NSMutableSet set];
    }
    NSMutableDictionary *modifiedMasternodes = [NSMutableDictionary dictionary];
    for (NSData *data in modifiedMasternodeKeys) {
//        DSSimplifiedMasternodeEntry *entry = addedOrModifiedMasternodes[data];
        //        NSLog(@"modify mnode %@:%@", data.hexString, uint256_hex(entry.simplifiedMasternodeEntryHash));
        [modifiedMasternodes setObject:addedOrModifiedMasternodes[data] forKey:data];
    }

    NSMutableDictionary *deletedQuorums = [NSMutableDictionary dictionary];
    NSMutableDictionary *addedQuorums = [NSMutableDictionary dictionary];

    BOOL quorumsActive = (coinbaseTransaction.coinbaseTransactionVersion >= 2);

    BOOL validQuorums = TRUE;

    NSMutableOrderedSet *neededMasternodeLists = [NSMutableOrderedSet orderedSet]; //if quorums are not active this stays empty

    if (quorumsActive) {
        if (length - offset < 1) {
            failureBlock();
            return;
        }
        NSNumber *deletedQuorumsCountLength;
        uint64_t deletedQuorumsCount = [message varIntAtOffset:offset length:&deletedQuorumsCountLength];
        offset += [deletedQuorumsCountLength unsignedLongValue];
        //        uint64_t deletedQuorumsCountCopy = deletedQuorumsCount;
        while (deletedQuorumsCount >= 1) {
            if (length - offset < 33) {
                failureBlock();
                return;
            }
            DSLLMQ llmq;
            llmq.type = [message UInt8AtOffset:offset];
            llmq.hash = [message UInt256AtOffset:offset + 1];
            if (![deletedQuorums objectForKey:@(llmq.type)]) {
                [deletedQuorums setObject:[NSMutableArray arrayWithObject:[NSData dataWithUInt256:llmq.hash]] forKey:@(llmq.type)];
            } else {
                NSMutableArray *mutableLLMQArray = [deletedQuorums objectForKey:@(llmq.type)];
                [mutableLLMQArray addObject:[NSData dataWithUInt256:llmq.hash]];
            }
            offset += 33;
            deletedQuorumsCount--;
        }
        //        NSMutableString *deletedQuorumsString = [NSMutableString stringWithString:@"[\n"];
        //        for (NSValue *value in deletedQuorums) {
        //            NSDictionary *dict = deletedQuorums[value];
        //            DSLLMQType llmqType;
        //            [value getValue:&llmqType];
        //            [deletedQuorumsString appendString:[NSString stringWithFormat:@"%@: {", @(llmqType)]];
        //            for (NSData *d in dict) {
        //                [deletedQuorumsString appendString:d.hexString];
        //                [deletedQuorumsString appendString:@",\n"];
        //            }
        //            [deletedQuorumsString appendString:@"\n}\n"];
        //        }
        //        [deletedQuorumsString appendString:@"]"];
        //        NSLog(@"QQ: deleted_quorums: %llu %@", deletedQuorumsCountCopy, deletedQuorumsString);

        if (length - offset < 1) {
            failureBlock();
            return;
        }
        NSNumber *addedQuorumsCountLength;
        uint64_t addedQuorumsCount = [message varIntAtOffset:offset length:&addedQuorumsCountLength];
        offset += [addedQuorumsCountLength unsignedLongValue];
        //        uint64_t addedQuorumsCountCopy = addedQuorumsCount;

        while (addedQuorumsCount >= 1) {
            DSQuorumEntry *potentialQuorumEntry = [DSQuorumEntry potentialQuorumEntryWithData:message dataOffset:(uint32_t)offset onChain:context.chain];
            //            NSLog(@"adding quorum... %llu: %lu", addedQuorumsCount, (unsigned long)offset);

            if ([context.chain shouldProcessQuorumOfType:potentialQuorumEntry.llmqType]) {
                DSMasternodeList *quorumMasternodeList = context.masternodeListLookup(potentialQuorumEntry.quorumHash);

                if (quorumMasternodeList) {
                    validQuorums &= [potentialQuorumEntry validateWithMasternodeList:quorumMasternodeList blockHeightLookup:context.blockHeightLookup];
                    //NSLog(@"process_quorum: %@, sig: {}, payload: {}, valid: %i", potentialQuorumEntry.description, validQuorums);

                    if (!validQuorums) {
                        DSLog(@"Invalid Quorum Found For Quorum at height %d", quorumMasternodeList.height);
                    }
                } else {
                    if (context.useInsightAsBackup) {
                        //We can trust insight if on testnet
                        UInt256 entryQuorumHash = potentialQuorumEntry.quorumEntryHash;
                        dispatch_semaphore_t sem = dispatch_semaphore_create(0);
                        [[DSInsightManager sharedInstance] blockForBlockHash:uint256_reverse(entryQuorumHash)
                                                                     onChain:context.chain
                                                                  completion:^(DSBlock *_Nullable block, NSError *_Nullable error) {
                                                                      if (!error && block) {
                                                                          [context.chain addInsightVerifiedBlock:block forBlockHash:entryQuorumHash];
                                                                      }
                                                                      dispatch_semaphore_signal(sem);
                                                                  }];
                        dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
                    }
                    if (context.blockHeightLookup(potentialQuorumEntry.quorumHash) != UINT32_MAX) {
                        [neededMasternodeLists addObject:uint256_data(potentialQuorumEntry.quorumHash)];
                    }
                }
            }

            NSData *key = [NSData dataWithUInt256:potentialQuorumEntry.quorumHash];
            NSMutableDictionary *dict = [addedQuorums objectForKey:@(potentialQuorumEntry.llmqType)];
            //            NSLog(@"adding quorum... %llu: %hu %@: %lu", addedQuorumsCount, potentialQuorumEntry.llmqType, [key hexString], (unsigned long)(dict ? [dict count] : 0));
            if (dict) {
                [dict setObject:potentialQuorumEntry forKey:key];
            } else {
                [addedQuorums setObject:[NSMutableDictionary dictionaryWithObject:potentialQuorumEntry forKey:key] forKey:@(potentialQuorumEntry.llmqType)];
            }
            offset += potentialQuorumEntry.length;
            addedQuorumsCount--;
        }

        //        NSMutableString *addedQuorumsString = [NSMutableString stringWithString:@"[\n"];
        //        for (NSNumber *value in addedQuorums) {
        //            [addedQuorumsString appendString:[NSString stringWithFormat:@"%@: {", value]];
        //            NSDictionary *dict = addedQuorums[value];
        //            for (NSData *d in dict) {
        //                DSQuorumEntry *entry = dict[d];
        //                [addedQuorumsString appendString:d.hexString];
        //                [addedQuorumsString appendString:[NSString stringWithFormat:@": MasternodeList { quorum_entry_hash: %@ }", uint256_hex([entry quorumEntryHash])]];
        //                [addedQuorumsString appendString:@",\n"];
        //            }
        //            [addedQuorumsString appendString:@"\n}\n"];
        //        }
        //        [addedQuorumsString appendString:@"]"];
        //        NSLog(@"QQ: added_quorums: %llu %@", addedQuorumsCountCopy, addedQuorumsString);
    }

    uint32_t b_h = context.blockHeightLookup(blockHash);
    //    NSLog(@"DSMasternodeList::new: (block_hash: %@, block_height: %u, mn+: %lu, mn-: %lu, mn~: %lu, q+: %lu q-: %lu)",
    //        uint256_hex(blockHash),
    //        b_h,
    //        (unsigned long)[addedMasternodes count],
    //        (unsigned long)[deletedMasternodeHashes count],
    //        (unsigned long)[modifiedMasternodes count],
    //        (unsigned long)[addedQuorums count],
    //        (unsigned long)[deletedQuorums count]);
    DSMasternodeList *masternodeList = [DSMasternodeList masternodeListAtBlockHash:blockHash atBlockHeight:b_h fromBaseMasternodeList:context.baseMasternodeList addedMasternodes:addedMasternodes removedMasternodeHashes:deletedMasternodeHashes modifiedMasternodes:modifiedMasternodes addedQuorums:addedQuorums removedQuorumHashesByType:deletedQuorums onChain:context.chain];

    //    NSLog(@"new MasternodeList {\nblock_hash: %@,\nknown_height: %u,\nmasternode_merkle_root: %@,\nquorum_merkle_root: %@}",
    //        uint256_hex([masternodeList blockHash]),
    //        [masternodeList height],
    //        uint256_hex([masternodeList masternodeMerkleRoot]),
    //        uint256_hex([masternodeList quorumMerkleRoot])
    //        //[masternodeList simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash]
    //        //[masternodeList quorums]
    //    );

    UInt256 mn_merkle_root = [masternodeList masternodeMerkleRootWithBlockHeightLookup:context.blockHeightLookup];
    BOOL rootMNListValid = uint256_eq(coinbaseTransaction.merkleRootMNList, mn_merkle_root);
    NSLog(@"rootMNListValid: %@ (%@ == %@)", rootMNListValid ? @"YES" : @"NO", uint256_hex(coinbaseTransaction.merkleRootMNList), uint256_hex(mn_merkle_root));

    if (!rootMNListValid) {
        DSLog(@"Masternode Merkle root not valid for DML on block %d version %d (%@ wanted - %@ calculated)", coinbaseTransaction.height, coinbaseTransaction.version, uint256_hex(coinbaseTransaction.merkleRootMNList), uint256_hex(masternodeList.masternodeMerkleRoot));
        int i = 0;
        for (NSString *string in [[masternodeList hashesForMerkleRootWithBlockHeightLookup:context.blockHeightLookup] transformToArrayOfHexStrings]) {
            DSLog(@"Hash %i is %@", i++, string);
        }
#if SAVE_MASTERNODE_ERROR_TO_FILE
        NSMutableData *message = [NSMutableData data];
        NSDictionary<NSData *, NSData *> *hashDictionary = [masternodeList hashDictionaryForMerkleRootWithBlockHeightLookup:blockHeightLookup];
        for (NSData *proTxHashData in [masternodeList providerTxOrderedHashes]) {
            NSString *line = [NSString stringWithFormat:@"%@ -> %@\n", [proTxHashData hexString], [hashDictionary[proTxHashData] hexString]];
            [message appendData:[line dataUsingEncoding:NSUTF8StringEncoding]];
        }
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        NSString *dataPath = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"MNL_SME_ERROR_%d.txt", masternodeList.height]];

        // Save it into file system
        [message writeToFile:dataPath atomically:YES];
#endif
#if SAVE_MASTERNODE_NO_ERROR_TO_FILE
    } else {
        NSMutableData *message = [NSMutableData data];
        NSDictionary<NSData *, NSData *> *hashDictionary = [masternodeList hashDictionaryForMerkleRootWithBlockHeightLookup:blockHeightLookup];
        for (NSData *proTxHashData in [masternodeList providerTxOrderedHashes]) {
            NSString *line = [NSString stringWithFormat:@"%@ -> %@\n", [proTxHashData hexString], [hashDictionary[proTxHashData] hexString]];
            [message appendData:[line dataUsingEncoding:NSUTF8StringEncoding]];
        }
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        NSString *dataPath = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"MNL_SME_NO_ERROR_%d.txt", masternodeList.height]];

        // Save it into file system
        [message writeToFile:dataPath atomically:YES];
#endif
    }

    BOOL rootQuorumListValid = TRUE;

    if (quorumsActive) {
        rootQuorumListValid = uint256_eq(coinbaseTransaction.merkleRootLLMQList, masternodeList.quorumMerkleRoot);
        NSLog(@"rootQuorumListValid: %@ (%@ == %@)", rootQuorumListValid ? @"YES" : @"NO", uint256_hex(coinbaseTransaction.merkleRootLLMQList), uint256_hex(masternodeList.quorumMerkleRoot));

        if (!rootQuorumListValid) {
            DSLog(@"Quorum Merkle root not valid for DML on block %d version %d (%@ wanted - %@ calculated)", coinbaseTransaction.height, coinbaseTransaction.version, uint256_hex(coinbaseTransaction.merkleRootLLMQList), uint256_hex(masternodeList.quorumMerkleRoot));
        }
    }

    //we need to check that the coinbase is in the transaction hashes we got back
    UInt256 coinbaseHash = coinbaseTransaction.txHash;
    BOOL foundCoinbase = FALSE;
    for (int i = 0; i < merkleHashes.length; i += 32) {
        UInt256 randomTransactionHash = [merkleHashes UInt256AtOffset:i];
        NSLog(@"finding coinbase: %@ == %@", uint256_hex(coinbaseHash), uint256_hex(randomTransactionHash));
        if (uint256_eq(coinbaseHash, randomTransactionHash)) {
            foundCoinbase = TRUE;
            break;
        }
    }

    //we also need to check that the coinbase is in the merkle block
    DSMerkleBlock *coinbaseVerificationMerkleBlock = [[DSMerkleBlock alloc] initWithBlockHash:blockHash merkleRoot:context.lastBlock.merkleRoot totalTransactions:totalTransactions hashes:merkleHashes flags:merkleFlags];

    BOOL validCoinbase = [coinbaseVerificationMerkleBlock isMerkleTreeValid];

#if TEST_RANDOM_ERROR_IN_MASTERNODE_DIFF
    //test random errors
    uint32_t chance = 20; //chance is 1/10

    completion((arc4random_uniform(chance) != 0) && foundCoinbase, (arc4random_uniform(chance) != 0) && validCoinbase, (arc4random_uniform(chance) != 0) && rootMNListValid, (arc4random_uniform(chance) != 0) && rootQuorumListValid, (arc4random_uniform(chance) != 0) && validQuorums, masternodeList, addedMasternodes, modifiedMasternodes, addedQuorums, neededMasternodeLists);
#else
    NSLog(@"---- PROCESS_START ----");
    NSLog(@"---- masternodeList ----");
    NSLog(@"%@", masternodeList.description);
    NSLog(@"---- addedMasternodes ---- (%lu)", [addedMasternodes count]);
    //    for (NSData *hash in addedMasternodes) {
    //        DSSimplifiedMasternodeEntry *entry = addedMasternodes[hash];
    //        NSLog(@"%@: %@", hash.hexString, entry.description);
    //    }
    NSLog(@"---- modifiedMasternodes ---- (%lu)", [modifiedMasternodes count]);
    //    for (NSData *hash in modifiedMasternodes) {
    //        DSSimplifiedMasternodeEntry *entry = modifiedMasternodes[hash];
    //        NSLog(@"%@: %@", hash.hexString, entry.description);
    //    }
    NSLog(@"---- addedQuorums ---- (%lu)", [addedQuorums count]);
    //    for (NSNumber *type in addedQuorums) {
    //        NSDictionary<NSData *, DSQuorumEntry *> *quorumMap = addedQuorums[type];
    //        NSLog(@"quorums of type: %@ (%lu)", type, (unsigned long)[quorumMap count]);
    //        for (NSData *hash in quorumMap) {
    //            DSQuorumEntry *entry = quorumMap[hash];
    //            NSLog(@"%@: %@", hash.hexString, entry.description);
    //        }
    //    }
    NSLog(@"---- neededMasternodeLists ---- (%lu)", [neededMasternodeLists count]);
    //    for (NSData *hash in neededMasternodeLists) {
    //        NSLog(@"%@", hash.hexString);
    //    }
    NSLog(@"---- PROCESS_COMPLETE ----");
    //normal completion
    completion(foundCoinbase, validCoinbase, rootMNListValid, rootQuorumListValid, validQuorums, masternodeList, addedMasternodes, modifiedMasternodes, addedQuorums, neededMasternodeLists);

#endif
}*/


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
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *dataPath = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"MNL_%@_%@.dat", @([self heightForBlockHash:baseBlockHash]), @([self heightForBlockHash:blockHash])]];

    // Save it into file system
    [message writeToFile:dataPath atomically:YES];
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

    if ([self.masternodeListsByBlockHash objectForKey:blockHashData]) {
        //we already have this
        DSLog(@"We already have this masternodeList %@ (%u)", blockHashData.reverse.hexString, [self heightForBlockHash:blockHash]);
        return; //no need to do anything more
    }

    if ([self.masternodeListsBlockHashStubs containsObject:blockHashData]) {
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
                            completion:^(BOOL foundCoinbase, BOOL validCoinbase, BOOL rootMNListValid, BOOL rootQuorumListValid, BOOL validQuorums, DSMasternodeList *masternodeList, NSDictionary *addedMasternodes, NSDictionary *modifiedMasternodes, NSDictionary *addedQuorums, NSOrderedSet *neededMissingMasternodeLists) {
                                if (![self.masternodeListRetrievalQueue containsObject:uint256_data(masternodeList.blockHash)]) {
                                    //We most likely wiped data in the meantime
                                    [self.masternodeListsInRetrieval removeAllObjects];
                                    [self dequeueMasternodeListRequest];
                                    return;
                                }

                                if (foundCoinbase && validCoinbase && rootMNListValid && rootQuorumListValid && validQuorums) {
                                    DSLog(@"Valid masternode list found at height %u", [self heightForBlockHash:blockHash]);
                                    //yay this is the correct masternode list verified deterministically for the given block

                                    if ([neededMissingMasternodeLists count] && [self.masternodeListQueriesNeedingQuorumsValidated containsObject:uint256_data(blockHash)]) {
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
                                        [self processValidMasternodeList:masternodeList havingAddedMasternodes:addedMasternodes modifiedMasternodes:modifiedMasternodes addedQuorums:addedQuorums];


                                        NSAssert([self.masternodeListRetrievalQueue containsObject:uint256_data(masternodeList.blockHash)], @"This should still be here");

                                        self.processingMasternodeListDiffHashes = nil;

                                        [self.masternodeListRetrievalQueue removeObject:uint256_data(masternodeList.blockHash)];
                                        [self dequeueMasternodeListRequest];

                                        //check for instant send locks that were awaiting a quorum

                                        if (![self.masternodeListRetrievalQueue count]) {
                                            [self.chain.chainManager.transactionManager checkInstantSendLocksWaitingForQuorums];
                                            [self.chain.chainManager.transactionManager checkChainLocksWaitingForQuorums];
                                        }

                                        [[NSUserDefaults standardUserDefaults] removeObjectForKey:CHAIN_FAULTY_DML_MASTERNODE_PEERS];
                                    }
                                } else {
                                    if (!foundCoinbase) DSLog(@"Did not find coinbase at height %u", [self heightForBlockHash:blockHash]);
                                    if (!validCoinbase) DSLog(@"Coinbase not valid at height %u", [self heightForBlockHash:blockHash]);
                                    if (!rootMNListValid) DSLog(@"rootMNListValid not valid at height %u", [self heightForBlockHash:blockHash]);
                                    if (!rootQuorumListValid) DSLog(@"rootQuorumListValid not valid at height %u", [self heightForBlockHash:blockHash]);
                                    if (!validQuorums) DSLog(@"validQuorums not valid at height %u", [self heightForBlockHash:blockHash]);

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
    if (!self.masternodeListsByBlockHash[uint256_data(masternodeList.blockHash)] && ![self.masternodeListsBlockHashStubs containsObject:uint256_data(masternodeList.blockHash)]) {
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
    return !!self.masternodeListCurrentlyBeingSavedCount;
}

- (void)saveMasternodeList:(DSMasternodeList *)masternodeList havingModifiedMasternodes:(NSDictionary *)modifiedMasternodes addedQuorums:(NSDictionary *)addedQuorums {
    [self saveMasternodeList:masternodeList
        havingModifiedMasternodes:modifiedMasternodes
                     addedQuorums:addedQuorums
                       completion:^(NSError *error) {
                           self.masternodeListCurrentlyBeingSavedCount--;
                           if (error) {
                               if ([self.masternodeListRetrievalQueue count]) { //if it is 0 then we most likely have wiped chain info
                                   [self wipeMasternodeInfo];
                                   dispatch_async(self.chain.networkingQueue, ^{
                                       [self getCurrentMasternodeListWithSafetyDelay:0];
                                   });
                               }
                           }
                       }];
}

- (void)saveMasternodeList:(DSMasternodeList *)masternodeList havingModifiedMasternodes:(NSDictionary *)modifiedMasternodes addedQuorums:(NSDictionary *)addedQuorums completion:(void (^)(NSError *error))completion {
    [self.masternodeListsByBlockHash setObject:masternodeList forKey:uint256_data(masternodeList.blockHash)];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DSMasternodeListDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey: self.chain}];

        [[NSNotificationCenter defaultCenter] postNotificationName:DSQuorumListDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey: self.chain}];
    });
    //We will want to create unknown blocks if they came from insight
    BOOL createUnknownBlocks = masternodeList.chain.allowInsightBlocksForVerification;
    self.masternodeListCurrentlyBeingSavedCount++;
    //This will create a queue for masternodes to be saved without blocking the networking queue
    dispatch_async(self.masternodeSavingQueue, ^{
        [DSMasternodeManager saveMasternodeList:masternodeList
                                        toChain:self.chain
                      havingModifiedMasternodes:modifiedMasternodes
                                   addedQuorums:addedQuorums
                            createUnknownBlocks:createUnknownBlocks
                                      inContext:self.managedObjectContext
                                     completion:completion];
    });
}

+ (void)saveMasternodeList:(DSMasternodeList *)masternodeList toChain:(DSChain *)chain havingModifiedMasternodes:(NSDictionary *)modifiedMasternodes addedQuorums:(NSDictionary *)addedQuorums createUnknownBlocks:(BOOL)createUnknownBlocks inContext:(NSManagedObjectContext *)context completion:(void (^)(NSError *error))completion {
    DSLog(@"Queued saving MNL at height %u", masternodeList.height);
    [context performBlockAndWait:^{
        //masternodes
        DSChainEntity *chainEntity = [chain chainEntityInContext:context];
        DSMerkleBlockEntity *merkleBlockEntity = [DSMerkleBlockEntity anyObjectInContext:context matching:@"blockHash == %@", uint256_data(masternodeList.blockHash)];
        if (!merkleBlockEntity && ([chain checkpointForBlockHash:masternodeList.blockHash])) {
            DSCheckpoint *checkpoint = [chain checkpointForBlockHash:masternodeList.blockHash];
            merkleBlockEntity = [[DSMerkleBlockEntity managedObjectInBlockedContext:context] setAttributesFromBlock:[checkpoint blockForChain:chain] forChainEntity:chainEntity];
        }
        NSAssert(!merkleBlockEntity || !merkleBlockEntity.masternodeList, @"Merkle block should not have a masternode list already");
        NSError *error = nil;
        if (!merkleBlockEntity) {
            if (createUnknownBlocks) {
                merkleBlockEntity = [DSMerkleBlockEntity managedObjectInBlockedContext:context];
                merkleBlockEntity.blockHash = uint256_data(masternodeList.blockHash);
                merkleBlockEntity.height = masternodeList.height;
                merkleBlockEntity.chain = chainEntity;
            } else {
                DSLog(@"Merkle block should exist for block hash %@", uint256_data(masternodeList.blockHash));
                error = [NSError errorWithDomain:@"DashSync" code:600 userInfo:@{NSLocalizedDescriptionKey: @"Merkle block should exist"}];
            }
        } else if (merkleBlockEntity.masternodeList) {
            error = [NSError errorWithDomain:@"DashSync" code:600 userInfo:@{NSLocalizedDescriptionKey: @"Merkle block should not have a masternode list already"}];
        }
        if (!error) {
            DSMasternodeListEntity *masternodeListEntity = [DSMasternodeListEntity managedObjectInBlockedContext:context];
            masternodeListEntity.block = merkleBlockEntity;
            masternodeListEntity.masternodeListMerkleRoot = uint256_data(masternodeList.masternodeMerkleRoot);
            masternodeListEntity.quorumListMerkleRoot = uint256_data(masternodeList.quorumMerkleRoot);
            uint32_t i = 0;

            NSArray<DSSimplifiedMasternodeEntryEntity *> *knownSimplifiedMasternodeEntryEntities = [DSSimplifiedMasternodeEntryEntity objectsInContext:context matching:@"chain == %@", chainEntity];
            NSMutableDictionary *indexedKnownSimplifiedMasternodeEntryEntities = [NSMutableDictionary dictionary];
            for (DSSimplifiedMasternodeEntryEntity *simplifiedMasternodeEntryEntity in knownSimplifiedMasternodeEntryEntities) {
                [indexedKnownSimplifiedMasternodeEntryEntities setObject:simplifiedMasternodeEntryEntity forKey:simplifiedMasternodeEntryEntity.providerRegistrationTransactionHash];
            }

            NSMutableSet<NSString *> *votingAddressStrings = [NSMutableSet set];
            NSMutableSet<NSString *> *operatorAddressStrings = [NSMutableSet set];
            NSMutableSet<NSData *> *providerRegistrationTransactionHashes = [NSMutableSet set];
            for (DSSimplifiedMasternodeEntry *simplifiedMasternodeEntry in masternodeList.simplifiedMasternodeEntries) {
                [votingAddressStrings addObject:simplifiedMasternodeEntry.votingAddress];
                [operatorAddressStrings addObject:simplifiedMasternodeEntry.operatorAddress];
                [providerRegistrationTransactionHashes addObject:uint256_data(simplifiedMasternodeEntry.providerRegistrationTransactionHash)];
            }

            //this is the initial list sync so lets speed things up a little bit with some optimizations
            NSDictionary<NSString *, DSAddressEntity *> *votingAddresses = [DSAddressEntity findAddressesAndIndexIn:votingAddressStrings onChain:(DSChain *)chain inContext:context];
            NSDictionary<NSString *, DSAddressEntity *> *operatorAddresses = [DSAddressEntity findAddressesAndIndexIn:votingAddressStrings onChain:(DSChain *)chain inContext:context];
            NSDictionary<NSData *, DSLocalMasternodeEntity *> *localMasternodes = [DSLocalMasternodeEntity findLocalMasternodesAndIndexForProviderRegistrationHashes:providerRegistrationTransactionHashes inContext:context];

            NSAssert(masternodeList.simplifiedMasternodeEntries, @"A masternode must have entries to be saved");

            for (DSSimplifiedMasternodeEntry *simplifiedMasternodeEntry in masternodeList.simplifiedMasternodeEntries) {
                DSSimplifiedMasternodeEntryEntity *simplifiedMasternodeEntryEntity = [indexedKnownSimplifiedMasternodeEntryEntities objectForKey:uint256_data(simplifiedMasternodeEntry.providerRegistrationTransactionHash)];
                if (!simplifiedMasternodeEntryEntity) {
                    simplifiedMasternodeEntryEntity = [DSSimplifiedMasternodeEntryEntity managedObjectInBlockedContext:context];
                    [simplifiedMasternodeEntryEntity setAttributesFromSimplifiedMasternodeEntry:simplifiedMasternodeEntry atBlockHeight:masternodeList.height knownOperatorAddresses:operatorAddresses knownVotingAddresses:votingAddresses localMasternodes:localMasternodes onChainEntity:chainEntity];
                } else if (simplifiedMasternodeEntry.updateHeight >= masternodeList.height) {
                    //it was updated in this masternode list
                    [simplifiedMasternodeEntryEntity updateAttributesFromSimplifiedMasternodeEntry:simplifiedMasternodeEntry atBlockHeight:masternodeList.height knownOperatorAddresses:operatorAddresses knownVotingAddresses:votingAddresses localMasternodes:localMasternodes];
                }
                [masternodeListEntity addMasternodesObject:simplifiedMasternodeEntryEntity];
                i++;
            }

            for (NSData *simplifiedMasternodeEntryHash in modifiedMasternodes) {
                DSSimplifiedMasternodeEntry *simplifiedMasternodeEntry = modifiedMasternodes[simplifiedMasternodeEntryHash];
                DSSimplifiedMasternodeEntryEntity *simplifiedMasternodeEntryEntity = [indexedKnownSimplifiedMasternodeEntryEntities objectForKey:uint256_data(simplifiedMasternodeEntry.providerRegistrationTransactionHash)];
                NSAssert(simplifiedMasternodeEntryEntity, @"this must be present");
                [simplifiedMasternodeEntryEntity updateAttributesFromSimplifiedMasternodeEntry:simplifiedMasternodeEntry atBlockHeight:masternodeList.height knownOperatorAddresses:operatorAddresses knownVotingAddresses:votingAddresses localMasternodes:localMasternodes];
            }
            for (NSNumber *llmqType in masternodeList.quorums) {
                NSDictionary *quorumsForMasternodeType = masternodeList.quorums[llmqType];
                for (NSData *quorumHash in quorumsForMasternodeType) {
                    DSQuorumEntry *potentialQuorumEntry = quorumsForMasternodeType[quorumHash];
                    DSQuorumEntryEntity *quorumEntry = [DSQuorumEntryEntity quorumEntryEntityFromPotentialQuorumEntry:potentialQuorumEntry inContext:context];
                    if (quorumEntry) {
                        [masternodeListEntity addQuorumsObject:quorumEntry];
                    }
                }
            }
            chainEntity.baseBlockHash = [NSData dataWithUInt256:masternodeList.blockHash];

            error = [context ds_save];

            DSLog(@"Finished saving MNL at height %u", masternodeList.height);
        }
        if (error) {
            chainEntity.baseBlockHash = uint256_data(chain.genesisHash);
            [DSLocalMasternodeEntity deleteAllOnChainEntity:chainEntity];
            [DSSimplifiedMasternodeEntryEntity deleteAllOnChainEntity:chainEntity];
            [DSQuorumEntryEntity deleteAllOnChainEntity:chainEntity];
            [context ds_save];
        }
        if (completion) {
            completion(error);
        }
    }];
}

- (void)removeOldMasternodeLists {
    if (!self.currentMasternodeList) return;
    [self.managedObjectContext performBlock:^{
        uint32_t lastBlockHeight = self.currentMasternodeList.height;
        NSMutableArray *masternodeListBlockHashes = [[self.masternodeListsByBlockHash allKeys] mutableCopy];
        [masternodeListBlockHashes addObjectsFromArray:[self.masternodeListsBlockHashStubs allObjects]];
        NSArray<DSMasternodeListEntity *> *masternodeListEntities = [DSMasternodeListEntity objectsInContext:self.managedObjectContext matching:@"block.height < %@ && block.blockHash IN %@ && (block.usedByQuorums.@count == 0)", @(lastBlockHeight - 50), masternodeListBlockHashes];
        BOOL removedItems = !!masternodeListEntities.count;
        for (DSMasternodeListEntity *masternodeListEntity in [masternodeListEntities copy]) {
            DSLog(@"Removing masternodeList at height %u", masternodeListEntity.block.height);
            DSLog(@"quorums are %@", masternodeListEntity.block.usedByQuorums);
            //A quorum is on a block that can only have one masternode list.
            //A block can have one quorum of each type.
            //A quorum references the masternode list by it's block
            //we need to check if this masternode list is being referenced by a quorum using the inverse of quorum.block.masternodeList

            [self.managedObjectContext deleteObject:masternodeListEntity];
            [self.masternodeListsByBlockHash removeObjectForKey:masternodeListEntity.block.blockHash];
        }
        if (removedItems) {
            //Now we should delete old quorums
            //To do this, first get the last 24 active masternode lists
            //Then check for quorums not referenced by them, and delete those

            NSArray<DSMasternodeListEntity *> *recentMasternodeLists = [DSMasternodeListEntity objectsSortedBy:@"block.height" ascending:NO offset:0 limit:10 inContext:self.managedObjectContext];


            uint32_t oldTime = lastBlockHeight - 24;

            uint32_t oldestBlockHeight = recentMasternodeLists.count ? MIN([recentMasternodeLists lastObject].block.height, oldTime) : oldTime;
            NSArray *oldQuorums = [DSQuorumEntryEntity objectsInContext:self.managedObjectContext matching:@"chain == %@ && SUBQUERY(referencedByMasternodeLists, $masternodeList, $masternodeList.block.height > %@).@count == 0", [self.chain chainEntityInContext:self.managedObjectContext], @(oldestBlockHeight)];

            for (DSQuorumEntryEntity *unusedQuorumEntryEntity in [oldQuorums copy]) {
                [self.managedObjectContext deleteObject:unusedQuorumEntryEntity];
            }

            [self.managedObjectContext ds_save];
        }
    }];
}

- (void)removeOldSimplifiedMasternodeEntries {
    //this serves both for cleanup, but also for initial migration

    [self.managedObjectContext performBlockAndWait:^{
        NSArray<DSSimplifiedMasternodeEntryEntity *> *simplifiedMasternodeEntryEntities = [DSSimplifiedMasternodeEntryEntity objectsInContext:self.managedObjectContext matching:@"masternodeLists.@count == 0"];
        BOOL deletedSomething = FALSE;
        NSUInteger deletionCount = 0;
        for (DSSimplifiedMasternodeEntryEntity *simplifiedMasternodeEntryEntity in [simplifiedMasternodeEntryEntities copy]) {
            [self.managedObjectContext deleteObject:simplifiedMasternodeEntryEntity];
            deletedSomething = TRUE;
            deletionCount++;
            if ((deletionCount % 3000) == 0) {
                [self.managedObjectContext ds_save];
            }
        }
        if (deletedSomething) {
            [self.managedObjectContext ds_save];
        }
    }];
}

- (void)issueWithMasternodeListFromPeer:(DSPeer *)peer {
    [self.peerManager peerMisbehaving:peer errorMessage:@"Issue with Deterministic Masternode list"];

    NSArray *faultyPeers = [[NSUserDefaults standardUserDefaults] arrayForKey:CHAIN_FAULTY_DML_MASTERNODE_PEERS];

    if (faultyPeers.count >= MAX_FAULTY_DML_PEERS) {
        DSLog(@"Exceeded max failures for masternode list, starting from scratch");
        //no need to remove local masternodes
        [self.masternodeListRetrievalQueue removeAllObjects];

        [self.managedObjectContext performBlockAndWait:^{
            DSChainEntity *chainEntity = [self.chain chainEntityInContext:self.managedObjectContext];
            [DSSimplifiedMasternodeEntryEntity deleteAllOnChainEntity:chainEntity];
            [DSQuorumEntryEntity deleteAllOnChainEntity:chainEntity];
            [DSMasternodeListEntity deleteAllOnChainEntity:chainEntity];
            [self.managedObjectContext ds_save];
        }];

        [self.masternodeListsByBlockHash removeAllObjects];
        [self.masternodeListsBlockHashStubs removeAllObjects];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:CHAIN_FAULTY_DML_MASTERNODE_PEERS];

        [self getCurrentMasternodeListWithSafetyDelay:0];
    } else {
        if (!faultyPeers) {
            faultyPeers = @[peer.location];
        } else {
            if (![faultyPeers containsObject:peer.location]) {
                faultyPeers = [faultyPeers arrayByAddingObject:peer.location];
            }
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
