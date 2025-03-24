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
#import "dash_spv_apple_bindings.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSIndexPath (Vec_u32)

+ (NSIndexPath *)ffi_from:(Vec_u32 *)ffi_ref;
+ (Vec_u32 *)ffi_to:(NSIndexPath *)obj;
+ (void)ffi_destroy:(Vec_u32 *)ffi_ref;
@end

NS_ASSUME_NONNULL_END
