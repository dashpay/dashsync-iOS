//
//  DSAuthenticationKeysDerivationPath.m
//  DashSync
//
//  Created by Sam Westrich on 2/10/19.
//

#import "DSAuthenticationKeysDerivationPath.h"
#import "DSDerivationPathFactory.h"
#import "DSSimpleIndexedDerivationPath+Protected.h"

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
+ (instancetype)blockchainUsersKeysDerivationPathForWallet:(DSWallet*)wallet {
    return [[DSDerivationPathFactory sharedInstance] blockchainUsersKeysDerivationPathForWallet:wallet];
}

-(NSUInteger)defaultGapLimit {
    return 10;
}

+ (instancetype)providerVotingKeysDerivationPathForChain:(DSChain*)chain {
    NSUInteger coinType = (chain.chainType == DSChainType_MainNet)?5:1;
    NSUInteger indexes[] = {FEATURE_PURPOSE_HARDENED, coinType | BIP32_HARD, 3 | BIP32_HARD, 1 | BIP32_HARD};
    return [DSAuthenticationKeysDerivationPath derivationPathWithIndexes:indexes length:4 type:DSDerivationPathType_Authentication signingAlgorithm:DSDerivationPathSigningAlgorith_ECDSA reference:DSDerivationPathReference_ProviderVotingKeys onChain:chain];
}

+ (instancetype)providerOwnerKeysDerivationPathForChain:(DSChain*)chain {
    NSUInteger coinType = (chain.chainType == DSChainType_MainNet)?5:1;
    NSUInteger indexes[] = {FEATURE_PURPOSE_HARDENED, coinType | BIP32_HARD, 3 | BIP32_HARD, 2 | BIP32_HARD};
    return [DSAuthenticationKeysDerivationPath derivationPathWithIndexes:indexes length:4 type:DSDerivationPathType_Authentication signingAlgorithm:DSDerivationPathSigningAlgorith_ECDSA reference:DSDerivationPathReference_ProviderOwnerKeys onChain:chain];
}

+ (instancetype)providerOperatorKeysDerivationPathForChain:(DSChain*)chain {
    NSUInteger coinType = (chain.chainType == DSChainType_MainNet)?5:1;
    NSUInteger indexes[] = {FEATURE_PURPOSE_HARDENED, coinType | BIP32_HARD, 3 | BIP32_HARD, 3 | BIP32_HARD};
    return [DSAuthenticationKeysDerivationPath derivationPathWithIndexes:indexes length:4 type:DSDerivationPathType_Authentication signingAlgorithm:DSDerivationPathSigningAlgorith_BLS reference:DSDerivationPathReference_ProviderOperatorKeys onChain:chain];
}

+ (instancetype)blockchainUsersKeysDerivationPathForChain:(DSChain*)chain {
    NSUInteger coinType = (chain.chainType == DSChainType_MainNet)?5:1;
    NSUInteger indexes[] = {FEATURE_PURPOSE_HARDENED, coinType | BIP32_HARD, 5 | BIP32_HARD, 0 | BIP32_HARD};
    return [DSAuthenticationKeysDerivationPath derivationPathWithIndexes:indexes length:4 type:DSDerivationPathType_Authentication signingAlgorithm:DSDerivationPathSigningAlgorith_ECDSA reference:DSDerivationPathReference_BlockchainUsers onChain:chain];
}

- (NSData*)firstUnusedPublicKey {
    return [self publicKeyDataAtIndex:[self unusedIndex]];
}

- (DSKey*)firstUnusedPrivateKeyFromSeed:(NSData*)seed {
    return [self privateKeyAtIndexPath:[NSIndexPath indexPathWithIndex:[self unusedIndex]] fromSeed:seed];
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
