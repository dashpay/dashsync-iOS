//
//  DSWallet.m
//  DashSync
//
//  Created by Sam Westrich on 5/20/18.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "DSAccount.h"
#import "DSAssetLockDerivationPath+Protected.h"
#import "DSAuthenticationKeysDerivationPath+Protected.h"
#import "DSAuthenticationManager+Private.h"
#import "DSChain+Params.h"
#import "DSChain+Wallet.h"
#import "DSChainsManager.h"
#import "DSDerivationPathFactory.h"
#import "DSLocalMasternode.h"
#import "DSMasternodeHoldingsDerivationPath+Protected.h"
#import "DSOptionsManager.h"
#import "DSProviderRegistrationTransaction.h"
#import "DSSpecialTransactionsWalletHolder.h"
#import "DSWallet+Identity.h"
#import "DSWallet+Invitation.h"
#import "DSWallet+Protected.h"
#import "NSDate+Utils.h"
#import "NSMutableData+Dash.h"

#define SEED_ENTROPY_LENGTH (128 / 8)
#define WALLET_CREATION_TIME_KEY @"WALLET_CREATION_TIME_KEY"
#define WALLET_CREATION_GUESS_TIME_KEY @"WALLET_CREATION_GUESS_TIME_KEY"
#define AUTH_PRIVKEY_KEY @"authprivkey"
#define WALLET_MNEMONIC_KEY @"WALLET_MNEMONIC_KEY"
#define WALLET_MASTER_PUBLIC_KEY @"WALLET_MASTER_PUBLIC_KEY"

#define WALLET_ACCOUNTS_KNOWN_KEY @"WALLET_ACCOUNTS_KNOWN_KEY"

#define WALLET_MASTERNODE_VOTERS_KEY @"WALLET_MASTERNODE_VOTERS_KEY"
#define WALLET_MASTERNODE_OWNERS_KEY @"WALLET_MASTERNODE_OWNERS_KEY"
#define WALLET_MASTERNODE_OPERATORS_KEY @"WALLET_MASTERNODE_OPERATORS_KEY"
#define WALLET_PLATFORM_NODES_KEY @"WALLET_PLATFORM_NODES_KEY"

#define VERIFIED_WALLET_CREATION_TIME_KEY @"VERIFIED_WALLET_CREATION_TIME"
#define REFERENCE_DATE_2001 978307200

@interface DSWallet () {
    NSTimeInterval _lGuessedWalletCreationTime;
}

@property (nonatomic, strong) DSChain *chain;
@property (nonatomic, strong) NSMutableDictionary *mAccounts;
@property (nonatomic, strong) DSSpecialTransactionsWalletHolder *specialTransactionsHolder;
@property (nonatomic, copy) NSString *uniqueIDString;
@property (nonatomic, assign) NSTimeInterval walletCreationTime;
@property (nonatomic, assign) BOOL checkedWalletCreationTime;
@property (nonatomic, assign) BOOL checkedGuessedWalletCreationTime;
@property (nonatomic, assign) BOOL checkedVerifyWalletCreationTime;

@property (nonatomic, strong) NSMutableDictionary<NSData *, NSNumber *> *mMasternodeOperatorIndexes;
@property (nonatomic, strong) NSMutableDictionary<NSData *, NSNumber *> *mMasternodeOwnerIndexes;
@property (nonatomic, strong) NSMutableDictionary<NSData *, NSNumber *> *mMasternodeVoterIndexes;
@property (nonatomic, strong) NSMutableDictionary<NSData *, NSNumber *> *mPlatformNodeIndexes;
@property (nonatomic, strong) NSMutableDictionary<NSData *, NSString *> *mMasternodeOperatorPublicKeyLocations;
@property (nonatomic, strong) NSMutableDictionary<NSData *, NSString *> *mMasternodeOwnerPrivateKeyLocations;
@property (nonatomic, strong) NSMutableDictionary<NSData *, NSString *> *mMasternodeVoterKeyLocations;
@property (nonatomic, strong) NSMutableDictionary<NSData *, NSString *> *mPlatformNodeKeyLocations;

@property (nonatomic, assign, getter=isTransient) BOOL transient;

@end

@implementation DSWallet

+ (DSWallet *)standardWalletWithSeedPhrase:(NSString *)seedPhrase setCreationDate:(NSTimeInterval)creationDate forChain:(DSChain *)chain storeSeedPhrase:(BOOL)store isTransient:(BOOL)isTransient {
    NSParameterAssert(seedPhrase);
    NSParameterAssert(chain);

    DSAccount *account = [DSAccount accountWithAccountNumber:0 withDerivationPaths:[chain standardDerivationPathsForAccountNumber:0] inContext:chain.chainManagedObjectContext];

    NSString *uniqueId = [self setSeedPhrase:seedPhrase createdAt:creationDate withAccounts:@[account] storeOnKeychain:store forChain:chain]; //make sure we can create the wallet first
    if (!uniqueId) return nil;
    [self registerSpecializedDerivationPathsForSeedPhrase:seedPhrase underUniqueId:uniqueId onChain:chain];
    DSWallet *wallet = [[DSWallet alloc] initWithUniqueID:uniqueId andAccounts:@[account] forChain:chain storeSeedPhrase:store isTransient:isTransient];

    return wallet;
}

+ (DSWallet *)standardWalletWithRandomSeedPhraseForChain:(DSChain *)chain storeSeedPhrase:(BOOL)store isTransient:(BOOL)isTransient {
    NSParameterAssert(chain);

    return [self standardWalletWithRandomSeedPhraseInLanguage:DSBIP39Language_Default forChain:chain storeSeedPhrase:store isTransient:isTransient];
}

+ (DSWallet *)standardWalletWithRandomSeedPhraseInLanguage:(DSBIP39Language)language forChain:(DSChain *)chain storeSeedPhrase:(BOOL)store isTransient:(BOOL)isTransient {
    NSParameterAssert(chain);

    return [self standardWalletWithSeedPhrase:[self generateRandomSeedPhraseForLanguage:language] setCreationDate:[NSDate timeIntervalSince1970] forChain:chain storeSeedPhrase:store isTransient:isTransient];
}

//this is for testing purposes only
+ (DSWallet *)transientWalletWithDerivedKeyData:(NSData *)derivedData forChain:(DSChain *)chain {
    NSParameterAssert(derivedData);
    NSParameterAssert(chain);

    DSAccount *account = [DSAccount accountWithAccountNumber:0 withDerivationPaths:[chain standardDerivationPathsForAccountNumber:0] inContext:chain.chainManagedObjectContext];


    NSString *uniqueId = [self setTransientDerivedKeyData:derivedData withAccounts:@[account] forChain:chain]; //make sure we can create the wallet first
    if (!uniqueId) return nil;
    //[self registerSpecializedDerivationPathsForSeedPhrase:seedPhrase underUniqueId:uniqueId onChain:chain];
    DSWallet *wallet = [[DSWallet alloc] initWithUniqueID:uniqueId andAccounts:@[account] forChain:chain storeSeedPhrase:NO isTransient:YES];

    wallet.transientDerivedKeyData = derivedData;

    return wallet;
}

- (instancetype)initWithChain:(DSChain *)chain {
    NSParameterAssert(chain);

    if (!(self = [super init])) return nil;
    self.transient = FALSE;
    self.mAccounts = [NSMutableDictionary dictionary];
    self.chain = chain;
//    self.mIdentities = [NSMutableDictionary dictionary];
    self.mMasternodeOwnerIndexes = [NSMutableDictionary dictionary];
    self.mMasternodeVoterIndexes = [NSMutableDictionary dictionary];
    self.mMasternodeOperatorIndexes = [NSMutableDictionary dictionary];
    self.mMasternodeOwnerPrivateKeyLocations = [NSMutableDictionary dictionary];
    self.mMasternodeVoterKeyLocations = [NSMutableDictionary dictionary];
    self.mMasternodeOperatorPublicKeyLocations = [NSMutableDictionary dictionary];
    self.checkedWalletCreationTime = NO;
    self.checkedGuessedWalletCreationTime = NO;
    self.checkedVerifyWalletCreationTime = NO;
    [self setup];
    return self;
}

- (instancetype)initWithUniqueID:(NSString *)uniqueID andAccounts:(NSArray<DSAccount *> *)accounts forChain:(DSChain *)chain storeSeedPhrase:(BOOL)store isTransient:(BOOL)isTransient {
    NSParameterAssert(uniqueID);
    NSParameterAssert(accounts);
    NSParameterAssert(chain);
    NSAssert(accounts.count > 0, @"The wallet must have at least one account");

    if (!(self = [self initWithChain:chain])) return nil;
    self.uniqueIDString = uniqueID;
    __weak typeof(self) weakSelf = self;

    self.secureSeedRequestBlock = ^void(NSString *authprompt, uint64_t amount, SeedCompletionBlock seedCompletion) {
        //this happens when we request the seed and want to auth with pin
        [weakSelf seedWithPrompt:authprompt forAmount:amount completion:seedCompletion];
    };
    if (store) {
        [chain registerWallet:self];
    }

    if (isTransient) {
        self.transient = TRUE;
    }

    if (accounts) [self addAccounts:accounts]; //this must be last, as adding the account queries the wallet unique ID

    [[DSDerivationPathFactory sharedInstance] loadedSpecializedDerivationPathsForWallet:self];

    self.specialTransactionsHolder = [[DSSpecialTransactionsWalletHolder alloc] initWithWallet:self inContext:self.chain.chainManagedObjectContext];
    [self setupIdentities];
    [self setupInvitations];

    //blockchain users are loaded

    //add blockchain user derivation paths to account

    return self;
}

+ (uint32_t)accountsKnownForUniqueId:(NSString *)uniqueID {
    NSError *error = nil;
    int32_t accountsKnown = (int32_t)getKeychainInt([DSWallet accountsKnownKeyForWalletUniqueID:uniqueID], &error);
    if (error) {
        return 0;
    }
    return accountsKnown;
}

- (uint32_t)accountsKnown {
    return [DSWallet accountsKnownForUniqueId:self.uniqueIDString];
}

- (NSData *_Nullable)requestSeedNoAuth {
    //this happens when we request the seed without a pin code
    NSString *seed = [self seedPhrase];
    NSData *seedData = [[DSBIP39Mnemonic sharedInstance] deriveKeyFromPhrase:seed withPassphrase:nil];
    
    return seedData;
}

+ (void)registerSpecializedDerivationPathsForSeedPhrase:(NSString *)seedPhrase underUniqueId:(NSString *)walletUniqueId onChain:(DSChain *)chain {
    @autoreleasepool {
        seedPhrase = [[DSBIP39Mnemonic sharedInstance] normalizePhrase:seedPhrase];

        NSData *derivedKeyData = (seedPhrase) ? [[DSBIP39Mnemonic sharedInstance]
                                                    deriveKeyFromPhrase:seedPhrase
                                                         withPassphrase:nil] :
                                                nil;

        if (derivedKeyData) {
            DSAuthenticationKeysDerivationPath *providerOwnerKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerOwnerKeysDerivationPathForChain:chain];
            [providerOwnerKeysDerivationPath generateExtendedPublicKeyFromSeed:derivedKeyData storeUnderWalletUniqueId:walletUniqueId];
            DSAuthenticationKeysDerivationPath *providerOperatorKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerOperatorKeysDerivationPathForChain:chain];
            [providerOperatorKeysDerivationPath generateExtendedPublicKeyFromSeed:derivedKeyData storeUnderWalletUniqueId:walletUniqueId];
            DSAuthenticationKeysDerivationPath *providerVotingKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerVotingKeysDerivationPathForChain:chain];
            [providerVotingKeysDerivationPath generateExtendedPublicKeyFromSeed:derivedKeyData storeUnderWalletUniqueId:walletUniqueId];
            DSAuthenticationKeysDerivationPath *providerPlatformNodeKeysDerivationPath = [DSAuthenticationKeysDerivationPath platformNodeKeysDerivationPathForChain:chain];
            [providerPlatformNodeKeysDerivationPath generateExtendedPublicKeyFromSeed:derivedKeyData storeUnderWalletUniqueId:walletUniqueId];
            DSMasternodeHoldingsDerivationPath *providerFundsDerivationPath = [DSMasternodeHoldingsDerivationPath providerFundsDerivationPathForChain:chain];
            [providerFundsDerivationPath generateExtendedPublicKeyFromSeed:derivedKeyData storeUnderWalletUniqueId:walletUniqueId];

            if (chain.isEvolutionEnabled) {
                DSAuthenticationKeysDerivationPath *identityBLSKeysDerivationPath = [DSAuthenticationKeysDerivationPath identityBLSKeysDerivationPathForChain:chain];
                [identityBLSKeysDerivationPath generateExtendedPublicKeyFromSeed:derivedKeyData storeUnderWalletUniqueId:walletUniqueId];

                DSAuthenticationKeysDerivationPath *identityECDSAKeysDerivationPath = [DSAuthenticationKeysDerivationPath identityECDSAKeysDerivationPathForChain:chain];
                [identityECDSAKeysDerivationPath generateExtendedPublicKeyFromSeed:derivedKeyData storeUnderWalletUniqueId:walletUniqueId];

                DSAssetLockDerivationPath *identityRegistrationFundingDerivationPath = [DSAssetLockDerivationPath identityRegistrationFundingDerivationPathForChain:chain];
                [identityRegistrationFundingDerivationPath generateExtendedPublicKeyFromSeed:derivedKeyData storeUnderWalletUniqueId:walletUniqueId];

                DSAssetLockDerivationPath *identityTopupFundingDerivationPath = [DSAssetLockDerivationPath identityTopupFundingDerivationPathForChain:chain];
                [identityTopupFundingDerivationPath generateExtendedPublicKeyFromSeed:derivedKeyData storeUnderWalletUniqueId:walletUniqueId];

                DSAssetLockDerivationPath *identityInvitationFundingDerivationPath = [DSAssetLockDerivationPath identityInvitationFundingDerivationPathForChain:chain];
                [identityInvitationFundingDerivationPath generateExtendedPublicKeyFromSeed:derivedKeyData storeUnderWalletUniqueId:walletUniqueId];
            }
        }
    }
}


- (instancetype)initWithUniqueID:(NSString *)uniqueID forChain:(DSChain *)chain {
    int32_t accountsKnown = [DSWallet accountsKnownForUniqueId:uniqueID];
    if (!(self = [self initWithUniqueID:uniqueID andAccounts:[DSAccount standardAccountsToAccountNumber:accountsKnown onChain:chain inContext:chain.chainManagedObjectContext] forChain:chain storeSeedPhrase:NO isTransient:NO])) return nil;
    return self;
}

+ (NSString *)accountsKnownKeyForWalletUniqueID:(NSString *)walletUniqueId {
    return [NSString stringWithFormat:@"%@_%@", WALLET_ACCOUNTS_KNOWN_KEY, walletUniqueId];
}

- (NSString *)walletMasternodeVotersKey {
    return [NSString stringWithFormat:@"%@_%@", WALLET_MASTERNODE_VOTERS_KEY, [self uniqueIDString]];
}

- (NSString *)walletMasternodeOwnersKey {
    return [NSString stringWithFormat:@"%@_%@", WALLET_MASTERNODE_OWNERS_KEY, [self uniqueIDString]];
}

- (NSString *)walletMasternodeOperatorsKey {
    return [NSString stringWithFormat:@"%@_%@", WALLET_MASTERNODE_OPERATORS_KEY, [self uniqueIDString]];
}

- (NSString *)walletPlatformNodesKey {
    return [NSString stringWithFormat:@"%@_%@", WALLET_PLATFORM_NODES_KEY, [self uniqueIDString]];
}

- (NSArray *)accounts {
    return [self.mAccounts allValues];
}

- (NSDictionary *)orderedAccounts {
    return [self.mAccounts copy];
}

- (uint32_t)lastAccountNumber {
    NSArray<NSNumber *> *accountNumbers = [self.mAccounts allKeys];
    if (accountNumbers.count == 0) {
        NSAssert(accountNumbers.count > 0, @"There should always be at least one account");
        return UINT32_MAX;
    }
    NSNumber *maxAccountNumber = [accountNumbers valueForKeyPath:@"@max.intValue"];
    return [maxAccountNumber unsignedIntValue];
}

- (void)addAccount:(DSAccount *)account {
    NSParameterAssert(account);

    [self.mAccounts setObject:account forKey:@(account.accountNumber)];
    account.wallet = self;
    uint32_t lastAccountNumber = [self lastAccountNumber];
    if (lastAccountNumber > [self accountsKnown]) {
        setKeychainInt(lastAccountNumber, [DSWallet accountsKnownKeyForWalletUniqueID:[self uniqueIDString]], NO);
    }
}

- (DSAccount *)addAnotherAccountIfAuthenticated {
    uint32_t addAccountNumber = self.lastAccountNumber + 1;
    NSArray *derivationPaths = [self.chain standardDerivationPathsForAccountNumber:addAccountNumber];
    DSAccount *addAccount = [DSAccount accountWithAccountNumber:addAccountNumber withDerivationPaths:derivationPaths inContext:self.chain.chainManagedObjectContext];
    NSString *seedPhrase = [self seedPhraseIfAuthenticated];
    if (seedPhrase == nil) {
        return nil;
    }
    NSData *derivedKeyData = [[DSBIP39Mnemonic sharedInstance] deriveKeyFromPhrase:seedPhrase
                                                                    withPassphrase:nil];
    for (DSDerivationPath *derivationPath in addAccount.fundDerivationPaths) {
        [derivationPath generateExtendedPublicKeyFromSeed:derivedKeyData
                                 storeUnderWalletUniqueId:self.uniqueIDString];
    }
    if ([self.chain isEvolutionEnabled]) {
        [addAccount.masterContactsDerivationPath generateExtendedPublicKeyFromSeed:derivedKeyData
                                                          storeUnderWalletUniqueId:self.uniqueIDString];
    }

    [self addAccount:addAccount];
    [addAccount loadDerivationPaths];
    return addAccount;
}

- (void)addAccounts:(NSArray<DSAccount *> *)accounts {
    NSParameterAssert(accounts);
    for (DSAccount *account in accounts) {
        [self addAccount:account];
    }
}

- (DSAccount *_Nullable)accountWithNumber:(NSUInteger)accountNumber {
    return [self.mAccounts objectForKey:@(accountNumber)];
}

- (void)copyForChain:(DSChain *)chain completion:(void (^_Nonnull)(DSWallet *copiedWallet))completion {
    if ([self.chain isEqual:chain]) {
        completion(self);
        return;
    }
    NSString *prompt = DSLocalizedFormat(@"Please authenticate to create your %@ wallet", @"Please authenticate to create your Testnet wallet", chain.localizedName);

    [self seedPhraseAfterAuthenticationWithPrompt:prompt
                                       completion:^(NSString *_Nullable seedPhrase) {
        if (!seedPhrase) {
            completion(nil);
            return;
        }
        DSWallet *wallet = [self.class standardWalletWithSeedPhrase:seedPhrase setCreationDate:(self.walletCreationTime == BIP39_CREATION_TIME) ? 0 : self.walletCreationTime forChain:chain storeSeedPhrase:YES isTransient:NO];
        completion(wallet);
    }];
}

// MARK: - Unique Identifiers

+ (NSString *)mnemonicUniqueIDForUniqueID:(NSString *)uniqueID {
    return [NSString stringWithFormat:@"%@_%@", WALLET_MNEMONIC_KEY, uniqueID];
}

- (NSString *)mnemonicUniqueID {
    return [DSWallet mnemonicUniqueIDForUniqueID:self.uniqueIDString];
}

+ (NSString *)creationTimeUniqueIDForUniqueID:(NSString *)uniqueID {
    NSParameterAssert(uniqueID);
    return [NSString stringWithFormat:@"%@_%@", WALLET_CREATION_TIME_KEY, uniqueID];
}

+ (NSString *)creationGuessTimeUniqueIDForUniqueID:(NSString *)uniqueID {
    NSParameterAssert(uniqueID);
    return [NSString stringWithFormat:@"%@_%@", WALLET_CREATION_GUESS_TIME_KEY, uniqueID];
}

+ (NSString *)didVerifyCreationTimeUniqueIDForUniqueID:(NSString *)uniqueID {
    NSParameterAssert(uniqueID);
    return [NSString stringWithFormat:@"%@_%@", VERIFIED_WALLET_CREATION_TIME_KEY, uniqueID];
}

- (NSString *)creationTimeUniqueID {
    return [DSWallet creationTimeUniqueIDForUniqueID:self.uniqueIDString];
}

- (NSString *)creationGuessTimeUniqueID {
    return [DSWallet creationGuessTimeUniqueIDForUniqueID:self.uniqueIDString];
}

- (NSString *)didVerifyCreationTimeUniqueID {
    return [DSWallet didVerifyCreationTimeUniqueIDForUniqueID:self.uniqueIDString];
}

// MARK: - Wallet Creation Time

- (NSTimeInterval)walletCreationTime {
    [self verifyWalletCreationTime];
    if (_walletCreationTime) return _walletCreationTime;

    if (!self.checkedWalletCreationTime) {
        NSData *d = getKeychainData(self.creationTimeUniqueID, nil);

        if (d.length == sizeof(NSTimeInterval)) {
            NSTimeInterval potentialWalletCreationTime = *(const NSTimeInterval *)d.bytes;
            if (potentialWalletCreationTime > BIP39_CREATION_TIME) {
                _walletCreationTime = potentialWalletCreationTime;
                return _walletCreationTime;
            }
        }
        self.checkedWalletCreationTime = TRUE;
    }

    if ([DSEnvironment sharedInstance].watchOnly) return BIP39_WALLET_UNKNOWN_CREATION_TIME; //0
    if ([self guessedWalletCreationTime]) return [self guessedWalletCreationTime];
    return BIP39_CREATION_TIME;
}

- (void)wipeWalletInfo {
    self.walletCreationTime = 0;
    setKeychainData(nil, self.creationTimeUniqueID, NO);
    setKeychainData(nil, self.creationGuessTimeUniqueID, NO);
    setKeychainData(nil, self.didVerifyCreationTimeUniqueID, NO);
}

- (NSTimeInterval)guessedWalletCreationTime {
    if (_lGuessedWalletCreationTime) return _lGuessedWalletCreationTime;
    if (!self.checkedGuessedWalletCreationTime) {
        NSData *d = getKeychainData(self.creationGuessTimeUniqueID, nil);

        if (d.length == sizeof(NSTimeInterval)) {
            _lGuessedWalletCreationTime = *(const NSTimeInterval *)d.bytes;
            return _lGuessedWalletCreationTime;
        }
        self.checkedGuessedWalletCreationTime = YES;
    }
    return BIP39_WALLET_UNKNOWN_CREATION_TIME; //0
}

- (void)setGuessedWalletCreationTime:(NSTimeInterval)guessedWalletCreationTime {
    if (_walletCreationTime) return;
    if ([self guessedWalletCreationTime]) return; //don't guess again
    if (!setKeychainData([NSData dataWithBytes:&guessedWalletCreationTime length:sizeof(guessedWalletCreationTime)], [self creationGuessTimeUniqueID], NO)) {
        NSAssert(FALSE, @"error setting wallet guessed creation time");
    }
    _lGuessedWalletCreationTime = guessedWalletCreationTime;
}

- (void)migrateWalletCreationTime {
    NSData *d = getKeychainData(self.creationTimeUniqueID, nil);

    if (d.length == sizeof(NSTimeInterval)) {
        NSTimeInterval potentialWalletCreationTime = *(const NSTimeInterval *)d.bytes;
        if (potentialWalletCreationTime < BIP39_CREATION_TIME) { //it was from reference date for sure
            NSDate *realWalletCreationDate = [NSDate dateWithTimeIntervalSinceReferenceDate:potentialWalletCreationTime];
            NSTimeInterval realWalletCreationTime = [realWalletCreationDate timeIntervalSince1970];
            if (realWalletCreationTime && (realWalletCreationTime != REFERENCE_DATE_2001)) {
                _walletCreationTime = MAX(realWalletCreationTime, BIP39_CREATION_TIME); //safeguard
#if DEBUG
                DSLogPrivate(@"[%@] real wallet creation set to %@", self.chain.name, realWalletCreationDate);
#else
                DSLog(@"[%@] real wallet creation set to %@", self.chain.name, @"<REDACTED>");
#endif
                setKeychainData([NSData dataWithBytes:&realWalletCreationTime length:sizeof(realWalletCreationTime)], self.creationTimeUniqueID, NO);
            } else if (realWalletCreationTime == REFERENCE_DATE_2001) {
                realWalletCreationTime = 0;
                setKeychainData([NSData dataWithBytes:&realWalletCreationTime length:sizeof(realWalletCreationTime)], self.creationTimeUniqueID, NO);
            }
        }
    }
}

- (void)verifyWalletCreationTime {
    if (!self.checkedVerifyWalletCreationTime) {
        NSError *error = nil;
        BOOL didVerifyAlready = hasKeychainData(self.didVerifyCreationTimeUniqueID, &error);
        if (!didVerifyAlready) {
            [self migrateWalletCreationTime];
            setKeychainInt(1, self.didVerifyCreationTimeUniqueID, NO);
        }
        self.checkedVerifyWalletCreationTime = YES;
    }
}

// MARK: - Chain Synchronization Fingerprint

- (NSData *)chainSynchronizationFingerprint {
    NSArray *blockHeightsArray = [[[self allTransactions] mutableArrayValueForKey:@"blockHeight"] sortedArrayUsingSelector:@selector(compare:)];
    NSMutableOrderedSet *blockHeightZones = [NSMutableOrderedSet orderedSet];
    [blockHeightsArray enumerateObjectsUsingBlock:^(id _Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        [blockHeightZones addObject:@([obj unsignedLongValue] / 500)];
    }];

    return [[self class] chainSynchronizationFingerprintForBlockZones:blockHeightZones forChainHeight:self.chain.lastSyncBlockHeight];
}

+ (NSOrderedSet *)blockZonesFromChainSynchronizationFingerprint:(NSData *)chainSynchronizationFingerprint rVersion:(uint8_t *)rVersion rChainHeight:(uint32_t *)rChainHeight {
    if (rVersion) {
        *rVersion = [chainSynchronizationFingerprint UInt8AtOffset:0];
    }
    if (rChainHeight) {
        *rChainHeight = ((uint32_t)[chainSynchronizationFingerprint UInt16BigToHostAtOffset:1]) * 500;
    }
    uint16_t firstBlockZone = [chainSynchronizationFingerprint UInt16BigToHostAtOffset:3];
    NSMutableOrderedSet *blockZones = [NSMutableOrderedSet orderedSet];
    [blockZones addObject:@(firstBlockZone)];
    uint16_t lastKnownBlockZone = firstBlockZone;
    uint16_t offset = 0;
    for (uint32_t i = 5; i < chainSynchronizationFingerprint.length; i += 2) {
        uint16_t currentData = [chainSynchronizationFingerprint UInt16BigToHostAtOffset:i];
        if (currentData & (1 << 15)) {
            //We are in a continuation
            if (offset) {
                offset = -15 + offset;
            }
            for (uint8_t i = 1; i < 16; i++) {
                if (currentData & (1 << (15 - i))) {
                    lastKnownBlockZone = lastKnownBlockZone - offset + i;
                    offset = i;
                    [blockZones addObject:@(lastKnownBlockZone)];
                }
            }
        } else { //this is a new zone
            offset = 0;
            lastKnownBlockZone = currentData;
            [blockZones addObject:@(lastKnownBlockZone)];
        }
    }
    return blockZones;
}

+ (NSData *)chainSynchronizationFingerprintForBlockZones:(NSOrderedSet *)blockHeightZones forChainHeight:(uint32_t)chainHeight {
    if (!blockHeightZones.count) {
        return [NSData data];
    }

    NSMutableData *fingerprintData = [NSMutableData data];
    [fingerprintData appendUInt8:1];                           //version 1
    [fingerprintData appendUInt16BigEndian:chainHeight / 500]; //last sync block height
    uint16_t previousBlockHeightZone = [blockHeightZones.firstObject unsignedShortValue];
    [fingerprintData appendUInt16BigEndian:previousBlockHeightZone]; //first one
    uint8_t currentOffset = 0;
    uint16_t currentContinuationData = 0;
    for (NSNumber *blockZoneNumber in blockHeightZones) {
        if (blockHeightZones.firstObject == blockZoneNumber) continue;
        uint16_t currentBlockHeightZone = [blockZoneNumber unsignedShortValue];
        uint16_t distance = currentBlockHeightZone - previousBlockHeightZone;
        if ((!currentOffset && distance >= 15) || (distance >= 30 - currentOffset)) {
            if (currentContinuationData) {
                [fingerprintData appendUInt16BigEndian:currentContinuationData];
                currentOffset = 0;
                currentContinuationData = 0;
            }
            [fingerprintData appendUInt16BigEndian:currentBlockHeightZone];
        } else {
            currentOffset += distance;
            if (currentOffset > 15) {
                currentOffset %= 15;
                [fingerprintData appendUInt16BigEndian:currentContinuationData];
                currentContinuationData = 1 << 15;
            }
            if (!currentContinuationData) {
                currentContinuationData = 1 << 15; //start with a 1 to show current continuation data
            }
            uint16_t currentOffsetBit = (1 << (15 - currentOffset));
            currentContinuationData |= currentOffsetBit;
        }
        previousBlockHeightZone = currentBlockHeightZone;
    }
    if (currentContinuationData) {
        [fingerprintData appendUInt16BigEndian:currentContinuationData];
    }
    return fingerprintData;
}

// MARK: - Seed

// generates a random seed, saves to keychain and returns the associated seedPhrase
+ (NSString *)generateRandomSeedPhraseForLanguage:(DSBIP39Language)language {
    NSMutableData *entropy = [NSMutableData secureDataWithLength:SEED_ENTROPY_LENGTH];
    if (SecRandomCopyBytes(kSecRandomDefault, entropy.length, entropy.mutableBytes) != 0) return nil;
    if (language != DSBIP39Language_Default) {
        [[DSBIP39Mnemonic sharedInstance] setDefaultLanguage:language];
    }
    return [[DSBIP39Mnemonic sharedInstance] encodePhrase:entropy];
}

+ (NSString *)generateRandomSeedPhrase {
    return [self generateRandomSeedPhraseForLanguage:DSBIP39Language_Default];
}

- (void)seedPhraseAfterAuthentication:(void (^)(NSString *_Nullable))completion {
    [self seedPhraseAfterAuthenticationWithPrompt:nil completion:completion];
}

- (BOOL)hasSeedPhrase {
    NSError *error = nil;
    return hasKeychainData(self.uniqueIDString, &error);
}

+ (NSString *)setTransientDerivedKeyData:(NSData *)derivedKeyData withAccounts:(NSArray *)accounts forChain:(DSChain *)chain {
    if (!derivedKeyData) return nil;
    NSString *uniqueID = nil;
    @autoreleasepool { // @autoreleasepool ensures sensitive data will be deallocated immediately
        // we store the wallet creation time on the keychain because keychain data persists even when an app is deleted
        Slice_u8 *derived_key_data = slice_ctor(derivedKeyData);
        uint64_t unique_id = DECDSAPublicKeyUniqueIdFromDerivedKeyData(derived_key_data, chain.chainType);
        uniqueID = [NSString stringWithFormat:@"%0llx", unique_id];
        for (DSAccount *account in accounts) {
            for (DSDerivationPath *derivationPath in account.fundDerivationPaths) {
                [derivationPath generateExtendedPublicKeyFromSeed:derivedKeyData storeUnderWalletUniqueId:nil];
            }
            if ([chain isEvolutionEnabled]) {
                [account.masterContactsDerivationPath generateExtendedPublicKeyFromSeed:derivedKeyData storeUnderWalletUniqueId:nil];
            }
        }
    }
    return uniqueID;
}

+ (NSString *)setSeedPhrase:(NSString *)seedPhrase createdAt:(NSTimeInterval)createdAt withAccounts:(NSArray *)accounts storeOnKeychain:(BOOL)storeOnKeychain forChain:(DSChain *)chain {
    if (!seedPhrase) return nil;
    NSString *uniqueID = nil;
    @autoreleasepool { // @autoreleasepool ensures sensitive data will be deallocated immediately
        // we store the wallet creation time on the keychain because keychain data persists even when an app is deleted
        seedPhrase = [[DSBIP39Mnemonic sharedInstance] normalizePhrase:seedPhrase];

        NSData *derivedKeyData = (seedPhrase) ? [[DSBIP39Mnemonic sharedInstance]
                                                    deriveKeyFromPhrase:seedPhrase
                                                         withPassphrase:nil] :
                                                nil;
        Slice_u8 *derived_key_data = slice_ctor(derivedKeyData);
        uint64_t unique_id = DECDSAPublicKeyUniqueIdFromDerivedKeyData(derived_key_data, chain.chainType);
        uniqueID = [NSString stringWithFormat:@"%0llx", unique_id];
        NSLog(@"[DSWallet] setSeedPhrase: unique_id %@", uniqueID);

        NSString *storeOnUniqueId = nil;
        //if not store on keychain then we wont save the extended public keys below.
        if (storeOnKeychain) {
            if (!setKeychainString(seedPhrase, [DSWallet mnemonicUniqueIDForUniqueID:uniqueID], YES) || (createdAt && !setKeychainData([NSData dataWithBytes:&createdAt length:sizeof(createdAt)], [DSWallet creationTimeUniqueIDForUniqueID:uniqueID], NO))) {
                NSAssert(FALSE, @"error setting wallet seed");
                return nil;
            }

            //in version 2.0.0 wallet creation times were migrated from reference date, since this is now fixed just add this line so verification only happens once
            setKeychainInt(1, [DSWallet didVerifyCreationTimeUniqueIDForUniqueID:uniqueID], NO);
            storeOnUniqueId = uniqueID;
        }

        for (DSAccount *account in accounts) {
            for (DSDerivationPath *derivationPath in account.fundDerivationPaths) {
                [derivationPath generateExtendedPublicKeyFromSeed:derivedKeyData storeUnderWalletUniqueId:storeOnUniqueId];
            }
            if ([chain isEvolutionEnabled]) {
                [account.masterContactsDerivationPath generateExtendedPublicKeyFromSeed:derivedKeyData storeUnderWalletUniqueId:storeOnUniqueId];
            }
        }
    }
    return uniqueID;
}

// authenticates user and returns seed
- (void)seedWithPrompt:(NSString *)authprompt forAmount:(uint64_t)amount completion:(_Nullable SeedCompletionBlock)completion {
    @autoreleasepool {
        if (!authprompt && [DSAuthenticationManager sharedInstance].didAuthenticate) {
            completion([[DSBIP39Mnemonic sharedInstance] deriveKeyFromPhrase:getKeychainString(self.mnemonicUniqueID, nil) withPassphrase:nil], NO);
            return;
        }

        BOOL usingBiometricAuthentication = amount ? [[DSAuthenticationManager sharedInstance] canUseBiometricAuthenticationForAmount:amount] : NO;

//        __weak typeof(self) weakSelf = self;
        [[DSAuthenticationManager sharedInstance] authenticateWithPrompt:authprompt
                                            usingBiometricAuthentication:usingBiometricAuthentication
                                                          alertIfLockout:YES
                                                              completion:^(BOOL authenticated, BOOL usedBiometrics, BOOL cancelled) {
            if (!authenticated) {
                completion(nil, cancelled);
            } else {
                if (usedBiometrics) {
                    BOOL loweredAmountSuccessfully = [[DSAuthenticationManager sharedInstance] updateBiometricsAmountLeftAfterSpendingAmount:amount];
                    if (!loweredAmountSuccessfully) {
                        completion(nil, cancelled);
                        return;
                    }
                }
                completion([self requestSeedNoAuth], cancelled);
            }
        }];
    }
}

- (NSString *)seedPhraseIfAuthenticated {
    return ![DSAuthenticationManager sharedInstance].usesAuthentication || [DSAuthenticationManager sharedInstance].didAuthenticate ? [self seedPhrase] : nil;
}

- (NSString *)seedPhrase {
    return getKeychainString(self.mnemonicUniqueID, nil);
}

// authenticates user and returns seedPhrase
- (void)seedPhraseAfterAuthenticationWithPrompt:(NSString *)authprompt completion:(void (^)(NSString *seedPhrase))completion {
    @autoreleasepool {
        [[DSAuthenticationManager sharedInstance] authenticateWithPrompt:authprompt
                                            usingBiometricAuthentication:NO
                                                          alertIfLockout:YES
                                                              completion:^(BOOL authenticated, BOOL usedBiometrics, BOOL cancelled) {
            completion(authenticated ? getKeychainString(self.mnemonicUniqueID, nil) : nil);
        }];
    }
}

// MARK: - Authentication

// private key for signing authenticated api calls

- (void)authPrivateKey:(void (^_Nullable)(NSString *_Nullable authKey))completion {
    @autoreleasepool {
        self.secureSeedRequestBlock(@"Please authorize", 0, ^(NSData *_Nullable seed, BOOL cancelled) {
            @autoreleasepool {
                NSString *privKey = getKeychainString(AUTH_PRIVKEY_KEY, nil);
                if (!privKey) {
                    privKey = [DSKeyManager NSStringFrom:DECDSAKeySerializedAuthPrivateKeyFromSeed(slice_ctor(seed), self.chain.chainType)];
                    setKeychainString(privKey, AUTH_PRIVKEY_KEY, NO);
                }
                completion(privKey);
            }
        });
    }
}

// MARK: - Combining Accounts

- (uint64_t)balance {
    uint64_t rBalance = 0;
    for (DSAccount *account in self.accounts) {
        rBalance += account.balance;
    }
    return rBalance;
}

- (NSArray *)registerAddressesWithGapLimit:(NSUInteger)gapLimit
                     unusedAccountGapLimit:(NSUInteger)unusedAccountGapLimit
                           dashpayGapLimit:(NSUInteger)dashpayGapLimit
                          coinJoinGapLimit:(NSUInteger)coinJoinGapLimit
                                  internal:(BOOL)internal
                                     error:(NSError **)error {
    NSMutableArray *mArray = [NSMutableArray array];
    for (DSAccount *account in self.accounts) {
        [mArray addObjectsFromArray:[account registerAddressesWithGapLimit:gapLimit unusedAccountGapLimit:unusedAccountGapLimit dashpayGapLimit:dashpayGapLimit coinJoinGapLimit:coinJoinGapLimit internal:internal error:error]];
    }
    return [mArray copy];
}

- (DSAccount *)firstAccountThatCanContainTransaction:(DSTransaction *)transaction {
    NSParameterAssert(transaction);
    for (DSAccount *account in self.accounts) {
        if ([account canContainTransaction:transaction]) return account;
    }
    return FALSE;
}

- (NSArray *)accountsThatCanContainTransaction:(DSTransaction *)transaction {
    NSParameterAssert(transaction);

    NSMutableArray *mArray = [NSMutableArray array];
    for (DSAccount *account in self.accounts) {
        if ([account canContainTransaction:transaction]) [mArray addObject:account];
    }
    return [mArray copy];
}
//- (NSArray *)accountsThatCanContainRustTransaction:(Result_ok_dashcore_blockdata_transaction_Transaction_err_dash_spv_platform_error_Error *)transaction {
//    NSParameterAssert(transaction);
//
//    NSMutableArray *mArray = [NSMutableArray array];
//    for (DSAccount *account in self.accounts) {
//        if ([account canContainRustTransaction:transaction]) [mArray addObject:account];
//    }
//    return [mArray copy];
//}

// all previously generated external addresses
- (NSSet *)allReceiveAddresses {
    NSMutableSet *mSet = [NSMutableSet set];
    for (DSAccount *account in self.accounts) {
        [mSet addObjectsFromArray:[account externalAddresses]];
    }
    return [mSet copy];
}

// all previously generated internal addresses
- (NSSet *)allChangeAddresses {
    NSMutableSet *mSet = [NSMutableSet set];
    for (DSAccount *account in self.accounts) {
        [mSet addObjectsFromArray:[account internalAddresses]];
    }
    return [mSet copy];
}

- (NSArray *)allTransactions {
    NSMutableSet *mSet = [NSMutableSet set];
    for (DSAccount *account in self.accounts) {
        [mSet addObjectsFromArray:[account.allTransactions copy]];
    }
    [mSet addObjectsFromArray:[self.specialTransactionsHolder allTransactions]];
    return [mSet allObjects];
}

- (NSArray *)allTransactionsForAccount:(DSAccount *)account {
    NSMutableSet *mSet = [NSMutableSet set];
    [mSet addObjectsFromArray:[account.allTransactions copy]];
    [mSet addObjectsFromArray:[self.specialTransactionsHolder allTransactions]];
    return [mSet allObjects];
}

- (DSTransaction *)transactionForHash:(UInt256)txHash {
    for (DSAccount *account in self.accounts) {
        DSTransaction *transaction = [account transactionForHash:txHash];
        if (transaction) return transaction;
    }
    DSTransaction *transaction = [self.specialTransactionsHolder transactionForHash:txHash];
    if (transaction) return transaction;
    return nil;
}

- (NSArray *)unspentOutputs {
    NSMutableArray *mArray = [NSMutableArray array];
    for (DSAccount *account in self.accounts) {
        [mArray addObjectsFromArray:account.unspentOutputs];
    }
    return mArray;
}

// true if the address is controlled by the wallet, this can also be for paths that are not accounts (todo)
- (BOOL)containsAddress:(NSString *)address {
    NSParameterAssert(address);
    for (DSAccount *account in self.accounts) {
        if ([account containsAddress:address]) return TRUE;
    }
    return FALSE;
}

// true if the address is controlled by the wallet, this can also be for paths that are not accounts (todo)
- (BOOL)accountsBaseDerivationPathsContainAddress:(NSString *)address {
    NSParameterAssert(address);
    for (DSAccount *account in self.accounts) {
        if ([account baseDerivationPathsContainAddress:address]) return TRUE;
    }
    return FALSE;
}

// returns the first account with a balance
- (DSAccount *_Nullable)firstAccountWithBalance {
    for (DSAccount *account in self.accounts) {
        if ([account balance]) return account;
    }
    return nil;
}

- (DSAccount *)accountForAddress:(NSString *)address {
    NSParameterAssert(address);
    for (DSAccount *account in self.accounts) {
        if ([account containsAddress:address]) return account;
    }
    return nil;
}

- (DSAccount *)accountForDashpayExternalDerivationPathAddress:(NSString *)address {
    NSParameterAssert(address);
    for (DSAccount *account in self.accounts) {
        if ([account externalDerivationPathContainingAddress:address]) return account;
    }
    return nil;
}

// true if the address was previously used as an input or output in any wallet transaction
- (BOOL)addressIsUsed:(NSString *)address {
    NSParameterAssert(address);
    for (DSAccount *account in self.accounts) {
        if ([account addressIsUsed:address]) return TRUE;
    }
    return FALSE;
}

- (BOOL)transactionAddressAlreadySeenInOutputs:(NSString *)address {
    NSParameterAssert(address);
    for (DSAccount *account in self.accounts) {
        if ([account transactionAddressAlreadySeenInOutputs:address]) return TRUE;
    }
    return FALSE;
}

// returns the amount received by the wallet from the transaction (total outputs to change and/or receive addresses)
- (uint64_t)amountReceivedFromTransaction:(DSTransaction *)transaction {
    NSParameterAssert(transaction);
    uint64_t received = 0;
    for (DSAccount *account in self.accounts) {
        received += [account amountReceivedFromTransaction:transaction];
    }
    return received;
}

// retuns the amount sent from the wallet by the trasaction (total wallet outputs consumed, change and fee included)
- (uint64_t)amountSentByTransaction:(DSTransaction *)transaction {
    NSParameterAssert(transaction);
    uint64_t sent = 0;
    for (DSAccount *account in self.accounts) {
        sent += [account amountSentByTransaction:transaction];
    }
    return sent;
}

// set the block heights and timestamps for the given transactions, use a height of TX_UNCONFIRMED and timestamp of 0 to
// indicate a transaction and it's dependents should remain marked as unverified (not 0-conf safe)
- (NSArray *)setBlockHeight:(int32_t)height andTimestamp:(NSTimeInterval)timestamp forTransactionHashes:(NSArray *)txHashes {
    NSParameterAssert(txHashes);
    if (![txHashes count]) return @[];

    NSMutableArray *updated = [NSMutableArray array];

    for (DSAccount *account in self.accounts) {
        NSArray *fromAccount = [account setBlockHeight:height andTimestamp:timestamp forTransactionHashes:txHashes];
        if (fromAccount) {
            [updated addObjectsFromArray:fromAccount];
        } else {
            [self chainUpdatedBlockHeight:height];
        }
    }
    [self.specialTransactionsHolder setBlockHeight:height
                                      andTimestamp:timestamp
                              forTransactionHashes:txHashes];
    return [updated copy];
}

// this is used to save transactions atomically with the block, needs to be called before switching threads to save the block
- (void)prepareForIncomingTransactionPersistenceForBlockSaveWithNumber:(uint32_t)blockNumber {
    for (DSAccount *account in self.accounts) {
        [account prepareForIncomingTransactionPersistenceForBlockSaveWithNumber:blockNumber];
    }
    [self.specialTransactionsHolder prepareForIncomingTransactionPersistenceForBlockSaveWithNumber:blockNumber];
}

// this is used to save transactions atomically with the block
- (void)persistIncomingTransactionsAttributesForBlockSaveWithNumber:(uint32_t)blockNumber inContext:(NSManagedObjectContext *)context {
    for (DSAccount *account in self.accounts) {
        [account persistIncomingTransactionsAttributesForBlockSaveWithNumber:blockNumber inContext:context];
    }
    [self.specialTransactionsHolder persistIncomingTransactionsAttributesForBlockSaveWithNumber:blockNumber
                                                                                      inContext:context];
}

- (void)chainUpdatedBlockHeight:(int32_t)height {
    for (DSAccount *account in self.accounts) {
        [account chainUpdatedBlockHeight:height];
    }
}

- (DSAccount *)accountForTransactionHash:(UInt256)txHash transaction:(DSTransaction **)transaction {
    for (DSAccount *account in self.accounts) {
        DSTransaction *lTransaction = [account transactionForHash:txHash];
        if (lTransaction) {
            if (transaction) *transaction = lTransaction;
            return account;
        }
    }
    return nil;
}

- (BOOL)transactionIsValid:(DSTransaction *_Nonnull)transaction {
    NSParameterAssert(transaction);

    for (DSAccount *account in self.accounts) {
        if (![account transactionIsValid:transaction]) return FALSE;
    }
    return TRUE;
}

- (int64_t)inputValue:(UInt256)txHash inputIndex:(uint32_t)index {
    for (DSAccount *account in self.accounts) {
        int64_t value = [account inputValue:txHash inputIndex:index];
        if (value != -1) return value;
    }
    return -1;
}

- (DMaybeOpaqueKey *)privateKeyForAddress:(NSString *)address fromSeed:(NSData *)seed {
    NSParameterAssert(address);
    NSParameterAssert(seed);

    DSAccount *account = [self accountForAddress:address];
    if (!account) return nil;
    DSFundsDerivationPath *derivationPath = (DSFundsDerivationPath *)[account derivationPathContainingAddress:address];
    if (!derivationPath) return nil;
    NSIndexPath *indexPath = [derivationPath indexPathForKnownAddress:address];
    return [derivationPath privateKeyAtIndexPath:indexPath fromSeed:seed];
}

- (NSString *)privateKeyAddressForAddress:(NSString *)address fromSeed:(NSData *)seed {
    DMaybeOpaqueKey *result = [self privateKeyForAddress:address fromSeed:seed];
    NSString *keyAddress = NULL;
    if (result) {
        if (result->ok) {
            char *c_string = DOpaqueKeyPubAddress(result->ok, self.chain.chainType);
            keyAddress = NSStringFromPtr(c_string);
            if (c_string) {
                DCharDtor(c_string);
            }
        }
        DMaybeOpaqueKeyDtor(result);
    }
    return keyAddress;
}

- (void)reloadDerivationPaths {
    for (DSAccount *account in self.accounts) {
        for (DSDerivationPath *derivationPath in account.fundDerivationPaths) {
            [derivationPath reloadAddresses];
        }
    }
    for (DSDerivationPath *derivationPath in self.specializedDerivationPaths) {
        [derivationPath reloadAddresses];
    }
}

- (NSArray *)specializedDerivationPaths {
    return [[DSDerivationPathFactory sharedInstance] loadedSpecializedDerivationPathsForWallet:self];
}

- (BOOL)hasAnExtendedPublicKeyMissing {
    for (DSAccount *account in self.accounts) {
        if ([account hasAnExtendedPublicKeyMissing]) return YES;
    }
    //todo add non funds derivation paths
    return NO;
}

// MARK: - Wiping

- (void)wipeBlockchainInfoInContext:(NSManagedObjectContext *)context {
    for (DSAccount *account in self.accounts) {
        [account wipeBlockchainInfo];
    }
    [self.specialTransactionsHolder removeAllTransactions];
    [self wipeIdentitiesInContext:context];
    [self wipeInvitationsInContext:context];
}

- (void)wipeBlockchainExtraAccountsInContext:(NSManagedObjectContext *)context {
    NSMutableArray *allAccountKeys = [[self.mAccounts allKeys] mutableCopy];
    [allAccountKeys removeObject:@(0)];
    if ([allAccountKeys containsObject:@(1)] && [[DSOptionsManager sharedInstance] syncType] & DSSyncType_MultiAccountAutoDiscovery) {
        [allAccountKeys removeObject:@(1)]; // In this case we want to keep account 1
    }
    if ([allAccountKeys count]) {
        [self.mAccounts removeObjectsForKeys:allAccountKeys];
    }
}


// MARK: - Masternodes (Providers)

- (NSArray *)providerOwnerAddresses {
    DSAuthenticationKeysDerivationPath *derivationPath = [[DSDerivationPathFactory sharedInstance] providerOwnerKeysDerivationPathForWallet:self];
    if (!derivationPath.hasExtendedPublicKey) return @[];
    return [derivationPath addressesToIndex:[self unusedProviderOwnerIndex] + 10 useCache:YES addToCache:YES];
}

- (uint32_t)unusedProviderOwnerIndex {
    NSArray *indexes = [_mMasternodeOwnerIndexes allValues];
    NSNumber *max = [indexes valueForKeyPath:@"@max.intValue"];
    return max != nil ? ([max unsignedIntValue] + 1) : 0;
}

- (NSArray *)providerVotingAddresses {
    DSAuthenticationKeysDerivationPath *derivationPath = [[DSDerivationPathFactory sharedInstance] providerVotingKeysDerivationPathForWallet:self];
    if (!derivationPath.hasExtendedPublicKey) return @[];
    return [derivationPath addressesToIndex:[self unusedProviderVotingIndex] + 10 useCache:YES addToCache:YES];
}

- (uint32_t)unusedProviderVotingIndex {
    NSArray *indexes = [_mMasternodeVoterIndexes allValues];
    NSNumber *max = [indexes valueForKeyPath:@"@max.intValue"];
    return max != nil ? ([max unsignedIntValue] + 1) : 0;
}

- (NSArray *)providerOperatorAddresses {
    DSAuthenticationKeysDerivationPath *derivationPath = [[DSDerivationPathFactory sharedInstance] providerOperatorKeysDerivationPathForWallet:self];
    if (!derivationPath.hasExtendedPublicKey) return @[];
    return [derivationPath addressesToIndex:[self unusedProviderOperatorIndex] + 10 useCache:YES addToCache:YES];
}

- (uint32_t)unusedProviderOperatorIndex {
    NSArray *indexes = [_mMasternodeOperatorIndexes allValues];
    NSNumber *max = [indexes valueForKeyPath:@"@max.intValue"];
    return max != nil ? ([max unsignedIntValue] + 1) : 0;
}

- (NSArray *)platformNodeAddresses {
    DSAuthenticationKeysDerivationPath *derivationPath = [[DSDerivationPathFactory sharedInstance] platformNodeKeysDerivationPathForWallet:self];
    if (!derivationPath.hasExtendedPublicKey) return @[];
    return [derivationPath addressesToIndex:[self unusedPlatformNodeIndex] + 10 useCache:YES addToCache:YES];
}

- (uint32_t)unusedPlatformNodeIndex {
    NSArray *indexes = [_mPlatformNodeIndexes allValues];
    NSNumber *max = [indexes valueForKeyPath:@"@max.intValue"];
    return max != nil ? ([max unsignedIntValue] + 1) : 0;
}

- (void)registerMasternodeOperator:(DSLocalMasternode *)masternode {
    NSParameterAssert(masternode);
    if ([self.mMasternodeOperatorIndexes objectForKey:uint256_data(masternode.providerRegistrationTransaction.txHash)] == nil) {
        [self.mMasternodeOperatorIndexes setObject:@(masternode.operatorWalletIndex) forKey:uint256_data(masternode.providerRegistrationTransaction.txHash)];
        NSError *error = nil;
        NSMutableDictionary *keyChainDictionary = [getKeychainDict(self.walletMasternodeOperatorsKey, @[[NSNumber class], [NSData class]], &error) mutableCopy];
        if (!keyChainDictionary) keyChainDictionary = [NSMutableDictionary dictionary];
        keyChainDictionary[uint256_data(masternode.providerRegistrationTransaction.txHash)] = @(masternode.operatorWalletIndex);
        setKeychainDict(keyChainDictionary, self.walletMasternodeOperatorsKey, NO);
    }
}

- (void)registerMasternodeOperator:(DSLocalMasternode *)masternode withOperatorPublicKey:(DOpaqueKey *)operatorKey {
    NSParameterAssert(masternode);
    if ([self.mMasternodeOperatorPublicKeyLocations objectForKey:uint256_data(masternode.providerRegistrationTransaction.txHash)] == nil) {
        NSData *publicKeyData = [DSKeyManager publicKeyData:operatorKey];
        NSData *hashedOperatorKey = [NSData dataWithUInt256:publicKeyData.SHA256];
        NSString *operatorKeyStorageLocation = [NSString stringWithFormat:@"DS_OPERATOR_KEY_LOC_%@", hashedOperatorKey.hexString];
        [self.mMasternodeOperatorPublicKeyLocations setObject:operatorKeyStorageLocation forKey:uint256_data(masternode.providerRegistrationTransaction.txHash)];
        NSError *error = nil;
        NSMutableDictionary *keyChainDictionary = [getKeychainDict(self.walletMasternodeOperatorsKey, @[[NSNumber class], [NSData class]], &error) mutableCopy];
        if (!keyChainDictionary) keyChainDictionary = [NSMutableDictionary dictionary];
        keyChainDictionary[uint256_data(masternode.providerRegistrationTransaction.txHash)] = hashedOperatorKey;
        setKeychainDict(keyChainDictionary, self.walletMasternodeOperatorsKey, NO);
        setKeychainData(publicKeyData, operatorKeyStorageLocation, NO);
    }
}

- (void)registerMasternodeOwner:(DSLocalMasternode *)masternode {
    NSParameterAssert(masternode);
    if ([self.mMasternodeOwnerIndexes objectForKey:uint256_data(masternode.providerRegistrationTransaction.txHash)] == nil && masternode.ownerWalletIndex != UINT32_MAX) {
        [self.mMasternodeOwnerIndexes setObject:@(masternode.ownerWalletIndex) forKey:uint256_data(masternode.providerRegistrationTransaction.txHash)];
        NSError *error = nil;
        NSMutableDictionary *keyChainDictionary = [getKeychainDict(self.walletMasternodeOwnersKey, @[[NSNumber class], [NSData class]], &error) mutableCopy];
        if (!keyChainDictionary) keyChainDictionary = [NSMutableDictionary dictionary];
        keyChainDictionary[uint256_data(masternode.providerRegistrationTransaction.txHash)] = @(masternode.ownerWalletIndex);
        setKeychainDict(keyChainDictionary, self.walletMasternodeOwnersKey, NO);
    }
}

- (void)registerMasternodeOwner:(DSLocalMasternode *)masternode withOwnerPrivateKey:(DOpaqueKey *)ownerKey {
    NSParameterAssert(masternode);

    if ([self.mMasternodeOwnerPrivateKeyLocations objectForKey:uint256_data(masternode.providerRegistrationTransaction.txHash)] == nil) {
        NSData *publicKeyData = [DSKeyManager publicKeyData:ownerKey];
        NSData *hashedOwnerKey = [NSData dataWithUInt256:publicKeyData.SHA256];
        NSString *ownerKeyStorageLocation = [NSString stringWithFormat:@"DS_OWNER_KEY_LOC_%@", hashedOwnerKey.hexString];
        [self.mMasternodeOwnerPrivateKeyLocations setObject:ownerKeyStorageLocation forKey:uint256_data(masternode.providerRegistrationTransaction.txHash)];
        NSError *error = nil;
        NSMutableDictionary *keyChainDictionary = [getKeychainDict(self.walletMasternodeOwnersKey, @[[NSNumber class], [NSData class]], &error) mutableCopy];
        if (!keyChainDictionary) keyChainDictionary = [NSMutableDictionary dictionary];
        keyChainDictionary[uint256_data(masternode.providerRegistrationTransaction.txHash)] = hashedOwnerKey;
        setKeychainDict(keyChainDictionary, self.walletMasternodeOwnersKey, NO);
        setKeychainData([DSKeyManager privateKeyData:ownerKey], ownerKeyStorageLocation, NO);
    }
}
- (void)registerMasternodeVoter:(DSLocalMasternode *)masternode {
    NSParameterAssert(masternode);

    if ([self.mMasternodeVoterIndexes objectForKey:uint256_data(masternode.providerRegistrationTransaction.txHash)] == nil) {
        [self.mMasternodeVoterIndexes setObject:@(masternode.votingWalletIndex) forKey:uint256_data(masternode.providerRegistrationTransaction.txHash)];
        NSError *error = nil;
        NSMutableDictionary *keyChainDictionary = [getKeychainDict(self.walletMasternodeVotersKey, @[[NSNumber class], [NSData class]], &error) mutableCopy];
        if (!keyChainDictionary) keyChainDictionary = [NSMutableDictionary dictionary];
        keyChainDictionary[uint256_data(masternode.providerRegistrationTransaction.txHash)] = @(masternode.votingWalletIndex);
        setKeychainDict(keyChainDictionary, self.walletMasternodeVotersKey, NO);
    }
}

- (void)registerMasternodeVoter:(DSLocalMasternode *)masternode withVotingKey:(DOpaqueKey *)votingKey {
    if ([self.mMasternodeVoterKeyLocations objectForKey:uint256_data(masternode.providerRegistrationTransaction.txHash)] == nil) {
        NSData *publicKeyData = [DSKeyManager publicKeyData:votingKey];
        NSData *hashedVoterKey = [NSData dataWithUInt256:publicKeyData.SHA256];
        NSString *votingKeyStorageLocation = [NSString stringWithFormat:@"DS_VOTING_KEY_LOC_%@", hashedVoterKey.hexString];
        [self.mMasternodeVoterKeyLocations setObject:votingKeyStorageLocation forKey:uint256_data(masternode.providerRegistrationTransaction.txHash)];
        NSError *error = nil;
        NSMutableDictionary *keyChainDictionary = [getKeychainDict(self.walletMasternodeVotersKey, @[[NSNumber class], [NSData class]], &error) mutableCopy];
        if (!keyChainDictionary) keyChainDictionary = [NSMutableDictionary dictionary];
        keyChainDictionary[uint256_data(masternode.providerRegistrationTransaction.txHash)] = hashedVoterKey;
        setKeychainDict(keyChainDictionary, self.walletMasternodeVotersKey, NO);
        if ([DSKeyManager hasPrivateKey:votingKey]) {
            setKeychainData([DSKeyManager privateKeyData:votingKey], votingKeyStorageLocation, NO);
        } else {
            setKeychainData(publicKeyData, votingKeyStorageLocation, NO);
        }
    }
}

- (void)registerPlatformNode:(DSLocalMasternode *)masternode {
    NSParameterAssert(masternode);
    if ([self.mPlatformNodeIndexes objectForKey:uint256_data(masternode.providerRegistrationTransaction.txHash)] == nil && masternode.platformNodeWalletIndex != UINT32_MAX) {
        [self.mPlatformNodeIndexes setObject:@(masternode.platformNodeWalletIndex) forKey:uint256_data(masternode.providerRegistrationTransaction.txHash)];
        NSError *error = nil;
        NSMutableDictionary *keyChainDictionary = [getKeychainDict(self.walletPlatformNodesKey, @[[NSNumber class], [NSData class]], &error) mutableCopy];
        if (!keyChainDictionary) keyChainDictionary = [NSMutableDictionary dictionary];
        keyChainDictionary[uint256_data(masternode.providerRegistrationTransaction.txHash)] = @(masternode.platformNodeWalletIndex);
        setKeychainDict(keyChainDictionary, self.walletPlatformNodesKey, NO);
    }
}

- (void)registerPlatformNode:(DSLocalMasternode *)masternode withKey:(DOpaqueKey *)key {
    NSParameterAssert(masternode);

    if ([self.mPlatformNodeKeyLocations objectForKey:uint256_data(masternode.providerRegistrationTransaction.txHash)] == nil) {
        NSData *publicKeyData = [DSKeyManager publicKeyData:key];
        NSData *hashedPlatformNodeKey = [NSData dataWithUInt256:publicKeyData.SHA256];
        NSString *platformNodeKeyStorageLocation = [NSString stringWithFormat:@"DS_PLATFORM_NODE_KEY_LOC_%@", hashedPlatformNodeKey.hexString];
        [self.mPlatformNodeKeyLocations setObject:platformNodeKeyStorageLocation forKey:uint256_data(masternode.providerRegistrationTransaction.txHash)];
        NSError *error = nil;
        NSMutableDictionary *keyChainDictionary = [getKeychainDict(self.walletPlatformNodesKey, @[[NSNumber class], [NSData class]], &error) mutableCopy];
        if (!keyChainDictionary) keyChainDictionary = [NSMutableDictionary dictionary];
        keyChainDictionary[uint256_data(masternode.providerRegistrationTransaction.txHash)] = hashedPlatformNodeKey;
        setKeychainDict(keyChainDictionary, self.walletPlatformNodesKey, NO);
        // TODO: check what to store (private vs. public key data)
        setKeychainData([DSKeyManager privateKeyData:key], platformNodeKeyStorageLocation, NO);
    }
}

- (BOOL)containsProviderVotingAuthenticationHash:(UInt160)hash {
    return [[DSAuthenticationKeysDerivationPath providerVotingKeysDerivationPathForWallet:self] containsAddressHash:hash];
}

- (BOOL)containsProviderOwningAuthenticationHash:(UInt160)hash {
    return [[DSAuthenticationKeysDerivationPath providerOwnerKeysDerivationPathForWallet:self] containsAddressHash:hash];
}

- (BOOL)containsProviderOperatorAuthenticationKey:(UInt384)providerOperatorAuthenticationKey {
    UInt160 hash = [[NSData dataWithUInt384:providerOperatorAuthenticationKey] hash160];
    return [[DSAuthenticationKeysDerivationPath providerOperatorKeysDerivationPathForWallet:self] containsAddressHash:hash];
}

- (BOOL)containsPlatformNodeAuthenticationHash:(UInt160)hash {
    return [[DSAuthenticationKeysDerivationPath platformNodeKeysDerivationPathForWallet:self] containsAddressHash:hash];
}

- (BOOL)containsIdentityBLSAuthenticationHash:(UInt160)hash {
    return [[DSAuthenticationKeysDerivationPath identitiesBLSKeysDerivationPathForWallet:self] containsAddressHash:hash];
}

- (BOOL)containsHoldingAddress:(NSString *)holdingAddress {
    NSParameterAssert(holdingAddress);
    return [[DSMasternodeHoldingsDerivationPath providerFundsDerivationPathForWallet:self] containsAddress:holdingAddress];
}

- (NSUInteger)indexOfProviderVotingAuthenticationHash:(UInt160)hash {
    return [[DSAuthenticationKeysDerivationPath providerVotingKeysDerivationPathForWallet:self] indexOfKnownAddressHash:hash];
}

- (NSUInteger)indexOfProviderOwningAuthenticationHash:(UInt160)hash {
    return [[DSAuthenticationKeysDerivationPath providerOwnerKeysDerivationPathForWallet:self] indexOfKnownAddressHash:hash];
}

- (NSUInteger)indexOfProviderOperatorAuthenticationKey:(UInt384)providerOperatorAuthenticationKey {
    return [[DSAuthenticationKeysDerivationPath providerOperatorKeysDerivationPathForWallet:self] indexOfKnownAddressHash:[[NSData dataWithUInt384:providerOperatorAuthenticationKey] hash160]];
}

- (NSUInteger)indexOfPlatformNodeAuthenticationHash:(UInt160)hash {
    return [[DSAuthenticationKeysDerivationPath platformNodeKeysDerivationPathForWallet:self] indexOfKnownAddressHash:hash];
}

- (NSUInteger)indexOfHoldingAddress:(NSString *)holdingAddress {
    NSParameterAssert(holdingAddress);
    return [[DSMasternodeHoldingsDerivationPath providerFundsDerivationPathForWallet:self] indexOfKnownAddress:holdingAddress];
}

@end
