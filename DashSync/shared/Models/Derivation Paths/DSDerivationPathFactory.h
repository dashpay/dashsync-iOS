//
//  DSDerivationPathFactory.h
//  DashSync
//
//  Created by Sam Westrich on 2/10/19.
//

#import <Foundation/Foundation.h>
#import "DSKeyManager.h"
#import "DSDerivationPath.h"


NS_ASSUME_NONNULL_BEGIN

@class DSAuthenticationKeysDerivationPath, DSWallet, DSMasternodeHoldingsDerivationPath, DSDerivationPath, DSAssetLockDerivationPath;

typedef NS_ENUM(NSUInteger, DSDerivationPathKind) {
    DSDerivationPathKind_ProviderVoting = 0,
    DSDerivationPathKind_ProviderOwner = 1,
    DSDerivationPathKind_ProviderOperator = 2,
    DSDerivationPathKind_PlatformNode = 3,
    
    DSDerivationPathKind_IdentityRegistrationFunding = 4,
    DSDerivationPathKind_IdentityTopupFunding = 5,
    DSDerivationPathKind_InvitationFunding = 6,
    DSDerivationPathKind_IdentityBLS = 7,
    DSDerivationPathKind_IdentityECDSA = 8
};
@interface DSDerivationPathFactory : NSObject

+ (instancetype _Nullable)sharedInstance;

- (DSDerivationPath *)derivationPathOfKind:(DSDerivationPathKind)kind forWallet:(DSWallet *)wallet;
- (BOOL)hasExtendedPublicKeyForDerivationPathOfKind:(DSDerivationPathKind)kind forWallet:(DSWallet *)wallet;

- (DMaybeOpaqueKey *_Nullable)generateExtendedPublicKeyFromSeedForDerivationPathKind:(DSDerivationPathKind)kind fromSeed:(NSData *)seed forWallet:(DSWallet *)wallet;
- (DOpaqueKey *_Nullable)privateKeyAtIndexPath:(NSIndexPath *)indexPath fromSeed:(NSData *)seed ofKind:(DSDerivationPathKind)kind forWallet:(DSWallet *)wallet;

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
