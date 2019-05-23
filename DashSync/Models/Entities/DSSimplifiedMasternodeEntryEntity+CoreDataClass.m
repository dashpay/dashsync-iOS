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
    char s[INET6_ADDRSTRLEN];
    uint32_t address32 = CFSwapInt32BigToHost(simplifiedMasternodeEntry.address.u32[3]);
    NSString * ipAddressString = @(inet_ntop(AF_INET, &address32, s, sizeof(s)));
    DSDLog(@"changing address to %@",ipAddressString);
    self.address = address32;
    self.port = simplifiedMasternodeEntry.port;
    self.keyIDVoting = [NSData dataWithUInt160:simplifiedMasternodeEntry.keyIDVoting];
    self.operatorBLSPublicKey = [NSData dataWithUInt384:simplifiedMasternodeEntry.operatorPublicKey];
    self.isValid = simplifiedMasternodeEntry.isValid;
    self.simplifiedMasternodeEntryHash = [NSData dataWithUInt256:simplifiedMasternodeEntry.simplifiedMasternodeEntryHash];
    DSLocalMasternodeEntity * localMasternode = [DSLocalMasternodeEntity anyObjectMatching:@"providerRegistrationTransaction.transactionHash.txHash == %@", uint256_data(simplifiedMasternodeEntry.providerRegistrationTransactionHash)];
    self.localMasternode = localMasternode;
    
    NSString * operatorAddress = [DSKey addressWithPublicKeyData:self.operatorBLSPublicKey forChain:simplifiedMasternodeEntry.chain];
    NSString * votingAddress = [self.keyIDVoting addressFromHash160DataForChain:simplifiedMasternodeEntry.chain];
    
    DSAddressEntity * operatorAddressEntity = [DSAddressEntity findAddressMatching:operatorAddress onChain:simplifiedMasternodeEntry.chain];
    if (operatorAddressEntity) {
        [self addAddressesObject:operatorAddressEntity];
    }
    
    DSAddressEntity * votingAddressEntity = [DSAddressEntity findAddressMatching:votingAddress onChain:simplifiedMasternodeEntry.chain];
    if (votingAddressEntity) {
        [self addAddressesObject:votingAddressEntity];
    }
}

- (void)setAttributesFromSimplifiedMasternodeEntry:(DSSimplifiedMasternodeEntry *)simplifiedMasternodeEntry onChain:(DSChainEntity*)chainEntity {
    self.providerRegistrationTransactionHash = [NSData dataWithUInt256:simplifiedMasternodeEntry.providerRegistrationTransactionHash];
    self.confirmedHash = [NSData dataWithUInt256:simplifiedMasternodeEntry.confirmedHash];
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
    DSLocalMasternodeEntity * localMasternode = [DSLocalMasternodeEntity anyObjectMatching:@"providerRegistrationTransaction.transactionHash.txHash == %@", uint256_data(simplifiedMasternodeEntry.providerRegistrationTransactionHash)];
    self.localMasternode = localMasternode;
    
    NSString * operatorAddress = [DSKey addressWithPublicKeyData:self.operatorBLSPublicKey forChain:simplifiedMasternodeEntry.chain];
    NSString * votingAddress = [self.keyIDVoting addressFromHash160DataForChain:simplifiedMasternodeEntry.chain];
    
    DSAddressEntity * operatorAddressEntity = [DSAddressEntity findAddressMatching:operatorAddress onChain:simplifiedMasternodeEntry.chain];
    if (operatorAddressEntity) {
        [self addAddressesObject:operatorAddressEntity];
    }
    
    DSAddressEntity * votingAddressEntity = [DSAddressEntity findAddressMatching:votingAddress onChain:simplifiedMasternodeEntry.chain];
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
    NSArray * objects = [self objectsMatching:@"(chain == %@) && (providerRegistrationTransactionHash == %@)",chainEntity,providerRegistrationTransactionHash];
    return [objects firstObject];
}

+ (DSSimplifiedMasternodeEntryEntity*)simplifiedMasternodeEntryForHash:(NSData*)simplifiedMasternodeEntryHash onChain:(DSChainEntity*)chainEntity {
    NSArray * objects = [self objectsMatching:@"(chain == %@) && (simplifiedMasternodeEntryHash == %@)",chainEntity,simplifiedMasternodeEntryHash];
    return [objects firstObject];
}

- (DSSimplifiedMasternodeEntry*)simplifiedMasternodeEntry {
    UInt128 address = { .u32 = { 0, 0, CFSwapInt32HostToBig(0xffff), CFSwapInt32HostToBig((uint32_t)self.address) } };
    DSSimplifiedMasternodeEntry * simplifiedMasternodeEntry = [DSSimplifiedMasternodeEntry simplifiedMasternodeEntryWithProviderRegistrationTransactionHash:[self.providerRegistrationTransactionHash UInt256] confirmedHash:[self.confirmedHash UInt256] address:address port:self.port operatorBLSPublicKey:[self.operatorBLSPublicKey UInt384] previousOperatorBLSPublicKeys:[self.previousOperatorBLSPublicKeys copy] keyIDVoting:[self.keyIDVoting UInt160] isValid:self.isValid simplifiedMasternodeEntryHash:[self.simplifiedMasternodeEntryHash UInt256] onChain:self.chain.chain];
    return simplifiedMasternodeEntry;
}

@end
