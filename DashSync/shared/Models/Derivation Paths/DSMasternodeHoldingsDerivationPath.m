//
//  DSMasternodeHoldingsDerivationPath.m
//  DashSync
//
//  Created by Sam Westrich on 2/10/19.
//

#import "DSChain+Params.h"
#import "DSMasternodeHoldingsDerivationPath.h"
#import "DSDerivationPath+Protected.h"
#import "DSDerivationPathFactory.h"
#import "DSGapLimit.h"
#import "DSMasternodeManager.h"
#import "DSSimpleIndexedDerivationPath+Protected.h"
#import "DSWallet+Protected.h"

@interface DSMasternodeHoldingsDerivationPath ()

@end

@implementation DSMasternodeHoldingsDerivationPath

+ (instancetype _Nonnull)providerFundsDerivationPathForWallet:(DSWallet *)wallet {
    return [[DSDerivationPathFactory sharedInstance] providerFundsDerivationPathForWallet:wallet];
}

+ (instancetype _Nonnull)providerFundsDerivationPathForChain:(DSChain *)chain {
    UInt256 indexes[] = {uint256_from_long(FEATURE_PURPOSE), uint256_from_long((uint64_t) chain.coinType), uint256_from_long(3), uint256_from_long(0)};
    BOOL hardenedIndexes[] = {YES, YES, YES, YES};
    return [self derivationPathWithIndexes:indexes
                                  hardened:hardenedIndexes
                                    length:4
                                      type:DSDerivationPathType_ProtectedFunds
                          signingAlgorithm:DKeyKindECDSA()
                                 reference:DSDerivationPathReference_ProviderFunds
                                   onChain:chain];
}

- (DSGapLimit *)defaultGapSettings {
    return [DSGapLimit withLimit:5];
}

@end
