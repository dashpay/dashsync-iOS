//
//  DSSimpleIndexedDerivationPath.m
//  DashSync
//
//  Created by Sam Westrich on 2/20/19.
//

#import "DSAccount.h"
#import "DSAddressEntity+CoreDataClass.h"
#import "DSGapLimit.h"
#import "DSAuthenticationKeysDerivationPath.h"
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
            [self registerAddressesWithSettings:[self defaultGapSettings]];
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
            [self registerAddressesWithSettings:[self defaultGapSettings]];
        }
        return TRUE;
    }
    return FALSE;
}

- (DSGapLimit *)defaultGapSettings {
    return [DSGapLimit withLimit:10];
}

// Wallets are composed of chains of addresses. Each chain is traversed until a gap of a certain number of addresses is
// found that haven't been used in any transactions. This method returns an array of <gapLimit> unused addresses
// following the last used address in the chain.
- (NSArray *)registerAddressesWithSettings:(DSGapLimit *)settings
                                 inContext:(NSManagedObjectContext *)context {
    NSAssert(self.type != DSDerivationPathType_MultipleUserAuthentication, @"This should not be called for multiple user authentication. Use '- (NSArray *)registerAddressesWithSettings:(DSGapLimit *)gapLimit' with DSGapLimitIdentity.");
    uintptr_t gapLimit = settings.gapLimit;

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
            NSData *pubKey = [self publicKeyDataAtIndexPath:[NSIndexPath indexPathWithIndex:n]];
            NSString *addr = [DSKeyManager addressWithPublicKeyData:pubKey forChain:self.chain];
            if (!addr) {
                DSLog(@"[%@] error generating keys", self.chain.name);
                return nil;
            }
            if (!self.wallet.isTransient)
                [self storeNewAddressInContext:addr atIndex:n context:self.managedObjectContext];

            [self.mAllAddresses addObject:addr];
            [rArray addObject:addr];
            [self.mOrderedAddresses addObject:addr];
            n++;
        }

        return rArray;
    }
}

- (uint32_t)firstUnusedIndex {
    uint32_t i = (uint32_t)self.mOrderedAddresses.count;

    // keep only the trailing contiguous block of addresses that aren't used
    while (i > 0 && ![self.usedAddresses containsObject:self.mOrderedAddresses[i - 1]]) {
        i--;
    }

    return i;
}

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

- (NSArray *)addressesToIndex:(NSUInteger)index {
    return [self addressesToIndex:index useCache:NO addToCache:NO];
}

- (NSArray *)addressesToIndex:(NSUInteger)index useCache:(BOOL)useCache addToCache:(BOOL)addToCache {
    NSMutableArray *mArray = [NSMutableArray array];
    for (uint32_t i = 0; i < index; i++) {
        if (useCache && self.mOrderedAddresses.count > i && self.mOrderedAddresses[i]) {
            [mArray addObject:self.mOrderedAddresses[i]];
        } else {
            NSData *pubKey = [self publicKeyDataAtIndexPath:[NSIndexPath indexPathWithIndex:i]];
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
        DMaybeOpaqueKey *privateKey = [self privateKeyAtIndexPath:[NSIndexPath indexPathWithIndex:i] fromSeed:seed];
        NSValue *privateKeyValue = [NSValue valueWithPointer:privateKey];
        [mArray addObject:privateKeyValue];
    }
    return [mArray copy];
}

- (void)loadAddressesInContext:(NSManagedObjectContext *)context {
    [context performBlockAndWait:^{
        DSDerivationPathEntity *derivationPathEntity = [DSDerivationPathEntity derivationPathEntityMatchingDerivationPath:self inContext:self.managedObjectContext];
        NSArray<DSAddressEntity *> *addresses = [derivationPathEntity.addresses sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"index" ascending:YES]]];
        for (DSAddressEntity *e in addresses) {
            @autoreleasepool {
                while (e.index >= self.mOrderedAddresses.count)
                    [self.mOrderedAddresses addObject:[NSNull null]];
                if (!DIsValidDashAddress(DChar(e.address), self.chain.chainType)) {
#if DEBUG
                    DSLogPrivate(@"[%@] address %@ loaded but was not valid on chain", self.chain.name, e.address);
#else
                        DSLog(@"[%@] address %@ loaded but was not valid on chain", self.chain.name, @"<REDACTED>");
#endif /* DEBUG */
                    continue;
                }
                self.mOrderedAddresses[e.index] = e.address;
                [self.mAllAddresses addObject:e.address];
                if ([e.usedInInputs count] || [e.usedInOutputs count] || [e.usedInSpecialTransactions count] /*|| [e.usedInSimplifiedMasternodeEntries count]*/) {
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
        NSAssert(DIsValidDashAddress(DChar(address), self.chain.chainType), @"the address is being saved to the wrong derivation path");
        e.address = address;
        e.index = n;
        e.standalone = NO;
    }];

}
@end
