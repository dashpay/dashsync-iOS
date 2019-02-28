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

- (NSUInteger)indexOfAddress:(NSString*)address;

// gets a public key at an index
- (NSData*)publicKeyDataAtIndex:(uint32_t)index;

// gets an addess at an index
- (NSString *)addressAtIndex:(uint32_t)index;

- (NSArray *)publicKeyDataArrayToIndex:(NSUInteger)index;
- (NSArray *)addressesToIndex:(NSUInteger)index;

// gets a private key at an index
- (DSKey * _Nullable)privateKeyAtIndex:(uint32_t)index fromSeed:(NSData *)seed;

@end

NS_ASSUME_NONNULL_END
