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

#import "NSIndexPath+FFI.h"

//@implementation NSIndexPath (FFI)
//
//- (Vec *)ffi_malloc {
//    DIndexPathU32 *obj = malloc(sizeof(dash_spv_crypto_keys_key_IndexPathU32));
//    NSUInteger *indexes = calloc(self.length, sizeof(NSUInteger));
//    [self getIndexes:indexes];
//    obj->indexes = Vec_u32_ctor(self.length, (uint32_t *) indexes);
////    obj->len = self.length;
//    return obj;
//}
//
//+ (void)ffi_free:(DIndexPathU32 *)entry {
//    if (entry->indexes > 0) {
//        free((void *) entry->indexes);
//    }
//    if (entry->hardened > 0) {
//        free((void *) entry->hardened);
//    }
//    free(entry);
////    if (entry->len > 0) {
////        free((void *) entry->indexes);
////    }
////    free(entry);
//}
//
//@end

@implementation NSIndexPath (Vec_u32)

+ (NSIndexPath *)ffi_from:(Vec_u32 *)ffi_ref {
    return [NSIndexPath indexPathWithIndexes:(NSUInteger *) ffi_ref->values length:ffi_ref->count];
}

+ (Vec_u32 *)ffi_to:(NSIndexPath *)obj {
    NSUInteger length = obj.length;
    uint32_t *indexes = malloc(sizeof(uint32_t) * length);
    for (NSUInteger i = 0; i < length; i++) {
        indexes[i] = (uint32_t)[obj indexAtPosition:i];
    }
    return Vec_u32_ctor(length, indexes);
    
}
+ (void)ffi_destroy:(Vec_u32 *)ffi_ref {
    Vec_u32_destroy(ffi_ref);
}
@end
