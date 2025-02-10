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
#import "DSKeyManager.h"

@implementation NSError (dash_spv_platform_error_Error)

+ (nonnull NSError *)ffi_from_platform_error:(nonnull dash_spv_platform_error_Error *)ffi_ref {
    switch (ffi_ref->tag) {
        case dash_spv_platform_error_Error_KeyError:
            return [NSError ffi_from_key_error:ffi_ref->key_error];
        case dash_spv_platform_error_Error_DashSDKError:
            return [NSError errorWithCode:0 localizedDescriptionKey:[NSString stringWithCString:ffi_ref->dash_sdk_error encoding:NSUTF8StringEncoding]];
        case dash_spv_platform_error_Error_Any:
            return [NSError errorWithCode:ffi_ref->any._0 localizedDescriptionKey:[NSString stringWithCString:ffi_ref->any._1 encoding:NSUTF8StringEncoding]];
        case dash_spv_platform_error_Error_MaxRetryExceeded:
            return [NSError errorWithCode:0 localizedDescriptionKey:[NSString stringWithCString:ffi_ref->max_retry_exceeded encoding:NSUTF8StringEncoding]];
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
            return [NSError errorWithCode:0 localizedDescriptionKey:[NSString stringWithCString:ffi_ref->any encoding:NSUTF8StringEncoding]];
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
        case dash_spv_masternode_processor_processing_core_provider_CoreProviderError_QuorumValidation:
            return [NSError errorWithCode:0 localizedDescriptionKey:DSLocalizedString(@"Quorum Validation Error", nil)];
    }
}
@end

@implementation NSError (dash_spv_masternode_processor_processing_processing_error_ProcessingError)
+ (NSError *)ffi_from_processing_error:(dash_spv_masternode_processor_processing_processing_error_ProcessingError *)ffi_ref {
    switch (ffi_ref->tag) {
        case dash_spv_masternode_processor_processing_processing_error_ProcessingError_PersistInRetrieval:
            return [NSError errorWithCode:0 localizedDescriptionKey:DSLocalizedFormat(@"Unexpected Diff Processing (%@..%@)", nil, u256_hex(ffi_ref->persist_in_retrieval._0), u256_hex(ffi_ref->persist_in_retrieval._1))];
        case dash_spv_masternode_processor_processing_processing_error_ProcessingError_LocallyStored:
            return [NSError errorWithCode:0 localizedDescriptionKey:DSLocalizedFormat(@"Masternode List already stored for %u: %@", nil, ffi_ref->locally_stored._0, u256_hex(ffi_ref->locally_stored._1))];
        case dash_spv_masternode_processor_processing_processing_error_ProcessingError_ParseError:
            return [NSError errorWithCode:0 localizedDescriptionKey:DSLocalizedFormat(@"Message Parse Error", nil, NSStringFromPtr(ffi_ref->parse_error))];
        case dash_spv_masternode_processor_processing_processing_error_ProcessingError_HasNoBaseBlockHash:
            return [NSError errorWithCode:0 localizedDescriptionKey:DSLocalizedFormat(@"Unknown base block hash", nil, u256_hex(ffi_ref->has_no_base_block_hash))];
        case dash_spv_masternode_processor_processing_processing_error_ProcessingError_UnknownBlockHash:
            return [NSError errorWithCode:0 localizedDescriptionKey:DSLocalizedFormat(@"Unknown block hash %@", nil, u256_hex(ffi_ref->unknown_block_hash))];
        case dash_spv_masternode_processor_processing_processing_error_ProcessingError_InvalidResult:
            return [NSError errorWithCode:0 localizedDescriptionKey:DSLocalizedFormat(@"Invalid Result", nil, NSStringFromPtr(ffi_ref->invalid_result))];
        case dash_spv_masternode_processor_processing_processing_error_ProcessingError_CoreProvider:
            return [NSError ffi_from_core_provider_error:ffi_ref->core_provider];
        case dash_spv_masternode_processor_processing_processing_error_ProcessingError_MissingLists:
            return [NSError errorWithCode:0 localizedDescriptionKey:DSLocalizedFormat(@"Missing Masternode Lists: %@", nil, NSStringFromPtr(ffi_ref->missing_lists))];
    }
}
@end

