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

#import <Foundation/Foundation.h>
#import "dash_shared_core.h"
#import "DSKeyManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSError (dash_spv_platform_error_Error)
+ (NSError *)ffi_from_platform_error:(dash_spv_platform_error_Error *)ffi_ref;
@end


@interface NSError (dash_spv_crypto_keys_KeyError)
+ (NSError *)ffi_from_key_error:(dash_spv_crypto_keys_KeyError *)ffi_ref;
@end

@interface NSError (dash_spv_masternode_processor_processing_core_provider_CoreProviderError)
+ (NSError *)ffi_from_core_provider_error:(dash_spv_masternode_processor_processing_core_provider_CoreProviderError *)ffi_ref;
@end

@interface NSError (DProcessingError)
+ (NSError *)ffi_from_processing_error:(DProcessingError *)ffi_ref;
@end


NS_ASSUME_NONNULL_END
