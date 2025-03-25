//
//  DSSimpleIndexedDerivationPath.h
//  DashSync
//
//  Created by Sam Westrich on 2/20/19.
//

#import "DSDerivationPath.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSSimpleIndexedDerivationPath : DSDerivationPath

// returns the index of an address in the derivation path as long as it is within the gap limit
- (NSUInteger)indexOfKnownAddress:(NSString *)address;
- (NSUInteger)indexOfKnownAddressHash:(UInt160)hash;

// returns the index of the first unused Address;
- (uint32_t)firstUnusedIndex;

// gets addresses to an index, does not use cache and does not add to cache
- (NSArray *)addressesToIndex:(NSUInteger)index;

// gets addresses to an index, does not use cache and does not add to cache
- (NSArray *)addressesToIndex:(NSUInteger)index useCache:(BOOL)useCache addToCache:(BOOL)addToCache;

- (NSArray *)privateKeysForRange:(NSRange)range fromSeed:(NSData *)seed;

@end

NS_ASSUME_NONNULL_END
