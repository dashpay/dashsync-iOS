//  
//  Created by Vladimir Pirogov
//  Copyright © 2023 Dash Core Group. All rights reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://opensource.org/licenses/MIT
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "dash_shared_core.h"
#import "DSChain.h"
#import "DSDerivationPath+Protected.h"
#import "DSKeyManager.h"
#import "NSIndexPath+FFI.h"

// Main purpose of this class is to organize work with rust bindings for keys and internal cache

@interface DSKeyManager ()

@property (nonatomic, strong) DSChain *chain;
@property (nonatomic, assign, nullable) KeysCache *keysCache;

@end


@implementation DSKeyManager

- (instancetype)initWithChain:(DSChain *)chain {
    NSParameterAssert(chain);
    if (!(self = [super init])) return nil;
    _keysCache = [DSKeyManager createKeysCache];
    NSLog(@"DSKeyManager.initWithChain: %@: ", chain);
    return self;
}

- (void)dealloc {
    [DSKeyManager destroyKeysCache:self.keysCache];
}

+ (KeysCache *)createKeysCache {
    return keys_create_cache();
}

+ (void)destroyKeysCache:(KeysCache *)cache {
    keys_destroy_cache(cache);
}

+ (BOOL)hasPrivateKey:(OpaqueKey *)key {
    return key_has_private_key(key);
}

+ (BOOL)keysPublicKeyDataIsEqual:(OpaqueKey *)key1 key2:(OpaqueKey *)key2 {
    if (key1 == NULL || key2 == NULL) return false;
    return keys_public_key_data_is_equal(key1, key2);
}

+ (NSString *)secretKeyHexString:(OpaqueKey *)key {
    return [DSKeyManager NSStringFrom:key_secret_key_string(key)];
}

+ (OpaqueKey *_Nullable)keyWithPrivateKeyData:(NSData *)data ofType:(KeyKind)keyType {
    return key_create_with_private_key_data(data.bytes, data.length, (int16_t) keyType);
}

+ (OpaqueKey *_Nullable)keyWithPublicKeyData:(NSData *)data ofType:(KeyKind)keyType {
    return key_create_with_public_key_data(data.bytes, data.length, (int16_t) keyType);
}

+ (OpaqueKey *_Nullable)keyWithExtendedPublicKeyData:(NSData *)data ofType:(KeyKind)keyType {
    return key_create_from_extended_public_key_data(data.bytes, data.length, (int16_t) keyType);
}

+ (NSData *)signMesasageDigest:(OpaqueKey *)key digest:(UInt256)digest {
    return [DSKeyManager NSDataFrom:key_sign_message_digest(key, digest.u8)];
}

+ (BOOL)verifyMessageDigest:(OpaqueKey *)key digest:(UInt256)digest signature:(NSData *)signature {
    return key_verify_message_digest(key, digest.u8, signature.bytes, signature.length);
}

+ (OpaqueKey *_Nullable)privateKeyAtIndexPath:(KeyKind)keyType indexes:(UInt256 *)indexes hardened:(BOOL *)hardened length:(NSUInteger)length indexPath:(NSIndexPath *)indexPath fromSeed:(NSData *)seed {
    NSParameterAssert(indexPath);
    NSParameterAssert(seed);
    if (!seed || !indexPath) return nil;
    if (!length) return nil; //there needs to be at least 1 length
    IndexPathData *index_path = [indexPath ffi_malloc];
    OpaqueKey *key = key_private_key_at_index_path(seed.bytes, seed.length, (int16_t) keyType, index_path, (const uint8_t *) indexes, hardened, length);
    [NSIndexPath ffi_free:index_path];
    return key;
}

+ (OpaqueKey *_Nullable)keyPublicDeriveTo256Bit:(DSDerivationPath *)parentPath childIndexes:(UInt256 *)childIndexes childHardened:(BOOL *)childHardened length:(NSUInteger)length {
    OpaqueKey *key = key_public_derive_to_256bit(parentPath.extendedPublicKey, (const uint8_t *) childIndexes, childHardened, length, parentPath.length);
    return key;
}

+ (OpaqueKey *_Nullable)publicKeyAtIndexPath:(OpaqueKey *)key indexPath:(NSIndexPath *)indexPath {
    if (key == NULL) return nil;
    IndexPathData *index_path = [indexPath ffi_malloc];
    OpaqueKey *key_at_index_path = key_public_key_at_index_path(key, index_path);
    [NSIndexPath ffi_free:index_path];
    return key_at_index_path;
}

+ (NSData *_Nullable)publicKeyDataAtIndexPath:(OpaqueKey *)key indexPath:(NSIndexPath *)indexPath {
    if (key == NULL) return nil;
    IndexPathData *index_path = [indexPath ffi_malloc];
    ByteArray byte_array = key_public_key_data_at_index_path(key, index_path);
    [NSIndexPath ffi_free:index_path];
    return [DSKeyManager NSDataFrom:byte_array];
}

+ (NSString *)serializedPrivateKey:(OpaqueKey *)key chainType:(ChainType)chainType {
    char *c_string = key_serialized_private_key_for_chain(key, chainType);
    return [DSKeyManager NSStringFrom:c_string];
}

+ (NSString *)addressForKey:(OpaqueKey *)key forChainType:(ChainType)chainType {
    char *c_string = key_address_for_key(key, chainType);
    return [DSKeyManager NSStringFrom:c_string];
}

+ (NSString *)addressWithPublicKeyData:(NSData *)data forChain:(nonnull DSChain *)chain {
    char *c_string = key_address_with_public_key_data(data.bytes, data.length, chain.chainType);
    return [DSKeyManager NSStringFrom:c_string];
}

+ (NSString *)addressFromHash160:(UInt160)hash forChain:(nonnull DSChain *)chain {
    char *c_string = address_from_hash160(hash.u8, chain.chainType);
    return [DSKeyManager NSStringFrom:c_string];
}

+ (NSString *_Nullable)addressWithScriptPubKey:(NSData *)script forChain:(nonnull DSChain *)chain {
    char *c_string = address_with_script_pubkey(script.bytes, script.length, chain.chainType);
    return [DSKeyManager NSStringFrom:c_string];
}

+ (NSString *_Nullable)addressWithScriptSig:(NSData *)script forChain:(nonnull DSChain *)chain {
    char *c_string = address_with_script_sig(script.bytes, script.length, chain.chainType);
    return [DSKeyManager NSStringFrom:c_string];
}

+ (BOOL)isValidDashAddress:(NSString *)address forChain:(nonnull DSChain *)chain {
    return is_valid_dash_address_for_chain([address UTF8String], chain.chainType);
}

+ (NSData *)scriptPubKeyForAddress:(NSString *)address forChain:(nonnull DSChain *)chain {
    return [DSKeyManager NSDataFrom:script_pubkey_for_address([address UTF8String], chain.chainType)];
}

+ (NSData *)privateKeyData:(OpaqueKey *)key {
    ByteArray arr = key_private_key_data(key);
    return [DSKeyManager NSDataFrom:arr];
}

+ (NSData *)publicKeyData:(OpaqueKey *)key {
    ByteArray arr = key_public_key_data(key);
    return [DSKeyManager NSDataFrom:arr];
}

+ (NSData *)extendedPrivateKeyData:(OpaqueKey *)key {
    ByteArray arr = key_extended_private_key_data(key);
    return [DSKeyManager NSDataFrom:arr];
}

+ (NSData *)extendedPublicKeyData:(OpaqueKey *)key {
    ByteArray arr = key_extended_public_key_data(key);
    return [DSKeyManager NSDataFrom:arr];
}


+ (OpaqueKey *_Nullable)deriveKeyFromExtenedPrivateKeyDataAtIndexPath:(NSData *_Nullable)data
                                                            indexPath:(NSIndexPath *)indexPath
                                                           forKeyType:(KeyKind)keyType {
    if (!data) return nil;
    NSUInteger idxs[[indexPath length]];
    [indexPath getIndexes:idxs];
    OpaqueKey *key = key_derive_key_from_extened_private_key_data_for_index_path(data.bytes, data.length, (int16_t) keyType, idxs, indexPath.length);
    return key;
}

+ (UInt160)ecdsaKeyPublicKeyHashFromSecret:(NSString *)secret forChainType:(ChainType)chainType {
    return [DSKeyManager NSDataFrom:ecdsa_public_key_hash_from_secret([secret UTF8String], chainType)].UInt160;
}

+ (NSString *_Nullable)ecdsaKeyAddressFromPublicKeyData:(NSData *)data forChainType:(ChainType)chainType {
    return [DSKeyManager NSStringFrom:ecdsa_address_from_public_key_data(data.bytes, data.length, chainType)];
}


- (NSString *)ecdsaKeyPublicKeyUniqueIDFromDerivedKeyData:(UInt256)secret forChainType:(ChainType)chainType {
    uint64_t unque_id = ecdsa_public_key_unique_id_from_derived_key_data(secret.u8, 32, chainType);
    return [NSString stringWithFormat:@"%0llx", unque_id];
}

- (NSString *)keyRecoveredFromCompactSig:(NSData *)signature andMessageDigest:(UInt256)md {
    return [DSKeyManager NSStringFrom:address_for_ecdsa_key_recovered_from_compact_sig(signature.bytes, signature.length, md.u8, self.chain.chainType)];
}

+ (NSData *_Nullable)compactSign:(DSDerivationPath *)derivationPath fromSeed:(NSData *)seed atIndexPath:(NSIndexPath *)indexPath digest:(UInt256)digest {
    OpaqueKey *key = [derivationPath privateKeyAtIndexPath:indexPath fromSeed:seed];
    // TODO: wrong need to sign opaque?
    NSData *data = [DSKeyManager NSDataFrom:key_ecdsa_compact_sign(key->ecdsa, digest.u8)];
    processor_destroy_opaque_key(key);
    return data;
}

+ (ECDSAKey *)ecdsaKeyWithPrivateKey:(NSString *)key forChainType:(ChainType)chainType {
    return key_ecdsa_with_private_key([key UTF8String], chainType);
}

+ (NSString *)blsPublicKeySerialize:(OpaqueKey *)key legacy:(BOOL)legacy {
    BLSKey *bls;
    if (key->tag == OpaqueKey_BLSBasic)
        bls = key->bls_basic;
    else
        bls = key->bls_legacy;
    return uint384_hex([DSKeyManager NSDataFrom:key_bls_serialize(bls, legacy)].UInt384);
}

+ (NSString *_Nullable)ecdsaKeyWithBIP38Key:(NSString *)key passphrase:(NSString *)passphrase forChainType:(ChainType)chainType {
    return [DSKeyManager NSStringFrom:key_ecdsa_with_bip38_key([key UTF8String], [passphrase UTF8String], chainType)];
}

+ (BOOL)isValidDashBIP38Key:(NSString *)key {
    return key_is_valid_bip38_key([key UTF8String]);
}

+ (OpaqueKey *_Nullable)keyWithPrivateKeyString:(NSString *)key ofKeyType:(KeyKind)keyType forChainType:(ChainType)chainType {
    return key_with_private_key([key UTF8String], keyType, chainType);
}

+ (OpaqueKey *_Nullable)keyDeprecatedExtendedPublicKeyFromSeed:(NSData *)seed indexes:(UInt256 *)indexes hardened:(BOOL *)hardened length:(NSUInteger)length {
    OpaqueKey *key = deprecated_incorrect_extended_public_key_from_seed(seed.bytes, seed.length, (const uint8_t *) indexes, hardened, length);
    return key;
}

+ (NSString *)NSStringFrom:(char *)c_string {
    if (c_string == NULL) {
        return nil;
    } else {
        NSString *address = [NSString stringWithUTF8String:c_string];
        processor_destroy_string(c_string);
        return address;
    }
}

+ (NSData *)NSDataFrom:(ByteArray)byte_array {
    if (byte_array.ptr == NULL && byte_array.len == 0) {
        return nil;
    } else {
        NSData *data = [NSData dataWithBytes:(const void *)byte_array.ptr length:byte_array.len];
        processor_destroy_byte_array(byte_array.ptr, byte_array.len);
        return data;
    }
}

+ (NSString *)keyStoragePrefix:(KeyKind)keyType {
    switch (keyType) {
        case KeyKind_ECDSA: return @"";
        case KeyKind_BLS: return @"_BLS_";
        case KeyKind_BLSBasic: return @"_BLS_";
        case KeyKind_ED25519: return @"_ED_";
    }
}

+ (NSString *)localizedKeyType:(OpaqueKey *)key {
    switch (key->tag) {
        case OpaqueKey_ECDSA: return DSLocalizedString(@"ECDSA", nil);
        case OpaqueKey_BLSLegacy: return DSLocalizedString(@"BLS (Legacy)", nil);
        case OpaqueKey_BLSBasic: return DSLocalizedString(@"BLS (Basic)", nil);
        case OpaqueKey_ED25519: return DSLocalizedString(@"ED25519", nil);
        default: return DSLocalizedString(@"Unknown Key Type", nil);
    }
}
/// Crypto
+ (UInt256)x11:(NSData *)data {
    return [DSKeyManager NSDataFrom:processor_x11(data.bytes, data.length)].UInt256;
}

+ (UInt256)blake3:(NSData *)data {
    return [DSKeyManager NSDataFrom:processor_blake3(data.bytes, data.length)].UInt256;
}

+ (NSData *)encryptData:(NSData *)data secretKey:(OpaqueKey *)secretKey publicKey:(OpaqueKey *)publicKey {
    ByteArray result = key_encrypt_data(data.bytes, data.length, secretKey, publicKey);
    return [DSKeyManager NSDataFrom:result];
}

+ (NSData *)encryptData:(NSData *)data secretKey:(OpaqueKey *)secretKey publicKey:(OpaqueKey *)publicKey usingIV:(NSData *)iv {
    ByteArray result = key_encrypt_data_using_iv(data.bytes, data.length, secretKey, publicKey, iv.bytes, iv.length);
    return [DSKeyManager NSDataFrom:result];
}

+ (NSData *)decryptData:(NSData *)data secretKey:(OpaqueKey *)secretKey publicKey:(OpaqueKey *)publicKey {
    ByteArray result = key_decrypt_data(data.bytes, data.length, secretKey, publicKey);
    return [DSKeyManager NSDataFrom:result];
}

+ (NSData *)decryptData:(NSData *)data secretKey:(OpaqueKey *)secretKey publicKey:(OpaqueKey *)publicKey usingIVSize:(NSUInteger)ivSize {
    ByteArray result = key_decrypt_data_using_iv_size(data.bytes, data.length, secretKey, publicKey, ivSize);
    return [DSKeyManager NSDataFrom:result];
}

+ (NSData *)encryptData:(NSData *)data withDHKey:(OpaqueKey *)dhKey {
    ByteArray result = key_encrypt_data_with_dh_key(data.bytes, data.length, dhKey);
    return [DSKeyManager NSDataFrom:result];
}

+ (NSData *)decryptData:(NSData *)data withDHKey:(OpaqueKey *)dhKey {
    ByteArray result = key_decrypt_data_with_dh_key(data.bytes, data.length, dhKey);
    return [DSKeyManager NSDataFrom:result];
}




+ (BOOL)verifyProRegTXPayloadSignature:(NSData *)signature payload:(NSData *)payload ownerKeyHash:(UInt160)ownerKeyHash {
    return pro_reg_tx_verify_payload_signature(signature.bytes, signature.length, payload.bytes, payload.length, ownerKeyHash.u8);
}

+ (NSData *)proRegTXPayloadCollateralDigest:(NSData *)payload
                               scriptPayout:(NSData *)scriptPayout
                                     reward:(uint16_t)reward
                               ownerKeyHash:(UInt160)ownerKeyHash
                               voterKeyHash:(UInt160)voterKeyHash
                                  chainType:(ChainType)chainType {
    ByteArray result = pro_reg_tx_payload_collateral_digest(payload.bytes, payload.length, scriptPayout.bytes, scriptPayout.length, reward, ownerKeyHash.u8, voterKeyHash.u8, chainType);
    return [DSKeyManager NSDataFrom:result];
}

+ (NSString *_Nullable)devnetIdentifierFor:(ChainType)chainType {
    return [DSKeyManager NSStringFrom:devnet_identifier_for_chain_type(chainType)];
}

@end
