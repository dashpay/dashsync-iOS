//
//  DSMasternodeKeysDerivationPath.h
//  DashSync
//
//  Created by Sam Westrich on 2/10/19.
//

#import "DSDerivationPath+Protected.h"
#import "DSSimpleIndexedDerivationPath.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSAuthenticationKeysDerivationPath : DSSimpleIndexedDerivationPath

+ (instancetype)providerVotingKeysDerivationPathForWallet:(DSWallet*)wallet;
+ (instancetype)providerOwnerKeysDerivationPathForWallet:(DSWallet*)wallet;
+ (instancetype)providerOperatorKeysDerivationPathForWallet:(DSWallet*)wallet;

- (NSData*)firstUnusedPublicKey;
- (DSKey*)firstUnusedPrivateKeyFromSeed:(NSData*)seed;
- (DSKey*)privateKeyForAddress:(NSString*)address fromSeed:(NSData*)seed;
- (DSKey*)privateKeyForHash160:(UInt160)hash160 fromSeed:(NSData*)seed;

@end

NS_ASSUME_NONNULL_END
