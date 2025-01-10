//
//  Created by Sam Westrich
//  Copyright © 2020 Dash Core Group. All rights reserved.
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

NS_ASSUME_NONNULL_BEGIN

#define FFIMapConversion(TYPE, \
    KeyTypeC, KeyTypeObjC, KeyCtor, KeyDtor, KeyFrom, KeyTo, \
    ValueTypeC, ValueTypeObjC, ValueCtor, ValueDtor, ValueFrom, ValueTo) \
@implementation NSDictionary (Conversions_##TYPE) \
- (TYPE *)ffi_to:(NSDictionary *)obj { \
    NSUInteger i = 0, count = [obj count]; \
    TYPE *ffi_ref = malloc(sizeof(TYPE)); \
    KeyTypeC *keys = malloc(count * sizeof(KeyTypeC)); \
    ValueTypeC *values = malloc(count * sizeof(ValueTypeC)); \
    for (id key in obj) { \
        keys[i] = KeyTo; \
        values[i] = ValueTo; \
        i++; \
    } \
    ffi_ref->count = count; \
    ffi_ref->keys = keys; \
    ffi_ref->values = values; \
    return ffi_ref; \
} \
+ (TYPE *)ffi_to_opt:(NSDictionary * _Nullable)obj { \
    return obj ? [self ffi_to:obj] : nil; \
} \
- (NSDictionary *)ffi_from:(TYPE *)ffi_ref { \
    uintptr_t count = ffi_ref->count; \
    NSMutableDictionary *obj = [NSMutableDictionary dictionaryWithCapacity:count]; \
    for (int i = 0; i < count; i++) { \
        [obj setObject:ValueFrom forKey:KeyFrom]; \
    } \
    return obj; \
} \
+ (NSDictionary * _Nullable)ffi_from_opt:(TYPE *)ffi_ref { \
    return ffi_ref ? [self ffi_from:ffi_ref] : nil; \
} \
+ (void)ffi_destroy:(TYPE *)ffi_ref { \
    if (!ffi_ref) return; \
    if (ffi_ref->count > 0) { \
        for (int i = 0; i < ffi_ref->count; i++) { \
            KeyDtor\
            ValueDtor\
        } \
        free(ffi_ref->keys); \
        free(ffi_ref->values); \
    } \
    free(ffi_ref); \
} \
@end \
@implementation NSDictionary (Bindings_##TYPE) \
+ (TYPE *)ffi_ctor:(NSDictionary *)obj { \
    NSUInteger i = 0, count = [obj count]; \
    KeyTypeC *keys = malloc(count * sizeof(KeyTypeC)); \
    ValueTypeC *values = malloc(count * sizeof(ValueTypeC)); \
    for (id key in obj) { \
        keys[i] = KeyTo; \
        values[i] = ValueTo; \
        i++; \
    } \
    return ##TYPE_ctor(count, keys, values); \
} \
+ (void)ffi_dtor:(TYPE *)ffi_ref { \
    ##TYPE_destroy(ffi_ref); \
} \
@end
@interface NSDictionary (Dash)

- (NSDictionary *)transformToDictionaryOfHexStringsToHexStrings;
+ (NSDictionary *)mergeDictionary:(NSDictionary *_Nullable)dictionary1 withDictionary:(NSDictionary *)dictionary2;

@end

//FFIMapConversion(<#TYPE#>, <#KeyTypeC#>, <#KeyTypeObjC#>, <#KeyCtor#>, <#KeyDtor#>, <#KeyFrom#>, <#KeyTo#>, <#ValueTypeC#>, <#ValueTypeObjC#>, <#ValueCtor#>, <#ValueDtor#>, <#ValueFrom#>, <#ValueTo#>)

NS_ASSUME_NONNULL_END
