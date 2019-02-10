//
//  DSAuthenticationKeysDerivationPath.m
//  DashSync
//
//  Created by Sam Westrich on 2/10/19.
//

#import "DSAuthenticationKeysDerivationPath.h"

@implementation DSAuthenticationKeysDerivationPath

+ (instancetype _Nonnull)providerVotingKeysDerivationPathForWallet:(DSWallet*)wallet {
    NSUInteger coinType = (wallet.chain.chainType == DSChainType_MainNet)?5:1;
    NSUInteger indexes[] = {5 | BIP32_HARD, coinType | BIP32_HARD, 3 | BIP32_HARD, 1 | BIP32_HARD};
    DSAuthenticationKeysDerivationPath * derivationPath = [self derivationPathWithIndexes:indexes length:4 type:DSDerivationPathType_Authentication signingAlgorithm:DSDerivationPathSigningAlgorith_ECDSA reference:DSDerivationPathReference_ProviderVotingKeys onChain:wallet.chain];
    derivationPath.wallet = wallet;
    return derivationPath;
}

+ (instancetype _Nonnull)providerOwnerKeysDerivationPathForWallet:(DSWallet*)wallet {
    NSUInteger coinType = (wallet.chain.chainType == DSChainType_MainNet)?5:1;
    NSUInteger indexes[] = {5 | BIP32_HARD, coinType | BIP32_HARD, 3 | BIP32_HARD, 2 | BIP32_HARD};
    DSAuthenticationKeysDerivationPath * derivationPath = [self derivationPathWithIndexes:indexes length:4 type:DSDerivationPathType_Authentication signingAlgorithm:DSDerivationPathSigningAlgorith_ECDSA reference:DSDerivationPathReference_ProviderOwnerKeys onChain:wallet.chain];
    derivationPath.wallet = wallet;
    return derivationPath;
}

+ (instancetype _Nonnull)providerOperatorKeysDerivationPathForWallet:(DSWallet*)wallet {
    NSUInteger coinType = (wallet.chain.chainType == DSChainType_MainNet)?5:1;
    NSUInteger indexes[] = {5 | BIP32_HARD, coinType | BIP32_HARD, 3 | BIP32_HARD, 3 | BIP32_HARD};
    DSAuthenticationKeysDerivationPath * derivationPath = [self derivationPathWithIndexes:indexes length:4 type:DSDerivationPathType_Authentication signingAlgorithm:DSDerivationPathSigningAlgorith_BLS reference:DSDerivationPathReference_ProviderOperatorKeys onChain:wallet.chain];
    derivationPath.wallet = wallet;
    return derivationPath;
}

-(uint32_t)unusedIndex {
    return 0;
}

- (NSData*)firstUnusedPublicKey {
    return [self publicKeyAtIndex:[self unusedIndex]];
}

-(DSKey*)firstUnusedPrivateKeyFromSeed:(NSData*)seed {
    return [self privateKeyAtIndexPath:[NSIndexPath indexPathWithIndex:[self unusedIndex]] fromSeed:seed];
}

@end
