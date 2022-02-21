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

+ (NSMutableDictionary<NSNumber *, NSMutableDictionary<NSData *, DSQuorumEntry *> *> *)entriesWith:(LLMQMap *_Nullable *_Nonnull)entries count:(uintptr_t)count onChain:(DSChain *)chain {
    NSMutableDictionary<NSNumber *, NSMutableDictionary<NSData *, DSQuorumEntry *> *> *quorums = [NSMutableDictionary dictionaryWithCapacity:count];
    for (NSUInteger i = 0; i < count; i++) {
        LLMQMap *llmq_map = entries[i];
        DSLLMQType llmqType = (DSLLMQType)llmq_map->llmq_type;
        NSMutableDictionary *quorumsOfType = [[NSMutableDictionary alloc] initWithCapacity:llmq_map->count];
        for (NSUInteger j = 0; j < llmq_map->count; j++) {
            LLMQEntry *quorum_entry = llmq_map->values[j];
            NSData *hash = [NSData dataWithBytes:quorum_entry->llmq_hash length:32];
            DSQuorumEntry *entry = [[DSQuorumEntry alloc] initWithEntry:quorum_entry onChain:chain];
            [quorumsOfType setObject:entry forKey:hash];
        }
        [quorums setObject:quorumsOfType
                    forKey:@(llmqType)];
    }
    return quorums;
}

- (LLMQEntry *)ffi_malloc {
    LLMQEntry *quorum_entry = malloc(sizeof(LLMQEntry));
    quorum_entry->all_commitment_aggregated_signature = malloc(sizeof(UInt768));
    memcpy(quorum_entry->all_commitment_aggregated_signature, [self allCommitmentAggregatedSignature].u8, sizeof(UInt768));
    quorum_entry->commitment_hash = malloc(sizeof(UInt256));
    memcpy(quorum_entry->commitment_hash, [self commitmentHash].u8, sizeof(UInt256));
    quorum_entry->length = [self length];
    quorum_entry->llmq_type = [self llmqType];
    quorum_entry->entry_hash = malloc(sizeof(UInt256));
    memcpy(quorum_entry->entry_hash, [self quorumEntryHash].u8, sizeof(UInt256));
    quorum_entry->llmq_hash = malloc(sizeof(UInt256));
    memcpy(quorum_entry->llmq_hash, [self quorumHash].u8, sizeof(UInt256));
    quorum_entry->public_key = malloc(sizeof(UInt384));
    memcpy(quorum_entry->public_key, [self quorumPublicKey].u8, sizeof(UInt384));
    quorum_entry->threshold_signature = malloc(sizeof(UInt768));
    memcpy(quorum_entry->threshold_signature, [self quorumThresholdSignature].u8, sizeof(UInt768));
    quorum_entry->verification_vector_hash = malloc(sizeof(UInt256));
    memcpy(quorum_entry->verification_vector_hash, [self quorumVerificationVectorHash].u8, sizeof(UInt256));
    quorum_entry->saved = [self saved];
    NSData *signersBitset = [self signersBitset];
    NSUInteger signersBitsetLength = signersBitset.length;
    quorum_entry->signers_bitset = malloc(signersBitsetLength);
    memcpy(quorum_entry->signers_bitset, signersBitset.bytes, signersBitsetLength);
    quorum_entry->signers_bitset_length = signersBitsetLength;
    quorum_entry->signers_count = [self signersCount];
    NSData *validMembersBitset = [self validMembersBitset];
    NSUInteger validMembersBitsetLength = validMembersBitset.length;
    quorum_entry->valid_members_bitset = malloc(validMembersBitsetLength);
    memcpy(quorum_entry->valid_members_bitset, validMembersBitset.bytes, validMembersBitsetLength);
    quorum_entry->valid_members_bitset_length = validMembersBitsetLength;
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
