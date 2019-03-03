//
//  DSMasternodeHoldingsDerivationPath+Protected.h
//  DashSync
//
//  Created by Sam Westrich on 2/16/19.
//

#import "DSMasternodeHoldingsDerivationPath.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSMasternodeHoldingsDerivationPath ()

+ (instancetype)providerFundsDerivationPathForChain:(DSChain*)chain;

@end

NS_ASSUME_NONNULL_END
