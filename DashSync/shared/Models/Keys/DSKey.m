//
//  DSKey.m
//  DashSync
//
//  Created by Sam Westrich on 2/14/19.
//

#import "DSKey.h"
#import "DSBLSKey.h"
#import "DSChain.h"
#import "DSECDSAKey.h"
#import "NSData+DSHash.h"
#import "NSData+Dash.h"
#import "NSMutableData+Dash.h"
#import "NSString+Bitcoin.h"
#import "NSString+Dash.h"

@interface DSKey ()

@property (nonatomic, strong) NSData *extendedPrivateKeyData;
@property (nonatomic, strong) NSData *extendedPublicKeyData;

@end

@implementation DSKey

- (UInt160)hash160 {
    return self.publicKeyData.hash160;
}

+ (NSString *)addressWithPublicKeyData:(NSData *)data forChain:(DSChain *)chain {
    NSParameterAssert(data);
    NSParameterAssert(chain);

    NSMutableData *d = [NSMutableData secureDataWithCapacity:160 / 8 + 1];
    uint8_t version;
    UInt160 hash160 = data.hash160;

    if ([chain isMainnet]) {
        version = DASH_PUBKEY_ADDRESS;
    } else {
        version = DASH_PUBKEY_ADDRESS_TEST;
    }

    [d appendBytes:&version
            length:1];
    [d appendBytes:&hash160 length:sizeof(hash160)];
    return [NSString base58checkWithData:d];
}

- (NSString *)addressForChain:(DSChain *)chain {
    NSParameterAssert(chain);

    return [DSKey addressWithPublicKeyData:self.publicKeyData forChain:chain];
}

+ (NSString *)randomAddressForChain:(DSChain *)chain {
    NSParameterAssert(chain);

    UInt160 randomNumber = UINT160_ZERO;
    for (int i = 0; i < 5; i++) {
        randomNumber.u32[i] = arc4random();
    }

    return [[NSData dataWithUInt160:randomNumber] addressFromHash160DataForChain:chain];
}

- (NSString *)serializedPrivateKeyForChain:(DSChain *)chain {
    return nil;
}

- (DSKeyType)keyType {
    return 0;
}

- (BOOL)verify:(UInt256)messageDigest signatureData:(NSData *)signature {
    NSAssert(NO, @"This should be overridden");
    return NO;
}

- (NSString *)localizedKeyType {
    switch (self.keyType) {
        case DSKeyType_ECDSA:
            return DSLocalizedString(@"ECDSA", nil);
        case DSKeyType_BLS:
            return DSLocalizedString(@"BLS", nil);
        default:
            return DSLocalizedString(@"Unknown Key Type", nil);
    }
}

+ (instancetype)keyWithDHKeyExchangeWithPublicKey:(DSKey *)publicKey forPrivateKey:(DSKey *)privateKey {
    return [[self alloc] initWithDHKeyExchangeWithPublicKey:publicKey forPrivateKey:privateKey];
}

- (nullable instancetype)initWithDHKeyExchangeWithPublicKey:(DSKey *)publicKey forPrivateKey:(DSKey *)privateKey {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

+ (nullable instancetype)keyWithSeedData:(NSData *)data forKeyType:(DSKeyType)keyType {
    switch (keyType) {
        case DSKeyType_BLS:
            return [DSBLSKey extendedPrivateKeyWithSeedData:data useLegacy:true];
        case DSKeyType_BLS_BASIC:
            return [DSBLSKey extendedPrivateKeyWithSeedData:data useLegacy:false];
        case DSKeyType_ECDSA:
            return [DSECDSAKey keyWithSeedData:data];
        default:
            return nil;
    }
}

+ (DSKey *)keyWithPublicKeyData:(NSData *)data forKeyType:(DSKeyType)keyType {
    switch (keyType) {
        case DSKeyType_BLS:
            return [DSBLSKey keyWithPublicKey:data.UInt384 useLegacy:true];
        case DSKeyType_BLS_BASIC:
            return [DSBLSKey keyWithPublicKey:data.UInt384 useLegacy:false];
        case DSKeyType_ECDSA:
            return [DSECDSAKey keyWithPublicKeyData:data];
        default:
            return nil;
    }
}

+ (DSKey *)keyWithPrivateKeyData:(NSData *)data forKeyType:(DSKeyType)keyType {
    switch (keyType) {
        case DSKeyType_BLS:
            return [DSBLSKey keyWithPrivateKey:data.UInt256 useLegacy:true];
        case DSKeyType_BLS_BASIC:
            return [DSBLSKey keyWithPrivateKey:data.UInt256 useLegacy:false];
        case DSKeyType_ECDSA:
            return [DSECDSAKey keyWithSecret:data.UInt256 compressed:YES];
        default:
            return nil;
    }
}

+ (DSKey *)keyWithExtendedPublicKeyData:(NSData *)data forKeyType:(DSKeyType)keyType {
    if (!data) return nil;
    switch (keyType) {
        case DSKeyType_BLS:
            return [DSBLSKey keyWithExtendedPublicKeyData:data useLegacy:true];
        case DSKeyType_BLS_BASIC:
            return [DSBLSKey keyWithExtendedPublicKeyData:data useLegacy:false];
        case DSKeyType_ECDSA:
            return [DSECDSAKey keyWithExtendedPublicKeyData:data];
        default:
            return nil;
    }
}

+ (DSKey *)keyWithExtendedPrivateKeyData:(NSData *)data forKeyType:(DSKeyType)keyType {
    if (!data) return nil;
    switch (keyType) {
        case DSKeyType_BLS:
            return [DSBLSKey keyWithExtendedPrivateKeyData:data useLegacy:true];
        case DSKeyType_BLS_BASIC:
            return [DSBLSKey keyWithExtendedPrivateKeyData:data useLegacy:false];
        case DSKeyType_ECDSA:
            return [DSECDSAKey keyWithExtendedPrivateKeyData:data];
        default:
            return nil;
    }
}

- (void)forgetPrivateKey {
}

- (instancetype)privateDeriveToPath:(NSIndexPath *)derivationPath {
    NSAssert(NO, @"This should be overridden");
    return nil;
}

- (instancetype)publicDeriveToPath:(NSIndexPath *)derivationPath {
    NSAssert(NO, @"This should be overridden");
    return nil;
}

- (nullable instancetype)privateDeriveTo256BitDerivationPath:(DSDerivationPath *)derivationPath {
    NSAssert(NO, @"This should be overridden");
    return nil;
}
- (nullable instancetype)publicDeriveTo256BitDerivationPath:(DSDerivationPath *)derivationPath {
    NSAssert(NO, @"This should be overridden");
    return nil;
}

- (nullable instancetype)publicDeriveTo256BitDerivationPath:(DSDerivationPath *)derivationPath derivationPathOffset:(NSUInteger)derivationPathOffset {
    NSAssert(NO, @"This should be overridden");
    return nil;
}

- (UInt256)HMAC256Data:(NSData *)data {
    NSAssert(NO, @"This should be overridden");
    return UINT256_ZERO;
}

- (void)signMessageDigest:(UInt256)digest completion:(void (^_Nullable)(BOOL success, NSData *signature))completion {
    NSAssert(NO, @"This should be overridden");
}

+ (NSData *_Nullable)publicKeyFromExtendedPublicKeyData:(NSData *)publicKeyData atIndexPath:(NSIndexPath *)indexPath {
    NSAssert(NO, @"This should be overridden");
    return [NSData data];
}

@end
