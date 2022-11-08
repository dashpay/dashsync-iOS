//
//  DSBLSKey.h
//  DashSync
//
//  Created by Sam Westrich on 11/3/18.
//

#import "BigIntTypes.h"
#import "DSKey.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class DSChain, DSDerivationPath;

@interface DSBLSKey : DSKey

@property (nonatomic, readonly) uint32_t publicKeyFingerprint;
@property (nonatomic, readonly) BOOL useLegacy;
@property (nonatomic, readonly) UInt256 chainCode;
@property (nonatomic, readonly) UInt256 secretKey;
@property (nonatomic, readonly) UInt384 publicKey;

+ (nullable instancetype)keyWithSeedData:(NSData *)seedData useLegacy:(BOOL)useLegacy;
- (nullable instancetype)initWithSeedData:(NSData *)seedData useLegacy:(BOOL)useLegacy;
+ (nullable instancetype)extendedPrivateKeyWithSeedData:(NSData *)seed useLegacy:(BOOL)useLegacy;
- (nullable instancetype)initWithExtendedPrivateKeyWithSeedData:(NSData *)seed useLegacy:(BOOL)useLegacy;
+ (nullable instancetype)keyWithExtendedPrivateKeyData:(NSData *)extendedPrivateKey useLegacy:(BOOL)useLegacy;
- (nullable instancetype)initWithExtendedPrivateKeyData:(NSData *)extendedPrivateKey useLegacy:(BOOL)useLegacy;
+ (nullable instancetype)keyWithExtendedPublicKeyData:(NSData *)extendedPublicKey useLegacy:(BOOL)useLegacy;
- (nullable instancetype)initWithExtendedPublicKeyData:(NSData *)extendedPublicKey useLegacy:(BOOL)useLegacy;
+ (nullable instancetype)keyWithPublicKey:(UInt384)publicKey useLegacy:(BOOL)useLegacy;
- (nullable instancetype)initWithPublicKey:(UInt384)publicKey useLegacy:(BOOL)useLegacy;
+ (nullable instancetype)keyWithPrivateKey:(UInt256)secretKey useLegacy:(BOOL)useLegacy;
- (nullable instancetype)initWithPrivateKey:(UInt256)secretKey useLegacy:(BOOL)useLegacy;

- (BOOL)verify:(UInt256)messageDigest signature:(UInt768)signature;
+ (BOOL)verify:(UInt256)messageDigest signature:(UInt768)signature withPublicKey:(UInt384)publicKey useLegacy:(BOOL)useLegacy;
+ (BOOL)verifySecureAggregated:(UInt256)messageDigest signature:(UInt768)signature withPublicKeys:(NSArray *)publicKeys useLegacy:(BOOL)useLegacy;

+ (BOOL)verifyAggregatedSignature:(UInt768)signature withPublicKeys:(NSArray<DSBLSKey *> *)publicKeys withMessages:(NSArray *)messages useLegacy:(BOOL)useLegacy;
+ (NSData *_Nullable)publicKeyFromExtendedPublicKeyData:(NSData *)publicKeyData atIndexPath:(NSIndexPath *)indexPath useLegacy:(BOOL)useLegacy;

- (UInt768)signDigest:(UInt256)messageDigest;
- (UInt768)signData:(NSData *)data;
- (UInt768)signDataSingleSHA256:(NSData *)data;

- (NSData *)encryptData:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
