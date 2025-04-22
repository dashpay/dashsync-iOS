//
//  DSDerivationPathFactory.m
//  DashSync
//
//  Created by Sam Westrich on 2/10/19.
//

#import "DSDerivationPathFactory.h"
#import "DSAccount.h"
#import "DSAuthenticationKeysDerivationPath+Protected.h"
#import "DSChain+Params.h"
#import "DSAssetLockDerivationPath+Protected.h"
#import "DSMasternodeHoldingsDerivationPath+Protected.h"
#import "DSBlockchainIdentityEntity+CoreDataClass.h"
#import "DSBlockchainIdentityUsernameEntity+CoreDataClass.h"
#import "DSDashpayUserEntity+CoreDataClass.h"
#import "NSManagedObject+Sugar.h"
#import "NSMutableData+Dash.h"

#define DERIVATION_PATH_EXTENDED_PUBLIC_KEY_WALLET_BASED_LOCATION @"DP_EPK_WBL"
#define DERIVATION_PATH_EXTENDED_PUBLIC_KEY_STANDALONE_BASED_LOCATION @"DP_EPK_SBL"
#define DERIVATION_PATH_STANDALONE_INFO_DICTIONARY_LOCATION @"DP_SIDL"
#define DERIVATION_PATH_EXTENDED_SECRET_KEY_WALLET_BASED_LOCATION @"DP_ESK_WBL"


@interface DSDerivationPathFactory ()

@property (nonatomic, strong) NSMutableDictionary *votingKeysDerivationPathByWallet;
@property (nonatomic, strong) NSMutableDictionary *ownerKeysDerivationPathByWallet;
@property (nonatomic, strong) NSMutableDictionary *operatorKeysDerivationPathByWallet;
@property (nonatomic, strong) NSMutableDictionary *platformNodeKeysDerivationPathByWallet;
@property (nonatomic, strong) NSMutableDictionary *providerFundsDerivationPathByWallet;
@property (nonatomic, strong) NSMutableDictionary *identityRegistrationFundingDerivationPathByWallet;
@property (nonatomic, strong) NSMutableDictionary *identityTopupFundingDerivationPathByWallet;
@property (nonatomic, strong) NSMutableDictionary *identityInvitationFundingDerivationPathByWallet;
@property (nonatomic, strong) NSMutableDictionary *identityBLSDerivationPathByWallet;
@property (nonatomic, strong) NSMutableDictionary *identityECDSADerivationPathByWallet;

@end

@implementation DSDerivationPathFactory

+ (instancetype)sharedInstance {
    static id singleton = nil;
    static dispatch_once_t onceToken = 0;

    dispatch_once(&onceToken, ^{
        singleton = [self new];
    });

    return singleton;
}

- (DSAuthenticationKeysDerivationPath *)providerVotingKeysDerivationPathForWallet:(DSWallet *)wallet {
    static dispatch_once_t votingKeysDerivationPathByWalletToken = 0;
    dispatch_once(&votingKeysDerivationPathByWalletToken, ^{
        self.votingKeysDerivationPathByWallet = [NSMutableDictionary dictionary];
    });
    @synchronized(self) {
        if (![self.votingKeysDerivationPathByWallet objectForKey:wallet.uniqueIDString]) {
            DSAuthenticationKeysDerivationPath *derivationPath = [DSAuthenticationKeysDerivationPath providerVotingKeysDerivationPathForChain:wallet.chain];
            derivationPath.wallet = wallet;
            if (derivationPath.hasExtendedPublicKey) {
                [derivationPath loadAddresses];
            }
            [self.votingKeysDerivationPathByWallet setObject:derivationPath
                                                      forKey:wallet.uniqueIDString];
        }
    }
    return [self.votingKeysDerivationPathByWallet objectForKey:wallet.uniqueIDString];
}

- (DSAuthenticationKeysDerivationPath *)providerOwnerKeysDerivationPathForWallet:(DSWallet *)wallet {
    static dispatch_once_t providerOwnerKeysDerivationPathByWalletToken = 0;
    dispatch_once(&providerOwnerKeysDerivationPathByWalletToken, ^{
        self.ownerKeysDerivationPathByWallet = [NSMutableDictionary dictionary];
    });
    @synchronized(self) {
        if (![self.ownerKeysDerivationPathByWallet objectForKey:wallet.uniqueIDString]) {
            DSAuthenticationKeysDerivationPath *derivationPath = [DSAuthenticationKeysDerivationPath providerOwnerKeysDerivationPathForChain:wallet.chain];
            derivationPath.wallet = wallet;
            if (derivationPath.hasExtendedPublicKey) {
                [derivationPath loadAddresses];
            }
            [self.ownerKeysDerivationPathByWallet setObject:derivationPath
                                                     forKey:wallet.uniqueIDString];
        }
    }
    return [self.ownerKeysDerivationPathByWallet objectForKey:wallet.uniqueIDString];
}

- (DSAuthenticationKeysDerivationPath *)providerOperatorKeysDerivationPathForWallet:(DSWallet *)wallet {
    static dispatch_once_t providerOperatorKeysDerivationPathByWalletToken = 0;
    dispatch_once(&providerOperatorKeysDerivationPathByWalletToken, ^{
        self.operatorKeysDerivationPathByWallet = [NSMutableDictionary dictionary];
    });
    @synchronized(self) {
        if (![self.operatorKeysDerivationPathByWallet objectForKey:wallet.uniqueIDString]) {
            DSAuthenticationKeysDerivationPath *derivationPath = [DSAuthenticationKeysDerivationPath providerOperatorKeysDerivationPathForChain:wallet.chain];
            derivationPath.wallet = wallet;
            if (derivationPath.hasExtendedPublicKey) {
                [derivationPath loadAddresses];
            }
            [self.operatorKeysDerivationPathByWallet setObject:derivationPath
                                                        forKey:wallet.uniqueIDString];
        }
    }
    return [self.operatorKeysDerivationPathByWallet objectForKey:wallet.uniqueIDString];
}

- (DSAuthenticationKeysDerivationPath *)platformNodeKeysDerivationPathForWallet:(DSWallet *)wallet {
    static dispatch_once_t providerOperatorKeysDerivationPathByWalletToken = 0;
    dispatch_once(&providerOperatorKeysDerivationPathByWalletToken, ^{
        self.platformNodeKeysDerivationPathByWallet = [NSMutableDictionary dictionary];
    });
    @synchronized(self) {
        if (![self.platformNodeKeysDerivationPathByWallet objectForKey:wallet.uniqueIDString]) {
            DSAuthenticationKeysDerivationPath *derivationPath = [DSAuthenticationKeysDerivationPath platformNodeKeysDerivationPathForChain:wallet.chain];
            derivationPath.wallet = wallet;
            if (derivationPath.hasExtendedPrivateKey || (derivationPath.hasExtendedPublicKey && !derivationPath.usesHardenedKeys)) {
//            if (derivationPath.hasExtendedPublicKey) {
                [derivationPath loadAddresses];
            }
            [self.platformNodeKeysDerivationPathByWallet setObject:derivationPath
                                                        forKey:wallet.uniqueIDString];
        }
    }
    return [self.platformNodeKeysDerivationPathByWallet objectForKey:wallet.uniqueIDString];
}

- (DSMasternodeHoldingsDerivationPath *)providerFundsDerivationPathForWallet:(DSWallet *)wallet {
    static dispatch_once_t providerFundsDerivationPathByWalletToken = 0;
    dispatch_once(&providerFundsDerivationPathByWalletToken, ^{
        self.providerFundsDerivationPathByWallet = [NSMutableDictionary dictionary];
    });
    @synchronized(self) {
        if (![self.providerFundsDerivationPathByWallet objectForKey:wallet.uniqueIDString]) {
            DSMasternodeHoldingsDerivationPath *derivationPath = [DSMasternodeHoldingsDerivationPath providerFundsDerivationPathForChain:wallet.chain];
            derivationPath.wallet = wallet;
            if (derivationPath.hasExtendedPublicKey) {
                [derivationPath loadAddresses];
            }
            [self.providerFundsDerivationPathByWallet setObject:derivationPath
                                                         forKey:wallet.uniqueIDString];
        }
    }
    return [self.providerFundsDerivationPathByWallet objectForKey:wallet.uniqueIDString];
}

// MARK: - Identity Funding

- (DSAssetLockDerivationPath *)identityRegistrationFundingDerivationPathForWallet:(DSWallet *)wallet {
    static dispatch_once_t identityRegistrationFundingDerivationPathByWalletToken = 0;
    dispatch_once(&identityRegistrationFundingDerivationPathByWalletToken, ^{
        self.identityRegistrationFundingDerivationPathByWallet = [NSMutableDictionary dictionary];
    });
    @synchronized(self) {
        if (![self.identityRegistrationFundingDerivationPathByWallet objectForKey:wallet.uniqueIDString]) {
            DSAssetLockDerivationPath *derivationPath = [DSAssetLockDerivationPath identityRegistrationFundingDerivationPathForChain:wallet.chain];
            derivationPath.wallet = wallet;
            if (derivationPath.hasExtendedPublicKey) {
                [derivationPath loadAddresses];
            }
            [self.identityRegistrationFundingDerivationPathByWallet setObject:derivationPath
                                                                       forKey:wallet.uniqueIDString];
        }
    }
    return [self.identityRegistrationFundingDerivationPathByWallet objectForKey:wallet.uniqueIDString];
}

- (DSAssetLockDerivationPath *)identityTopupFundingDerivationPathForWallet:(DSWallet *)wallet {
    static dispatch_once_t identityTopupFundingDerivationPathByWalletToken = 0;
    dispatch_once(&identityTopupFundingDerivationPathByWalletToken, ^{
        self.identityTopupFundingDerivationPathByWallet = [NSMutableDictionary dictionary];
    });
    @synchronized(self) {
        if (![self.identityTopupFundingDerivationPathByWallet objectForKey:wallet.uniqueIDString]) {
            DSAssetLockDerivationPath *derivationPath = [DSAssetLockDerivationPath identityTopupFundingDerivationPathForChain:wallet.chain];
            derivationPath.wallet = wallet;
            if (derivationPath.hasExtendedPublicKey) {
                [derivationPath loadAddresses];
            }
            [self.identityTopupFundingDerivationPathByWallet setObject:derivationPath
                                                                forKey:wallet.uniqueIDString];
        }
    }
    return [self.identityTopupFundingDerivationPathByWallet objectForKey:wallet.uniqueIDString];
}

- (DSAssetLockDerivationPath *)identityInvitationFundingDerivationPathForWallet:(DSWallet *)wallet {
    static dispatch_once_t identityInvitationFundingDerivationPathByWalletToken = 0;
    dispatch_once(&identityInvitationFundingDerivationPathByWalletToken, ^{
        self.identityInvitationFundingDerivationPathByWallet = [NSMutableDictionary dictionary];
    });
    @synchronized(self) {
        if (![self.identityInvitationFundingDerivationPathByWallet objectForKey:wallet.uniqueIDString]) {
            DSAssetLockDerivationPath *derivationPath = [DSAssetLockDerivationPath identityInvitationFundingDerivationPathForChain:wallet.chain];
            derivationPath.wallet = wallet;
            if (derivationPath.hasExtendedPublicKey) {
                [derivationPath loadAddresses];
            }
            [self.identityInvitationFundingDerivationPathByWallet setObject:derivationPath
                                                                               forKey:wallet.uniqueIDString];
        }
    }
    return [self.identityInvitationFundingDerivationPathByWallet objectForKey:wallet.uniqueIDString];
}

// MARK: - Identity Authentication

- (DSAuthenticationKeysDerivationPath *)identityBLSKeysDerivationPathForWallet:(DSWallet *)wallet {
    static dispatch_once_t identityBLSDerivationPathByWalletToken = 0;
    dispatch_once(&identityBLSDerivationPathByWalletToken, ^{
        self.identityBLSDerivationPathByWallet = [NSMutableDictionary dictionary];
    });
    @synchronized(self) {
        if (![self.identityBLSDerivationPathByWallet objectForKey:wallet.uniqueIDString]) {
            DSAuthenticationKeysDerivationPath *derivationPath = [DSAuthenticationKeysDerivationPath identityBLSKeysDerivationPathForChain:wallet.chain];
            derivationPath.wallet = wallet;
            if (derivationPath.hasExtendedPrivateKey || (derivationPath.hasExtendedPublicKey && !derivationPath.usesHardenedKeys)) {
                [derivationPath loadAddresses];
            }
            [self.identityBLSDerivationPathByWallet setObject:derivationPath
                                                       forKey:wallet.uniqueIDString];
        }
    }
    return [self.identityBLSDerivationPathByWallet objectForKey:wallet.uniqueIDString];
}

- (DSAuthenticationKeysDerivationPath *)identityECDSAKeysDerivationPathForWallet:(DSWallet *)wallet {
    NSParameterAssert(wallet);
    static dispatch_once_t identityECDSADerivationPathByWalletToken = 0;
    dispatch_once(&identityECDSADerivationPathByWalletToken, ^{
        self.identityECDSADerivationPathByWallet = [NSMutableDictionary dictionary];
    });
    @synchronized(self) {
        if (![self.identityECDSADerivationPathByWallet objectForKey:wallet.uniqueIDString]) {
            DSAuthenticationKeysDerivationPath *derivationPath = [DSAuthenticationKeysDerivationPath identityECDSAKeysDerivationPathForChain:wallet.chain];
            derivationPath.wallet = wallet;
            if (derivationPath.hasExtendedPrivateKey || (derivationPath.hasExtendedPublicKey && !derivationPath.usesHardenedKeys)) {
                [derivationPath loadAddresses];
            }
            [self.identityECDSADerivationPathByWallet setObject:derivationPath
                                                         forKey:wallet.uniqueIDString];
        }
    }
    return [self.identityECDSADerivationPathByWallet objectForKey:wallet.uniqueIDString];
}

- (NSArray<DSDerivationPath *> *)loadedSpecializedDerivationPathsForWallet:(DSWallet *)wallet {
    NSMutableArray *mArray = [NSMutableArray array];
    [mArray addObject:[[DSDerivationPathFactory sharedInstance] providerOwnerKeysDerivationPathForWallet:wallet]];
    [mArray addObject:[[DSDerivationPathFactory sharedInstance] providerOperatorKeysDerivationPathForWallet:wallet]];
    [mArray addObject:[[DSDerivationPathFactory sharedInstance] providerVotingKeysDerivationPathForWallet:wallet]];
    [mArray addObject:[[DSDerivationPathFactory sharedInstance] platformNodeKeysDerivationPathForWallet:wallet]];
    [mArray addObject:[[DSDerivationPathFactory sharedInstance] providerFundsDerivationPathForWallet:wallet]];
    if (wallet.chain.isEvolutionEnabled) {
        [mArray addObject:[[DSDerivationPathFactory sharedInstance] identityECDSAKeysDerivationPathForWallet:wallet]];
        [mArray addObject:[[DSDerivationPathFactory sharedInstance] identityBLSKeysDerivationPathForWallet:wallet]];
        [mArray addObject:[[DSDerivationPathFactory sharedInstance] identityRegistrationFundingDerivationPathForWallet:wallet]];
        [mArray addObject:[[DSDerivationPathFactory sharedInstance] identityTopupFundingDerivationPathForWallet:wallet]];
    }
    return mArray;
}

- (NSArray<DSDerivationPath *> *)fundDerivationPathsNeedingExtendedPublicKeyForWallet:(DSWallet *)wallet {
    NSMutableArray *mArray = [NSMutableArray array];

    for (DSAccount *account in wallet.accounts) {
        for (DSDerivationPath *fundsDerivationPath in account.outgoingFundDerivationPaths) {
            // We should only add derivation paths that are local (ie where we can rederivate)
            // The ones that come from the network should be refetched.
            if (fundsDerivationPath.length && ![fundsDerivationPath hasExtendedPublicKey]) {
                [mArray addObject:fundsDerivationPath];
            }
        }
        for (DSDerivationPath *fundsDerivationPath in account.fundDerivationPaths) {
            if (![fundsDerivationPath hasExtendedPublicKey]) {
                [mArray addObject:fundsDerivationPath];
            }
        }
        if (account.coinJoinDerivationPath && ![account.coinJoinDerivationPath hasExtendedPublicKey])
            [mArray addObject:account.coinJoinDerivationPath];
    }

    return [mArray copy];
}

- (NSArray<DSDerivationPath *> *)specializedDerivationPathsNeedingExtendedPublicKeyForWallet:(DSWallet *)wallet {
    NSMutableArray *mArray = [NSMutableArray array];

    for (DSDerivationPath *derivationPath in [self unloadedSpecializedDerivationPathsForWallet:wallet]) {
        if (![derivationPath hasExtendedPublicKey]) {
            [mArray addObject:derivationPath];
        }
    }
    if (wallet.chain.isEvolutionEnabled) {
        for (DSAccount *account in wallet.accounts) {
            DSDerivationPath *masterIdentityContactsDerivationPath = [DSDerivationPath masterIdentityContactsDerivationPathForAccountNumber:account.accountNumber onChain:wallet.chain];
            masterIdentityContactsDerivationPath.wallet = wallet;
            if (![masterIdentityContactsDerivationPath hasExtendedPublicKey]) {
                [mArray addObject:masterIdentityContactsDerivationPath];
            }
        }
    }
    return [mArray copy];
}

- (NSArray<DSDerivationPath *> *)unloadedSpecializedDerivationPathsForWallet:(DSWallet *)wallet {
    NSMutableArray *mArray = [NSMutableArray array];
    // Masternode Owner
    DSAuthenticationKeysDerivationPath *providerOwnerKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerOwnerKeysDerivationPathForChain:wallet.chain];
    providerOwnerKeysDerivationPath.wallet = wallet;
    [mArray addObject:providerOwnerKeysDerivationPath];

    // Masternode Operator
    DSAuthenticationKeysDerivationPath *providerOperatorKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerOperatorKeysDerivationPathForChain:wallet.chain];
    providerOperatorKeysDerivationPath.wallet = wallet;
    [mArray addObject:providerOperatorKeysDerivationPath];

    // Masternode Voting
    DSAuthenticationKeysDerivationPath *providerVotingKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerVotingKeysDerivationPathForChain:wallet.chain];
    providerVotingKeysDerivationPath.wallet = wallet;
    [mArray addObject:providerVotingKeysDerivationPath];

    // Masternode Holding
    DSMasternodeHoldingsDerivationPath *providerFundsDerivationPath = [DSMasternodeHoldingsDerivationPath providerFundsDerivationPathForChain:wallet.chain];
    providerFundsDerivationPath.wallet = wallet;
    [mArray addObject:providerFundsDerivationPath];

    // Platform Node
    DSAuthenticationKeysDerivationPath *providerPlatformNodeKeysDerivationPath = [DSAuthenticationKeysDerivationPath platformNodeKeysDerivationPathForChain:wallet.chain];
    providerPlatformNodeKeysDerivationPath.wallet = wallet;
    [mArray addObject:providerPlatformNodeKeysDerivationPath];

    if (wallet.chain.isEvolutionEnabled) {
        // Identities
        DSAuthenticationKeysDerivationPath *identitiesECDSADerivationPath = [DSAuthenticationKeysDerivationPath identityECDSAKeysDerivationPathForChain:wallet.chain];
        identitiesECDSADerivationPath.wallet = wallet;
        [mArray addObject:identitiesECDSADerivationPath];

        DSAuthenticationKeysDerivationPath *identitiesBLSDerivationPath = [DSAuthenticationKeysDerivationPath identityBLSKeysDerivationPathForChain:wallet.chain];
        identitiesBLSDerivationPath.wallet = wallet;
        [mArray addObject:identitiesBLSDerivationPath];

        DSAssetLockDerivationPath *identitiesRegistrationDerivationPath = [DSAssetLockDerivationPath identityRegistrationFundingDerivationPathForChain:wallet.chain];
        identitiesRegistrationDerivationPath.wallet = wallet;
        [mArray addObject:identitiesRegistrationDerivationPath];

        DSAssetLockDerivationPath *identitiesTopupDerivationPath = [DSAssetLockDerivationPath identityTopupFundingDerivationPathForChain:wallet.chain];
        identitiesTopupDerivationPath.wallet = wallet;
        [mArray addObject:identitiesTopupDerivationPath];

        DSAssetLockDerivationPath *identitiesInvitationsDerivationPath = [DSAssetLockDerivationPath identityInvitationFundingDerivationPathForChain:wallet.chain];
        identitiesInvitationsDerivationPath.wallet = wallet;
        [mArray addObject:identitiesInvitationsDerivationPath];
    }

    return [mArray copy];
}


+ (DMaybeOpaqueKeys *)privateKeysAtIndexPaths:(NSArray *)indexPaths
                                     fromSeed:(NSData *)seed
                               derivationPath:(DSDerivationPath *)derivationPath {
    if (!seed || !indexPaths || !derivationPath)
        return nil;
    if (indexPaths.count == 0)
        return Result_ok_Vec_dash_spv_crypto_keys_key_OpaqueKey_err_dash_spv_crypto_keys_KeyError_ctor(Vec_dash_spv_crypto_keys_key_OpaqueKey_ctor(0, NULL), NULL);
    NSUInteger count = indexPaths.count;
    Slice_u8 *seed_slice = slice_ctor(seed);
    Vec_u32 **values = malloc(count * sizeof(Vec_u32 *));
    for (NSUInteger i = 0; i < count; i++) {
        values[i] = [NSIndexPath ffi_to:indexPaths[i]];
    }
    Vec_Vec_u32 *index_paths = Vec_Vec_u32_ctor(count, values);
    DIndexPathU256 *path = [DSDerivationPath ffi_to:derivationPath];
    return DMaybeOpaquePrivateKeysAtIndexPathsWrapped(derivationPath.signingAlgorithm, seed_slice, index_paths, path);
}

+ (NSString *)serializedExtendedPrivateKeyFromSeed:(NSData *)seed
                                    derivationPath:(DSDerivationPath *)derivationPath {
    @autoreleasepool {
        if (!seed) return nil;
        Slice_u8 *slice = slice_ctor(seed);
        DIndexPathU256 *path = [DSDerivationPath ffi_to:derivationPath];
        DMaybeKeyString *result = DECDSAKeySerializedPrivateKeyFromSeedAtU256(slice, path, derivationPath.chain.chainType);
        NSString *serializedKey = result->ok ? NSStringFromPtr(result->ok) : nil;
        DMaybeKeyStringDtor(result);
        return serializedKey;
    }
}

+ (NSArray<NSString *> *)serializedPrivateKeysAtIndexPaths:(NSArray *)indexPaths
                                                  fromSeed:(NSData *)seed
                                            derivationPath:(DSDerivationPath *)derivationPath {
    if (!seed || !indexPaths) return nil;
    if (indexPaths.count == 0) return @[];
    
    NSUInteger count = indexPaths.count;
    Vec_u32 **values = malloc(count * sizeof(Vec_u32 *));
    for (NSUInteger i = 0; i < count; i++) {
        values[i] = [NSIndexPath ffi_to:indexPaths[i]];
    }
    Vec_Vec_u32 *index_paths = Vec_Vec_u32_ctor(count, values);
    DIndexPathU256 *path = [DSDerivationPath ffi_to:derivationPath];
    Slice_u8 *seed_slice = slice_ctor(seed);
    Result_ok_Vec_String_err_dash_spv_crypto_keys_KeyError *result = DMaybeSerializedOpaquePrivateKeysAtIndexPathsWrapped(derivationPath.signingAlgorithm, seed_slice, index_paths, path, derivationPath.chain.chainType);
    Vec_String *keys = result->ok;
    NSMutableArray *privateKeys = [NSMutableArray arrayWithCapacity:keys->count];
    for (NSUInteger i = 0; i < keys->count; i++) {
        [privateKeys addObject:NSStringFromPtr(keys->values[i])];
    }
    Result_ok_Vec_String_err_dash_spv_crypto_keys_KeyError_destroy(result);
    return privateKeys;
}

+ (NSData *)deserializedExtendedPublicKey:(NSString *)extendedPublicKeyString
                                  onChain:(DSChain *)chain
                                   rDepth:(uint8_t *)depth
                        rTerminalHardened:(BOOL *)terminalHardened
                           rTerminalIndex:(UInt256 *)terminalIndex {
    uint32_t fingerprint;
    UInt256 chainHash;
    NSData *pubkey = nil;
    NSMutableData *masterPublicKey = [NSMutableData secureData];
    BOOL valid = deserialize(extendedPublicKeyString, depth, &fingerprint, terminalHardened, terminalIndex, &chainHash, &pubkey, [chain isMainnet]);
    if (!valid) return nil;
    [masterPublicKey appendUInt32:fingerprint];
    [masterPublicKey appendBytes:&chainHash length:32];
    [masterPublicKey appendData:pubkey];
    return [masterPublicKey copy];
}
+ (NSData *)deserializedExtendedPublicKey:(NSString *)extendedPublicKeyString onChain:(DSChain *)chain {
    __unused uint8_t depth = 0;
    __unused BOOL terminalHardened = 0;
    __unused UInt256 terminalIndex = UINT256_ZERO;
    NSData *extendedPublicKey = [self deserializedExtendedPublicKey:extendedPublicKeyString onChain:chain rDepth:&depth rTerminalHardened:&terminalHardened rTerminalIndex:&terminalIndex];
    return extendedPublicKey;
}

+ (NSString *)serializedExtendedPublicKey:(DSDerivationPath *)derivationPath {
    //todo make sure this works with BLS keys
    NSData *extPubKeyData = derivationPath.extendedPublicKeyData;
    if (extPubKeyData.length < 36) return nil;
    uint32_t fingerprint = [extPubKeyData UInt32AtOffset:0];
    UInt256 chain = [extPubKeyData UInt256AtOffset:4];
    DSECPoint pubKey = [extPubKeyData ECPointAtOffset:36];
    UInt256 child = UINT256_ZERO;
    BOOL isHardened = NO;
    if (derivationPath.length) {
        child = [derivationPath indexAtPosition:[derivationPath length] - 1];
        isHardened = [derivationPath isHardenedAtPosition:[derivationPath length] - 1];
    }

    return serialize([derivationPath.depth unsignedCharValue], fingerprint, isHardened, child, chain, [NSData dataWithBytes:&pubKey length:sizeof(pubKey)], [derivationPath.chain isMainnet]);
}



+ (NSData *)deserializedExtendedPublicKey:(DSDerivationPath *)derivationPath extendedPublicKeyString:(NSString *)extendedPublicKeyString {
    return [DSDerivationPathFactory deserializedExtendedPublicKey:extendedPublicKeyString onChain:derivationPath.chain];
}



+ (NSString *)standaloneExtendedPublicKeyLocationStringForUniqueID:(NSString *)uniqueID {
    return [NSString stringWithFormat:@"%@_%@", DERIVATION_PATH_EXTENDED_PUBLIC_KEY_STANDALONE_BASED_LOCATION, uniqueID];
}

+ (NSString *)standaloneInfoDictionaryLocationStringForUniqueID:(NSString *)uniqueID {
    return [NSString stringWithFormat:@"%@_%@", DERIVATION_PATH_STANDALONE_INFO_DICTIONARY_LOCATION, uniqueID];
}

+ (NSString *)walletBasedExtendedPublicKeyLocationStringForUniqueID:(NSString *)uniqueID {
    return [NSString stringWithFormat:@"%@_%@", DERIVATION_PATH_EXTENDED_PUBLIC_KEY_WALLET_BASED_LOCATION, uniqueID];
}

+ (NSString *)walletBasedExtendedPrivateKeyLocationStringForUniqueID:(NSString *)uniqueID {
    return [NSString stringWithFormat:@"%@_%@", DERIVATION_PATH_EXTENDED_SECRET_KEY_WALLET_BASED_LOCATION, uniqueID];
}


+ (NSString *)stringRepresentationOfIndex:(UInt256)index
                                 hardened:(BOOL)hardened
                                inContext:(NSManagedObjectContext *)context {
    if (uint256_is_31_bits(index)) {
        return [NSString stringWithFormat:@"/%lu%@", (unsigned long)index.u64[0], hardened ? @"'" : @""];
    } else if (context) {
        __block NSString *rString = nil;
        [context performBlockAndWait:^{
            DSDashpayUserEntity *dashpayUserEntity = [DSDashpayUserEntity anyObjectInContext:context matching:@"associatedBlockchainIdentity.uniqueID == %@", uint256_data(index)];
            if (dashpayUserEntity) {
                DSBlockchainIdentityUsernameEntity *usernameEntity = [dashpayUserEntity.associatedBlockchainIdentity.usernames anyObject];
                rString = [NSString stringWithFormat:@"/%@%@", usernameEntity.stringValue, hardened ? @"'" : @""];
            } else {
                rString = [NSString stringWithFormat:@"/0x%@%@", uint256_hex(index), hardened ? @"'" : @""];
            }
        }];
        return rString;
    } else {
        return [NSString stringWithFormat:@"/0x%@%@", uint256_hex(index), hardened ? @"'" : @""];
    }
}

@end
