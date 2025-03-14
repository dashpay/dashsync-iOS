//
//  Created by Vladimir Pirogov
//  Copyright © 2021 Dash Core Group. All rights reserved.
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
#import "DSKeyManager.h"
NS_ASSUME_NONNULL_BEGIN

@interface NSSet (Dash)

- (NSSet *)compactMap:(id (^)(id obj))block;
- (NSSet *)map:(id (^)(id obj))block;
- (NSSet *)filter:(BOOL (^)(id obj))block;

@end

@interface NSSet (Vec_u8_32)

+ (NSSet<NSData *> *)ffi_from_vec_u256:(Vec_u8_32 *)ffi_ref;
+ (Vec_u8_32 *)ffi_to_vec_u256:(NSSet<NSData *> *)obj;
+ (void)ffi_destroy_vec_u256:(Vec_u8_32 *)ffi_ref;
@end



NS_ASSUME_NONNULL_END
