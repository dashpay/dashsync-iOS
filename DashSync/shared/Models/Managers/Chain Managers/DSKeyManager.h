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

#import <Foundation/Foundation.h>
#import "dash_shared_core.h"
#import "DSChain.h"
#import "NSIndexPath+FFI.h"

#define NSDataToHeap(data) (^{ \
    uint8_t *ffi_ref = malloc(data.length); \
    memcpy(ffi_ref, data.bytes, data.length); \
    return ffi_ref; \
}())

#define u128 Arr_u8_16
#define u160 Arr_u8_20
#define u256 Arr_u8_32
#define u264 Arr_u8_33
#define u384 Arr_u8_48
#define u512 Arr_u8_64
#define u768 Arr_u8_96

#define u128_ctor(data) Arr_u8_16_ctor(data.length, NSDataToHeap(data))
#define u160_ctor(data) Arr_u8_20_ctor(data.length, NSDataToHeap(data))
#define u256_ctor(data) Arr_u8_32_ctor(data.length, NSDataToHeap(data))
#define u264_ctor(data) Arr_u8_33_ctor(data.length, NSDataToHeap(data))
#define u384_ctor(data) Arr_u8_48_ctor(data.length, NSDataToHeap(data))
#define u512_ctor(data) Arr_u8_64_ctor(data.length, NSDataToHeap(data))
#define u768_ctor(data) Arr_u8_96_ctor(data.length, NSDataToHeap(data))

#define u128_cast(u) *((UInt128 *)u->values)
#define u160_cast(u) *((UInt160 *)u->values)
#define u256_cast(u) *((UInt256 *)u->values)
#define u384_cast(u) *((UInt384 *)u->values)
#define u512_cast(u) *((UInt512 *)u->values)
#define u768_cast(u) *((UInt768 *)u->values)

#define u128_hex(u) uint128_hex(*((UInt128 *)u->values))
#define u160_hex(u) uint160_hex(*((UInt160 *)u->values))
#define u256_hex(u) uint256_hex(*((UInt256 *)u->values))
#define u384_hex(u) uint384_hex(*((UInt384 *)u->values))
#define u512_hex(u) uint512_hex(*((UInt512 *)u->values))
#define u768_hex(u) uint768_hex(*((UInt768 *)u->values))

#define u128_reversed_hex(u) uint128_hex(uint128_reverse(*((UInt128 *)u->values)))
#define u160_reversed_hex(u) uint160_hex(uint160_reverse(*((UInt160 *)u->values)))
#define u256_reversed_hex(u) uint256_hex(uint256_reverse(*((UInt256 *)u->values)))
#define u384_reversed_hex(u) uint384_hex(uint384_reverse(*((UInt384 *)u->values)))
#define u512_reversed_hex(u) uint512_hex(uint512_reverse(*((UInt512 *)u->values)))
#define u768_reversed_hex(u) uint768_hex(uint768_reverse(*((UInt768 *)u->values)))

#define u8_16_ctor_u(u) (^{ \
    uint8_t (*ffi_ref)[16] = malloc(16 * sizeof(uint8_t)); \
    memcpy(ffi_ref, u.u8, 16); \
    return ffi_ref; \
}())

#define u8_20_ctor_u(u) (^{ \
    uint8_t (*ffi_ref)[20] = malloc(20 * sizeof(uint8_t)); \
    memcpy(ffi_ref, u.u8, 20); \
    return ffi_ref; \
}())
#define u8_32_ctor_u(u) (^{ \
    uint8_t (*ffi_ref)[32] = malloc(32 * sizeof(uint8_t)); \
    memcpy(ffi_ref, u.u8, 32); \
    return ffi_ref; \
}())

#define u8_48_ctor_u(u) (^{ \
    uint8_t (*ffi_ref)[48] = malloc(48 * sizeof(uint8_t)); \
    memcpy(ffi_ref, u.u8, 48); \
    return ffi_ref; \
}())

#define u8_64_ctor_u(u) (^{ \
    uint8_t (*ffi_ref)[64] = malloc(64 * sizeof(uint8_t)); \
    memcpy(ffi_ref, u.u8, 64); \
    return ffi_ref; \
}())

#define u8_96_ctor_u(u) (^{ \
    uint8_t (*ffi_ref)[96] = malloc(96 * sizeof(uint8_t)); \
    memcpy(ffi_ref, u.u8, 96); \
    return ffi_ref; \
}())

#define u128_ctor_u(u) (^{ \
    uint8_t *ffi_ref = malloc(16 * sizeof(uint8_t)); \
    memcpy(ffi_ref, u.u8, 16); \
    return Arr_u8_16_ctor(16, ffi_ref); \
}())
#define u160_ctor_u(u) (^{ \
    uint8_t *ffi_ref = malloc(20 * sizeof(uint8_t)); \
    memcpy(ffi_ref, u.u8, 20); \
    return Arr_u8_20_ctor(20, ffi_ref); \
}())
#define u256_ctor_u(u) (^{ \
    uint8_t *ffi_ref = malloc(32 * sizeof(uint8_t)); \
    memcpy(ffi_ref, u.u8, 32); \
    return Arr_u8_32_ctor(32, ffi_ref); \
}())
#define u384_ctor_u(u) (^{ \
    uint8_t *ffi_ref = malloc(48 * sizeof(uint8_t)); \
    memcpy(ffi_ref, u.u8, 48); \
    return Arr_u8_48_ctor(48, ffi_ref); \
}())
#define u512_ctor_u(u) (^{ \
    uint8_t *ffi_ref = malloc(64 * sizeof(uint8_t)); \
    memcpy(ffi_ref, u.u8, 64); \
   return Arr_u8_64_ctor(64, ffi_ref); \
}())
#define u768_ctor_u(u) (^{ \
    uint8_t *ffi_ref = malloc(96 * sizeof(uint8_t)); \
    memcpy(ffi_ref, u.u8, 96); \
    return Arr_u8_96_ctor(96, ffi_ref); \
}())


#define u128_dtor(ptr) Arr_u8_16_destroy(ptr)
#define u160_dtor(ptr) Arr_u8_20_destroy(ptr)
#define u256_dtor(ptr) Arr_u8_32_destroy(ptr)
#define u264_dtor(ptr) Arr_u8_33_destroy(ptr)
#define u384_dtor(ptr) Arr_u8_48_destroy(ptr)
#define u512_dtor(ptr) Arr_u8_64_destroy(ptr)
#define u768_dtor(ptr) Arr_u8_96_destroy(ptr)

#define u_is_zero(ptr) ({ \
    BOOL result = YES;                                         \
    for (uintptr_t i = 0; i < ptr->count; i++) {              \
        if (ptr->values[i] != 0) {                            \
            result = NO;                                       \
            break;                                             \
        }                                                      \
    }                                                          \
    result;                                                    \
})

#define slice_ctor(data) Slice_u8_ctor(data.length, NSDataToHeap(data))
#define slice_u128_ctor_u(u) Slice_u8_ctor(16, u.u8)
#define slice_u160_ctor_u(u) Slice_u8_ctor(20, u.u8)
#define slice_u256_ctor_u(u) Slice_u8_ctor(32, u.u8)
#define slice_u384_ctor_u(u) Slice_u8_ctor(48, u.u8)
#define slice_u512_ctor_u(u) Slice_u8_ctor(64, u.u8)
#define slice_u768_ctor_u(u) Slice_u8_ctor(96, u.u8)

#define slice_dtor(ptr) Slice_u8_destroy(ptr)

#define bytes_ctor(data) Vec_u8_ctor(data.length, NSDataToHeap(data))
#define bytes_dtor(ptr) Vec_u8_destroy(ptr)

#define DChar(str) (char *) [str UTF8String]
#define DCharDtor(str) str_destroy(str)


#define DMNSyncState dash_spv_masternode_processor_models_sync_state_CacheState
#define DMNSyncStateDtor(ptr) dash_spv_masternode_processor_models_sync_state_CacheState_destroy(ptr)
#define DMNSyncStateQueueChanged dash_spv_masternode_processor_models_sync_state_CacheState_QueueChanged
#define DMNSyncStateStoreChanged dash_spv_masternode_processor_models_sync_state_CacheState_StoreChanged
#define DMNSyncStateStubCount dash_spv_masternode_processor_models_sync_state_CacheState_StubCount

#define MaybePubKey Result_ok_u8_arr_48_err_drive_proof_verifier_error_ContextProviderError
#define MaybePubKeyDtor Result_ok_u8_arr_48_err_drive_proof_verifier_error_ContextProviderError_destroy
#define DDataContract dpp_data_contract_DataContract
#define MaybeDataContract Result_ok_Option_std_sync_Arc_dpp_data_contract_DataContract_err_drive_proof_verifier_error_ContextProviderError
#define MaybeDataContractDtor Result_ok_Option_std_sync_Arc_dpp_data_contract_DataContract_err_drive_proof_verifier_error_ContextProviderError_destroy
#define MaybeSignedData Result_ok_platform_value_types_binary_data_BinaryData_err_dpp_errors_protocol_error_ProtocolError
#define MaybeSignedDataDtor Result_ok_platform_value_types_binary_data_BinaryData_err_dpp_errors_protocol_error_ProtocolError_destroy
#define MaybePlatformActivationHeight Result_ok_dpp_prelude_CoreBlockHeight_err_drive_proof_verifier_error_ContextProviderError

#define DCoreProviderError dash_spv_masternode_processor_processing_core_provider_CoreProviderError
#define DCoreProviderErrorNullResultCtor(message) dash_spv_masternode_processor_processing_core_provider_CoreProviderError_NullResult_ctor(message)
#define MaybeBool Result_ok_bool_err_dash_spv_masternode_processor_processing_core_provider_CoreProviderError
#define MaybeLLMQSnapshot Result_ok_dash_spv_masternode_processor_models_snapshot_LLMQSnapshot_err_dash_spv_masternode_processor_processing_core_provider_CoreProviderError

#define DBlock dash_spv_masternode_processor_common_block_Block
#define DBlockCtor(height, hash) dash_spv_masternode_processor_common_block_Block_ctor(height, hash)

#define DMBlock dash_spv_masternode_processor_common_block_MBlock
#define DMBlockCtor(height, hash, merkle_root) dash_spv_masternode_processor_common_block_MBlock_ctor(height, hash, merkle_root)

#define DMaybeBlock Result_ok_dash_spv_masternode_processor_common_block_Block_err_dash_spv_masternode_processor_processing_core_provider_CoreProviderError
#define DMaybeBlockCtor(ok, err) Result_ok_dash_spv_masternode_processor_common_block_Block_err_dash_spv_masternode_processor_processing_core_provider_CoreProviderError_ctor(ok, err)
#define DMaybeBlockDtor(ptr) Result_ok_dash_spv_masternode_processor_common_block_Block_err_dash_spv_masternode_processor_processing_core_provider_CoreProviderError_destroy(ptr)

#define DMaybeMBlock Result_ok_dash_spv_masternode_processor_common_block_MBlock_err_dash_spv_masternode_processor_processing_core_provider_CoreProviderError
#define DMaybeMBlockCtor(ok, err) Result_ok_dash_spv_masternode_processor_common_block_MBlock_err_dash_spv_masternode_processor_processing_core_provider_CoreProviderError_ctor(ok, err)

#define DMasternodeList dashcore_sml_masternode_list_MasternodeList
#define DMasternodeListDtor(ptr) dashcore_sml_masternode_list_MasternodeList_destroy(ptr)
#define DMaybeMasternodeList Result_ok_dashcore_sml_masternode_list_MasternodeList_err_dash_spv_masternode_processor_processing_core_provider_CoreProviderError

#define DMasternodeEntry dashcore_sml_masternode_list_entry_qualified_masternode_list_entry_QualifiedMasternodeListEntry
#define DMasternodeEntryDtor(ptr) dashcore_sml_masternode_list_entry_qualified_masternode_list_entry_QualifiedMasternodeListEntry_destroy(ptr)
#define DMasternodeEntryList Vec_dashcore_sml_masternode_list_entry_qualified_masternode_list_entry_QualifiedMasternodeListEntry
#define DMasternodeEntryListCtor(count, list) Vec_dashcore_sml_masternode_list_entry_qualified_masternode_list_entry_QualifiedMasternodeListEntry_ctor(count, list)
#define DMasternodeEntryListDtor(ptr) Vec_dashcore_sml_masternode_list_entry_qualified_masternode_list_entry_QualifiedMasternodeListEntry_destroy(ptr)
#define DMasternodeEntryMapDtor(ptr) std_collections_Map_keys_u8_arr_32_values_dashcore_sml_masternode_list_entry_qualified_masternode_list_entry_QualifiedMasternodeListEntry_destroy(ptr)
#define DLLMQEntry dashcore_sml_quorum_entry_qualified_quorum_entry_QualifiedQuorumEntry
#define DLLMQEntryDtor(ptr) dashcore_sml_quorum_entry_qualified_quorum_entry_QualifiedQuorumEntry_destroy(ptr)

#define DLLMQEntryList Vec_dash_spv_crypto_llmq_entry_LLMQEntry
#define DLLMQEntryListCtor(count, list) Vec_dash_spv_crypto_llmq_entry_LLMQEntry_ctor(count, list)

#define DLLMQType dash_spv_crypto_network_llmq_type_LLMQType
#define DLLMQSnapshot dash_spv_masternode_processor_models_snapshot_LLMQSnapshot
#define DKeyError dash_spv_crypto_keys_KeyError
#define DKeyKind dash_spv_crypto_keys_key_KeyKind
#define DKeyKindIndex(kind) dash_spv_crypto_keys_key_KeyKind_index(kind)
#define DKeyKindFromIndex(index) dash_spv_crypto_keys_key_key_kind_from_index(index)
#define DKeyKindDtor(ptr) dash_spv_crypto_keys_key_KeyKind_destroy(ptr)
#define DKeyKindECDSA() dash_spv_crypto_keys_key_KeyKind_ECDSA_ctor()
#define DKeyKindBLS() dash_spv_crypto_keys_key_KeyKind_BLS_ctor()
#define DKeyKindED25519() dash_spv_crypto_keys_key_KeyKind_ED25519_ctor()
#define DKeyKindStoragePrefix(kind) dash_spv_crypto_keys_key_KeyKind_key_storage_prefix(kind)
#define DKeyKindDerivationString(kind) dash_spv_crypto_keys_key_KeyKind_derivation_string(kind)
#define DKeyVerificationResult Result_ok_bool_err_dash_spv_crypto_keys_KeyError
#define DKeyVerificationResultDtor(ptr) Result_ok_bool_err_dash_spv_crypto_keys_KeyError_destroy(ptr)

#define DMaybeECDSAKey Result_ok_dash_spv_crypto_keys_ecdsa_key_ECDSAKey_err_dash_spv_crypto_keys_KeyError
#define DMaybeECDSAKeyDtor(ptr) Result_ok_dash_spv_crypto_keys_ecdsa_key_ECDSAKey_err_dash_spv_crypto_keys_KeyError_destroy(ptr)
#define DMaybeECDSAKeyWithPrivateKey(key_str, chain_type) dash_spv_crypto_keys_ecdsa_key_ECDSAKey_key_with_private_key(key_str, chain_type)
#define DECDSAKeyPublicKeyData(key) dash_spv_crypto_keys_ecdsa_key_ECDSAKey_public_key_data(key)
#define DECDSAKeyPublicKeyDataForPrivateKey(key_str, chain_type) dash_spv_crypto_keys_ecdsa_key_ECDSAKey_public_key_data_for_private_key(key_str, chain_type)
#define DECDSAKeySign(key, data) dash_spv_crypto_keys_ecdsa_key_ECDSAKey_sign(key, data)
#define DECDSAKeyCompactSign(key, data) dash_spv_crypto_keys_ecdsa_key_ECDSAKey_compact_sign(key, data)
#define DECDSAKeyPublicKeyHash(key) dash_spv_crypto_keys_ecdsa_key_ECDSAKey_hash160(key)
#define DECDSAKeyPubAddress(key, chain_type) dash_spv_crypto_keys_ecdsa_key_ECDSAKey_address_with_public_key_data(key, chain_type)
#define DECDSAKeyWithSecret(data, compressed) dash_spv_crypto_keys_ecdsa_key_ECDSAKey_key_with_secret_data(data, compressed)
#define DECDSAKeyWithPublicKeyData(data) dash_spv_crypto_keys_ecdsa_key_ECDSAKey_key_with_public_key_data(data)
#define DECDSAKeyWithPublicKeyDataEqualTo(key, data) dash_spv_crypto_keys_ecdsa_key_ECDSAKey_public_key_data_equal_to(key, data)
#define DECDSAKeyWithCompactSig(sig, digest) dash_spv_crypto_keys_ecdsa_key_ECDSAKey_key_with_compact_sig(sig, digest)
#define DECDSAKeyFromCompactSig(sig, digest) dash_spv_crypto_keys_ecdsa_key_ECDSAKey_key_recovered_from_compact_sig(sig, digest)
#define DECDSAKeyFromSeedData(data) dash_spv_crypto_keys_ecdsa_key_ECDSAKey_init_with_seed_data(data)
#define DECDSAKeySerializedPrivateKey(key, script) dash_spv_crypto_keys_ecdsa_key_ECDSAKey_serialized_private_key_for_script(key, script)
#define DECDSAKeySerializedPrivateMasterKey(seed, chain_type) dash_spv_crypto_keys_ecdsa_key_ECDSAKey_serialized_private_master_key_from_seed(seed, chain_type)
#define DECDSAKeySerializedPrivateKeyFromSeedAtU256(seed, path, chain_type) dash_spv_crypto_keys_ecdsa_key_ECDSAKey_serialized_extended_private_key_from_seed_at_u256_path(seed, path, chain_type)
#define DECDSAKeySerializedPrivateKeyFromBIP38(bip38_key, passphrase, chain_type) dash_spv_crypto_keys_ecdsa_key_ECDSAKey_serialized_from_bip38_key(bip38_key, passphrase, chain_type)
#define DECDSAKeySerializedAuthPrivateKeyFromSeed(seed, chain_type) dash_spv_crypto_keys_ecdsa_key_ECDSAKey_serialized_auth_private_key_from_seed_for_chain(seed, chain_type)
#define DECDSAKeyIsValidBIP38(bip38_key) dash_spv_crypto_keys_ecdsa_key_ECDSAKey_is_valid_bip38_key(bip38_key)
#define DECDSAPublicKeyUniqueIdFromDerivedKeyData(secret, chain_type) dash_spv_crypto_keys_ecdsa_key_ECDSAKey_public_key_unique_id_from_derived_key_data(secret, chain_type)
#define DECDSAKeyProRegTxPayloadCollateralDigest(payload_hash, script_payout, reward, owner_hash, voter_hash, chain_type) dash_spv_crypto_keys_ecdsa_key_ECDSAKey_pro_reg_tx_payload_collateral_digest(payload_hash, script_payout, reward, owner_hash, voter_hash, chain_type)
#define DECDSAKeyProRegTxVerifyPayloadSig(sig, payload, hash) dash_spv_crypto_keys_ecdsa_key_ECDSAKey_pro_reg_tx_verify_payload_signature(sig, payload, hash)
#define DECDSAKeyContainsSecretKey(sec_key_str, chain_type) dash_spv_crypto_keys_ecdsa_key_ECDSAKey_contains_secret_key(sec_key_str, chain_type)

#define DECDSAKeyAddressFromPublicKeyData(data, chain_type) dash_spv_crypto_keys_ecdsa_key_ECDSAKey_address_from_public_key_data(data, chain_type)
#define DECDSAKeyAddressFromRecoveredCompactSig(sig, digest, chain_type) dash_spv_crypto_keys_ecdsa_key_ECDSAKey_address_from_recovered_compact_sig(sig, digest, chain_type)

#define DBLSKeyWithPublicKey(key, legacy) dash_spv_crypto_keys_bls_key_BLSKey_key_with_public_key(key, legacy)
#define DBLSKeyWithSeedData(data, legacy) dash_spv_crypto_keys_bls_key_BLSKey_key_with_seed_data(data, legacy)
#define DBLSKeyPublicKeyData(key) dash_spv_crypto_keys_bls_key_BLSKey_public_key_data(key)
#define DBLSKeyPrivateKeyData(key) dash_spv_crypto_keys_bls_key_BLSKey_private_key_data(key)
#define DBLSKeySignData(key, data) dash_spv_crypto_keys_bls_key_BLSKey_sign_data(key, data)
#define DBLSKeyVerify(key, digest, sig) dash_spv_crypto_keys_bls_key_BLSKey_verify(key, digest, sig)
#define DBLSKeyVerifySig(key, legacy, digest, sig) dash_spv_crypto_keys_bls_key_BLSKey_verify_signature(key, legacy, digest, sig)
#define DBLSKeySerializedPubKey(key, legacy) dash_spv_crypto_keys_bls_key_BLSKey_public_key_serialized(key, legacy)

#define DOpaqueKey dash_spv_crypto_keys_key_OpaqueKey
#define DOpaqueKeyDtor(ptr) dash_spv_crypto_keys_key_OpaqueKey_destroy(ptr)
#define DOpaqueKeyExtendedPublicKeyData(ptr) dash_spv_crypto_keys_key_OpaqueKey_extended_public_key_data(ptr)

#define DOpaqueKeyEncryptData(prv_key, pub_key, data) dash_spv_crypto_keys_key_OpaqueKey_encrypt_data(prv_key, pub_key, data)
#define DOpaqueKeyEncryptDataUsingIV(prv_key, pub_key, data, iv) dash_spv_crypto_keys_key_OpaqueKey_encrypt_data_using_iv(prv_key, pub_key, data, iv)
#define DOpaqueKeyEncryptDataWithDHKey(key, data) dash_spv_crypto_keys_key_OpaqueKey_encrypt_data_with_dh_key(key, data)
#define DOpaqueKeyDecryptData(prv_key, pub_key, data) dash_spv_crypto_keys_key_OpaqueKey_decrypt_data(prv_key, pub_key, data)
#define DOpaqueKeyDecryptDataUsingIV(prv_key, pub_key, data, iv) dash_spv_crypto_keys_key_OpaqueKey_decrypt_data_using_iv_size(prv_key, pub_key, data, iv)
#define DOpaqueKeyDecryptDataWithDHKey(key, data) dash_spv_crypto_keys_key_OpaqueKey_decrypt_data_with_dh_key(key, data)

#define DOpaqueKeySign(key, data) dash_spv_crypto_keys_key_OpaqueKey_sign(key, data)
#define DOpaqueKeyPrivateKeyData(key) dash_spv_crypto_keys_key_OpaqueKey_private_key_data(key)
#define DOpaqueKeyPublicKeyData(key) dash_spv_crypto_keys_key_OpaqueKey_public_key_data(key)
#define DOpaqueKeyPublicKeyHash(key) dash_spv_crypto_keys_key_OpaqueKey_hash160(key)
#define DOpaqueKeyHashAndSign(key, data) dash_spv_crypto_keys_key_OpaqueKey_hash_and_sign(key, data)
#define DOpaqueKeyCreateIdentifier(key) dash_spv_crypto_keys_key_OpaqueKey_create_identifier(key)
#define DOpaqueKeyCreateAccountRef(src_key, dst_key, acc_number) dash_spv_crypto_keys_key_OpaqueKey_create_account_reference(src_key, dst_key, acc_number)
#define DOpaqueKeyCreateTxSig(key, input, flags, in_script) dash_spv_crypto_keys_key_OpaqueKey_create_tx_signature(key, input, flags, in_script)
#define DOpaqueKeyHasPrivateKey(key) dash_spv_crypto_keys_key_OpaqueKey_has_private_key(key)
#define DOpaqueKeyForgetPrivateKey(key) dash_spv_crypto_keys_key_OpaqueKey_forget_private_key(key)
#define DOpaqueKeyDerivateTo256WithOffset(key, path, offset) dash_spv_crypto_keys_key_OpaqueKey_public_derive_to_256_path_with_offset(key, path, offset)
#define DOpaqueKeyVerify(key, payload, signature) dash_spv_crypto_keys_key_OpaqueKey_verify(key, payload, signature)
#define DOpaqueKeyCheckPayloadSignature(key, hash) dash_spv_crypto_keys_key_OpaqueKey_check_payload_signature(key, hash)
#define DOpaqueKeySerializedPrivateKey(key, script) dash_spv_crypto_keys_key_OpaqueKey_serialized_private_key_for_script(key, script)
#define DOpaqueKeyPublicKeyDataEqualTo(key, data) dash_spv_crypto_keys_key_OpaqueKey_public_key_data_equal_to(key, data)
#define DOpaqueKeyPublicKeyDataAtIndexPath(key, index_path) dash_spv_crypto_keys_key_OpaqueKey_public_key_data_at_index_path(key, index_path)
#define DOpaqueKeyPublicKeyFromExtPubKeyDataAtIndexPath(key, index_path) dash_spv_crypto_keys_key_OpaqueKey_public_key_from_extended_public_key_data_at_index_path(key, index_path)
#define DOpaqueKeyPrivateKeyDataEqualTo(key, data) dash_spv_crypto_keys_key_OpaqueKey_private_key_data_equal_to(key, data)
#define DOpaqueKeyExtPrivateKeyData(key) dash_spv_crypto_keys_key_OpaqueKey_extended_private_key_data(key)
#define DOpaqueKeySecretKeyString(key) dash_spv_crypto_keys_key_OpaqueKey_secret_key_string(key)
#define DOpaqueKeyHasKind(key, kind) dash_spv_crypto_keys_key_OpaqueKey_has_kind(key, kind)
#define DOpaqueKeyDecrypt(prv_key, pub_key, data) dash_spv_crypto_keys_key_OpaqueKey_decrypt_data_vec(prv_key, pub_key, data)
#define DOpaqueKeyPubAddress(key, chain_type) dash_spv_crypto_keys_key_OpaqueKey_address_with_public_key_data(key, chain_type)

#define DScriptPubKeyForAddress(address, chain_type) dash_spv_apple_bindings_address_addresses_script_pubkey_for_address(address, chain_type)
#define DIsValidDashAddress(address, chain_type) dash_spv_apple_bindings_address_addresses_is_valid_dash_address_for_chain(address, chain_type)
#define DAddressWithScriptPubKeyData(data, chain_type) dash_spv_apple_bindings_address_addresses_address_with_script_pubkey(data, chain_type)
#define DMaybeOpaqueKeyFromSeed(kind, seed) dash_spv_crypto_keys_key_KeyKind_key_with_seed_data(kind, seed)
#define DMaybeDeriveOpaqueKeyFromExtendedPrivateKeyDataForIndexPath(kind, data, index_path) dash_spv_crypto_keys_key_KeyKind_derive_key_from_extended_private_key_data_for_index_path(kind, data, index_path)
#define DMaybeOpaqueKeyWithPrivateKeyData(kind, data) dash_spv_crypto_keys_key_KeyKind_key_with_private_key_data(kind, data)
#define DMaybeOpaqueKeyWithPrivateKey(kind, key_str, data) dash_spv_crypto_keys_key_KeyKind_key_with_private_key(kind, key_str, data)
#define DMaybeOpaqueKeyWithPublicKeyData(kind, data) dash_spv_crypto_keys_key_KeyKind_key_with_public_key_data(kind, data)
#define DMaybeOpaqueKeyInitWithExtendedPublicKeyData(kind, data) dash_spv_crypto_keys_key_KeyKind_key_init_with_extended_public_key_data(kind, data)
#define DMaybeOpaqueKeyWithExtendedPublicKeyData(kind, data) dash_spv_crypto_keys_key_KeyKind_key_with_extended_public_key_data(kind, data)
#define DMaybeOpaqueKeyWithExtendedPrivateKeyData(kind, data) dash_spv_crypto_keys_key_KeyKind_key_with_extended_private_key_data(kind, data)
#define DMaybeOpaqueKeyFromExtendedPublicKeyDataAtU256(kind, data, path) dash_spv_crypto_keys_key_KeyKind_public_key_from_extended_public_key_data_at_index_path_256(kind, data, path)
#define DMaybeOpaquePrivateKeyAtIndexPathWrapped(kind, seed, index_path, derivation_path) dash_spv_crypto_keys_key_KeyKind_private_key_at_index_path_wrapped(kind, seed, index_path, derivation_path)
#define DMaybeOpaquePrivateKeysAtIndexPathsWrapped(kind, seed, index_paths, derivation_path) dash_spv_crypto_keys_key_KeyKind_private_keys_at_index_paths_wrapped(kind, seed, index_paths, derivation_path)
#define DMaybeSerializedOpaquePrivateKeysAtIndexPathsWrapped(kind, seed, index_paths, derivation_path, chain_type) dash_spv_crypto_keys_key_KeyKind_serialized_private_keys_at_index_paths_wrapper(kind, seed, index_paths, derivation_path, chain_type)
#define DOpaqueKeyUsedInTxInputScript(in_script, key, chain_type) dash_spv_crypto_keys_key_maybe_opaque_key_used_in_tx_input_script(in_script, key, chain_type)

#define DMaybeOpaqueKey Result_ok_dash_spv_crypto_keys_key_OpaqueKey_err_dash_spv_crypto_keys_KeyError
#define DMaybeOpaqueKeys Result_ok_Vec_dash_spv_crypto_keys_key_OpaqueKey_err_dash_spv_crypto_keys_KeyError
#define DMaybeKeyData Result_ok_Vec_u8_err_dash_spv_crypto_keys_KeyError
#define DMaybeKeyString Result_ok_String_err_dash_spv_crypto_keys_KeyError
#define DChainType dash_spv_crypto_network_chain_type_ChainType
#define DDevnetType dash_spv_crypto_network_chain_type_DevnetType
#define DIndexPathU256 dash_spv_crypto_keys_key_IndexPathU256
#define DMaybeOpaqueKeyDtor(ptr) Result_ok_dash_spv_crypto_keys_key_OpaqueKey_err_dash_spv_crypto_keys_KeyError_destroy(ptr)
#define DMaybeKeyDataDtor(ptr) Result_ok_Vec_u8_err_dash_spv_crypto_keys_KeyError_destroy(ptr)
#define DMaybeKeyStringDtor(ptr) Result_ok_String_err_dash_spv_crypto_keys_KeyError_destroy(ptr)

#define DIdentityPublicKey dpp_identity_identity_public_key_IdentityPublicKey
#define DIdentifier platform_value_types_identifier_Identifier
#define DRetry dash_spv_platform_util_RetryStrategy
#define DRetryLinear(max_retry) dash_spv_platform_util_RetryStrategy_Linear_ctor(max_retry)
#define DRetryDown20(max_retry) dash_spv_platform_util_RetryStrategy_SlowingDown20Percent_ctor(max_retry)
#define DRetryDown50(max_retry) dash_spv_platform_util_RetryStrategy_SlowingDown50Percent_ctor(max_retry)

#define DNotFoundAsAnError() dash_spv_platform_document_manager_DocumentValidator_None_ctor()
#define DNotFoundAsNotAnError() dash_spv_platform_document_manager_DocumentValidator_AcceptNotFoundAsNotAnError_ctor()

#define DProcessingError dash_spv_masternode_processor_processing_processor_processing_error_ProcessingError
#define DQRInfoResult Result_ok_std_collections_BTreeSet_dashcore_hash_types_BlockHash_err_dash_spv_masternode_processor_processing_processor_processing_error_ProcessingError
#define DQRInfoResultDtor(ptr) Result_ok_std_collections_BTreeSet_dashcore_hash_types_BlockHash_err_dash_spv_masternode_processor_processing_processor_processing_error_ProcessingError_destroy(ptr)

#define DMnDiffFromFile(processor, message, protocol_version) dash_spv_masternode_processor_processing_processor_MasternodeProcessor_mn_list_diff_result_from_file(processor, message, protocol_version)
#define DMnDiffFromMessage(proc, message, height, verify) dash_spv_masternode_processor_processing_processor_MasternodeProcessor_process_mn_list_diff_result_from_message(proc, message, height, verify)

#define DMnEngineDeserializationResult Result_ok_usize_err_dash_spv_masternode_processor_processing_processor_processing_error_ProcessingError
#define DMnEngineDeserializationResultDtor(ptr) Result_ok_usize_err_dash_spv_masternode_processor_processing_processor_processing_error_ProcessingError_destroy(ptr)
#define DMnDiffResult Result_Tuple_dashcore_hash_types_BlockHash_dashcore_hash_types_BlockHash_err_dash_spv_masternode_processor_processing_processor_processing_error_ProcessingError
#define DMnDiffResultDtor(ptr) Result_Tuple_dashcore_hash_types_BlockHash_dashcore_hash_types_BlockHash_err_dash_spv_masternode_processor_processing_processor_processing_error_ProcessingError_destroy(ptr)

#define DMasternodeListForBlockHash(processor, block_hash) dash_spv_masternode_processor_processing_processor_MasternodeProcessor_masternode_list_for_block_hash(processor, block_hash)

#define DMasternodeListByBlockHash(cache, block_hash) dash_spv_masternode_processor_processing_processor_cache_MasternodeProcessorCache_masternode_list_by_block_hash(cache, block_hash)

#define DMasternodeListReversedProRegTxHashes(list) dashcore_sml_masternode_list_MasternodeList_reversed_pro_reg_tx_hashes_cloned(list)

#define DProcessorClear(proc) dash_spv_masternode_processor_processing_processor_MasternodeProcessor_clear(proc)

#define DMasternodeEntryByProRegTxHash(list, hash) dashcore_sml_masternode_list_MasternodeList_masternode_by_pro_reg_tx_hash(list, hash)

#define NSDataFromPtr(ptr) ptr ? [NSData dataWithBytes:(const void *)ptr->values length:ptr->count] : nil
#define NSStringFromPtr(ptr) ptr ? [NSString stringWithCString:ptr encoding:NSUTF8StringEncoding] : nil

#define DKnownMasternodeListsCount(proc) dash_spv_masternode_processor_processing_processor_MasternodeProcessor_known_masternode_lists_count(proc)
#define DCurrentMasternodeListBlockHeight(proc) dash_spv_masternode_processor_processing_processor_MasternodeProcessor_current_masternode_list_height(proc)
#define DHeightForBlockHash(proc, hash) dash_spv_masternode_processor_processing_processor_MasternodeProcessor_height_for_block_hash(proc, hash)

#define DMasternodeEntryVotingAddress(entry, chain_type) dash_spv_masternode_processor_processing_voting_address(entry, chain_type)
#define DMasternodeEntryOperatorPublicKeyAddress(entry, chain_type) dash_spv_masternode_processor_processing_operator_public_key_address(entry, chain_type)
#define DMasternodeEntryEvoNodeAddress(entry, chain_type) dash_spv_masternode_processor_processing_evo_node_address(entry, chain_type)
#define DAddMasternodeList(cache, hash, list) dash_spv_masternode_processor_processing_processor_cache_MasternodeProcessorCache_add_masternode_list(cache, hash, list)
#define DRemoveMasternodeList(cache, hash) dash_spv_masternode_processor_processing_processor_cache_MasternodeProcessorCache_remove_masternode_list(cache, hash)
#define DRemoveMasternodeListsBefore(cache, height) dash_spv_masternode_processor_processing_processor_cache_MasternodeProcessorCache_remove_masternode_lists_before_height(cache, height)

#define DKeyType dpp_identity_identity_public_key_key_type_KeyType

#define DBinaryData platform_value_types_binary_data_BinaryData
#define DBinaryDataCtor(ptr) platform_value_types_binary_data_BinaryData_ctor(ptr)
#define DAssetLockProof dpp_identity_state_transition_asset_lock_proof_AssetLockProof
#define DDocumentTypes std_collections_Map_keys_dpp_data_contract_DocumentName_values_dpp_data_contract_document_type_DocumentType
#define DDocument dpp_document_Document
#define DDocumentsMap indexmap_IndexMap_platform_value_types_identifier_Identifier_Option_dpp_document_Document
#define DMaybeDocument Result_ok_Option_dpp_document_Document_err_dash_spv_platform_error_Error
#define DMaybeDocumentDtor(ptr) Result_ok_Option_dpp_document_Document_err_dash_spv_platform_error_Error_destroy(ptr)

#define DDocumentResult Result_ok_dpp_document_Document_err_dash_spv_platform_error_Error
#define DDocumentResultDtor(ptr) Result_ok_dpp_document_Document_err_dash_spv_platform_error_Error_destroy(ptr)

#define DMaybeDocumentsMap Result_ok_indexmap_IndexMap_platform_value_types_identifier_Identifier_Option_dpp_document_Document_err_dash_spv_platform_error_Error
#define DMaybeDocumentsMapDtor(ptr) Result_ok_indexmap_IndexMap_platform_value_types_identifier_Identifier_Option_dpp_document_Document_err_dash_spv_platform_error_Error_destroy(ptr)
#define DContactRequest dash_spv_platform_models_contact_request_ContactRequest
#define DContactRequestDtor(ptr) dash_spv_platform_models_contact_request_ContactRequest_destroy(ptr)
#define DContactRequestKind dash_spv_platform_models_contact_request_ContactRequestKind
#define DContactRequests Vec_dash_spv_platform_models_contact_request_ContactRequestKind
#define DMaybeContactRequests Result_ok_Vec_dash_spv_platform_models_contact_request_ContactRequestKind_err_dash_spv_platform_error_Error
#define DMaybeContactRequestsDtor(ptr) Result_ok_Vec_dash_spv_platform_models_contact_request_ContactRequestKind_err_dash_spv_platform_error_Error_destroy(ptr)

#define DMaybeContract Result_ok_Option_dpp_data_contract_DataContract_err_dash_spv_platform_error_Error
#define DMaybeContractDtor(ptr) Result_ok_Option_dpp_data_contract_DataContract_err_dash_spv_platform_error_Error_destroy(ptr)
#define DIdentity dpp_identity_identity_Identity
#define DMaybeIdentity Result_ok_Option_dpp_identity_identity_Identity_err_dash_spv_platform_error_Error
#define DMaybeIdentityDtor(ptr) Result_ok_Option_dpp_identity_identity_Identity_err_dash_spv_platform_error_Error_destroy(ptr)

#define DMaybeTransientUser Result_ok_Option_dash_spv_platform_models_transient_dashpay_user_TransientDashPayUser_err_dash_spv_platform_error_Error
#define DMaybeTransientUserDtor(ptr) Result_ok_Option_dash_spv_platform_models_transient_dashpay_user_TransientDashPayUser_err_dash_spv_platform_error_Error_destroy(ptr)

#define DMaybeStateTransition Result_ok_dpp_state_transition_StateTransition_err_dash_spv_platform_error_Error
#define DMaybeStateTransitionProofResult Result_ok_dpp_state_transition_proof_result_StateTransitionProofResult_err_dash_spv_platform_error_Error
#define DMaybeStateTransitionProofResultDtor(ptr) Result_ok_dpp_state_transition_proof_result_StateTransitionProofResult_err_dash_spv_platform_error_Error_destroy(ptr)

#define DGetDocProperty(document, prop) dash_spv_platform_document_get_document_property(document, DChar(prop))
#define DValue platform_value_Value
#define DValueDtor(ptr) platform_value_Value_destroy(ptr)
#define DValuePair Tuple_platform_value_Value_platform_value_Value
#define DValuePairCtor(key, value) Tuple_platform_value_Value_platform_value_Value_ctor(key, value)
#define DValuePairVec Vec_Tuple_platform_value_Value_platform_value_Value
#define DValuePairVecCtor(count, values) Vec_Tuple_platform_value_Value_platform_value_Value_ctor(count, values)
#define DValueMapCtor(value_pair_vec) platform_value_value_map_ValueMap_ctor(value_pair_vec)

#define DValueVec Vec_platform_value_Value
#define DValueVecCtor(count, values) Vec_platform_value_Value_ctor(count, values)
#define DValueTextPairCtor(key, value) DValuePairCtor(platform_value_Value_Text_ctor(DChar(key)), value)
#define DValueTextTextPairCtor(key, value) DValueTextPairCtor(key, platform_value_Value_Text_ctor(DChar(value)))
#define DValueTextBytesPairCtor(key, value) DValueTextPairCtor(key, platform_value_Value_Bytes_ctor(bytes_ctor(value)))
#define DValueTextBoolPairCtor(key, value) DValueTextPairCtor(key, platform_value_Value_Bool_ctor(value))
#define DValueTextMapPairCtor(key, value) DValueTextPairCtor(key, platform_value_Value_Map_ctor(value))
#define DValueTextU32PairCtor(key, value) DValueTextPairCtor(key, platform_value_Value_U32_ctor(value))
#define DValueTextU64PairCtor(key, value) DValueTextPairCtor(key, platform_value_Value_U64_ctor(value))
#define DValueTextIdentifierPairCtor(key, value) DValueTextPairCtor(key, platform_value_Value_Identifier_ctor(value))

#define DAddSaltForUsername(model, username, salt) dash_spv_platform_identity_model_IdentityModel_add_salt(model, DChar(username), salt)
#define DSaltForUsername(model, username) dash_spv_platform_identity_model_IdentityModel_salt_for_username(model, DChar(username))

#define DGetTextDocProperty(document, propertyName) ({ \
    NSString *result = nil; \
    DValue *value = DGetDocProperty((document), (propertyName)); \
    if (value) { \
        result = NSStringFromPtr(value->text); \
        DValueDtor(value); \
    } \
    result; \
})
#define DGetBytesDocProperty(document, propertyName) ({ \
    NSData *result = nil; \
    DValue *value = DGetDocProperty((document), (propertyName)); \
    if (value) { \
        result = NSDataFromPtr(value->bytes); \
        DValueDtor(value); \
    } \
    result; \
})
#define DGetBytes32DocProperty(document, propertyName) ({ \
    NSData *result = nil; \
    DValue *value = DGetDocProperty((document), (propertyName)); \
    if (value) { \
        result = NSDataFromPtr(value->bytes32); \
        DValueDtor(value); \
    } \
    result; \
})
#define DGetIDDocProperty(document, propertyName) ({ \
    NSData *result = nil; \
    DValue *value = DGetDocProperty((document), (propertyName)); \
    if (value) { \
        if (value->identifier && value->identifier->_0) \
            result = NSDataFromPtr(value->identifier->_0); \
        DValueDtor(value); \
    } \
    result; \
})

#define DGetIDDocProperty(document, propertyName) ({ \
    NSData *result = nil; \
    DValue *value = DGetDocProperty((document), (propertyName)); \
    if (value) { \
        if (value->identifier && value->identifier->_0) \
            result = NSDataFromPtr(value->identifier->_0); \
        DValueDtor(value); \
    } \
    result; \
})


#define DKeyID dpp_identity_identity_public_key_KeyID
#define DIdentityPublicKey dpp_identity_identity_public_key_IdentityPublicKey
#define DIdentityPublicKeysMap std_collections_Map_keys_dpp_identity_identity_public_key_KeyID_values_dpp_identity_identity_public_key_IdentityPublicKey

#define DAcceptIdentityNotFound() dash_spv_platform_identity_manager_IdentityValidator_AcceptNotFoundAsNotAnError_ctor()
#define DRaiseIdentityNotFound() dash_spv_platform_identity_manager_IdentityValidator_None_ctor()

#define DOpaqueKeyFromIdentityPubKey(key) dash_spv_platform_identity_manager_opaque_key_from_identity_public_key(key)
#define DOpaqueKeyToKeyTypeIndex(key) dash_spv_platform_identity_manager_opaque_key_to_key_type_index(key)
#define DOpaqueKeyKind(key) dash_spv_crypto_keys_key_OpaqueKey_kind(key)

#define DDataContract dpp_data_contract_DataContract

#define DPurpose dpp_identity_identity_public_key_purpose_Purpose
#define DPurposeDtor(ptr) dpp_identity_identity_public_key_purpose_Purpose_destroy(ptr)
#define DPurposeAuth() dpp_identity_identity_public_key_purpose_Purpose_AUTHENTICATION_ctor()
#define DPurposeIndex(ptr) dash_spv_platform_identity_manager_purpose_to_index(ptr)
#define DPurposeFromIndex(index) dash_spv_platform_identity_manager_purpose_from_index(index)

#define DSecurityLevel dpp_identity_identity_public_key_security_level_SecurityLevel
#define DSecurityLevelDtor(ptr) dpp_identity_identity_public_key_security_level_SecurityLevel_destroy(ptr)
#define DSecurityLevelMaster() dpp_identity_identity_public_key_security_level_SecurityLevel_MASTER_ctor()
#define DSecurityLevelHigh() dpp_identity_identity_public_key_security_level_SecurityLevel_HIGH_ctor()
#define DSecurityLevelIndex(ptr) dash_spv_platform_identity_manager_security_level_to_index(ptr)
#define DSecurityLevelFromIndex(index) dash_spv_platform_identity_manager_security_level_from_index(index)

#define DIdentityRegistrationPublicKey(index, key) dash_spv_platform_identity_manager_identity_registration_public_key(index, key)
#define DCreateIdentityPubKey(index, key, security_level, purpose) dash_spv_platform_identity_manager_identity_public_key(index, key, security_level, purpose)
#define DUsernameStatus dash_spv_platform_document_usernames_UsernameStatus
#define DUsernameStatusDtor(ptr) dash_spv_platform_document_usernames_UsernameStatus_destroy(ptr)
#define DUsernameStatusCallback Fn_ARGS_std_os_raw_c_void_dash_spv_platform_document_usernames_UsernameStatus_RTRN_
#define DUsernameStatusFromIndex(index) dash_spv_platform_document_usernames_username_status_from_index(index)
#define DUsernameStatusIndex(status) dash_spv_platform_document_usernames_username_status_to_index(status)
#define DUsernameAdd(model, username, domain, status) dash_spv_platform_identity_model_IdentityModel_add_username(model, DChar(username), DChar(domain), status);
#define DMaybeIdentityBalance Result_ok_Option_u64_err_dash_spv_platform_error_Error
#define DMaybeIdentityBalanceDtor(ptr) Result_ok_Option_u64_err_dash_spv_platform_error_Error_destroy(ptr)
#define DIdentityKeyStatus dash_spv_platform_identity_model_IdentityKeyStatus
#define DIdentityKeyStatusDtor(ptr) dash_spv_platform_identity_model_IdentityKeyStatus_destroy(ptr)
#define DIdentityRegistrationStatus dash_spv_platform_identity_model_IdentityRegistrationStatus
#define DIdentityRegistrationStatusDtor(ptr) dash_spv_platform_identity_model_IdentityRegistrationStatus_destroy(ptr)
#define DIdentityRegistrationStatusIndex(ptr) dash_spv_platform_identity_model_IdentityModel_registration_status_index(ptr)
#define DIdentityRegistrationStatusFromIndex(index) dash_spv_platform_identity_model_IdentityRegistrationStatus_from_index(index)
#define DIdentityRegistrationStatusRegistered() dash_spv_platform_identity_model_IdentityRegistrationStatus_Registered_ctor()

#define DKeyInfo dash_spv_platform_identity_model_KeyInfo
#define DKeyInfoDtor(ptr) dash_spv_platform_identity_model_KeyInfo_destroy(ptr)
#define DKeyInfoDictionaries std_collections_Map_keys_u32_values_dash_spv_platform_identity_model_KeyInfo
#define DKeyInfoDictionariesDtor(ptr) std_collections_Map_keys_u32_values_dash_spv_platform_identity_model_KeyInfo_destroy(ptr)
#define DKeyInfoAtIndex(model, index) dash_spv_platform_identity_model_IdentityModel_key_info_at_index(model, index)
#define DIdentityModelSetStatus(model, status) dash_spv_platform_identity_model_IdentityModel_set_registration_status(model, status)
#define DGetKeyInfoDictionaries(model) dash_spv_platform_identity_model_IdentityModel_key_info_dictionaries(model)
#define DGetRegisteredKeyInfoDictionaries(model) dash_spv_platform_identity_model_IdentityModel_registered_key_info_dictionaries(model)
#define DIdentityKeyStatusFromIndex(index) dash_spv_platform_identity_model_IdentityKeyStatus_from_index(index)
#define DIdentityKeyStatusToIndex(status) dash_spv_platform_identity_model_IdentityKeyStatus_to_index(status)

#define DIdentityKeyStatusRegistered() dash_spv_platform_identity_model_IdentityKeyStatus_Registered_ctor()

#define DUsernameStatuses std_collections_Map_keys_String_values_dash_spv_platform_identity_model_UsernameStatusInfo
#define DUsernameStatusesDtor(ptr) std_collections_Map_keys_String_values_dash_spv_platform_identity_model_UsernameStatusInfo_destroy(ptr)

#define DBLSSignature dashcore_bls_sig_utils_BLSSignature
#define DBLSSignatureCtor(sig) dashcore_bls_sig_utils_BLSSignature_ctor(sig)

#define DChainLock dashcore_ephemerealdata_chain_lock_ChainLock
#define DChainLockCtor(height, block_hash, sig) dashcore_ephemerealdata_chain_lock_ChainLock_ctor(height, block_hash, sig)
#define DChainLockBlockHeight(ptr) dashcore_ephemerealdata_chain_lock_ChainLock_get_block_height(ptr)
#define DChainLockSignature(ptr) dashcore_ephemerealdata_chain_lock_ChainLock_get_signature(ptr)
#define DChainLockDtor(ptr) dashcore_ephemerealdata_chain_lock_ChainLock_destroy(ptr)
#define DInstantLock dashcore_ephemerealdata_instant_lock_InstantLock
#define DInstantLockCtor(version, inputs, txid, cycle_hash, sig) dashcore_ephemerealdata_instant_lock_InstantLock_ctor(version, inputs, txid, cycle_hash, sig)
#define DInstantLockDtor(ptr) dashcore_ephemerealdata_instant_lock_InstantLock_destroy(ptr)
#define DMaybeInstantLock Result_ok_dashcore_ephemerealdata_instant_lock_InstantLock_err_dash_spv_masternode_processor_processing_processor_processing_error_ProcessingError
#if (defined(DASHCORE_MESSAGE_VERIFICATION))
#define DMessageVerificationResult Result_ok_bool_err_dashcore_sml_message_verification_error_MessageVerificationError
#define DMessageVerificationResultDtor(ptr) Result_ok_bool_err_dashcore_sml_message_verification_error_MessageVerificationError_destroy(ptr)
#endif

#define DScriptBuf dashcore_blockdata_script_owned_ScriptBuf
#define DScriptBufCtor(bytes) dashcore_blockdata_script_owned_ScriptBuf_ctor(bytes)
#define DScriptBufDtor(ptr) dashcore_blockdata_script_owned_ScriptBuf_destroy(ptr)

#define DTxIn dashcore_blockdata_transaction_txin_TxIn
#define DTxInCtor(prev_output, script_sig, sequence) dashcore_blockdata_transaction_txin_TxIn_ctor(prev_output, script_sig, sequence, dashcore_blockdata_witness_Witness_ctor(bytes_ctor([NSData data]), 0, 0))
#define DTxInDtor(ptr) dashcore_blockdata_transaction_txin_TxIn_destroy(ptr)
#define DTxInputs Vec_dashcore_blockdata_transaction_txin_TxIn
#define DTxInputsCtor(count, values) Vec_dashcore_blockdata_transaction_txin_TxIn_ctor(count, values)
#define DTxInputsDtor(ptr) Vec_dashcore_blockdata_transaction_txin_TxIn_destroy(ptr)

#define DTxOut dashcore_blockdata_transaction_txout_TxOut
#define DTxOutCtor(amount, script) dashcore_blockdata_transaction_txout_TxOut_ctor(amount, script)
#define DTxOutDtor(ptr) dashcore_blockdata_transaction_txout_TxOut_destroy(ptr)
#define DTxOutputs Vec_dashcore_blockdata_transaction_txout_TxOut
#define DTxOutputsCtor(count, values) Vec_dashcore_blockdata_transaction_txout_TxOut_ctor(count, values)

#define DTxid dashcore_hash_types_Txid
#define DTxidCtor(data) dashcore_hash_types_Txid_ctor(data)
#define DTxidDtor(ptr) dashcore_hash_types_Txid_destroy(ptr)

#define DOutPoint dashcore_blockdata_transaction_outpoint_OutPoint
#define DOutPointCtor(txid, vout) dashcore_blockdata_transaction_outpoint_OutPoint_ctor(txid, vout)
#define DOutPointCtorU(u, i) DOutPointCtor(DTxidCtor(u256_ctor_u(u)), i)
#define DOutPointFromUTXO(utxo) DOutPointCtorU(utxo.hash, (uint32_t) utxo.n)
#define DOutPointFromMessage(msg) dash_spv_masternode_processor_processing_outpoint_from_message(msg)
#define DOutPointDtor(ptr) dashcore_blockdata_transaction_outpoint_OutPoint_destroy(ptr)
#define DOutPoints Vec_dashcore_blockdata_transaction_outpoint_OutPoint
#define DOutPointsCtor(count, values) Vec_dashcore_blockdata_transaction_outpoint_OutPoint_ctor(count, values)

#define DBalance dash_spv_coinjoin_models_balance_Balance
#define DBalanceCtor(myTrusted, myUntrustedPending, myImmature, watchOnlyTrusted, watchOnlyUntrustedPending, watchOnlyImmature, anonymized, denominatedTrusted, denominatedUntrustedPending) dash_spv_coinjoin_models_balance_Balance_ctor(myTrusted, myUntrustedPending, myImmature, watchOnlyTrusted, watchOnlyUntrustedPending, watchOnlyImmature, anonymized, denominatedTrusted, denominatedUntrustedPending)
#define DBalanceDtor(ptr) dash_spv_coinjoin_models_balance_Balance_destroy(ptr)

#define DTransaction dashcore_blockdata_transaction_Transaction
#define DTransactionCtor(version, lock_time, inputs, outputs, special_payload) dashcore_blockdata_transaction_Transaction_ctor(version, lock_time, inputs, outputs, special_payload);
#define DTransactionDtor(ptr) dashcore_blockdata_transaction_Transaction_destroy(ptr)

#define DSocketAddrFrom(ip, port) dash_spv_masternode_processor_processing_socket_addr_v4_ctor(ip, port)
#define DSocketAddrIp(addr) dash_spv_masternode_processor_processing_socket_addr_ip(addr)
#define DSocketAddrPort(addr) dash_spv_masternode_processor_processing_socket_addr_port(addr)

#define DBlockHash dashcore_hash_types_BlockHash
#define DCycleHash dashcore_hash_types_CycleHash

NS_ASSUME_NONNULL_BEGIN

@class DSDerivationPath;

// This is temporary class provides rust FFI for keys and some other things
@interface DSKeyManager : NSObject

- (instancetype)initWithChain:(DSChain *)chain;

+ (BOOL)hasPrivateKey:(DOpaqueKey *)key;
+ (NSString *)secretKeyHexString:(DOpaqueKey *)key;
+ (DMaybeOpaqueKey *_Nullable)keyWithPrivateKeyData:(NSData *)data ofType:(DKeyKind *)keyType;
+ (DMaybeOpaqueKey *_Nullable)keyWithPublicKeyData:(NSData *)data ofType:(DKeyKind *)keyType;
+ (DMaybeOpaqueKey *_Nullable)keyWithExtendedPublicKeyData:(NSData *)data ofType:(DKeyKind *)keyType;
+ (BOOL)keysPublicKeyDataIsEqual:(DOpaqueKey *)key1 key2:(DOpaqueKey *)key2;
+ (NSData *)signMesasageDigest:(DOpaqueKey *)key digest:(UInt256)digest;
+ (BOOL)verifyMessageDigest:(DOpaqueKey *)key digest:(UInt256)digest signature:(NSData *)signature;

+ (DMaybeOpaqueKey *_Nullable)publicKeyAtIndexPath:(DOpaqueKey *)key indexPath:(NSIndexPath *)indexPath;
+ (NSData *_Nullable)publicKeyDataAtIndexPath:(DOpaqueKey *)key indexPath:(NSIndexPath *)indexPath;

+ (NSData *)privateKeyData:(DOpaqueKey *)key;
+ (NSData *)publicKeyData:(DOpaqueKey *)key;
+ (NSData *)extendedPrivateKeyData:(DOpaqueKey *)key;
+ (NSData *)extendedPublicKeyData:(DOpaqueKey *)key;

+ (NSString *)serializedPrivateKey:(DOpaqueKey *)key
                         chainType:(DChainType *)chainType;

+ (NSString *)addressForKey:(DOpaqueKey *)key
               forChainType:(DChainType *)chainType;
+ (NSString *)addressWithPublicKeyData:(NSData *)data
                              forChain:(nonnull DSChain *)chain;
+ (NSString *_Nullable)addressWithScriptPubKey:(NSData *)script
                                      forChain:(nonnull DSChain *)chain;
+ (NSString *_Nullable)addressWithScriptSig:(NSData *)script
                                   forChain:(nonnull DSChain *)chain;
+ (NSString *)addressFromHash160:(UInt160)hash
                        forChain:(nonnull DSChain *)chain;
+ (BOOL)isValidDashAddress:(NSString *)address
                  forChain:(nonnull DSChain *)chain;
+ (NSData *)scriptPubKeyForAddress:(NSString *)address
                          forChain:(nonnull DSChain *)chain;

+ (NSString *_Nullable)ecdsaKeyAddressFromPublicKeyData:(NSData *)data
                                           forChainType:(DChainType *)chainType;
- (NSString *)ecdsaKeyPublicKeyUniqueIDFromDerivedKeyData:(UInt256)secret
                                             forChainType:(DChainType *)chainType;
- (NSString *)keyRecoveredFromCompactSig:(NSData *)signature
                        andMessageDigest:(UInt256)md;
+ (NSData *_Nullable)compactSign:(DSDerivationPath *)derivationPath
                        fromSeed:(NSData *)seed
                     atIndexPath:(NSIndexPath *)indexPath
                          digest:(UInt256)digest;
+ (NSString *)blsPublicKeySerialize:(DOpaqueKey *)key
                             legacy:(BOOL)legacy;
+ (NSString *_Nullable)ecdsaKeyWithBIP38Key:(NSString *)key
                                 passphrase:(NSString *)passphrase
                               forChainType:(DChainType *)chainType;
+ (BOOL)isValidDashBIP38Key:(NSString *)key;

+ (NSString *)NSStringFrom:(char *)c_string;
+ (NSData *)NSDataFrom:(Vec_u8 *)byte_array;
+ (NSString *)localizedKeyType:(DOpaqueKey *)key;

+ (UInt256)x11:(NSData *)data;
+ (UInt256)blake3:(NSData *)data;

+ (NSData *)encryptData:(NSData *)data secretKey:(DOpaqueKey *)secretKey publicKey:(DOpaqueKey *)publicKey;
+ (NSData *)encryptData:(NSData *)data secretKey:(DOpaqueKey *)secretKey publicKey:(DOpaqueKey *)publicKey usingIV:(NSData *)iv;
+ (NSData *)decryptData:(NSData *)data secretKey:(DOpaqueKey *)secretKey publicKey:(DOpaqueKey *)publicKey;
+ (NSData *)decryptData:(NSData *)data secretKey:(DOpaqueKey *)secretKey publicKey:(DOpaqueKey *)publicKey usingIVSize:(NSUInteger)ivSize;

+ (NSData *)encryptData:(NSData *)data withDHKey:(DOpaqueKey *)dhKey;
+ (NSData *)decryptData:(NSData *)data withDHKey:(DOpaqueKey *)dhKey;

/// Transactions
+ (BOOL)verifyProRegTXPayloadSignature:(NSData *)signature payload:(NSData *)payload ownerKeyHash:(UInt160)ownerKeyHash;

+ (NSString *_Nullable)devnetIdentifierFor:(DChainType *)chainType;

@end

NS_ASSUME_NONNULL_END
