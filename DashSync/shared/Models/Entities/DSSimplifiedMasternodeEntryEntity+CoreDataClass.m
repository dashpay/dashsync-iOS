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
#import "DSKey.h"
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
        NSAssert(simplifiedMasternodeEntry.updateHeight == blockHeight, @"the block height should be the same as the entry update height");
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
            DSDSMNELog(@"changing operatorBLSPublicKey to %@", operatorPublicKeyData.hexString);
        }

        if (self.isValid != simplifiedMasternodeEntry.isValid) {
            self.isValid = simplifiedMasternodeEntry.isValid;
            DSDSMNELog(@"changing isValid to %@", simplifiedMasternodeEntry.isValid ? @"TRUE" : @"FALSE");
        }


        self.simplifiedMasternodeEntryHash = [NSData dataWithUInt256:simplifiedMasternodeEntry.simplifiedMasternodeEntryHash];
        [self mergePreviousFieldsUsingSimplifiedMasternodeEntrysPreviousFields:simplifiedMasternodeEntry atBlockHeight:blockHeight];

        DSLocalMasternodeEntity *localMasternode = nil;
        if (localMasternodes) {
            localMasternode = [localMasternodes objectForKey:uint256_data(simplifiedMasternodeEntry.providerRegistrationTransactionHash)];
        } else {
            localMasternode = [DSLocalMasternodeEntity anyObjectInContext:self.managedObjectContext matching:@"providerRegistrationTransaction.transactionHash.txHash == %@", uint256_data(simplifiedMasternodeEntry.providerRegistrationTransactionHash)];
        }

        self.localMasternode = localMasternode;

        NSString *operatorAddress = [DSKey addressWithPublicKeyData:self.operatorBLSPublicKey forChain:simplifiedMasternodeEntry.chain];
        NSString *votingAddress = [self.keyIDVoting addressFromHash160DataForChain:simplifiedMasternodeEntry.chain];

        DSAddressEntity *operatorAddressEntity = nil;

        if (knownOperatorAddresses) {
            operatorAddressEntity = [knownOperatorAddresses objectForKey:operatorAddress];
        } else {
            operatorAddressEntity = [DSAddressEntity findAddressMatching:operatorAddress onChain:simplifiedMasternodeEntry.chain inContext:self.managedObjectContext];
        }

        if (operatorAddressEntity) {
            [self addAddressesObject:operatorAddressEntity];
        }

        DSAddressEntity *votingAddressEntity = nil;

        if (knownVotingAddresses) {
            votingAddressEntity = [knownVotingAddresses objectForKey:operatorAddress];
        } else {
            votingAddressEntity = [DSAddressEntity findAddressMatching:votingAddress onChain:simplifiedMasternodeEntry.chain inContext:self.managedObjectContext];
        }

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
        NSDictionary *currentPreviousSimplifiedMasternodeEntryHashesDictionary = self.previousSimplifiedMasternodeEntryHashes;
        if (!currentPreviousSimplifiedMasternodeEntryHashesDictionary || currentPreviousSimplifiedMasternodeEntryHashesDictionary.count == 0) {
            self.previousSimplifiedMasternodeEntryHashes = oldPreviousSimplifiedMasternodeEntryHashesDictionary;
        } else {
            //we should merge the 2 dictionaries
            NSMutableDictionary *mergedDictionary = [currentPreviousSimplifiedMasternodeEntryHashesDictionary mutableCopy];
            [mergedDictionary addEntriesFromDictionary:oldPreviousSimplifiedMasternodeEntryHashesDictionary];
            self.previousSimplifiedMasternodeEntryHashes = mergedDictionary;
        }
    }

    //OperatorBLSPublicKeys
    NSDictionary *oldPreviousOperatorBLSPublicKeysDictionary = [self blockHashDictionaryFromBlockDictionary:simplifiedMasternodeEntry.previousOperatorPublicKeys];
    if (oldPreviousOperatorBLSPublicKeysDictionary && oldPreviousOperatorBLSPublicKeysDictionary.count) {
        NSDictionary *currentPreviousOperatorBLSPublicKeysDictionary = self.previousOperatorBLSPublicKeys;
        if (!currentPreviousOperatorBLSPublicKeysDictionary || currentPreviousOperatorBLSPublicKeysDictionary.count == 0) {
            self.previousOperatorBLSPublicKeys = oldPreviousOperatorBLSPublicKeysDictionary;
        } else {
            //we should merge the 2 dictionaries
            NSMutableDictionary *mergedDictionary = [currentPreviousOperatorBLSPublicKeysDictionary mutableCopy];
            [mergedDictionary addEntriesFromDictionary:oldPreviousOperatorBLSPublicKeysDictionary];
            self.previousOperatorBLSPublicKeys = mergedDictionary;
        }
    }

    //MasternodeValidity
    NSDictionary *oldPreviousValidityDictionary = [self blockHashDictionaryFromBlockDictionary:simplifiedMasternodeEntry.previousValidity];
    if (oldPreviousValidityDictionary && oldPreviousValidityDictionary.count) {
        NSDictionary *currentPreviousValidityDictionary = self.previousValidity;
        if (!currentPreviousValidityDictionary || currentPreviousValidityDictionary.count == 0) {
            self.previousValidity = oldPreviousValidityDictionary;
        } else {
            //we should merge the 2 dictionaries
            NSMutableDictionary *mergedDictionary = [currentPreviousValidityDictionary mutableCopy];
            [mergedDictionary addEntriesFromDictionary:oldPreviousValidityDictionary];
            self.previousValidity = mergedDictionary;
        }
    }

    if (uint256_is_not_zero(self.confirmedHash.UInt256) && uint256_is_not_zero(simplifiedMasternodeEntry.confirmedHash) && (self.knownConfirmedAtHeight > blockHeight)) {
        //we now know it was confirmed earlier so update to earlier
        self.knownConfirmedAtHeight = blockHeight;
    }
}

- (void)setAttributesFromSimplifiedMasternodeEntry:(DSSimplifiedMasternodeEntry *)simplifiedMasternodeEntry atBlockHeight:(uint32_t)blockHeight onChainEntity:(DSChainEntity *)chainEntity {
    [self setAttributesFromSimplifiedMasternodeEntry:simplifiedMasternodeEntry atBlockHeight:(uint32_t)blockHeight knownOperatorAddresses:nil knownVotingAddresses:nil localMasternodes:nil onChainEntity:chainEntity];
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
    self.isValid = simplifiedMasternodeEntry.isValid;
    self.simplifiedMasternodeEntryHash = [NSData dataWithUInt256:simplifiedMasternodeEntry.simplifiedMasternodeEntryHash];
    self.updateHeight = blockHeight;
    
    NSAssert(simplifiedMasternodeEntry.updateHeight == blockHeight, ([NSString stringWithFormat:@"the block height (%i) should be the same as the entry update height (%i)", blockHeight, simplifiedMasternodeEntry.updateHeight]));
    if (!chainEntity) {
        self.chain = [simplifiedMasternodeEntry.chain chainEntityInContext:self.managedObjectContext];
    } else {
        self.chain = chainEntity;
    }

    DSLocalMasternodeEntity *localMasternode = nil;
    if (localMasternodes) {
        localMasternode = [localMasternodes objectForKey:uint256_data(simplifiedMasternodeEntry.providerRegistrationTransactionHash)];
    } else {
        localMasternode = [DSLocalMasternodeEntity anyObjectInContext:chainEntity.managedObjectContext matching:@"providerRegistrationTransaction.transactionHash.txHash == %@", uint256_data(simplifiedMasternodeEntry.providerRegistrationTransactionHash)];
    }

    self.localMasternode = localMasternode;

    NSString *operatorAddress = [DSKey addressWithPublicKeyData:self.operatorBLSPublicKey forChain:simplifiedMasternodeEntry.chain];
    NSString *votingAddress = [self.keyIDVoting addressFromHash160DataForChain:simplifiedMasternodeEntry.chain];

    DSAddressEntity *operatorAddressEntity = nil;

    if (knownOperatorAddresses) {
        operatorAddressEntity = [knownOperatorAddresses objectForKey:operatorAddress];
    } else {
        operatorAddressEntity = [DSAddressEntity findAddressMatching:operatorAddress onChain:simplifiedMasternodeEntry.chain inContext:self.managedObjectContext];
    }

    if (operatorAddressEntity) {
        [self addAddressesObject:operatorAddressEntity];
    }

    DSAddressEntity *votingAddressEntity = nil;

    if (knownVotingAddresses) {
        votingAddressEntity = [knownVotingAddresses objectForKey:operatorAddress];
    } else {
        votingAddressEntity = [DSAddressEntity findAddressMatching:votingAddress onChain:simplifiedMasternodeEntry.chain inContext:self.managedObjectContext];
    }

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

- (NSDictionary<DSBlock *, id> *)blockDictionaryFromBlockHashDictionary:(NSDictionary<NSData *, id> *)blockHashDictionary {
    return [self blockDictionaryFromBlockHashDictionary:blockHashDictionary blockHeightLookup:nil];
}

- (NSDictionary<DSBlock *, id> *)blockDictionaryFromBlockHashDictionary:(NSDictionary<NSData *, id> *)blockHashDictionary blockHeightLookup:(BlockHeightFinder)blockHeightLookup {
    NSMutableDictionary *rDictionary = [NSMutableDictionary dictionary];
    DSChain *chain = self.chain.chain;
    for (NSData *blockHash in blockHashDictionary) {
        DSBlock *block = [chain blockForBlockHash:blockHash.UInt256];
        if (block) {
            rDictionary[block] = blockHashDictionary[blockHash];
        } else if (blockHeightLookup) {
            uint32_t blockHeight = blockHeightLookup(blockHash.UInt256);
            if (blockHeight && blockHeight != UINT32_MAX) {
                DSBlock *block = [[DSBlock alloc] initWithBlockHash:blockHash.UInt256 height:blockHeight onChain:chain];
                rDictionary[block] = blockHashDictionary[blockHash];
            }
        }
    }
    return rDictionary;
}

- (NSDictionary<NSData *, id> *)blockHashDictionaryFromBlockDictionary:(NSDictionary<DSBlock *, id> *)blockHashDictionary {
    NSMutableDictionary *rDictionary = [NSMutableDictionary dictionary];
    for (DSBlock *block in blockHashDictionary) {
        NSData *blockHash = uint256_data(block.blockHash);
        if (blockHash) {
            rDictionary[blockHash] = blockHashDictionary[block];
        }
    }
    return rDictionary;
}

- (DSSimplifiedMasternodeEntry *)simplifiedMasternodeEntry {
    return [self simplifiedMasternodeEntryWithBlockHeightLookup:nil];
}

- (DSSimplifiedMasternodeEntry *)simplifiedMasternodeEntryWithBlockHeightLookup:(BlockHeightFinder)blockHeightLookup {
    DSSimplifiedMasternodeEntry *simplifiedMasternodeEntry = [DSSimplifiedMasternodeEntry simplifiedMasternodeEntryWithProviderRegistrationTransactionHash:[self.providerRegistrationTransactionHash UInt256] confirmedHash:[self.confirmedHash UInt256] address:self.ipv6Address.UInt128 port:self.port operatorBLSPublicKey:[self.operatorBLSPublicKey UInt384] previousOperatorBLSPublicKeys:[self blockDictionaryFromBlockHashDictionary:(NSDictionary<NSData *, NSData *> *)self.previousOperatorBLSPublicKeys blockHeightLookup:blockHeightLookup] keyIDVoting:[self.keyIDVoting UInt160] isValid:self.isValid previousValidity:[self blockDictionaryFromBlockHashDictionary:(NSDictionary<NSData *, NSData *> *)self.previousValidity blockHeightLookup:blockHeightLookup] knownConfirmedAtHeight:self.knownConfirmedAtHeight updateHeight:self.updateHeight simplifiedMasternodeEntryHash:[self.simplifiedMasternodeEntryHash UInt256] previousSimplifiedMasternodeEntryHashes:[self blockDictionaryFromBlockHashDictionary:(NSDictionary<NSData *, NSData *> *)self.previousSimplifiedMasternodeEntryHashes blockHeightLookup:blockHeightLookup] onChain:self.chain.chain];
    return simplifiedMasternodeEntry;
}

@end
