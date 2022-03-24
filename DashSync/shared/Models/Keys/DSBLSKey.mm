//
//  DSBLSKey.m
//  DashSync
//
//  Created by Sam Westrich on 11/3/18.
//

#import "DSBLSKey+Private.h"
#import "DSChain.h"
#import "DSDerivationPath.h"
#import "DSKey+Protected.h"
#import "NSData+Dash.h"
#import "NSData+Encryption.h"
#import "NSIndexPath+Dash.h"
#import "NSMutableData+Dash.h"
#import "NSString+Dash.h"
#import <CommonCrypto/CommonCryptor.h>

#define BLS_USE_LEGACY TRUE

@interface DSBLSKey ()

@property (nonatomic, assign) UInt256 secretKey;
@property (nonatomic, assign) UInt384 publicKey;
@property (nonatomic, assign) UInt256 chainCode;

@end

@implementation DSBLSKey

//A little recursive magic since extended private keys can't be re-assigned in the library
+ (bls::ExtendedPrivateKey)derive:(bls::ExtendedPrivateKey)extendedPrivateKey indexes:(NSIndexPath *)indexPath {
    if (!indexPath.length) return extendedPrivateKey;
    uint32_t topIndexPath = (uint32_t)[indexPath indexAtPosition:0];
    bls::ExtendedPrivateKey skChild = extendedPrivateKey.PrivateChild(topIndexPath);
    return [self derive:skChild indexes:[indexPath indexPathByRemovingFirstIndex]];
}

+ (BOOL)canPublicDerive:(NSIndexPath *)indexPath {
    for (int i = 0; i < [indexPath length]; i++) {
        uint32_t index = (uint32_t)[indexPath indexAtPosition:0];
        if (index >> 31 == 1) return NO;
    }
    return YES;
}

+ (bls::ExtendedPublicKey)publicDerive:(bls::ExtendedPublicKey)extendedPublicKey indexes:(NSIndexPath *)indexPath {
    if (!indexPath.length) return extendedPublicKey;
    uint32_t topIndexPath = (uint32_t)[indexPath indexAtPosition:0];
    NSAssert(topIndexPath >> 31 == 0, @"There should be no hardened derivation if you wish to derive extended public keys");
    bls::ExtendedPublicKey pkChild = extendedPublicKey.PublicChild(topIndexPath);
    return [self publicDerive:pkChild indexes:[indexPath indexPathByRemovingFirstIndex]];
}

+ (nullable instancetype)keyWithSeedData:(NSData *)seedData {
    return [[DSBLSKey alloc] initWithSeedData:seedData];
}

- (nullable instancetype)initWithSeedData:(NSData *)seedData {
    if (!(self = [super init])) return nil;
    bls::PrivateKey blsPrivateKey = bls::PrivateKey::FromSeedBIP32(bls::Bytes((uint8_t *)seedData.bytes, seedData.length));
    bls::G1Element blsPublicKey = blsPrivateKey.GetG1Element();
    UInt256 secret = UINT256_ZERO;
    blsPrivateKey.Serialize(secret.u8);
    self.secretKey = secret;
    UInt384 publicKey = [NSData dataWithBytes:blsPublicKey.Serialize(BLS_USE_LEGACY).data() length:sizeof(UInt384)].UInt384;
    self.publicKey = publicKey;

    return self;
}

+ (nullable instancetype)extendedPrivateKeyWithSeedData:(NSData *)seed {
    return [[DSBLSKey alloc] initWithExtendedPrivateKeyWithSeedData:seed];
}

+ (nullable instancetype)keyWithPublicKey:(UInt384)publicKey {
    return [[DSBLSKey alloc] initWithPublicKey:publicKey];
}

- (nullable instancetype)initWithPublicKey:(UInt384)publicKey {
    if (!(self = [super init])) return nil;
    self.publicKey = publicKey;

    return self;
}

+ (nullable instancetype)keyWithPrivateKey:(UInt256)secretKey {
    return [[DSBLSKey alloc] initWithPrivateKey:secretKey];
}

- (nullable instancetype)initWithPrivateKey:(UInt256)secretKey {
    if (!(self = [super init])) return nil;
    self.secretKey = secretKey;
    bls::PrivateKey blsPrivateKey = bls::PrivateKey::FromBytes(bls::Bytes((const uint8_t *)secretKey.u8, sizeof(UInt256)), BLS_USE_LEGACY);
    bls::G1Element blsPublicKey = blsPrivateKey.GetG1Element();
    UInt384 publicKey = [NSData dataWithBytes:blsPublicKey.Serialize(BLS_USE_LEGACY).data() length:sizeof(UInt384)].UInt384;
    self.publicKey = publicKey;

    return self;
}

+ (nullable instancetype)keyWithExtendedPublicKeyData:(NSData *)extendedPublicKey {
    return [[DSBLSKey alloc] initWithExtendedPublicKeyData:extendedPublicKey];
}

+ (nullable instancetype)keyWithExtendedPrivateKeyData:(NSData *)extendedPrivateKey {
    return [[DSBLSKey alloc] initWithExtendedPrivateKeyData:extendedPrivateKey];
}

- (nullable instancetype)initWithExtendedPublicKeyData:(NSData *)extendedPublicKey {
    
    bls::ExtendedPublicKey extendedPublicBLSKey = bls::ExtendedPublicKey::FromBytes(bls::Bytes((const uint8_t *)extendedPublicKey.bytes, extendedPublicKey.length), BLS_USE_LEGACY);
    return [self initWithBLSExtendedPublicKey:extendedPublicBLSKey];
}

- (nullable instancetype)initWithExtendedPrivateKeyData:(NSData *)extendedPrivateKey {
    bls::ExtendedPrivateKey extendedPrivateBLSKey = bls::ExtendedPrivateKey::FromBytes(bls::Bytes((const uint8_t *)extendedPrivateKey.bytes, extendedPrivateKey.length));
    return [self initWithBLSExtendedPrivateKey:extendedPrivateBLSKey];
}

- (nullable instancetype)initWithExtendedPrivateKeyWithSeedData:(NSData *)seed {
    if (!(self = [super init])) return nil;
    
    bls::ExtendedPrivateKey blsExtendedPrivateKey = bls::ExtendedPrivateKey::FromSeed(bls::Bytes((const uint8_t *)seed.bytes, seed.length));

    return [self initWithBLSExtendedPrivateKey:blsExtendedPrivateKey];
}

- (nullable instancetype)initWithBLSExtendedPrivateKey:(bls::ExtendedPrivateKey)blsExtendedPrivateKey {
    if (!self || !(self = [super init])) return nil;

    uint8_t blsExtendedPrivateKeyBytes[bls::ExtendedPrivateKey::SIZE];

    blsExtendedPrivateKey.Serialize(blsExtendedPrivateKeyBytes);
    NSMutableData *blsExtendedPrivateKeyData = [NSMutableData secureDataWithCapacity:bls::ExtendedPrivateKey::SIZE];
    [blsExtendedPrivateKeyData appendBytes:blsExtendedPrivateKeyBytes length:bls::ExtendedPrivateKey::SIZE];
    self.extendedPrivateKeyData = blsExtendedPrivateKeyData;

    uint8_t blsExtendedPublicKeyBytes[bls::ExtendedPublicKey::SIZE];

    blsExtendedPrivateKey.GetExtendedPublicKey().Serialize(blsExtendedPublicKeyBytes);

    NSMutableData *blsExtendedPublicKeyData = [NSMutableData secureDataWithCapacity:bls::ExtendedPublicKey::SIZE];
    [blsExtendedPublicKeyData appendBytes:blsExtendedPublicKeyBytes length:bls::ExtendedPublicKey::SIZE];
    self.extendedPublicKeyData = blsExtendedPublicKeyData;

    UInt256 blsChainCode;
    blsExtendedPrivateKey.GetChainCode().Serialize(blsChainCode.u8);
    self.chainCode = blsChainCode;

    bls::PrivateKey blsPrivateKey = blsExtendedPrivateKey.GetPrivateKey();
    bls::G1Element blsPublicKey = blsPrivateKey.GetG1Element();
    UInt256 secret = UINT256_ZERO;
    blsPrivateKey.Serialize(secret.u8);
    self.secretKey = secret;
    UInt384 publicKey = [NSData dataWithBytes:blsPublicKey.Serialize(BLS_USE_LEGACY).data() length:sizeof(UInt384)].UInt384;
    self.publicKey = publicKey;

    return self;
}

- (nullable instancetype)initWithBLSExtendedPublicKey:(bls::ExtendedPublicKey)blsExtendedPublicKey {
    if (!self || !(self = [super init])) return nil;

    uint8_t blsExtendedPublicKeyBytes[bls::ExtendedPublicKey::SIZE];

    blsExtendedPublicKey.Serialize(blsExtendedPublicKeyBytes);
    NSMutableData *blsExtendedPublicKeyData = [NSMutableData secureDataWithCapacity:bls::ExtendedPublicKey::SIZE];
    [blsExtendedPublicKeyData appendBytes:blsExtendedPublicKeyBytes length:bls::ExtendedPublicKey::SIZE];
    self.extendedPublicKeyData = blsExtendedPublicKeyData;

    UInt256 blsChainCode;
    blsExtendedPublicKey.GetChainCode().Serialize(blsChainCode.u8);
    self.chainCode = blsChainCode;

    self.secretKey = UINT256_ZERO;

    bls::G1Element blsPublicKey = blsExtendedPublicKey.GetPublicKey();

    UInt384 publicKey = [NSData dataWithBytes:blsPublicKey.Serialize(BLS_USE_LEGACY).data() length:sizeof(UInt384)].UInt384;
    self.publicKey = publicKey;

    return self;
}

- (nullable instancetype)initWithDHKeyExchangeWithPublicKey:(DSKey *)publicKey forPrivateKey:(DSKey *)privateKey {
    NSParameterAssert(publicKey);
    NSParameterAssert(privateKey);
    NSAssert([publicKey isKindOfClass:[DSBLSKey class]], @"The public key needs to be a BLS key");
    NSAssert([privateKey isKindOfClass:[DSBLSKey class]], @"The privateKey key needs to be a BLS key");
    if (!(self = [self init])) return nil;

    const bls::G1Element blsPublicKey = ((DSBLSKey *)publicKey).blsPublicKey;
    const bls::PrivateKey blsPrivateKey = ((DSBLSKey *)privateKey).blsPrivateKey;

    const bls::G1Element dhBLSPublicKey = blsPrivateKey*blsPublicKey;

    UInt384 dhPublicKey = [NSData dataWithBytes:dhBLSPublicKey.Serialize(BLS_USE_LEGACY).data() length:sizeof(UInt384)].UInt384;
    
    return [self initWithPublicKey:dhPublicKey];
}

- (uint32_t)publicKeyFingerprint {
    bls::G1Element blsPublicKey = bls::G1Element::FromBytes(bls::Bytes(self.publicKey.u8, sizeof(UInt384)));
    return blsPublicKey.GetFingerprint();
}

- (NSData *)publicKeyData {
    return [NSData dataWithUInt384:self.publicKey];
}

- (NSData *)privateKeyData {
    if (uint256_is_zero(self.secretKey)) return nil;
    return [NSData dataWithUInt256:self.secretKey];
}

- (NSString *)secretKeyString {
    if (uint256_is_zero(self.secretKey)) return @"";
    return [NSData dataWithUInt256:self.secretKey].hexString;
}

- (NSString *)serializedPrivateKeyForChain:(DSChain *)chain {
    if (uint256_is_zero(self.secretKey)) return nil;

    NSMutableData *d = [NSMutableData secureDataWithCapacity:sizeof(UInt256) + 2];
    uint8_t version;
    if ([chain isMainnet]) {
        version = DASH_PRIVKEY;
    } else {
        version = DASH_PRIVKEY_TEST;
    }

    [d appendBytes:&version
            length:1];
    [d appendUInt256:self.secretKey];
    [d appendBytes:"\x02" length:1];
    return [NSString base58checkWithData:d];
}

- (DSKeyType)keyType {
    return DSKeyType_BLS;
}

- (void)forgetPrivateKey {
    self.secretKey = UINT256_ZERO;
}

// MARK: - Derivation

- (instancetype)privateDeriveTo256BitDerivationPath:(DSDerivationPath *)derivationPath {
    return [self privateDeriveToPath:[derivationPath baseIndexPath]];
}

- (DSBLSKey *)privateDeriveToPath:(NSIndexPath *)derivationPath {
    bls::ExtendedPrivateKey blsExtendedPrivateKey = bls::ExtendedPrivateKey::FromBytes(bls::Bytes((const uint8_t *)self.extendedPrivateKeyData.bytes, self.extendedPrivateKeyData.length));
    bls::ExtendedPrivateKey derivedExtendedPrivateKey = [DSBLSKey derive:blsExtendedPrivateKey indexes:derivationPath];
    return [[DSBLSKey alloc] initWithBLSExtendedPrivateKey:derivedExtendedPrivateKey];
}

- (DSBLSKey *)publicDeriveToPath:(NSIndexPath *)derivationPath {
    if (!self.extendedPublicKeyData.length && !self.extendedPrivateKeyData.length) return nil;
    bls::ExtendedPublicKey blsExtendedPublicKey = [self blsExtendedPublicKey];

    bls::ExtendedPublicKey derivedExtendedPublicKey = [DSBLSKey publicDerive:blsExtendedPublicKey indexes:derivationPath];
    return [[DSBLSKey alloc] initWithBLSExtendedPublicKey:derivedExtendedPublicKey];
}

- (DSKey *)extendedPublicKey {
    if (!self.extendedPublicKeyData.length) return nil;
    return [[DSBLSKey alloc] initWithBLSExtendedPublicKey:[self blsExtendedPublicKey]];
}

- (bls::ExtendedPublicKey)blsExtendedPublicKey {
    if (self.extendedPublicKeyData.length) {
        bls::ExtendedPublicKey blsExtendedPublicKey = bls::ExtendedPublicKey::FromBytes(bls::Bytes((const uint8_t *)self.extendedPublicKeyData.bytes, self.extendedPublicKeyData.length), BLS_USE_LEGACY);

        return blsExtendedPublicKey;
    } else if (self.extendedPrivateKeyData.length) {
        bls::ExtendedPrivateKey blsExtendedPrivateKey = bls::ExtendedPrivateKey::FromBytes(bls::Bytes((const uint8_t *)self.extendedPrivateKeyData.bytes, self.extendedPrivateKeyData.length));

        return blsExtendedPrivateKey.GetExtendedPublicKey(BLS_USE_LEGACY);
    } else {
        uint8_t bytes[] = {};
        return bls::ExtendedPublicKey::FromBytes(bls::Bytes((const uint8_t *)bytes, 0), BLS_USE_LEGACY);
    }
}

- (DSKey *)extendedPrivateKey {
    if (!self.extendedPrivateKeyData.length) return nil;
    return [[DSBLSKey alloc] initWithBLSExtendedPrivateKey:[self blsExtendedPrivateKey]];
}

- (bls::ExtendedPrivateKey)blsExtendedPrivateKey {
    if (self.extendedPrivateKeyData.length) {
        bls::ExtendedPrivateKey blsExtendedPrivateKey = bls::ExtendedPrivateKey::FromBytes(bls::Bytes((const uint8_t *)self.extendedPrivateKeyData.bytes, self.extendedPrivateKeyData.length));

        return blsExtendedPrivateKey;
    } else {
        uint8_t bytes[] = {};
        return bls::ExtendedPrivateKey::FromBytes(bls::Bytes((const uint8_t *)bytes, 0));
    }
}

- (bls::PrivateKey)blsPrivateKey {
    if (uint256_is_not_zero(self.secretKey)) {
        bls::PrivateKey blsPrivateKey = bls::PrivateKey::FromBytes(bls::Bytes(self.secretKey.u8, sizeof(UInt256)));

        return blsPrivateKey;
    } else if (self.extendedPrivateKeyData.length) {
        bls::ExtendedPrivateKey blsExtendedPrivateKey = bls::ExtendedPrivateKey::FromBytes(bls::Bytes((const uint8_t *)self.extendedPrivateKeyData.bytes, self.extendedPrivateKeyData.length));
        return blsExtendedPrivateKey.GetPrivateKey();
    } else {
        bls::PrivateKey blsPrivateKey = bls::PrivateKey::FromBytes(bls::Bytes(self.secretKey.u8, sizeof(UInt256)));
        return blsPrivateKey;
    }
}

- (bls::G1Element)blsPublicKey {
    if (!uint384_is_zero(self.publicKey)) {
        bls::G1Element blsPublicKey = bls::G1Element::FromBytes(bls::Bytes(self.publicKey.u8, sizeof(UInt384)), BLS_USE_LEGACY);

        return blsPublicKey;
    } else {
        bls::PrivateKey blsPrivateKey = [self blsPrivateKey];
        bls::G1Element blsPublicKey = blsPrivateKey.GetG1Element();
        return blsPublicKey;
    }
}

// MARK: - Signing

- (UInt768)signData:(NSData *)data {
    if (uint256_is_zero(self.secretKey) && !self.extendedPrivateKeyData.length) return UINT768_ZERO;
    bls::PrivateKey blsPrivateKey = [self blsPrivateKey];
    UInt256 hash = [data SHA256_2];
    bls::G2Element blsSignature = bls::LegacySchemeMPL().Sign(blsPrivateKey, bls::Bytes(hash.u8, sizeof(UInt256)));
    UInt768 signature = [NSData dataWithBytes:blsSignature.Serialize(BLS_USE_LEGACY).data() length:sizeof(UInt768)].UInt768;
    return signature;
}

- (UInt768)signDataSingleSHA256:(NSData *)data {
    if (uint256_is_zero(self.secretKey) && !self.extendedPrivateKeyData.length) return UINT768_ZERO;
    bls::PrivateKey blsPrivateKey = [self blsPrivateKey];
    UInt256 hash = [data SHA256];
    bls::G2Element blsSignature = bls::LegacySchemeMPL().Sign(blsPrivateKey, bls::Bytes(hash.u8, sizeof(UInt256)));
    UInt768 signature = [NSData dataWithBytes:blsSignature.Serialize(BLS_USE_LEGACY).data() length:sizeof(UInt768)].UInt768;
    return signature;
}

- (UInt768)signDigest:(UInt256)md {
    if (uint256_is_zero(self.secretKey) && !self.extendedPrivateKeyData.length) return UINT768_ZERO;
    bls::PrivateKey blsPrivateKey = [self blsPrivateKey];
    bls::G2Element blsSignature = bls::LegacySchemeMPL().Sign(blsPrivateKey, bls::Bytes(md.u8, sizeof(UInt256)));
    UInt768 signature = [NSData dataWithBytes:blsSignature.Serialize(BLS_USE_LEGACY).data() length:sizeof(UInt768)].UInt768;
    return signature;
}

- (void)signMessageDigest:(UInt256)digest completion:(void (^_Nullable)(BOOL success, NSData *signature))completion {
    NSParameterAssert(completion);
    NSData *signatureData = nil;
    UInt768 signature = [self signDigest:digest];
    BOOL success = uint768_is_not_zero(signature);
    if (success) {
        signatureData = uint768_data(signature);
    }
    completion(success, signatureData);
}

// MARK: - HMAC

- (UInt256)HMAC256Data:(NSData *)data {
    return [data HMACSHA256WithKey:self.secretKey];
}

// MARK: - Encryption

- (NSData *)encryptData:(NSData *)data {
    return [data encryptWithDHKey:self];
}

// MARK: - Verification

- (BOOL)verify:(UInt256)messageDigest signatureData:(NSData *)signatureData {
    return [self verify:messageDigest signature:signatureData.UInt768];
}

- (BOOL)verify:(UInt256)messageDigest signature:(UInt768)signature {
    bls::G1Element blsPublicKey = [self blsPublicKey];
    BOOL isLegacy = !uint384_is_zero(self.publicKey);
    bls::G2Element blsSignature = bls::G2Element::FromBytes(bls::Bytes(signature.u8, sizeof(UInt768)), isLegacy);
    return bls::LegacySchemeMPL().Verify(blsPublicKey, bls::Bytes(messageDigest.u8, sizeof(UInt256)), blsSignature);
}


+ (BOOL)verify:(UInt256)messageDigest signature:(UInt768)signature withPublicKey:(UInt384)publicKey {
    bls::G1Element blsPublicKey = [[[DSBLSKey alloc] initWithPublicKey:publicKey] blsPublicKey];
    bls::G2Element blsSignature = bls::G2Element::FromBytes(bls::Bytes(signature.u8, sizeof(UInt768)));
    return bls::LegacySchemeMPL().Verify(blsPublicKey, bls::Bytes(messageDigest.u8, sizeof(UInt256)), blsSignature);
}

+ (BOOL)verifySecureAggregated:(UInt256)messageDigest signature:(UInt768)signature withPublicKeys:(NSArray *)publicKeys {
    std::vector<bls::G1Element> blsPubKeys;
    for (DSBLSKey *key in publicKeys) {
        blsPubKeys.push_back([key blsPublicKey]);
    }

    bls::G2Element blsSignature = bls::G2Element::FromBytes(bls::Bytes(signature.u8, sizeof(UInt768)), BLS_USE_LEGACY);

    return bls::LegacySchemeMPL().VerifySecure(blsPubKeys, blsSignature, bls::Bytes(messageDigest.u8, sizeof(UInt256)));
}

+ (BOOL)verifyAggregatedSignature:(UInt768)signature withPublicKeys:(NSArray *)publicKeys withMessages:(NSArray *)messages {
    std::vector<bls::G1Element> blsPubKeys;
    std::vector<bls::Bytes> blsMessages;
    for (uint32_t i = 0; i < publicKeys.count; i++) {
        DSBLSKey *key = publicKeys[i];
        NSData *message = messages[i];
        blsPubKeys.push_back([key blsPublicKey]);
        blsMessages.push_back(bls::Bytes((const uint8_t *)message.bytes, message.length));
    }

    bls::G2Element blsSignature = bls::G2Element::FromBytes(bls::Bytes(signature.u8, sizeof(UInt768)), BLS_USE_LEGACY);

    return bls::LegacySchemeMPL().AggregateVerify(blsPubKeys, blsMessages, blsSignature);
}

//// MARK: - Signature Aggregation
//
//+ (UInt768)aggregateSignatures:(NSArray *)signatures withPublicKeys:(NSArray<DSBLSKey *> *)publicKeys withMessages:(NSArray *)messages {
//    std::vector<bls::G2Element> blsSignatures = {};
//    for (int i = 0; i < [signatures count]; i++) {
//        NSData *signatureData = signatures[i];
//        NSData *publicKeyData = publicKeys[i].publicKeyData;
//        NSData *messageData = messages[i];
//        UInt768 signature = [signatureData UInt768];
//        UInt384 publickey = [publicKeyData UInt384];
//        bls::G1Element blsPublicKey = bls::G1Element::FromBytes(publickey.u8);
//        bls::AggregationInfo aggregationInfo = bls::AggregationInfo::FromMsg(blsPublicKey, (const uint8_t *)messageData.bytes, messageData.length);
//        bls::G2Element blsSignature = bls::G2Element::FromBytes(signature.u8, aggregationInfo);
//        blsSignatures.push_back(blsSignature);
//    }
//    bls::G2Element blsAggregateSignature = bls::G2Element::AggregateSigs(blsSignatures);
//    UInt768 signature = UINT768_ZERO;
//    blsAggregateSignature.Serialize(signature.u8);
//    return signature;
//}

@end
