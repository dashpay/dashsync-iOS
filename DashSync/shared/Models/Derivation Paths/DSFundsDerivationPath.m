//
//  DSFundsDerivationPath.m
//  DashSync
//
//  Created by Sam Westrich on 2/10/19.
//

#import "DSFundsDerivationPath.h"
#import "DSAccount.h"
#import "DSBlockchainIdentity.h"
#import "DSDashpayUserEntity+CoreDataClass.h"
#import "DSDerivationPath+Protected.h"
#import "DSKeyManager.h"
#import "DSLogger.h"
#import "NSError+Dash.h"

#define DERIVATION_PATH_IS_USED_KEY @"DERIVATION_PATH_IS_USED_KEY"

@interface DSFundsDerivationPath ()

@property (atomic, strong) NSMutableArray *internalAddresses, *externalAddresses;
@property (atomic, assign) BOOL isForFirstAccount;
@property (nonatomic, assign) BOOL hasKnownBalanceInternal;
@property (nonatomic, assign) BOOL checkedInitialHasKnownBalance;

@end

@implementation DSFundsDerivationPath

+ (instancetype _Nonnull)bip32DerivationPathForAccountNumber:(uint32_t)accountNumber onChain:(DSChain *)chain {
    UInt256 indexes[] = {uint256_from_long(accountNumber)};
    BOOL hardenedIndexes[] = {YES};
    return [self derivationPathWithIndexes:indexes hardened:hardenedIndexes length:1 type:DSDerivationPathType_ClearFunds signingAlgorithm:KeyKind_ECDSA reference:DSDerivationPathReference_BIP32 onChain:chain];
}
+ (instancetype _Nonnull)bip44DerivationPathForAccountNumber:(uint32_t)accountNumber onChain:(DSChain *)chain {
    UInt256 indexes[] = {uint256_from_long(44), uint256_from_long(chain_coin_type(chain.chainType)), uint256_from_long(accountNumber)};
    BOOL hardenedIndexes[] = {YES, YES, YES};
    return [self derivationPathWithIndexes:indexes hardened:hardenedIndexes length:3 type:DSDerivationPathType_ClearFunds signingAlgorithm:KeyKind_ECDSA reference:DSDerivationPathReference_BIP44 onChain:chain];
}
+ (instancetype _Nonnull)coinJoinDerivationPathForAccountNumber:(uint32_t)accountNumber onChain:(DSChain *)chain {
    UInt256 indexes[] = {uint256_from_long(FEATURE_PURPOSE), uint256_from_long((uint64_t) chain_coin_type(chain.chainType)), uint256_from_long(FEATURE_PURPOSE_COINJOIN), uint256_from_long(accountNumber)};
    BOOL hardenedIndexes[] = {YES, YES, YES, YES};
    return [self derivationPathWithIndexes:indexes hardened:hardenedIndexes length:4 type:DSDerivationPathType_AnonymousFunds signingAlgorithm:KeyKind_ECDSA reference:DSDerivationPathReference_CoinJoin onChain:chain];
}


- (instancetype)initWithIndexes:(const UInt256[])indexes hardened:(const BOOL[])hardenedIndexes length:(NSUInteger)length type:(DSDerivationPathType)type signingAlgorithm:(KeyKind)signingAlgorithm reference:(DSDerivationPathReference)reference onChain:(DSChain *)chain {
    if (!(self = [super initWithIndexes:indexes hardened:hardenedIndexes length:length type:type signingAlgorithm:signingAlgorithm reference:reference onChain:chain])) return nil;

    UInt256 lastIndex = indexes[length - 1];
    self.isForFirstAccount = uint256_is_zero(lastIndex);
    self.internalAddresses = [NSMutableArray array];
    self.externalAddresses = [NSMutableArray array];

    return self;
}

- (BOOL)shouldUseReducedGapLimit {
    if (!self.checkedInitialHasKnownBalance) {
        NSError *error = nil;
        uint64_t hasKnownBalance = getKeychainInt([self hasKnownBalanceUniqueIDString], &error);
        if (!error) {
            self.hasKnownBalanceInternal = hasKnownBalance ? TRUE : FALSE;
            self.checkedInitialHasKnownBalance = TRUE;
        }
    }
    return !self.hasKnownBalanceInternal && !(self.isForFirstAccount && self.reference == DSDerivationPathReference_BIP44);
}

- (void)setHasKnownBalance {
    if (!self.hasKnownBalanceInternal) {
        setKeychainInt(1, [self hasKnownBalanceUniqueIDString], NO);
        self.hasKnownBalanceInternal = TRUE;
    }
}

- (NSString *)hasKnownBalanceUniqueIDString {
    return [NSString stringWithFormat:@"%@_%@_%lu", DERIVATION_PATH_IS_USED_KEY, [self.account uniqueID], (unsigned long)self.reference];
}

- (void)reloadAddresses {
    self.internalAddresses = [NSMutableArray array];
    self.externalAddresses = [NSMutableArray array];
    [self.mUsedAddresses removeAllObjects];
    self.addressesLoaded = NO;
    [self loadAddresses];
}

- (void)loadAddresses {
    if (!self.addressesLoaded) {
        [self.managedObjectContext performBlockAndWait:^{
            DSDerivationPathEntity *derivationPathEntity = [DSDerivationPathEntity derivationPathEntityMatchingDerivationPath:self inContext:self.managedObjectContext];
            self.syncBlockHeight = derivationPathEntity.syncBlockHeight;
            for (DSAddressEntity *e in derivationPathEntity.addresses) {
                @autoreleasepool {
                    NSMutableArray *a = (e.internal) ? self.internalAddresses : self.externalAddresses;

                    while (e.index >= a.count) [a addObject:[NSNull null]];
                    if (![DSKeyManager isValidDashAddress:e.address forChain:self.account.wallet.chain]) {
#if DEBUG
                        DSLogPrivate(@"[%@] address %@ loaded but was not valid on chain", self.account.wallet.chain.name, e.address);
#else
                            DSLog(@"[%@] address %@ loaded but was not valid on chain %@", self.account.wallet.chain.name, @"<REDACTED>");
#endif /* DEBUG */
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
        NSUInteger gapLimit = 0;
        
        if (self.shouldUseReducedGapLimit) {
            gapLimit = SEQUENCE_UNUSED_GAP_LIMIT_INITIAL;
        } else if (self.type == DSDerivationPathType_AnonymousFunds) {
            gapLimit = SEQUENCE_GAP_LIMIT_INITIAL_COINJOIN;
        } else {
            gapLimit = SEQUENCE_GAP_LIMIT_INITIAL;
        }
        
        [self registerAddressesWithGapLimit:gapLimit internal:YES error:nil];
        [self registerAddressesWithGapLimit:gapLimit internal:NO error:nil];
    }
}

// MARK: - Derivation Path Addresses

- (BOOL)registerTransactionAddress:(NSString *_Nonnull)address {
    if ([self containsAddress:address]) {
        if (![self.mUsedAddresses containsObject:address]) {
            [self.mUsedAddresses addObject:address];
            if ([self.allChangeAddresses containsObject:address]) {
                [self registerAddressesWithGapLimit:SEQUENCE_GAP_LIMIT_INTERNAL internal:YES error:nil];
            } else {
                [self registerAddressesWithGapLimit:SEQUENCE_GAP_LIMIT_EXTERNAL internal:NO error:nil];
            }
        }
        return TRUE;
    }
    return FALSE;
}

// Wallets are composed of chains of addresses. Each chain is traversed until a gap of a certain number of addresses is
// found that haven't been used in any transactions. This method returns an array of <gapLimit> unused addresses
// following the last used address in the chain. The internal chain is used for change addresses and the external chain
// for receive addresses.
- (NSArray *)registerAddressesWithGapLimit:(NSUInteger)gapLimit internal:(BOOL)internal error:(NSError **)error {
    if (!self.account.wallet.isTransient && !self.addressesLoaded) {
        return @[];
    }
    
    @synchronized(self) {
        NSMutableArray *a = [NSMutableArray arrayWithArray:(internal) ? self.internalAddresses : self.externalAddresses];
        NSUInteger i = a.count;
        // keep only the trailing contiguous block of addresses with no transactions
        while (i > 0 && ![self.usedAddresses containsObject:a[i - 1]]) {
            i--;
        }

        if (i > 0) [a removeObjectsInRange:NSMakeRange(0, i)];
        if (a.count >= gapLimit) return [a subarrayWithRange:NSMakeRange(0, gapLimit)];

        if (gapLimit > 1) { // get receiveAddress and changeAddress first to avoid blocking
            [self receiveAddress];
            [self changeAddress];
        }

        //It seems weird to repeat this, but it's correct because of the original call receive address and change address
        [a setArray:(internal) ? self.internalAddresses : self.externalAddresses];
        i = a.count;

        unsigned n = (unsigned)i;

        // keep only the trailing contiguous block of addresses with no transactions
        while (i > 0 && ![self.usedAddresses containsObject:a[i - 1]]) {
            i--;
        }

        if (i > 0) [a removeObjectsInRange:NSMakeRange(0, i)];
        if (a.count >= gapLimit) return [a subarrayWithRange:NSMakeRange(0, gapLimit)];

        NSMutableDictionary *addAddresses = [NSMutableDictionary dictionary];

        while (a.count < gapLimit) { // generate new addresses up to gapLimit
            NSData *pubKey = [self publicKeyDataAtIndex:n internal:internal];
            NSString *addr = [DSKeyManager ecdsaKeyAddressFromPublicKeyData:pubKey forChainType:self.chain.chainType];

            if (!addr) {
                DSLog(@"[%@] error generating keys", self.account.wallet.chain.name);
                if (error) {
                    *error = [NSError errorWithCode:500 localizedDescriptionKey:@"Error generating public keys"];
                }
                return nil;
            }

            [self.mAllAddresses addObject:addr];
            [(internal) ? self.internalAddresses : self.externalAddresses addObject:addr];
            [a addObject:addr];
            [addAddresses setObject:addr forKey:@(n)];
            n++;
        }

        if (!self.account.wallet.isTransient) {
            [self.managedObjectContext performBlock:^{ // store new address in core data
                DSDerivationPathEntity *derivationPathEntity = [DSDerivationPathEntity derivationPathEntityMatchingDerivationPath:self inContext:self.managedObjectContext];
                for (NSNumber *number in addAddresses) {
                    NSString *address = [addAddresses objectForKey:number];
                    NSAssert([DSKeyManager isValidDashAddress:address forChain:self.chain], @"the address is being saved to the wrong derivation path");
                    DSAddressEntity *e = [DSAddressEntity managedObjectInContext:self.managedObjectContext];
                    e.derivationPath = derivationPathEntity;
                    e.address = address;
                    e.index = [number intValue];
                    e.internal = internal;
                    e.standalone = NO;
                }
                [self.managedObjectContext ds_save];
            }];
        }

        return a;
    }
}

- (NSArray *)addressesForExportWithInternalRange:(NSRange)exportInternalRange externalCount:(NSRange)exportExternalRange {
    NSMutableArray *addresses = [NSMutableArray array];
    for (NSUInteger i = exportInternalRange.location; i < exportInternalRange.length + exportInternalRange.location; i++) {
        NSData *pubKey = [self publicKeyDataAtIndex:(uint32_t)i internal:YES];
        NSString *addr = [DSKeyManager ecdsaKeyAddressFromPublicKeyData:pubKey forChainType:self.chain.chainType];
        [addresses addObject:addr];
    }

    for (NSUInteger i = exportExternalRange.location; i < exportExternalRange.location + exportExternalRange.length; i++) {
        NSData *pubKey = [self publicKeyDataAtIndex:(uint32_t)i internal:NO];
        NSString *addr = [DSKeyManager ecdsaKeyAddressFromPublicKeyData:pubKey forChainType:self.chain.chainType];
        [addresses addObject:addr];
    }

    return [addresses copy];
}

// gets an address at an index path
- (NSString *)addressAtIndex:(uint32_t)index internal:(BOOL)internal {
    NSData *pubKey = [self publicKeyDataAtIndex:index internal:internal];
    NSString *addr = [DSKeyManager ecdsaKeyAddressFromPublicKeyData:pubKey forChainType:self.chain.chainType];
    return addr;
}

// returns the first unused external address
- (NSString *)receiveAddress {
    //TODO: limit to 10,000 total addresses and utxos for practical usability with bloom filters
    NSString *addr = [self registerAddressesWithGapLimit:1 internal:NO error:nil].lastObject;
    return (addr) ? addr : self.allReceiveAddresses.lastObject;
}

- (NSString *)receiveAddressAtOffset:(NSUInteger)offset {
    //TODO: limit to 10,000 total addresses and utxos for practical usability with bloom filters
    NSString *addr = [self registerAddressesWithGapLimit:offset + 1 internal:NO error:nil].lastObject;
    return (addr) ? addr : self.allReceiveAddresses.lastObject;
}

// returns the first unused internal address
- (NSString *)changeAddress {
    //TODO: limit to 10,000 total addresses and utxos for practical usability with bloom filters
    return [self registerAddressesWithGapLimit:1 internal:YES error:nil].lastObject;
}

// all previously generated external addresses
- (NSArray *)allReceiveAddresses {
    return [self.externalAddresses copy];
}

// all previously generated external addresses
- (NSArray *)allChangeAddresses {
    return [self.internalAddresses copy];
}

// true if the address is controlled by the wallet
- (BOOL)containsChangeAddress:(NSString *)address {
    return address && [self.allChangeAddresses containsObject:address];
}

// true if the address is controlled by the wallet
- (BOOL)containsReceiveAddress:(NSString *)address {
    return address && [self.allReceiveAddresses containsObject:address];
}

- (NSArray *)usedReceiveAddresses {
    NSMutableSet *intersection = [NSMutableSet setWithArray:self.allReceiveAddresses];
    [intersection intersectSet:self.mUsedAddresses];
    return [intersection allObjects];
}

- (NSArray *)usedChangeAddresses {
    NSMutableSet *intersection = [NSMutableSet setWithArray:self.allChangeAddresses];
    [intersection intersectSet:self.mUsedAddresses];
    return [intersection allObjects];
}

- (NSData *)publicKeyDataAtIndex:(uint32_t)n internal:(BOOL)internal {
    NSUInteger indexes[] = {(internal ? 1 : 0), n};
    return [self publicKeyDataAtIndexPath:[NSIndexPath indexPathWithIndexes:indexes length:2]];
}

- (NSString *)privateKeyStringAtIndex:(uint32_t)n internal:(BOOL)internal fromSeed:(NSData *)seed {
    return seed ? [self serializedPrivateKeys:@[@(n)] internal:internal fromSeed:seed].lastObject : nil;
}

- (NSArray *)privateKeys:(NSArray *)n internal:(BOOL)internal fromSeed:(NSData *)seed {
    NSMutableArray *mArray = [NSMutableArray array];
    for (NSNumber *index in n) {
        NSUInteger indexes[] = {(internal ? 1 : 0), index.unsignedIntValue};
        [mArray addObject:[NSIndexPath indexPathWithIndexes:indexes length:2]];
    }

    return [self privateKeysAtIndexPaths:mArray fromSeed:seed];
}

- (NSArray *)serializedPrivateKeys:(NSArray *)n internal:(BOOL)internal fromSeed:(NSData *)seed {
    NSMutableArray *mArray = [NSMutableArray array];
    for (NSNumber *index in n) {
        NSUInteger indexes[] = {(internal ? 1 : 0), index.unsignedIntValue};
        [mArray addObject:[NSIndexPath indexPathWithIndexes:indexes length:2]];
    }

    return [self serializedPrivateKeysAtIndexPaths:mArray fromSeed:seed];
}

- (NSIndexPath *)indexPathForKnownAddress:(NSString *)address {
    if ([self.allChangeAddresses containsObject:address]) {
        NSUInteger indexes[] = {1, [self.allChangeAddresses indexOfObject:address]};
        return [NSIndexPath indexPathWithIndexes:indexes length:2];
    } else if ([self.allReceiveAddresses containsObject:address]) {
        NSUInteger indexes[] = {0, [self.allReceiveAddresses indexOfObject:address]};
        return [NSIndexPath indexPathWithIndexes:indexes length:2];
    }
    return nil;
}

@end
