//
//  DSSimplifiedMasternodeEntryEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 7/19/18.
//
//

#import "DSAddressEntity+CoreDataClass.h"
#import "DSChain.h"
#import "DSChainEntity+CoreDataProperties.h"
#import "DSKey.h"
#import "DSLocalMasternodeEntity+CoreDataClass.h"
#import "DSMerkleBlock.h"
#import "DSSimplifiedMasternodeEntry.h"
#import "DSSimplifiedMasternodeEntryEntity+CoreDataClass.h"
#import "NSData+Bitcoin.h"
#import "NSManagedObject+Sugar.h"
#include <arpa/inet.h>

#define LOG_SMNE_CHANGES 0

#if LOG_SMNE_CHANGES
#define DSDSMNELog(s, ...) DSDLog(s, ##__VA_ARGS__)
#else
#define DSDSMNELog(s, ...)
#endif

//DSDLog(s, ##__VA_ARGS__)

@implementation DSSimplifiedMasternodeEntryEntity

- (void)updateAttributesFromSimplifiedMasternodeEntry:(DSSimplifiedMasternodeEntry *)simplifiedMasternodeEntry {
    [self updateAttributesFromSimplifiedMasternodeEntry:simplifiedMasternodeEntry knownOperatorAddresses:nil knownVotingAddresses:nil localMasternodes:nil];
}

- (void)updateAttributesFromSimplifiedMasternodeEntry:(DSSimplifiedMasternodeEntry *)simplifiedMasternodeEntry knownOperatorAddresses:(NSDictionary<NSString *, DSAddressEntity *> *)knownOperatorAddresses knownVotingAddresses:(NSDictionary<NSString *, DSAddressEntity *> *)knownVotingAddresses localMasternodes:(NSDictionary<NSData *, DSLocalMasternodeEntity *> *)localMasternodes {

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
        self.confirmedHash = confirmedHashData;
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
    self.previousSimplifiedMasternodeEntryHashes = [self blockHashDictionaryFromMerkleBlockDictionary:simplifiedMasternodeEntry.previousSimplifiedMasternodeEntryHashes];
    self.previousOperatorBLSPublicKeys = [self blockHashDictionaryFromMerkleBlockDictionary:simplifiedMasternodeEntry.previousOperatorPublicKeys];
    self.previousValidity = [self blockHashDictionaryFromMerkleBlockDictionary:simplifiedMasternodeEntry.previousValidity];

    DSLocalMasternodeEntity *localMasternode = nil;
    if (localMasternodes) {
        localMasternode = [localMasternodes objectForKey:uint256_data(simplifiedMasternodeEntry.providerRegistrationTransactionHash)];
    }
    else {
        localMasternode = [DSLocalMasternodeEntity anyObjectMatching:@"providerRegistrationTransaction.transactionHash.txHash == %@", uint256_data(simplifiedMasternodeEntry.providerRegistrationTransactionHash)];
    }

    self.localMasternode = localMasternode;

    NSString *operatorAddress = [DSKey addressWithPublicKeyData:self.operatorBLSPublicKey forChain:simplifiedMasternodeEntry.chain];
    NSString *votingAddress = [self.keyIDVoting addressFromHash160DataForChain:simplifiedMasternodeEntry.chain];

    DSAddressEntity *operatorAddressEntity = nil;

    if (knownOperatorAddresses) {
        operatorAddressEntity = [knownOperatorAddresses objectForKey:operatorAddress];
    }
    else {
        operatorAddressEntity = [DSAddressEntity findAddressMatching:operatorAddress onChain:simplifiedMasternodeEntry.chain];
    }

    if (operatorAddressEntity) {
        [self addAddressesObject:operatorAddressEntity];
    }

    DSAddressEntity *votingAddressEntity = nil;

    if (knownVotingAddresses) {
        votingAddressEntity = [knownVotingAddresses objectForKey:operatorAddress];
    }
    else {
        votingAddressEntity = [DSAddressEntity findAddressMatching:votingAddress onChain:simplifiedMasternodeEntry.chain];
    }

    if (votingAddressEntity) {
        [self addAddressesObject:votingAddressEntity];
    }
}

- (void)setAttributesFromSimplifiedMasternodeEntry:(DSSimplifiedMasternodeEntry *)simplifiedMasternodeEntry onChain:(DSChainEntity *)chainEntity {
    [self setAttributesFromSimplifiedMasternodeEntry:simplifiedMasternodeEntry knownOperatorAddresses:nil knownVotingAddresses:nil localMasternodes:nil onChain:chainEntity];
}

- (void)setAttributesFromSimplifiedMasternodeEntry:(DSSimplifiedMasternodeEntry *)simplifiedMasternodeEntry knownOperatorAddresses:(NSDictionary<NSString *, DSAddressEntity *> *)knownOperatorAddresses knownVotingAddresses:(NSDictionary<NSString *, DSAddressEntity *> *)knownVotingAddresses localMasternodes:(NSDictionary<NSData *, DSLocalMasternodeEntity *> *)localMasternodes onChain:(DSChainEntity *)chainEntity {
    self.providerRegistrationTransactionHash = [NSData dataWithUInt256:simplifiedMasternodeEntry.providerRegistrationTransactionHash];
    self.confirmedHash = [NSData dataWithUInt256:simplifiedMasternodeEntry.confirmedHash];
    self.ipv6Address = uint128_data(simplifiedMasternodeEntry.address);
    self.address = CFSwapInt32BigToHost(simplifiedMasternodeEntry.address.u32[3]);
    self.port = simplifiedMasternodeEntry.port;
    self.keyIDVoting = [NSData dataWithUInt160:simplifiedMasternodeEntry.keyIDVoting];
    self.operatorBLSPublicKey = [NSData dataWithUInt384:simplifiedMasternodeEntry.operatorPublicKey];
    self.isValid = simplifiedMasternodeEntry.isValid;
    self.simplifiedMasternodeEntryHash = [NSData dataWithUInt256:simplifiedMasternodeEntry.simplifiedMasternodeEntryHash];
    if (!chainEntity) {
        self.chain = simplifiedMasternodeEntry.chain.chainEntity;
    }
    else {
        self.chain = chainEntity;
    }


    DSLocalMasternodeEntity *localMasternode = nil;
    if (localMasternodes) {
        localMasternode = [localMasternodes objectForKey:uint256_data(simplifiedMasternodeEntry.providerRegistrationTransactionHash)];
    }
    else {
        localMasternode = [DSLocalMasternodeEntity anyObjectMatching:@"providerRegistrationTransaction.transactionHash.txHash == %@", uint256_data(simplifiedMasternodeEntry.providerRegistrationTransactionHash)];
    }

    self.localMasternode = localMasternode;

    NSString *operatorAddress = [DSKey addressWithPublicKeyData:self.operatorBLSPublicKey forChain:simplifiedMasternodeEntry.chain];
    NSString *votingAddress = [self.keyIDVoting addressFromHash160DataForChain:simplifiedMasternodeEntry.chain];

    DSAddressEntity *operatorAddressEntity = nil;

    if (knownOperatorAddresses) {
        operatorAddressEntity = [knownOperatorAddresses objectForKey:operatorAddress];
    }
    else {
        operatorAddressEntity = [DSAddressEntity findAddressMatching:operatorAddress onChain:simplifiedMasternodeEntry.chain];
    }

    if (operatorAddressEntity) {
        [self addAddressesObject:operatorAddressEntity];
    }

    DSAddressEntity *votingAddressEntity = nil;

    if (knownVotingAddresses) {
        votingAddressEntity = [knownVotingAddresses objectForKey:operatorAddress];
    }
    else {
        votingAddressEntity = [DSAddressEntity findAddressMatching:votingAddress onChain:simplifiedMasternodeEntry.chain];
    }

    if (votingAddressEntity) {
        [self addAddressesObject:votingAddressEntity];
    }
}

+ (void)deleteHavingProviderTransactionHashes:(NSArray *)providerTransactionHashes onChain:(DSChainEntity *)chainEntity {
    NSArray *hashesToDelete = [self objectsMatching:@"(chain == %@) && (providerRegistrationTransactionHash IN %@)", chainEntity, providerTransactionHashes];
    for (DSSimplifiedMasternodeEntryEntity *simplifiedMasternodeEntryEntity in hashesToDelete) {
        [chainEntity.managedObjectContext deleteObject:simplifiedMasternodeEntryEntity];
    }
}

+ (void)deleteAllOnChain:(DSChainEntity *)chainEntity {
    NSArray *hashesToDelete = [self objectsMatching:@"(chain == %@)", chainEntity];
    for (DSSimplifiedMasternodeEntryEntity *simplifiedMasternodeEntryEntity in hashesToDelete) {
        [chainEntity.managedObjectContext deleteObject:simplifiedMasternodeEntryEntity];
    }
}

+ (DSSimplifiedMasternodeEntryEntity *)simplifiedMasternodeEntryForProviderRegistrationTransactionHash:(NSData *)providerRegistrationTransactionHash onChain:(DSChainEntity *)chainEntity {
    return [self anyObjectMatching:@"(providerRegistrationTransactionHash == %@) && (chain == %@)", providerRegistrationTransactionHash, chainEntity];
}

+ (DSSimplifiedMasternodeEntryEntity *)simplifiedMasternodeEntryForHash:(NSData *)simplifiedMasternodeEntryHash onChain:(DSChainEntity *)chainEntity {
    return [self anyObjectMatching:@"(simplifiedMasternodeEntryHash == %@) && (chain == %@)", simplifiedMasternodeEntryHash, chainEntity];
}

- (NSDictionary<DSMerkleBlock *, id> *)merkleBlockDictionaryFromBlockHashDictionary:(NSDictionary<NSData *, id> *)blockHashDictionary {
    NSMutableDictionary *rDictionary = [NSMutableDictionary dictionary];
    DSChain *chain = self.chain.chain;
    for (NSData *blockHash in blockHashDictionary) {
        DSMerkleBlock *block = [chain blockForBlockHash:blockHash.UInt256];
        if (block) {
            [rDictionary setObject:blockHashDictionary[blockHash] forKey:block];
        }
    }
    return rDictionary;
}

- (NSDictionary<NSData *, id> *)blockHashDictionaryFromMerkleBlockDictionary:(NSDictionary<DSMerkleBlock *, id> *)blockHashDictionary {
    NSMutableDictionary *rDictionary = [NSMutableDictionary dictionary];
    for (DSMerkleBlock *merkleBlock in blockHashDictionary) {
        NSData *blockHash = uint256_data(merkleBlock.blockHash);
        if (blockHash) {
            [rDictionary setObject:blockHashDictionary[merkleBlock] forKey:blockHash];
        }
    }
    return rDictionary;
}

- (DSSimplifiedMasternodeEntry *)simplifiedMasternodeEntry {
    DSSimplifiedMasternodeEntry *simplifiedMasternodeEntry = [DSSimplifiedMasternodeEntry simplifiedMasternodeEntryWithProviderRegistrationTransactionHash:[self.providerRegistrationTransactionHash UInt256] confirmedHash:[self.confirmedHash UInt256] address:self.ipv6Address.UInt128 port:self.port operatorBLSPublicKey:[self.operatorBLSPublicKey UInt384] previousOperatorBLSPublicKeys:[self merkleBlockDictionaryFromBlockHashDictionary:(NSDictionary<NSData *, NSData *> *)self.previousOperatorBLSPublicKeys] keyIDVoting:[self.keyIDVoting UInt160] isValid:self.isValid previousValidity:[self merkleBlockDictionaryFromBlockHashDictionary:(NSDictionary<NSData *, NSData *> *)self.previousValidity] simplifiedMasternodeEntryHash:[self.simplifiedMasternodeEntryHash UInt256] previousSimplifiedMasternodeEntryHashes:[self merkleBlockDictionaryFromBlockHashDictionary:(NSDictionary<NSData *, NSData *> *)self.previousSimplifiedMasternodeEntryHashes] onChain:self.chain.chain];
    return simplifiedMasternodeEntry;
}

@end
