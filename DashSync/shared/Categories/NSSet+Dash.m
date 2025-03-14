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

#import "NSSet+Dash.h"

@implementation NSSet (Dash)

- (NSSet *)compactMap:(id (^)(id obj))block {
    NSParameterAssert(block != nil);
    NSMutableSet *result = [NSMutableSet set];
    [self enumerateObjectsUsingBlock:^(id _Nonnull obj, BOOL *_Nonnull stop) {
        id mObj = block(obj);
        if (mObj && mObj != [NSNull null]) {
            [result addObject:mObj];
        }
    }];
    return result;
}

- (NSSet *)map:(id (^)(id obj))block {
    NSParameterAssert(block != nil);
    NSMutableSet *result = [NSMutableSet setWithCapacity:self.count];
    [self enumerateObjectsUsingBlock:^(id _Nonnull obj, BOOL *_Nonnull stop) {
        [result addObject:block(obj) ?: [NSNull null]];
    }];
    return result;
}

- (NSSet *)filter:(BOOL (^)(id obj))block {
    NSMutableSet *result = [NSMutableSet set];
    [self enumerateObjectsUsingBlock:^(id  _Nonnull obj, BOOL * _Nonnull stop) {
        if (block(obj) == YES) {
            [result addObject:obj];
        }
    }];
    return result;
}

@end

@implementation NSSet (Vec_u8_32)

+ (NSSet<NSData *> *)ffi_from_vec_u256:(Vec_u8_32 *)ffi_ref {
    NSMutableSet<NSData *> *arr = [NSMutableSet set];
    for (int i = 0; i < ffi_ref->count; i++) {
        [arr addObject:NSDataFromPtr(ffi_ref->values[i])];
    }
    return arr;
}
+ (Vec_u8_32 *)ffi_to_vec_u256:(NSSet<NSData *> *)obj {
    NSArray<NSData *> *arr = [obj allObjects];
    NSUInteger count = arr.count;
    u256 **values = malloc(count * sizeof(u256 *));
    for (NSUInteger i = 0; i < count; i++) {
        values[i] = u256_ctor(arr[i]);
    }
    return Vec_u8_32_ctor(count, values);
}
+ (void)ffi_destroy_vec_u256:(Vec_u8_32 *)ffi_ref {
    Vec_u8_32_destroy(ffi_ref);
}
@end

