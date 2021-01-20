//
//  DSDerivationPathFactory.h
//  DashSync
//
//  Created by Sam Westrich on 2/10/19.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class DSAuthenticationKeysDerivationPath, DSWallet, DSMasternodeHoldingsDerivationPath, DSDerivationPath, DSCreditFundingDerivationPath;

@interface DSDerivationPathFactory : NSObject

+ (instancetype _Nullable)sharedInstance;

- (DSAuthenticationKeysDerivationPath *)providerVotingKeysDerivationPathForWallet:(DSWallet *)wallet;
- (DSAuthenticationKeysDerivationPath *)providerOwnerKeysDerivationPathForWallet:(DSWallet *)wallet;
- (DSAuthenticationKeysDerivationPath *)providerOperatorKeysDerivationPathForWallet:(DSWallet *)wallet;
- (DSMasternodeHoldingsDerivationPath *)providerFundsDerivationPathForWallet:(DSWallet *)wallet;

- (DSCreditFundingDerivationPath *)blockchainIdentityRegistrationFundingDerivationPathForWallet:(DSWallet *)wallet;
- (DSCreditFundingDerivationPath *)blockchainIdentityTopupFundingDerivationPathForWallet:(DSWallet *)wallet;
- (DSAuthenticationKeysDerivationPath *)blockchainIdentityBLSKeysDerivationPathForWallet:(DSWallet *)wallet;
- (DSAuthenticationKeysDerivationPath *)blockchainIdentityECDSAKeysDerivationPathForWallet:(DSWallet *)wallet;

- (NSArray<DSDerivationPath *> *)loadedSpecializedDerivationPathsForWallet:(DSWallet *)wallet;
- (NSArray<DSDerivationPath *> *)unloadedSpecializedDerivationPathsForWallet:(DSWallet *)wallet;
- (NSArray<DSDerivationPath *> *)unloadedSpecializedDerivationPathsNeedingExtendedPublicKeyForWallet:(DSWallet *)wallet;

@end

NS_ASSUME_NONNULL_END
