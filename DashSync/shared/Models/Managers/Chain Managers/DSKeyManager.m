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

#import "DSChain+Params.h"
#import "DSDerivationPath+Protected.h"
#import "DSKeyManager.h"
#import "NSIndexPath+FFI.h"
#import "NSString+Dash.h"


// Main purpose of this class is to organize work with rust bindings for keys and internal cache

@interface DSKeyManager ()

@property (nonatomic, strong) DSChain *chain;
//@property (nonatomic, assign, nullable) KeysCache *keysCache;

@end


@implementation DSKeyManager

- (instancetype)initWithChain:(DSChain *)chain {
    NSParameterAssert(chain);
    if (!(self = [super init])) return nil;
//    _keysCache = [DSKeyManager createKeysCache];
    DSLog(@"[%@] DSKeyManager.initWithChain: %@: ", chain.name, chain);
    return self;
}

//- (void)dealloc {
//    [DSKeyManager destroyKeysCache:self.keysCache];
//}
//
//+ (KeysCache *)createKeysCache {
//    return keys_create_cache();
//}
//
//+ (void)destroyKeysCache:(KeysCache *)cache {
//    keys_destroy_cache(cache);
//}

+ (BOOL)hasPrivateKey:(DOpaqueKey *)key {
    return dash_spv_crypto_keys_key_OpaqueKey_has_private_key(key);
}

+ (BOOL)keysPublicKeyDataIsEqual:(DOpaqueKey *)key1 key2:(DOpaqueKey *)key2 {
    if (key1 == NULL || key2 == NULL) return false;
    BYTES *public_key_data2 = dash_spv_crypto_keys_key_OpaqueKey_public_key_data(key2);
    BOOL is_equal = dash_spv_crypto_keys_key_OpaqueKey_public_key_data_equal_to(key1, public_key_data2);
//    bytes_dtor(public_key_data2);
    return is_equal;
}

+ (NSString *)secretKeyHexString:(DOpaqueKey *)key {
    return [DSKeyManager NSStringFrom:dash_spv_crypto_keys_key_OpaqueKey_secret_key_string(key)];
}

+ (DMaybeOpaqueKey *_Nullable)keyWithPrivateKeyData:(NSData *)data ofType:(DKeyKind *)keyType {
    SLICE *slice = slice_ctor(data);
    DMaybeOpaqueKey *result = dash_spv_crypto_keys_key_KeyKind_key_with_private_key_data(keyType, slice);
    return result;
}

+ (DMaybeOpaqueKey *_Nullable)keyWithPublicKeyData:(NSData *)data ofType:(DKeyKind *)keyType {
    SLICE *slice = slice_ctor(data);
    DMaybeOpaqueKey *result = dash_spv_crypto_keys_key_KeyKind_key_with_public_key_data(keyType, slice);
    return result;
}

+ (DMaybeOpaqueKey *_Nullable)keyWithExtendedPublicKeyData:(NSData *)data ofType:(DKeyKind *)keyType {
    SLICE *slice = slice_ctor(data);
    DMaybeOpaqueKey *result = dash_spv_crypto_keys_key_KeyKind_key_with_extended_private_key_data(keyType, slice);
    return result;
}

+ (NSData *)signMesasageDigest:(DOpaqueKey *)key digest:(UInt256)digest {
    SLICE *digest_slice = slice_u256_ctor_u(digest);
    NSData *signature = [DSKeyManager NSDataFrom:dash_spv_crypto_keys_key_OpaqueKey_sign(key, digest_slice)];
    return signature;
}

+ (BOOL)verifyMessageDigest:(DOpaqueKey *)key digest:(UInt256)digest signature:(NSData *)signature {
    SLICE *message_digest = slice_u256_ctor_u(digest);
    SLICE *sig = slice_ctor(signature);
    Result_ok_bool_err_dash_spv_crypto_keys_KeyError *result = dash_spv_crypto_keys_key_OpaqueKey_verify(key, message_digest, sig);
    BOOL verified = result && result->ok && result->ok[0];
    Result_ok_bool_err_dash_spv_crypto_keys_KeyError_destroy(result);
    return verified;
}

+ (DMaybeOpaqueKey *_Nullable)publicKeyAtIndexPath:(DOpaqueKey *)key indexPath:(NSIndexPath *)indexPath {
    if (key == NULL) return nil;
    Vec_u32 *index_path = [NSIndexPath ffi_to:indexPath];
    DMaybeOpaqueKey *maybe_key = dash_spv_crypto_keys_key_OpaqueKey_public_key_from_extended_public_key_data_at_index_path(key, index_path);
    return maybe_key;
}

+ (NSData *_Nullable)publicKeyDataAtIndexPath:(DOpaqueKey *)key indexPath:(NSIndexPath *)indexPath {
    if (key == NULL) return nil;
    Vec_u32 *index_path = [NSIndexPath ffi_to:indexPath];
    DMaybeKeyData *maybe_data = dash_spv_crypto_keys_key_OpaqueKey_public_key_data_at_index_path(key, index_path);
    NSData *data = NULL;
    if (maybe_data) {
        if (maybe_data->ok)
            data = NSDataFromPtr(maybe_data->ok);
        DMaybeKeyDataDtor(maybe_data);
    }
    return data;
}

+ (NSString *)serializedPrivateKey:(DOpaqueKey *)key chainType:(DChainType *)chainType {
    uint8_t priv_key = dash_spv_crypto_network_chain_type_ChainType_script_priv_key(chainType);
    char *c_string = dash_spv_crypto_keys_key_OpaqueKey_serialized_private_key_for_script(key, priv_key);
    return [DSKeyManager NSStringFrom:c_string];
}

+ (NSString *)addressForKey:(DOpaqueKey *)key forChainType:(DChainType *)chainType {
    char *c_string = dash_spv_crypto_keys_key_OpaqueKey_address_with_public_key_data(key, chainType);
    return [DSKeyManager NSStringFrom:c_string];
}

+ (NSString *)addressWithPublicKeyData:(NSData *)data forChain:(nonnull DSChain *)chain {
    SLICE *slice = slice_ctor(data);
    char *c_string = dash_spv_crypto_util_address_address_with_public_key_data(slice, chain.chainType);
    return [DSKeyManager NSStringFrom:c_string];
}

+ (NSString *)addressFromHash160:(UInt160)hash forChain:(nonnull DSChain *)chain {
    u160 *h = u160_ctor_u(hash);
    char *c_string = dash_spv_apple_bindings_address_addresses_address_from_hash160(h, chain.chainType);
    return [DSKeyManager NSStringFrom:c_string];
}

+ (NSString *_Nullable)addressWithScriptPubKey:(NSData *)script forChain:(nonnull DSChain *)chain {
    BYTES *vec = bytes_ctor(script);
    char *c_string = dash_spv_apple_bindings_address_addresses_address_with_script_pubkey(vec, chain.chainType);
    return [DSKeyManager NSStringFrom:c_string];
}

+ (NSString *_Nullable)addressWithScriptSig:(NSData *)script forChain:(nonnull DSChain *)chain {
    BYTES *vec = bytes_ctor(script);
    char *c_string = dash_spv_apple_bindings_address_addresses_address_with_script_sig(vec, chain.chainType);
    return [DSKeyManager NSStringFrom:c_string];
}

+ (BOOL)isValidDashAddress:(NSString *)address forChain:(nonnull DSChain *)chain {
    return dash_spv_apple_bindings_address_addresses_is_valid_dash_address_for_chain(DChar(address), chain.chainType);
}

+ (NSData *)scriptPubKeyForAddress:(NSString *)address forChain:(nonnull DSChain *)chain {
    BYTES *vec = dash_spv_apple_bindings_address_addresses_script_pubkey_for_address(DChar(address), chain.chainType);
    return [DSKeyManager NSDataFrom:vec];
}

+ (NSData *)privateKeyData:(DOpaqueKey *)key {
    DMaybeKeyData *result = dash_spv_crypto_keys_key_OpaqueKey_private_key_data(key);
    if (result->error) {
        return NULL;
    }
    NSData *data = NSDataFromPtr(result->ok);
    DMaybeKeyDataDtor(result);
    return data;
}

+ (NSData *)publicKeyData:(DOpaqueKey *)key {
    BYTES *vec = dash_spv_crypto_keys_key_OpaqueKey_public_key_data(key);
    NSData *data = [DSKeyManager NSDataFrom:vec];
    return data;
}

+ (NSData *)extendedPrivateKeyData:(DOpaqueKey *)key {
    Result_ok_dash_spv_crypto_util_sec_vec_SecVec_err_dash_spv_crypto_keys_KeyError *result = dash_spv_crypto_keys_key_OpaqueKey_extended_private_key_data(key);
    if (result->error) {
        return NULL;
    }
    BYTES *bytes = dash_spv_crypto_util_sec_vec_SecVec_to_vec(result->ok);
    NSData *data = NSDataFromPtr(bytes);
    Result_ok_dash_spv_crypto_util_sec_vec_SecVec_err_dash_spv_crypto_keys_KeyError_destroy(result);
    return data;
}

+ (NSData *)extendedPublicKeyData:(DOpaqueKey *)key {
    DMaybeKeyData *result = dash_spv_crypto_keys_key_OpaqueKey_extended_public_key_data(key);
    NSData *data = NULL;
    if (result) {
        if (result->ok)
            data = NSDataFromPtr(result->ok);
        DMaybeKeyDataDtor(result);
    }
    return data;
}


+ (DMaybeOpaqueKey *_Nullable)deriveKeyFromExtenedPrivateKeyDataAtIndexPath:(NSData *_Nullable)data
                                                            indexPath:(NSIndexPath *)indexPath
                                                           forKeyType:(DKeyKind *)keyType {
    if (!data) return nil;
//    NSUInteger idxs[[indexPath length]];
//    [indexPath getIndexes:idxs];
    SLICE *slice = slice_ctor(data);
    Vec_u32 *index_path = [NSIndexPath ffi_to:indexPath];
//    NSLog(@"[kind: %u] deriveKeyFromExtenedPrivateKeyDataAtIndexPath: %@ %@", dash_spv_crypto_keys_key_KeyKind_index(keyType), data.hexString, indexPath);
    DMaybeOpaqueKey *maybe_key = dash_spv_crypto_keys_key_KeyKind_derive_key_from_extended_private_key_data_for_index_path(keyType, slice, index_path);
    return maybe_key;
}

//+ (UInt160)ecdsaKeyPublicKeyHashFromSecret:(NSString *)secret forChainType:(DChainType *)chainType {
//    key_with_private_key
//    key_hash
//    return [DSKeyManager NSDataFrom:ecdsa_public_key_hash_from_secret([secret UTF8String], chainType)].UInt160;
//}

+ (NSString *_Nullable)ecdsaKeyAddressFromPublicKeyData:(NSData *)data forChainType:(DChainType *)chainType {
    SLICE *slice = slice_ctor(data);
    char *addr = dash_spv_crypto_keys_ecdsa_key_ECDSAKey_address_from_public_key_data(slice, chainType);
//    slice_dtor(slice);
    return [DSKeyManager NSStringFrom:addr];
}


- (NSString *)ecdsaKeyPublicKeyUniqueIDFromDerivedKeyData:(UInt256)secret forChainType:(DChainType *)chainType {
    SLICE *slice = slice_u256_ctor_u(secret);
    uint64_t unique_id = dash_spv_crypto_keys_ecdsa_key_ECDSAKey_public_key_unique_id_from_derived_key_data(slice, chainType);
    return [NSString stringWithFormat:@"%0llx", unique_id];
}

- (NSString *)keyRecoveredFromCompactSig:(NSData *)signature andMessageDigest:(UInt256)md {
    SLICE *slice = slice_ctor(signature);
    u256 *digest = u256_ctor_u(md);
    DMaybeKeyString *result = dash_spv_crypto_keys_ecdsa_key_ECDSAKey_address_from_recovered_compact_sig(slice, digest, self.chain.chainType);
    NSString *addr = NULL;
    if (result) {
        addr = NSStringFromPtr(result->ok);
        DMaybeKeyStringDtor(result);
    }
    return addr;
}

+ (NSData *_Nullable)compactSign:(DSDerivationPath *)derivationPath fromSeed:(NSData *)seed atIndexPath:(NSIndexPath *)indexPath digest:(UInt256)digest {
    DMaybeOpaqueKey *key = [derivationPath privateKeyAtIndexPath:indexPath fromSeed:seed];
    NSData *data = NULL;
    if (key) {
        if (key->ok) {
            SLICE *slice = slice_u256_ctor_u(digest);
            BYTES *bytes = dash_spv_crypto_keys_key_OpaqueKey_sign(key->ok, slice);
            data = NSDataFromPtr(bytes);
            bytes_dtor(bytes);
        }
        DMaybeOpaqueKeyDtor(key);
    }
    return data;
}

//+ (struct ECDSAKey *)ecdsaKeyWithPrivateKey:(NSString *)key forChainType:(DChainType *)chainType {
//    struct Result_ok_dash_spv_crypto_keys_ecdsa_key_ECDSAKey_err_dash_spv_crypto_keys_KeyError *result = dash_spv_crypto_keys_ecdsa_key_ECDSAKey_key_with_private_key([key UTF8String], chainType);
//    return key_ecdsa_with_private_key([key UTF8String], chainType);
//}

+ (NSString *)blsPublicKeySerialize:(DOpaqueKey *)key legacy:(BOOL)legacy {
    DMaybeKeyString *result = dash_spv_crypto_keys_bls_key_BLSKey_public_key_serialized(key->bls, legacy);
    NSString *keySerialized = NULL;
    if (result) {
        keySerialized = NSStringFromPtr(result->ok);
        DMaybeKeyStringDtor(result);
    }
    return keySerialized;
}

+ (NSString *_Nullable)ecdsaKeyWithBIP38Key:(NSString *)key
                                 passphrase:(NSString *)passphrase
                               forChainType:(DChainType *)chainType {
    DMaybeKeyString *result = dash_spv_crypto_keys_ecdsa_key_ECDSAKey_serialized_from_bip38_key(DChar(key), DChar(passphrase), chainType);
    NSString *keySerialized = NULL;
    if (result) {
        keySerialized = NSStringFromPtr(result->ok);
        DMaybeKeyStringDtor(result);
    }
    return keySerialized;
}

+ (BOOL)isValidDashBIP38Key:(NSString *)key {
    return dash_spv_crypto_keys_ecdsa_key_ECDSAKey_is_valid_bip38_key(DChar(key));
}

+ (DMaybeOpaqueKey *_Nullable)keyWithPrivateKeyString:(NSString *)key
                                       ofKeyType:(DKeyKind *)keyType
                                    forChainType:(DChainType *)chainType {
    return dash_spv_crypto_keys_key_KeyKind_key_with_private_key(keyType, DChar(key), chainType);
}

//+ (DOpaqueKey *_Nullable)keyDeprecatedExtendedPublicKeyFromSeed:(NSData *)seed indexes:(UInt256 *)indexes hardened:(BOOL *)hardened length:(NSUInteger)length {
//    SLICE *secret = slice_ctor(seed);
//    
//    dash_spv_crypto_keys_ecdsa_key_ECDSAKey_deprecated_incorrect_extended_public_key_from_seed_as_opaque(<#struct Slice_u8 *secret#>, <#struct Slice_u8 *chaincode#>, <#struct Slice_u8 *hashes#>, <#uintptr_t derivation_len#>)
//    
//    DOpaqueKey *key = deprecated_incorrect_extended_public_key_from_seed(seed.bytes, seed.length, (const uint8_t *) indexes, hardened, length);
//    return key;
//}

+ (NSString *)NSStringFrom:(char *)c_string {
    if (c_string == NULL) {
        return nil;
    } else {
        NSString *address = [NSString stringWithUTF8String:c_string];
        str_destroy(c_string);
//        processor_destroy_string(c_string);
        return address;
    }
}

+ (NSData *)NSDataFrom:(BYTES *)byte_array {
    if (byte_array->values == NULL && byte_array->count == 0) {
        return nil;
    } else {
        NSData *data = NSDataFromPtr(byte_array);
        bytes_dtor(byte_array);
        return data;
    }
}
+ (NSData *)NSDataFromArr_u8_32:(u256 *)byte_array {
    if (byte_array->values == NULL && byte_array->count == 0) {
        return nil;
    } else {
        NSData *data = NSDataFromPtr(byte_array);
        u256_dtor(byte_array);
        return data;
    }
}

//+ (NSString *)keyStoragePrefix:(DKeyKind *)keyType {
//    switch (&keyType) {
//        case dash_spv_crypto_keys_key_KeyKind_ECDSA: return @"";
//        case dash_spv_crypto_keys_key_KeyKind_BLS: return @"_BLS_";
//        case dash_spv_crypto_keys_key_KeyKind_BLSBasic: return @"_BLS_B_";
//        case dash_spv_crypto_keys_key_KeyKind_ED25519: return @"_ED25519_";
//    }
//}

+ (NSString *)localizedKeyType:(DOpaqueKey *)key {
    switch (key->tag) {
        case dash_spv_crypto_keys_key_OpaqueKey_ECDSA: return DSLocalizedString(@"ECDSA", nil);
//        case dash_spv_crypto_keys_key_OpaqueKey_BLSLegacy: return DSLocalizedString(@"BLS (Legacy)", nil);
        case dash_spv_crypto_keys_key_OpaqueKey_BLS: return DSLocalizedString(@"BLS", nil);
//        case dash_spv_crypto_keys_key_OpaqueKey_BLSBasic: return DSLocalizedString(@"BLS (Basic)", nil);
        case dash_spv_crypto_keys_key_OpaqueKey_ED25519: return DSLocalizedString(@"ED25519", nil);
        default: return DSLocalizedString(@"Unknown Key Type", nil);
    }
}
//+ (DKeyKind *)keyKindFromIndex:(uint16_t)index {
//    switch (index) {
//        case dash_spv_crypto_keys_key_KeyKind_ECDSA:
//            return dash_spv_crypto_keys_key_KeyKind_ECDSA_ctor();
//        case dash_spv_crypto_keys_key_KeyKind_BLS:
//            return dash_spv_crypto_keys_key_KeyKind_BLS_ctor();
//        case dash_spv_crypto_keys_key_KeyKind_BLSBasic:
//            return dash_spv_crypto_keys_key_KeyKind_BLSBasic_ctor();
//        case dash_spv_crypto_keys_key_KeyKind_ED25519:
//            return dash_spv_crypto_keys_key_KeyKind_ED25519_ctor();
//    }
//    
//}

/// Crypto
+ (UInt256)x11:(NSData *)data {
    SLICE *slice = slice_ctor(data);
    u256 *result = dash_spv_crypto_x11(slice);
//    slice_dtor(slice);
    NSData *hash = NSDataFromPtr(result);
    u256_dtor(result);
    return hash.UInt256;
}

+ (UInt256)blake3:(NSData *)data {
    SLICE *slice = slice_ctor(data);
    u256 *result = dash_spv_crypto_blake3(slice);
//    slice_dtor(slice);
    NSData *hash = NSDataFromPtr(result);
    u256_dtor(result);
    return hash.UInt256;
}

+ (NSData *)encryptData:(NSData *)data secretKey:(DOpaqueKey *)secretKey publicKey:(DOpaqueKey *)publicKey {
    SLICE *slice = slice_ctor(data);
    DMaybeKeyData *result = dash_spv_crypto_keys_key_OpaqueKey_encrypt_data(secretKey, publicKey, slice);
    NSData *encrypted = NULL;
    if (result) {
        if (result->ok)
            encrypted = NSDataFromPtr(result->ok);
        DMaybeKeyDataDtor(result);
    }
    return encrypted;
}

+ (NSData *)encryptData:(NSData *)data secretKey:(DOpaqueKey *)secretKey publicKey:(DOpaqueKey *)publicKey usingIV:(NSData *)iv {
    SLICE *slice = slice_ctor(data);
    BYTES *iv_slice = bytes_ctor(iv);
//    NSLog(@"[DSKeyManager] encryptData --> %@ -- %p -- %p -- %@", data.hexString, secretKey, publicKey, iv.hexString);
    DMaybeKeyData *result = dash_spv_crypto_keys_key_OpaqueKey_encrypt_data_using_iv(secretKey, publicKey, slice, iv_slice);
    NSData *encrypted = NULL;
    if (result) {
        if (result->ok)
            encrypted = NSDataFromPtr(result->ok);
        DMaybeKeyDataDtor(result);
    }
//    NSLog(@"[DSKeyManager] encryptData <-- %@", encrypted.hexString);
    return encrypted;
}

+ (NSData *)decryptData:(NSData *)data secretKey:(DOpaqueKey *)secretKey publicKey:(DOpaqueKey *)publicKey {
    SLICE *slice = slice_ctor(data);
    DMaybeKeyData *result = dash_spv_crypto_keys_key_OpaqueKey_decrypt_data(secretKey, publicKey, slice);
    NSData *decrypted = NULL;
    if (result) {
        if (result->ok)
            decrypted = NSDataFromPtr(result->ok);
        DMaybeKeyDataDtor(result);
    }
    return decrypted;
}

+ (NSData *)decryptData:(NSData *)data secretKey:(DOpaqueKey *)secretKey publicKey:(DOpaqueKey *)publicKey usingIVSize:(NSUInteger)ivSize {
    SLICE *slice = slice_ctor(data);
    DMaybeKeyData *result = dash_spv_crypto_keys_key_OpaqueKey_decrypt_data_using_iv_size(secretKey, publicKey, slice, ivSize);
    NSData *decrypted = NULL;
    if (result) {
        if (result->ok)
            decrypted = NSDataFromPtr(result->ok);
        DMaybeKeyDataDtor(result);
    }
    return decrypted;
}

+ (NSData *)encryptData:(NSData *)data withDHKey:(DOpaqueKey *)dhKey {
    BYTES *bytes = bytes_ctor(data);
    DMaybeKeyData *result = dash_spv_crypto_keys_key_OpaqueKey_encrypt_data_with_dh_key(dhKey, bytes);
    NSData *encrypted = NULL;
    if (result) {
        if (result->ok)
            encrypted = NSDataFromPtr(result->ok);
        DMaybeKeyDataDtor(result);
    }
    return encrypted;
}

+ (NSData *)decryptData:(NSData *)data withDHKey:(DOpaqueKey *)dhKey {
    BYTES *bytes = bytes_ctor(data);
    DMaybeKeyData *result = dash_spv_crypto_keys_key_OpaqueKey_decrypt_data_with_dh_key(dhKey, bytes);
    NSData *decrypted = NULL;
    if (result) {
        if (result->ok)
            decrypted = NSDataFromPtr(result->ok);
        DMaybeKeyDataDtor(result);
    }
    return decrypted;
}

+ (BOOL)verifyProRegTXPayloadSignature:(NSData *)signature payload:(NSData *)payload ownerKeyHash:(UInt160)ownerKeyHash {
    SLICE *sig = slice_ctor(signature);
    SLICE *pld = slice_ctor(payload);
    u160 *hash = u160_ctor_u(ownerKeyHash);
    BOOL verified = dash_spv_crypto_keys_ecdsa_key_ECDSAKey_pro_reg_tx_verify_payload_signature(sig, pld, hash);
    return verified;
}

+ (NSString *_Nullable)devnetIdentifierFor:(DChainType *)chainType {
    return [DSKeyManager NSStringFrom:dash_spv_crypto_network_chain_type_ChainType_devnet_identifier(chainType)];
}

@end
