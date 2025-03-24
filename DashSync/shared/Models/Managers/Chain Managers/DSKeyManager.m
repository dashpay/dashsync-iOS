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

@end


@implementation DSKeyManager

- (instancetype)initWithChain:(DSChain *)chain {
    NSParameterAssert(chain);
    if (!(self = [super init])) return nil;
    DSLog(@"[%@] DSKeyManager.initWithChain: %@: ", chain.name, chain);
    return self;
}

+ (BOOL)hasPrivateKey:(DOpaqueKey *)key {
    return DOpaqueKeyHasPrivateKey(key);
}

+ (BOOL)keysPublicKeyDataIsEqual:(DOpaqueKey *)key1 key2:(DOpaqueKey *)key2 {
    if (key1 == NULL || key2 == NULL) return false;
    return DOpaqueKeyPublicKeyDataEqualTo(key1, DOpaqueKeyPublicKeyData(key2));
}

+ (NSString *)secretKeyHexString:(DOpaqueKey *)key {
    return [DSKeyManager NSStringFrom:DOpaqueKeySecretKeyString(key)];
}

+ (DMaybeOpaqueKey *_Nullable)keyWithPrivateKeyData:(NSData *)data ofType:(DKeyKind *)keyType {
    Slice_u8 *slice = slice_ctor(data);
    DMaybeOpaqueKey *result = DMaybeOpaqueKeyWithPrivateKeyData(keyType, slice);
    return result;
}

+ (DMaybeOpaqueKey *_Nullable)keyWithPublicKeyData:(NSData *)data ofType:(DKeyKind *)keyType {
    Slice_u8 *slice = slice_ctor(data);
    DMaybeOpaqueKey *result = DMaybeOpaqueKeyWithPublicKeyData(keyType, slice);
    return result;
}

+ (DMaybeOpaqueKey *_Nullable)keyWithExtendedPublicKeyData:(NSData *)data ofType:(DKeyKind *)keyType {
    Slice_u8 *slice = slice_ctor(data);
    DMaybeOpaqueKey *result = DMaybeOpaqueKeyWithExtendedPrivateKeyData(keyType, slice);
    return result;
}

+ (NSData *)signMesasageDigest:(DOpaqueKey *)key digest:(UInt256)digest {
    Slice_u8 *digest_slice = slice_u256_ctor_u(digest);
    NSData *signature = [DSKeyManager NSDataFrom:DOpaqueKeySign(key, digest_slice)];
    return signature;
}

+ (BOOL)verifyMessageDigest:(DOpaqueKey *)key digest:(UInt256)digest signature:(NSData *)signature {
    Slice_u8 *message_digest = slice_u256_ctor_u(digest);
    Slice_u8 *sig = slice_ctor(signature);
    DKeyVerificationResult *result = DOpaqueKeyVerify(key, message_digest, sig);
    BOOL verified = result->ok && result->ok[0];
    DKeyVerificationResultDtor(result);
    return verified;
}

+ (DMaybeOpaqueKey *_Nullable)publicKeyAtIndexPath:(DOpaqueKey *)key indexPath:(NSIndexPath *)indexPath {
    if (key == NULL) return nil;
    Vec_u32 *index_path = [NSIndexPath ffi_to:indexPath];
    return DOpaqueKeyPublicKeyFromExtPubKeyDataAtIndexPath(key, index_path);
}

+ (NSData *_Nullable)publicKeyDataAtIndexPath:(DOpaqueKey *)key indexPath:(NSIndexPath *)indexPath {
    if (key == NULL) return nil;
    DMaybeKeyData *maybe_data = DOpaqueKeyPublicKeyDataAtIndexPath(key, [NSIndexPath ffi_to:indexPath]);
    NSData *data = NSDataFromPtr(maybe_data->ok);
    DMaybeKeyDataDtor(maybe_data);
    return data;
}

+ (NSString *)serializedPrivateKey:(DOpaqueKey *)key chainType:(DChainType *)chainType {
    uint8_t priv_key = dash_spv_crypto_network_chain_type_ChainType_script_priv_key(chainType);
    char *c_string = DOpaqueKeySerializedPrivateKey(key, priv_key);
    return [DSKeyManager NSStringFrom:c_string];
}

+ (NSString *)addressForKey:(DOpaqueKey *)key forChainType:(DChainType *)chainType {
    char *c_string = DOpaqueKeyPubAddress(key, chainType);
    return [DSKeyManager NSStringFrom:c_string];
}

+ (NSString *)addressWithPublicKeyData:(NSData *)data forChain:(nonnull DSChain *)chain {
    char *c_string = DAddressWithPubKeyData(slice_ctor(data), chain.chainType);
    return [DSKeyManager NSStringFrom:c_string];
}

+ (NSString *)addressFromHash160:(UInt160)hash forChain:(nonnull DSChain *)chain {
    u160 *h = u160_ctor_u(hash);
    char *c_string = dash_spv_apple_bindings_address_addresses_address_from_hash160(h, chain.chainType);
    return [DSKeyManager NSStringFrom:c_string];
}

+ (NSString *_Nullable)addressWithScriptPubKey:(NSData *)script forChain:(nonnull DSChain *)chain {
    Vec_u8 *vec = bytes_ctor(script);
    char *c_string = DAddressWithScriptPubKeyData(vec, chain.chainType);
    return [DSKeyManager NSStringFrom:c_string];
}

+ (NSString *_Nullable)addressWithScriptSig:(NSData *)script forChain:(nonnull DSChain *)chain {
    Vec_u8 *vec = bytes_ctor(script);
    char *c_string = dash_spv_apple_bindings_address_addresses_address_with_script_sig(vec, chain.chainType);
    return [DSKeyManager NSStringFrom:c_string];
}

+ (BOOL)isValidDashAddress:(NSString *)address forChain:(nonnull DSChain *)chain {
    return DIsValidDashAddress(DChar(address), chain.chainType);
}

+ (NSData *)scriptPubKeyForAddress:(NSString *)address forChain:(nonnull DSChain *)chain {
    Vec_u8 *vec = DScriptPubKeyForAddress(DChar(address), chain.chainType);
    return [DSKeyManager NSDataFrom:vec];
}

+ (NSData *)privateKeyData:(DOpaqueKey *)key {
    DMaybeKeyData *result = DOpaqueKeyPrivateKeyData(key);
    NSData *data = NSDataFromPtr(result->ok);
    DMaybeKeyDataDtor(result);
    return data;
}

+ (NSData *)publicKeyData:(DOpaqueKey *)key {
    Vec_u8 *vec = DOpaqueKeyPublicKeyData(key);
    NSData *data = [DSKeyManager NSDataFrom:vec];
    return data;
}

+ (NSData *)extendedPrivateKeyData:(DOpaqueKey *)key {
    Result_ok_dash_spv_crypto_util_sec_vec_SecVec_err_dash_spv_crypto_keys_KeyError *result = DOpaqueKeyExtPrivateKeyData(key);
    if (result->error) {
        return NULL;
    }
    Vec_u8 *bytes = dash_spv_crypto_util_sec_vec_SecVec_to_vec(result->ok);
    NSData *data = NSDataFromPtr(bytes);
    Result_ok_dash_spv_crypto_util_sec_vec_SecVec_err_dash_spv_crypto_keys_KeyError_destroy(result);
    return data;
}

+ (NSData *)extendedPublicKeyData:(DOpaqueKey *)key {
    DMaybeKeyData *result = DOpaqueKeyExtendedPublicKeyData(key);
    NSData *data = NSDataFromPtr(result->ok);
    DMaybeKeyDataDtor(result);
    return data;
}


+ (NSString *_Nullable)ecdsaKeyAddressFromPublicKeyData:(NSData *)data forChainType:(DChainType *)chainType {
    char *addr = DECDSAKeyAddressFromPublicKeyData(slice_ctor(data), chainType);
    return [DSKeyManager NSStringFrom:addr];
}


- (NSString *)ecdsaKeyPublicKeyUniqueIDFromDerivedKeyData:(UInt256)secret forChainType:(DChainType *)chainType {
    Slice_u8 *slice = slice_u256_ctor_u(secret);
    uint64_t unique_id = DECDSAPublicKeyUniqueIdFromDerivedKeyData(slice, chainType);
    return [NSString stringWithFormat:@"%0llx", unique_id];
}

- (NSString *)keyRecoveredFromCompactSig:(NSData *)signature andMessageDigest:(UInt256)md {
    Slice_u8 *slice = slice_ctor(signature);
    u256 *digest = u256_ctor_u(md);
    DMaybeKeyString *result = DECDSAKeyAddressFromRecoveredCompactSig(slice, digest, self.chain.chainType);
    NSString *addr = NSStringFromPtr(result->ok);
    DMaybeKeyStringDtor(result);
    return addr;
}

+ (NSData *_Nullable)compactSign:(DSDerivationPath *)derivationPath
                        fromSeed:(NSData *)seed
                     atIndexPath:(NSIndexPath *)indexPath
                          digest:(UInt256)digest {
    DMaybeOpaqueKey *key = [derivationPath privateKeyAtIndexPath:indexPath fromSeed:seed];
    NSData *data = NULL;
    if (key->ok) {
        Slice_u8 *slice = slice_u256_ctor_u(digest);
        Vec_u8 *bytes = DOpaqueKeySign(key->ok, slice);
        data = NSDataFromPtr(bytes);
        bytes_dtor(bytes);
    }
    DMaybeOpaqueKeyDtor(key);
    return data;
}

+ (NSString *)blsPublicKeySerialize:(DOpaqueKey *)key legacy:(BOOL)legacy {
    DMaybeKeyString *result = DBLSKeySerializedPubKey(key->bls, legacy);
    NSString *keySerialized = NSStringFromPtr(result->ok);
    DMaybeKeyStringDtor(result);
    return keySerialized;
}

+ (NSString *_Nullable)ecdsaKeyWithBIP38Key:(NSString *)key
                                 passphrase:(NSString *)passphrase
                               forChainType:(DChainType *)chainType {
    DMaybeKeyString *result = DECDSAKeySerializedPrivateKeyFromBIP38(DChar(key), DChar(passphrase), chainType);
    NSString *keySerialized = NSStringFromPtr(result->ok);
    DMaybeKeyStringDtor(result);
    return keySerialized;
}

+ (BOOL)isValidDashBIP38Key:(NSString *)key {
    return DECDSAKeyIsValidBIP38(DChar(key));
}

+ (NSString *)NSStringFrom:(char *)c_string {
    NSString *address = NULL;
    if (c_string != NULL) {
        address = NSStringFromPtr(c_string);
        DCharDtor(c_string);
    }
    return address;
}

+ (NSData *)NSDataFrom:(Vec_u8 *)byte_array {
    if (byte_array->values == NULL && byte_array->count == 0) {
        return nil;
    } else {
        NSData *data = NSDataFromPtr(byte_array);
        bytes_dtor(byte_array);
        return data;
    }
}

+ (NSString *)localizedKeyType:(DOpaqueKey *)key {
    switch (key->tag) {
        case dash_spv_crypto_keys_key_OpaqueKey_ECDSA: return DSLocalizedString(@"ECDSA", nil);
        case dash_spv_crypto_keys_key_OpaqueKey_BLS: return DSLocalizedString(@"BLS", nil);
        case dash_spv_crypto_keys_key_OpaqueKey_ED25519: return DSLocalizedString(@"ED25519", nil);
        default: return DSLocalizedString(@"Unknown Key Type", nil);
    }
}

/// Crypto
+ (UInt256)x11:(NSData *)data {
    u256 *result = dash_spv_crypto_x11(slice_ctor(data));
    NSData *hash = NSDataFromPtr(result);
    u256_dtor(result);
    return hash.UInt256;
}

+ (UInt256)blake3:(NSData *)data {
    u256 *result = dash_spv_crypto_blake3(slice_ctor(data));
    NSData *hash = NSDataFromPtr(result);
    u256_dtor(result);
    return hash.UInt256;
}

+ (NSData *)encryptData:(NSData *)data
              secretKey:(DOpaqueKey *)secretKey
              publicKey:(DOpaqueKey *)publicKey {
    DMaybeKeyData *result = DOpaqueKeyEncryptData(secretKey, publicKey, slice_ctor(data));
    NSData *encrypted = NSDataFromPtr(result->ok);
    DMaybeKeyDataDtor(result);
    return encrypted;
}

+ (NSData *)encryptData:(NSData *)data
              secretKey:(DOpaqueKey *)secretKey
              publicKey:(DOpaqueKey *)publicKey
                usingIV:(NSData *)iv {
    DMaybeKeyData *result = DOpaqueKeyEncryptDataUsingIV(secretKey, publicKey, slice_ctor(data), bytes_ctor(iv));
    NSData *encrypted = NSDataFromPtr(result->ok);
    DMaybeKeyDataDtor(result);
    return encrypted;
}

+ (NSData *)decryptData:(NSData *)data
              secretKey:(DOpaqueKey *)secretKey
              publicKey:(DOpaqueKey *)publicKey {
    DMaybeKeyData *result = DOpaqueKeyDecryptData(secretKey, publicKey, slice_ctor(data));
    NSData *decrypted = NSDataFromPtr(result->ok);
    DMaybeKeyDataDtor(result);
    return decrypted;
}

+ (NSData *)decryptData:(NSData *)data
              secretKey:(DOpaqueKey *)secretKey
              publicKey:(DOpaqueKey *)publicKey
            usingIVSize:(NSUInteger)ivSize {
    DMaybeKeyData *result = DOpaqueKeyDecryptDataUsingIV(secretKey, publicKey, slice_ctor(data), ivSize);
    NSData *decrypted = NSDataFromPtr(result->ok);
    DMaybeKeyDataDtor(result);
    return decrypted;
}

+ (NSData *)encryptData:(NSData *)data
              withDHKey:(DOpaqueKey *)dhKey {
    DMaybeKeyData *result = DOpaqueKeyEncryptDataWithDHKey(dhKey, bytes_ctor(data));
    NSData *encrypted = NSDataFromPtr(result->ok);
    DMaybeKeyDataDtor(result);
    return encrypted;
}

+ (NSData *)decryptData:(NSData *)data
              withDHKey:(DOpaqueKey *)dhKey {
    DMaybeKeyData *result = DOpaqueKeyDecryptDataWithDHKey(dhKey, bytes_ctor(data));
    NSData *decrypted = NSDataFromPtr(result->ok);
    DMaybeKeyDataDtor(result);
    return decrypted;
}

+ (BOOL)verifyProRegTXPayloadSignature:(NSData *)signature
                               payload:(NSData *)payload
                          ownerKeyHash:(UInt160)ownerKeyHash {
    Slice_u8 *sig = slice_ctor(signature);
    Slice_u8 *pld = slice_ctor(payload);
    u160 *hash = u160_ctor_u(ownerKeyHash);
    return DECDSAKeyProRegTxVerifyPayloadSig(sig, pld, hash);
}

+ (NSString *_Nullable)devnetIdentifierFor:(DChainType *)chainType {
    return [DSKeyManager NSStringFrom:dash_spv_crypto_network_chain_type_ChainType_devnet_identifier(chainType)];
}

@end
