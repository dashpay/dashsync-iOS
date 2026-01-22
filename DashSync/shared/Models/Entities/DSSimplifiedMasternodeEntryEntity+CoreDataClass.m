//
//  DSSimplifiedMasternodeEntryEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 7/19/18.
//
//

#import "DSAddressEntity+CoreDataClass.h"
#import "DSChain+Protected.h"
#import "DSChainEntity+CoreDataProperties.h"
#import "NSDictionary+Dash.h"
#import "DSKeyManager.h"
#import "DSLocalMasternodeEntity+CoreDataClass.h"
#import "DSMerkleBlock.h"
#import "DSSimplifiedMasternodeEntry.h"
#import "DSSimplifiedMasternodeEntryEntity+CoreDataClass.h"
#import "NSData+Dash.h"
#import "NSManagedObject+Sugar.h"
#include <arpa/inet.h>

#define LOG_SMNE_CHANGES 0

#if LOG_SMNE_CHANGES
#define DSDSMNELog(s, ...) DSLog(s, ##__VA_ARGS__)
#else
#define DSDSMNELog(s, ...)
#endif

//DSLog(s, ##__VA_ARGS__)

@implementation DSSimplifiedMasternodeEntryEntity

- (void)updateAttributesFromSimplifiedMasternodeEntry:(DSSimplifiedMasternodeEntry *)simplifiedMasternodeEntry atBlockHeight:(uint32_t)blockHeight {
    [self updateAttributesFromSimplifiedMasternodeEntry:simplifiedMasternodeEntry atBlockHeight:(uint32_t)blockHeight knownOperatorAddresses:nil knownVotingAddresses:nil localMasternodes:nil];
}

- (void)updateAttributesFromSimplifiedMasternodeEntry:(DSSimplifiedMasternodeEntry *)simplifiedMasternodeEntry atBlockHeight:(uint32_t)blockHeight knownOperatorAddresses:(NSDictionary<NSString *, DSAddressEntity *> *)knownOperatorAddresses knownVotingAddresses:(NSDictionary<NSString *, DSAddressEntity *> *)knownVotingAddresses localMasternodes:(NSDictionary<NSData *, DSLocalMasternodeEntity *> *)localMasternodes {
    if (self.updateHeight < blockHeight) {
        //NSAssert(simplifiedMasternodeEntry.updateHeight == blockHeight, @"the block height should be the same as the entry update height");
        self.updateHeight = blockHeight;
        //we should only update if the data received is the most recent
        if (!uint128_eq(self.ipv6Address.UInt128, simplifiedMasternodeEntry.address)) {
            self.ipv6Address = uint128_data(simplifiedMasternodeEntry.address);
            uint32_t address32 = CFSwapInt32BigToHost(simplifiedMasternodeEntry.address.u32[3]);
            if (self.address != address32) {
                self.address = address32;
#if LOG_SMNE_CHANGES
                char s[INET6_ADDRSTRLEN];
#endif
                DSDSMNELog(@"changing address to %@", @(inet_ntop(AF_INET, &address32, s, sizeof(s))));
            }
        }
        NSData *confirmedHashData = uint256_data(simplifiedMasternodeEntry.confirmedHash);
        if (![self.confirmedHash isEqualToData:confirmedHashData]) {
            NSAssert(self.confirmedHash == nil || uint256_is_zero(self.confirmedHash.UInt256), @"If this changes the previous should be empty");
            //this should only happen once at confirmation
            self.confirmedHash = confirmedHashData;
            self.knownConfirmedAtHeight = blockHeight;
            DSDSMNELog(@"changing confirmedHashData to %@", confirmedHashData.hexString);
        }
        if (self.port != simplifiedMasternodeEntry.port) {
            self.port = simplifiedMasternodeEntry.port;
            DSDSMNELog(@"changing port to %u", simplifiedMasternodeEntry.port);
        }
        NSData *keyIDVotingData = [NSData dataWithUInt160:simplifiedMasternodeEntry.keyIDVoting];
        if (![self.keyIDVoting isEqualToData:keyIDVotingData]) {
            self.keyIDVoting = keyIDVotingData;
            DSDSMNELog(@"changing keyIDVotingData to %@", keyIDVotingData.hexString);
        }
        NSData *operatorPublicKeyData = [NSData dataWithUInt384:simplifiedMasternodeEntry.operatorPublicKey];
        if (![self.operatorBLSPublicKey isEqualToData:operatorPublicKeyData]) {
            self.operatorBLSPublicKey = operatorPublicKeyData;
            self.operatorPublicKeyVersion = simplifiedMasternodeEntry.operatorPublicKeyVersion;
            DSDSMNELog(@"changing operatorBLSPublicKey to %@", operatorPublicKeyData.hexString);
        }
        
        if (self.type != simplifiedMasternodeEntry.type) {
            self.type = simplifiedMasternodeEntry.type;
            DSDSMNELog(@"changing type to %d", simplifiedMasternodeEntry.type);
        }
        NSData *platformNodeIDData = uint160_data(simplifiedMasternodeEntry.platformNodeID);
        if (![self.platformNodeID isEqualToData:platformNodeIDData]) {
            self.platformNodeID = platformNodeIDData;
            DSDSMNELog(@"changing platformNodeID to %d", platformNodeIDData.hexString);
        }
        if (self.platformHTTPPort != simplifiedMasternodeEntry.platformHTTPPort) {
            self.platformHTTPPort = simplifiedMasternodeEntry.platformHTTPPort;
            DSDSMNELog(@"changing platformHTTPPort to %d", simplifiedMasternodeEntry.platformHTTPPort);
        }

        if (self.isValid != simplifiedMasternodeEntry.isValid) {
            self.isValid = simplifiedMasternodeEntry.isValid;
            DSDSMNELog(@"changing isValid to %@", simplifiedMasternodeEntry.isValid ? @"TRUE" : @"FALSE");
        }
        self.simplifiedMasternodeEntryHash = [NSData dataWithUInt256:simplifiedMasternodeEntry.simplifiedMasternodeEntryHash];
        [self mergePreviousFieldsUsingSimplifiedMasternodeEntrysPreviousFields:simplifiedMasternodeEntry atBlockHeight:blockHeight];
        DSLocalMasternodeEntity *localMasternode = localMasternodes
            ? [localMasternodes objectForKey:uint256_data(simplifiedMasternodeEntry.providerRegistrationTransactionHash)]
            : [DSLocalMasternodeEntity anyObjectInContext:self.managedObjectContext matching:@"providerRegistrationTransaction.transactionHash.txHash == %@", uint256_data(simplifiedMasternodeEntry.providerRegistrationTransactionHash)];
        self.localMasternode = localMasternode;
        NSString *operatorAddress = [DSKeyManager addressWithPublicKeyData:self.operatorBLSPublicKey forChain:simplifiedMasternodeEntry.chain];
        NSString *votingAddress = [DSKeyManager addressFromHash160:self.keyIDVoting.UInt160 forChain:simplifiedMasternodeEntry.chain];
        DSAddressEntity *operatorAddressEntity = knownOperatorAddresses
            ? [knownOperatorAddresses objectForKey:operatorAddress]
            : [DSAddressEntity findAddressMatching:operatorAddress onChain:simplifiedMasternodeEntry.chain inContext:self.managedObjectContext];
        if (operatorAddressEntity) {
            [self addAddressesObject:operatorAddressEntity];
        }
        DSAddressEntity *votingAddressEntity = knownVotingAddresses
            ? [knownVotingAddresses objectForKey:operatorAddress]
            : [DSAddressEntity findAddressMatching:votingAddress onChain:simplifiedMasternodeEntry.chain inContext:self.managedObjectContext];
        if (votingAddressEntity) {
            [self addAddressesObject:votingAddressEntity];
        }
    } else if (blockHeight < self.updateHeight) {
        [self mergePreviousFieldsUsingSimplifiedMasternodeEntrysPreviousFields:simplifiedMasternodeEntry atBlockHeight:blockHeight];
    }
}

- (void)mergePreviousFieldsUsingSimplifiedMasternodeEntrysPreviousFields:(DSSimplifiedMasternodeEntry *)simplifiedMasternodeEntry atBlockHeight:(uint32_t)blockHeight {
    //we should not update current values but we should merge some fields
    //currentPrevious means the current set of previous values
    //oldPrevious means the old set of previous values

    //SimplifiedMasternodeEntryHashes
    NSDictionary *oldPreviousSimplifiedMasternodeEntryHashesDictionary = [self blockHashDictionaryFromBlockDictionary:simplifiedMasternodeEntry.previousSimplifiedMasternodeEntryHashes];
    if (oldPreviousSimplifiedMasternodeEntryHashesDictionary && oldPreviousSimplifiedMasternodeEntryHashesDictionary.count) {
        self.previousSimplifiedMasternodeEntryHashes = [NSDictionary mergeDictionary:self.previousSimplifiedMasternodeEntryHashes withDictionary:oldPreviousSimplifiedMasternodeEntryHashesDictionary];
    }

    //OperatorBLSPublicKeys
    NSDictionary *oldPreviousOperatorBLSPublicKeysDictionary = [self blockHashDictionaryFromBlockDictionary:simplifiedMasternodeEntry.previousOperatorPublicKeys];
    if (oldPreviousOperatorBLSPublicKeysDictionary && oldPreviousOperatorBLSPublicKeysDictionary.count) {
        self.previousOperatorBLSPublicKeys = [NSDictionary mergeDictionary:self.previousOperatorBLSPublicKeys withDictionary:oldPreviousOperatorBLSPublicKeysDictionary];
    }

    //MasternodeValidity
    NSDictionary *oldPreviousValidityDictionary = [self blockHashDictionaryFromBlockDictionary:simplifiedMasternodeEntry.previousValidity];
    if (oldPreviousValidityDictionary && oldPreviousValidityDictionary.count) {
        self.previousValidity = [NSDictionary mergeDictionary:self.previousValidity withDictionary:oldPreviousValidityDictionary];
    }

    if (uint256_is_not_zero(self.confirmedHash.UInt256) && uint256_is_not_zero(simplifiedMasternodeEntry.confirmedHash) && (self.knownConfirmedAtHeight > blockHeight)) {
        //we now know it was confirmed earlier so update to earlier
        self.knownConfirmedAtHeight = blockHeight;
    }
}

- (void)setAttributesFromSimplifiedMasternodeEntry:(DSSimplifiedMasternodeEntry *)simplifiedMasternodeEntry atBlockHeight:(uint32_t)blockHeight onChainEntity:(DSChainEntity *)chainEntity {
    [self setAttributesFromSimplifiedMasternodeEntry:simplifiedMasternodeEntry atBlockHeight:blockHeight knownOperatorAddresses:nil knownVotingAddresses:nil localMasternodes:nil onChainEntity:chainEntity];
}

- (void)setAttributesFromSimplifiedMasternodeEntry:(DSSimplifiedMasternodeEntry *)simplifiedMasternodeEntry atBlockHeight:(uint32_t)blockHeight knownOperatorAddresses:(NSDictionary<NSString *, DSAddressEntity *> *)knownOperatorAddresses knownVotingAddresses:(NSDictionary<NSString *, DSAddressEntity *> *)knownVotingAddresses localMasternodes:(NSDictionary<NSData *, DSLocalMasternodeEntity *> *)localMasternodes onChainEntity:(DSChainEntity *)chainEntity {
    NSParameterAssert(simplifiedMasternodeEntry);
    self.providerRegistrationTransactionHash = [NSData dataWithUInt256:simplifiedMasternodeEntry.providerRegistrationTransactionHash];
    self.confirmedHash = [NSData dataWithUInt256:simplifiedMasternodeEntry.confirmedHash];
    if (uint256_is_not_zero(simplifiedMasternodeEntry.confirmedHash)) {
        self.knownConfirmedAtHeight = blockHeight;
    }
    self.ipv6Address = uint128_data(simplifiedMasternodeEntry.address);
    self.address = CFSwapInt32BigToHost(simplifiedMasternodeEntry.address.u32[3]);
    self.port = simplifiedMasternodeEntry.port;
    self.keyIDVoting = [NSData dataWithUInt160:simplifiedMasternodeEntry.keyIDVoting];
    self.operatorBLSPublicKey = [NSData dataWithUInt384:simplifiedMasternodeEntry.operatorPublicKey];
    self.operatorPublicKeyVersion = simplifiedMasternodeEntry.operatorPublicKeyVersion;
    self.type = simplifiedMasternodeEntry.type;
    self.platformNodeID = [NSData dataWithUInt160:simplifiedMasternodeEntry.platformNodeID];
    self.platformHTTPPort = simplifiedMasternodeEntry.platformHTTPPort;
    self.isValid = simplifiedMasternodeEntry.isValid;
    self.simplifiedMasternodeEntryHash = [NSData dataWithUInt256:simplifiedMasternodeEntry.simplifiedMasternodeEntryHash];
    self.updateHeight = blockHeight;
    
    // TODO: make sure we're doing
//    NSAssert(simplifiedMasternodeEntry.updateHeight == blockHeight, ([NSString stringWithFormat:@"the block height (%i) for %@ should be the same as the entry update height (%i)", blockHeight, uint256_hex(simplifiedMasternodeEntry.providerRegistrationTransactionHash), simplifiedMasternodeEntry.updateHeight]));
    if (!chainEntity) {
        self.chain = [simplifiedMasternodeEntry.chain chainEntityInContext:self.managedObjectContext];
    } else {
        self.chain = chainEntity;
    }
    DSLocalMasternodeEntity *localMasternode = localMasternodes
        ? [localMasternodes objectForKey:uint256_data(simplifiedMasternodeEntry.providerRegistrationTransactionHash)]
        : [DSLocalMasternodeEntity anyObjectInContext:chainEntity.managedObjectContext matching:@"providerRegistrationTransaction.transactionHash.txHash == %@", uint256_data(simplifiedMasternodeEntry.providerRegistrationTransactionHash)];
    self.localMasternode = localMasternode;
    NSString *operatorAddress = [DSKeyManager addressWithPublicKeyData:self.operatorBLSPublicKey forChain:simplifiedMasternodeEntry.chain];
    NSString *votingAddress = [DSKeyManager addressFromHash160:self.keyIDVoting.UInt160 forChain:simplifiedMasternodeEntry.chain];
    // TODO: check do we have to do the same for platform node addresses
    DSAddressEntity *operatorAddressEntity = knownOperatorAddresses
        ? [knownOperatorAddresses objectForKey:operatorAddress]
        : [DSAddressEntity findAddressMatching:operatorAddress onChain:simplifiedMasternodeEntry.chain inContext:self.managedObjectContext];
    if (operatorAddressEntity) {
        [self addAddressesObject:operatorAddressEntity];
    }
    DSAddressEntity *votingAddressEntity = knownVotingAddresses
        ? [knownVotingAddresses objectForKey:votingAddress]
        : [DSAddressEntity findAddressMatching:votingAddress onChain:simplifiedMasternodeEntry.chain inContext:self.managedObjectContext];
    if (votingAddressEntity) {
        [self addAddressesObject:votingAddressEntity];
    }
}

+ (void)deleteHavingProviderTransactionHashes:(NSArray *)providerTransactionHashes onChainEntity:(DSChainEntity *)chainEntity {
    NSArray *hashesToDelete = [self objectsInContext:chainEntity.managedObjectContext matching:@"(chain == %@) && (providerRegistrationTransactionHash IN %@)", chainEntity, providerTransactionHashes];
    for (DSSimplifiedMasternodeEntryEntity *simplifiedMasternodeEntryEntity in hashesToDelete) {
        [chainEntity.managedObjectContext deleteObject:simplifiedMasternodeEntryEntity];
    }
}

+ (void)deleteAllOnChainEntity:(DSChainEntity *)chainEntity {
    NSArray *hashesToDelete = [self objectsInContext:chainEntity.managedObjectContext matching:@"(chain == %@)", chainEntity];
    for (DSSimplifiedMasternodeEntryEntity *simplifiedMasternodeEntryEntity in hashesToDelete) {
        [chainEntity.managedObjectContext deleteObject:simplifiedMasternodeEntryEntity];
    }
}

+ (DSSimplifiedMasternodeEntryEntity *)simplifiedMasternodeEntryForProviderRegistrationTransactionHash:(NSData *)providerRegistrationTransactionHash onChainEntity:(DSChainEntity *)chainEntity {
    return [self anyObjectInContext:chainEntity.managedObjectContext matching:@"(providerRegistrationTransactionHash == %@) && (chain == %@)", providerRegistrationTransactionHash, chainEntity];
}

+ (DSSimplifiedMasternodeEntryEntity *)simplifiedMasternodeEntryForHash:(NSData *)simplifiedMasternodeEntryHash onChainEntity:(DSChainEntity *)chainEntity {
    return [self anyObjectInContext:chainEntity.managedObjectContext matching:@"(simplifiedMasternodeEntryHash == %@) && (chain == %@)", simplifiedMasternodeEntryHash, chainEntity];
}

- (NSDictionary<NSData *, id> *)blockDictionaryFromBlockHashDictionary:(NSDictionary<NSData *, id> *)blockHashDictionary {
    return [self blockDictionaryFromBlockHashDictionary:blockHashDictionary blockHeightLookup:nil];
}

- (NSDictionary<NSData *, id> *)blockDictionaryFromBlockHashDictionary:(NSDictionary<NSData *, id> *)blockHashDictionary blockHeightLookup:(BlockHeightFinder)blockHeightLookup {
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

- (DSSimplifiedMasternodeEntry *)simplifiedMasternodeEntry {
    return [self simplifiedMasternodeEntryWithBlockHeightLookup:nil];
}

- (DSSimplifiedMasternodeEntry *)simplifiedMasternodeEntryWithBlockHeightLookup:(BlockHeightFinder)blockHeightLookup {
    DSSimplifiedMasternodeEntry *simplifiedMasternodeEntry = [DSSimplifiedMasternodeEntry simplifiedMasternodeEntryWithProviderRegistrationTransactionHash:[self.providerRegistrationTransactionHash UInt256] confirmedHash:[self.confirmedHash UInt256] address:self.ipv6Address.UInt128 port:self.port operatorBLSPublicKey:[self.operatorBLSPublicKey UInt384] operatorPublicKeyVersion:self.operatorPublicKeyVersion previousOperatorBLSPublicKeys:[self blockDictionaryFromBlockHashDictionary:self.previousOperatorBLSPublicKeys blockHeightLookup:blockHeightLookup] keyIDVoting:[self.keyIDVoting UInt160] isValid:self.isValid type:self.type platformHTTPPort:self.platformHTTPPort platformNodeID:[self.platformNodeID UInt160] previousValidity:[self blockDictionaryFromBlockHashDictionary:self.previousValidity blockHeightLookup:blockHeightLookup] knownConfirmedAtHeight:self.knownConfirmedAtHeight updateHeight:self.updateHeight simplifiedMasternodeEntryHash:[self.simplifiedMasternodeEntryHash UInt256] previousSimplifiedMasternodeEntryHashes:[self blockDictionaryFromBlockHashDictionary:self.previousSimplifiedMasternodeEntryHashes blockHeightLookup:blockHeightLookup] onChain:self.chain.chain];
    return simplifiedMasternodeEntry;
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
