//
//  DSAuthenticationKeysDerivationPath+Protected.h
//  DashSync
//
//  Created by Sam Westrich on 2/15/19.
//

#import "DSAuthenticationKeysDerivationPath.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSAuthenticationKeysDerivationPath ()

+ (instancetype)providerVotingKeysDerivationPathForChain:(DSChain*)chain;
+ (instancetype)providerOwnerKeysDerivationPathForChain:(DSChain*)chain;
+ (instancetype)providerOperatorKeysDerivationPathForChain:(DSChain*)chain;
+ (instancetype)blockchainIdentityECDSAKeysDerivationPathForChain:(DSChain*)chain;
+ (instancetype)blockchainIdentityBLSKeysDerivationPathForChain:(DSChain*)chain;

@end

NS_ASSUME_NONNULL_END
