//
//  DSMasternodeKeysDerivationPath.h
//  DashSync
//
//  Created by Sam Westrich on 2/10/19.
//

#import "dash_shared_core.h"
#import "DSDerivationPath+Protected.h"
#import "DSSimpleIndexedDerivationPath.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSAuthenticationKeysDerivationPath : DSSimpleIndexedDerivationPath

@property (nonatomic, readonly) BOOL hasExtendedPrivateKey;
@property (nonatomic, readonly) BOOL usesHardenedKeys;

+ (instancetype)providerVotingKeysDerivationPathForWallet:(DSWallet *)wallet;
+ (instancetype)providerOwnerKeysDerivationPathForWallet:(DSWallet *)wallet;
+ (instancetype)providerOperatorKeysDerivationPathForWallet:(DSWallet *)wallet;
+ (instancetype)platformNodeKeysDerivationPathForWallet:(DSWallet *)wallet;
+ (instancetype)blockchainIdentitiesBLSKeysDerivationPathForWallet:(DSWallet *)wallet;
+ (instancetype)blockchainIdentitiesECDSAKeysDerivationPathForWallet:(DSWallet *)wallet;

- (NSData *)firstUnusedPublicKey;
- (OpaqueKey *)firstUnusedPrivateKeyFromSeed:(NSData *)seed;
- (OpaqueKey *)privateKeyForAddress:(NSString *)address fromSeed:(NSData *)seed;
- (OpaqueKey *)privateKeyForHash160:(UInt160)hash160 fromSeed:(NSData *)seed;
- (NSData *)publicKeyDataForHash160:(UInt160)hash160;

- (OpaqueKey *_Nullable)privateKeyAtIndexPath:(NSIndexPath *)indexPath;

@end

NS_ASSUME_NONNULL_END
