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
#import "DSSimplifiedMasternodeEntry.h"
#import "NSData+Dash.h"

@implementation DSMasternodeList (Mndiff)

+ (instancetype)masternodeListWith:(MasternodeList *)list onChain:(DSChain *)chain {
    uint8_t(**masternodes_keys)[32] = list->masternodes_keys;
    MasternodeEntry **masternodes_values = list->masternodes_values;
    uintptr_t masternodes_count = list->masternodes_count;
    NSMutableDictionary<NSData *, DSSimplifiedMasternodeEntry *> *masternodes = [NSMutableDictionary dictionaryWithCapacity:masternodes_count];
    for (NSUInteger i = 0; i < masternodes_count; i++) {
        NSData *hash = [NSData dataWithBytes:masternodes_keys[i] length:32];
        [masternodes setObject:[[DSSimplifiedMasternodeEntry alloc] initWithEntry:masternodes_values[i] onChain:chain] forKey:hash];
    }
    uint8_t *quorums_keys = list->quorums_keys;
    LLMQMap **quorums_values = list->quorums_values;
    uintptr_t quorums_count = list->quorums_count;
    NSMutableDictionary<NSNumber *, NSMutableDictionary<NSData *, DSQuorumEntry *> *> *quorums = [NSMutableDictionary dictionaryWithCapacity:quorums_count];
    for (NSUInteger i = 0; i < quorums_count; i++) {
        DSLLMQType llmqType = (DSLLMQType)quorums_keys[i];
        LLMQMap *llmq_map = quorums_values[i];
        NSMutableDictionary *quorumsOfType = [[NSMutableDictionary alloc] initWithCapacity:llmq_map->count];
        for (NSUInteger j = 0; j < llmq_map->count; j++) {
            uint8_t(*h)[32] = llmq_map->keys[j];
            NSData *hash = [NSData dataWithBytes:h length:32];
            QuorumEntry *quorum_entry = llmq_map->values[j];
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
