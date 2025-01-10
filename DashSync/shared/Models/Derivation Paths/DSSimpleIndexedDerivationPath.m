//
//  DSSimpleIndexedDerivationPath.m
//  DashSync
//
//  Created by Sam Westrich on 2/20/19.
//

#import "DSAddressEntity+CoreDataClass.h"
#import "DSChain+Params.h"
#import "DSDerivationPath+Protected.h"
#import "DSKeyManager.h"
#import "DSSimpleIndexedDerivationPath+Protected.h"
#import "NSError+Dash.h"
#import "NSManagedObject+Sugar.h"

@implementation DSSimpleIndexedDerivationPath

- (instancetype _Nullable)initWithIndexes:(const UInt256[_Nullable])indexes
                                 hardened:(const BOOL[_Nullable])hardenedIndexes
                                   length:(NSUInteger)length
                                     type:(DSDerivationPathType)type
                         signingAlgorithm:(DKeyKind *)signingAlgorithm
                                reference:(DSDerivationPathReference)reference
                                  onChain:(DSChain *)chain {
    if (!(self = [super initWithIndexes:indexes
                               hardened:hardenedIndexes
                                 length:length
                                   type:type
                       signingAlgorithm:signingAlgorithm
                              reference:reference
                                onChain:chain])) return nil;

    self.mOrderedAddresses = [NSMutableArray array];

    return self;
}

- (void)loadAddresses {
    @synchronized(self) {
        if (!self.addressesLoaded) {
            [self loadAddressesInContext:self.managedObjectContext];
            self.addressesLoaded = TRUE;
            [self registerAddressesWithGapLimit:10 error:nil];
        }
    }
}

- (void)reloadAddresses {
    [self.mAllAddresses removeAllObjects];
    [self.mOrderedAddresses removeAllObjects];
    [self.mUsedAddresses removeAllObjects];
    self.addressesLoaded = NO;
    [self loadAddresses];
}

// MARK: - Derivation Path Addresses

- (BOOL)registerTransactionAddress:(NSString *_Nonnull)address {
    if ([self containsAddress:address]) {
        if (![self.mUsedAddresses containsObject:address]) {
            [self.mUsedAddresses addObject:address];
            [self registerAddressesWithDefaultGapLimitWithError:nil];
        }
        return TRUE;
    }
    return FALSE;
}

- (NSUInteger)defaultGapLimit {
    return 10;
}

- (NSArray *)registerAddressesWithDefaultGapLimitWithError:(NSError **)error {
    return [self registerAddressesWithGapLimit:[self defaultGapLimit] error:error];
}

// Wallets are composed of chains of addresses. Each chain is traversed until a gap of a certain number of addresses is
// found that haven't been used in any transactions. This method returns an array of <gapLimit> unused addresses
// following the last used address in the chain.
- (NSArray *)registerAddressesWithGapLimit:(NSUInteger)gapLimit error:(NSError **)error {
    NSAssert(self.type != DSDerivationPathType_MultipleUserAuthentication, @"This should not be called for multiple user authentication. Use '- (NSArray *)registerAddressesWithGapLimit:(NSUInteger)gapLimit forIdentityIndex:(uint32_t)identityIndex error:(NSError**)error' instead.");

    NSMutableArray *rArray = [self.mOrderedAddresses mutableCopy];

    if (!self.wallet.isTransient) {
        NSAssert(self.addressesLoaded, @"addresses must be loaded before calling this function");
    }
    NSUInteger i = rArray.count;

    // keep only the trailing contiguous block of addresses that aren't used
    while (i > 0 && ![self.usedAddresses containsObject:rArray[i - 1]]) {
        i--;
    }

    if (i > 0) [rArray removeObjectsInRange:NSMakeRange(0, i)];
    if (rArray.count >= gapLimit) return [rArray subarrayWithRange:NSMakeRange(0, gapLimit)];

    @synchronized(self) {
        //It seems weird to repeat this, but it's correct because of the original call receive address and change address
        rArray = [self.mOrderedAddresses mutableCopy];
        i = rArray.count;

        unsigned n = (unsigned)i;

        // keep only the trailing contiguous block of addresses with no transactions
        while (i > 0 && ![self.usedAddresses containsObject:rArray[i - 1]]) {
            i--;
        }

        if (i > 0) [rArray removeObjectsInRange:NSMakeRange(0, i)];
        if (rArray.count >= gapLimit) return [rArray subarrayWithRange:NSMakeRange(0, gapLimit)];

        while (rArray.count < gapLimit) { // generate new addresses up to gapLimit
            NSData *pubKey = [self publicKeyDataAtIndex:n];
            NSString *addr = [DSKeyManager addressWithPublicKeyData:pubKey forChain:self.chain];
            if (!addr) {
                DSLog(@"[%@] error generating keys", self.chain.name);
                if (error) {
                    *error = [NSError errorWithCode:500 localizedDescriptionKey:@"Error generating public keys"];
                }
                return nil;
            }

            if (!self.wallet.isTransient) {
                [self storeNewAddressInContext:addr atIndex:n context:self.managedObjectContext];
            }

            [self.mAllAddresses addObject:addr];
            [rArray addObject:addr];
            [self.mOrderedAddresses addObject:addr];
            n++;
        }

        return rArray;
    }
}

- (NSUInteger)firstUnusedIndex {
    uint32_t i = (uint32_t)self.mOrderedAddresses.count;

    // keep only the trailing contiguous block of addresses that aren't used
    while (i > 0 && ![self.usedAddresses containsObject:self.mOrderedAddresses[i - 1]]) {
        i--;
    }

    return i;
}

// gets an addess at an index
- (NSString *)addressAtIndex:(uint32_t)index {
    return [self addressAtIndexPath:[NSIndexPath indexPathWithIndex:index]];
}

//- (BOOL)addressIsUsedAtIndex:(uint32_t)index {
//    return [self addressIsUsedAtIndexPath:[NSIndexPath indexPathWithIndex:index]];
//}

- (NSIndexPath *)indexPathForKnownAddress:(NSString *)address {
    return [NSIndexPath indexPathWithIndex:[self indexOfKnownAddress:address]];
}

- (NSUInteger)indexOfKnownAddress:(NSString *)address {
    return [self.mOrderedAddresses indexOfObject:address];
}

- (NSUInteger)indexOfKnownAddressHash:(UInt160)hash {
    NSString *address = [DSKeyManager addressFromHash160:hash forChain:self.chain];
    return [self.mOrderedAddresses indexOfObject:address];
}

// gets a public key at an index
- (NSData *)publicKeyDataAtIndex:(uint32_t)index {
    return [self publicKeyDataAtIndexPath:[NSIndexPath indexPathWithIndex:index]];
}

- (DMaybeOpaqueKey *)privateKeyAtIndex:(uint32_t)index fromSeed:(NSData *)seed {
    return [self privateKeyAtIndexPath:[NSIndexPath indexPathWithIndex:index] fromSeed:seed];
}

- (NSArray *)publicKeyDataArrayToIndex:(NSUInteger)index {
    NSMutableArray *mArray = [NSMutableArray array];
    for (int i = 0; i < index; i++) {
        NSData *pubKey = [self publicKeyDataAtIndex:i];
        [mArray addObject:pubKey];
    }
    return [mArray copy];
}

- (NSArray *)addressesToIndex:(NSUInteger)index {
    return [self addressesToIndex:index useCache:NO addToCache:NO];
}

- (NSArray *)addressesToIndex:(NSUInteger)index useCache:(BOOL)useCache addToCache:(BOOL)addToCache {
    NSMutableArray *mArray = [NSMutableArray array];
    for (uint32_t i = 0; i < index; i++) {
        if (useCache && self.mOrderedAddresses.count > i && self.mOrderedAddresses[i]) {
            [mArray addObject:self.mOrderedAddresses[i]];
        } else {
            NSData *pubKey = [self publicKeyDataAtIndex:i];
            NSString *addr = [DSKeyManager addressWithPublicKeyData:pubKey forChain:self.chain];
            [mArray addObject:addr];
            if (addToCache && self.mOrderedAddresses.count == i) {
                [self.mOrderedAddresses addObject:addr];
            }
        }
    }
    return [mArray copy];
}

- (NSArray *)privateKeysForRange:(NSRange)range fromSeed:(NSData *)seed {
    NSMutableArray *mArray = [NSMutableArray array];
    for (NSUInteger i = range.location; i < (range.location + range.length); i++) {
        DMaybeOpaqueKey *privateKey = [self privateKeyAtIndex:(uint32_t)i fromSeed:seed];
        NSValue *privateKeyValue = [NSValue valueWithPointer:privateKey];
        [mArray addObject:privateKeyValue];
    }
    return [mArray copy];
}

- (NSArray *)privateKeysToIndex:(NSUInteger)index fromSeed:(NSData *)seed {
    return [self privateKeysForRange:NSMakeRange(0, index) fromSeed:seed];
}


- (void)loadAddressesInContext:(NSManagedObjectContext *)context {
    [context performBlockAndWait:^{
        DSDerivationPathEntity *derivationPathEntity = [DSDerivationPathEntity derivationPathEntityMatchingDerivationPath:self inContext:self.managedObjectContext];
        self.syncBlockHeight = derivationPathEntity.syncBlockHeight;
        NSArray<DSAddressEntity *> *addresses = [derivationPathEntity.addresses sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"index" ascending:YES]]];
        for (DSAddressEntity *e in addresses) {
            @autoreleasepool {
                while (e.index >= self.mOrderedAddresses.count) [self.mOrderedAddresses addObject:[NSNull null]];
                if (![DSKeyManager isValidDashAddress:e.address forChain:self.wallet.chain]) {
#if DEBUG
                    DSLogPrivate(@"[%@] address %@ loaded but was not valid on chain", self.chain.name, e.address);
#else
                        DSLog(@"[%@] address %@ loaded but was not valid on chain", self.account.wallet.chain.name, @"<REDACTED>");
#endif /* DEBUG */
                    continue;
                }
                self.mOrderedAddresses[e.index] = e.address;
                [self.mAllAddresses addObject:e.address];
                if ([e.usedInInputs count] || [e.usedInOutputs count] || [e.usedInSpecialTransactions count] || [e.usedInSimplifiedMasternodeEntries count]) {
                    [self.mUsedAddresses addObject:e.address];
                }
            }
        }
    }];

}
- (void)storeNewAddressInContext:(NSString *)address
                         atIndex:(uint32_t)n
                         context:(NSManagedObjectContext *)context {
    [context performBlock:^{ // store new address in core data
        DSDerivationPathEntity *derivationPathEntity = [DSDerivationPathEntity derivationPathEntityMatchingDerivationPath:self inContext:self.managedObjectContext];
        DSAddressEntity *e = [DSAddressEntity managedObjectInContext:self.managedObjectContext];
        e.derivationPath = derivationPathEntity;
        NSAssert([DSKeyManager isValidDashAddress:address forChain:self.chain], @"the address is being saved to the wrong derivation path");
        e.address = address;
        e.index = n;
        e.standalone = NO;
    }];

}
@end
