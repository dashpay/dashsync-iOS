//
//  DSSimplifiedMasternodeEntryEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 7/19/18.
//
//

#import "DSAddressEntity+CoreDataClass.h"
#import "DSChain+Params.h"
#import "DSChain+Protected.h"
#import "DSChainEntity+CoreDataProperties.h"
#import "NSDictionary+Dash.h"
#import "DSKeyManager.h"
#import "DSLocalMasternodeEntity+CoreDataClass.h"
#import "DSMerkleBlock.h"
#import "DSSimplifiedMasternodeEntryEntity+CoreDataClass.h"
#import "NSData+Dash.h"
#import "NSDictionary+Dash.h"
#import "NSManagedObject+Sugar.h"
#import "NSMutableData+Dash.h"
#include <arpa/inet.h>

#define LOG_SMNE_CHANGES 0

#if LOG_SMNE_CHANGES
#define DSDSMNELog(s, ...) DSLog(s, ##__VA_ARGS__)
#else
#define DSDSMNELog(s, ...)
#endif

//DSLog(s, ##__VA_ARGS__)

@implementation DSSimplifiedMasternodeEntryEntity

- (void)updateAttributesFromSimplifiedMasternodeEntry:(DMasternodeEntry *)simplifiedMasternodeEntry
                                        atBlockHeight:(uint32_t)blockHeight
                               knownOperatorAddresses:(NSDictionary<NSString *, DSAddressEntity *> *)knownOperatorAddresses
                                 knownVotingAddresses:(NSDictionary<NSString *, DSAddressEntity *> *)knownVotingAddresses
                                platformNodeAddresses:(NSDictionary<NSString *, DSAddressEntity *> *)platformNodeAddresses
                                     localMasternodes:(NSDictionary<NSData *, DSLocalMasternodeEntity *> *)localMasternodes
                                              onChain:(DSChain *)chain {
    if (self.updateHeight < blockHeight) {
        //NSAssert(simplifiedMasternodeEntry.updateHeight == blockHeight, @"the block height should be the same as the entry update height");
        self.updateHeight = blockHeight;
        //we should only update if the data received is the most recent
        if (!dash_spv_masternode_processor_models_masternode_entry_MasternodeEntry_address_is_equal_to(simplifiedMasternodeEntry, u128_ctor(self.ipv6Address))) {
            self.ipv6Address = uint128_data(u128_cast(simplifiedMasternodeEntry->socket_address->ip_address));
            uint32_t address32 = dash_spv_masternode_processor_common_socket_address_SocketAddress_ipv4(simplifiedMasternodeEntry->socket_address);
            if (self.address != address32) {
                self.address = address32;
#if LOG_SMNE_CHANGES
                char s[INET6_ADDRSTRLEN];
#endif
                DSDSMNELog(@"changing address to %@", @(inet_ntop(AF_INET, &address32, s, sizeof(s))));
            }
        }
        
        NSData *confirmedHashData = NSDataFromPtr(simplifiedMasternodeEntry->confirmed_hash);
        bool same_confirmed_hash = dash_spv_masternode_processor_models_masternode_entry_MasternodeEntry_confirmed_hash_is_equal_to(simplifiedMasternodeEntry, u256_ctor(self.confirmedHash));
        if (!same_confirmed_hash) {
            NSAssert(self.confirmedHash == nil || uint256_is_zero(self.confirmedHash.UInt256), @"If this changes the previous should be empty");
            //this should only happen once at confirmation
            self.confirmedHash = confirmedHashData;
            self.knownConfirmedAtHeight = blockHeight;
            DSDSMNELog(@"changing confirmedHashData to %@", confirmedHashData.hexString);
        }
        if (self.port != simplifiedMasternodeEntry->socket_address->port) {
            self.port = simplifiedMasternodeEntry->socket_address->port;
            DSDSMNELog(@"changing port to %u", simplifiedMasternodeEntry.port);
        }
        
        if (!dash_spv_masternode_processor_models_masternode_entry_MasternodeEntry_key_id_is_equal_to(simplifiedMasternodeEntry, u160_ctor(self.keyIDVoting))) {
            self.keyIDVoting = NSDataFromPtr(simplifiedMasternodeEntry->key_id_voting);
            DSDSMNELog(@"changing keyIDVotingData to %@", keyIDVotingData.hexString);
        }
        if (!dash_spv_masternode_processor_models_masternode_entry_MasternodeEntry_operator_pub_key_is_equal_to(simplifiedMasternodeEntry, u384_ctor(self.operatorBLSPublicKey))) {
            self.operatorBLSPublicKey = NSDataFromPtr(simplifiedMasternodeEntry->operator_public_key->data);
            self.operatorPublicKeyVersion = simplifiedMasternodeEntry->operator_public_key->version;
            DSDSMNELog(@"changing operatorBLSPublicKey to %@", operatorPublicKeyData.hexString);
        }
        if (!dash_spv_masternode_processor_models_masternode_entry_MasternodeEntry_type_is_equal_to(simplifiedMasternodeEntry, self.type)) {
            self.type = dash_spv_masternode_processor_models_masternode_entry_MasternodeEntry_type_uint(simplifiedMasternodeEntry);
            DSDSMNELog(@"changing type to %d", self.type);
        }
        if (!dash_spv_masternode_processor_models_masternode_entry_MasternodeEntry_platform_node_id_is_equal_to(simplifiedMasternodeEntry, u160_ctor(self.platformNodeID))) {
            self.platformNodeID = NSDataFromPtr(simplifiedMasternodeEntry->platform_node_id);
            DSDSMNELog(@"changing platformNodeID to %d", platformNodeIDData.hexString);
        }
        if (self.platformHTTPPort != simplifiedMasternodeEntry->platform_http_port) {
            self.platformHTTPPort = simplifiedMasternodeEntry->platform_http_port;
            DSDSMNELog(@"changing platformHTTPPort to %d", simplifiedMasternodeEntry->platformHTTPPort);
        }

        if (self.isValid != simplifiedMasternodeEntry->is_valid) {
            self.isValid = simplifiedMasternodeEntry->is_valid;
            DSDSMNELog(@"changing isValid to %@", simplifiedMasternodeEntry->isValid ? @"TRUE" : @"FALSE");
        }
        // TODO: self.version = simplifiedMasternodeEntry->?
        self.simplifiedMasternodeEntryHash = NSDataFromPtr(simplifiedMasternodeEntry->entry_hash);
        
        [self mergePreviousFieldsUsingSimplifiedMasternodeEntrysPreviousFields:simplifiedMasternodeEntry
                                                                 atBlockHeight:blockHeight];
        NSData *localNodeHash = NSDataFromPtr(simplifiedMasternodeEntry->provider_registration_transaction_hash);
        DSLocalMasternodeEntity *localMasternode = localMasternodes
            ? [localMasternodes objectForKey:localNodeHash]
            : [DSLocalMasternodeEntity anyObjectInContext:self.managedObjectContext matching:@"providerRegistrationTransaction.transactionHash.txHash == %@", localNodeHash];
        self.localMasternode = localMasternode;
        char *operator_address = DMasternodeEntryOperatorPublicKeyAddress(simplifiedMasternodeEntry, chain.chainType);
        char *voting_address = DMasternodeEntryVotingAddress(simplifiedMasternodeEntry, chain.chainType);
        char *platform_node_address = DMasternodeEntryEvoNodeAddress(simplifiedMasternodeEntry, chain.chainType);
        
        NSString *operatorAddress = NSStringFromPtr(operator_address);
        NSString *votingAddress = NSStringFromPtr(voting_address);
        NSString *platformNodeAddress = NSStringFromPtr(platform_node_address);
        str_destroy(operator_address);
        str_destroy(voting_address);
        str_destroy(platform_node_address);
        
        [self addAddressIfExist:operatorAddress addresses:knownOperatorAddresses onChain:chain];
        [self addAddressIfExist:votingAddress addresses:knownVotingAddresses onChain:chain];
        [self addAddressIfExist:platformNodeAddress addresses:platformNodeAddresses onChain:chain];
    } else if (blockHeight < self.updateHeight) {
        [self mergePreviousFieldsUsingSimplifiedMasternodeEntrysPreviousFields:simplifiedMasternodeEntry
                                                                 atBlockHeight:blockHeight];
    }
}

- (void)mergePreviousFieldsUsingSimplifiedMasternodeEntrysPreviousFields:(DMasternodeEntry *)entry
                                                           atBlockHeight:(uint32_t)blockHeight {
    //we should not update current values but we should merge some fields
    //currentPrevious means the current set of previous values
    //oldPrevious means the old set of previous values

    DPreviousEntryHashes *prev_entry_hashes = entry->previous_entry_hashes;
    NSMutableDictionary *prevEntryHashes = [NSMutableDictionary dictionaryWithCapacity:prev_entry_hashes->count];
    for (int i = 0; i < prev_entry_hashes->count; i++) {
        [prevEntryHashes setObject:NSDataFromPtr(prev_entry_hashes->values[i]) forKey:NSDataFromPtr(prev_entry_hashes->keys[i]->hash)];
    }
    if (!self.previousSimplifiedMasternodeEntryHashes || [self.previousSimplifiedMasternodeEntryHashes count] == 0) {
        self.previousSimplifiedMasternodeEntryHashes = prevEntryHashes;
    } else {
        NSMutableDictionary *mergedDictionary = [self.previousSimplifiedMasternodeEntryHashes mutableCopy];
        [mergedDictionary addEntriesFromDictionary:prevEntryHashes];
        self.previousSimplifiedMasternodeEntryHashes = mergedDictionary;
    }
    DPreviousOperatorKeys *prev_operator_keys = entry->previous_operator_public_keys;
    NSMutableDictionary *prevOperatorKeys = [NSMutableDictionary dictionaryWithCapacity:prev_operator_keys->count];

    for (int i = 0; i < prev_operator_keys->count; i++) {
        dash_spv_crypto_keys_operator_public_key_OperatorPublicKey *value = prev_operator_keys->values[i];
        NSMutableData *v = [NSMutableData dataWithBytes:value->data->values length:48];
        [v appendUInt16:value->version];
        [prevOperatorKeys setObject:v forKey:NSDataFromPtr(prev_operator_keys->keys[i]->hash)];
    }
    if (!self.previousOperatorBLSPublicKeys || [self.previousOperatorBLSPublicKeys count] == 0) {
        self.previousOperatorBLSPublicKeys = prevOperatorKeys;
    } else {
        NSMutableDictionary *mergedDictionary = [self.previousOperatorBLSPublicKeys mutableCopy];
        [mergedDictionary addEntriesFromDictionary:prevOperatorKeys];
        self.previousOperatorBLSPublicKeys = mergedDictionary;
    }
    DPreviousValidity *prev_validity = entry->previous_validity;
    NSMutableDictionary *prevValidity = [NSMutableDictionary dictionaryWithCapacity:prev_validity->count];
    for (int i = 0; i < prev_validity->count; i++) {
        [prevValidity setObject:@(prev_validity->values[i]) forKey:NSDataFromPtr(prev_validity->keys[i]->hash)];
    }
    if (!self.previousValidity || [self.previousValidity count] == 0) {
        self.previousValidity = prevValidity;
    } else {
        NSMutableDictionary *mergedDictionary = [self.previousValidity mutableCopy];
        [mergedDictionary addEntriesFromDictionary:prevValidity];
        self.previousValidity = mergedDictionary;
    }

    if (uint256_is_not_zero(self.confirmedHash.UInt256) && !u_is_zero(entry->confirmed_hash) && (self.knownConfirmedAtHeight > blockHeight)) {
        //we now know it was confirmed earlier so update to earlier
        self.knownConfirmedAtHeight = blockHeight;
    }

    
//    NSMutableString *debugInfo = [NSMutableString stringWithFormat:@"Entity: mergePreviousFieldsUsingSimplifiedMasternodeEntrysPreviousFields at %u for %@\n", blockHeight, u256_hex(entry->provider_registration_transaction_hash)];
//    
//    for (NSData *data in self.previousSimplifiedMasternodeEntryHashes) {
//        NSData *entry_hash = self.previousSimplifiedMasternodeEntryHashes[data];
//        NSUInteger offset = 0;
//        UInt256 blockHash = [data readUInt256AtOffset:&offset];
//        uint32_t blockHeight = [data readUInt32AtOffset:&offset];
//        [debugInfo appendFormat:@"%u: %@: %@\n", blockHeight, uint256_hex(blockHash), entry_hash.hexString];
//    }
//    
//    DSLog(@"%@", debugInfo);
}

- (void)setAttributesFromSimplifiedMasternodeEntry:(DMasternodeEntry *)entry
                                     atBlockHeight:(uint32_t)blockHeight
                                           onChain:(DSChain *)chain
                                     onChainEntity:(DSChainEntity *)chainEntity {
    [self setAttributesFromSimplifiedMasternodeEntry:entry
                                       atBlockHeight:blockHeight
                              knownOperatorAddresses:nil
                                knownVotingAddresses:nil
                               platformNodeAddresses:nil
                                    localMasternodes:nil
                                             onChain:chain
                                       onChainEntity:chainEntity];
}

- (void)addAddressIfExist:(NSString *)address
                       addresses:(NSDictionary<NSString *, DSAddressEntity *> *_Nullable)addresses
                         onChain:(DSChain *)chain {
    DSAddressEntity *addressEntity = addresses ? [addresses objectForKey:address] : [DSAddressEntity findAddressMatching:address onChain:chain inContext:self.managedObjectContext];
    if (addressEntity)
        [self addAddressesObject:addressEntity];
}

- (void)setAttributesFromSimplifiedMasternodeEntry:(DMasternodeEntry *)entry
                                     atBlockHeight:(uint32_t)blockHeight
                            knownOperatorAddresses:(NSDictionary<NSString *, DSAddressEntity *> *)knownOperatorAddresses
                              knownVotingAddresses:(NSDictionary<NSString *, DSAddressEntity *> *)knownVotingAddresses
                             platformNodeAddresses:(NSDictionary<NSString *, DSAddressEntity *> *)platformNodeAddresses
                                  localMasternodes:(NSDictionary<NSData *, DSLocalMasternodeEntity *> *)localMasternodes
                                           onChain:(DSChain *)chain
                                     onChainEntity:(DSChainEntity *)chainEntity {
    NSParameterAssert(entry);
    NSData *providerRegistrationTransactionHash = NSDataFromPtr(entry->provider_registration_transaction_hash);
    self.providerRegistrationTransactionHash = providerRegistrationTransactionHash;
    self.confirmedHash = NSDataFromPtr(entry->confirmed_hash);
    if (!u_is_zero(entry->confirmed_hash))
        self.knownConfirmedAtHeight = blockHeight;
    
    self.ipv6Address = NSDataFromPtr(entry->socket_address->ip_address);
    self.address = dash_spv_masternode_processor_common_socket_address_SocketAddress_ipv4(entry->socket_address);
    self.port = entry->socket_address->port;
    self.keyIDVoting = NSDataFromPtr(entry->key_id_voting);
    self.operatorBLSPublicKey = NSDataFromPtr(entry->operator_public_key->data);
    self.operatorPublicKeyVersion = entry->operator_public_key->version;
    self.type = dash_spv_masternode_processor_models_masternode_entry_MasternodeEntry_type_uint(entry);
    self.platformNodeID = NSDataFromPtr(entry->platform_node_id);
    self.platformHTTPPort = entry->platform_http_port;
    self.isValid = entry->is_valid;
    self.simplifiedMasternodeEntryHash = NSDataFromPtr(entry->entry_hash);
    self.updateHeight = blockHeight;
//    if (entry->update_height != blockHeight)
//        DSLog(@"• setAttributesFromSimplifiedMasternodeEntry: list.height %u != entry.height %u", blockHeight, entry->update_height);
    
    
    if (!chainEntity) {
        self.chain = [chain chainEntityInContext:self.managedObjectContext];
    } else {
        self.chain = chainEntity;
    }

    DSLocalMasternodeEntity *localMasternode = localMasternodes
        ? [localMasternodes objectForKey:providerRegistrationTransactionHash]
        : [DSLocalMasternodeEntity anyObjectInContext:chainEntity.managedObjectContext matching:@"providerRegistrationTransaction.transactionHash.txHash == %@", providerRegistrationTransactionHash];
    self.localMasternode = localMasternode;
    NSString *operatorAddress = [DSKeyManager addressWithPublicKeyData:self.operatorBLSPublicKey forChain:chain];
    NSString *votingAddress = [DSKeyManager addressFromHash160:self.keyIDVoting.UInt160 forChain:chain];
    NSString *platformNodeAddress = [DSKeyManager addressFromHash160:self.platformNodeID.UInt160 forChain:chain];

    [self addAddressIfExist:operatorAddress addresses:knownOperatorAddresses onChain:chain];
    [self addAddressIfExist:votingAddress addresses:knownVotingAddresses onChain:chain];
    [self addAddressIfExist:platformNodeAddress addresses:platformNodeAddresses onChain:chain];
    
    
    
//    self.providerRegistrationTransactionHash = [NSData dataWithUInt256:simplifiedMasternodeEntry.providerRegistrationTransactionHash];
//    self.confirmedHash = [NSData dataWithUInt256:simplifiedMasternodeEntry.confirmedHash];
//    if (uint256_is_not_zero(simplifiedMasternodeEntry.confirmedHash)) {
//        self.knownConfirmedAtHeight = blockHeight;
//    }
//    self.ipv6Address = uint128_data(simplifiedMasternodeEntry.address);
//    self.address = CFSwapInt32BigToHost(simplifiedMasternodeEntry.address.u32[3]);
//    self.port = simplifiedMasternodeEntry.port;
//    self.keyIDVoting = [NSData dataWithUInt160:simplifiedMasternodeEntry.keyIDVoting];
//    self.operatorBLSPublicKey = [NSData dataWithUInt384:simplifiedMasternodeEntry.operatorPublicKey];
//    self.operatorPublicKeyVersion = simplifiedMasternodeEntry.operatorPublicKeyVersion;
//    self.type = simplifiedMasternodeEntry.type;
//    self.platformNodeID = [NSData dataWithUInt160:simplifiedMasternodeEntry.platformNodeID];
//    self.platformHTTPPort = simplifiedMasternodeEntry.platformHTTPPort;
//    self.isValid = simplifiedMasternodeEntry.isValid;
//    self.simplifiedMasternodeEntryHash = [NSData dataWithUInt256:simplifiedMasternodeEntry.simplifiedMasternodeEntryHash];
//    self.updateHeight = blockHeight;
//    
//    if (simplifiedMasternodeEntry.updateHeight != blockHeight) {
//        DSLog(@"• setAttributesFromSimplifiedMasternodeEntry: list.height %u != entry.height %u", blockHeight, simplifiedMasternodeEntry.updateHeight);
//    }
//    // TODO: make sure we're doing
////    NSAssert(simplifiedMasternodeEntry.updateHeight == blockHeight, ([NSString stringWithFormat:@"the block height (%i) for %@ should be the same as the entry update height (%i)", blockHeight, uint256_hex(simplifiedMasternodeEntry.providerRegistrationTransactionHash), simplifiedMasternodeEntry.updateHeight]));
//    if (!chainEntity) {
//        self.chain = [simplifiedMasternodeEntry.chain chainEntityInContext:self.managedObjectContext];
//    } else {
//        self.chain = chainEntity;
//    }
//    DSLocalMasternodeEntity *localMasternode = localMasternodes
//        ? [localMasternodes objectForKey:uint256_data(simplifiedMasternodeEntry.providerRegistrationTransactionHash)]
//        : [DSLocalMasternodeEntity anyObjectInContext:chainEntity.managedObjectContext matching:@"providerRegistrationTransaction.transactionHash.txHash == %@", uint256_data(simplifiedMasternodeEntry.providerRegistrationTransactionHash)];
//    self.localMasternode = localMasternode;
//    NSString *operatorAddress = [DSKeyManager addressWithPublicKeyData:self.operatorBLSPublicKey forChain:simplifiedMasternodeEntry.chain];
//    NSString *votingAddress = [DSKeyManager addressFromHash160:self.keyIDVoting.UInt160 forChain:simplifiedMasternodeEntry.chain];
//    NSString *platformNodeAddress = [DSKeyManager addressFromHash160:self.platformNodeID.UInt160 forChain:simplifiedMasternodeEntry.chain];
//    // TODO: check do we have to do the same for platform node addresses
//    DSAddressEntity *operatorAddressEntity = knownOperatorAddresses
//        ? [knownOperatorAddresses objectForKey:operatorAddress]
//        : [DSAddressEntity findAddressMatching:operatorAddress onChain:simplifiedMasternodeEntry.chain inContext:self.managedObjectContext];
//    if (operatorAddressEntity) {
//        [self addAddressesObject:operatorAddressEntity];
//    }
//    DSAddressEntity *votingAddressEntity = knownVotingAddresses
//        ? [knownVotingAddresses objectForKey:votingAddress]
//        : [DSAddressEntity findAddressMatching:votingAddress onChain:simplifiedMasternodeEntry.chain inContext:self.managedObjectContext];
//    if (votingAddressEntity) {
//        [self addAddressesObject:votingAddressEntity];
//    }
//    DSAddressEntity *platformNodeAddressEntity = platformNodeAddresses
//        ? [platformNodeAddresses objectForKey:platformNodeAddress]
//        : [DSAddressEntity findAddressMatching:platformNodeAddress onChain:simplifiedMasternodeEntry.chain inContext:self.managedObjectContext];
//    if (platformNodeAddressEntity) {
//        [self addAddressesObject:platformNodeAddressEntity];
//    }
}

+ (void)deleteHavingProviderTransactionHashes:(NSArray *)providerTransactionHashes
                                onChainEntity:(DSChainEntity *)chainEntity {
    NSArray *hashesToDelete = [self objectsInContext:chainEntity.managedObjectContext matching:@"(chain == %@) && (providerRegistrationTransactionHash IN %@)", chainEntity, providerTransactionHashes];
    for (DSSimplifiedMasternodeEntryEntity *simplifiedMasternodeEntryEntity in hashesToDelete) {
        DSLog(@"deleteHavingProviderTransactionHashes: %@", simplifiedMasternodeEntryEntity.providerRegistrationTransactionHash.hexString);
        [chainEntity.managedObjectContext deleteObject:simplifiedMasternodeEntryEntity];
    }
}

+ (void)deleteAllOnChainEntity:(DSChainEntity *)chainEntity {
    NSArray *hashesToDelete = [self objectsInContext:chainEntity.managedObjectContext matching:@"(chain == %@)", chainEntity];
    for (DSSimplifiedMasternodeEntryEntity *simplifiedMasternodeEntryEntity in hashesToDelete) {
        [chainEntity.managedObjectContext deleteObject:simplifiedMasternodeEntryEntity];
    }
}

+ (DSSimplifiedMasternodeEntryEntity *)simplifiedMasternodeEntryForProviderRegistrationTransactionHash:(NSData *)providerRegistrationTransactionHash
                                                                                         onChainEntity:(DSChainEntity *)chainEntity {
    return [self anyObjectInContext:chainEntity.managedObjectContext matching:@"(providerRegistrationTransactionHash == %@) && (chain == %@)", providerRegistrationTransactionHash, chainEntity];
}

+ (DSSimplifiedMasternodeEntryEntity *)simplifiedMasternodeEntryForHash:(NSData *)simplifiedMasternodeEntryHash
                                                          onChainEntity:(DSChainEntity *)chainEntity {
    return [self anyObjectInContext:chainEntity.managedObjectContext matching:@"(simplifiedMasternodeEntryHash == %@) && (chain == %@)", simplifiedMasternodeEntryHash, chainEntity];
}

- (NSDictionary<NSData *, id> *)blockDictionaryFromBlockHashDictionary:(NSDictionary<NSData *, id> *)blockHashDictionary {
    return [self blockDictionaryFromBlockHashDictionary:blockHashDictionary blockHeightLookup:nil];
}

- (NSDictionary<NSData *, id> *)blockDictionaryFromBlockHashDictionary:(NSDictionary<NSData *, id> *)blockHashDictionary
                                                     blockHeightLookup:(BlockHeightFinder)blockHeightLookup {
    NSMutableDictionary *rDictionary = [NSMutableDictionary dictionary];
    DSChain *chain = self.chain.chain;
    for (NSData *blockHash in blockHashDictionary) {
        UInt256 hash = *(UInt256 *)(blockHash.bytes);
        DSBlock *block = [chain blockForBlockHash:hash];
        if (block) {
            rDictionary[[NSData dataWithBlockHash:hash height:block.height]] = blockHashDictionary[blockHash];
        } else if (blockHeightLookup) {
            uint32_t blockHeight = blockHeightLookup(blockHash.UInt256);
            if (blockHeight && blockHeight != UINT32_MAX) {
                rDictionary[[NSData dataWithBlockHash:hash height:blockHeight]] = blockHashDictionary[blockHash];
            }
        }
    }
    return rDictionary;
}

- (NSDictionary<NSData *, id> *)blockHashDictionaryFromBlockDictionary:(NSDictionary<NSData *, id> *)blockHashDictionary {
    NSMutableDictionary *rDictionary = [NSMutableDictionary dictionary];
    for (NSData *blockInfo in blockHashDictionary) {
        UInt256 blockInfoHash = [blockInfo UInt256AtOffset:0];
        NSData *blockHash = uint256_data(blockInfoHash);
        if (blockHash) {
            rDictionary[blockHash] = blockHashDictionary[blockInfo];
        }
    }
    return rDictionary;
}

//- (DMasternodeEntry *)simplifiedMasternodeEntry {
//    return [self simplifiedMasternodeEntryWithBlockHeightLookup:nil];
//}

- (DMasternodeEntry *)simplifiedMasternodeEntryWithBlockHeightLookup:(BlockHeightFinder)blockHeightLookup {
    u256 *provider_registration_transaction_hash = u256_ctor(self.providerRegistrationTransactionHash);
    u256 *confirmed_hash = u256_ctor(self.confirmedHash);
    u128 *ip_address = u128_ctor_u(self.ipv6Address.UInt128);
    uint16_t port = self.port;
    u160 *key_id_voting = u160_ctor(self.keyIDVoting);
    u384 *operator_public_key_data = u384_ctor(self.operatorBLSPublicKey);
    uint16_t operator_public_key_version = self.operatorPublicKeyVersion;
    uint16_t mn_type = self.type;
    uint16_t platform_http_port = self.platformHTTPPort;
    u160 *platform_node_id = u160_ctor(self.platformNodeID);
    uint32_t update_height = self.updateHeight;
    u256 *entry_hash = u256_ctor(self.simplifiedMasternodeEntryHash);

    u256 *hash_confirmed_hash = dash_spv_masternode_processor_models_masternode_entry_MasternodeEntry_hash_confirmed_hash(confirmed_hash, provider_registration_transaction_hash);
    uintptr_t prev_entry_hashes_count = self.previousSimplifiedMasternodeEntryHashes.count;
    Arr_u8_68 **prev_entry_hashes_values = malloc(prev_entry_hashes_count * sizeof(Arr_u8_68 *));
    uintptr_t index = 0;
    for (NSData *key in self.previousSimplifiedMasternodeEntryHashes) {
        NSData *value = self.previousSimplifiedMasternodeEntryHashes[key];
        NSMutableData *blob = [key mutableCopy];
        uint32_t height = blockHeightLookup(key.UInt256);
        [blob appendUInt32:height];
        [blob appendUInt256:value.UInt256];
        //DSLog(@"prev_entry_hash: %@ --> %@ (%u) -> %@", self.providerRegistrationTransactionHash.hexString, value.hexString, height, value.hexString);

        prev_entry_hashes_values[index] = Arr_u8_68_ctor(blob.length, (uint8_t *) blob.bytes);
        index++;
    }

//    for (uintptr_t i = 0; i < index; i++) {
//        free(prev_entry_hashes_values[i]);
//    }
//    free(prev_entry_hashes_values);

    uintptr_t prev_operator_keys_count = self.previousOperatorBLSPublicKeys.count;
    Arr_u8_86 **prev_operator_keys_values = malloc(prev_operator_keys_count * sizeof(Arr_u8_86 *));
    index = 0;
    for (NSData *key in self.previousOperatorBLSPublicKeys) {
        NSData *value = self.previousOperatorBLSPublicKeys[key];
        NSMutableData *blob = [key mutableCopy];
        [blob appendUInt32:blockHeightLookup(key.UInt256)];
        [blob appendData:value];
        prev_operator_keys_values[index] = Arr_u8_86_ctor(blob.length, (uint8_t *) blob.bytes);
        index++;
    }
//    for (uintptr_t i = 0; i < index; i++) {
//        free(prev_operator_keys_values[i]);
//    }
//    free(prev_operator_keys_values);

    uintptr_t prev_validity_count = self.previousValidity.count;
    Arr_u8_37 **prev_validity_values = malloc(prev_validity_count * sizeof(Arr_u8_37 *));
    index = 0;
    for (NSData *key in self.previousValidity) {
        NSNumber *value = self.previousValidity[key];
        NSMutableData *blob = [key mutableCopy];
        [blob appendUInt32:blockHeightLookup(key.UInt256)];
        [blob appendUInt8:(uint8_t) value.boolValue];
        prev_validity_values[index] = Arr_u8_37_ctor(blob.length, (uint8_t *) blob.bytes);
        index++;
    }
//    for (uintptr_t i = 0; i < index; i++) {
//        free(prev_validity_values[i]);
//    }
//    free(prev_validity_values);

    Vec_u8_68 *prev_entry_hashes = Vec_u8_68_ctor(prev_entry_hashes_count, prev_entry_hashes_values);
    Vec_u8_86 *previous_operator_public_keys = Vec_u8_86_ctor(prev_operator_keys_count, prev_operator_keys_values);
    Vec_u8_37 *previous_validity = Vec_u8_37_ctor(prev_validity_count, prev_validity_values);
    DMasternodeEntry *entry = DMasternodeEntryFromEntity(self.version, provider_registration_transaction_hash, confirmed_hash, ip_address, port, key_id_voting, operator_public_key_data, operator_public_key_version, self.isValid, mn_type, platform_http_port, platform_node_id, update_height, hash_confirmed_hash, self.knownConfirmedAtHeight, entry_hash, prev_entry_hashes, previous_operator_public_keys, previous_validity);
    // TODO: free mem
    return entry;
}


- (NSString *)debugDescription {
    NSMutableString *str = [NSMutableString string];
    [str appendFormat:@"---------------------- \n"];
    [str appendFormat:@"pro_reg_tx_hash: %@ \n", self.providerRegistrationTransactionHash.hexString];
    [str appendFormat:@"confirmed_hash: %@ \n", self.confirmedHash.hexString];
    [str appendFormat:@"address: %@ \n", self.ipv6Address.hexString];
    [str appendFormat:@"port: %u \n", self.port];
    [str appendFormat:@"operator_public_key: %@ \n", self.operatorBLSPublicKey.hexString];
    [str appendFormat:@"operator_public_key_version: %u \n", self.operatorPublicKeyVersion];
    for (NSData *hash in self.previousOperatorBLSPublicKeys) {
        [str appendFormat:@"prev_operator_public_key [%@]: %@ \n", hash.hexString, ((NSData *) self.previousOperatorBLSPublicKeys[hash]).hexString];
    }
    [str appendFormat:@"key_id_voting: %@ \n", self.keyIDVoting.hexString];
    [str appendFormat:@"is_valid: %u \n", self.isValid];
    [str appendFormat:@"type: %u \n", self.type];
    [str appendFormat:@"platform_http_port: %u \n", self.platformHTTPPort];
    [str appendFormat:@"platform_node_id: %@ \n", self.platformNodeID.hexString];
    for (NSData *hash in self.previousValidity) {
        [str appendFormat:@"prev_validity [%@]: %u \n", hash.hexString, ((NSNumber *) self.previousValidity[hash]).boolValue];
    }
    [str appendFormat:@"known_confirmed_at_height: %u \n", self.knownConfirmedAtHeight];
    [str appendFormat:@"update_height: %u \n", self.updateHeight];
    [str appendFormat:@"entry_hash: %@ \n", self.simplifiedMasternodeEntryHash.hexString];
    for (NSData *hash in self.previousSimplifiedMasternodeEntryHashes) {
        [str appendFormat:@"prev_entry_hash [%@]: %@ \n", hash.hexString, ((NSData *) self.previousSimplifiedMasternodeEntryHashes[hash]).hexString];
    }
    [str appendFormat:@"---------------------- \n"];
    return [[super debugDescription] stringByAppendingString:str];
}


@end

