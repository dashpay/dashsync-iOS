//
//  DSFundsDerivationPath.m
//  DashSync
//
//  Created by Sam Westrich on 2/10/19.
//

#import "DSDerivationPath+Protected.h"
#import "DSFundsDerivationPath.h"

@interface DSFundsDerivationPath()

@property (nonatomic, strong) NSMutableArray *internalAddresses, *externalAddresses;

@end

@implementation DSFundsDerivationPath

+ (instancetype _Nonnull)bip32DerivationPathOnChain:(DSChain*)chain forAccountNumber:(uint32_t)accountNumber {
    NSUInteger indexes[] = {accountNumber | BIP32_HARD};
    return [self derivationPathWithIndexes:indexes length:1 type:DSDerivationPathType_ClearFunds signingAlgorithm:DSDerivationPathSigningAlgorith_ECDSA reference:DSDerivationPathReference_BIP32 onChain:chain];
}
+ (instancetype _Nonnull)bip44DerivationPathOnChain:(DSChain*)chain forAccountNumber:(uint32_t)accountNumber {
    NSUInteger coinType = (chain.chainType == DSChainType_MainNet)?5:1;
    NSUInteger indexes[] = {44 | BIP32_HARD, coinType | BIP32_HARD, accountNumber | BIP32_HARD};
    return [self derivationPathWithIndexes:indexes length:3 type:DSDerivationPathType_ClearFunds signingAlgorithm:DSDerivationPathSigningAlgorith_ECDSA reference:DSDerivationPathReference_BIP44 onChain:chain];
}

- (instancetype)initWithIndexes:(NSUInteger *)indexes length:(NSUInteger)length
                           type:(DSDerivationPathType)type signingAlgorithm:(DSDerivationPathSigningAlgorith)signingAlgorithm reference:(DSDerivationPathReference)reference onChain:(DSChain*)chain {
    
    if (! (self = [super initWithIndexes:indexes length:length type:type signingAlgorithm:signingAlgorithm reference:reference onChain:chain])) return nil;
    
    self.internalAddresses = [NSMutableArray array];
    self.externalAddresses = [NSMutableArray array];
    
    return self;
}

-(void)reloadAddresses {
    self.internalAddresses = [NSMutableArray array];
    self.externalAddresses = [NSMutableArray array];
    [self.mUsedAddresses removeAllObjects];
    self.addressesLoaded = NO;
    [self loadAddresses];
}

-(void)loadAddresses {
    if (!self.addressesLoaded) {
        [self.moc performBlockAndWait:^{
            [DSAddressEntity setContext:self.moc];
            [DSTransactionEntity setContext:self.moc];
            DSDerivationPathEntity * derivationPathEntity = [DSDerivationPathEntity derivationPathEntityMatchingDerivationPath:self];
            self.syncBlockHeight = derivationPathEntity.syncBlockHeight;
            for (DSAddressEntity *e in derivationPathEntity.addresses) {
                @autoreleasepool {
                    NSMutableArray *a = (e.internal) ? self.internalAddresses : self.externalAddresses;
                    
                    while (e.index >= a.count) [a addObject:[NSNull null]];
                    if (![e.address isValidDashAddressOnChain:self.account.wallet.chain]) {
                        DSDLog(@"address %@ loaded but was not valid on chain %@",e.address,self.account.wallet.chain.name);
                        continue;
                    }
                    a[e.index] = e.address;
                    [self.mAllAddresses addObject:e.address];
                    if ([e.usedInInputs count] || [e.usedInOutputs count]) {
                        [self.mUsedAddresses addObject:e.address];
                    }
                }
            }
        }];
        self.addressesLoaded = TRUE;
        [self registerAddressesWithGapLimit:100 internal:YES];
        [self registerAddressesWithGapLimit:100 internal:NO];
        
    }
}

// MARK: - Derivation Path Addresses

- (void)registerTransactionAddress:(NSString * _Nonnull)address {
    if ([self containsAddress:address]) {
        if (![self.mUsedAddresses containsObject:address]) {
            [self.mUsedAddresses addObject:address];
            if ([self.internalAddresses containsObject:address]) {
                [self registerAddressesWithGapLimit:SEQUENCE_GAP_LIMIT_INTERNAL internal:YES];
            } else {
                [self registerAddressesWithGapLimit:SEQUENCE_GAP_LIMIT_EXTERNAL internal:NO];
            }
        }
    }
}

// Wallets are composed of chains of addresses. Each chain is traversed until a gap of a certain number of addresses is
// found that haven't been used in any transactions. This method returns an array of <gapLimit> unused addresses
// following the last used address in the chain. The internal chain is used for change addresses and the external chain
// for receive addresses.
- (NSArray *)registerAddressesWithGapLimit:(NSUInteger)gapLimit internal:(BOOL)internal
{
    if (!self.account.wallet.isTransient) {
        NSAssert(self.addressesLoaded, @"addresses must be loaded before calling this function");
    }
    
    @synchronized(self) {
        
        NSMutableArray *a = [NSMutableArray arrayWithArray:(internal) ? self.internalAddresses : self.externalAddresses];
        NSUInteger i = a.count;
        
        // keep only the trailing contiguous block of addresses with no transactions
        while (i > 0 && ! [self.usedAddresses containsObject:a[i - 1]]) {
            i--;
        }
        
        if (i > 0) [a removeObjectsInRange:NSMakeRange(0, i)];
        if (a.count >= gapLimit) return [a subarrayWithRange:NSMakeRange(0, gapLimit)];
        
        if (gapLimit > 1) { // get receiveAddress and changeAddress first to avoid blocking
            [self receiveAddress];
            [self changeAddress];
        }
        
        uint32_t n = (internal) ? (uint32_t)self.internalAddresses.count : (uint32_t)self.externalAddresses.count;
        
        while (a.count < gapLimit) { // generate new addresses up to gapLimit
            NSData *pubKey = [self publicKeyDataAtIndex:n internal:internal];
            NSString *addr = [[DSECDSAKey keyWithPublicKey:pubKey] addressForChain:self.chain];
            
            if (! addr) {
                DSDLog(@"error generating keys");
                return nil;
            }
            
            if (!self.account.wallet.isTransient) {
                [self.moc performBlock:^{ // store new address in core data
                    [DSDerivationPathEntity setContext:self.moc];
                    DSDerivationPathEntity * derivationPathEntity = [DSDerivationPathEntity derivationPathEntityMatchingDerivationPath:self];
                    DSAddressEntity *e = [DSAddressEntity managedObject];
                    e.derivationPath = derivationPathEntity;
                    NSAssert([addr isValidDashAddressOnChain:self.chain], @"the address is being saved to the wrong derivation path");
                    e.address = addr;
                    e.index = n;
                    e.internal = internal;
                    e.standalone = NO;
                }];
            }
            
            [self.mAllAddresses addObject:addr];
            [(internal) ? self.internalAddresses : self.externalAddresses addObject:addr];
            [a addObject:addr];
            n++;
        }
        
        return a;
    }
}

- (NSArray *)addressesForExportWithInternalRange:(NSRange)exportInternalRange externalCount:(NSRange)exportExternalRange
{
    NSMutableArray * addresses = [NSMutableArray array];
    for (NSUInteger i = exportInternalRange.location;i<exportInternalRange.length + exportInternalRange.location;i++) {
        NSData *pubKey = [self publicKeyDataAtIndex:(uint32_t)i internal:YES];
        NSString *addr = [[DSECDSAKey keyWithPublicKey:pubKey] addressForChain:self.chain];
        [addresses addObject:addr];
    }
    
    for (NSUInteger i = exportExternalRange.location;i<exportExternalRange.location + exportExternalRange.length;i++) {
        NSData *pubKey = [self publicKeyDataAtIndex:(uint32_t)i internal:NO];
        NSString *addr = [[DSECDSAKey keyWithPublicKey:pubKey] addressForChain:self.chain];
        [addresses addObject:addr];
    }
    
    return [addresses copy];
}

// gets an address at an index path
- (NSString *)addressAtIndex:(uint32_t)index internal:(BOOL)internal
{
    NSData *pubKey = [self publicKeyDataAtIndex:index internal:internal];
    return [[DSECDSAKey keyWithPublicKey:pubKey] addressForChain:self.chain];
}

// returns the first unused external address
- (NSString *)receiveAddress
{
    //TODO: limit to 10,000 total addresses and utxos for practical usability with bloom filters
    NSString *addr = [self registerAddressesWithGapLimit:1 internal:NO].lastObject;
    return (addr) ? addr : self.externalAddresses.lastObject;
}

- (NSString *)receiveAddressAtOffset:(NSUInteger)offset
{
    //TODO: limit to 10,000 total addresses and utxos for practical usability with bloom filters
    NSString *addr = [self registerAddressesWithGapLimit:offset + 1 internal:NO].lastObject;
    return (addr) ? addr : self.externalAddresses.lastObject;
}

// returns the first unused internal address
- (NSString *)changeAddress
{
    //TODO: limit to 10,000 total addresses and utxos for practical usability with bloom filters
    return [self registerAddressesWithGapLimit:1 internal:YES].lastObject;
}

// all previously generated external addresses
- (NSArray *)allReceiveAddresses
{
    return [self.externalAddresses copy];
}

// all previously generated external addresses
- (NSArray *)allChangeAddresses
{
    return [self.internalAddresses copy];
}

-(NSArray *)usedReceiveAddresses {
    NSMutableSet *intersection = [NSMutableSet setWithArray:self.externalAddresses];
    [intersection intersectSet:self.mUsedAddresses];
    return [intersection allObjects];
}

-(NSArray *)usedChangeAddresses {
    NSMutableSet *intersection = [NSMutableSet setWithArray:self.internalAddresses];
    [intersection intersectSet:self.mUsedAddresses];
    return [intersection allObjects];
}

- (NSData *)publicKeyDataAtIndex:(uint32_t)n internal:(BOOL)internal
{
    NSUInteger indexes[] = {(internal ? 1 : 0),n};
    return [self publicKeyDataAtIndexPath:[NSIndexPath indexPathWithIndexes:indexes length:2]];
}

- (NSString *)privateKeyStringAtIndex:(uint32_t)n internal:(BOOL)internal fromSeed:(NSData *)seed
{
    return seed ? [self serializedPrivateKeys:@[@(n)] internal:internal fromSeed:seed].lastObject : nil;
}

- (NSArray *)serializedPrivateKeys:(NSArray *)n internal:(BOOL)internal fromSeed:(NSData *)seed
{
    NSMutableArray * mArray = [NSMutableArray array];
    for (NSNumber * index in n) {
        NSUInteger indexes[] = {(internal ? 1 : 0),index.unsignedIntValue};
        [mArray addObject:[NSIndexPath indexPathWithIndexes:indexes length:2]];
    }
    
    return [self serializedPrivateKeysAtIndexPaths:mArray fromSeed:seed];
}

- (NSIndexPath*)indexPathForAddress:(NSString*)address {
    if ([self.allChangeAddresses containsObject:address]) {
        NSUInteger indexes[] = {1,[self.allChangeAddresses indexOfObject:address]};
        return [NSIndexPath indexPathWithIndexes:indexes length:2];
    } else if ([self.allReceiveAddresses containsObject:address]) {
        NSUInteger indexes[] = {0,[self.allReceiveAddresses indexOfObject:address]};
        return [NSIndexPath indexPathWithIndexes:indexes length:2];
    }
    return nil;
}

@end
