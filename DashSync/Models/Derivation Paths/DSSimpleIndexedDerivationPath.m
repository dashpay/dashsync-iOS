//
//  DSSimpleIndexedDerivationPath.m
//  DashSync
//
//  Created by Sam Westrich on 2/20/19.
//

#import "DSSimpleIndexedDerivationPath+Protected.h"
#import "DSDerivationPath+Protected.h"


@implementation DSSimpleIndexedDerivationPath

- (instancetype)initWithIndexes:(NSUInteger *)indexes length:(NSUInteger)length
                           type:(DSDerivationPathType)type signingAlgorithm:(DSDerivationPathSigningAlgorith)signingAlgorithm reference:(DSDerivationPathReference)reference onChain:(DSChain*)chain {
    
    if (! (self = [super initWithIndexes:indexes length:length type:type signingAlgorithm:signingAlgorithm reference:reference onChain:chain])) return nil;
    
    self.mOrderedAddresses = [NSMutableArray array];
    
    return self;
}

-(void)loadAddresses {
    @synchronized (self) {
        if (!self.addressesLoaded) {
            [self.moc performBlockAndWait:^{
                [DSAddressEntity setContext:self.moc];
                [DSTransactionEntity setContext:self.moc];
                DSDerivationPathEntity * derivationPathEntity = [DSDerivationPathEntity derivationPathEntityMatchingDerivationPath:self];
                self.syncBlockHeight = derivationPathEntity.syncBlockHeight;
                NSArray<DSAddressEntity *> *addresses = [derivationPathEntity.addresses sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"index" ascending:YES]]];
                for (DSAddressEntity *e in addresses) {
                    @autoreleasepool {
                        while (e.index >= self.mOrderedAddresses.count) [self.mOrderedAddresses addObject:[NSNull null]];
                        if (![e.address isValidDashAddressOnChain:self.wallet.chain]) {
                            DSDLog(@"address %@ loaded but was not valid on chain %@",e.address,self.wallet.chain.name);
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
            self.addressesLoaded = TRUE;
            [self registerAddressesWithGapLimit:10];
        }
    }
}

-(void)reloadAddresses {
    [self.mAllAddresses removeAllObjects];
    [self.mUsedAddresses removeAllObjects];
    self.addressesLoaded = NO;
    [self loadAddresses];
}

// MARK: - Derivation Path Addresses

- (void)registerTransactionAddress:(NSString * _Nonnull)address {
    if (![self.mUsedAddresses containsObject:address]) {
        [self.mUsedAddresses addObject:address];
        [self registerAddressesWithDefaultGapLimit];
    }
}

-(NSUInteger)defaultGapLimit {
    return 10;
}

- (NSArray *)registerAddressesWithDefaultGapLimit {
    return [self registerAddressesWithGapLimit:[self defaultGapLimit]];
}

// Wallets are composed of chains of addresses. Each chain is traversed until a gap of a certain number of addresses is
// found that haven't been used in any transactions. This method returns an array of <gapLimit> unused addresses
// following the last used address in the chain.
- (NSArray *)registerAddressesWithGapLimit:(NSUInteger)gapLimit
{
    
    NSMutableArray * rArray = [self.mOrderedAddresses mutableCopy];
    
    if (!self.wallet.isTransient) {
        NSAssert(self.addressesLoaded, @"addresses must be loaded before calling this function");
    }
    NSUInteger i = rArray.count;
    
    // keep only the trailing contiguous block of addresses that aren't used
    while (i > 0 && ! [self.usedAddresses containsObject:rArray[i - 1]]) {
        i--;
    }
    
    if (i > 0) [rArray removeObjectsInRange:NSMakeRange(0, i)];
    if (rArray.count >= gapLimit) return [rArray subarrayWithRange:NSMakeRange(0, gapLimit)];
    
    @synchronized(self) {
        unsigned n = (unsigned)self.mOrderedAddresses.count;
        
        while (rArray.count < gapLimit) { // generate new addresses up to gapLimit
            NSData *pubKey = [self publicKeyDataAtIndex:n];
            NSString *addr = [DSKey addressWithPublicKeyData:pubKey forChain:self.chain];
            
            if (! addr) {
                DSDLog(@"error generating keys");
                return nil;
            }
            
            if (!self.wallet.isTransient) {
                [self.moc performBlock:^{ // store new address in core data
                    [DSDerivationPathEntity setContext:self.moc];
                    DSDerivationPathEntity * derivationPathEntity = [DSDerivationPathEntity derivationPathEntityMatchingDerivationPath:self];
                    DSAddressEntity *e = [DSAddressEntity managedObject];
                    e.derivationPath = derivationPathEntity;
                    NSAssert([addr isValidDashAddressOnChain:self.chain], @"the address is being saved to the wrong derivation path");
                    e.address = addr;
                    e.index = n;
                    e.standalone = NO;
                }];
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
    while (i > 0 && ! [self.usedAddresses containsObject:self.mOrderedAddresses[i - 1]]) {
        i--;
    }
    
    return i;
}

// gets an addess at an index
- (NSString *)addressAtIndex:(uint32_t)index
{
    return [self addressAtIndexPath:[NSIndexPath indexPathWithIndex:index]];
}

- (BOOL)addressIsUsedAtIndex:(uint32_t)index {
    return [self addressIsUsedAtIndexPath:[NSIndexPath indexPathWithIndex:index]];
}

- (NSIndexPath*)indexPathForKnownAddress:(NSString*)address {
    return [NSIndexPath indexPathWithIndex:[self indexOfKnownAddress:address]];
}

- (NSUInteger)indexOfKnownAddress:(NSString*)address {
    return [self.mOrderedAddresses indexOfObject:address];
}

// gets a public key at an index
- (NSData*)publicKeyDataAtIndex:(uint32_t)index
{
    return [self publicKeyDataAtIndexPath:[NSIndexPath indexPathWithIndex:index]];
}

- (DSKey *)privateKeyAtIndex:(uint32_t)index fromSeed:(NSData *)seed {
    return [self privateKeyAtIndexPath:[NSIndexPath indexPathWithIndex:index] fromSeed:seed];
}

- (NSArray *)publicKeyDataArrayToIndex:(NSUInteger)index
{
    NSMutableArray * mArray = [NSMutableArray array];
    for (int i = 0;i<index;i++) {
        NSData *pubKey = [self publicKeyDataAtIndex:i];
        [mArray addObject:pubKey];
    }
    return [mArray copy];
}

- (NSArray *)addressesToIndex:(NSUInteger)index
{
    NSMutableArray * mArray = [NSMutableArray array];
    for (NSData * pubKey in [self publicKeyDataArrayToIndex:index]) {
        NSString *addr = [DSKey addressWithPublicKeyData:pubKey forChain:self.chain];
        [mArray addObject:addr];
    }
    return [mArray copy];
}

- (NSArray *)privateKeysToIndex:(NSUInteger)index fromSeed:(NSData *)seed {

    NSMutableArray * mArray = [NSMutableArray array];
    for (int i = 0;i<index;i++) {
        DSKey *privateKey = [self privateKeyAtIndex:i fromSeed:seed];
        [mArray addObject:privateKey];
    }
    return [mArray copy];
}

@end
