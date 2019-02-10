//
//  DSMasternodeKeysDerivationPath.h
//  DashSync
//
//  Created by Sam Westrich on 2/10/19.
//

#import "DSDerivationPath+Protected.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSAuthenticationKeysDerivationPath : DSDerivationPath

+ (instancetype)providerVotingKeysDerivationPathForWallet:(DSWallet*)wallet;
+ (instancetype)providerOwnerKeysDerivationPathForWallet:(DSWallet*)wallet;
+ (instancetype)providerOperatorKeysDerivationPathForWallet:(DSWallet*)wallet;

- (NSData*)firstUnusedPublicKey;
- (DSKey*)firstUnusedPrivateKeyFromSeed:(NSData*)seed;

@end

NS_ASSUME_NONNULL_END
