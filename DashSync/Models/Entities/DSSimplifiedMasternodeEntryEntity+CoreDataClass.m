//
//  DSSimplifiedMasternodeEntryEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 7/19/18.
//
//

#import "DSSimplifiedMasternodeEntryEntity+CoreDataClass.h"
#import "DSSimplifiedMasternodeEntry.h"
#import "DSLocalMasternodeEntity+CoreDataClass.h"
#import "DSChain.h"
#import "DSChainEntity+CoreDataProperties.h"
#import "NSData+Bitcoin.h"
#import "NSManagedObject+Sugar.h"
#import "DSAddressEntity+CoreDataClass.h"
#import "DSKey.h"
#include <arpa/inet.h>

@implementation DSSimplifiedMasternodeEntryEntity

- (void)updateAttributesFromSimplifiedMasternodeEntry:(DSSimplifiedMasternodeEntry *)simplifiedMasternodeEntry {
    [self updateAttributesFromSimplifiedMasternodeEntry:simplifiedMasternodeEntry knownOperatorAddresses:nil knownVotingAddresses:nil localMasternodes:nil];
}

- (void)updateAttributesFromSimplifiedMasternodeEntry:(DSSimplifiedMasternodeEntry *)simplifiedMasternodeEntry knownOperatorAddresses:(NSDictionary<NSString*,DSAddressEntity*>*)knownOperatorAddresses knownVotingAddresses:(NSDictionary<NSString*,DSAddressEntity*>*)knownVotingAddresses localMasternodes:(NSDictionary<NSData*,DSLocalMasternodeEntity*>*)localMasternodes {
    
    if (!uint128_eq(self.ipv6Address.UInt128, simplifiedMasternodeEntry.address)) {
        self.ipv6Address = uint128_data(simplifiedMasternodeEntry.address);
        char s[INET6_ADDRSTRLEN];
        uint32_t address32 = CFSwapInt32BigToHost(simplifiedMasternodeEntry.address.u32[3]);
        NSString * ipAddressString = @(inet_ntop(AF_INET, &address32, s, sizeof(s)));
        if (self.address != address32) {
            self.address = address32;
            DSDLog(@"changing address to %@",ipAddressString);
        }
    }
    
    NSData * confirmedHashData = uint256_data(simplifiedMasternodeEntry.confirmedHash);
    
    if (![self.confirmedHash isEqualToData:confirmedHashData]) {
        self.confirmedHash = confirmedHashData;
        DSDLog(@"changing confirmedHashData to %@",confirmedHashData.hexString);
    }
    
    if (self.port != simplifiedMasternodeEntry.port) {
        self.port = simplifiedMasternodeEntry.port;
        DSDLog(@"changing port to %u",simplifiedMasternodeEntry.port);
    }
    
    NSData * keyIDVotingData = [NSData dataWithUInt160:simplifiedMasternodeEntry.keyIDVoting];
    
    if (![self.keyIDVoting isEqualToData:keyIDVotingData]) {
        self.keyIDVoting = keyIDVotingData;
        DSDLog(@"changing keyIDVotingData to %@",keyIDVotingData.hexString);
    }
    
    NSData * operatorPublicKeyData = [NSData dataWithUInt384:simplifiedMasternodeEntry.operatorPublicKey];
    
    if (![self.operatorBLSPublicKey isEqualToData:operatorPublicKeyData]) {
        self.operatorBLSPublicKey = operatorPublicKeyData;
        DSDLog(@"changing operatorBLSPublicKey to %@",operatorPublicKeyData.hexString);
    }
    
    if (self.isValid != simplifiedMasternodeEntry.isValid) {
        self.isValid = simplifiedMasternodeEntry.isValid;
        DSDLog(@"changing isValid to %@",simplifiedMasternodeEntry.isValid?@"TRUE":@"FALSE");
    }
    
    
    self.simplifiedMasternodeEntryHash = [NSData dataWithUInt256:simplifiedMasternodeEntry.simplifiedMasternodeEntryHash];
    self.previousSimplifiedMasternodeEntryHashes = simplifiedMasternodeEntry.previousSimplifiedMasternodeEntryHashes;
    self.previousOperatorBLSPublicKeys = simplifiedMasternodeEntry.previousOperatorPublicKeys;
    self.previousValidity = simplifiedMasternodeEntry.previousValidity;
    
    DSLocalMasternodeEntity * localMasternode = nil;
    if (localMasternodes) {
        localMasternode = [localMasternodes objectForKey:uint256_data(simplifiedMasternodeEntry.providerRegistrationTransactionHash)];
    } else {
        localMasternode = [DSLocalMasternodeEntity anyObjectMatching:@"providerRegistrationTransaction.transactionHash.txHash == %@", uint256_data(simplifiedMasternodeEntry.providerRegistrationTransactionHash)];
    }
    
    self.localMasternode = localMasternode;
    
    NSString * operatorAddress = [DSKey addressWithPublicKeyData:self.operatorBLSPublicKey forChain:simplifiedMasternodeEntry.chain];
    NSString * votingAddress = [self.keyIDVoting addressFromHash160DataForChain:simplifiedMasternodeEntry.chain];
    
    DSAddressEntity * operatorAddressEntity = nil;
    
    if (knownOperatorAddresses) {
        operatorAddressEntity = [knownOperatorAddresses objectForKey:operatorAddress];
    } else {
        operatorAddressEntity = [DSAddressEntity findAddressMatching:operatorAddress onChain:simplifiedMasternodeEntry.chain];
    }
    
    if (operatorAddressEntity) {
        [self addAddressesObject:operatorAddressEntity];
    }
    
    DSAddressEntity * votingAddressEntity = nil;
    
    if (knownVotingAddresses) {
        votingAddressEntity = [knownVotingAddresses objectForKey:operatorAddress];
    } else {
        votingAddressEntity = [DSAddressEntity findAddressMatching:votingAddress onChain:simplifiedMasternodeEntry.chain];
    }
    
    if (votingAddressEntity) {
        [self addAddressesObject:votingAddressEntity];
    }
}

- (void)setAttributesFromSimplifiedMasternodeEntry:(DSSimplifiedMasternodeEntry *)simplifiedMasternodeEntry onChain:(DSChainEntity*)chainEntity {
    [self setAttributesFromSimplifiedMasternodeEntry:simplifiedMasternodeEntry knownOperatorAddresses:nil knownVotingAddresses:nil localMasternodes:nil onChain:chainEntity];
}

- (void)setAttributesFromSimplifiedMasternodeEntry:(DSSimplifiedMasternodeEntry *)simplifiedMasternodeEntry knownOperatorAddresses:(NSDictionary<NSString*,DSAddressEntity*>*)knownOperatorAddresses knownVotingAddresses:(NSDictionary<NSString*,DSAddressEntity*>*)knownVotingAddresses localMasternodes:(NSDictionary<NSData*,DSLocalMasternodeEntity*>*)localMasternodes onChain:(DSChainEntity*)chainEntity {
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
    } else {
        self.chain = chainEntity;
    }
    
    
    DSLocalMasternodeEntity * localMasternode = nil;
    if (localMasternodes) {
        localMasternode = [localMasternodes objectForKey:uint256_data(simplifiedMasternodeEntry.providerRegistrationTransactionHash)];
    } else {
        localMasternode = [DSLocalMasternodeEntity anyObjectMatching:@"providerRegistrationTransaction.transactionHash.txHash == %@", uint256_data(simplifiedMasternodeEntry.providerRegistrationTransactionHash)];
    }
    
    self.localMasternode = localMasternode;
    
    NSString * operatorAddress = [DSKey addressWithPublicKeyData:self.operatorBLSPublicKey forChain:simplifiedMasternodeEntry.chain];
    NSString * votingAddress = [self.keyIDVoting addressFromHash160DataForChain:simplifiedMasternodeEntry.chain];
    
    DSAddressEntity * operatorAddressEntity = nil;
    
    if (knownOperatorAddresses) {
        operatorAddressEntity = [knownOperatorAddresses objectForKey:operatorAddress];
    } else {
        operatorAddressEntity = [DSAddressEntity findAddressMatching:operatorAddress onChain:simplifiedMasternodeEntry.chain];
    }
    
    if (operatorAddressEntity) {
        [self addAddressesObject:operatorAddressEntity];
    }
    
    DSAddressEntity * votingAddressEntity = nil;
    
    if (knownVotingAddresses) {
        votingAddressEntity = [knownVotingAddresses objectForKey:operatorAddress];
    } else {
        votingAddressEntity = [DSAddressEntity findAddressMatching:votingAddress onChain:simplifiedMasternodeEntry.chain];
    }
    
    if (votingAddressEntity) {
        [self addAddressesObject:votingAddressEntity];
    }
}

+ (void)deleteHavingProviderTransactionHashes:(NSArray*)providerTransactionHashes onChain:(DSChainEntity*)chainEntity {
    NSArray * hashesToDelete = [self objectsMatching:@"(chain == %@) && (providerRegistrationTransactionHash IN %@)",chainEntity,providerTransactionHashes];
    for (DSSimplifiedMasternodeEntryEntity * simplifiedMasternodeEntryEntity in hashesToDelete) {
        [chainEntity.managedObjectContext deleteObject:simplifiedMasternodeEntryEntity];
    }
}

+ (void)deleteAllOnChain:(DSChainEntity*)chainEntity {
    NSArray * hashesToDelete = [self objectsMatching:@"(chain == %@)",chainEntity];
    for (DSSimplifiedMasternodeEntryEntity * simplifiedMasternodeEntryEntity in hashesToDelete) {
        [chainEntity.managedObjectContext deleteObject:simplifiedMasternodeEntryEntity];
    }
}

+ (DSSimplifiedMasternodeEntryEntity*)simplifiedMasternodeEntryForProviderRegistrationTransactionHash:(NSData*)providerRegistrationTransactionHash onChain:(DSChainEntity*)chainEntity {
    return [self anyObjectMatching:@"(providerRegistrationTransactionHash == %@) && (chain == %@)",providerRegistrationTransactionHash,chainEntity];
}

+ (DSSimplifiedMasternodeEntryEntity*)simplifiedMasternodeEntryForHash:(NSData*)simplifiedMasternodeEntryHash onChain:(DSChainEntity*)chainEntity {
    return [self anyObjectMatching:@"(simplifiedMasternodeEntryHash == %@) && (chain == %@)",simplifiedMasternodeEntryHash,chainEntity];
}

- (DSSimplifiedMasternodeEntry*)simplifiedMasternodeEntry {
    DSSimplifiedMasternodeEntry * simplifiedMasternodeEntry = [DSSimplifiedMasternodeEntry simplifiedMasternodeEntryWithProviderRegistrationTransactionHash:[self.providerRegistrationTransactionHash UInt256] confirmedHash:[self.confirmedHash UInt256] address:self.ipv6Address.UInt128 port:self.port operatorBLSPublicKey:[self.operatorBLSPublicKey UInt384] previousOperatorBLSPublicKeys:[self.previousOperatorBLSPublicKeys copy] keyIDVoting:[self.keyIDVoting UInt160] isValid:self.isValid previousValidity:[self.previousValidity copy] simplifiedMasternodeEntryHash:[self.simplifiedMasternodeEntryHash UInt256] previousSimplifiedMasternodeEntryHashes:[self.previousSimplifiedMasternodeEntryHashes copy] onChain:self.chain.chain];
    return simplifiedMasternodeEntry;
}

@end
