//
//  DSDerivationPathFactory.h
//  DashSync
//
//  Created by Sam Westrich on 2/10/19.
//

#import <Foundation/Foundation.h>
#import "DSKeyManager.h"


NS_ASSUME_NONNULL_BEGIN

@class DSAuthenticationKeysDerivationPath, DSWallet, DSMasternodeHoldingsDerivationPath, DSDerivationPath, DSAssetLockDerivationPath;

@interface DSDerivationPathFactory : NSObject

+ (instancetype _Nullable)sharedInstance;

- (DSAuthenticationKeysDerivationPath *)providerVotingKeysDerivationPathForWallet:(DSWallet *)wallet;
- (DSAuthenticationKeysDerivationPath *)providerOwnerKeysDerivationPathForWallet:(DSWallet *)wallet;
- (DSAuthenticationKeysDerivationPath *)providerOperatorKeysDerivationPathForWallet:(DSWallet *)wallet;
- (DSAuthenticationKeysDerivationPath *)platformNodeKeysDerivationPathForWallet:(DSWallet *)wallet;
- (DSMasternodeHoldingsDerivationPath *)providerFundsDerivationPathForWallet:(DSWallet *)wallet;

- (DSAssetLockDerivationPath *)identityRegistrationFundingDerivationPathForWallet:(DSWallet *)wallet;
- (DSAssetLockDerivationPath *)identityTopupFundingDerivationPathForWallet:(DSWallet *)wallet;
- (DSAssetLockDerivationPath *)identityInvitationFundingDerivationPathForWallet:(DSWallet *)wallet;
- (DSAuthenticationKeysDerivationPath *)identityBLSKeysDerivationPathForWallet:(DSWallet *)wallet;
- (DSAuthenticationKeysDerivationPath *)identityECDSAKeysDerivationPathForWallet:(DSWallet *)wallet;

- (NSArray<DSDerivationPath *> *)loadedSpecializedDerivationPathsForWallet:(DSWallet *)wallet;
- (NSArray<DSDerivationPath *> *)unloadedSpecializedDerivationPathsForWallet:(DSWallet *)wallet;
- (NSArray<DSDerivationPath *> *)specializedDerivationPathsNeedingExtendedPublicKeyForWallet:(DSWallet *)wallet;

- (NSArray<DSDerivationPath *> *)fundDerivationPathsNeedingExtendedPublicKeyForWallet:(DSWallet *)wallet;





+ (DMaybeOpaqueKeys *)privateKeysAtIndexPaths:(NSArray *)indexPaths
                                     fromSeed:(NSData *)seed
                               derivationPath:(DSDerivationPath *)derivationPath;
+ (NSArray<NSString *> *)serializedPrivateKeysAtIndexPaths:(NSArray *)indexPaths
                                      fromSeed:(NSData *)seed
                                derivationPath:(DSDerivationPath *)derivationPath;
+ (NSString *_Nullable)serializedExtendedPublicKey:(DSDerivationPath *)derivationPath;

+ (NSString *)serializedExtendedPrivateKeyFromSeed:(NSData *)seed
                                    derivationPath:(DSDerivationPath *)derivationPath;
+ (NSData *)deserializedExtendedPublicKey:(NSString *)extendedPublicKeyString onChain:(DSChain *)chain;
+ (NSData *)deserializedExtendedPublicKey:(NSString *)extendedPublicKeyString
                                  onChain:(DSChain *)chain
                                   rDepth:(uint8_t *)depth
                        rTerminalHardened:(BOOL *)terminalHardened
                           rTerminalIndex:(UInt256 *)terminalIndex;
+ (NSData *)deserializedExtendedPublicKey:(DSDerivationPath *)derivationPath extendedPublicKeyString:(NSString *)extendedPublicKeyString;

+ (NSString *)standaloneExtendedPublicKeyLocationStringForUniqueID:(NSString *)uniqueID;
+ (NSString *)standaloneInfoDictionaryLocationStringForUniqueID:(NSString *)uniqueID;
+ (NSString *)walletBasedExtendedPublicKeyLocationStringForUniqueID:(NSString *)uniqueID;
+ (NSString *)walletBasedExtendedPrivateKeyLocationStringForUniqueID:(NSString *)uniqueID;


+ (NSString *)stringRepresentationOfIndex:(UInt256)index hardened:(BOOL)hardened inContext:(NSManagedObjectContext *)context;

@end

NS_ASSUME_NONNULL_END
