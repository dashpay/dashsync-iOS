//
//  DSAuthenticationKeysDerivationPath.m
//  DashSync
//
//  Created by Sam Westrich on 2/10/19.
//

#import "DSAuthenticationKeysDerivationPath.h"
#import "DSCreditFundingDerivationPath.h"
#import "DSDerivationPathFactory.h"
#import "DSSimpleIndexedDerivationPath+Protected.h"
#import "NSError+Dash.h"

@interface DSAuthenticationKeysDerivationPath ()

@property (nonatomic, assign) BOOL shouldStoreExtendedPrivateKey;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSMutableArray *> *addressesByIdentity;
@property (nonatomic, assign) BOOL usesHardenedKeys;

@end

@implementation DSAuthenticationKeysDerivationPath

+ (instancetype)providerVotingKeysDerivationPathForWallet:(DSWallet *)wallet {
    return [[DSDerivationPathFactory sharedInstance] providerVotingKeysDerivationPathForWallet:wallet];
}
+ (instancetype)providerOwnerKeysDerivationPathForWallet:(DSWallet *)wallet {
    return [[DSDerivationPathFactory sharedInstance] providerOwnerKeysDerivationPathForWallet:wallet];
}
+ (instancetype)providerOperatorKeysDerivationPathForWallet:(DSWallet *)wallet {
    return [[DSDerivationPathFactory sharedInstance] providerOperatorKeysDerivationPathForWallet:wallet];
}
+ (instancetype)blockchainIdentitiesBLSKeysDerivationPathForWallet:(DSWallet *)wallet {
    return [[DSDerivationPathFactory sharedInstance] blockchainIdentityBLSKeysDerivationPathForWallet:wallet];
}
+ (instancetype)blockchainIdentitiesECDSAKeysDerivationPathForWallet:(DSWallet *)wallet {
    return [[DSDerivationPathFactory sharedInstance] blockchainIdentityECDSAKeysDerivationPathForWallet:wallet];
}

- (NSUInteger)defaultGapLimit {
    return 10;
}

- (instancetype)initWithIndexes:(const UInt256[_Nullable])indexes hardened:(const BOOL[_Nullable])hardenedIndexes length:(NSUInteger)length
                           type:(DSDerivationPathType)type
               signingAlgorithm:(DSKeyType)signingAlgorithm
                      reference:(DSDerivationPathReference)reference
                        onChain:(DSChain *)chain {
    DSAuthenticationKeysDerivationPath *authenticationKeysDerivationPath = [super initWithIndexes:indexes hardened:hardenedIndexes length:length type:type signingAlgorithm:signingAlgorithm reference:reference onChain:chain];
    authenticationKeysDerivationPath.shouldStoreExtendedPrivateKey = NO;
    self.addressesByIdentity = [NSMutableDictionary dictionary];
    return authenticationKeysDerivationPath;
}

+ (instancetype _Nullable)derivationPathWithIndexes:(const UInt256[_Nullable])indexes hardened:(const BOOL[_Nullable])hardenedIndexes length:(NSUInteger)length
                                               type:(DSDerivationPathType)type
                                   signingAlgorithm:(DSKeyType)signingAlgorithm
                                          reference:(DSDerivationPathReference)reference
                                            onChain:(DSChain *)chain {
    DSAuthenticationKeysDerivationPath *derivationPath = [super derivationPathWithIndexes:indexes hardened:hardenedIndexes length:length type:type signingAlgorithm:signingAlgorithm reference:reference onChain:chain];
    derivationPath.shouldStoreExtendedPrivateKey = NO;
    return derivationPath;
}

+ (instancetype)providerVotingKeysDerivationPathForChain:(DSChain *)chain {
    NSUInteger coinType = (chain.chainType == DSChainType_MainNet) ? 5 : 1;
    UInt256 indexes[] = {uint256_from_long(FEATURE_PURPOSE), uint256_from_long(coinType), uint256_from_long(3), uint256_from_long(1)};
    BOOL hardenedIndexes[] = {YES, YES, YES, YES};
    return [DSAuthenticationKeysDerivationPath derivationPathWithIndexes:indexes hardened:hardenedIndexes length:4 type:DSDerivationPathType_SingleUserAuthentication signingAlgorithm:DSKeyType_ECDSA reference:DSDerivationPathReference_ProviderVotingKeys onChain:chain];
}

+ (instancetype)providerOwnerKeysDerivationPathForChain:(DSChain *)chain {
    NSUInteger coinType = (chain.chainType == DSChainType_MainNet) ? 5 : 1;
    UInt256 indexes[] = {uint256_from_long(FEATURE_PURPOSE), uint256_from_long(coinType), uint256_from_long(3), uint256_from_long(2)};
    BOOL hardenedIndexes[] = {YES, YES, YES, YES};
    return [DSAuthenticationKeysDerivationPath derivationPathWithIndexes:indexes hardened:hardenedIndexes length:4 type:DSDerivationPathType_SingleUserAuthentication signingAlgorithm:DSKeyType_ECDSA reference:DSDerivationPathReference_ProviderOwnerKeys onChain:chain];
}

+ (instancetype)providerOperatorKeysDerivationPathForChain:(DSChain *)chain {
    NSUInteger coinType = (chain.chainType == DSChainType_MainNet) ? 5 : 1;
    UInt256 indexes[] = {uint256_from_long(FEATURE_PURPOSE), uint256_from_long(coinType), uint256_from_long(3), uint256_from_long(3)};
    BOOL hardenedIndexes[] = {YES, YES, YES, YES};
    return [DSAuthenticationKeysDerivationPath derivationPathWithIndexes:indexes hardened:hardenedIndexes length:4 type:DSDerivationPathType_SingleUserAuthentication signingAlgorithm:DSKeyType_BLS reference:DSDerivationPathReference_ProviderOperatorKeys onChain:chain];
}

+ (instancetype)blockchainIdentityECDSAKeysDerivationPathForChain:(DSChain *)chain {
    NSUInteger coinType = (chain.chainType == DSChainType_MainNet) ? 5 : 1;
    UInt256 indexes[] = {uint256_from_long(FEATURE_PURPOSE), uint256_from_long(coinType), uint256_from_long(FEATURE_PURPOSE_IDENTITIES), uint256_from_long(FEATURE_PURPOSE_IDENTITIES_SUBFEATURE_AUTHENTICATION), uint256_from_long(0)};
    BOOL hardenedIndexes[] = {YES, YES, YES, YES, YES};
    DSAuthenticationKeysDerivationPath *blockchainIdentityECDSAKeysDerivationPath = [DSAuthenticationKeysDerivationPath derivationPathWithIndexes:indexes hardened:hardenedIndexes length:5 type:DSDerivationPathType_MultipleUserAuthentication signingAlgorithm:DSKeyType_ECDSA reference:DSDerivationPathReference_BlockchainIdentities onChain:chain];
    blockchainIdentityECDSAKeysDerivationPath.shouldStoreExtendedPrivateKey = YES;
    blockchainIdentityECDSAKeysDerivationPath.usesHardenedKeys = YES;
    return blockchainIdentityECDSAKeysDerivationPath;
}

+ (instancetype)blockchainIdentityBLSKeysDerivationPathForChain:(DSChain *)chain {
    NSUInteger coinType = (chain.chainType == DSChainType_MainNet) ? 5 : 1;
    UInt256 indexes[] = {uint256_from_long(FEATURE_PURPOSE), uint256_from_long(coinType), uint256_from_long(FEATURE_PURPOSE_IDENTITIES), uint256_from_long(FEATURE_PURPOSE_IDENTITIES_SUBFEATURE_AUTHENTICATION), uint256_from_long(1)};
    BOOL hardenedIndexes[] = {YES, YES, YES, YES, YES};
    DSAuthenticationKeysDerivationPath *blockchainIdentityBLSKeysDerivationPath = [DSAuthenticationKeysDerivationPath derivationPathWithIndexes:indexes hardened:hardenedIndexes length:5 type:DSDerivationPathType_MultipleUserAuthentication signingAlgorithm:DSKeyType_BLS reference:DSDerivationPathReference_BlockchainIdentities onChain:chain];
    blockchainIdentityBLSKeysDerivationPath.shouldStoreExtendedPrivateKey = YES;
    blockchainIdentityBLSKeysDerivationPath.usesHardenedKeys = YES;
    return blockchainIdentityBLSKeysDerivationPath;
}

- (void)loadAddresses {
    @synchronized(self) {
        if (!self.addressesLoaded) {
            [self.managedObjectContext performBlockAndWait:^{
                DSDerivationPathEntity *derivationPathEntity = [DSDerivationPathEntity derivationPathEntityMatchingDerivationPath:self inContext:self.managedObjectContext];
                self.syncBlockHeight = derivationPathEntity.syncBlockHeight;
                NSArray<DSAddressEntity *> *addresses = [derivationPathEntity.addresses sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"index" ascending:YES]]];
                for (DSAddressEntity *e in addresses) {
                    @autoreleasepool {
                        while (e.index >= self.mOrderedAddresses.count) [self.mOrderedAddresses addObject:[NSNull null]];
                        if (![e.address isValidDashAddressOnChain:self.wallet.chain]) {
#if DEBUG
                            DSLogPrivate(@"address %@ loaded but was not valid on chain %@", e.address, self.wallet.chain.name);
#else
                                DSLog(@"address %@ loaded but was not valid on chain %@", @"<REDACTED>", self.wallet.chain.name);
#endif
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
            if ([self type] == DSDerivationPathType_SingleUserAuthentication) {
                [self registerAddressesWithGapLimit:10 error:nil];
            } else {
                [self registerAddressesWithGapLimit:10 forIdentityIndex:0 error:nil];
            }
        }
    }
}


- (NSArray *)registerAddressesWithGapLimit:(NSUInteger)gapLimit forIdentityIndex:(uint32_t)identityIndex error:(NSError **)error {
    if (!self.account.wallet.isTransient) {
        NSAssert(self.addressesLoaded, @"addresses must be loaded before calling this function");
    }
    NSAssert(self.type != DSDerivationPathType_SingleUserAuthentication, @"This should not be called for single user authentication. Use '- (NSArray *)registerAddressesWithGapLimit:(NSUInteger)gapLimit error:(NSError**)error' instead.");

    if (self.usesHardenedKeys && !self.hasExtendedPrivateKey) {
        return [NSArray array];
    }

    if (![self.addressesByIdentity objectForKey:@(identityIndex)]) {
        [self.addressesByIdentity setObject:[NSMutableArray array] forKey:@(identityIndex)];
    }

    NSMutableArray *a = [NSMutableArray arrayWithArray:[self.addressesByIdentity objectForKey:@(identityIndex)]];
    NSUInteger i = a.count;

    // keep only the trailing contiguous block of addresses with no transactions
    while (i > 0 && ![self.usedAddresses containsObject:a[i - 1]]) {
        i--;
    }

    if (i > 0) [a removeObjectsInRange:NSMakeRange(0, i)];
    if (a.count >= gapLimit) return [a subarrayWithRange:NSMakeRange(0, gapLimit)];

    @synchronized(self) {
        //It seems weird to repeat this, but it's correct because of the original call receive address and change address
        [a setArray:[self.addressesByIdentity objectForKey:@(identityIndex)]];
        i = a.count;

        unsigned n = (unsigned)i;

        // keep only the trailing contiguous block of addresses with no transactions
        while (i > 0 && ![self.usedAddresses containsObject:a[i - 1]]) {
            i--;
        }

        if (i > 0) [a removeObjectsInRange:NSMakeRange(0, i)];
        if (a.count >= gapLimit) return [a subarrayWithRange:NSMakeRange(0, gapLimit)];

        while (a.count < gapLimit) { // generate new addresses up to gapLimit
            const NSUInteger hardenedIndexes[] = {identityIndex | BIP32_HARD, n | BIP32_HARD};
            const NSUInteger softIndexes[] = {identityIndex, n};
            const NSUInteger *indexes = self.usesHardenedKeys ? hardenedIndexes : softIndexes;
            NSData *pubKey = [self publicKeyDataAtIndexPath:[NSIndexPath indexPathWithIndexes:indexes length:2]];
            NSString *addr = [[DSKey keyWithPublicKeyData:pubKey forKeyType:self.signingAlgorithm] addressForChain:self.chain];

            if (!addr) {
                DSLog(@"error generating keys");
                if (error) {
                    *error = [NSError errorWithCode:500 localizedDescriptionKey:@"Error generating public keys"];
                }
                return nil;
            }

            if (!self.account.wallet.isTransient) {
                [self.managedObjectContext performBlock:^{ // store new address in core data
                    DSDerivationPathEntity *derivationPathEntity = [DSDerivationPathEntity derivationPathEntityMatchingDerivationPath:self inContext:self.managedObjectContext];
                    DSAddressEntity *e = [DSAddressEntity managedObjectInContext:self.managedObjectContext];
                    e.derivationPath = derivationPathEntity;
                    NSAssert([addr isValidDashAddressOnChain:self.chain], @"the address is being saved to the wrong derivation path");
                    e.address = addr;
                    e.index = n;
                    e.identityIndex = identityIndex;
                    e.standalone = NO;
                }];
            }

            [self.mAllAddresses addObject:addr];
            [[self.addressesByIdentity objectForKey:@(identityIndex)] addObject:addr];
            [a addObject:addr];
            n++;
        }

        return a;
    }
}

- (NSData *)firstUnusedPublicKey {
    return [self publicKeyDataAtIndex:(uint32_t)[self firstUnusedIndex]];
}

- (DSKey *)firstUnusedPrivateKeyFromSeed:(NSData *)seed {
    return [self privateKeyAtIndexPath:[NSIndexPath indexPathWithIndex:[self firstUnusedIndex]] fromSeed:seed];
}

- (DSKey *)privateKeyForAddress:(NSString *)address fromSeed:(NSData *)seed {
    NSUInteger index = [self indexOfKnownAddress:address];
    return [self privateKeyAtIndexPath:[NSIndexPath indexPathWithIndex:index] fromSeed:seed];
}

- (NSData *)publicKeyDataForAddress:(NSString *)address {
    uint32_t index = (uint32_t)[self indexOfKnownAddress:address];
    return [self publicKeyDataAtIndex:index];
}

- (DSKey *)privateKeyForHash160:(UInt160)hash160 fromSeed:(NSData *)seed {
    NSString *address = [[NSData dataWithUInt160:hash160] addressFromHash160DataForChain:self.chain];
    return [self privateKeyForAddress:address fromSeed:seed];
}

- (NSData *)publicKeyDataForHash160:(UInt160)hash160 {
    NSString *address = [[NSData dataWithUInt160:hash160] addressFromHash160DataForChain:self.chain];
    return [self publicKeyDataForAddress:address];
}

- (DSKey *)generateExtendedPublicKeyFromSeed:(NSData *)seed storeUnderWalletUniqueId:(NSString *)walletUniqueId {
    return [super generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:walletUniqueId storePrivateKey:self.shouldStoreExtendedPrivateKey];
}

- (BOOL)hasExtendedPrivateKey {
    NSError *error = nil;
    return hasKeychainData([self walletBasedExtendedPrivateKeyLocationString], &error);
}

- (NSData *)extendedPrivateKeyData {
    NSError *error = nil;
    NSData *data = getKeychainData([self walletBasedExtendedPrivateKeyLocationString], &error);
    return data;
}

- (DSKey *_Nullable)privateKeyAtIndexPath:(NSIndexPath *)indexPath {
    DSKey *extendedPrivateKey = [DSKey keyWithExtendedPrivateKeyData:self.extendedPrivateKeyData forKeyType:self.signingAlgorithm];
    return [extendedPrivateKey privateDeriveToPath:indexPath];
}

- (NSData *)publicKeyDataAtIndexPath:(NSIndexPath *)indexPath {
    BOOL hasHardenedDerivation = FALSE;
    for (NSInteger i = 0; i < [indexPath length]; i++) {
        uint32_t derivation = (uint32_t)[indexPath indexAtPosition:i];
        hasHardenedDerivation |= ((derivation & BIP32_HARD) > 0);
        if (hasHardenedDerivation) break;
    }
    if (hasHardenedDerivation) {
        if ([self hasExtendedPrivateKey]) {
            DSKey *key = [self privateKeyAtIndexPath:indexPath];
            return key.publicKeyData;
        } else {
            return nil;
        }
    } else {
        return [super publicKeyDataAtIndexPath:indexPath];
    }
}

@end
