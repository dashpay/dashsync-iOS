//  
//  Created by Vladimir Pirogov
//  Copyright © 2021 Dash Core Group. All rights reserved.
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

#import "DSBlock.h"
#import "DSBLSKey.h"
#import "DSChain+Protected.h"
#import "DSInsightManager.h"
#import "DSMasternodeDiffMessageContext.h"
#import "DSMasternodeManager+Mndiff.h"
#import "NSData+Dash.h"

@implementation DSMasternodeManager (Mndiff)

const MasternodeList *masternodeListLookupCallback(uint8_t (*block_hash)[32], const void *context) {
    DSMasternodeDiffMessageContext *mndiffContext = (__bridge DSMasternodeDiffMessageContext *)context;
    NSData *data = [NSData dataWithBytes:block_hash length:32];
    DSMasternodeList *list = mndiffContext.masternodeListLookup(data.UInt256);
    MasternodeList *c_list = [DSMasternodeManager wrapMasternodeList:list];
    mndiff_block_hash_destroy(block_hash);
    return c_list;
}

void masternodeListDestroyCallback(const MasternodeList *masternode_list) {
    [DSMasternodeManager freeMasternodeList:(MasternodeList *)masternode_list];
}

uint32_t blockHeightListLookupCallback(uint8_t (*block_hash)[32], const void *context) {
    DSMasternodeDiffMessageContext *mndiffContext = (__bridge DSMasternodeDiffMessageContext *)context;
    NSData *data = [NSData dataWithBytes:block_hash length:32];
    uint32_t block_height = mndiffContext.blockHeightLookup(data.UInt256);
    mndiff_block_hash_destroy(block_hash);
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
    uintptr_t count = data->count;
    uint8_t (**items)[48] = data->items;
    NSMutableArray<DSBLSKey *> *publicKeyArray = [NSMutableArray array];
    for (NSUInteger i = 0; i < count; i++) {
        NSData *pkData = [NSData dataWithBytes:items[i] length:48];
        [publicKeyArray addObject:[DSBLSKey keyWithPublicKey:pkData.UInt384]];
    }
    uint8_t (*all_commitment_aggregated_signature)[96] = data->all_commitment_aggregated_signature;
    uint8_t (*commitment_hash)[32] = data->commitment_hash;
    UInt256 commitmentHash = [NSData dataWithBytes:commitment_hash length:32].UInt256;
    UInt768 allCommitmentAggregatedSignature = [NSData dataWithBytes:all_commitment_aggregated_signature length:96].UInt768;
    bool allCommitmentAggregatedSignatureValidated = [DSBLSKey verifySecureAggregated:commitmentHash signature:allCommitmentAggregatedSignature withPublicKeys:publicKeyArray];
    if (!allCommitmentAggregatedSignatureValidated) {
        return false;
    }
    //The sig must validate against the commitmentHash and all public keys determined by the signers bitvector. This is an aggregated BLS signature verification.
    uint8_t (*quorum_threshold_signature)[96] = data->quorum_threshold_signature;
    uint8_t (*quorum_public_key)[48] = data->quorum_public_key;
    UInt768 quorumThresholdSignature = [NSData dataWithBytes:quorum_threshold_signature length:96].UInt768;
    UInt384 quorumPublicKey = [NSData dataWithBytes:quorum_public_key length:48].UInt384;
    bool quorumSignatureValidated = [DSBLSKey verify:commitmentHash signature:quorumThresholdSignature withPublicKey:quorumPublicKey];
    mndiff_quorum_validation_data_destroy(data);
    if (!quorumSignatureValidated) {
        DSLog(@"Issue with quorumSignatureValidated");
        return false;
    }
    return true;
};

+ (MasternodeList *)wrapMasternodeList:(DSMasternodeList *)list {
    if (!list) return NULL;
    NSDictionary<NSNumber *, NSDictionary<NSData *, DSQuorumEntry *> *> *quorums = [list quorums];
    NSDictionary<NSData *, DSSimplifiedMasternodeEntry *> *masternodes = [list simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash];
    uintptr_t quorum_type_maps_count = quorums.count;
    uintptr_t masternodes_count = masternodes.count;
    MasternodeList *masternode_list = malloc(sizeof(MasternodeList));
    LLMQMap **quorum_type_maps = malloc(quorum_type_maps_count * sizeof(LLMQMap *));
    int i = 0;
    int j = 0;
    for (NSNumber *type in quorums) {
        NSDictionary<NSData *, DSQuorumEntry *> *quorumsMaps = quorums[type];
        uintptr_t quorum_maps_count = quorumsMaps.count;
        LLMQMap *quorums_map = malloc(sizeof(LLMQMap));
        QuorumEntry **quorums_of_type = malloc(quorum_maps_count * sizeof(QuorumEntry *));
        j = 0;
        for (NSData *hash in quorumsMaps) {
            quorums_of_type[j++] = [DSMasternodeManager wrapQuorumEntry:quorumsMaps[hash]];
        }
        quorums_map->llmq_type = (uint8_t)[type unsignedIntegerValue];
        quorums_map->count = quorum_maps_count;
        quorums_map->values = quorums_of_type;
        quorum_type_maps[i++] = quorums_map;
    }
    masternode_list->quorum_type_maps = quorum_type_maps;
    masternode_list->quorum_type_maps_count = quorum_type_maps_count;
    MasternodeEntry **masternodes_values = malloc(masternodes_count * sizeof(MasternodeEntry *));
    i = 0;
    for (NSData *hash in masternodes) {
        masternodes_values[i++] = [DSMasternodeManager wrapMasternodeEntry:masternodes[hash]];
    }
    masternode_list->masternodes = masternodes_values;
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
            [DSMasternodeManager freeMasternodeEntry:list->masternodes[i]];
        }
    }
    if (list->masternodes)
        free(list->masternodes);
    if (list->quorum_type_maps_count > 0) {
        for (int i = 0; i < list->quorum_type_maps_count; i++) {
            LLMQMap *map = list->quorum_type_maps[i];
            for (int j = 0; j < map->count; j++) {
                [DSMasternodeManager freeQuorumEntry:map->values[j]];
            }
            if (map->values)
                free(map->values);
            free(map);
        }
    }
    if (list->quorum_type_maps)
        free(list->quorum_type_maps);
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
    //NSLog(@"wrapMasternodeEntry: %p", entry);
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
    OperatorPublicKey *previous_operator_public_keys = malloc(previousOperatorPublicKeysCount * sizeof(OperatorPublicKey));
    int i = 0;
    for (DSBlock *block in previousOperatorPublicKeys) {
        NSData *keyData = previousOperatorPublicKeys[block];
        OperatorPublicKey obj = {.block_height = block.height};
        memcpy(obj.key, keyData.bytes, sizeof(UInt384));
        memcpy(obj.block_hash, block.blockHash.u8, sizeof(UInt256));
        previous_operator_public_keys[i] = obj;
        i++;
    }
    masternode_entry->previous_operator_public_keys = previous_operator_public_keys;
    masternode_entry->previous_operator_public_keys_count = previousOperatorPublicKeysCount;
    NSUInteger previousSimplifiedMasternodeEntryHashesCount = [previousSimplifiedMasternodeEntryHashes count];
    MasternodeEntryHash *previous_masternode_entry_hashes = malloc(previousSimplifiedMasternodeEntryHashesCount * sizeof(MasternodeEntryHash));
    i = 0;
    for (DSBlock *block in previousSimplifiedMasternodeEntryHashes) {
        NSData *hashData = previousSimplifiedMasternodeEntryHashes[block];
        MasternodeEntryHash obj = {.block_height = block.height};
        memcpy(obj.hash, hashData.bytes, sizeof(UInt256));
        memcpy(obj.block_hash, block.blockHash.u8, sizeof(UInt256));
        previous_masternode_entry_hashes[i] = obj;
        i++;
    }
    masternode_entry->previous_masternode_entry_hashes = previous_masternode_entry_hashes;
    masternode_entry->previous_masternode_entry_hashes_count = previousSimplifiedMasternodeEntryHashesCount;
    NSUInteger previousValidityCount = [previousValidity count];
    Validity *previous_validity = malloc(previousValidityCount * sizeof(Validity));
    i = 0;
    for (DSBlock *block in previousValidity) {
        NSNumber *flag = previousValidity[block];
        Validity obj = {.block_height = block.height, .is_valid = [flag boolValue]};
        memcpy(obj.block_hash, block.blockHash.u8, sizeof(UInt256));
        previous_validity[i] = obj;
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
    free(entry->confirmed_hash);
    if (entry->confirmed_hash_hashed_with_provider_registration_transaction_hash)
        free(entry->confirmed_hash_hashed_with_provider_registration_transaction_hash);
    free(entry->operator_public_key);
    free(entry->masternode_entry_hash);
    free(entry->ip_address);
    free(entry->key_id_voting);
    free(entry->provider_registration_transaction_hash);
    if (entry->previous_masternode_entry_hashes)
        free(entry->previous_masternode_entry_hashes);
    if (entry->previous_operator_public_keys)
        free(entry->previous_operator_public_keys);
    if (entry->previous_validity)
        free(entry->previous_validity);
    free(entry);
}
@end
