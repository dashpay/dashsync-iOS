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
#import "DSSimplifiedMasternodeEntry+Mndiff.h"
#import "NSData+Dash.h"

@implementation DSSimplifiedMasternodeEntry (Mndiff)

+ (instancetype)simplifiedEntryWith:(MasternodeEntry *)entry onChain:(DSChain *)chain {
    UInt256 confirmedHash = *((UInt256 *) entry->confirmed_hash);
    // TODO: Refactor to avoid unnecessary SHAing
    /*uint8_t (*confirmed_hash_hashed_with_provider_registration_transaction_hash)[32] = entry->confirmed_hash_hashed_with_provider_registration_transaction_hash;
    NSData *confirmedHashHashedWithProviderRegistrationTransactionHashData = confirmed_hash_hashed_with_provider_registration_transaction_hash
        ? [NSData dataWithBytes:confirmed_hash_hashed_with_provider_registration_transaction_hash length:32]
        : nil;
    UInt256 confirmedHashHashedWithProviderRegistrationTransactionHash = [confirmedHashHashedWithProviderRegistrationTransactionHashData UInt256];*/
    BOOL isValid = entry->is_valid;
    UInt160 keyIDVoting = *((UInt160 *) entry->key_id_voting);
    uint32_t knownConfirmedAtHeight = entry->known_confirmed_at_height;
    UInt256 simplifiedMasternodeEntryHash = *((UInt256 *) entry->masternode_entry_hash);
    UInt384 operatorPublicKey = *((UInt384 *) entry->operator_public_key);
    uintptr_t previous_operator_public_keys_count = entry->previous_operator_public_keys_count;
    OperatorPublicKey *previous_operator_public_keys = entry->previous_operator_public_keys;
    NSMutableDictionary<DSBlock *, NSData *> *operatorPublicKeys = [NSMutableDictionary dictionaryWithCapacity:previous_operator_public_keys_count];
    for (NSUInteger i = 0; i < previous_operator_public_keys_count; i++) {
        OperatorPublicKey operator_public_key = previous_operator_public_keys[i];
        UInt256 blockHash = *((UInt256 *) operator_public_key.block_hash);
        uint32_t blockHeight = operator_public_key.block_height;
        DSBlock *block = (DSBlock *)[chain blockForBlockHash:blockHash];
        if (!block) block = [[DSBlock alloc] initWithBlockHash:blockHash height:blockHeight onChain:chain];
        NSData *key = [NSData dataWithBytes:operator_public_key.key length:48];
        [operatorPublicKeys setObject:key forKey:block];
    }
    uintptr_t previous_masternode_entry_hashes_count = entry->previous_masternode_entry_hashes_count;
    MasternodeEntryHash *previous_masternode_entry_hashes = entry->previous_masternode_entry_hashes;
    NSMutableDictionary<DSBlock *, NSData *> *masternodeEntryHashes = [NSMutableDictionary dictionaryWithCapacity:previous_masternode_entry_hashes_count];
    for (NSUInteger i = 0; i < previous_masternode_entry_hashes_count; i++) {
        MasternodeEntryHash masternode_entry_hash = previous_masternode_entry_hashes[i];
        UInt256 blockHash = *((UInt256 *) masternode_entry_hash.block_hash);
        uint32_t blockHeight = masternode_entry_hash.block_height;
        DSBlock *block = (DSBlock *)[chain blockForBlockHash:blockHash];
        if (!block) block = [[DSBlock alloc] initWithBlockHash:blockHash height:blockHeight onChain:chain];
        NSData *hash = [NSData dataWithBytes:masternode_entry_hash.hash length:32];
        [masternodeEntryHashes setObject:hash forKey:block];
    }
    uintptr_t previous_validity_count = entry->previous_validity_count;
    Validity *previous_validity = entry->previous_validity;
    NSMutableDictionary<DSBlock *, NSNumber *> *validities = [NSMutableDictionary dictionaryWithCapacity:previous_validity_count];
    for (NSUInteger i = 0; i < previous_validity_count; i++) {
        Validity validity = previous_validity[i];
        UInt256 blockHash = *((UInt256 *) validity.block_hash);
        uint32_t blockHeight = validity.block_height;
        DSBlock *block = (DSBlock *)[chain blockForBlockHash:blockHash];
        if (!block) block = [[DSBlock alloc] initWithBlockHash:blockHash height:blockHeight onChain:chain];
        NSNumber *isValid = [NSNumber numberWithBool:validity.is_valid];
        [validities setObject:isValid forKey:block];
    }
    UInt256 providerRegistrationTransactionHash = *((UInt256 *) entry->provider_registration_transaction_hash);
    UInt128 address = *((UInt128 *) entry->ip_address);
    uint16_t port = entry->port;
    uint32_t updateHeight = entry->update_height;
    return [self simplifiedMasternodeEntryWithProviderRegistrationTransactionHash:providerRegistrationTransactionHash
                                                                    confirmedHash:confirmedHash
                                                                          address:address
                                                                             port:port
                                                             operatorBLSPublicKey:operatorPublicKey
                                                    previousOperatorBLSPublicKeys:operatorPublicKeys
                                                                      keyIDVoting:keyIDVoting
                                                                          isValid:isValid
                                                                 previousValidity:validities
                                                           knownConfirmedAtHeight:knownConfirmedAtHeight
                                                                     updateHeight:updateHeight
                                                    simplifiedMasternodeEntryHash:simplifiedMasternodeEntryHash
                                          previousSimplifiedMasternodeEntryHashes:masternodeEntryHashes
                                                                          onChain:chain];
}
+ (NSMutableDictionary<NSData *, DSSimplifiedMasternodeEntry *> *)simplifiedEntriesWith:(MasternodeEntry *_Nullable*_Nonnull)entries count:(uintptr_t)count onChain:(DSChain *)chain {
    NSMutableDictionary<NSData *, DSSimplifiedMasternodeEntry *> *masternodes = [NSMutableDictionary dictionaryWithCapacity:count];
    for (NSUInteger i = 0; i < count; i++) {
        MasternodeEntry *c_entry = entries[i];
        NSData *hash = [NSData dataWithBytes:c_entry->provider_registration_transaction_hash length:32].reverse;
        DSSimplifiedMasternodeEntry *entry = [DSSimplifiedMasternodeEntry simplifiedEntryWith:c_entry onChain:chain];
        [masternodes setObject:entry forKey:hash];
    }
    return masternodes;
}
@end
