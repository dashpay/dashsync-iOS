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

#define u128 Arr_u8_16
#define u160 Arr_u8_20
#define u256 Arr_u8_32
#define u264 Arr_u8_33
#define u384 Arr_u8_48
#define u512 Arr_u8_64
#define u768 Arr_u8_96

#define SLICE Slice_u8
#define BYTES Vec_u8
#define BITSET dash_spv_crypto_llmq_bitset_Bitset

#define u128_ctor(data) Arr_u8_16_ctor(data.length, (uint8_t *) data.bytes)
#define u160_ctor(data) Arr_u8_20_ctor(data.length, (uint8_t *) data.bytes)
#define u256_ctor(data) Arr_u8_32_ctor(data.length, (uint8_t *) data.bytes)
#define u264_ctor(data) Arr_u8_33_ctor(data.length, (uint8_t *) data.bytes)
#define u384_ctor(data) Arr_u8_48_ctor(data.length, (uint8_t *) data.bytes)
#define u512_ctor(data) Arr_u8_64_ctor(data.length, (uint8_t *) data.bytes)
#define u768_ctor(data) Arr_u8_96_ctor(data.length, (uint8_t *) data.bytes)

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


#define u128_ctor_u(u) (^{ \
    uint8_t *hash = malloc(16 * sizeof(uint8_t)); \
    memcpy(hash, u.u8, 16); \
    return Arr_u8_16_ctor(16, hash); \
}())

#define u160_ctor_u(u) (^{ \
    uint8_t *ffi = malloc(20 * sizeof(uint8_t)); \
    memcpy(ffi, u.u8, 20); \
    return Arr_u8_20_ctor(20, ffi); \
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

#define slice_ctor(data) Slice_u8_ctor(data.length, (uint8_t *) data.bytes)
#define slice_u128_ctor_u(u) Slice_u8_ctor(16, u.u8)
#define slice_u160_ctor_u(u) Slice_u8_ctor(20, u.u8)
#define slice_u256_ctor_u(u) Slice_u8_ctor(32, u.u8)
#define slice_u384_ctor_u(u) Slice_u8_ctor(48, u.u8)
#define slice_u512_ctor_u(u) Slice_u8_ctor(64, u.u8)
#define slice_u768_ctor_u(u) Slice_u8_ctor(96, u.u8)

#define slice_dtor(ptr) Slice_u8_destroy(ptr)

#define bytes_ctor(data) Vec_u8_ctor(data.length, (uint8_t *)data.bytes)
#define bytes_dtor(ptr) Vec_u8_destroy(ptr)

#define bitset_ctor(data, count) dash_spv_crypto_llmq_bitset_Bitset_ctor(data.length, (uint8_t *)data.bytes)
#define bitset_dtor(ptr) dash_spv_crypto_llmq_bitset_Bitset_destroy(ptr)

#define DChar(str) (char *) [str UTF8String]


#define DMNSyncState dash_spv_masternode_processor_models_sync_state_CacheState
#define DMNSyncStateDtor(ptr) dash_spv_masternode_processor_models_sync_state_CacheState_destroy(ptr)
#define DMNSyncStateQueueChanged dash_spv_masternode_processor_models_sync_state_CacheState_QueueChanged
#define DMNSyncStateStoreChanged dash_spv_masternode_processor_models_sync_state_CacheState_StoreChanged
#define DMNSyncStateStubCount dash_spv_masternode_processor_models_sync_state_CacheState_StubCount

#define MaybePubKey Result_ok_u8_arr_48_err_drive_proof_verifier_error_ContextProviderError
#define MaybePubKeyDtor Result_ok_u8_arr_48_err_drive_proof_verifier_error_ContextProviderError_destroy
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

#define DMasternodeList dash_spv_masternode_processor_models_masternode_list_MasternodeList
#define DMasternodeListDtor(ptr) dash_spv_masternode_processor_models_masternode_list_MasternodeList_destroy(ptr)
//#define DArcMasternodeList std_sync_Arc_dash_spv_masternode_processor_models_masternode_list_MasternodeList
//#define DArcMasternodeListDtor(ptr) std_sync_Arc_dash_spv_masternode_processor_models_masternode_list_MasternodeList_destroy(ptr)
#define DMaybeMasternodeList Result_ok_dash_spv_masternode_processor_models_masternode_list_MasternodeList_err_dash_spv_masternode_processor_processing_core_provider_CoreProviderError

#define DMasternodeListFromEntryPool(block_hash, block_height, mn_merkle_root, llmq_merkle_root, masternodes_vec, quorums_vec) dash_spv_masternode_processor_models_masternode_list_from_entry_pool(block_hash, block_height, mn_merkle_root, llmq_merkle_root, masternodes_vec, quorums_vec)
#define DMasternodeEntry dash_spv_masternode_processor_models_masternode_entry_MasternodeEntry
#define DMasternodeEntryDtor(ptr) dash_spv_masternode_processor_models_masternode_entry_MasternodeEntry_destroy(ptr)
#define DMasternodeEntryList Vec_dash_spv_masternode_processor_models_masternode_entry_MasternodeEntry
#define DMasternodeEntryListCtor(count, list) Vec_dash_spv_masternode_processor_models_masternode_entry_MasternodeEntry_ctor(count, list)
#define DMasternodeEntryListDtor(ptr) Vec_dash_spv_masternode_processor_models_masternode_entry_MasternodeEntry_destroy(ptr)
#define DMasternodeEntryMap std_collections_Map_keys_u8_arr_32_values_dash_spv_masternode_processor_models_masternode_entry_MasternodeEntry
#define DMasternodeEntryMapDtor(ptr) std_collections_Map_keys_u8_arr_32_values_dash_spv_masternode_processor_models_masternode_entry_MasternodeEntry_destroy(ptr)
#define DLLMQMap std_collections_Map_keys_dash_spv_crypto_network_llmq_type_LLMQType_values_std_collections_Map_keys_u8_arr_32_values_dash_spv_crypto_llmq_entry_LLMQEntry
#define DLLMQMapOfType std_collections_Map_keys_u8_arr_32_values_dash_spv_crypto_llmq_entry_LLMQEntry
#define DLLMQEntry dash_spv_crypto_llmq_entry_LLMQEntry
#define DLLMQEntryDtor(ptr) dash_spv_crypto_llmq_entry_LLMQEntry_destroy(ptr)
#define DLLMQEntrySignID(ptr, req_id, hash) dash_spv_crypto_llmq_entry_LLMQEntry_sign_id(ptr, req_id, hash)
#define DLLMQEntryVerifySignature(ptr, sign_id, sig) dash_spv_crypto_llmq_entry_LLMQEntry_verify_signature(ptr, sign_id, sig)
#define DLLMQEntryHashHex(ptr) dash_spv_crypto_llmq_entry_LLMQEntry_llmq_hash_hex(ptr)

#define DLLMQEntryList Vec_dash_spv_crypto_llmq_entry_LLMQEntry
#define DLLMQEntryListCtor(count, list) Vec_dash_spv_crypto_llmq_entry_LLMQEntry_ctor(count, list)

#define DLLMQType dash_spv_crypto_network_llmq_type_LLMQType
#define DLLMQSnapshot dash_spv_masternode_processor_models_snapshot_LLMQSnapshot
#define DKeyKind dash_spv_crypto_keys_key_KeyKind
#define DKeyKindDtor(ptr) dash_spv_crypto_keys_key_KeyKind_destroy(ptr)
#define DKeyKindECDSA() dash_spv_crypto_keys_key_KeyKind_ECDSA_ctor()
#define DKeyKindBLS() dash_spv_crypto_keys_key_KeyKind_BLS_ctor()
#define DKeyKindED25519() dash_spv_crypto_keys_key_KeyKind_ED25519_ctor()

#define DOpaqueKey dash_spv_crypto_keys_key_OpaqueKey
#define DOpaqueKeyDtor(ptr) dash_spv_crypto_keys_key_OpaqueKey_destroy(ptr)
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

#define DQRInfoResult Result_Tuple_Arr_u8_32_Arr_u8_32_err_dash_spv_masternode_processor_processing_processing_error_ProcessingError
#define DQRInfoResultDtor(ptr) Result_Tuple_Arr_u8_32_Arr_u8_32_err_dash_spv_masternode_processor_processing_processing_error_ProcessingError_destroy(ptr)

#define DMnDiffFromFile(processor, message, protocol_version) dash_spv_masternode_processor_processing_processor_MasternodeProcessor_mn_list_diff_result_from_file(processor, message, protocol_version)
#define DMnDiffFromMessage(processor, message, is_from_snapshot, protocol_version, allow_invalid_merkle_roots, peer) dash_spv_masternode_processor_processing_processor_MasternodeProcessor_mn_list_diff_result_from_message(processor, message, is_from_snapshot, protocol_version, allow_invalid_merkle_roots, peer)

#define DMnDiffResult Result_Tuple_Arr_u8_32_Arr_u8_32_bool_err_dash_spv_masternode_processor_processing_processing_error_ProcessingError
#define DMnDiffResultDtor(ptr) Result_Tuple_Arr_u8_32_Arr_u8_32_bool_err_dash_spv_masternode_processor_processing_processing_error_ProcessingError_destroy(ptr)

#define DMasternodeListForBlockHash(processor, block_hash) dash_spv_masternode_processor_processing_processor_MasternodeProcessor_masternode_list_for_block_hash(processor, block_hash)
#define DCalcMnMerkleRoot(list, block_height) dash_spv_masternode_processor_models_masternode_list_MasternodeList_calculate_masternodes_merkle_root(list, block_height)
#define DCalcLLMQMerkleRoot(list) dash_spv_masternode_processor_models_masternode_list_MasternodeList_calculate_llmq_merkle_root(list)
#define DCalcMnMerkleRootWithBlockHeightLookup(list, context, lookup) dash_spv_masternode_processor_models_masternode_list_MasternodeList_calculate_masternodes_merkle_root_with_block_height_lookup(list, context, lookup)

#define DMasternodeListByBlockHash(cache, block_hash) dash_spv_masternode_processor_processing_processor_cache_MasternodeProcessorCache_masternode_list_by_block_hash(cache, block_hash)

#define DMasternodeListReversedProRegTxHashes(list) dash_spv_masternode_processor_models_masternode_list_MasternodeList_reversed_pro_reg_tx_hashes_cloned(list)

#define DMnDiffQueueCount(cache) dash_spv_masternode_processor_processing_processor_cache_MasternodeProcessorCache_mn_list_retrieval_queue_count(cache)
#define DMnDiffQueueMaxAmount(cache) dash_spv_masternode_processor_processing_processor_cache_MasternodeProcessorCache_mn_list_retrieval_queue_get_max_amount(cache)
#define DMnDiffQueueRemove(proc, block_hash) dash_spv_masternode_processor_processing_processor_MasternodeProcessor_remove_from_mn_list_retrieval_queue(proc, block_hash)
#define DMnDiffQueueClean(proc) dash_spv_masternode_processor_processing_processor_MasternodeProcessor_clean_mn_list_retrieval_queue(proc)

#define DQrInfoQueueCount(cache) dash_spv_masternode_processor_processing_processor_cache_MasternodeProcessorCache_qr_info_retrieval_queue_count(cache)
#define DQrInfoQueueMaxAmount(cache) dash_spv_masternode_processor_processing_processor_cache_MasternodeProcessorCache_qr_info_retrieval_queue_get_max_amount(cache)
#define DQrInfoQueueRemove(proc, block_hash) dash_spv_masternode_processor_processing_processor_MasternodeProcessor_remove_from_qr_info_retrieval_queue(proc, block_hash)
#define DQrInfoQueueClean(proc) dash_spv_masternode_processor_processing_processor_MasternodeProcessor_clean_qr_info_retrieval_queue(proc)

#define DMasternodeListHashesForMerkleRootWithBlockHeightLookup(list, context, lookup) dash_spv_masternode_processor_models_masternode_list_MasternodeList_hashes_for_merkle_root_with_block_height_lookup(list, context, lookup)
#define DMasternodeEntryByProRegTxHash(list, hash) dash_spv_masternode_processor_models_masternode_list_MasternodeList_masternode_by_pro_reg_tx_hash(list, hash)
#define DMasternodeEntryFromEntity(version, provider_registration_transaction_hash, confirmed_hash, ip_address, port, key_id_voting, operator_public_key_data, operator_public_key_version, is_valid, mn_type, platform_http_port, platform_node_id, update_height, confirmed_hash_hashed_with_provider_registration_transaction_hash, known_confirmed_at_height, entry_hash, previous_entry_hashes, previous_operator_public_keys, previous_validity) dash_spv_masternode_processor_models_masternode_entry_from_entity(version, provider_registration_transaction_hash, confirmed_hash, ip_address, port, key_id_voting, operator_public_key_data, operator_public_key_version, is_valid, mn_type, platform_http_port, platform_node_id, update_height, confirmed_hash_hashed_with_provider_registration_transaction_hash, known_confirmed_at_height, entry_hash, previous_entry_hashes, previous_operator_public_keys, previous_validity)

#define DMasternodeListPrint(list) dash_spv_masternode_processor_models_masternode_list_MasternodeList_print_description(list)
#define DMasternodeEntryPrint(entry) dash_spv_masternode_processor_models_masternode_entry_MasternodeEntry_print_description(entry)
#define DLLMQEntryPrint(entry) dash_spv_crypto_llmq_entry_LLMQEntry_print_description(entry)


#define DMNListDiffResult dash_spv_masternode_processor_processing_mn_listdiff_result_MNListDiffResult

#define NSDataFromPtr(ptr) ptr ? [NSData dataWithBytes:(const void *)ptr->values length:ptr->count] : nil
#define NSStringFromPtr(ptr) ptr ? [NSString stringWithCString:ptr encoding:NSUTF8StringEncoding] : nil

#define DPreviousOperatorKeys std_collections_Map_keys_dash_spv_masternode_processor_common_block_Block_values_dash_spv_crypto_keys_operator_public_key_OperatorPublicKey
#define DPreviousEntryHashes std_collections_Map_keys_dash_spv_masternode_processor_common_block_Block_values_u8_arr_32
#define DPreviousValidity std_collections_Map_keys_dash_spv_masternode_processor_common_block_Block_values_bool

#define DStoredMasternodeListsCount(proc) dash_spv_masternode_processor_processing_processor_cache_MasternodeProcessorCache_stored_masternode_lists_count(proc)
#define DKnownMasternodeListsCount(cache) dash_spv_masternode_processor_processing_processor_cache_MasternodeProcessorCache_known_masternode_lists_count(cache)
#define DLastMasternodeListBlockHeight(proc) dash_spv_masternode_processor_processing_processor_MasternodeProcessor_last_masternode_list_block_height(proc)
#define DHeightForBlockHash(proc, hash) dash_spv_masternode_processor_processing_processor_MasternodeProcessor_height_for_block_hash(proc, hash)

#define DMasternodeEntryVotingAddress(entry, chain_type) dash_spv_masternode_processor_models_masternode_entry_MasternodeEntry_voting_address(entry, chain_type)
#define DMasternodeEntryOperatorPublicKeyAddress(entry, chain_type) dash_spv_masternode_processor_models_masternode_entry_MasternodeEntry_operator_public_key_address(entry, chain_type)
#define DMasternodeEntryEvoNodeAddress(entry, chain_type) dash_spv_masternode_processor_models_masternode_entry_MasternodeEntry_evo_node_address(entry, chain_type)
#define DAddMasternodeList(cache, hash, list) dash_spv_masternode_processor_processing_processor_cache_MasternodeProcessorCache_add_masternode_list(cache, hash, list)
#define DRemoveMasternodeList(cache, hash) dash_spv_masternode_processor_processing_processor_cache_MasternodeProcessorCache_remove_masternode_list(cache, hash)
#define DRemoveMasternodeListsBefore(cache, height) dash_spv_masternode_processor_processing_processor_cache_MasternodeProcessorCache_remove_masternode_lists_before_height(cache, height)
#define DMasternodeListLoaded(cache, hash, list) dash_spv_masternode_processor_processing_processor_cache_MasternodeProcessorCache_masternode_list_loaded(cache, hash, list)
#define DCacheBlockHeight(cache, hash, height) dash_spv_masternode_processor_processing_processor_cache_MasternodeProcessorCache_cache_block_height_for_hash(cache, hash, height)
#define DAddMasternodeListStub(cache, hash) dash_spv_masternode_processor_processing_processor_cache_MasternodeProcessorCache_add_stub_for_masternode_list(cache, hash)
//#define DProcessingErrorIndex(ptr) dash_spv_masternode_processor_processing_processing_error_ProcessingError_index(ptr)

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

#define DCreateIdentityPubKey(index, key, security_level, purpose) dash_spv_platform_identity_manager_identity_public_key(index, key, security_level, purpose)
#define DUsernameStatus dash_spv_platform_document_usernames_UsernameStatus
#define DUsernameStatusDtor(ptr) dash_spv_platform_document_usernames_UsernameStatus_destroy(ptr)
#define DUsernameStatusCallback Fn_ARGS_std_os_raw_c_void_dash_spv_platform_document_usernames_UsernameStatus_RTRN_

#define DIdentityKeyStatus dash_spv_platform_identity_model_IdentityKeyStatus
#define DIdentityRegistrationStatus dash_spv_platform_identity_model_IdentityRegistrationStatus

NS_ASSUME_NONNULL_BEGIN

@class DSDerivationPath;

// This is temporary class provides rust FFI for keys and some other things
@interface DSKeyManager : NSObject

- (instancetype)initWithChain:(DSChain *)chain;
//+ (DKeyKind *)keyKindFromIndex:(uint16_t)index;

+ (BOOL)hasPrivateKey:(DOpaqueKey *)key;
+ (NSString *)secretKeyHexString:(DOpaqueKey *)key;
+ (DMaybeOpaqueKey *_Nullable)keyWithPrivateKeyString:(NSString *)key
                                            ofKeyType:(DKeyKind *)keyType
                                         forChainType:(DChainType *)chainType;
+ (DMaybeOpaqueKey *_Nullable)keyWithPrivateKeyData:(NSData *)data ofType:(DKeyKind *)keyType;
+ (DMaybeOpaqueKey *_Nullable)keyWithPublicKeyData:(NSData *)data ofType:(DKeyKind *)keyType;
+ (DMaybeOpaqueKey *_Nullable)keyWithExtendedPublicKeyData:(NSData *)data ofType:(DKeyKind *)keyType;
+ (BOOL)keysPublicKeyDataIsEqual:(DOpaqueKey *)key1 key2:(DOpaqueKey *)key2;
+ (NSData *)signMesasageDigest:(DOpaqueKey *)key digest:(UInt256)digest;
+ (BOOL)verifyMessageDigest:(DOpaqueKey *)key digest:(UInt256)digest signature:(NSData *)signature;

//+ (DMaybeOpaqueKey *_Nullable)privateKeyAtIndexPath:(DKeyKind *)keyType
//                                               path:(DIndexPathU256 *)path
//                                         index_path:(Vec_u32 *)index_path
//                                               seed:(NSData *)seed;
//+ (DMaybeOpaqueKey *_Nullable)privateKeyAtIndexPath:(DKeyKind *)keyType
//                                       indexes:(UInt256 *)indexes
//                                      hardened:(BOOL *)hardened
//                                        length:(NSUInteger)length
//                                     indexPath:(NSIndexPath *)indexPath
//                                      fromSeed:(NSData *)seed;
+ (DMaybeOpaqueKey *_Nullable)publicKeyAtIndexPath:(DOpaqueKey *)key indexPath:(NSIndexPath *)indexPath;
+ (NSData *_Nullable)publicKeyDataAtIndexPath:(DOpaqueKey *)key indexPath:(NSIndexPath *)indexPath;

+ (NSData *)privateKeyData:(DOpaqueKey *)key;
+ (NSData *)publicKeyData:(DOpaqueKey *)key;
+ (NSData *)extendedPrivateKeyData:(DOpaqueKey *)key;
+ (NSData *)extendedPublicKeyData:(DOpaqueKey *)key;

+ (DMaybeOpaqueKey *_Nullable)deriveKeyFromExtenedPrivateKeyDataAtIndexPath:(NSData *_Nullable)data
                                                             indexPath:(NSIndexPath *)indexPath
                                                            forKeyType:(DKeyKind *)keyType;
//+ (DMaybeOpaqueKey *_Nullable)keyPublicDeriveTo256Bit:(DSDerivationPath *)parentPath
//                                    childIndexes:(UInt256 *)childIndexes
//                                   childHardened:(BOOL *)childHardened
//                                          length:(NSUInteger)length;

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

//+ (UInt160)ecdsaKeyPublicKeyHashFromSecret:(NSString *)secret forChainType:(DChainType *)chainType;

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
//+ (struct ECDSAKey *)ecdsaKeyWithPrivateKey:(NSString *)key forChainType:(DChainType *)chainType;
+ (NSString *)blsPublicKeySerialize:(DOpaqueKey *)key
                             legacy:(BOOL)legacy;
+ (NSString *_Nullable)ecdsaKeyWithBIP38Key:(NSString *)key
                                 passphrase:(NSString *)passphrase
                               forChainType:(DChainType *)chainType;
+ (BOOL)isValidDashBIP38Key:(NSString *)key;
//+ (DOpaqueKey *_Nullable)keyDeprecatedExtendedPublicKeyFromSeed:(NSData *)seed
//                                                        indexes:(UInt256 *)indexes
//                                                       hardened:(BOOL *)hardened
//                                                         length:(NSUInteger)length;

+ (NSString *)NSStringFrom:(char *)c_string;
+ (NSData *)NSDataFrom:(BYTES *)byte_array;
+ (NSData *)NSDataFromArr_u8_32:(u256 *)byte_array;
+ (NSString *)localizedKeyType:(DOpaqueKey *)key;

+ (UInt256)x11:(NSData *)data;
+ (UInt256)blake3:(NSData *)data;

+ (NSData *)encryptData:(NSData *)data secretKey:(DOpaqueKey *)secretKey publicKey:(DOpaqueKey *)publicKey;
+ (NSData *)encryptData:(NSData *)data secretKey:(DOpaqueKey *)secretKey publicKey:(DOpaqueKey *)publicKey usingIV:(NSData *)iv;
+ (NSData *)decryptData:(NSData *)data secretKey:(DOpaqueKey *)secretKey publicKey:(DOpaqueKey *)publicKey;
+ (NSData *)decryptData:(NSData *)data secretKey:(DOpaqueKey *)secretKey publicKey:(DOpaqueKey *)publicKey usingIVSize:(NSUInteger)ivSize;

+ (NSData *)encryptData:(NSData *)data withDHKey:(DOpaqueKey *)dhKey;
+ (NSData *)decryptData:(NSData *)data withDHKey:(DOpaqueKey *)dhKey;

//+ (NSString *)keyStoragePrefix:(DKeyKind *)keyType;

/// Transactions
+ (BOOL)verifyProRegTXPayloadSignature:(NSData *)signature payload:(NSData *)payload ownerKeyHash:(UInt160)ownerKeyHash;

+ (NSString *_Nullable)devnetIdentifierFor:(DChainType *)chainType;

@end

NS_ASSUME_NONNULL_END
