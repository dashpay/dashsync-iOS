//
//  DSAuthenticationKeysDerivationPath.m
//  DashSync
//
//  Created by Sam Westrich on 2/10/19.
//

#import "DSAuthenticationKeysDerivationPath.h"
#import "DSDerivationPathFactory.h"
#import "DSSimpleIndexedDerivationPath+Protected.h"
#import "DSCreditFundingDerivationPath.h"

@interface DSAuthenticationKeysDerivationPath()

@end

@implementation DSAuthenticationKeysDerivationPath

+ (instancetype)providerVotingKeysDerivationPathForWallet:(DSWallet*)wallet {
    return [[DSDerivationPathFactory sharedInstance] providerVotingKeysDerivationPathForWallet:wallet];
}
+ (instancetype)providerOwnerKeysDerivationPathForWallet:(DSWallet*)wallet {
     return [[DSDerivationPathFactory sharedInstance] providerOwnerKeysDerivationPathForWallet:wallet];
}
+ (instancetype)providerOperatorKeysDerivationPathForWallet:(DSWallet*)wallet {
    return [[DSDerivationPathFactory sharedInstance] providerOperatorKeysDerivationPathForWallet:wallet];
}
+ (instancetype)blockchainIdentitiesBLSKeysDerivationPathForWallet:(DSWallet*)wallet {
    return [[DSDerivationPathFactory sharedInstance] blockchainIdentityBLSKeysDerivationPathForWallet:wallet];
}
+ (instancetype)blockchainIdentitiesECDSAKeysDerivationPathForWallet:(DSWallet*)wallet {
    return [[DSDerivationPathFactory sharedInstance] blockchainIdentityECDSAKeysDerivationPathForWallet:wallet];
}

-(NSUInteger)defaultGapLimit {
    return 10;
}

+ (instancetype)providerVotingKeysDerivationPathForChain:(DSChain*)chain {
    NSUInteger coinType = (chain.chainType == DSChainType_MainNet)?5:1;
    UInt256 indexes[] = {uint256_from_long(FEATURE_PURPOSE), uint256_from_long(coinType), uint256_from_long(3), uint256_from_long(1)};
    BOOL hardenedIndexes[] = {YES,YES,YES,YES};
    return [DSAuthenticationKeysDerivationPath derivationPathWithIndexes:indexes hardened:hardenedIndexes length:4 type:DSDerivationPathType_Authentication signingAlgorithm:DSKeyType_ECDSA reference:DSDerivationPathReference_ProviderVotingKeys onChain:chain];
}

+ (instancetype)providerOwnerKeysDerivationPathForChain:(DSChain*)chain {
    NSUInteger coinType = (chain.chainType == DSChainType_MainNet)?5:1;
    UInt256 indexes[] = {uint256_from_long(FEATURE_PURPOSE), uint256_from_long(coinType), uint256_from_long(3), uint256_from_long(2)};
    BOOL hardenedIndexes[] = {YES,YES,YES,YES};
    return [DSAuthenticationKeysDerivationPath derivationPathWithIndexes:indexes hardened:hardenedIndexes length:4 type:DSDerivationPathType_Authentication signingAlgorithm:DSKeyType_ECDSA reference:DSDerivationPathReference_ProviderOwnerKeys onChain:chain];
}

+ (instancetype)providerOperatorKeysDerivationPathForChain:(DSChain*)chain {
    NSUInteger coinType = (chain.chainType == DSChainType_MainNet)?5:1;
    UInt256 indexes[] = {uint256_from_long(FEATURE_PURPOSE), uint256_from_long(coinType), uint256_from_long(3), uint256_from_long(3)};
    BOOL hardenedIndexes[] = {YES,YES,YES,YES};
    return [DSAuthenticationKeysDerivationPath derivationPathWithIndexes:indexes hardened:hardenedIndexes length:4 type:DSDerivationPathType_Authentication signingAlgorithm:DSKeyType_BLS reference:DSDerivationPathReference_ProviderOperatorKeys onChain:chain];
}

+ (instancetype)blockchainIdentityECDSAKeysDerivationPathForChain:(DSChain*)chain {
    NSUInteger coinType = (chain.chainType == DSChainType_MainNet)?5:1;
    UInt256 indexes[] = {uint256_from_long(FEATURE_PURPOSE), uint256_from_long(coinType), uint256_from_long(5), uint256_from_long(0), uint256_from_long(0)};
    BOOL hardenedIndexes[] = {YES,YES,YES,YES,YES};
    return [DSAuthenticationKeysDerivationPath derivationPathWithIndexes:indexes hardened:hardenedIndexes length:5 type:DSDerivationPathType_Authentication signingAlgorithm:DSKeyType_ECDSA reference:DSDerivationPathReference_BlockchainIdentities onChain:chain];
}

+ (instancetype)blockchainIdentityBLSKeysDerivationPathForChain:(DSChain*)chain {
    NSUInteger coinType = (chain.chainType == DSChainType_MainNet)?5:1;
    UInt256 indexes[] = {uint256_from_long(FEATURE_PURPOSE), uint256_from_long(coinType), uint256_from_long(5), uint256_from_long(0), uint256_from_long(1)};
    BOOL hardenedIndexes[] = {YES,YES,YES,YES,YES};
    return [DSAuthenticationKeysDerivationPath derivationPathWithIndexes:indexes hardened:hardenedIndexes length:5 type:DSDerivationPathType_Authentication signingAlgorithm:DSKeyType_BLS reference:DSDerivationPathReference_BlockchainIdentities onChain:chain];
}

- (NSData*)firstUnusedPublicKey {
    return [self publicKeyDataAtIndex:(uint32_t)[self firstUnusedIndex]];
}

- (DSKey*)firstUnusedPrivateKeyFromSeed:(NSData*)seed {
    return [self privateKeyAtIndexPath:[NSIndexPath indexPathWithIndex:[self firstUnusedIndex]] fromSeed:seed];
}

- (DSKey*)privateKeyForAddress:(NSString*)address fromSeed:(NSData*)seed {
    NSUInteger index = [self indexOfKnownAddress:address];
    return [self privateKeyAtIndexPath:[NSIndexPath indexPathWithIndex:index] fromSeed:seed];
}

- (DSKey*)privateKeyForHash160:(UInt160)hash160 fromSeed:(NSData*)seed {
    NSString * address = [[NSData dataWithUInt160:hash160] addressFromHash160DataForChain:self.chain];
    return [self privateKeyForAddress:address fromSeed:seed];
}

@end
