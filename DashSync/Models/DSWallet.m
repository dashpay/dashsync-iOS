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

#import "DSWallet.h"
#import "DSAccount.h"
#import "DSAuthenticationManager.h"
#import "DSPriceManager.h"
#import "DSBIP39Mnemonic.h"
#import "NSManagedObject+Sugar.h"
#import "NSMutableData+Dash.h"
#import "DSAddressEntity+CoreDataProperties.h"
#import "DSTransactionEntity+CoreDataProperties.h"
#import "DSECDSAKey.h"
#import "NSData+Bitcoin.h"
#import "DSEnvironment.h"
#import "DSChainsManager.h"
#import "DSBlockchainUser.h"
#import "DSBlockchainUserRegistrationTransaction.h"
#import "DSBlockchainUserResetTransaction.h"
#import "DSProviderRegistrationTransaction.h"
#import "NSDate+Utils.h"
#import "DSLocalMasternode.h"
#import "DSAuthenticationKeysDerivationPath+Protected.h"
#import "DSMasternodeHoldingsDerivationPath+Protected.h"
#import "DSDerivationPathFactory.h"
#import "DSSpecialTransactionsWalletHolder.h"

#define SEED_ENTROPY_LENGTH   (128/8)
#define WALLET_CREATION_TIME_KEY   @"WALLET_CREATION_TIME_KEY"
#define WALLET_CREATION_GUESS_TIME_KEY @"WALLET_CREATION_GUESS_TIME_KEY"
#define AUTH_PRIVKEY_KEY    @"authprivkey"
#define WALLET_MNEMONIC_KEY        @"WALLET_MNEMONIC_KEY"
#define WALLET_MASTER_PUBLIC_KEY        @"WALLET_MASTER_PUBLIC_KEY"
#define WALLET_BLOCKCHAIN_USERS_KEY  @"WALLET_BLOCKCHAIN_USERS_KEY"

#define WALLET_MASTERNODE_VOTERS_KEY @"WALLET_MASTERNODE_VOTERS_KEY"
#define WALLET_MASTERNODE_OWNERS_KEY @"WALLET_MASTERNODE_OWNERS_KEY"
#define WALLET_MASTERNODE_OPERATORS_KEY @"WALLET_MASTERNODE_OPERATORS_KEY"

#define VERIFIED_WALLET_CREATION_TIME_KEY @"VERIFIED_WALLET_CREATION_TIME"
#define REFERENCE_DATE_2001 978307200

@interface DSWallet() {
    NSTimeInterval _lGuessedWalletCreationTime;
}

@property (nonatomic, strong) DSChain * chain;
@property (nonatomic, strong) NSMutableDictionary * mAccounts;
@property (nonatomic, strong) DSSpecialTransactionsWalletHolder * specialTransactionsHolder;
@property (nonatomic, copy) NSString * uniqueID;
@property (nonatomic, assign) NSTimeInterval walletCreationTime;
@property (nonatomic, assign) BOOL checkedWalletCreationTime;
@property (nonatomic, assign) BOOL checkedGuessedWalletCreationTime;
@property (nonatomic, assign) BOOL checkedVerifyWalletCreationTime;
@property (nonatomic, strong) NSMutableDictionary<NSString *,NSNumber *> * mBlockchainUsers;
@property (nonatomic, strong) NSMutableDictionary<NSData *,NSNumber *> * mMasternodeOperators;
@property (nonatomic, strong) NSMutableDictionary<NSData *,NSNumber *> * mMasternodeOwners;
@property (nonatomic, strong) NSMutableDictionary<NSData *,NSNumber *> * mMasternodeVoters;
@property (nonatomic, strong) SeedRequestBlock seedRequestBlock;
@property (nonatomic, assign, getter=isTransient) BOOL transient;

@end

@implementation DSWallet

+ (DSWallet*)standardWalletWithSeedPhrase:(NSString*)seedPhrase setCreationDate:(NSTimeInterval)creationDate forChain:(DSChain*)chain storeSeedPhrase:(BOOL)store isTransient:(BOOL)isTransient {
    DSAccount * account = [DSAccount accountWithDerivationPaths:[chain standardDerivationPathsForAccountNumber:0] inContext:chain.managedObjectContext];
    
    NSString * uniqueId = [self setSeedPhrase:seedPhrase createdAt:creationDate withAccounts:@[account] storeOnKeychain:store forChain:chain]; //make sure we can create the wallet first
    if (!uniqueId) return nil;
    [self registerSpecializedDerivationPathsForSeedPhrase:seedPhrase underUniqueId:uniqueId onChain:chain];
    DSWallet * wallet = [[DSWallet alloc] initWithUniqueID:uniqueId andAccount:account forChain:chain storeSeedPhrase:store isTransient:isTransient];
    
    return wallet;
}

+ (DSWallet*)standardWalletWithRandomSeedPhraseForChain:(DSChain*)chain storeSeedPhrase:(BOOL)store isTransient:(BOOL)isTransient {
    return [self standardWalletWithRandomSeedPhraseInLanguage:DSBIP39Language_Default forChain:chain storeSeedPhrase:store isTransient:isTransient];
}

+ (DSWallet*)standardWalletWithRandomSeedPhraseInLanguage:(DSBIP39Language)language forChain:(DSChain*)chain storeSeedPhrase:(BOOL)store isTransient:(BOOL)isTransient {
    return [self standardWalletWithSeedPhrase:[self generateRandomSeedForLanguage:language] setCreationDate:[NSDate timeIntervalSince1970] forChain:chain storeSeedPhrase:store isTransient:isTransient];
}

-(instancetype)initWithChain:(DSChain*)chain {
    if (! (self = [super init])) return nil;
    self.transient = FALSE;
    self.mAccounts = [NSMutableDictionary dictionary];
    self.chain = chain;
    self.mBlockchainUsers = [NSMutableDictionary dictionary];
    self.mMasternodeOwners = [NSMutableDictionary dictionary];
    self.mMasternodeVoters = [NSMutableDictionary dictionary];
    self.mMasternodeOperators = [NSMutableDictionary dictionary];
    self.checkedWalletCreationTime = NO;
    self.checkedGuessedWalletCreationTime = NO;
    self.checkedVerifyWalletCreationTime = NO;
    return self;
}

-(instancetype)initWithUniqueID:(NSString*)uniqueID andAccount:(DSAccount*)account forChain:(DSChain*)chain storeSeedPhrase:(BOOL)store isTransient:(BOOL)isTransient {
    if (! (self = [self initWithChain:chain])) return nil;
    self.uniqueID = uniqueID;
    __weak typeof(self) weakSelf = self;
    self.seedRequestBlock = ^void(NSString *authprompt, uint64_t amount, SeedCompletionBlock seedCompletion) {
        //this happens when we request the seed
        [weakSelf seedWithPrompt:authprompt forAmount:amount completion:seedCompletion];
    };
    if (store) {
        [chain registerWallet:self];
    }
    
    if (isTransient) {
        self.transient = TRUE;
    }
    
    if (account) [self addAccount:account]; //this must be last, as adding the account queries the wallet unique ID
    
    [[DSDerivationPathFactory sharedInstance] loadSpecializedDerivationPathsForWallet:self];
    
    self.specialTransactionsHolder = [[DSSpecialTransactionsWalletHolder alloc] initWithWallet:self inContext:self.chain.managedObjectContext];
    
    NSError * error = nil;
    self.mBlockchainUsers = [getKeychainDict(self.walletBlockchainUsersKey, &error) mutableCopy];
    if (error) return nil;
    return self;
}


+(void)registerSpecializedDerivationPathsForSeedPhrase:(NSString*)seedPhrase underUniqueId:(NSString*)walletUniqueId onChain:(DSChain*)chain {
    @autoreleasepool {
        seedPhrase = [[DSBIP39Mnemonic sharedInstance] normalizePhrase:seedPhrase];
        
        NSData * derivedKeyData = (seedPhrase) ?[[DSBIP39Mnemonic sharedInstance]
                                                 deriveKeyFromPhrase:seedPhrase withPassphrase:nil]:nil;
        
        DSAuthenticationKeysDerivationPath * providerOwnerKeysDericationPath = [DSAuthenticationKeysDerivationPath providerOwnerKeysDerivationPathForChain:chain];
        [providerOwnerKeysDericationPath generateExtendedPublicKeyFromSeed:derivedKeyData storeUnderWalletUniqueId:walletUniqueId];
        DSAuthenticationKeysDerivationPath * providerOperatorKeysDericationPath = [DSAuthenticationKeysDerivationPath providerOperatorKeysDerivationPathForChain:chain];
        [providerOperatorKeysDericationPath generateExtendedPublicKeyFromSeed:derivedKeyData storeUnderWalletUniqueId:walletUniqueId];
        DSAuthenticationKeysDerivationPath * providerVotingKeysDericationPath = [DSAuthenticationKeysDerivationPath providerVotingKeysDerivationPathForChain:chain];
        [providerVotingKeysDericationPath generateExtendedPublicKeyFromSeed:derivedKeyData storeUnderWalletUniqueId:walletUniqueId];
        DSMasternodeHoldingsDerivationPath * providerFundsDerivationPath = [DSMasternodeHoldingsDerivationPath providerFundsDerivationPathForChain:chain];
        [providerFundsDerivationPath generateExtendedPublicKeyFromSeed:derivedKeyData storeUnderWalletUniqueId:walletUniqueId];
    }
}

-(instancetype)initWithUniqueID:(NSString*)uniqueID forChain:(DSChain*)chain {
    if (! (self = [self initWithUniqueID:uniqueID andAccount:[DSAccount accountWithDerivationPaths:[chain standardDerivationPathsForAccountNumber:0] inContext:chain.managedObjectContext] forChain:chain storeSeedPhrase:NO isTransient:NO])) return nil;
    return self;
}

-(NSString*)walletBlockchainUsersKey {
    return [NSString stringWithFormat:@"%@_%@",WALLET_BLOCKCHAIN_USERS_KEY,[self uniqueID]];
}

-(NSString*)walletMasternodeVotersKey {
    return [NSString stringWithFormat:@"%@_%@",WALLET_MASTERNODE_VOTERS_KEY,[self uniqueID]];
}

-(NSString*)walletMasternodeOwnersKey {
    return [NSString stringWithFormat:@"%@_%@",WALLET_MASTERNODE_OWNERS_KEY,[self uniqueID]];
}

-(NSString*)walletMasternodeOperatorsKey {
    return [NSString stringWithFormat:@"%@_%@",WALLET_MASTERNODE_OPERATORS_KEY,[self uniqueID]];
}

-(NSArray *)accounts {
    return [self.mAccounts allValues];
}

-(void)addAccount:(DSAccount*)account {
    [self.mAccounts setObject:account forKey:@(account.accountNumber)];
    account.wallet = self;
}

- (DSAccount* _Nullable)accountWithNumber:(NSUInteger)accountNumber {
    return [self.mAccounts objectForKey:@(accountNumber)];
}

-(void)copyForChain:(DSChain*)chain completion:(void (^ _Nonnull)(DSWallet * copiedWallet))completion {
    if ([self.chain isEqual:chain]) {
        completion(self);
        return;
    }
    [self seedPhraseAfterAuthentication:^(NSString * _Nullable seedPhrase) {
        if (!seedPhrase) {
            completion(nil);
            return;
        }
        DSWallet * wallet = [self.class standardWalletWithSeedPhrase:seedPhrase setCreationDate:(self.walletCreationTime == BIP39_CREATION_TIME)?0:self.walletCreationTime forChain:chain storeSeedPhrase:YES isTransient:NO];
        completion(wallet);
    }];
}

// MARK: - Unique Identifiers

+(NSString*)mnemonicUniqueIDForUniqueID:(NSString*)uniqueID {
    return [NSString stringWithFormat:@"%@_%@",WALLET_MNEMONIC_KEY,uniqueID];
}

-(NSString*)mnemonicUniqueID {
    return [DSWallet mnemonicUniqueIDForUniqueID:self.uniqueID];
}

+(NSString*)creationTimeUniqueIDForUniqueID:(NSString*)uniqueID {
    return [NSString stringWithFormat:@"%@_%@",WALLET_CREATION_TIME_KEY,uniqueID];
}

+(NSString*)creationGuessTimeUniqueIDForUniqueID:(NSString*)uniqueID {
    return [NSString stringWithFormat:@"%@_%@",WALLET_CREATION_GUESS_TIME_KEY,uniqueID];
}

+(NSString*)didVerifyCreationTimeUniqueIDForUniqueID:(NSString*)uniqueID {
    return [NSString stringWithFormat:@"%@_%@",VERIFIED_WALLET_CREATION_TIME_KEY,uniqueID];
}

-(NSString*)creationTimeUniqueID {
    return [DSWallet creationTimeUniqueIDForUniqueID:self.uniqueID];
}

-(NSString*)creationGuessTimeUniqueID {
    return [DSWallet creationGuessTimeUniqueIDForUniqueID:self.uniqueID];
}

-(NSString*)didVerifyCreationTimeUniqueID {
    return [DSWallet didVerifyCreationTimeUniqueIDForUniqueID:self.uniqueID];
}

// MARK: - Wallet Creation Time

-(NSTimeInterval)walletCreationTime {
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

-(void)wipeWalletInfo {
    _walletCreationTime = 0;
    setKeychainData(nil, self.creationTimeUniqueID, NO);
    setKeychainData(nil, self.creationGuessTimeUniqueID,NO);
    setKeychainData(nil, self.didVerifyCreationTimeUniqueID,NO);
}

-(NSTimeInterval)guessedWalletCreationTime {
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

-(void)setGuessedWalletCreationTime:(NSTimeInterval)guessedWalletCreationTime {
    if (_walletCreationTime) return;
    if (!setKeychainData([NSData dataWithBytes:&guessedWalletCreationTime length:sizeof(guessedWalletCreationTime)], [self creationGuessTimeUniqueID], NO)) {
        NSAssert(FALSE, @"error setting wallet guessed creation time");
    }
    _lGuessedWalletCreationTime = guessedWalletCreationTime;
}

-(void)migrateWalletCreationTime {
    NSData *d = getKeychainData(self.creationTimeUniqueID, nil);
    
    if (d.length == sizeof(NSTimeInterval)) {
        NSTimeInterval potentialWalletCreationTime = *(const NSTimeInterval *)d.bytes;
        if (potentialWalletCreationTime < BIP39_CREATION_TIME) { //it was from reference date for sure
            NSDate * realWalletCreationDate = [NSDate dateWithTimeIntervalSinceReferenceDate:potentialWalletCreationTime];
            NSTimeInterval realWalletCreationTime = [realWalletCreationDate timeIntervalSince1970];
            if (realWalletCreationTime && (realWalletCreationTime != REFERENCE_DATE_2001)) {
                _walletCreationTime = MAX(realWalletCreationTime,BIP39_CREATION_TIME); //safeguard
                DSDLog(@"real wallet creation set to %@",realWalletCreationDate);
                setKeychainData([NSData dataWithBytes:&realWalletCreationTime length:sizeof(realWalletCreationTime)], self.creationTimeUniqueID, NO);
            } else if (realWalletCreationTime == REFERENCE_DATE_2001) {
                realWalletCreationTime = 0;
                setKeychainData([NSData dataWithBytes:&realWalletCreationTime length:sizeof(realWalletCreationTime)], self.creationTimeUniqueID, NO);
            }
        }
    }
}

-(void)verifyWalletCreationTime {
    if (!self.checkedVerifyWalletCreationTime) {
        NSError * error = nil;
        BOOL didVerifyAlready = hasKeychainData(self.didVerifyCreationTimeUniqueID, &error);
        if (!didVerifyAlready) {
            [self migrateWalletCreationTime];
            setKeychainInt(1, self.didVerifyCreationTimeUniqueID, NO);
        }
        self.checkedVerifyWalletCreationTime = YES;
    }
}

// MARK: - Seed

// generates a random seed, saves to keychain and returns the associated seedPhrase
+ (NSString *)generateRandomSeedForLanguage:(DSBIP39Language)language
{
    NSMutableData *entropy = [NSMutableData secureDataWithLength:SEED_ENTROPY_LENGTH];
    
    if (SecRandomCopyBytes(kSecRandomDefault, entropy.length, entropy.mutableBytes) != 0) return nil;
    
    if (language != DSBIP39Language_Default) {
        [[DSBIP39Mnemonic sharedInstance] setDefaultLanguage:language];
    }
    
    NSString *phrase = [[DSBIP39Mnemonic sharedInstance] encodePhrase:entropy];
    
    return phrase;
}

+ (NSString *)generateRandomSeed {
    return [self generateRandomSeedForLanguage:DSBIP39Language_Default];
}

- (void)seedPhraseAfterAuthentication:(void (^)(NSString * _Nullable))completion
{
    [self seedPhraseAfterAuthenticationWithPrompt:nil completion:completion];
}

-(BOOL)hasSeedPhrase {
    NSError * error = nil;
    BOOL hasSeed = hasKeychainData(self.uniqueID, &error);
    return hasSeed;
}

+ (NSString*)setSeedPhrase:(NSString *)seedPhrase createdAt:(NSTimeInterval)createdAt withAccounts:(NSArray*)accounts storeOnKeychain:(BOOL)storeOnKeychain forChain:(DSChain*)chain
{
    if (!seedPhrase) return nil;
    NSString * uniqueID = nil;
    @autoreleasepool { // @autoreleasepool ensures sensitive data will be deallocated immediately
        // we store the wallet creation time on the keychain because keychain data persists even when an app is deleted
        seedPhrase = [[DSBIP39Mnemonic sharedInstance] normalizePhrase:seedPhrase];
        
        NSData * derivedKeyData = (seedPhrase) ?[[DSBIP39Mnemonic sharedInstance]
                                                 deriveKeyFromPhrase:seedPhrase withPassphrase:nil]:nil;
        UInt512 I;
        
        HMAC(&I, SHA512, sizeof(UInt512), BIP32_SEED_KEY, strlen(BIP32_SEED_KEY), derivedKeyData.bytes, derivedKeyData.length);
        
        NSData * publicKey = [DSECDSAKey keyWithSecret:*(UInt256 *)&I compressed:YES].publicKeyData;
        NSMutableData * uniqueIDData = [[NSData dataWithUInt256:chain.genesisHash] mutableCopy];
        [uniqueIDData appendData:publicKey];
        uniqueID = [NSData dataWithUInt256:[uniqueIDData SHA256]].shortHexString; //one way injective function
        NSString * storeOnUniqueId = nil;//if not store on keychain then we wont save the extended public keys below.
        if (storeOnKeychain) {
            if (! setKeychainString(seedPhrase, [DSWallet mnemonicUniqueIDForUniqueID:uniqueID], YES) || (createdAt && !setKeychainData([NSData dataWithBytes:&createdAt length:sizeof(createdAt)], [DSWallet creationTimeUniqueIDForUniqueID:uniqueID], NO))) {
                NSAssert(FALSE, @"error setting wallet seed");
                
                return nil;
            }
            
            //in version 2.0.0 wallet creation times were migrated from reference date, since this is now fixed just add this line so verification only happens once
            setKeychainInt(1, [DSWallet didVerifyCreationTimeUniqueIDForUniqueID:uniqueID], NO);
            storeOnUniqueId = uniqueID;
        }
        
        for (DSAccount * account in accounts) {
            for (DSDerivationPath * derivationPath in account.derivationPaths) {
                [derivationPath generateExtendedPublicKeyFromSeed:derivedKeyData storeUnderWalletUniqueId:storeOnUniqueId];
            }
        }
    }
    return uniqueID;
}

// authenticates user and returns seed
- (void)seedWithPrompt:(NSString *)authprompt forAmount:(uint64_t)amount completion:(_Nullable SeedCompletionBlock)completion
{
    @autoreleasepool {
        if (!authprompt && [DSAuthenticationManager sharedInstance].didAuthenticate) {
            completion([[DSBIP39Mnemonic sharedInstance] deriveKeyFromPhrase:getKeychainString(self.mnemonicUniqueID, nil) withPassphrase:nil],NO);
            return;
        }
        BOOL touchid = amount?((self.totalSent + amount < getKeychainInt(SPEND_LIMIT_KEY, nil)) ? YES : NO):NO;
        
        [[DSAuthenticationManager sharedInstance] authenticateWithPrompt:authprompt andTouchId:touchid alertIfLockout:YES completion:^(BOOL authenticated,BOOL cancelled) {
            if (!authenticated) {
                completion(nil,cancelled);
            } else {
                // BUG: if user manually chooses to enter pin, the Touch ID spending limit is reset, but the tx being authorized
                // still counts towards the next Touch ID spending limit
                if (! touchid) setKeychainInt(self.totalSent + amount + [DSChainsManager sharedInstance].spendingLimit, SPEND_LIMIT_KEY, NO);
                completion([[DSBIP39Mnemonic sharedInstance] deriveKeyFromPhrase:getKeychainString(self.mnemonicUniqueID, nil) withPassphrase:nil],cancelled);
            }
        }];
        
    }
}

-(NSString*)seedPhraseIfAuthenticated {
    
    if (![DSAuthenticationManager sharedInstance].usesAuthentication || [DSAuthenticationManager sharedInstance].didAuthenticate) {
        return getKeychainString(self.mnemonicUniqueID, nil);
    } else {
        return nil;
    }
}

// authenticates user and returns seedPhrase
- (void)seedPhraseAfterAuthenticationWithPrompt:(NSString *)authprompt completion:(void (^)(NSString * seedPhrase))completion
{
    @autoreleasepool {
        [[DSAuthenticationManager sharedInstance] authenticateWithPrompt:authprompt andTouchId:NO alertIfLockout:YES completion:^(BOOL authenticated,BOOL cancelled) {
            NSString * rSeedPhrase = authenticated?getKeychainString(self.mnemonicUniqueID, nil):nil;
            completion(rSeedPhrase);
        }];
    }
}

// MARK: - Authentication

// private key for signing authenticated api calls

-(void)authPrivateKey:(void (^ _Nullable)(NSString * _Nullable authKey))completion;
{
    @autoreleasepool {
        self.seedRequestBlock(@"Please authorize", 0, ^(NSData * _Nullable seed, BOOL cancelled) {
            @autoreleasepool {
                NSString *privKey = getKeychainString(AUTH_PRIVKEY_KEY, nil);
                if (! privKey) {
                    privKey = [DSDerivationPath authPrivateKeyFromSeed:seed forChain:self.chain];
                    setKeychainString(privKey, AUTH_PRIVKEY_KEY, NO);
                }
                
                completion(privKey);
            }
        });
    }
}

// MARK: - Combining Accounts

-(uint64_t)balance {
    uint64_t rBalance = 0;
    for (DSAccount * account in self.accounts) {
        rBalance += account.balance;
    }
    return rBalance;
}

-(NSArray *)registerAddressesWithGapLimit:(NSUInteger)gapLimit internal:(BOOL)internal {
    NSMutableArray * mArray = [NSMutableArray array];
    for (DSAccount * account in self.accounts) {
        [mArray addObjectsFromArray:[account registerAddressesWithGapLimit:gapLimit internal:internal]];
    }
    return [mArray copy];
}

- (DSAccount*)accountContainingTransaction:(DSTransaction *)transaction {
    for (DSAccount * account in self.accounts) {
        if ([account containsTransaction:transaction]) return account;
    }
    return FALSE;
}

// all previously generated external addresses
-(NSSet *)allReceiveAddresses {
    NSMutableSet * mSet = [NSMutableSet set];
    for (DSAccount * account in self.accounts) {
        [mSet addObjectsFromArray:[account externalAddresses]];
    }
    return [mSet copy];
}

// all previously generated internal addresses
-(NSSet *)allChangeAddresses {
    NSMutableSet * mSet = [NSMutableSet set];
    for (DSAccount * account in self.accounts) {
        [mSet addObjectsFromArray:[account internalAddresses]];
    }
    return [mSet copy];
}

-(NSArray *) allTransactions {
    NSMutableSet * mSet = [NSMutableSet set];
    for (DSAccount * account in self.accounts) {
        [mSet addObjectsFromArray:account.allTransactions];
    }
    [mSet addObjectsFromArray:[self.specialTransactionsHolder allTransactions]];
    return [mSet allObjects];
}

- (DSTransaction *)transactionForHash:(UInt256)txHash {
    for (DSAccount * account in self.accounts) {
        DSTransaction * transaction = [account transactionForHash:txHash];
        if (transaction) return transaction;
    }
    DSTransaction * transaction = [self.specialTransactionsHolder transactionForHash:txHash];
    if (transaction) return transaction;
    return nil;
}

-(NSArray *) unspentOutputs {
    NSMutableArray * mArray = [NSMutableArray array];
    for (DSAccount * account in self.accounts) {
        [mArray addObjectsFromArray:account.unspentOutputs];
    }
    return mArray;
}

// true if the address is controlled by the wallet, this can also be for paths that are not accounts (todo)
- (BOOL)containsAddress:(NSString *)address {
    for (DSAccount * account in self.accounts) {
        if ([account containsAddress:address]) return TRUE;
    }
    return FALSE;
}

- (DSAccount*)accountForAddress:(NSString *)address {
    for (DSAccount * account in self.accounts) {
        if ([account containsAddress:address]) return account;
    }
    return nil;
}

// true if the address was previously used as an input or output in any wallet transaction
- (BOOL)addressIsUsed:(NSString *)address {
    for (DSAccount * account in self.accounts) {
        if ([account addressIsUsed:address]) return TRUE;
    }
    return FALSE;
}

// returns the amount received by the wallet from the transaction (total outputs to change and/or receive addresses)
- (uint64_t)amountReceivedFromTransaction:(DSTransaction *)transaction {
    uint64_t received = 0;
    for (DSAccount * account in self.accounts) {
        received += [account amountReceivedFromTransaction:transaction];
    }
    return received;
}

// retuns the amount sent from the wallet by the trasaction (total wallet outputs consumed, change and fee included)
- (uint64_t)amountSentByTransaction:(DSTransaction *)transaction {
    uint64_t sent = 0;
    for (DSAccount * account in self.accounts) {
        sent += [account amountSentByTransaction:transaction];
    }
    return sent;
}

// set the block heights and timestamps for the given transactions, use a height of TX_UNCONFIRMED and timestamp of 0 to
// indicate a transaction and it's dependents should remain marked as unverified (not 0-conf safe)
- (NSArray *)setBlockHeight:(int32_t)height andTimestamp:(NSTimeInterval)timestamp forTxHashes:(NSArray *)txHashes
{
    NSMutableArray *updated = [NSMutableArray array];
    
    for (DSAccount * account in self.accounts) {
        NSArray * fromAccount = [account setBlockHeight:height andTimestamp:timestamp forTxHashes:txHashes];
        if (fromAccount)
            [updated addObjectsFromArray:fromAccount];
    }
    return updated;
}

- (DSAccount *)accountForTransactionHash:(UInt256)txHash transaction:(DSTransaction **)transaction {
    for (DSAccount * account in self.accounts) {
        DSTransaction * lTransaction = [account transactionForHash:txHash];
        if (lTransaction) {
            if (transaction) *transaction = lTransaction;
            return account;
        }
    }
    return nil;
}

- (BOOL)transactionIsValid:(DSTransaction * _Nonnull)transaction {
    for (DSAccount * account in self.accounts) {
        if (![account transactionIsValid:transaction]) return FALSE;
    }
    return TRUE;
}

-(DSKey*)privateKeyForAddress:(NSString*)address fromSeed:(NSData*)seed {
    DSAccount * account = [self accountForAddress:address];
    if (!account) return nil;
    DSFundsDerivationPath * derivationPath = [account derivationPathContainingAddress:address];
    if (!derivationPath) return nil;
    NSIndexPath * indexPath = [derivationPath indexPathForAddress:address];
    return [derivationPath privateKeyAtIndexPath:indexPath fromSeed:seed];
}

// MARK: - Seed

- (NSString *)serializedPrivateMasterFromSeed:(NSData *)seed
{
    if (! seed) return nil;
    
    UInt512 I;
    
    HMAC(&I, SHA512, sizeof(UInt512), BIP32_SEED_KEY, strlen(BIP32_SEED_KEY), seed.bytes, seed.length);
    
    UInt256 secret = *(UInt256 *)&I, chain = *(UInt256 *)&I.u8[sizeof(UInt256)];
    
    return serialize(0, 0, 0, chain, [NSData dataWithBytes:&secret length:sizeof(secret)],[self.chain isMainnet]);
}

- (void)wipeBlockchainInfo {
    for (DSAccount * account in self.accounts) {
        [account wipeBlockchainInfo];
    }
}

// MARK: - Blockchain Users

-(NSArray*)blockchainUserAddresses {
    DSAuthenticationKeysDerivationPath * derivationPath = [[DSDerivationPathFactory sharedInstance] blockchainUsersKeysDerivationPathForWallet:self];
    if (!derivationPath.hasExtendedPublicKey) return @[];
    return [derivationPath addressesToIndex:[self unusedBlockchainUserIndex] + 10];
}

- (DSBlockchainUserRegistrationTransaction *)registrationTransactionForPublicKeyHash:(UInt160)publicKeyHash {
    for (DSAccount * account in self.accounts) {
        DSBlockchainUserRegistrationTransaction * transaction = [account blockchainUserRegistrationTransactionForPublicKeyHash:publicKeyHash];
        if (transaction) return transaction;
    }
    return nil;
}

- (UInt256)lastBlockchainUserTransactionHashForRegistrationTransactionHash:(UInt256)blockchainUserRegistrationTransactionHash {
    UInt256 lastSubscriptionTransactionHash = blockchainUserRegistrationTransactionHash;
    UInt256 startLastSubscriptionTransactionHash;
    do {
        startLastSubscriptionTransactionHash = lastSubscriptionTransactionHash;
        for (DSAccount * account in self.accounts) {
            lastSubscriptionTransactionHash = [account lastSubscriptionTransactionHashForRegistrationTransactionHash:lastSubscriptionTransactionHash];
        }
    }
    while (!uint256_eq(startLastSubscriptionTransactionHash, lastSubscriptionTransactionHash));
    return lastSubscriptionTransactionHash;
}

- (DSBlockchainUserResetTransaction *)resetTransactionForPublicKeyHash:(UInt160)publicKeyHash {
    for (DSAccount * account in self.accounts) {
        DSBlockchainUserResetTransaction * transaction = [account blockchainUserResetTransactionForPublicKeyHash:publicKeyHash];
        if (transaction) return transaction;
    }
    return nil;
}

-(DSBlockchainUserRegistrationTransaction *)registrationTransactionForIndex:(uint32_t)index {
    DSAuthenticationKeysDerivationPath * derivationPath = [[DSDerivationPathFactory sharedInstance] blockchainUsersKeysDerivationPathForWallet:self];
    UInt160 hash160 = [derivationPath publicKeyDataAtIndex:index].hash160;
    return [self registrationTransactionForPublicKeyHash:hash160];
}

-(void)unregisterBlockchainUser:(DSBlockchainUser *)blockchainUser {
    NSAssert(blockchainUser.wallet == self, @"the blockchainUser you are trying to remove is not in this wallet");
    [self.mBlockchainUsers removeObjectForKey:blockchainUser.username];
    NSError * error = nil;
    NSMutableDictionary * keyChainDictionary = [getKeychainDict(self.walletBlockchainUsersKey, &error) mutableCopy];
    if (!keyChainDictionary) keyChainDictionary = [NSMutableDictionary dictionary];
    [keyChainDictionary removeObjectForKey:blockchainUser.username];
    setKeychainDict(keyChainDictionary, self.walletBlockchainUsersKey, NO);
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DSChainBlockchainUsersDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain}];
    });
}
-(void)addBlockchainUser:(DSBlockchainUser *)blockchainUser {
    [self.mBlockchainUsers setObject:@(blockchainUser.index) forKey:blockchainUser.username];
}

- (void)registerBlockchainUser:(DSBlockchainUser *)blockchainUser
{
    if ([self.mBlockchainUsers objectForKey:blockchainUser.username] == nil) {
        [self addBlockchainUser:blockchainUser];
    }
    NSError * error = nil;
    NSMutableDictionary * keyChainDictionary = [getKeychainDict(self.walletBlockchainUsersKey, &error) mutableCopy];
    if (!keyChainDictionary) keyChainDictionary = [NSMutableDictionary dictionary];
    [keyChainDictionary setObject:@(blockchainUser.index) forKey:blockchainUser.username];
    setKeychainDict(keyChainDictionary, self.walletBlockchainUsersKey, NO);
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DSChainBlockchainUsersDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain}];
    });
}

-(NSArray*)blockchainUsers {
    NSError * error = nil;
    NSMutableDictionary * keyChainDictionary = [getKeychainDict(self.walletBlockchainUsersKey, &error) mutableCopy];
    NSMutableArray * rArray = [NSMutableArray array];
    if (keyChainDictionary) {
        for (NSString * username in keyChainDictionary) {
            uint32_t index = [keyChainDictionary[username] unsignedIntValue];
            UInt256 registrationTransactionHash = [self registrationTransactionForIndex:index].txHash;
            UInt256 lastBlockchainUserTransactionHash = [self lastBlockchainUserTransactionHashForRegistrationTransactionHash:registrationTransactionHash];
            [rArray addObject:[[DSBlockchainUser alloc] initWithUsername:username atIndex:[keyChainDictionary[username] unsignedIntValue] inWallet:self createdWithTransactionHash:registrationTransactionHash lastBlockchainUserTransactionHash:lastBlockchainUserTransactionHash]];
        }
    }
    return [rArray copy];
}

-(uint32_t)unusedBlockchainUserIndex {
    NSArray * indexes = [_mBlockchainUsers allValues];
    NSNumber * max = [indexes valueForKeyPath:@"@max.intValue"];
    return max != nil ? ([max unsignedIntValue] + 1) : 0;
}

-(DSBlockchainUser*)createBlockchainUserForUsername:(NSString*)username {
    DSBlockchainUser * blockchainUser = [[DSBlockchainUser alloc] initWithUsername:username atIndex:[self unusedBlockchainUserIndex] inWallet:self];
    return blockchainUser;
}

// MARK: - Masternodes (Providers)

- (void)registerMasternodeOperator:(DSLocalMasternode *)masternode
{
    if ([self.mMasternodeOperators objectForKey:uint256_data(masternode.providerRegistrationTransaction.txHash)] == nil) {
        [self.mMasternodeOperators setObject:@(masternode.operatorWalletIndex) forKey:uint256_data(masternode.providerRegistrationTransaction.txHash)];
    }
    NSError * error = nil;
    NSMutableDictionary * keyChainDictionary = [getKeychainDict(self.walletMasternodeOperatorsKey, &error) mutableCopy];
    if (!keyChainDictionary) keyChainDictionary = [NSMutableDictionary dictionary];
    [keyChainDictionary setObject:@(masternode.operatorWalletIndex) forKey:uint256_data(masternode.providerRegistrationTransaction.txHash)];
    setKeychainDict(keyChainDictionary, self.walletMasternodeOperatorsKey, NO);
}

- (void)registerMasternodeOwner:(DSLocalMasternode *)masternode
{
    if ([self.mMasternodeOwners objectForKey:uint256_data(masternode.providerRegistrationTransaction.txHash)] == nil) {
        [self.mMasternodeOwners setObject:@(masternode.ownerWalletIndex) forKey:uint256_data(masternode.providerRegistrationTransaction.txHash)];
    }
    NSError * error = nil;
    NSMutableDictionary * keyChainDictionary = [getKeychainDict(self.walletMasternodeOwnersKey, &error) mutableCopy];
    if (!keyChainDictionary) keyChainDictionary = [NSMutableDictionary dictionary];
    [keyChainDictionary setObject:@(masternode.ownerWalletIndex) forKey:uint256_data(masternode.providerRegistrationTransaction.txHash)];
    setKeychainDict(keyChainDictionary, self.walletMasternodeOwnersKey, NO);
}

- (void)registerMasternodeVoter:(DSLocalMasternode *)masternode
{
    if ([self.mMasternodeVoters objectForKey:uint256_data(masternode.providerRegistrationTransaction.txHash)] == nil) {
        [self.mMasternodeVoters setObject:@(masternode.votingWalletIndex) forKey:uint256_data(masternode.providerRegistrationTransaction.txHash)];
    }
    NSError * error = nil;
    NSMutableDictionary * keyChainDictionary = [getKeychainDict(self.walletMasternodeVotersKey, &error) mutableCopy];
    if (!keyChainDictionary) keyChainDictionary = [NSMutableDictionary dictionary];
    [keyChainDictionary setObject:@(masternode.votingWalletIndex) forKey:uint256_data(masternode.providerRegistrationTransaction.txHash)];
    setKeychainDict(keyChainDictionary, self.walletMasternodeVotersKey, NO);
}

- (BOOL)containsProviderVotingAuthenticationHash:(UInt160)votingAuthenticationHash {
    DSAuthenticationKeysDerivationPath * derivationPath = [DSAuthenticationKeysDerivationPath providerVotingKeysDerivationPathForWallet:self];
    return [derivationPath containsAddress:[[NSData dataWithUInt160:votingAuthenticationHash] addressFromHash160DataForChain:self.chain]];
}

- (BOOL)containsProviderOwningAuthenticationHash:(UInt160)owningAuthenticationHash {
    DSAuthenticationKeysDerivationPath * derivationPath = [DSAuthenticationKeysDerivationPath providerOwnerKeysDerivationPathForWallet:self];
    return [derivationPath containsAddress:[[NSData dataWithUInt160:owningAuthenticationHash] addressFromHash160DataForChain:self.chain]];
}

- (BOOL)containsProviderOperatorAuthenticationKey:(UInt384)providerOperatorAuthenticationKey {
    DSAuthenticationKeysDerivationPath * derivationPath = [DSAuthenticationKeysDerivationPath providerOperatorKeysDerivationPathForWallet:self];
    return [derivationPath containsAddress:[[NSData dataWithUInt160:[[NSData dataWithUInt384:providerOperatorAuthenticationKey] hash160]] addressFromHash160DataForChain:self.chain]];
}

- (BOOL)containsBlockchainUserAuthenticationHash:(UInt160)blockchainUserAuthenticationHash {
    DSAuthenticationKeysDerivationPath * derivationPath = [DSAuthenticationKeysDerivationPath blockchainUsersKeysDerivationPathForWallet:self];
    return [derivationPath containsAddress:[[NSData dataWithUInt160:blockchainUserAuthenticationHash] addressFromHash160DataForChain:self.chain]];
}

- (BOOL)containsHoldingAddress:(NSString*)holdingAddress {
    DSMasternodeHoldingsDerivationPath * derivationPath = [DSMasternodeHoldingsDerivationPath providerFundsDerivationPathForWallet:self];
    return [derivationPath containsAddress:holdingAddress];
}

- (NSUInteger)indexOfProviderVotingAuthenticationHash:(UInt160)votingAuthenticationHash {
    DSAuthenticationKeysDerivationPath * derivationPath = [DSAuthenticationKeysDerivationPath providerVotingKeysDerivationPathForWallet:self];
    return [derivationPath indexOfKnownAddress:[[NSData dataWithUInt160:votingAuthenticationHash] addressFromHash160DataForChain:self.chain]];
}

- (NSUInteger)indexOfProviderOwningAuthenticationHash:(UInt160)owningAuthenticationHash {
    DSAuthenticationKeysDerivationPath * derivationPath = [DSAuthenticationKeysDerivationPath providerOwnerKeysDerivationPathForWallet:self];
    return [derivationPath indexOfKnownAddress:[[NSData dataWithUInt160:owningAuthenticationHash] addressFromHash160DataForChain:self.chain]];
}

- (NSUInteger)indexOfProviderOperatorAuthenticationKey:(UInt384)providerOperatorAuthenticationKey {
    DSAuthenticationKeysDerivationPath * derivationPath = [DSAuthenticationKeysDerivationPath providerOperatorKeysDerivationPathForWallet:self];
    return [derivationPath indexOfKnownAddress:[[NSData dataWithUInt160:[[NSData dataWithUInt384:providerOperatorAuthenticationKey] hash160]] addressFromHash160DataForChain:self.chain]];
}

- (NSUInteger)indexOfHoldingAddress:(NSString*)holdingAddress {
    DSMasternodeHoldingsDerivationPath * derivationPath = [DSMasternodeHoldingsDerivationPath providerFundsDerivationPathForWallet:self];
    return [derivationPath indexOfKnownAddress:holdingAddress];
}

- (NSUInteger)indexOfBlockchainUserAuthenticationHash:(UInt160)blockchainUserAuthenticationHash {
    DSAuthenticationKeysDerivationPath * derivationPath = [DSAuthenticationKeysDerivationPath blockchainUsersKeysDerivationPathForWallet:self];
    return [derivationPath indexOfKnownAddress:[[NSData dataWithUInt160:blockchainUserAuthenticationHash] addressFromHash160DataForChain:self.chain]];
}

@end
