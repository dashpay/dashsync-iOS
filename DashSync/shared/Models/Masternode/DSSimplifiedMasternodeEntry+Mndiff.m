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
    UInt256 confirmedHash = [NSData dataWithBytes:entry->confirmed_hash length:32].UInt256;
    /*uint8_t (*confirmed_hash_hashed_with_provider_registration_transaction_hash)[32] = entry->confirmed_hash_hashed_with_provider_registration_transaction_hash;
    NSData *confirmedHashHashedWithProviderRegistrationTransactionHashData = confirmed_hash_hashed_with_provider_registration_transaction_hash
        ? [NSData dataWithBytes:confirmed_hash_hashed_with_provider_registration_transaction_hash length:32]
        : nil;
    UInt256 confirmedHashHashedWithProviderRegistrationTransactionHash = [confirmedHashHashedWithProviderRegistrationTransactionHashData UInt256];*/
    BOOL isValid = entry->is_valid;
    UInt160 keyIDVoting = [NSData dataWithBytes:entry->key_id_voting length:20].UInt160;
    uint32_t knownConfirmedAtHeight = entry->known_confirmed_at_height;
    UInt256 simplifiedMasternodeEntryHash = [NSData dataWithBytes:entry->masternode_entry_hash length:32].UInt256;
    UInt384 operatorPublicKey = [NSData dataWithBytes:entry->operator_public_key length:48].UInt384;
    uintptr_t previous_operator_public_keys_count = entry->previous_operator_public_keys_count;
    OperatorPublicKey **previous_operator_public_keys = entry->previous_operator_public_keys;
    NSMutableDictionary<DSBlock *, NSData *> *operatorPublicKeys = [NSMutableDictionary dictionaryWithCapacity:previous_operator_public_keys_count];
    for (NSUInteger i = 0; i < previous_operator_public_keys_count; i++) {
        OperatorPublicKey *operator_public_key = previous_operator_public_keys[i];
        UInt256 blockHash = [NSData dataWithBytes:operator_public_key->block_hash length:32].UInt256;
        uint32_t blockHeight = operator_public_key->block_height;
        DSBlock *block = [chain blockForBlockHash:blockHash];
        if (!block) block = [[DSBlock alloc] initWithBlockHash:blockHash height:blockHeight onChain:chain];
        NSData *key = [NSData dataWithBytes:operator_public_key->key length:48];
        [operatorPublicKeys setObject:key forKey:block];
    }
    uintptr_t previous_masternode_entry_hashes_count = entry->previous_masternode_entry_hashes_count;
    MasternodeEntryHash **previous_masternode_entry_hashes = entry->previous_masternode_entry_hashes;
    NSMutableDictionary<DSBlock *, NSData *> *masternodeEntryHashes = [NSMutableDictionary dictionaryWithCapacity:previous_masternode_entry_hashes_count];
    BOOL needLog = previous_masternode_entry_hashes_count > 1;
    for (NSUInteger i = 0; i < previous_masternode_entry_hashes_count; i++) {
        MasternodeEntryHash *masternode_entry_hash = previous_masternode_entry_hashes[i];
        UInt256 blockHash = [NSData dataWithBytes:masternode_entry_hash->block_hash length:32].UInt256;
        uint32_t blockHeight = masternode_entry_hash->block_height;
        DSBlock *block = [chain blockForBlockHash:blockHash];
        if (!block) block = [[DSBlock alloc] initWithBlockHash:blockHash height:blockHeight onChain:chain];
        NSData *hash = [NSData dataWithBytes:masternode_entry_hash->hash length:32];
        if (needLog) NSLog(@"initWithEntry.previous_masternode_entry_hashes[%lu]:%p\n%u:%@", i, masternode_entry_hash, blockHeight, hash.hexString);
        [masternodeEntryHashes setObject:hash forKey:block];
    }
    uintptr_t previous_validity_count = entry->previous_validity_count;
    Validity **previous_validity = entry->previous_validity;
    NSMutableDictionary<DSBlock *, NSNumber *> *validities = [NSMutableDictionary dictionaryWithCapacity:previous_validity_count];
    for (NSUInteger i = 0; i < previous_validity_count; i++) {
        Validity *validity = previous_validity[i];
        UInt256 blockHash = [NSData dataWithBytes:validity->block_hash length:32].UInt256;
        uint32_t blockHeight = validity->block_height;
        DSBlock *block = [chain blockForBlockHash:blockHash];
        if (!block) block = [[DSBlock alloc] initWithBlockHash:blockHash height:blockHeight onChain:chain];
        NSNumber *isValid = [NSNumber numberWithBool:validity->is_valid];
        [validities setObject:isValid forKey:block];
    }
    UInt256 providerRegistrationTransactionHash = [NSData dataWithBytes:entry->provider_registration_transaction_hash length:32].UInt256;
    UInt128 address = [NSData dataWithBytes:entry->ip_address length:16].UInt128;
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


@end
