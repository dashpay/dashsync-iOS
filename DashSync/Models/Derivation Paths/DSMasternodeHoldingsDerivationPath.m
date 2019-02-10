//
//  DSMasternodeHoldingsDerivationPath.m
//  DashSync
//
//  Created by Sam Westrich on 2/10/19.
//

#import "DSMasternodeHoldingsDerivationPath.h"
#import "DSDerivationPath+Protected.h"

@implementation DSMasternodeHoldingsDerivationPath

+ (instancetype _Nonnull)providerFundsDerivationPathForWallet:(DSWallet*)wallet {
    NSUInteger coinType = (wallet.chain.chainType == DSChainType_MainNet)?5:1;
    NSUInteger indexes[] = {5 | BIP32_HARD, coinType | BIP32_HARD, 3 | BIP32_HARD, 0 | BIP32_HARD};
    DSMasternodeHoldingsDerivationPath * derivationPath = [self derivationPathWithIndexes:indexes length:4 type:DSDerivationPathType_ProtectedFunds signingAlgorithm:DSDerivationPathSigningAlgorith_ECDSA reference:DSDerivationPathReference_ProviderFunds onChain:wallet.chain];
    derivationPath.wallet = wallet;
    return derivationPath;
}

-(void)loadAddresses {
    
}

-(uint32_t)unusedIndex {
    return 0;
}

-(NSString*)receiveAddress {
    return [self addressAtIndex:[self unusedIndex]];
}

@end
