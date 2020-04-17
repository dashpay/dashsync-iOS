//
//  DSBLSKey.h
//  DashSync
//
//  Created by Sam Westrich on 11/3/18.
//

#import <Foundation/Foundation.h>
#import "BigIntTypes.h"
#import "DSKey.h"

NS_ASSUME_NONNULL_BEGIN

@class DSChain,DSDerivationPath;

@interface DSBLSKey : DSKey

@property (nonatomic,readonly) uint32_t publicKeyFingerprint;
@property (nonatomic,readonly) UInt256 chainCode;
@property (nonatomic,readonly) UInt256 secretKey;
@property (nonatomic,readonly) UInt384 publicKey;

+ (nullable instancetype)keyWithSeedData:(NSData *)data;
- (nullable instancetype)initWithSeedData:(NSData*)seedData;
+ (nullable instancetype)extendedPrivateKeyWithSeedData:(NSData *)seed;
- (nullable instancetype)initWithExtendedPrivateKeyWithSeedData:(NSData *)seed;
+ (nullable instancetype)keyWithExtendedPrivateKeyData:(NSData*)extendedPrivateKey;
- (nullable instancetype)initWithExtendedPrivateKeyData:(NSData*)extendedPrivateKey;
+ (nullable instancetype)keyWithExtendedPublicKeyData:(NSData*)extendedPublicKey;
- (nullable instancetype)initWithExtendedPublicKeyData:(NSData*)extendedPublicKey;
+ (nullable instancetype)keyWithPublicKey:(UInt384)publicKey;
- (nullable instancetype)initWithPublicKey:(UInt384)publicKey;
+ (nullable instancetype)keyWithPrivateKey:(UInt256)secretKey;
- (nullable instancetype)initWithPrivateKey:(UInt256)secretKey;
+ (nullable instancetype)keyByAggregatingPublicKeys:(NSArray<DSBLSKey*>*)publicKeys;

- (BOOL)verify:(UInt256)messageDigest signature:(UInt768)signature;
+ (BOOL)verify:(UInt256)messageDigest signature:(UInt768)signature withPublicKey:(UInt384)publicKey;
+ (BOOL)verifySecureAggregated:(UInt256)messageDigest signature:(UInt768)signature withPublicKeys:(NSArray*)publicKeys;

- (UInt768)signDigest:(UInt256)messageDigest;
- (UInt768)signData:(NSData *)data;
- (UInt768)signDataSingleSHA256:(NSData *)data;

- (NSData*)encryptData:(NSData*)data;

+ (UInt768)aggregateSignatures:(NSArray*)signatures withPublicKeys:(NSArray*)publicKeys withMessages:(NSArray*)messages;

@end

NS_ASSUME_NONNULL_END
