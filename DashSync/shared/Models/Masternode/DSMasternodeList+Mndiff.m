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

#import "BigIntTypes.h"
#import "DSMasternodeList+Mndiff.h"
#import "DSQuorumEntry+Mndiff.h"
#import "DSSimplifiedMasternodeEntry+Mndiff.h"
#import "NSData+Dash.h"

@implementation DSMasternodeList (Mndiff)

+ (instancetype)masternodeListWith:(MasternodeList *)list onChain:(DSChain *)chain {
    uintptr_t masternodes_count = list->masternodes_count;
    NSMutableDictionary<NSData *, DSSimplifiedMasternodeEntry *> *masternodes = [DSSimplifiedMasternodeEntry simplifiedEntriesWith:list->masternodes count:masternodes_count onChain:chain];
    NSMutableDictionary<NSNumber *, NSMutableDictionary<NSData *, DSQuorumEntry *> *> *quorums = [DSQuorumEntry entriesWith:list->quorum_type_maps count:list->quorum_type_maps_count onChain:chain];
    UInt256 masternodeMerkleRoot = list->masternode_merkle_root ? *((UInt256 *)list->masternode_merkle_root) : UINT256_ZERO;
    UInt256 quorumMerkleRoot = list->quorum_merkle_root ? *((UInt256 *)list->quorum_merkle_root) : UINT256_ZERO;
    UInt256 blockHash = *((UInt256 *)list->block_hash);
    return [self masternodeListWithSimplifiedMasternodeEntriesDictionary:masternodes
                                                 quorumEntriesDictionary:quorums
                                                             atBlockHash:blockHash
                                                           atBlockHeight:list->known_height
                                            withMasternodeMerkleRootHash:masternodeMerkleRoot
                                                withQuorumMerkleRootHash:quorumMerkleRoot
                                                                 onChain:chain];
}

- (MasternodeList *)ffi_malloc {
    NSDictionary<NSNumber *, NSDictionary<NSData *, DSQuorumEntry *> *> *quorums = [self quorums];
    NSDictionary<NSData *, DSSimplifiedMasternodeEntry *> *masternodes = [self simplifiedMasternodeListDictionaryByReversedRegistrationTransactionHash];
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
            quorums_of_type[j++] = [quorumsMaps[hash] ffi_malloc];
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
        masternodes_values[i++] = [masternodes[hash] ffi_malloc];
    }
    masternode_list->masternodes = masternodes_values;
    masternode_list->masternodes_count = masternodes_count;
    masternode_list->block_hash = malloc(sizeof(UInt256));
    memcpy(masternode_list->block_hash, [self blockHash].u8, sizeof(UInt256));
    masternode_list->known_height = [self height];
    masternode_list->masternode_merkle_root = malloc(sizeof(UInt256));
    memcpy(masternode_list->masternode_merkle_root, [self masternodeMerkleRoot].u8, sizeof(UInt256));
    masternode_list->quorum_merkle_root = malloc(sizeof(UInt256));
    memcpy(masternode_list->quorum_merkle_root, [self quorumMerkleRoot].u8, sizeof(UInt256));
    return masternode_list;
}

+ (void)ffi_free:(MasternodeList *)list {
    if (!list) return;
    free(list->block_hash);
    if (list->masternodes_count > 0) {
        for (int i = 0; i < list->masternodes_count; i++) {
            [DSSimplifiedMasternodeEntry ffi_free:list->masternodes[i]];
        }
    }
    if (list->masternodes)
        free(list->masternodes);
    if (list->quorum_type_maps_count > 0) {
        for (int i = 0; i < list->quorum_type_maps_count; i++) {
            LLMQMap *map = list->quorum_type_maps[i];
            for (int j = 0; j < map->count; j++) {
                [DSQuorumEntry ffi_free:map->values[i]];
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

@end
