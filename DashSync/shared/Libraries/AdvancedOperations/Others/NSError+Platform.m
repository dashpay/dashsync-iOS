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

#import "NSError+Dash.h"
#import "NSError+Platform.h"

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
