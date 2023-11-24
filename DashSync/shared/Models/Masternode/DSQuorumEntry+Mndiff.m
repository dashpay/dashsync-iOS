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

#import "DSQuorumEntry+Mndiff.h"
#import "NSData+Dash.h"

@implementation DSQuorumEntry (Mndiff)

+ (NSDictionary<NSNumber *, NSDictionary<NSData *, DSQuorumEntry *> *> *)entriesWithMap:(LLMQMap *_Nullable *_Nonnull)entries count:(uintptr_t)count onChain:(DSChain *)chain {
    NSMutableDictionary<NSNumber *, NSMutableDictionary<NSData *, DSQuorumEntry *> *> *quorums = [NSMutableDictionary dictionaryWithCapacity:count];
    for (NSUInteger i = 0; i < count; i++) {
        LLMQMap *llmq_map = entries[i];
        LLMQType llmqType = (LLMQType)llmq_map->llmq_type;
        NSMutableDictionary *quorumsOfType = [[NSMutableDictionary alloc] initWithCapacity:llmq_map->count];
        for (NSUInteger j = 0; j < llmq_map->count; j++) {
            LLMQEntry *quorum_entry = llmq_map->values[j];
            NSData *hash = [NSData dataWithBytes:quorum_entry->llmq_hash length:32];
            DSQuorumEntry *entry = [[DSQuorumEntry alloc] initWithEntry:quorum_entry onChain:chain];
            [quorumsOfType setObject:entry forKey:hash];
        }
        [quorums setObject:quorumsOfType forKey:@(llmqType)];
    }
    return quorums;
}

+ (NSArray<DSQuorumEntry *> *)entriesWith:(LLMQEntry *_Nullable *_Nonnull)entries count:(uintptr_t)count onChain:(DSChain *)chain {
    NSMutableArray<DSQuorumEntry *> *result = [NSMutableArray arrayWithCapacity:count];
    for (NSUInteger i = 0; i < count; i++) {
        [result addObject:[[DSQuorumEntry alloc] initWithEntry:entries[i] onChain:chain]];
    }
    return result;
}

- (LLMQEntry *)ffi_malloc {
    LLMQEntry *quorum_entry = malloc(sizeof(LLMQEntry));
    quorum_entry->all_commitment_aggregated_signature = uint768_malloc([self allCommitmentAggregatedSignature]);
    quorum_entry->commitment_hash = uint256_malloc([self commitmentHash]);
    quorum_entry->llmq_type = (int8_t) [self llmqType];
    quorum_entry->entry_hash = uint256_malloc([self quorumEntryHash]);
    quorum_entry->llmq_hash = uint256_malloc([self quorumHash]);
    quorum_entry->public_key = uint384_malloc([self quorumPublicKey]);
    quorum_entry->threshold_signature = uint768_malloc([self quorumThresholdSignature]);
    quorum_entry->verification_vector_hash = uint256_malloc([self quorumVerificationVectorHash]);
    quorum_entry->saved = [self saved];
    NSData *signersBitset = [self signersBitset];
    quorum_entry->signers_bitset = data_malloc(signersBitset);
    quorum_entry->signers_bitset_length = signersBitset.length;
    quorum_entry->signers_count = [self signersCount];
    NSData *validMembersBitset = [self validMembersBitset];
    quorum_entry->valid_members_bitset = data_malloc(validMembersBitset);
    quorum_entry->valid_members_bitset_length = validMembersBitset.length;
    quorum_entry->valid_members_count = [self validMembersCount];
    quorum_entry->verified = [self verified];
    quorum_entry->version = [self version];
    return quorum_entry;
}

+ (void)ffi_free:(LLMQEntry *)entry {
    free(entry->all_commitment_aggregated_signature);
    if (entry->commitment_hash)
        free(entry->commitment_hash);
    free(entry->entry_hash);
    free(entry->llmq_hash);
    free(entry->public_key);
    free(entry->threshold_signature);
    free(entry->verification_vector_hash);
    free(entry->signers_bitset);
    free(entry->valid_members_bitset);
    free(entry);
}

@end
