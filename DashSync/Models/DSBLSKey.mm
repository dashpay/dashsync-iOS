//
//  DSBLSKey.m
//  DashSync
//
//  Created by Sam Westrich on 11/3/18.
//

#import "DSBLSKey.h"
#import "NSMutableData+Dash.h"
#import "DSDerivationPath.h"
#import "NSIndexPath+Dash.h"
#import "DSChain.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wconversion"
#pragma clang diagnostic ignored "-Wunused-function"
#pragma clang diagnostic ignored "-Wconditional-uninitialized"
#import <bls-signatures-pod/bls.hpp>
#pragma clang diagnostic pop

@interface DSBLSKey ()

@property (nonatomic, assign) UInt256 seckey;
@property (nonatomic, assign) UInt384 pubkey;
@property (nonatomic, assign) UInt256 chainCode;
@property (nonatomic, strong) DSChain * chain;
@property (nonatomic, strong) NSData * extendedPrivateKeyData;
@property (nonatomic, strong) NSData * extendedPublicKeyData;

@end

@implementation DSBLSKey

//A little recursive magic since extended private keys can't be re-assigned in the library
+(bls::ExtendedPrivateKey)derive:(bls::ExtendedPrivateKey)extendedPrivateKey indexes:(NSIndexPath*)indexPath {
    if (!indexPath.length) return extendedPrivateKey;
    uint32_t topIndexPath = (uint32_t)[indexPath indexAtPosition:0];
    bls::ExtendedPrivateKey skChild = extendedPrivateKey.PrivateChild(topIndexPath);
    return [self derive:skChild indexes:[indexPath indexPathByRemovingFirstIndex]];
}

+(BOOL)canPublicDerive:(NSIndexPath*)indexPath {
    for (int i = 0; i < [indexPath length]; i++ ) {
        uint32_t index = (uint32_t)[indexPath indexAtPosition:0];
        if (index >> 31 == 1) return NO;
    }
    return YES;
}

+(bls::ExtendedPublicKey)publicDerive:(bls::ExtendedPublicKey)extendedPublicKey indexes:(NSIndexPath*)indexPath {
    if (!indexPath.length) return extendedPublicKey;
    uint32_t topIndexPath = (uint32_t)[indexPath indexAtPosition:0];
    NSAssert(topIndexPath >> 31 == 0, @"There should be no hardened derivation if you wish to derive extended public keys");
    bls::ExtendedPublicKey pkChild = extendedPublicKey.PublicChild(topIndexPath);
    return [self publicDerive:pkChild indexes:[indexPath indexPathByRemovingFirstIndex]];
}


+ (nullable instancetype)blsKeyWithPrivateKeyFromSeed:(NSData * _Nonnull)seed onChain:(DSChain*)chain {
    return [[DSBLSKey alloc] initWithPrivateKeyFromSeed:seed onChain:chain];
}

- (nullable instancetype)initWithPrivateKeyFromSeed:(NSData * _Nonnull)seed onChain:(DSChain*)chain {
    if (!(self = [super init])) return nil;
    
    bls::PrivateKey blsPrivateKey = bls::PrivateKey::FromSeed((uint8_t *)seed.bytes, seed.length);
    bls::PublicKey blsPublicKey = blsPrivateKey.GetPublicKey();
    UInt256 secret = UINT256_ZERO;
    blsPrivateKey.Serialize(secret.u8);
    self.seckey = secret;
    UInt384 publicKey = UINT384_ZERO;
    blsPublicKey.Serialize(publicKey.u8);
    self.pubkey = publicKey;
    
    self.chain = chain;
    
    return self;
}

+ (nullable instancetype)blsKeyWithExtendedPrivateKeyFromSeed:(NSData * _Nonnull)seed onChain:(DSChain*)chain {
    return [[DSBLSKey alloc] initWithExtendedPrivateKeyFromSeed:seed onChain:chain];
}

- (nullable instancetype)initWithExtendedPrivateKeyFromSeed:(NSData * _Nonnull)seed onChain:(DSChain*)chain {
    if (!(self = [super init])) return nil;
    
    bls::ExtendedPrivateKey blsExtendedPrivateKey = bls::ExtendedPrivateKey::FromSeed((uint8_t *)seed.bytes, seed.length);
    
    return [self initWithExtendedPrivateKey:blsExtendedPrivateKey onChain:chain];
}

- (nullable instancetype)initWithExtendedPrivateKey:(bls::ExtendedPrivateKey)blsExtendedPrivateKey onChain:(DSChain*)chain {
    if (!self || !(self = [super init])) return nil;
    
    uint8_t blsExtendedPrivateKeyBytes[bls::ExtendedPrivateKey::EXTENDED_PRIVATE_KEY_SIZE];
    
    blsExtendedPrivateKey.Serialize(blsExtendedPrivateKeyBytes);
    NSMutableData * blsExtendedPrivateKeyData = [NSMutableData secureDataWithCapacity:bls::ExtendedPrivateKey::EXTENDED_PRIVATE_KEY_SIZE];
    [blsExtendedPrivateKeyData appendBytes:blsExtendedPrivateKeyBytes length:bls::ExtendedPrivateKey::EXTENDED_PRIVATE_KEY_SIZE];
    self.extendedPrivateKeyData = blsExtendedPrivateKeyData;
    
    UInt256 blsChainCode;
    blsExtendedPrivateKey.GetChainCode().Serialize(blsChainCode.u8);
    self.chainCode = blsChainCode;
    
    bls::PrivateKey blsPrivateKey = blsExtendedPrivateKey.GetPrivateKey();
    bls::PublicKey blsPublicKey = blsPrivateKey.GetPublicKey();
    UInt256 secret = UINT256_ZERO;
    blsPrivateKey.Serialize(secret.u8);
    self.seckey = secret;
    UInt384 publicKey = UINT384_ZERO;
    blsPublicKey.Serialize(publicKey.u8);
    self.pubkey = publicKey;
    
    self.chain = chain;
    
    return self;
}

- (nullable instancetype)initWithExtendedPublicKey:(bls::ExtendedPublicKey)blsExtendedPublicKey onChain:(DSChain*)chain {
    if (!self || !(self = [super init])) return nil;
    
    uint8_t blsExtendedPublicKeyBytes[bls::ExtendedPublicKey::EXTENDED_PUBLIC_KEY_SIZE];
    
    blsExtendedPublicKey.Serialize(blsExtendedPublicKeyBytes);
    NSMutableData * blsExtendedPublicKeyData = [NSMutableData secureDataWithCapacity:bls::ExtendedPublicKey::EXTENDED_PUBLIC_KEY_SIZE];
    [blsExtendedPublicKeyData appendBytes:blsExtendedPublicKeyBytes length:bls::ExtendedPrivateKey::EXTENDED_PRIVATE_KEY_SIZE];
    self.extendedPublicKeyData = blsExtendedPublicKeyData;
    
    UInt256 blsChainCode;
    blsExtendedPublicKey.GetChainCode().Serialize(blsChainCode.u8);
    self.chainCode = blsChainCode;
    
    
    bls::PublicKey blsPublicKey = blsExtendedPublicKey.GetPublicKey();
    
    UInt384 publicKey = UINT384_ZERO;
    blsPublicKey.Serialize(publicKey.u8);
    self.pubkey = publicKey;
    
    self.chain = chain;
    
    return self;
}

-(uint32_t)publicKeyFingerprint {
    bls::PublicKey blsPublicKey = bls::PublicKey::FromBytes(self.pubkey.u8);
    return blsPublicKey.GetFingerprint();
}

-(DSBLSKey*)deriveToPath:(DSDerivationPath*)derivationPath {
    bls::ExtendedPrivateKey blsExtendedPrivateKey = bls::ExtendedPrivateKey::FromBytes((const uint8_t *)self.extendedPrivateKeyData.bytes);
    bls::ExtendedPrivateKey derivedExtendedPrivateKey = [DSBLSKey derive:blsExtendedPrivateKey indexes:derivationPath];
    return [[DSBLSKey alloc] initWithExtendedPrivateKey:derivedExtendedPrivateKey onChain:self.chain];
}

-(DSBLSKey*)publicDeriveToPath:(DSDerivationPath*)derivationPath {
    if (self.extendedPrivateKeyData.length) {
        bls::ExtendedPrivateKey blsExtendedPrivateKey = bls::ExtendedPrivateKey::FromBytes((const uint8_t *)self.extendedPrivateKeyData.bytes);
        
        if (![DSBLSKey canPublicDerive:derivationPath]) return nil;
        
        bls::ExtendedPublicKey derivedExtendedPublicKey = [DSBLSKey publicDerive:blsExtendedPrivateKey.GetExtendedPublicKey() indexes:derivationPath];
        return [[DSBLSKey alloc] initWithExtendedPublicKey:derivedExtendedPublicKey onChain:self.chain];
    } else if (self.extendedPublicKeyData.length) {
        bls::ExtendedPublicKey blsExtendedPublicKey = bls::ExtendedPublicKey::FromBytes((const uint8_t *)self.extendedPublicKeyData.bytes);
        
        if (![DSBLSKey canPublicDerive:derivationPath]) return nil;
        
        bls::ExtendedPublicKey derivedExtendedPublicKey = [DSBLSKey publicDerive:blsExtendedPublicKey indexes:derivationPath];
        return [[DSBLSKey alloc] initWithExtendedPublicKey:derivedExtendedPublicKey onChain:self.chain];
    } else {
        return nil;
    }
}


@end
