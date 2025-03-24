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
#import "DSAddressEntity+CoreDataClass.h"
#import "DSIdentity.h"
#import "DSChainManager.h"
#import "DSChain+Params.h"
#import "DSDashpayUserEntity+CoreDataClass.h"
#import "DSDerivationPath+Protected.h"
#import "DSGapLimit.h"
#import "DSTxOutputEntity+CoreDataClass.h"
#import "NSError+Dash.h"
#import "NSManagedObject+Sugar.h"
#import "dash_spv_apple_bindings.h"

@interface DSIncomingFundsDerivationPath ()

@property (atomic, strong) NSMutableArray *externalAddresses;

@property (nonatomic, assign) UInt256 contactSourceIdentityUniqueId;
@property (nonatomic, assign) UInt256 contactDestinationIdentityUniqueId;

@end

@implementation DSIncomingFundsDerivationPath

+ (instancetype)contactBasedDerivationPathWithDestinationIdentityUniqueId:(UInt256)destinationIdentityUniqueId
                                                   sourceIdentityUniqueId:(UInt256)sourceIdentityUniqueId
                                                               forAccount:(DSAccount *)account
                                                                  onChain:(DSChain *)chain {
    NSAssert(!uint256_eq(sourceIdentityUniqueId, destinationIdentityUniqueId), @"source and destination must be different");
    UInt256 indexes[] = {uint256_from_long(FEATURE_PURPOSE), uint256_from_long((uint64_t) chain.coinType), uint256_from_long(FEATURE_PURPOSE_DASHPAY), uint256_from_long(account.accountNumber), sourceIdentityUniqueId, destinationIdentityUniqueId};
    BOOL hardenedIndexes[] = {YES, YES, YES, YES, NO, NO};
    //todo full uint256 derivation
    DSIncomingFundsDerivationPath *derivationPath = [self derivationPathWithIndexes:indexes
                                                                           hardened:hardenedIndexes
                                                                             length:6
                                                                               type:DSDerivationPathType_ClearFunds
                                                                   signingAlgorithm:DKeyKindECDSA()
                                                                          reference:DSDerivationPathReference_ContactBasedFunds
                                                                            onChain:chain];

    derivationPath.contactSourceIdentityUniqueId = sourceIdentityUniqueId;
    derivationPath.contactDestinationIdentityUniqueId = destinationIdentityUniqueId;
    derivationPath.account = account;
    return derivationPath;
}

+ (instancetype)externalDerivationPathWithExtendedPublicKey:(DMaybeOpaqueKey *)extendedPublicKey
                             withDestinationIdentityUniqueId:(UInt256)destinationIdentityUniqueId
                                     sourceIdentityUniqueId:(UInt256)sourceIdentityUniqueId
                                                    onChain:(DSChain *)chain {
    UInt256 indexes[] = {};
    BOOL hardenedIndexes[] = {};
    DSIncomingFundsDerivationPath *derivationPath = [[self alloc] initWithIndexes:indexes
                                                                         hardened:hardenedIndexes
                                                                           length:0
                                                                             type:DSDerivationPathType_ViewOnlyFunds
                                                                 signingAlgorithm:DKeyKindECDSA()
                                                                        reference:DSDerivationPathReference_ContactBasedFundsExternal
                                                                          onChain:chain]; //we are going to assume this is only ecdsa for now
    derivationPath.extendedPublicKey = extendedPublicKey;
    derivationPath.contactSourceIdentityUniqueId = sourceIdentityUniqueId;
    derivationPath.contactDestinationIdentityUniqueId = destinationIdentityUniqueId;
    return derivationPath;
}


+ (instancetype)externalDerivationPathWithExtendedPublicKeyUniqueID:(NSString *)extendedPublicKeyUniqueId
                                    withDestinationIdentityUniqueId:(UInt256)destinationIdentityUniqueId
                                             sourceIdentityUniqueId:(UInt256)sourceIdentityUniqueId
                                                            onChain:(DSChain *)chain {
    UInt256 indexes[] = {};
    BOOL hardenedIndexes[] = {};
    DSIncomingFundsDerivationPath *derivationPath = [[self alloc] initWithIndexes:indexes
                                                                         hardened:hardenedIndexes
                                                                           length:0
                                                                             type:DSDerivationPathType_ViewOnlyFunds
                                                                 signingAlgorithm:DKeyKindECDSA()
                                                                        reference:DSDerivationPathReference_ContactBasedFundsExternal
                                                                          onChain:chain]; //we are going to assume this is only ecdsa for now
    derivationPath.standaloneExtendedPublicKeyUniqueID = extendedPublicKeyUniqueId;

    derivationPath.contactSourceIdentityUniqueId = sourceIdentityUniqueId;
    derivationPath.contactDestinationIdentityUniqueId = destinationIdentityUniqueId;
    return derivationPath;
}

- (instancetype)initWithIndexes:(const UInt256[])indexes
                       hardened:(const BOOL[])hardenedIndexes
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
            for (DSAddressEntity *e in derivationPathEntity.addresses) {
                @autoreleasepool {
                    NSMutableArray *a = self.externalAddresses;

                    while (e.index >= a.count)
                        [a addObject:[NSNull null]];
                    if (!DIsValidDashAddress(DChar(e.address), self.chain.chainType)) {
    #if DEBUG
                        DSLogPrivate(@"[%@] address %@ loaded but was not valid on chain", self.chain.name, e.address);
    #else
                            DSLog(@"[%@] address %@ loaded but was not valid on chain", self.chain.name, @"<REDACTED>");
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
        [self registerAddressesWithSettings:[DSGapLimit withLimit:SEQUENCE_DASHPAY_GAP_LIMIT_INITIAL] inContext:context];
    }
}

- (NSUInteger)accountNumber {
    return [self indexAtPosition:[self length] - 3].u64[0] & ~BIP32_HARD;
}

// MARK: - Derivation Path Addresses

- (BOOL)registerTransactionAddress:(NSString *_Nonnull)address {
    if ([self containsAddress:address]) {
        if (![self.mUsedAddresses containsObject:address]) {
            [self.mUsedAddresses addObject:address];
            [self registerAddressesWithSettings:[DSGapLimit withLimit:SEQUENCE_GAP_LIMIT_EXTERNAL]];
        }
        return TRUE;
    }
    return FALSE;
}


- (NSString *)createIdentifierForDerivationPath {
    return [NSString stringWithFormat:@"%@-%@-%@",
            uint256_data(_contactSourceIdentityUniqueId).shortHexString,
            uint256_data(_contactDestinationIdentityUniqueId).shortHexString,
            [super createIdentifierForDerivationPath]
    ];
}

// Wallets are composed of chains of addresses. Each chain is traversed until a gap of a certain number of addresses is
// found that haven't been used in any transactions. This method returns an array of <gapLimit> unused addresses
// following the last used address in the chain. The internal chain is used for change addresses and the external chain
// for receive addresses.
- (NSArray *)registerAddressesWithSettings:(DSGapLimit *)settings
                                 inContext:(NSManagedObjectContext *)context {
    uintptr_t gapLimit = settings.gapLimit;
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
            NSData *pubKey = [self publicKeyDataAtIndexPath:[NSIndexPath indexPathWithIndexes:(const NSUInteger[]){n} length:1]];
            NSString *address = [DSKeyManager ecdsaKeyAddressFromPublicKeyData:pubKey forChainType:self.chain.chainType];
            if (!address) {
                DSLog(@"[%@] error generating keys", self.chain.name);
                return nil;
            }

            if (!self.account.wallet.isTransient) {
                BOOL isUsed = [self storeNewAddressInContext:address atIndex:n context:context];
                if (isUsed) {
                    [self.mUsedAddresses addObject:address];
                    upperLimit++;
                }
            }
            [self.mAllAddresses addObject:address];
            [self.externalAddresses addObject:address];
            [a addObject:address];
            n++;
        }

        return a;
    }
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
    NSString *addr = [self registerAddressesWithSettings:[DSGapLimit withLimit:offset + 1] inContext:context].lastObject;
    return addr ?: self.allReceiveAddresses.lastObject;
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

- (NSIndexPath *)indexPathForKnownAddress:(NSString *)address {
    if ([self.allReceiveAddresses containsObject:address]) {
        NSUInteger indexes[] = {[self.allReceiveAddresses indexOfObject:address]};
        return [NSIndexPath indexPathWithIndexes:indexes length:1];
    }
    return nil;
}


- (BOOL)storeNewAddressInContext:(NSString *)address
                         atIndex:(uint32_t)n
                         context:(NSManagedObjectContext *)context {
    __block BOOL isUsed = FALSE;
    [context performBlockAndWait:^{ // store new address in core data
        DSDerivationPathEntity *derivationPathEntity = [DSDerivationPathEntity derivationPathEntityMatchingDerivationPath:self inContext:context];
        DSAddressEntity *e = [DSAddressEntity managedObjectInContext:context];
        e.derivationPath = derivationPathEntity;
        NSAssert(DIsValidDashAddress(DChar(address), self.chain.chainType), @"the address is being saved to the wrong derivation path");
        e.address = address;
        e.index = n;
        e.internal = NO;
        e.standalone = NO;
        NSArray *outputs = [DSTxOutputEntity objectsInContext:context matching:@"address == %@", address];
        [e addUsedInOutputs:[NSSet setWithArray:outputs]];
        if (outputs.count) isUsed = TRUE;
    }];
    return isUsed;
}


@end
