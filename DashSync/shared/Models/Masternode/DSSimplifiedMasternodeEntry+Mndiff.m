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

//+ (instancetype)simplifiedEntryWith:(MasternodeEntry *)entry onChain:(DSChain *)chain {
//    UInt256 confirmedHash = *((UInt256 *)entry->confirmed_hash);
//    // TODO: Refactor to avoid unnecessary SHAing
//    /*uint8_t (*confirmed_hash_hashed_with_provider_registration_transaction_hash)[32] = entry->confirmed_hash_hashed_with_provider_registration_transaction_hash;
//    NSData *confirmedHashHashedWithProviderRegistrationTransactionHashData = confirmed_hash_hashed_with_provider_registration_transaction_hash
//        ? [NSData dataWithBytes:confirmed_hash_hashed_with_provider_registration_transaction_hash length:32]
//        : nil;
//    UInt256 confirmedHashHashedWithProviderRegistrationTransactionHash = [confirmedHashHashedWithProviderRegistrationTransactionHashData UInt256];*/
//    BOOL isValid = entry->is_valid;
//    UInt160 keyIDVoting = *((UInt160 *)entry->key_id_voting);
//    uint32_t knownConfirmedAtHeight = entry->known_confirmed_at_height;
//    UInt256 simplifiedMasternodeEntryHash = *((UInt256 *)entry->entry_hash);
//    OperatorPublicKey *operator_public_key = entry->operator_public_key;
//    UInt384 operatorPublicKey = *((UInt384 *)operator_public_key->data);
//    uint16_t operatorPublicKeyVersion = operator_public_key->version;
//    uintptr_t previous_operator_public_keys_count = entry->previous_operator_public_keys_count;
//    BlockOperatorPublicKey *previous_operator_public_keys = entry->previous_operator_public_keys;
//    NSMutableDictionary<NSData *, NSData *> *operatorPublicKeys = [NSMutableDictionary dictionaryWithCapacity:previous_operator_public_keys_count];
//    for (NSUInteger i = 0; i < previous_operator_public_keys_count; i++) {
//        BlockOperatorPublicKey prev_operator_public_key = previous_operator_public_keys[i];
//        UInt256 blockHash = *((UInt256 *)prev_operator_public_key.block_hash);
//        uint32_t blockHeight = prev_operator_public_key.block_height;
//        NSData *block = [NSData dataWithBlockHash:blockHash height:blockHeight];
//        NSMutableData *data = [NSMutableData dataWithUInt384:*((UInt384 *)prev_operator_public_key.key)];
//        [data appendData:[NSData dataWithUInt16:prev_operator_public_key.version]];
//        [operatorPublicKeys setObject:data forKey:block];
//    }
//    uintptr_t previous_entry_hashes_count = entry->previous_entry_hashes_count;
//    MasternodeEntryHash *previous_entry_hashes = entry->previous_entry_hashes;
//    NSMutableDictionary<NSData *, NSData *> *masternodeEntryHashes = [NSMutableDictionary dictionaryWithCapacity:previous_entry_hashes_count];
//    for (NSUInteger i = 0; i < previous_entry_hashes_count; i++) {
//        MasternodeEntryHash entry_hash = previous_entry_hashes[i];
//        UInt256 blockHash = *((UInt256 *)entry_hash.block_hash);
//        uint32_t blockHeight = entry_hash.block_height;
//        NSData *block = [NSData dataWithBlockHash:blockHash height:blockHeight];
//        NSData *hash = [NSData dataWithBytes:entry_hash.hash length:32];
//        [masternodeEntryHashes setObject:hash forKey:block];
//    }
//    uintptr_t previous_validity_count = entry->previous_validity_count;
//    Validity *previous_validity = entry->previous_validity;
//    NSMutableDictionary<NSData *, NSNumber *> *validities = [NSMutableDictionary dictionaryWithCapacity:previous_validity_count];
//    for (NSUInteger i = 0; i < previous_validity_count; i++) {
//        Validity validity = previous_validity[i];
//        UInt256 blockHash = *((UInt256 *)validity.block_hash);
//        uint32_t blockHeight = validity.block_height;
//        NSData *block = [NSData dataWithBlockHash:blockHash height:blockHeight];
//        NSNumber *isValid = [NSNumber numberWithBool:validity.is_valid];
//        [validities setObject:isValid forKey:block];
//    }
//    UInt256 providerRegistrationTransactionHash = *((UInt256 *)entry->provider_registration_transaction_hash);
//    UInt128 address = *((UInt128 *)entry->ip_address);
//    uint16_t port = entry->port;
//    uint32_t updateHeight = entry->update_height;
//    uint16_t type = entry->mn_type;
//    uint16_t platformHTTPPort = entry->platform_http_port;
//    UInt160 platformNodeID = *((UInt160 *)entry->platform_node_id);
//   return [self simplifiedMasternodeEntryWithProviderRegistrationTransactionHash:providerRegistrationTransactionHash
//                                                                    confirmedHash:confirmedHash
//                                                                          address:address
//                                                                             port:port
//                                                             operatorBLSPublicKey:operatorPublicKey
//                                                             operatorPublicKeyVersion:operatorPublicKeyVersion
//                                                    previousOperatorBLSPublicKeys:operatorPublicKeys
//                                                                      keyIDVoting:keyIDVoting
//                                                                          isValid:isValid
//                                                                            type:type
//                                                                platformHTTPPort:platformHTTPPort
//                                                                platformNodeID:platformNodeID
//                                                                 previousValidity:validities
//                                                           knownConfirmedAtHeight:knownConfirmedAtHeight
//                                                                     updateHeight:updateHeight
//                                                    simplifiedMasternodeEntryHash:simplifiedMasternodeEntryHash
//                                          previousSimplifiedMasternodeEntryHashes:masternodeEntryHashes
//                                                                          onChain:chain];
//}
//+ (NSDictionary<NSData *, DSSimplifiedMasternodeEntry *> *)simplifiedEntriesWith:(MasternodeEntry *_Nullable *_Nonnull)entries count:(uintptr_t)count onChain:(DSChain *)chain {
//    NSMutableDictionary<NSData *, DSSimplifiedMasternodeEntry *> *masternodes = [NSMutableDictionary dictionaryWithCapacity:count];
//    for (NSUInteger i = 0; i < count; i++) {
//        MasternodeEntry *c_entry = entries[i];
//        DSSimplifiedMasternodeEntry *entry = [DSSimplifiedMasternodeEntry simplifiedEntryWith:c_entry onChain:chain];
//        UInt256 hash = uint256_reverse(entry.providerRegistrationTransactionHash);
//        [masternodes setObject:entry forKey:uint256_data(hash)];
//    }
//    return masternodes;
//}
//
//- (MasternodeEntry *)ffi_malloc {
//    uint32_t known_confirmed_at_height = [self knownConfirmedAtHeight];
//    NSDictionary<NSData *, NSData *> *previousOperatorPublicKeys = [self previousOperatorPublicKeys];
//    NSDictionary<NSData *, NSData *> *previousSimplifiedMasternodeEntryHashes = [self previousSimplifiedMasternodeEntryHashes];
//    NSDictionary<NSData *, NSNumber *> *previousValidity = [self previousValidity];
//    MasternodeEntry *masternode_entry = malloc(sizeof(MasternodeEntry));
//    masternode_entry->confirmed_hash = uint256_malloc([self confirmedHash]);
//    masternode_entry->confirmed_hash_hashed_with_provider_registration_transaction_hash = uint256_malloc([self confirmedHashHashedWithProviderRegistrationTransactionHash]);
//    masternode_entry->is_valid = [self isValid];
//    masternode_entry->key_id_voting = uint160_malloc([self keyIDVoting]);
//    masternode_entry->known_confirmed_at_height = known_confirmed_at_height;
//    masternode_entry->entry_hash = uint256_malloc([self simplifiedMasternodeEntryHash]);
//    OperatorPublicKey *operator_public_key = malloc(sizeof(OperatorPublicKey));
//    memcpy(operator_public_key->data, [self operatorPublicKey].u8, sizeof(UInt384));
//    operator_public_key->version = self.operatorPublicKeyVersion;
//    masternode_entry->operator_public_key = operator_public_key;
//    NSUInteger previousOperatorPublicKeysCount = [previousOperatorPublicKeys count];
//    BlockOperatorPublicKey *previous_operator_public_keys = malloc(previousOperatorPublicKeysCount * sizeof(BlockOperatorPublicKey));
//    NSUInteger i = 0;
//    for (NSData *block in previousOperatorPublicKeys) {
//        NSData *keyVersionData = previousOperatorPublicKeys[block];
//        UInt256 blockHash = *(UInt256 *)(block.bytes);
//        uint32_t blockHeight = *(uint32_t *)(block.bytes + sizeof(UInt256));
//        BlockOperatorPublicKey obj = {.block_height = blockHeight};
//        memcpy(obj.block_hash, blockHash.u8, sizeof(UInt256));
//        if (keyVersionData.length == 48) {
//            obj.version = 0;
//            memcpy(obj.key, keyVersionData.bytes, sizeof(UInt384));
//        } else {
//            UInt384 keyData = [keyVersionData UInt384AtOffset:0];
//            obj.version = [keyVersionData UInt16AtOffset:48];
//            memcpy(obj.key, keyData.u8, sizeof(UInt384));
//        }
//        previous_operator_public_keys[i++] = obj;
//    }
//    masternode_entry->previous_operator_public_keys = previous_operator_public_keys;
//    masternode_entry->previous_operator_public_keys_count = previousOperatorPublicKeysCount;
//    NSUInteger previousSimplifiedMasternodeEntryHashesCount = [previousSimplifiedMasternodeEntryHashes count];
//    MasternodeEntryHash *previous_masternode_entry_hashes = malloc(previousSimplifiedMasternodeEntryHashesCount * sizeof(MasternodeEntryHash));
//    i = 0;
//    for (NSData *block in previousSimplifiedMasternodeEntryHashes) {
//        NSData *hashData = previousSimplifiedMasternodeEntryHashes[block];
//        UInt256 blockHash = *(UInt256 *)(block.bytes);
//        uint32_t blockHeight = *(uint32_t *)(block.bytes + sizeof(UInt256));
//        MasternodeEntryHash obj = {.block_height = blockHeight};
//        memcpy(obj.hash, hashData.bytes, sizeof(UInt256));
//        memcpy(obj.block_hash, blockHash.u8, sizeof(UInt256));
//        previous_masternode_entry_hashes[i++] = obj;
//    }
//    masternode_entry->previous_entry_hashes = previous_masternode_entry_hashes;
//    masternode_entry->previous_entry_hashes_count = previousSimplifiedMasternodeEntryHashesCount;
//    NSUInteger previousValidityCount = [previousValidity count];
//    Validity *previous_validity = malloc(previousValidityCount * sizeof(Validity));
//    i = 0;
//    for (NSData *block in previousValidity) {
//        NSNumber *flag = previousValidity[block];
//        UInt256 blockHash = *(UInt256 *)(block.bytes);
//        uint32_t blockHeight = *(uint32_t *)(block.bytes + sizeof(UInt256));
//        Validity obj = {.block_height = blockHeight, .is_valid = [flag boolValue]};
//        memcpy(obj.block_hash, blockHash.u8, sizeof(UInt256));
//        previous_validity[i++] = obj;
//    }
//    masternode_entry->previous_validity = previous_validity;
//    masternode_entry->previous_validity_count = previousValidityCount;
//    masternode_entry->provider_registration_transaction_hash = uint256_malloc([self providerRegistrationTransactionHash]);
//    masternode_entry->ip_address = uint128_malloc([self address]);
//    masternode_entry->port = [self port];
//    masternode_entry->update_height = [self updateHeight];
//    masternode_entry->mn_type = [self type];
//    masternode_entry->platform_http_port = [self platformHTTPPort];
//    masternode_entry->platform_node_id = uint160_malloc([self platformNodeID]);
//    return masternode_entry;
//
//}
//
//+ (void)ffi_free:(MasternodeEntry *)entry {
//    free(entry->confirmed_hash);
//    if (entry->confirmed_hash_hashed_with_provider_registration_transaction_hash)
//        free(entry->confirmed_hash_hashed_with_provider_registration_transaction_hash);
//    free(entry->operator_public_key);
//    free(entry->entry_hash);
//    free(entry->ip_address);
//    free(entry->key_id_voting);
//    free(entry->platform_node_id);
//    free(entry->provider_registration_transaction_hash);
//    if (entry->previous_entry_hashes)
//        free(entry->previous_entry_hashes);
//    if (entry->previous_operator_public_keys)
//        free(entry->previous_operator_public_keys);
//    if (entry->previous_validity)
//        free(entry->previous_validity);
//    free(entry);
//}

@end
