//
//  DSSimpleIndexedDerivationPath.h
//  DashSync
//
//  Created by Sam Westrich on 2/20/19.
//

#import "DSDerivationPath.h"

NS_ASSUME_NONNULL_BEGIN

@class DSKey;

@interface DSSimpleIndexedDerivationPath : DSDerivationPath

// returns the index of an address in the derivation path as long as it is within the gap limit
- (NSUInteger)indexOfKnownAddress:(NSString*)address;

// returns the index of the first unused Address;
- (NSUInteger)firstUnusedIndex;

// gets a public key at an index
- (NSData*)publicKeyDataAtIndex:(uint32_t)index;

// gets public keys to an index as NSData
- (NSArray *)publicKeyDataArrayToIndex:(NSUInteger)index;

// gets an addess at an index
- (NSString *)addressAtIndex:(uint32_t)index;

// true if the address at the index was previously used as an input or output in any wallet transaction
- (BOOL)addressIsUsedAtIndex:(uint32_t)index;

// gets addresses to an index, does not use cache and does not add to cache
- (NSArray *)addressesToIndex:(NSUInteger)index;

// gets addresses to an index, does not use cache and does not add to cache
- (NSArray *)addressesToIndex:(NSUInteger)index useCache:(BOOL)useCache addToCache:(BOOL)addToCache;

// gets a private key at an index
- (DSKey * _Nullable)privateKeyAtIndex:(uint32_t)index fromSeed:(NSData *)seed;

// get private keys for a range or to an index
- (NSArray *)privateKeysToIndex:(NSUInteger)index fromSeed:(NSData *)seed;
- (NSArray *)privateKeysForRange:(NSRange)range fromSeed:(NSData *)seed;

// update addresses
- (NSArray * _Nullable)registerAddressesWithDefaultGapLimitWithError:(NSError**)error;
- (NSArray * _Nullable)registerAddressesWithGapLimit:(NSUInteger)gapLimit error:(NSError**)error;

@end

NS_ASSUME_NONNULL_END
