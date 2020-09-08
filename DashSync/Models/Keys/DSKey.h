//
//  DSKey.h
//  DashSync
//
//  Created by Sam Westrich on 2/14/19.
//

#import <Foundation/Foundation.h>
#import "BigIntTypes.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, DSKeyType) {
    DSKeyType_ECDSA = 0,
    DSKeyType_BLS = 1,
};

@class DSChain, DSDerivationPath;

@interface DSKey : NSObject

@property (nullable, nonatomic, readonly) NSData *extendedPublicKeyData;
@property (nullable, nonatomic, readonly) NSData *extendedPrivateKeyData;
@property (nullable, nonatomic, readonly) NSData *publicKeyData;
@property (nullable, nonatomic, readonly) NSData *privateKeyData;
@property (nonatomic,readonly) UInt160 hash160;
@property (nonatomic,readonly) NSString * secretKeyString;
@property (nonatomic,readonly) DSKeyType keyType;
@property (nonatomic,readonly) NSString * localizedKeyType;

- (void)forgetPrivateKey;
- (BOOL)verify:(UInt256)messageDigest signatureData:(NSData*)signature;
- (NSString *)addressForChain:(DSChain*)chain;
+ (NSString *)randomAddressForChain:(DSChain*)chain;
+ (NSString *)addressWithPublicKeyData:(NSData*)data forChain:(DSChain*)chain;
- (NSString * _Nullable)serializedPrivateKeyForChain:(DSChain*)chain;

+ (nullable instancetype)keyWithSeedData:(NSData*)data forKeyType:(DSKeyType)keyType;
+ (nullable instancetype)keyWithPublicKeyData:(NSData*)data forKeyType:(DSKeyType)keyType;
+ (nullable instancetype)keyWithPrivateKeyData:(NSData*)data forKeyType:(DSKeyType)keyType;
+ (nullable instancetype)keyWithExtendedPrivateKeyData:(NSData*)extendedPrivateKeyData forKeyType:(DSKeyType)keyType;
+ (nullable instancetype)keyWithExtendedPublicKeyData:(NSData*)extendedPublicKeyData forKeyType:(DSKeyType)keyType;
+ (nullable instancetype)keyWithDHKeyExchangeWithPublicKey:(DSKey *)publicKey forPrivateKey:(DSKey*)privateKey;

- (nullable instancetype)privateDeriveToPath:(NSIndexPath*)derivationPath;
- (nullable instancetype)publicDeriveToPath:(NSIndexPath*)derivationPath;
- (nullable instancetype)privateDeriveTo256BitDerivationPath:(DSDerivationPath*)derivationPath;
- (nullable instancetype)publicDeriveTo256BitDerivationPath:(DSDerivationPath*)derivationPath;
- (nullable instancetype)publicDeriveTo256BitDerivationPath:(DSDerivationPath*)derivationPath derivationPathOffset:(NSUInteger)derivationPathOffset;

- (nullable instancetype)initWithDHKeyExchangeWithPublicKey:(DSKey*)publicKey forPrivateKey:(DSKey*)privateKey;

- (UInt256)HMAC256Data:(NSData*)data;

- (nullable instancetype)publicCopy;

@end

NS_ASSUME_NONNULL_END
