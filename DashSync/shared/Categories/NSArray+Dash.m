//
//  NSArray+Dash.m
//  DashSync
//
//  Created by Sam Westrich on 11/21/19.
//

#import "NSArray+Dash.h"
#import "NSMutableArray+Dash.h"
#import "NSMutableData+Dash.h"

@implementation NSArray (Dash)

- (UInt256)hashDataComponents {
    NSMutableData *concatenatedData = [NSMutableData data];
    for (NSData *data in self) {
        [concatenatedData appendData:data];
    }
    return [concatenatedData SHA256];
}

- (UInt256)hashDataComponentsWithSelector:(SEL)hashFunction {
    NSMutableData *concatenatedData = [NSMutableData data];
    for (NSData *data in self) {
        [concatenatedData appendData:data];
    }
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:
                                                 [NSMutableData instanceMethodSignatureForSelector:hashFunction]];
    [invocation setSelector:hashFunction];
    [invocation setTarget:concatenatedData];
    [invocation invoke];
    UInt256 returnValue = UINT256_ZERO;
    [invocation getReturnValue:&returnValue];
    return returnValue;
}

- (NSArray *)transformToArrayOfHexStrings {
    NSMutableArray *mArray = [NSMutableArray array];
    for (NSData *data in self) {
        NSAssert([data isKindOfClass:[NSData class]], @"all elements must be of type NSData");
        [mArray addObject:[data hexString]];
    }
    return [mArray copy];
}

- (NSMutableArray *)secureMutableCopy {
    return [NSMutableArray secureArrayWithArray:self];
}

- (NSArray *)compactMap:(id (^)(id obj))block {
    NSMutableArray *result = [NSMutableArray array];
    [self enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        id mObj = block(obj);
        if (mObj && mObj != [NSNull null]) {
            [result addObject:mObj];
        }
    }];
    return result;
}

- (NSArray *)map:(id (^)(id obj))block {
    NSParameterAssert(block != nil);
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:self.count];
    [self enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [result addObject:block(obj) ?: [NSNull null]];
    }];
    return result;
}

@end

//@implementation NSArray (HashSet_u8_32)
//
//+ (NSArray<NSData *> *)ffi_from_hash_set:(std_collections_HashSet_u8_32 *)ffi_ref {
//    NSMutableArray<NSData *> *arr = [NSMutableArray arrayWithCapacity:ffi_ref->count];
//    for (int i = 0; i < ffi_ref->count; i++) {
//        u256 *chunk = ffi_ref->values[i];
//        NSData *data = NSDataFromPtr(chunk);
//        [arr addObject:data];
//    }
//    return arr;
//}
//+ (std_collections_HashSet_u8_32 *)ffi_to_hash_set:(NSArray<NSData *> *)obj {
//    std_collections_HashSet_u8_32 *set = malloc(sizeof(std_collections_HashSet_u8_32));
//    u256 **values = malloc(obj.count * sizeof(u256 *));
//    for (NSUInteger i = 0; i < obj.count; i++) {
//        NSData *data = obj[i];
//        values[i] = u256_ctor(data);
//    }
//    set->count = obj.count;
//    set->values = values;
//    return set;
//}
//+ (void)ffi_destroy_hash_set:(std_collections_HashSet_u8_32 *)ffi_ref {
//    std_collections_HashSet_u8_32_destroy(ffi_ref);
//}
//@end

@implementation NSArray (_)

+ (NSArray<NSString *> *)ffi_from_vec:(Vec_ *)ffi_ref {
    NSMutableArray<NSString *> *arr = [NSMutableArray arrayWithCapacity:ffi_ref->count];
    for (int i = 0; i < ffi_ref->count; i++) {
        [arr addObject:[NSString stringWithUTF8String:ffi_ref->values[i]]];
    }
    return arr;
}
+ (Vec_ *)ffi_to_vec:(NSArray<NSString *> *)obj {
    NSUInteger count = obj.count;
    char **values = malloc(count * sizeof(char *));
    for (NSUInteger i = 0; i < count; i++) {
        values[i] = strdup([obj[i] UTF8String]);
    }
    return Vec__ctor(count, values);
}
+ (void)ffi_destroy_vec:(Vec_ *)ffi_ref {
    Vec__destroy(ffi_ref);
}
@end

@implementation NSArray (Vec_String)

+ (NSArray<NSString *> *)ffi_from_vec_of_string:(Vec_String *)ffi_ref {
    NSMutableArray<NSString *> *arr = [NSMutableArray arrayWithCapacity:ffi_ref->count];
    for (int i = 0; i < ffi_ref->count; i++) {
        [arr addObject:[NSString stringWithUTF8String:ffi_ref->values[i]]];
    }
    return arr;
}
+ (Vec_String *)ffi_to_vec_of_string:(NSArray<NSString *> *)obj {
    NSUInteger count = obj.count;
    char **values = malloc(count * sizeof(char *));
    for (NSUInteger i = 0; i < count; i++) {
        values[i] = strdup([obj[i] UTF8String]);
    }
    return Vec_String_ctor(count, values);
}
+ (void)ffi_destroy_vec_of_string:(Vec_String *)ffi_ref {
    Vec_String_destroy(ffi_ref);
}
@end

@implementation NSArray (Vec_u8_32)

+ (NSArray<NSData *> *)ffi_from_vec_u256:(Vec_u8_32 *)ffi_ref {
    NSMutableArray<NSData *> *arr = [NSMutableArray arrayWithCapacity:ffi_ref->count];
    for (int i = 0; i < ffi_ref->count; i++) {
        [arr addObject:NSDataFromPtr(ffi_ref->values[i])];
    }
    return arr;
}
+ (Vec_u8_32 *)ffi_to_vec_u256:(NSArray<NSData *> *)obj {
    NSUInteger count = obj.count;
    u256 **values = malloc(count * sizeof(u256 *));
    for (NSUInteger i = 0; i < count; i++) {
        values[i] = u256_ctor(obj[i]);
    }
    return Vec_u8_32_ctor(count, values);
}
+ (void)ffi_destroy_vec_u256:(Vec_u8_32 *)ffi_ref {
    Vec_u8_32_destroy(ffi_ref);
}
@end

@implementation NSArray (Vec_Vec_u8)

+ (NSArray<NSData *> *)ffi_from_vec_vec_u8:(Vec_Vec_u8 *)ffi_ref {
    NSMutableArray<NSData *> *arr = [NSMutableArray arrayWithCapacity:ffi_ref->count];
    for (int i = 0; i < ffi_ref->count; i++) {
        [arr addObject:NSDataFromPtr(ffi_ref->values[i])];
    }
    return arr;
}
+ (Vec_Vec_u8 *)ffi_to_vec_vec_u8:(NSArray<NSData *> *)obj {
    NSUInteger count = obj.count;
    Vec_u8 **values = malloc(sizeof(Vec_u8 *) * count);
    for (int i = 0; i < count; i++) {
        values[i] = bytes_ctor(obj[i]);
    }
    return Vec_Vec_u8_ctor(count, values);
}
+ (void)ffi_destroy_vec_vec_u8:(Vec_Vec_u8 *)ffi_ref {
    Vec_Vec_u8_destroy(ffi_ref);
}
@end

@implementation NSArray (std_collections_BTreeSet_dashcore_hash_types_BlockHash)

+ (NSArray<NSData *> *)ffi_from_block_hash_btree_set:(std_collections_BTreeSet_dashcore_hash_types_BlockHash *)ffi_ref {
    NSMutableArray<NSData *> *arr = [NSMutableArray arrayWithCapacity:ffi_ref->count];
    for (int i = 0; i < ffi_ref->count; i++) {
        u256 *block_hash = dashcore_hash_types_BlockHash_inner(ffi_ref->values[i]);
        NSData *blockHashData = NSDataFromPtr(block_hash);
        u256_dtor(block_hash);
        [arr addObject:blockHashData];
    }
    return arr;
}
+ (std_collections_BTreeSet_dashcore_hash_types_BlockHash *)ffi_to_block_hash_btree_set:(NSArray<NSData *> *)obj {
    NSUInteger count = obj.count;
    DBlockHash **values = malloc(sizeof(DBlockHash *) * count);
    for (int i = 0; i < count; i++) {
        values[i] = dashcore_hash_types_BlockHash_ctor(u256_ctor(obj[i]));
    }
    return std_collections_BTreeSet_dashcore_hash_types_BlockHash_ctor(count, values);
}
+ (void)ffi_destroy_block_hash_btree_set:(std_collections_BTreeSet_dashcore_hash_types_BlockHash *)ffi_ref {
    std_collections_BTreeSet_dashcore_hash_types_BlockHash_destroy(ffi_ref);
}
@end

