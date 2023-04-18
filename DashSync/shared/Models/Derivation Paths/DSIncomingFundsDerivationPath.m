//
//  Created by Sam Westrich
//  Copyright © 2019 Dash Core Group. All rights reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://opensource.org/licenses/MIT
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "DSIncomingFundsDerivationPath.h"
#import "DSAccount.h"
#import "DSBlockchainIdentity.h"
#import "DSChainManager.h"
#import "DSDashpayUserEntity+CoreDataClass.h"
#import "DSDerivationPath+Protected.h"
#import "NSError+Dash.h"
#import "dash_shared_core.h"

@interface DSIncomingFundsDerivationPath ()

@property (atomic, strong) NSMutableArray *externalAddresses;

@property (nonatomic, assign) UInt256 contactSourceBlockchainIdentityUniqueId;
@property (nonatomic, assign) UInt256 contactDestinationBlockchainIdentityUniqueId;
@property (nonatomic, assign) BOOL externalDerivationPath;

@end

@implementation DSIncomingFundsDerivationPath

+ (instancetype)contactBasedDerivationPathWithDestinationBlockchainIdentityUniqueId:(UInt256)destinationBlockchainIdentityUniqueId sourceBlockchainIdentityUniqueId:(UInt256)sourceBlockchainIdentityUniqueId forAccountNumber:(uint32_t)accountNumber onChain:(DSChain *)chain {
    NSAssert(!uint256_eq(sourceBlockchainIdentityUniqueId, destinationBlockchainIdentityUniqueId), @"source and destination must be different");
    UInt256 indexes[] = {uint256_from_long(FEATURE_PURPOSE), uint256_from_long((uint64_t) chain_coin_type(chain.chainType)), uint256_from_long(FEATURE_PURPOSE_DASHPAY), uint256_from_long(accountNumber), sourceBlockchainIdentityUniqueId, destinationBlockchainIdentityUniqueId};
    BOOL hardenedIndexes[] = {YES, YES, YES, YES, NO, NO};
    //todo full uint256 derivation
    DSIncomingFundsDerivationPath *derivationPath = [self derivationPathWithIndexes:indexes hardened:hardenedIndexes length:6 type:DSDerivationPathType_ClearFunds signingAlgorithm:KeyKind_ECDSA reference:DSDerivationPathReference_ContactBasedFunds onChain:chain];

    derivationPath.contactSourceBlockchainIdentityUniqueId = sourceBlockchainIdentityUniqueId;
    derivationPath.contactDestinationBlockchainIdentityUniqueId = destinationBlockchainIdentityUniqueId;

    return derivationPath;
}

+ (instancetype)externalDerivationPathWithExtendedPublicKey:(OpaqueKey *)extendedPublicKey
                  withDestinationBlockchainIdentityUniqueId:(UInt256)destinationBlockchainIdentityUniqueId
                           sourceBlockchainIdentityUniqueId:(UInt256)sourceBlockchainIdentityUniqueId
                                                    onChain:(DSChain *)chain {
    UInt256 indexes[] = {};
    BOOL hardenedIndexes[] = {};
    DSIncomingFundsDerivationPath *derivationPath = [[self alloc] initWithIndexes:indexes hardened:hardenedIndexes length:0 type:DSDerivationPathType_ViewOnlyFunds signingAlgorithm:KeyKind_ECDSA reference:DSDerivationPathReference_ContactBasedFundsExternal onChain:chain]; //we are going to assume this is only ecdsa for now
    derivationPath.extendedPublicKey = extendedPublicKey;

    derivationPath.contactSourceBlockchainIdentityUniqueId = sourceBlockchainIdentityUniqueId;
    derivationPath.contactDestinationBlockchainIdentityUniqueId = destinationBlockchainIdentityUniqueId;
    derivationPath.externalDerivationPath = TRUE;
    return derivationPath;
}

+ (instancetype)externalDerivationPathWithExtendedPublicKeyUniqueID:(NSString *)extendedPublicKeyUniqueId withDestinationBlockchainIdentityUniqueId:(UInt256)destinationBlockchainIdentityUniqueId sourceBlockchainIdentityUniqueId:(UInt256)sourceBlockchainIdentityUniqueId onChain:(DSChain *)chain {
    UInt256 indexes[] = {};
    BOOL hardenedIndexes[] = {};
    DSIncomingFundsDerivationPath *derivationPath = [[self alloc] initWithIndexes:indexes hardened:hardenedIndexes length:0 type:DSDerivationPathType_ViewOnlyFunds signingAlgorithm:KeyKind_ECDSA reference:DSDerivationPathReference_ContactBasedFundsExternal onChain:chain]; //we are going to assume this is only ecdsa for now
    derivationPath.standaloneExtendedPublicKeyUniqueID = extendedPublicKeyUniqueId;

    derivationPath.contactSourceBlockchainIdentityUniqueId = sourceBlockchainIdentityUniqueId;
    derivationPath.contactDestinationBlockchainIdentityUniqueId = destinationBlockchainIdentityUniqueId;
    derivationPath.externalDerivationPath = TRUE;
    return derivationPath;
}

- (instancetype)initWithIndexes:(const UInt256[])indexes hardened:(const BOOL[])hardenedIndexes length:(NSUInteger)length type:(DSDerivationPathType)type signingAlgorithm:(KeyKind)signingAlgorithm reference:(DSDerivationPathReference)reference onChain:(DSChain *)chain {
    if (!(self = [super initWithIndexes:indexes hardened:hardenedIndexes length:length type:type signingAlgorithm:signingAlgorithm reference:reference onChain:chain])) return nil;

    self.externalAddresses = [NSMutableArray array];

    return self;
}

- (void)storeExternalDerivationPathExtendedPublicKeyToKeyChain {
    NSAssert(self.extendedPublicKeyData != nil, @"the extended public key must exist");
    setKeychainData(self.extendedPublicKeyData, self.standaloneExtendedPublicKeyLocationString, NO);
}

- (void)reloadAddresses {
    self.externalAddresses = [NSMutableArray array];
    [self.mUsedAddresses removeAllObjects];
    self.addressesLoaded = NO;
    [self loadAddresses];
}

- (void)loadAddresses {
    [self loadAddressesInContext:self.managedObjectContext];
}

- (void)loadAddressesInContext:(NSManagedObjectContext *)context {
    if (!self.addressesLoaded) {
        [context performBlockAndWait:^{
            DSDerivationPathEntity *derivationPathEntity = [DSDerivationPathEntity derivationPathEntityMatchingDerivationPath:self inContext:context];
            self.syncBlockHeight = derivationPathEntity.syncBlockHeight;
            for (DSAddressEntity *e in derivationPathEntity.addresses) {
                @autoreleasepool {
                    NSMutableArray *a = self.externalAddresses;

                    while (e.index >= a.count) [a addObject:[NSNull null]];
                    if (![DSKeyManager isValidDashAddress:e.address forChain:self.account.wallet.chain]) {
#if DEBUG
                        DSLogPrivate(@"address %@ loaded but was not valid on chain %@", e.address, self.account.wallet.chain.name);
#else
                            DSLog(@"address %@ loaded but was not valid on chain %@", @"<REDACTED>", self.account.wallet.chain.name);
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
        [self registerAddressesWithGapLimit:SEQUENCE_DASHPAY_GAP_LIMIT_INITIAL inContext:context error:nil];
    }
}

- (NSUInteger)accountNumber {
    return [self indexAtPosition:[self length] - 3].u64[0] & ~BIP32_HARD;
}

- (BOOL)sourceIsLocal {
    return !![self.chain blockchainIdentityForUniqueId:self.contactSourceBlockchainIdentityUniqueId];
}

- (BOOL)destinationIsLocal {
    return !![self.chain blockchainIdentityForUniqueId:self.contactDestinationBlockchainIdentityUniqueId];
}

// MARK: - Derivation Path Addresses

- (BOOL)registerTransactionAddress:(NSString *_Nonnull)address {
    if ([self containsAddress:address]) {
        if (![self.mUsedAddresses containsObject:address]) {
            [self.mUsedAddresses addObject:address];
            [self registerAddressesWithGapLimit:SEQUENCE_GAP_LIMIT_EXTERNAL error:nil];
        }
        return TRUE;
    }
    return FALSE;
}


- (NSString *)createIdentifierForDerivationPath {
    return [NSString stringWithFormat:@"%@-%@-%@", [NSData dataWithUInt256:_contactSourceBlockchainIdentityUniqueId].shortHexString, [NSData dataWithUInt256:_contactDestinationBlockchainIdentityUniqueId].shortHexString, [NSData dataWithUInt256:[[self extendedPublicKeyData] SHA256]].shortHexString];
}

- (NSArray *)registerAddressesWithGapLimit:(NSUInteger)gapLimit error:(NSError **)error {
    return [self registerAddressesWithGapLimit:gapLimit inContext:self.managedObjectContext error:error];
}

// Wallets are composed of chains of addresses. Each chain is traversed until a gap of a certain number of addresses is
// found that haven't been used in any transactions. This method returns an array of <gapLimit> unused addresses
// following the last used address in the chain. The internal chain is used for change addresses and the external chain
// for receive addresses.
- (NSArray *)registerAddressesWithGapLimit:(NSUInteger)gapLimit inContext:(NSManagedObjectContext *)context error:(NSError **)error {
    NSAssert(self.account, @"Account must be set");
    if (!self.account.wallet.isTransient) {
        if (!self.addressesLoaded) {
            sleep(1); //quite hacky, we need to fix this
        }
        NSAssert(self.addressesLoaded, @"addresses must be loaded before calling this function");
    }

    NSMutableArray *a = [NSMutableArray arrayWithArray:self.externalAddresses];
    NSUInteger i = a.count;

    // keep only the trailing contiguous block of addresses with no transactions
    while (i > 0 && ![self.usedAddresses containsObject:a[i - 1]]) {
        i--;
    }

    if (i > 0) [a removeObjectsInRange:NSMakeRange(0, i)];
    if (a.count >= gapLimit) return [a subarrayWithRange:NSMakeRange(0, gapLimit)];

    if (gapLimit > 1) { // get receiveAddress and changeAddress first to avoid blocking
        [self receiveAddressInContext:context];
    }

    @synchronized(self) {
        //It seems weird to repeat this, but it's correct because of the original call receive address and change address
        [a setArray:self.externalAddresses];
        i = a.count;

        unsigned n = (unsigned)i;

        // keep only the trailing contiguous block of addresses with no transactions
        while (i > 0 && ![self.usedAddresses containsObject:a[i - 1]]) {
            i--;
        }

        if (i > 0) [a removeObjectsInRange:NSMakeRange(0, i)];
        if (a.count >= gapLimit) return [a subarrayWithRange:NSMakeRange(0, gapLimit)];

        NSUInteger upperLimit = gapLimit;
        while (a.count < upperLimit) { // generate new addresses up to gapLimit
            NSString *address = [self addressAtIndex:n];
            if (!address) {
                DSLog(@"error generating keys");
                if (error) {
                    *error = [NSError errorWithCode:500 localizedDescriptionKey:@"Error generating public keys"];
                }
                return nil;
            }

            __block BOOL isUsed = FALSE;

            if (!self.account.wallet.isTransient) {
                [context performBlockAndWait:^{ // store new address in core data
                    DSDerivationPathEntity *derivationPathEntity = [DSDerivationPathEntity derivationPathEntityMatchingDerivationPath:self inContext:context];
                    DSAddressEntity *e = [DSAddressEntity managedObjectInContext:context];
                    e.derivationPath = derivationPathEntity;
                    NSAssert([DSKeyManager isValidDashAddress:address forChain:self.chain], @"the address is being saved to the wrong derivation path");
                    e.address = address;
                    e.index = n;
                    e.internal = NO;
                    e.standalone = NO;
                    NSArray *outputs = [DSTxOutputEntity objectsInContext:context matching:@"address == %@", address];
                    [e addUsedInOutputs:[NSSet setWithArray:outputs]];
                    if (outputs.count) isUsed = TRUE;
                }];
            }
            if (isUsed) {
                [self.mUsedAddresses addObject:address];
                upperLimit++;
            }
            [self.mAllAddresses addObject:address];
            [self.externalAddresses addObject:address];
            [a addObject:address];
            n++;
        }

        return a;
    }
}

// gets an address at an index path
- (NSString *)addressAtIndex:(uint32_t)index {
    NSData *pubKey = [self publicKeyDataAtIndex:index];
    return [DSKeyManager ecdsaKeyAddressFromPublicKeyData:pubKey forChainType:self.chain.chainType];
}

// returns the first unused external address
- (NSString *)receiveAddress {
    return [self receiveAddressInContext:self.managedObjectContext];
}

- (NSString *)receiveAddressInContext:(NSManagedObjectContext *)context {
    return [self receiveAddressAtOffset:0 inContext:context];
}

- (NSString *)receiveAddressAtOffset:(NSUInteger)offset {
    return [self receiveAddressAtOffset:offset inContext:self.managedObjectContext];
}

- (NSString *)receiveAddressAtOffset:(NSUInteger)offset inContext:(NSManagedObjectContext *)context {
    //TODO: limit to 10,000 total addresses and utxos for practical usability with bloom filters
    NSString *addr = [self registerAddressesWithGapLimit:offset + 1 inContext:context error:nil].lastObject;
    return (addr) ? addr : self.allReceiveAddresses.lastObject;
}

// all previously generated external addresses
- (NSArray *)allReceiveAddresses {
    return [self.externalAddresses copy];
}

- (NSArray *)usedReceiveAddresses {
    NSMutableSet *intersection = [NSMutableSet setWithArray:self.allReceiveAddresses];
    [intersection intersectSet:self.mUsedAddresses];
    return [intersection allObjects];
}

- (NSData *)publicKeyDataAtIndex:(uint32_t)n {
    NSUInteger indexes[] = {n};
    return [self publicKeyDataAtIndexPath:[NSIndexPath indexPathWithIndexes:indexes length:1]];
}

- (NSString *)privateKeyStringAtIndex:(uint32_t)n fromSeed:(NSData *)seed {
    return seed ? [self serializedPrivateKeys:@[@(n)] fromSeed:seed].lastObject : nil;
}

- (NSArray *)privateKeys:(NSArray *)n fromSeed:(NSData *)seed {
    NSMutableArray *mArray = [NSMutableArray array];
    for (NSNumber *index in n) {
        NSUInteger indexes[] = {index.unsignedIntValue};
        [mArray addObject:[NSIndexPath indexPathWithIndexes:indexes length:1]];
    }

    return [self privateKeysAtIndexPaths:mArray fromSeed:seed];
}

- (NSArray *)serializedPrivateKeys:(NSArray *)n fromSeed:(NSData *)seed {
    NSMutableArray *mArray = [NSMutableArray array];
    for (NSNumber *index in n) {
        NSUInteger indexes[] = {index.unsignedIntValue};
        [mArray addObject:[NSIndexPath indexPathWithIndexes:indexes length:1]];
    }

    return [self serializedPrivateKeysAtIndexPaths:mArray fromSeed:seed];
}

- (NSIndexPath *)indexPathForKnownAddress:(NSString *)address {
    if ([self.allReceiveAddresses containsObject:address]) {
        NSUInteger indexes[] = {[self.allReceiveAddresses indexOfObject:address]};
        return [NSIndexPath indexPathWithIndexes:indexes length:1];
    }
    return nil;
}


- (DSBlockchainIdentity *)contactSourceBlockchainIdentity {
    return [self.chain blockchainIdentityForUniqueId:self.contactSourceBlockchainIdentityUniqueId foundInWallet:nil includeForeignBlockchainIdentities:YES];
}

- (DSBlockchainIdentity *)contactDestinationBlockchainIdentity {
    return [self.chain blockchainIdentityForUniqueId:self.contactDestinationBlockchainIdentityUniqueId foundInWallet:nil includeForeignBlockchainIdentities:YES];
}

@end
