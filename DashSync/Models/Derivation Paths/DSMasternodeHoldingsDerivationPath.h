//
//  DSMasternodeHoldingsDerivationPath.h
//  DashSync
//
//  Created by Sam Westrich on 2/10/19.
//

#import "DSDerivationPath.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSMasternodeHoldingsDerivationPath : DSDerivationPath

+ (instancetype)providerFundsDerivationPathForWallet:(DSWallet*)wallet;

-(NSString*)receiveAddress;

@end

NS_ASSUME_NONNULL_END
