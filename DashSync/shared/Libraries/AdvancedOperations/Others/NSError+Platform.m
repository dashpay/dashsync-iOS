//  
//  Created by Vladimir Pirogov
//  Copyright © 2025 Dash Core Group. All rights reserved.
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

#import "NSData+Dash.h"
#import "NSError+Dash.h"
#import "NSError+Platform.h"

@implementation NSError (dash_spv_platform_error_Error)

+ (nonnull NSError *)ffi_from_platform_error:(nonnull dash_spv_platform_error_Error *)ffi_ref {
    switch (ffi_ref->tag) {
        case dash_spv_platform_error_Error_KeyError:
            return [NSError ffi_from_key_error:ffi_ref->key_error];
        case dash_spv_platform_error_Error_DashSDKError:
            return [NSError errorWithCode:0 localizedDescriptionKey:NSStringFromPtr(ffi_ref->dash_sdk_error)];
        case dash_spv_platform_error_Error_Any:
            return [NSError errorWithCode:ffi_ref->any._0 localizedDescriptionKey:NSStringFromPtr(ffi_ref->any._1)];
        case dash_spv_platform_error_Error_MaxRetryExceeded:
        case dash_spv_platform_error_Error_InstantSendSignatureVerificationError:
            return [NSError errorWithCode:0 localizedDescriptionKey:NSStringFromPtr(ffi_ref->instant_send_signature_verification_error)];
    }
}

@end


@implementation NSError (dash_spv_crypto_keys_KeyError)

+ (nonnull NSError *)ffi_from_key_error:(nonnull dash_spv_crypto_keys_KeyError *)ffi_ref {
    switch (ffi_ref->tag) {
        case dash_spv_crypto_keys_KeyError_WrongFormat:
            return [NSError errorWithCode:0 localizedDescriptionKey:@"Wrong key format"];
        case dash_spv_crypto_keys_KeyError_WrongLength:
            return [NSError errorWithCode:0 descriptionKey:DSLocalizedFormat(@"Wrong key length", nil, ffi_ref->wrong_length)];
        case dash_spv_crypto_keys_KeyError_Extended:
            return [NSError errorWithCode:0 descriptionKey:DSLocalizedFormat(@"Key extended error", nil, ffi_ref->extended)];
        case dash_spv_crypto_keys_KeyError_UnableToDerive:
            return [NSError errorWithCode:0 localizedDescriptionKey:@"Unable to derive key"];
        case dash_spv_crypto_keys_KeyError_DHKeyExchange:
            return [NSError errorWithCode:0 localizedDescriptionKey:@"Unable to exchange key"];
        case dash_spv_crypto_keys_KeyError_CCCrypt:
            return [NSError errorWithCode:0 descriptionKey:DSLocalizedFormat(@"CCrypt error", nil, ffi_ref->cc_crypt)];
        case dash_spv_crypto_keys_KeyError_EmptySecKey:
            return [NSError errorWithCode:0 localizedDescriptionKey:@"Private key is empty"];
        case dash_spv_crypto_keys_KeyError_Product:
            return [NSError errorWithCode:0 localizedDescriptionKey:@"Can't multiple keys"];
        case dash_spv_crypto_keys_KeyError_Any:
            return [NSError errorWithCode:0 localizedDescriptionKey:NSStringFromPtr(ffi_ref->any)];
    }
}

@end

@implementation NSError (dashcore_sml_quorum_validation_error_ClientDataRetrievalError)

+ (nonnull NSError *)ffi_from_client_data_retrieval_error:(nonnull dashcore_sml_quorum_validation_error_ClientDataRetrievalError *)ffi_ref {
    switch (ffi_ref->tag) {
        case dashcore_sml_quorum_validation_error_ClientDataRetrievalError_RequiredBlockNotPresent: {
            u256 *block_hash = dashcore_hash_types_BlockHash_inner(ffi_ref->required_block_not_present);
            NSString *blockHashString = u256_hex(block_hash);
            NSString *blockHashRevString = u256_reversed_hex(block_hash);
            u256_dtor(block_hash);
            return [NSError errorWithCode:0 descriptionKey:DSLocalizedFormat(@"Required Block Not Present %@ (%@)", nil, blockHashString, blockHashRevString)];
        }
        case dashcore_sml_quorum_validation_error_ClientDataRetrievalError_CoinbaseNotFoundOnBlock: {
            u256 *block_hash = dashcore_hash_types_BlockHash_inner(ffi_ref->coinbase_not_found_on_block);
            NSString *blockHashString = u256_hex(block_hash);
            NSString *blockHashRevString = u256_reversed_hex(block_hash);
            u256_dtor(block_hash);
            return [NSError errorWithCode:0 descriptionKey:DSLocalizedFormat(@"Coinbase Not Found On Block %@ (%@)", nil, blockHashString, blockHashRevString)];
        }
    }
}

@end

@implementation NSError (dashcore_sml_quorum_validation_error_QuorumValidationError)
+ (NSError *)ffi_from_quorum_validation_error:(dashcore_sml_quorum_validation_error_QuorumValidationError *)ffi_ref {
    switch (ffi_ref->tag) {
        case dashcore_sml_quorum_validation_error_QuorumValidationError_RequiredBlockNotPresent: {
            u256 *block_hash = dashcore_hash_types_BlockHash_inner(ffi_ref->required_block_not_present);
            NSString *blockHashString = u256_hex(block_hash);
            NSString *blockHashRevString = u256_reversed_hex(block_hash);
//            u256_dtor(block_hash);
            return [NSError errorWithCode:0 localizedDescriptionKey:DSLocalizedFormat(@"Required block %@ (%@) not present", nil, blockHashString, blockHashRevString)];
        }
        case dashcore_sml_quorum_validation_error_QuorumValidationError_RequiredBlockHeightNotPresent:
            return [NSError errorWithCode:0 localizedDescriptionKey:DSLocalizedFormat(@"Required block height (%u) not present", nil, ffi_ref->required_block_height_not_present->_0)];
        case dashcore_sml_quorum_validation_error_QuorumValidationError_VerifyingMasternodeListNotPresent:
            return [NSError errorWithCode:0 localizedDescriptionKey:DSLocalizedFormat(@"Verifying MasternodeList (%u) not present", nil, ffi_ref->verifying_masternode_list_not_present->_0)];
        case dashcore_sml_quorum_validation_error_QuorumValidationError_RequiredMasternodeListNotPresent:
            return [NSError errorWithCode:0 localizedDescriptionKey:DSLocalizedFormat(@"Required MasternodeList (%u) not present", nil, ffi_ref->required_masternode_list_not_present->_0)];
        case dashcore_sml_quorum_validation_error_QuorumValidationError_RequiredChainLockNotPresent: {
            u256 *block_hash = dashcore_hash_types_BlockHash_inner(ffi_ref->required_chain_lock_not_present._1);
            NSString *blockHashString = u256_hex(block_hash);
            NSString *blockHashRevString = u256_reversed_hex(block_hash);
//            u256_dtor(block_hash);
            return [NSError errorWithCode:0 localizedDescriptionKey:DSLocalizedFormat(@"Required ChainLock %u: %@ (%@) not present", nil, ffi_ref->required_chain_lock_not_present._0->_0, blockHashString, blockHashRevString)];
        }
        case dashcore_sml_quorum_validation_error_QuorumValidationError_InsufficientSigners:
            return [NSError errorWithCode:0 localizedDescriptionKey:DSLocalizedFormat(@"Insufficient Signers (%llu/%llu)", nil, ffi_ref->insufficient_signers.found, ffi_ref->insufficient_signers.required)];
        case dashcore_sml_quorum_validation_error_QuorumValidationError_InsufficientValidMembers:
            return [NSError errorWithCode:0 localizedDescriptionKey:DSLocalizedFormat(@"Insufficient Valid Members (%llu/%llu)", nil, ffi_ref->insufficient_valid_members.found, ffi_ref->insufficient_valid_members.required)];
        case dashcore_sml_quorum_validation_error_QuorumValidationError_MismatchedBitsetLengths:
            return [NSError errorWithCode:0 localizedDescriptionKey:DSLocalizedFormat(@"Mismatched Bitset Lengths (%lu/%lu)", nil, ffi_ref->mismatched_bitset_lengths.signers_len, ffi_ref->mismatched_bitset_lengths.valid_members_len)];
        case dashcore_sml_quorum_validation_error_QuorumValidationError_InvalidQuorumPublicKey:
            return [NSError errorWithCode:0 localizedDescriptionKey:DSLocalizedFormat(@"Invalid Quorum PublicKey", nil)];
        case dashcore_sml_quorum_validation_error_QuorumValidationError_InvalidBLSPublicKey:
            return [NSError errorWithCode:0 localizedDescriptionKey:DSLocalizedFormat(@"Invalid BLS PublicKey (%@)", nil, NSStringFromPtr(ffi_ref->invalid_bls_public_key))];
        case dashcore_sml_quorum_validation_error_QuorumValidationError_InvalidBLSSignature:
            return [NSError errorWithCode:0 localizedDescriptionKey:DSLocalizedFormat(@"Invalid BLS Signature (%@)", nil, NSStringFromPtr(ffi_ref->invalid_bls_signature))];
        case dashcore_sml_quorum_validation_error_QuorumValidationError_InvalidQuorumSignature:
            return [NSError errorWithCode:0 localizedDescriptionKey:DSLocalizedFormat(@"Invalid Quorum Signature", nil)];
        case dashcore_sml_quorum_validation_error_QuorumValidationError_InvalidFinalSignature:
            return [NSError errorWithCode:0 localizedDescriptionKey:DSLocalizedFormat(@"Invalid Final Signature", nil)];
        case dashcore_sml_quorum_validation_error_QuorumValidationError_AllCommitmentAggregatedSignatureNotValid:
            return [NSError errorWithCode:0 localizedDescriptionKey:DSLocalizedFormat(@"All Commitment Aggregated Signature Not Valid (%@)", nil, NSStringFromPtr(ffi_ref->all_commitment_aggregated_signature_not_valid))];
        case dashcore_sml_quorum_validation_error_QuorumValidationError_ThresholdSignatureNotValid:
            return [NSError errorWithCode:0 localizedDescriptionKey:DSLocalizedFormat(@"Threshold Signature Not Valid (%@)", nil, NSStringFromPtr(ffi_ref->threshold_signature_not_valid))];
        case dashcore_sml_quorum_validation_error_QuorumValidationError_CommitmentHashNotPresent:
            return [NSError errorWithCode:0 localizedDescriptionKey:DSLocalizedFormat(@"Commitment Hash not present", nil)];
        case dashcore_sml_quorum_validation_error_QuorumValidationError_RequiredSnapshotNotPresent: {
            u256 *block_hash = dashcore_hash_types_BlockHash_inner(ffi_ref->required_snapshot_not_present);
            NSString *blockHashString = u256_hex(block_hash);
//            u256_dtor(block_hash);
            return [NSError errorWithCode:0 localizedDescriptionKey:DSLocalizedFormat(@"Required Snapshot (%@) not present", nil, blockHashString)];
        }
        case dashcore_sml_quorum_validation_error_QuorumValidationError_SMLError:
            return [NSError errorWithCode:0 localizedDescriptionKey:DSLocalizedFormat(@"SML Error", nil)];
        case dashcore_sml_quorum_validation_error_QuorumValidationError_RequiredQuorumIndexNotPresent: {
            u256 *quorum_hash = dashcore_hash_types_QuorumHash_inner(ffi_ref->required_quorum_index_not_present);
            NSString *quorumHashString = u256_hex(quorum_hash);
//            u256_dtor(quorum_hash);
            return [NSError errorWithCode:0 localizedDescriptionKey:DSLocalizedFormat(@"Required Quorum Index (%@) not present", nil, quorumHashString)];
        }
        case dashcore_sml_quorum_validation_error_QuorumValidationError_CorruptedCodeExecution:
            return [NSError errorWithCode:0 localizedDescriptionKey:DSLocalizedFormat(@"Corruped Code Execution (%@)", nil, NSStringFromPtr(ffi_ref->all_commitment_aggregated_signature_not_valid))];
        case dashcore_sml_quorum_validation_error_QuorumValidationError_ExpectedOnlyRotatedQuorums: {
            u256 *quorum_hash = dashcore_hash_types_QuorumHash_inner(ffi_ref->expected_only_rotated_quorums._0);
            NSString *quorumHashString = u256_hex(quorum_hash);
//            u256_dtor(quorum_hash);
            return [NSError errorWithCode:0 localizedDescriptionKey:DSLocalizedFormat(@"Expected Only Rotated Quorums (%u: %@)", nil, dashcore_sml_llmq_type_LLMQType_index(ffi_ref->expected_only_rotated_quorums._1), quorumHashString)];
        }
        case dashcore_sml_quorum_validation_error_QuorumValidationError_ClientDataRetrievalError:
            return [NSError ffi_from_client_data_retrieval_error:ffi_ref->client_data_retrieval_error];
        case dashcore_sml_quorum_validation_error_QuorumValidationError_FeatureNotTurnedOn:
            return [NSError errorWithCode:0 localizedDescriptionKey:DSLocalizedFormat(@"Feature Not Turned On (%@)", nil, NSStringFromPtr(ffi_ref->feature_not_turned_on))];
    }
}
@end

@implementation NSError (dash_spv_masternode_processor_processing_core_provider_CoreProviderError)
+ (NSError *)ffi_from_core_provider_error:(dash_spv_masternode_processor_processing_core_provider_CoreProviderError *)ffi_ref {
    switch (ffi_ref->tag) {
        case dash_spv_masternode_processor_processing_core_provider_CoreProviderError_NullResult:
            return [NSError errorWithCode:0 localizedDescriptionKey:DSLocalizedString(@"Core Provider Null Result", nil)];
        case dash_spv_masternode_processor_processing_core_provider_CoreProviderError_ByteError:
            return [NSError errorWithCode:0 localizedDescriptionKey:DSLocalizedString(@"Message Parse Error", nil)];
        case dash_spv_masternode_processor_processing_core_provider_CoreProviderError_BadBlockHash:
            return [NSError errorWithCode:0 localizedDescriptionKey:DSLocalizedFormat(@"Bad Block Hash (%@)", nil, u256_hex(ffi_ref->bad_block_hash))];
        case dash_spv_masternode_processor_processing_core_provider_CoreProviderError_UnknownBlockHeightForHash:
            return [NSError errorWithCode:0 localizedDescriptionKey:DSLocalizedFormat(@"Unknown height for Hash (%@)", nil, u256_hex(ffi_ref->unknown_block_height_for_hash))];
        case dash_spv_masternode_processor_processing_core_provider_CoreProviderError_BlockHashNotFoundAt:
            return [NSError errorWithCode:0 localizedDescriptionKey:DSLocalizedFormat(@"Block hash for height %u not found", nil, ffi_ref->block_hash_not_found_at)];
        case dash_spv_masternode_processor_processing_core_provider_CoreProviderError_NoSnapshot:
            return [NSError errorWithCode:0 localizedDescriptionKey:DSLocalizedString(@"Quorum Snapshot not found", nil)];
        case dash_spv_masternode_processor_processing_core_provider_CoreProviderError_HexError:
            return [NSError errorWithCode:0 localizedDescriptionKey:DSLocalizedString(@"Parse Hex Error", nil)];
        case dash_spv_masternode_processor_processing_core_provider_CoreProviderError_MissedMasternodeListAt:
            return [NSError errorWithCode:0 localizedDescriptionKey:DSLocalizedFormat(@"Missed Masternode List at (%@)", nil, u256_hex(ffi_ref->missed_masternode_list_at))];
    }
}
@end

@implementation NSError (DProcessingError)
+ (NSError *)ffi_from_processing_error:(DProcessingError *)ffi_ref {
    switch (ffi_ref->tag) {
        case dash_spv_masternode_processor_processing_processor_processing_error_ProcessingError_PersistInRetrieval:
            return [NSError errorWithCode:0 localizedDescriptionKey:DSLocalizedFormat(@"Unexpected Diff Processing (%@..%@)", nil, u256_hex(ffi_ref->persist_in_retrieval._0), u256_hex(ffi_ref->persist_in_retrieval._1))];
        case dash_spv_masternode_processor_processing_processor_processing_error_ProcessingError_LocallyStored:
            return [NSError errorWithCode:0 localizedDescriptionKey:DSLocalizedFormat(@"Masternode List already stored for %u: %@", nil, ffi_ref->locally_stored._0, u256_hex(ffi_ref->locally_stored._1))];
        case dash_spv_masternode_processor_processing_processor_processing_error_ProcessingError_ParseError:
            return [NSError errorWithCode:0 localizedDescriptionKey:DSLocalizedFormat(@"Message Parse Error", nil, NSStringFromPtr(ffi_ref->parse_error))];
        case dash_spv_masternode_processor_processing_processor_processing_error_ProcessingError_HasNoBaseBlockHash:
            return [NSError errorWithCode:0 localizedDescriptionKey:DSLocalizedFormat(@"Unknown base block hash", nil, u256_hex(ffi_ref->has_no_base_block_hash))];
        case dash_spv_masternode_processor_processing_processor_processing_error_ProcessingError_UnknownBlockHash:
            return [NSError errorWithCode:0 localizedDescriptionKey:DSLocalizedFormat(@"Unknown block hash %@", nil, u256_hex(ffi_ref->unknown_block_hash))];
        case dash_spv_masternode_processor_processing_processor_processing_error_ProcessingError_InvalidResult:
            return [NSError errorWithCode:0 localizedDescriptionKey:DSLocalizedFormat(@"Invalid Result", nil, NSStringFromPtr(ffi_ref->invalid_result))];
        case dash_spv_masternode_processor_processing_processor_processing_error_ProcessingError_CoreProvider:
            return [NSError ffi_from_core_provider_error:ffi_ref->core_provider];
        case dash_spv_masternode_processor_processing_processor_processing_error_ProcessingError_MissingLists:
            return [NSError errorWithCode:0 localizedDescriptionKey:DSLocalizedFormat(@"Missing Masternode Lists: %@", nil, NSStringFromPtr(ffi_ref->missing_lists))];
        case dash_spv_masternode_processor_processing_processor_processing_error_ProcessingError_EncodeError:
            return [NSError errorWithCode:0 localizedDescriptionKey:DSLocalizedFormat(@"Encode Error: %@", nil, NSStringFromPtr(ffi_ref->encode_error))];
        case dash_spv_masternode_processor_processing_processor_processing_error_ProcessingError_DecodeError:
            return [NSError errorWithCode:0 localizedDescriptionKey:DSLocalizedFormat(@"Decode Error: %@", nil, NSStringFromPtr(ffi_ref->decode_error))];
        case dash_spv_masternode_processor_processing_processor_processing_error_ProcessingError_QuorumValidationError:
            return [NSError ffi_from_quorum_validation_error:ffi_ref->quorum_validation_error];
    }
}
@end

