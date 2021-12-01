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
#import "DSQuorumEntry.h"
#import "DSSimplifiedMasternodeEntry+Mndiff.h"
#import "NSData+Dash.h"

@implementation DSMasternodeList (Mndiff)

+ (instancetype)masternodeListWith:(MasternodeList *)list onChain:(DSChain *)chain {
    MasternodeEntry **c_masternodes = list->masternodes;
    uintptr_t masternodes_count = list->masternodes_count;
    NSMutableDictionary<NSData *, DSSimplifiedMasternodeEntry *> *masternodes = [DSSimplifiedMasternodeEntry simplifiedEntriesWith:c_masternodes count:masternodes_count onChain:chain];
    LLMQMap **quorum_type_maps = list->quorum_type_maps;
    uintptr_t quorum_type_maps_count = list->quorum_type_maps_count;
    NSMutableDictionary<NSNumber *, NSMutableDictionary<NSData *, DSQuorumEntry *> *> *quorums = [NSMutableDictionary dictionaryWithCapacity:quorum_type_maps_count];
    for (NSUInteger i = 0; i < quorum_type_maps_count; i++) {
        LLMQMap *llmq_map = quorum_type_maps[i];
        DSLLMQType llmqType = (DSLLMQType)llmq_map->llmq_type;
        NSMutableDictionary *quorumsOfType = [[NSMutableDictionary alloc] initWithCapacity:llmq_map->count];
        for (NSUInteger j = 0; j < llmq_map->count; j++) {
            QuorumEntry *quorum_entry = llmq_map->values[j];
            NSData *hash = [NSData dataWithBytes:quorum_entry->quorum_hash length:32];
            DSQuorumEntry *entry = [[DSQuorumEntry alloc] initWithEntry:quorum_entry onChain:chain];
            [quorumsOfType setObject:entry forKey:hash];
        }
        [quorums setObject:quorumsOfType
                    forKey:@(llmqType)];
    }
    uint8_t(*masternode_merkle_root)[32] = list->masternode_merkle_root;
    uint8_t(*quorum_merkle_root)[32] = list->quorum_merkle_root;
    NSData *masternodeMerkleRootData = masternode_merkle_root ? [NSData dataWithBytes:masternode_merkle_root length:32] : nil;
    NSData *quorumMerkleRootData = quorum_merkle_root ? [NSData dataWithBytes:quorum_merkle_root length:32] : nil;
    return [self masternodeListWithSimplifiedMasternodeEntriesDictionary:masternodes
                                                 quorumEntriesDictionary:quorums
                                                             atBlockHash:[NSData dataWithBytes:list->block_hash length:32].UInt256
                                                           atBlockHeight:list->known_height
                                            withMasternodeMerkleRootHash:[masternodeMerkleRootData UInt256]
                                                withQuorumMerkleRootHash:[quorumMerkleRootData UInt256]
                                                                 onChain:chain];
}

@end
