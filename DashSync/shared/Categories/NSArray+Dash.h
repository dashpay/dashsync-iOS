//
//  NSArray+Dash.h
//  DashSync
//
//  Created by Sam Westrich on 11/21/19.
//

#import "BigIntTypes.h"
#import "dash_shared_core.h"
#import "DSKeyManager.h"
#import "NSData+Dash.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSArray (Dash)

- (UInt256)hashDataComponents;
- (NSArray *)transformToArrayOfHexStrings;
- (UInt256)hashDataComponentsWithSelector:(SEL)hashFunction;
- (NSMutableArray *)secureMutableCopy;

- (NSArray *)compactMap:(id (^)(id obj))block;
- (NSArray *)map:(id (^)(id obj))block;

@end

//@interface NSArray (HashSet_u8_32)
//+ (NSArray<NSData *> *)ffi_from_hash_set:(std_collections_HashSet_u8_32 *)ffi_ref;
//+ (std_collections_HashSet_u8_32 *)ffi_to_hash_set:(NSArray<NSData *> *)obj;
//+ (void)ffi_destroy_hash_set:(std_collections_HashSet_u8_32 *)ffi_ref;
//@end

@interface NSArray (_)
+ (NSArray<NSString *> *)ffi_from_vec:(Vec_ *)ffi_ref;
+ (Vec_ *)ffi_to_vec:(NSArray<NSString *> *)obj;
+ (void)ffi_destroy_vec:(Vec_ *)ffi_ref;
@end

@interface NSArray (Vec_String)
+ (NSArray<NSString *> *)ffi_from_vec_of_string:(Vec_String *)ffi_ref;
+ (Vec_String *)ffi_to_vec_of_string:(NSArray<NSString *> *)obj;
+ (void)ffi_destroy_vec_of_string:(Vec_String *)ffi_ref;
@end

@interface NSArray (Vec_u8_32)
+ (NSArray<NSData *> *)ffi_from_vec_u256:(Vec_u8_32 *)ffi_ref;
+ (Vec_u8_32 *)ffi_to_vec_u256:(NSArray<NSData *> *)obj;
+ (void)ffi_destroy_vec_u256:(Vec_u8_32 *)ffi_ref;
@end

@interface NSArray (Vec_Vec_u8)
+ (NSArray<NSData *> *)ffi_from_vec_vec_u8:(Vec_Vec_u8 *)ffi_ref;
+ (Vec_Vec_u8 *)ffi_to_vec_vec_u8:(NSArray<NSData *> *)obj;
+ (void)ffi_destroy_vec_vec_u8:(Vec_Vec_u8 *)ffi_ref;
@end

@interface NSArray (std_collections_BTreeSet_dashcore_hash_types_BlockHash)
+ (NSArray<NSData *> *)ffi_from_block_hash_btree_set:(std_collections_BTreeSet_dashcore_hash_types_BlockHash *)ffi_ref;
+ (std_collections_BTreeSet_dashcore_hash_types_BlockHash *)ffi_to_block_hash_btree_set:(NSArray<NSData *> *)obj;
+ (void)ffi_destroy_block_hash_btree_set:(std_collections_BTreeSet_dashcore_hash_types_BlockHash *)ffi_ref;
@end


NS_ASSUME_NONNULL_END
