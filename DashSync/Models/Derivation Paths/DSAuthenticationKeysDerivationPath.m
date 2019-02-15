//
//  DSAuthenticationKeysDerivationPath.m
//  DashSync
//
//  Created by Sam Westrich on 2/10/19.
//

#import "DSAuthenticationKeysDerivationPath.h"
#import "DSDerivationPathFactory.h"

@interface DSAuthenticationKeysDerivationPath()

@property (nonatomic, strong) NSMutableArray *mAddresses;

@end

@implementation DSAuthenticationKeysDerivationPath

+ (instancetype)providerVotingKeysDerivationPathForWallet:(DSWallet*)wallet {
    return [[DSDerivationPathFactory sharedInstance] providerVotingKeysDerivationPathForWallet:wallet];
}
+ (instancetype)providerOwnerKeysDerivationPathForWallet:(DSWallet*)wallet {
     return [[DSDerivationPathFactory sharedInstance] providerOwnerKeysDerivationPathForWallet:wallet];
}
+ (instancetype)providerOperatorKeysDerivationPathForWallet:(DSWallet*)wallet {
    return [[DSDerivationPathFactory sharedInstance] providerOperatorKeysDerivationPathForWallet:wallet];
}

+ (instancetype)providerVotingKeysDerivationPathForChain:(DSChain*)chain {
    NSUInteger coinType = (chain.chainType == DSChainType_MainNet)?5:1;
    NSUInteger indexes[] = {5 | BIP32_HARD, coinType | BIP32_HARD, 3 | BIP32_HARD, 1 | BIP32_HARD};
    return [DSAuthenticationKeysDerivationPath derivationPathWithIndexes:indexes length:4 type:DSDerivationPathType_Authentication signingAlgorithm:DSDerivationPathSigningAlgorith_ECDSA reference:DSDerivationPathReference_ProviderVotingKeys onChain:chain];
}

+ (instancetype)providerOwnerKeysDerivationPathForChain:(DSChain*)chain {
    NSUInteger coinType = (chain.chainType == DSChainType_MainNet)?5:1;
    NSUInteger indexes[] = {5 | BIP32_HARD, coinType | BIP32_HARD, 3 | BIP32_HARD, 2 | BIP32_HARD};
    return [DSAuthenticationKeysDerivationPath derivationPathWithIndexes:indexes length:4 type:DSDerivationPathType_Authentication signingAlgorithm:DSDerivationPathSigningAlgorith_ECDSA reference:DSDerivationPathReference_ProviderOwnerKeys onChain:chain];
}

+ (instancetype)providerOperatorKeysDerivationPathForChain:(DSChain*)chain {
    NSUInteger coinType = (chain.chainType == DSChainType_MainNet)?5:1;
    NSUInteger indexes[] = {5 | BIP32_HARD, coinType | BIP32_HARD, 3 | BIP32_HARD, 3 | BIP32_HARD};
    return [DSAuthenticationKeysDerivationPath derivationPathWithIndexes:indexes length:4 type:DSDerivationPathType_Authentication signingAlgorithm:DSDerivationPathSigningAlgorith_BLS reference:DSDerivationPathReference_ProviderOperatorKeys onChain:chain];
}

- (instancetype)initWithIndexes:(NSUInteger *)indexes length:(NSUInteger)length
                           type:(DSDerivationPathType)type signingAlgorithm:(DSDerivationPathSigningAlgorith)signingAlgorithm reference:(DSDerivationPathReference)reference onChain:(DSChain*)chain {
    
    if (! (self = [super initWithIndexes:indexes length:length type:type signingAlgorithm:signingAlgorithm reference:reference onChain:chain])) return nil;
    
    self.mAddresses = [NSMutableArray array];
    
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
                for (DSAddressEntity *e in derivationPathEntity.addresses) {
                    @autoreleasepool {
                        NSMutableArray *a = self.mAddresses;
                        
                        while (e.index >= a.count) [a addObject:[NSNull null]];
                        if (![e.address isValidDashAddressOnChain:self.wallet.chain]) {
                            DSDLog(@"address %@ loaded but was not valid on chain %@",e.address,self.wallet.chain.name);
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
            [self registerAddressesWithGapLimit:10];
        }
    }
}

// MARK: - Derivation Path Addresses

// Wallets are composed of chains of addresses. Each chain is traversed until a gap of a certain number of addresses is
// found that haven't been used in any transactions. This method returns an array of <gapLimit> unused addresses
// following the last used address in the chain. The internal chain is used for change addresses and the external chain
// for receive addresses.
- (NSArray *)registerAddressesWithGapLimit:(NSUInteger)gapLimit
{
    if (!self.wallet.isTransient) {
        NSAssert(self.addressesLoaded, @"addresses must be loaded before calling this function");
    }
    NSUInteger i = self.mAddresses.count;
    
    // keep only the trailing contiguous block of addresses with no transactions
    while (i > 0 && ! [self.usedAddresses containsObject:self.mAddresses[i - 1]]) {
        i--;
    }
    
    if (i > 0) [self.mAddresses removeObjectsInRange:NSMakeRange(0, i)];
    if (self.mAddresses.count >= gapLimit) return [self.mAddresses subarrayWithRange:NSMakeRange(0, gapLimit)];
    
    @synchronized(self) {
        i = self.mAddresses.count;
        
        unsigned n = (unsigned)i;
        
        // keep only the trailing contiguous block of addresses with no transactions
        while (i > 0 && ! [self.usedAddresses containsObject:self.mAddresses[i - 1]]) {
            i--;
        }
        
        if (i > 0) [self.mAddresses removeObjectsInRange:NSMakeRange(0, i)];
        if (self.mAddresses.count >= gapLimit) return [self.mAddresses subarrayWithRange:NSMakeRange(0, gapLimit)];
        
        while (self.mAddresses.count < gapLimit) { // generate new addresses up to gapLimit
            NSData *pubKey = [self generatePublicKeyAtIndex:n];
            NSString *addr = nil;
            if (self.signingAlgorithm == DSDerivationPathSigningAlgorith_ECDSA) {
                addr = [[DSECDSAKey keyWithPublicKey:pubKey] addressForChain:self.chain];
            } else if (self.signingAlgorithm == DSDerivationPathSigningAlgorith_BLS) {
                addr = [[DSBLSKey blsKeyWithPublicKey:pubKey.UInt384 onChain:self.chain] addressForChain:self.chain];
            }
            
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
            [self.mAddresses addObject:addr];
            n++;
        }
        
        return self.mAddresses;
    }
}

-(uint32_t)unusedIndex {
    return 0;
}

- (NSData*)firstUnusedPublicKey {
    return [self publicKeyAtIndex:[self unusedIndex]];
}

-(DSECDSAKey*)firstUnusedPrivateKeyFromSeed:(NSData*)seed {
    return [self privateKeyAtIndexPath:[NSIndexPath indexPathWithIndex:[self unusedIndex]] fromSeed:seed];
}

@end
