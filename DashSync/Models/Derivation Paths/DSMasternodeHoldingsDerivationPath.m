//
//  DSMasternodeHoldingsDerivationPath.m
//  DashSync
//
//  Created by Sam Westrich on 2/10/19.
//

#import "DSMasternodeHoldingsDerivationPath.h"
#import "DSDerivationPath+Protected.h"
#import "DSDerivationPathFactory.h"
#import "DSSimpleIndexedDerivationPath+Protected.h"

@interface DSMasternodeHoldingsDerivationPath()

@end

@implementation DSMasternodeHoldingsDerivationPath

+ (instancetype _Nonnull)providerFundsDerivationPathForWallet:(DSWallet*)wallet {
    return [[DSDerivationPathFactory sharedInstance] providerFundsDerivationPathForWallet:wallet];
}

+ (instancetype _Nonnull)providerFundsDerivationPathForChain:(DSChain*)chain {
    NSUInteger coinType = (chain.chainType == DSChainType_MainNet)?5:1;
    NSUInteger indexes[] = {5 | BIP32_HARD, coinType | BIP32_HARD, 3 | BIP32_HARD, 0 | BIP32_HARD};
    return [self derivationPathWithIndexes:indexes length:4 type:DSDerivationPathType_ProtectedFunds signingAlgorithm:DSDerivationPathSigningAlgorith_ECDSA reference:DSDerivationPathReference_ProviderFunds onChain:chain];
}

-(NSString*)receiveAddress {
    return [self addressAtIndex:[self unusedIndex]];
}

@end
