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
#import "DSAccountEntity+CoreDataClass.h"
#import "DSAddressEntity+CoreDataProperties.h"
#import "DSAuthenticationKeysDerivationPath+Protected.h"
#import "DSAuthenticationManager+Private.h"
#import "DSAuthenticationManager.h"
#import "DSBIP39Mnemonic.h"
#import "DSBlockchainIdentity+Protected.h"
#import "DSBlockchainIdentityEntity+CoreDataClass.h"
#import "DSBlockchainIdentityKeyPathEntity+CoreDataClass.h"
#import "DSBlockchainIdentityRegistrationTransition.h"
#import "DSBlockchainIdentityUpdateTransition.h"
#import "DSBlockchainIdentityUsernameEntity+CoreDataClass.h"
#import "DSBlockchainInvitation+Protected.h"
#import "DSChain+Protected.h"
#import "DSChainsManager.h"
#import "DSCreditFundingDerivationPath+Protected.h"
#import "DSCreditFundingTransaction.h"
#import "DSCreditFundingTransactionEntity+CoreDataClass.h"
#import "DSDashpayUserEntity+CoreDataClass.h"
#import "DSDerivationPathEntity+CoreDataClass.h"
#import "DSDerivationPathFactory.h"
#import "DSEnvironment.h"
#import "DSFriendRequestEntity+CoreDataClass.h"
#import "DSIncomingFundsDerivationPath.h"
#import "DSLocalMasternode.h"
#import "DSMasternodeHoldingsDerivationPath+Protected.h"
#import "DSOptionsManager.h"
#import "DSPriceManager.h"
#import "DSProviderRegistrationTransaction.h"
#import "DSSpecialTransactionsWalletHolder.h"
#import "DSTransactionEntity+CoreDataProperties.h"
#import "DSWallet+Protected.h"
#import "NSData+Dash.h"
#import "NSDate+Utils.h"
#import "NSManagedObject+Sugar.h"
#import "NSMutableData+Dash.h"

#define SEED_ENTROPY_LENGTH (128 / 8)
#define WALLET_CREATION_TIME_KEY @"WALLET_CREATION_TIME_KEY"
#define WALLET_CREATION_GUESS_TIME_KEY @"WALLET_CREATION_GUESS_TIME_KEY"
#define AUTH_PRIVKEY_KEY @"authprivkey"
#define WALLET_MNEMONIC_KEY @"WALLET_MNEMONIC_KEY"
#define WALLET_MASTER_PUBLIC_KEY @"WALLET_MASTER_PUBLIC_KEY"
#define WALLET_BLOCKCHAIN_USERS_KEY @"WALLET_BLOCKCHAIN_USERS_KEY"
#define WALLET_BLOCKCHAIN_INVITATIONS_KEY @"WALLET_BLOCKCHAIN_INVITATIONS_KEY"

#define WALLET_ACCOUNTS_KNOWN_KEY @"WALLET_ACCOUNTS_KNOWN_KEY"

#define WALLET_MASTERNODE_VOTERS_KEY @"WALLET_MASTERNODE_VOTERS_KEY"
#define WALLET_MASTERNODE_OWNERS_KEY @"WALLET_MASTERNODE_OWNERS_KEY"
#define WALLET_MASTERNODE_OPERATORS_KEY @"WALLET_MASTERNODE_OPERATORS_KEY"
#define WALLET_PLATFORM_NODES_KEY @"WALLET_PLATFORM_NODES_KEY"

#define VERIFIED_WALLET_CREATION_TIME_KEY @"VERIFIED_WALLET_CREATION_TIME"
#define REFERENCE_DATE_2001 978307200

#define IDENTITY_INDEX_KEY @"IDENTITY_INDEX_KEY"
#define IDENTITY_LOCKED_OUTPUT_KEY @"IDENTITY_LOCKED_OUTPUT_KEY"

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
@property (nonatomic, strong) NSMutableDictionary<NSData *, DSBlockchainIdentity *> *mBlockchainIdentities;
@property (nonatomic, strong) NSMutableDictionary<NSData *, DSBlockchainInvitation *> *mBlockchainInvitations;

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
    self.mBlockchainIdentities = [NSMutableDictionary dictionary];
    self.mMasternodeOwnerIndexes = [NSMutableDictionary dictionary];
    self.mMasternodeVoterIndexes = [NSMutableDictionary dictionary];
    self.mMasternodeOperatorIndexes = [NSMutableDictionary dictionary];
    self.mMasternodeOwnerPrivateKeyLocations = [NSMutableDictionary dictionary];
    self.mMasternodeVoterKeyLocations = [NSMutableDictionary dictionary];
    self.mMasternodeOperatorPublicKeyLocations = [NSMutableDictionary dictionary];
    self.checkedWalletCreationTime = NO;
    self.checkedGuessedWalletCreationTime = NO;
    self.checkedVerifyWalletCreationTime = NO;
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

    self.mBlockchainIdentities = nil;
    self.mBlockchainInvitations = nil;
    [self blockchainIdentities];
    [self blockchainInvitations];

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

- (void)loadBlockchainIdentities {
    [self.chain.chainManagedObjectContext performBlockAndWait:^{
        NSMutableArray *usedFriendshipIdentifiers = [NSMutableArray array];
        for (NSData *blockchainIdentityData in self.mBlockchainIdentities) {
            DSBlockchainIdentity *blockchainIdentity = [self.mBlockchainIdentities objectForKey:blockchainIdentityData];
            NSSet *outgoingRequests = [blockchainIdentity matchingDashpayUserInContext:self.chain.chainManagedObjectContext].outgoingRequests;
            for (DSFriendRequestEntity *friendRequest in outgoingRequests) {
                DSAccount *account = [self accountWithNumber:friendRequest.account.index];
                DSIncomingFundsDerivationPath *fundsDerivationPath = [DSIncomingFundsDerivationPath
                    contactBasedDerivationPathWithDestinationBlockchainIdentityUniqueId:friendRequest.destinationContact.associatedBlockchainIdentity.uniqueID.UInt256
                                                       sourceBlockchainIdentityUniqueId:blockchainIdentity.uniqueID
                                                                       forAccountNumber:account.accountNumber
                                                                                onChain:self.chain];
                fundsDerivationPath.standaloneExtendedPublicKeyUniqueID = friendRequest.derivationPath.publicKeyIdentifier;
                fundsDerivationPath.wallet = self;
                fundsDerivationPath.account = account;
                //DSLogPrivate(@"%@",blockchainIdentity.matchingDashpayUser.outgoingRequests);
                [account addIncomingDerivationPath:fundsDerivationPath forFriendshipIdentifier:friendRequest.friendshipIdentifier inContext:self.chain.chainManagedObjectContext];
                [usedFriendshipIdentifiers addObject:friendRequest.friendshipIdentifier];
            }
        }

        for (NSData *blockchainUniqueIdData in self.mBlockchainIdentities) {
            DSBlockchainIdentity *blockchainIdentity = [self.mBlockchainIdentities objectForKey:blockchainUniqueIdData];
            NSSet *incomingRequests = [blockchainIdentity matchingDashpayUserInContext:self.chain.chainManagedObjectContext].incomingRequests;
            for (DSFriendRequestEntity *friendRequest in incomingRequests) {
                DSAccount *account = [self accountWithNumber:friendRequest.account.index];
                DSIncomingFundsDerivationPath *fundsDerivationPath = [account derivationPathForFriendshipWithIdentifier:friendRequest.friendshipIdentifier];
                if (fundsDerivationPath) {
                    //both contacts are on device
                    [account addOutgoingDerivationPath:fundsDerivationPath forFriendshipIdentifier:friendRequest.friendshipIdentifier inContext:self.chain.chainManagedObjectContext];
                } else {
                    DSDerivationPathEntity *derivationPathEntity = friendRequest.derivationPath;

                    DSIncomingFundsDerivationPath *incomingFundsDerivationPath = [DSIncomingFundsDerivationPath
                        externalDerivationPathWithExtendedPublicKeyUniqueID:derivationPathEntity.publicKeyIdentifier
                                  withDestinationBlockchainIdentityUniqueId:friendRequest.destinationContact.associatedBlockchainIdentity.uniqueID.UInt256
                                           sourceBlockchainIdentityUniqueId:friendRequest.sourceContact.associatedBlockchainIdentity.uniqueID.UInt256
                                                                    onChain:self.chain];
                    incomingFundsDerivationPath.wallet = self;
                    incomingFundsDerivationPath.account = account;
                    [account addOutgoingDerivationPath:incomingFundsDerivationPath forFriendshipIdentifier:friendRequest.friendshipIdentifier inContext:self.chain.chainManagedObjectContext];
                }
            }
        }

        //this adds the extra information to the transaction and must come after loading all blockchain identities.
        for (DSAccount *account in self.accounts) {
            for (DSTransaction *transaction in account.allTransactions) {
                [transaction loadBlockchainIdentitiesFromDerivationPaths:account.fundDerivationPaths];
                [transaction loadBlockchainIdentitiesFromDerivationPaths:account.outgoingFundDerivationPaths];
            }
        }
    }];
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
                DSAuthenticationKeysDerivationPath *blockchainIdentityBLSKeysDerivationPath = [DSAuthenticationKeysDerivationPath blockchainIdentityBLSKeysDerivationPathForChain:chain];
                [blockchainIdentityBLSKeysDerivationPath generateExtendedPublicKeyFromSeed:derivedKeyData storeUnderWalletUniqueId:walletUniqueId];

                DSAuthenticationKeysDerivationPath *blockchainIdentityECDSAKeysDerivationPath = [DSAuthenticationKeysDerivationPath blockchainIdentityECDSAKeysDerivationPathForChain:chain];
                [blockchainIdentityECDSAKeysDerivationPath generateExtendedPublicKeyFromSeed:derivedKeyData storeUnderWalletUniqueId:walletUniqueId];

                DSCreditFundingDerivationPath *blockchainIdentityRegistrationFundingDerivationPath = [DSCreditFundingDerivationPath blockchainIdentityRegistrationFundingDerivationPathForChain:chain];
                [blockchainIdentityRegistrationFundingDerivationPath generateExtendedPublicKeyFromSeed:derivedKeyData storeUnderWalletUniqueId:walletUniqueId];

                DSCreditFundingDerivationPath *blockchainIdentityTopupFundingDerivationPath = [DSCreditFundingDerivationPath blockchainIdentityTopupFundingDerivationPathForChain:chain];
                [blockchainIdentityTopupFundingDerivationPath generateExtendedPublicKeyFromSeed:derivedKeyData storeUnderWalletUniqueId:walletUniqueId];

                DSCreditFundingDerivationPath *blockchainIdentityInvitationFundingDerivationPath = [DSCreditFundingDerivationPath blockchainIdentityInvitationFundingDerivationPathForChain:chain];
                [blockchainIdentityInvitationFundingDerivationPath generateExtendedPublicKeyFromSeed:derivedKeyData storeUnderWalletUniqueId:walletUniqueId];
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

- (NSString *)walletBlockchainIdentitiesKey {
    return [NSString stringWithFormat:@"%@_%@", WALLET_BLOCKCHAIN_USERS_KEY, [self uniqueIDString]];
}

- (NSString *)walletBlockchainIdentitiesDefaultIndexKey {
    return [NSString stringWithFormat:@"%@_%@_DEFAULT_INDEX", WALLET_BLOCKCHAIN_USERS_KEY, [self uniqueIDString]];
}

- (NSString *)walletBlockchainInvitationsKey {
    return [NSString stringWithFormat:@"%@_%@", WALLET_BLOCKCHAIN_INVITATIONS_KEY, [self uniqueIDString]];
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
    NSData *derivedKeyData = (seedPhrase) ? [[DSBIP39Mnemonic sharedInstance]
                                                deriveKeyFromPhrase:seedPhrase
                                                     withPassphrase:nil] :
                                            nil;
    for (DSDerivationPath *derivationPath in addAccount.fundDerivationPaths) {
        [derivationPath generateExtendedPublicKeyFromSeed:derivedKeyData storeUnderWalletUniqueId:self.uniqueIDString];
    }
    if ([self.chain isEvolutionEnabled]) {
        [addAccount.masterContactsDerivationPath generateExtendedPublicKeyFromSeed:derivedKeyData storeUnderWalletUniqueId:self.uniqueIDString];
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
    NSString *prompt = [NSString stringWithFormat:DSLocalizedString(@"Please authenticate to create your %@ wallet",
                                                      @"Please authenticate to create your Testnet wallet"),
                                 chain.localizedName];

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

    NSString *phrase = [[DSBIP39Mnemonic sharedInstance] encodePhrase:entropy];

    return phrase;
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
        uint64_t unique_id = ecdsa_public_key_unique_id_from_derived_key_data(derivedKeyData.bytes, derivedKeyData.length, chain.chainType);
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
        uint64_t unique_id = ecdsa_public_key_unique_id_from_derived_key_data(derivedKeyData.bytes, derivedKeyData.length, chain.chainType);
        uniqueID = [NSString stringWithFormat:@"%0llx", unique_id];
        
        NSString *storeOnUniqueId = nil;                                          //if not store on keychain then we wont save the extended public keys below.
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

        __weak typeof(self) weakSelf = self;
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
    if (![DSAuthenticationManager sharedInstance].usesAuthentication || [DSAuthenticationManager sharedInstance].didAuthenticate) {
        return [self seedPhrase];
    }

    return nil;
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
                                                                  NSString *rSeedPhrase = authenticated ? getKeychainString(self.mnemonicUniqueID, nil) : nil;
                                                                  completion(rSeedPhrase);
                                                              }];
    }
}

// MARK: - Authentication

// private key for signing authenticated api calls

- (void)authPrivateKey:(void (^_Nullable)(NSString *_Nullable authKey))completion;
{
    @autoreleasepool {
        self.secureSeedRequestBlock(@"Please authorize", 0, ^(NSData *_Nullable seed, BOOL cancelled) {
            @autoreleasepool {
                NSString *privKey = getKeychainString(AUTH_PRIVKEY_KEY, nil);
                if (!privKey) {
                    char *c_string = key_ecdsa_serialized_auth_private_key_for_chain(seed.bytes, seed.length, self.chain.chainType);
                    privKey = [NSString stringWithUTF8String:c_string];
                    processor_destroy_string(c_string);
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

- (NSArray *)registerAddressesWithGapLimit:(NSUInteger)gapLimit unusedAccountGapLimit:(NSUInteger)unusedAccountGapLimit dashpayGapLimit:(NSUInteger)dashpayGapLimit coinJoinGapLimit:(NSUInteger)coinJoinGapLimit internal:(BOOL)internal error:(NSError **)error {
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

- (OpaqueKey *)privateKeyForAddress:(NSString *)address fromSeed:(NSData *)seed {
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
    OpaqueKey *key = [self privateKeyForAddress:address fromSeed:seed];
    NSString *addressString = [DSKeyManager addressForKey:key forChainType:self.chain.chainType];
    return addressString;
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
    [self wipeBlockchainIdentitiesInContext:context];
    [self wipeBlockchainInvitationsInContext:context];
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

// MARK: - Blockchain Identities

- (NSArray *)blockchainIdentityAddresses {
    DSAuthenticationKeysDerivationPath *derivationPath = [[DSDerivationPathFactory sharedInstance] blockchainIdentityBLSKeysDerivationPathForWallet:self];
    if (!derivationPath.hasExtendedPublicKey) return @[];
    return [derivationPath addressesToIndex:[self unusedBlockchainIdentityIndex] + 10 useCache:YES addToCache:YES];
}

- (void)unregisterBlockchainIdentity:(DSBlockchainIdentity *)blockchainIdentity {
    NSParameterAssert(blockchainIdentity);
    NSAssert(blockchainIdentity.wallet == self, @"the blockchainIdentity you are trying to remove is not in this wallet");

    [self.mBlockchainIdentities removeObjectForKey:blockchainIdentity.uniqueIDData];
    NSError *error = nil;
    NSMutableDictionary *keyChainDictionary = [getKeychainDict(self.walletBlockchainIdentitiesKey, @[[NSNumber class], [NSData class]], &error) mutableCopy];
    if (!keyChainDictionary) keyChainDictionary = [NSMutableDictionary dictionary];
    [keyChainDictionary removeObjectForKey:blockchainIdentity.uniqueIDData];
    setKeychainDict(keyChainDictionary, self.walletBlockchainIdentitiesKey, NO);
}

- (void)addBlockchainIdentities:(NSArray<DSBlockchainIdentity *> *)blockchainIdentities {
    for (DSBlockchainIdentity *identity in blockchainIdentities) {
        [self addBlockchainIdentity:identity];
    }
}

- (void)addBlockchainIdentity:(DSBlockchainIdentity *)blockchainIdentity {
    NSParameterAssert(blockchainIdentity);
    NSAssert(uint256_is_not_zero(blockchainIdentity.uniqueID), @"The blockchain identity unique ID must be set");
    [self.mBlockchainIdentities setObject:blockchainIdentity forKey:blockchainIdentity.uniqueIDData];
}

- (BOOL)containsBlockchainIdentity:(DSBlockchainIdentity *)blockchainIdentity {
    if (blockchainIdentity.lockedOutpointData) {
        return ([self.mBlockchainIdentities objectForKey:blockchainIdentity.uniqueIDData] != nil);
    } else {
        return FALSE;
    }
}

- (BOOL)registerBlockchainIdentities:(NSArray<DSBlockchainIdentity *> *)blockchainIdentities verify:(BOOL)verify {
    for (DSBlockchainIdentity *identity in blockchainIdentities) {
        BOOL success = [self registerBlockchainIdentity:identity verify:verify];
        if (!success) {
            return FALSE;
        }
    }
    return TRUE;
}

- (BOOL)registerBlockchainIdentity:(DSBlockchainIdentity *)blockchainIdentity {
    return [self registerBlockchainIdentity:blockchainIdentity verify:NO];
}

- (BOOL)registerBlockchainIdentity:(DSBlockchainIdentity *)blockchainIdentity verify:(BOOL)verify {
    NSParameterAssert(blockchainIdentity);
    if (verify) {
        BOOL verified = [blockchainIdentity verifyKeysForWallet:self];
        if (!verified) {
            blockchainIdentity.isLocal = FALSE;
            return FALSE;
        }
    }

    if ([self.mBlockchainIdentities objectForKey:blockchainIdentity.uniqueIDData] == nil) {
        [self addBlockchainIdentity:blockchainIdentity];
    }
    NSError *error = nil;
    NSMutableDictionary *keyChainDictionary = [getKeychainDict(self.walletBlockchainIdentitiesKey, @[[NSNumber class], [NSData class]], &error) mutableCopy];

    if (error) return FALSE;

    if (!keyChainDictionary) keyChainDictionary = [NSMutableDictionary dictionary];

    NSAssert(uint256_is_not_zero(blockchainIdentity.uniqueID), @"registrationTransactionHashData must not be null");
    if (uint256_is_zero(blockchainIdentity.lockedOutpointData.transactionOutpoint.hash)) {
        keyChainDictionary[blockchainIdentity.uniqueIDData] = @{IDENTITY_INDEX_KEY: @(blockchainIdentity.index)};
    } else {
        keyChainDictionary[blockchainIdentity.uniqueIDData] = @{IDENTITY_INDEX_KEY: @(blockchainIdentity.index), IDENTITY_LOCKED_OUTPUT_KEY: blockchainIdentity.lockedOutpointData};
    }
    setKeychainDict(keyChainDictionary, self.walletBlockchainIdentitiesKey, NO);

    if (!_defaultBlockchainIdentity && (blockchainIdentity.index == 0)) {
        _defaultBlockchainIdentity = blockchainIdentity;
    }
    return TRUE;
}

- (void)wipeBlockchainIdentitiesInContext:(NSManagedObjectContext *)context {
    for (DSBlockchainIdentity *blockchainIdentity in [_mBlockchainIdentities allValues]) {
        [self unregisterBlockchainIdentity:blockchainIdentity];
        [blockchainIdentity deletePersistentObjectAndSave:NO inContext:context];
    }
    _defaultBlockchainIdentity = nil;
}

- (DSBlockchainIdentity *_Nullable)blockchainIdentityThatCreatedContract:(DPContract *)contract withContractId:(UInt256)contractId {
    NSParameterAssert(contract);
    NSAssert(uint256_is_not_zero(contractId), @"contractId must not be null");
    DSBlockchainIdentity *foundBlockchainIdentity = nil;
    for (DSBlockchainIdentity *blockchainIdentity in [_mBlockchainIdentities allValues]) {
        if (uint256_eq([contract contractIdIfRegisteredByBlockchainIdentity:blockchainIdentity], contractId)) {
            foundBlockchainIdentity = blockchainIdentity;
        }
    }
    return foundBlockchainIdentity;
}

- (DSBlockchainIdentity *)blockchainIdentityForUniqueId:(UInt256)uniqueId {
    NSAssert(uint256_is_not_zero(uniqueId), @"uniqueId must not be null");
    DSBlockchainIdentity *foundBlockchainIdentity = nil;
    for (DSBlockchainIdentity *blockchainIdentity in [_mBlockchainIdentities allValues]) {
        if (uint256_eq([blockchainIdentity uniqueID], uniqueId)) {
            foundBlockchainIdentity = blockchainIdentity;
        }
    }
    return foundBlockchainIdentity;
}

- (uint32_t)blockchainIdentitiesCount {
    return (uint32_t)[self.mBlockchainIdentities count];
}

- (BOOL)upgradeIdentityKeyChain {
    NSError *error = nil;
    NSMutableDictionary *keyChainDictionary = [getKeychainDict(self.walletBlockchainIdentitiesKey, @[[NSNumber class], [NSData class]], &error) mutableCopy];
    NSAssert(error == nil, @"There should be no error during upgrade");
    if (error) return FALSE;
    NSMutableDictionary *updatedKeyChainDictionary = [NSMutableDictionary dictionary];
    for (NSData *blockchainIdentityLockedOutpoint in keyChainDictionary) {
        NSData *uniqueIdData = uint256_data([blockchainIdentityLockedOutpoint SHA256_2]);
        [updatedKeyChainDictionary setObject:@{IDENTITY_INDEX_KEY: keyChainDictionary[blockchainIdentityLockedOutpoint], IDENTITY_LOCKED_OUTPUT_KEY: blockchainIdentityLockedOutpoint} forKey:uniqueIdData];
    }
    setKeychainDict(updatedKeyChainDictionary, self.walletBlockchainIdentitiesKey, NO);
    return TRUE;
}


//This loads all the identities that the wallet knows about. If the app was deleted and reinstalled the identity information will remain from the keychain but must be reaquired from the network.
- (NSMutableDictionary *)blockchainIdentities {
    //setKeychainDict(@{}, self.walletBlockchainIdentitiesKey, NO);
    if (_mBlockchainIdentities) return _mBlockchainIdentities;
    NSError *error = nil;
    NSMutableDictionary *keyChainDictionary = [getKeychainDict(self.walletBlockchainIdentitiesKey, @[[NSNumber class], [NSData class]], &error) mutableCopy];
    if (error) {
        return nil;
    }
    uint64_t defaultIndex = getKeychainInt(self.walletBlockchainIdentitiesDefaultIndexKey, &error);
    if (error) {
        return nil;
    }
    NSMutableDictionary *rDictionary = [NSMutableDictionary dictionary];

    if (keyChainDictionary && keyChainDictionary.count) {
        if ([[[keyChainDictionary allValues] firstObject] isKindOfClass:[NSNumber class]]) {
            BOOL upgraded = [self upgradeIdentityKeyChain];
            if (!upgraded) {
                return nil;
            } else {
                return (NSMutableDictionary *) [self blockchainIdentities];
            }
        }
        for (NSData *uniqueIdData in keyChainDictionary) {
            uint32_t index = [[keyChainDictionary[uniqueIdData] objectForKey:IDENTITY_INDEX_KEY] unsignedIntValue];
            //DSLogPrivate(@"Blockchain identity unique Id is %@",uint256_hex(blockchainIdentityUniqueId));
            //                UInt256 lastTransitionHash = [self.specialTransactionsHolder lastSubscriptionTransactionHashForRegistrationTransactionHash:registrationTransactionHash];
            //                DSLogPrivate(@"reg %@ last %@",uint256_hex(registrationTransactionHash),uint256_hex(lastTransitionHash));
            //                DSBlockchainIdentityRegistrationTransition * blockchainIdentityRegistrationTransaction = [self blockchainIdentityRegistrationTransactionForIndex:index];

            //either the identity is known in core data (and we can pull it) or the wallet has been wiped and we need to get it from DAPI (the unique Id was saved in the keychain, so we don't need to resync)
            //TODO: get the identity from core data

            NSManagedObjectContext *context = [NSManagedObjectContext chainContext]; //shouldn't matter what context is used

            [context performBlockAndWait:^{
                NSUInteger blockchainIdentityEntitiesCount = [DSBlockchainIdentityEntity countObjectsInContext:context matching:@"chain == %@ && isLocal == TRUE", [self.chain chainEntityInContext:context]];
                if (blockchainIdentityEntitiesCount != keyChainDictionary.count) {
                    DSLog(@"[%@] Unmatching blockchain entities count", self.chain.name);
                }
                DSBlockchainIdentityEntity *blockchainIdentityEntity = [DSBlockchainIdentityEntity anyObjectInContext:context matching:@"uniqueID == %@", uniqueIdData];
                DSBlockchainIdentity *blockchainIdentity = nil;
                NSData *lockedOutpointData = [keyChainDictionary[uniqueIdData] objectForKey:IDENTITY_LOCKED_OUTPUT_KEY];
                if (blockchainIdentityEntity) {
                    if (lockedOutpointData) {
                        blockchainIdentity = [[DSBlockchainIdentity alloc] initAtIndex:index withLockedOutpoint:lockedOutpointData.transactionOutpoint inWallet:self withBlockchainIdentityEntity:blockchainIdentityEntity];
                    } else {
                        blockchainIdentity = [[DSBlockchainIdentity alloc] initAtIndex:index withUniqueId:uniqueIdData.UInt256 inWallet:self withBlockchainIdentityEntity:blockchainIdentityEntity];
                    }
                } else if (lockedOutpointData) {
                    //No blockchain identity is known in core data
                    NSData *transactionHashData = uint256_data(uint256_reverse(lockedOutpointData.transactionOutpoint.hash));
                    DSTransactionEntity *creditRegitrationTransactionEntity = [DSTransactionEntity anyObjectInContext:context matching:@"transactionHash.txHash == %@", transactionHashData];
                    if (creditRegitrationTransactionEntity) {
                        //The registration funding transaction exists
                        //Weird but we should recover in this situation
                        DSCreditFundingTransaction *registrationTransaction = (DSCreditFundingTransaction *)[creditRegitrationTransactionEntity transactionForChain:self.chain];

                        BOOL correctIndex = [registrationTransaction checkDerivationPathIndexForWallet:self isIndex:index];
                        if (!correctIndex) {
                            NSAssert(FALSE, @"We should implement this");
                        } else {
                            blockchainIdentity = [[DSBlockchainIdentity alloc] initAtIndex:index withFundingTransaction:registrationTransaction withUsernameDictionary:nil inWallet:self];
                            [blockchainIdentity registerInWallet];
                        }
                    } else {
                        //We also don't have the registration funding transaction
                        blockchainIdentity = [[DSBlockchainIdentity alloc] initAtIndex:index withUniqueId:uniqueIdData.UInt256 inWallet:self];
                        [blockchainIdentity registerInWalletForBlockchainIdentityUniqueId:uniqueIdData.UInt256];
                    }
                } else {
                    blockchainIdentity = [[DSBlockchainIdentity alloc] initAtIndex:index withUniqueId:uniqueIdData.UInt256 inWallet:self];
                    [blockchainIdentity registerInWalletForBlockchainIdentityUniqueId:uniqueIdData.UInt256];
                }
                if (blockchainIdentity) {
                    rDictionary[uniqueIdData] = blockchainIdentity;
                    if (index == defaultIndex) {
                        _defaultBlockchainIdentity = blockchainIdentity;
                    }
                }
            }];
        }
    }
    _mBlockchainIdentities = rDictionary;
    return _mBlockchainIdentities;
}

- (void)setDefaultBlockchainIdentity:(DSBlockchainIdentity *)defaultBlockchainIdentity {
    if (![[self.blockchainIdentities allValues] containsObject:defaultBlockchainIdentity]) return;
    _defaultBlockchainIdentity = defaultBlockchainIdentity;
    setKeychainInt(defaultBlockchainIdentity.index, self.walletBlockchainIdentitiesDefaultIndexKey, NO);
}

- (uint32_t)unusedBlockchainIdentityIndex {
    NSArray *blockchainIdentities = [_mBlockchainIdentities allValues];
    NSNumber *max = [blockchainIdentities valueForKeyPath:@"index.@max.intValue"];
    return max != nil ? ([max unsignedIntValue] + 1) : 0;
}

- (DSBlockchainIdentity *)createBlockchainIdentity {
    DSBlockchainIdentity *blockchainIdentity = [[DSBlockchainIdentity alloc] initAtIndex:[self unusedBlockchainIdentityIndex] inWallet:self];
    return blockchainIdentity;
}

- (DSBlockchainIdentity *)createBlockchainIdentityUsingDerivationIndex:(uint32_t)index {
    DSBlockchainIdentity *blockchainIdentity = [[DSBlockchainIdentity alloc] initAtIndex:index inWallet:self];
    return blockchainIdentity;
}

- (DSBlockchainIdentity *)createBlockchainIdentityForUsername:(NSString *)username {
    DSBlockchainIdentity *blockchainIdentity = [self createBlockchainIdentity];
    [blockchainIdentity addDashpayUsername:username save:NO];
    return blockchainIdentity;
}

- (DSBlockchainIdentity *)createBlockchainIdentityForUsername:(NSString *)username usingDerivationIndex:(uint32_t)index {
    DSBlockchainIdentity *blockchainIdentity = [self createBlockchainIdentityUsingDerivationIndex:index];
    [blockchainIdentity addDashpayUsername:username save:NO];
    return blockchainIdentity;
}

// MARK: - Invitations


- (uint32_t)blockchainInvitationsCount {
    return (uint32_t)[self.mBlockchainInvitations count];
}


//This loads all the identities that the wallet knows about. If the app was deleted and reinstalled the identity information will remain from the keychain but must be reaquired from the network.
- (NSMutableDictionary *)blockchainInvitations {
    //setKeychainDict(@{}, self.walletBlockchainInvitationsKey, NO);
    if (_mBlockchainInvitations) return _mBlockchainInvitations;
    NSError *error = nil;
    NSMutableDictionary *keyChainDictionary = [getKeychainDict(self.walletBlockchainInvitationsKey, @[[NSNumber class], [NSData class]], &error) mutableCopy];
    if (error) {
        return nil;
    }
    NSMutableDictionary *rDictionary = [NSMutableDictionary dictionary];

    if (keyChainDictionary) {
        for (NSData *blockchainInvitationLockedOutpointData in keyChainDictionary) {
            uint32_t index = [keyChainDictionary[blockchainInvitationLockedOutpointData] unsignedIntValue];
            DSUTXO blockchainInvitationLockedOutpoint = blockchainInvitationLockedOutpointData.transactionOutpoint;
            //DSLogPrivate(@"Blockchain identity unique Id is %@",uint256_hex(blockchainInvitationUniqueId));
            //                UInt256 lastTransitionHash = [self.specialTransactionsHolder lastSubscriptionTransactionHashForRegistrationTransactionHash:registrationTransactionHash];
            //                DSLogPrivate(@"reg %@ last %@",uint256_hex(registrationTransactionHash),uint256_hex(lastTransitionHash));
            //                DSBlockchainInvitationRegistrationTransition * blockchainInvitationRegistrationTransaction = [self blockchainInvitationRegistrationTransactionForIndex:index];

            //either the identity is known in core data (and we can pull it) or the wallet has been wiped and we need to get it from DAPI (the unique Id was saved in the keychain, so we don't need to resync)
            //TODO: get the identity from core data

            NSManagedObjectContext *context = [NSManagedObjectContext chainContext]; //shouldn't matter what context is used

            [context performBlockAndWait:^{
                NSUInteger blockchainInvitationEntitiesCount = [DSBlockchainInvitationEntity countObjectsInContext:context matching:@"chain == %@", [self.chain chainEntityInContext:context]];
                if (blockchainInvitationEntitiesCount != keyChainDictionary.count) {
                    DSLog(@"[%@] Unmatching blockchain invitations count", self.chain.name);
                }
                DSBlockchainInvitationEntity *blockchainInvitationEntity = [DSBlockchainInvitationEntity anyObjectInContext:context matching:@"blockchainIdentity.uniqueID == %@", uint256_data([dsutxo_data(blockchainInvitationLockedOutpoint) SHA256_2])];
                DSBlockchainInvitation *blockchainInvitation = nil;
                if (blockchainInvitationEntity) {
                    blockchainInvitation = [[DSBlockchainInvitation alloc] initAtIndex:index withLockedOutpoint:blockchainInvitationLockedOutpoint inWallet:self withBlockchainInvitationEntity:blockchainInvitationEntity];
                } else {
                    //No blockchain identity is known in core data
                    NSData *transactionHashData = uint256_data(uint256_reverse(blockchainInvitationLockedOutpoint.hash));
                    DSTransactionEntity *creditRegitrationTransactionEntity = [DSTransactionEntity anyObjectInContext:context matching:@"transactionHash.txHash == %@", transactionHashData];
                    if (creditRegitrationTransactionEntity) {
                        //The registration funding transaction exists
                        //Weird but we should recover in this situation
                        DSCreditFundingTransaction *registrationTransaction = (DSCreditFundingTransaction *)[creditRegitrationTransactionEntity transactionForChain:self.chain];

                        BOOL correctIndex = [registrationTransaction checkInvitationDerivationPathIndexForWallet:self isIndex:index];
                        if (!correctIndex) {
                            NSAssert(FALSE, @"We should implement this");
                        } else {
                            blockchainInvitation = [[DSBlockchainInvitation alloc] initAtIndex:index withFundingTransaction:registrationTransaction inWallet:self];
                            [blockchainInvitation registerInWallet];
                        }
                    } else {
                        //We also don't have the registration funding transaction
                        blockchainInvitation = [[DSBlockchainInvitation alloc] initAtIndex:index withLockedOutpoint:blockchainInvitationLockedOutpoint inWallet:self];
                        [blockchainInvitation registerInWalletForBlockchainIdentityUniqueId:[dsutxo_data(blockchainInvitationLockedOutpoint) SHA256_2]];
                    }
                }
                if (blockchainInvitation) {
                    rDictionary[blockchainInvitationLockedOutpointData] = blockchainInvitation;
                }
            }];
        }
    }
    _mBlockchainInvitations = rDictionary;
    return _mBlockchainInvitations;
}

- (DSBlockchainInvitation *)blockchainInvitationForUniqueId:(UInt256)uniqueId {
    NSAssert(uint256_is_not_zero(uniqueId), @"uniqueId must not be null");
    DSBlockchainInvitation *foundBlockchainInvitation = nil;
    for (DSBlockchainInvitation *blockchainInvitation in [_mBlockchainInvitations allValues]) {
        if (uint256_eq([blockchainInvitation.identity uniqueID], uniqueId)) {
            foundBlockchainInvitation = blockchainInvitation;
        }
    }
    return foundBlockchainInvitation;
}

- (uint32_t)unusedBlockchainInvitationIndex {
    NSArray *blockchainInvitations = [_mBlockchainInvitations allValues];
    NSNumber *max = [blockchainInvitations valueForKeyPath:@"identity.index.@max.intValue"];
    return max != nil ? ([max unsignedIntValue] + 1) : 0;
}

- (DSBlockchainInvitation *)createBlockchainInvitation {
    DSBlockchainInvitation *blockchainInvitation = [[DSBlockchainInvitation alloc] initAtIndex:[self unusedBlockchainInvitationIndex] inWallet:self];
    return blockchainInvitation;
}

- (DSBlockchainInvitation *)createBlockchainInvitationUsingDerivationIndex:(uint32_t)index {
    DSBlockchainInvitation *blockchainInvitation = [[DSBlockchainInvitation alloc] initAtIndex:index inWallet:self];
    return blockchainInvitation;
}

- (void)unregisterBlockchainInvitation:(DSBlockchainInvitation *)blockchainInvitation {
    NSParameterAssert(blockchainInvitation);
    NSAssert(blockchainInvitation.wallet == self, @"the blockchainInvitation you are trying to remove is not in this wallet");
    NSAssert(blockchainInvitation.identity != nil, @"the blockchainInvitation you are trying to remove has no identity");

    [self.mBlockchainInvitations removeObjectForKey:blockchainInvitation.identity.lockedOutpointData];
    NSError *error = nil;
    NSMutableDictionary *keyChainDictionary = [getKeychainDict(self.walletBlockchainInvitationsKey, @[[NSNumber class], [NSData class]], &error) mutableCopy];
    if (!keyChainDictionary) keyChainDictionary = [NSMutableDictionary dictionary];
    [keyChainDictionary removeObjectForKey:blockchainInvitation.identity.lockedOutpointData];
    setKeychainDict(keyChainDictionary, self.walletBlockchainInvitationsKey, NO);
}

- (void)addBlockchainInvitation:(DSBlockchainInvitation *)blockchainInvitation {
    NSParameterAssert(blockchainInvitation);
    [self.mBlockchainInvitations setObject:blockchainInvitation forKey:blockchainInvitation.identity.lockedOutpointData];
}

- (void)registerBlockchainInvitation:(DSBlockchainInvitation *)blockchainInvitation {
    NSParameterAssert(blockchainInvitation);
    NSAssert(blockchainInvitation.identity != nil, @"the blockchainInvitation you are trying to remove has no identity");

    if ([self.mBlockchainInvitations objectForKey:blockchainInvitation.identity.lockedOutpointData] == nil) {
        [self addBlockchainInvitation:blockchainInvitation];
    }
    NSError *error = nil;
    NSMutableDictionary *keyChainDictionary = [getKeychainDict(self.walletBlockchainInvitationsKey, @[[NSNumber class], [NSData class]], &error) mutableCopy];
    if (!keyChainDictionary) keyChainDictionary = [NSMutableDictionary dictionary];

    NSAssert(uint256_is_not_zero(blockchainInvitation.identity.uniqueID), @"registrationTransactionHashData must not be null");
    keyChainDictionary[blockchainInvitation.identity.lockedOutpointData] = @(blockchainInvitation.identity.index);
    setKeychainDict(keyChainDictionary, self.walletBlockchainInvitationsKey, NO);
}

- (BOOL)containsBlockchainInvitation:(DSBlockchainInvitation *)blockchainInvitation {
    if (blockchainInvitation.identity.lockedOutpointData) {
        return ([self.mBlockchainInvitations objectForKey:blockchainInvitation.identity.lockedOutpointData] != nil);
    } else {
        return FALSE;
    }
}

- (void)wipeBlockchainInvitationsInContext:(NSManagedObjectContext *)context {
    for (DSBlockchainInvitation *blockchainInvitation in [_mBlockchainInvitations allValues]) {
        [self unregisterBlockchainInvitation:blockchainInvitation];
        [blockchainInvitation deletePersistentObjectAndSave:NO inContext:context];
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

- (void)registerMasternodeOperator:(DSLocalMasternode *)masternode withOperatorPublicKey:(OpaqueKey *)operatorKey {
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

- (void)registerMasternodeOwner:(DSLocalMasternode *)masternode withOwnerPrivateKey:(OpaqueKey *)ownerKey {
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

- (void)registerMasternodeVoter:(DSLocalMasternode *)masternode withVotingKey:(OpaqueKey *)votingKey {
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

- (void)registerPlatformNode:(DSLocalMasternode *)masternode withKey:(OpaqueKey *)key {
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

- (BOOL)containsProviderVotingAuthenticationHash:(UInt160)votingAuthenticationHash {
    DSAuthenticationKeysDerivationPath *derivationPath = [DSAuthenticationKeysDerivationPath providerVotingKeysDerivationPathForWallet:self];
    NSString *address = [DSKeyManager addressFromHash160:votingAuthenticationHash forChain:self.chain];
    return [derivationPath containsAddress:address];
}

- (BOOL)containsProviderOwningAuthenticationHash:(UInt160)owningAuthenticationHash {
    DSAuthenticationKeysDerivationPath *derivationPath = [DSAuthenticationKeysDerivationPath providerOwnerKeysDerivationPathForWallet:self];
    NSString *address = [DSKeyManager addressFromHash160:owningAuthenticationHash forChain:self.chain];
    return [derivationPath containsAddress:address];
}

- (BOOL)containsProviderOperatorAuthenticationKey:(UInt384)providerOperatorAuthenticationKey {
    DSAuthenticationKeysDerivationPath *derivationPath = [DSAuthenticationKeysDerivationPath providerOperatorKeysDerivationPathForWallet:self];
    NSString *address = [DSKeyManager addressFromHash160:[[NSData dataWithUInt384:providerOperatorAuthenticationKey] hash160] forChain:self.chain];
    return [derivationPath containsAddress:address];
}

- (BOOL)containsPlatformNodeAuthenticationHash:(UInt160)platformNodeAuthenticationHash {
    DSAuthenticationKeysDerivationPath *derivationPath = [DSAuthenticationKeysDerivationPath platformNodeKeysDerivationPathForWallet:self];
    NSString *address = [DSKeyManager addressFromHash160:platformNodeAuthenticationHash forChain:self.chain];
    return [derivationPath containsAddress:address];
}

- (BOOL)containsBlockchainIdentityBLSAuthenticationHash:(UInt160)blockchainIdentityAuthenticationHash {
    DSAuthenticationKeysDerivationPath *derivationPath = [DSAuthenticationKeysDerivationPath blockchainIdentitiesBLSKeysDerivationPathForWallet:self];
    NSString *address = [DSKeyManager addressFromHash160:blockchainIdentityAuthenticationHash forChain:self.chain];
    return [derivationPath containsAddress:address];
}

- (BOOL)containsHoldingAddress:(NSString *)holdingAddress {
    NSParameterAssert(holdingAddress);

    DSMasternodeHoldingsDerivationPath *derivationPath = [DSMasternodeHoldingsDerivationPath providerFundsDerivationPathForWallet:self];
    return [derivationPath containsAddress:holdingAddress];
}

- (NSUInteger)indexOfProviderVotingAuthenticationHash:(UInt160)votingAuthenticationHash {
    DSAuthenticationKeysDerivationPath *derivationPath = [DSAuthenticationKeysDerivationPath providerVotingKeysDerivationPathForWallet:self];
    NSString *address = [DSKeyManager addressFromHash160:votingAuthenticationHash forChain:self.chain];
    return [derivationPath indexOfKnownAddress:address];
}

- (NSUInteger)indexOfProviderOwningAuthenticationHash:(UInt160)owningAuthenticationHash {
    DSAuthenticationKeysDerivationPath *derivationPath = [DSAuthenticationKeysDerivationPath providerOwnerKeysDerivationPathForWallet:self];
    NSString *address = [DSKeyManager addressFromHash160:owningAuthenticationHash forChain:self.chain];
    return [derivationPath indexOfKnownAddress:address];
}

- (NSUInteger)indexOfProviderOperatorAuthenticationKey:(UInt384)providerOperatorAuthenticationKey {
    DSAuthenticationKeysDerivationPath *derivationPath = [DSAuthenticationKeysDerivationPath providerOperatorKeysDerivationPathForWallet:self];
    NSString *address = [DSKeyManager addressFromHash160:[[NSData dataWithUInt384:providerOperatorAuthenticationKey] hash160] forChain:self.chain];
    return [derivationPath indexOfKnownAddress:address];
}

- (NSUInteger)indexOfPlatformNodeAuthenticationHash:(UInt160)platformNodeAuthenticationHash {
    DSAuthenticationKeysDerivationPath *derivationPath = [DSAuthenticationKeysDerivationPath platformNodeKeysDerivationPathForWallet:self];
    NSString *address = [DSKeyManager addressFromHash160:platformNodeAuthenticationHash forChain:self.chain];
    return [derivationPath indexOfKnownAddress:address];
}

- (NSUInteger)indexOfHoldingAddress:(NSString *)holdingAddress {
    NSParameterAssert(holdingAddress);
    DSMasternodeHoldingsDerivationPath *derivationPath = [DSMasternodeHoldingsDerivationPath providerFundsDerivationPathForWallet:self];
    return [derivationPath indexOfKnownAddress:holdingAddress];
}

- (NSUInteger)indexOfBlockchainIdentityAuthenticationHash:(UInt160)blockchainIdentityAuthenticationHash {
    DSAuthenticationKeysDerivationPath *derivationPath = [DSAuthenticationKeysDerivationPath blockchainIdentitiesBLSKeysDerivationPathForWallet:self];
    NSString *address = [DSKeyManager addressFromHash160:blockchainIdentityAuthenticationHash forChain:self.chain];
    return [derivationPath indexOfKnownAddress:address];
}

- (NSUInteger)indexOfBlockchainIdentityCreditFundingRegistrationHash:(UInt160)creditFundingRegistrationHash {
    DSCreditFundingDerivationPath *derivationPath = [DSCreditFundingDerivationPath blockchainIdentityRegistrationFundingDerivationPathForWallet:self];
    NSString *address = [DSKeyManager addressFromHash160:creditFundingRegistrationHash forChain:self.chain];
    return [derivationPath indexOfKnownAddress:address];
}

- (NSUInteger)indexOfBlockchainIdentityCreditFundingTopupHash:(UInt160)creditFundingTopupHash {
    DSCreditFundingDerivationPath *derivationPath = [DSCreditFundingDerivationPath blockchainIdentityTopupFundingDerivationPathForWallet:self];
    NSString *address = [DSKeyManager addressFromHash160:creditFundingTopupHash forChain:self.chain];
    return [derivationPath indexOfKnownAddress:address];
}

- (NSUInteger)indexOfBlockchainIdentityCreditFundingInvitationHash:(UInt160)creditFundingInvitationHash {
    DSCreditFundingDerivationPath *derivationPath = [DSCreditFundingDerivationPath blockchainIdentityInvitationFundingDerivationPathForWallet:self];
    NSString *address = [DSKeyManager addressFromHash160:creditFundingInvitationHash forChain:self.chain];
    return [derivationPath indexOfKnownAddress:address];
}

@end
