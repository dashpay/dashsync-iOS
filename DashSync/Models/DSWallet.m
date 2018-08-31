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
#import "DSKey.h"
#import "NSData+Bitcoin.h"
#import "DSEnvironment.h"
#import "DSChainManager.h"
#import "DSBlockchainUser.h"
#import "DSBlockchainUserRegistrationTransaction.h"
#import "DSBlockchainUserResetTransaction.h"

#define SEED_ENTROPY_LENGTH   (128/8)
#define WALLET_CREATION_TIME_KEY   @"WALLET_CREATION_TIME_KEY"
#define AUTH_PRIVKEY_KEY    @"authprivkey"
#define WALLET_MNEMONIC_KEY        @"WALLET_MNEMONIC_KEY"
#define WALLET_MASTER_PUBLIC_KEY        @"WALLET_MASTER_PUBLIC_KEY"
#define WALLET_BLOCKCHAIN_USERS_KEY  @"WALLET_BLOCKCHAIN_USERS_KEY"

@interface DSWallet()

@property (nonatomic, strong) DSChain * chain;
@property (nonatomic, strong) NSMutableDictionary * mAccounts;
@property (nonatomic, copy) NSString * uniqueID;
@property (nonatomic, assign) NSTimeInterval walletCreationTime;
@property (nonatomic, strong) NSMutableDictionary<NSString *,NSNumber *> * mBlockchainUsers;
@property (nonatomic, strong) SeedRequestBlock seedRequestBlock;

@end

@implementation DSWallet

+ (DSWallet*)standardWalletWithSeedPhrase:(NSString*)seedPhrase forChain:(DSChain*)chain storeSeedPhrase:(BOOL)store {
    DSAccount * account = [DSAccount accountWithDerivationPaths:[chain standardDerivationPathsForAccountNumber:0]];
    NSString * uniqueId = [self setSeedPhrase:seedPhrase withAccounts:@[account] storeOnKeychain:store]; //make sure we can create the wallet first
    if (!uniqueId) return nil;
    DSWallet * wallet = [[DSWallet alloc] initWithUniqueID:uniqueId andAccount:account forChain:chain storeSeedPhrase:store];
    return wallet;
}

+ (DSWallet*)standardWalletWithRandomSeedPhraseForChain:(DSChain* )chain {
    return [self standardWalletWithSeedPhrase:[self generateRandomSeed] forChain:chain storeSeedPhrase:YES];
}

-(instancetype)initWithChain:(DSChain*)chain {
    if (! (self = [super init])) return nil;
    self.mAccounts = [NSMutableDictionary dictionary];
    self.chain = chain;
    self.mBlockchainUsers = [NSMutableDictionary dictionary];
    return self;
}

-(instancetype)initWithUniqueID:(NSString*)uniqueID andAccount:(DSAccount*)account forChain:(DSChain*)chain storeSeedPhrase:(BOOL)store {
    if (! (self = [self initWithChain:chain])) return nil;
    self.uniqueID = uniqueID;
    if (store) {
        __weak typeof(self) weakSelf = self;
        self.seedRequestBlock = ^void(NSString *authprompt, uint64_t amount, SeedCompletionBlock seedCompletion) {
            //this happens when we request the seed
            [weakSelf seedWithPrompt:authprompt forAmount:amount completion:seedCompletion];
        };
    }
    if (account) [self addAccount:account]; //this must be last, as adding the account queries the wallet unique ID
    NSError * error = nil;
    self.mBlockchainUsers = [getKeychainDict(self.walletBlockchainUsersKey, &error) mutableCopy];
    if (error) return nil;
    return self;
}

-(instancetype)initWithUniqueID:(NSString*)uniqueID forChain:(DSChain*)chain {
    if (! (self = [self initWithUniqueID:uniqueID andAccount:[DSAccount accountWithDerivationPaths:[chain standardDerivationPathsForAccountNumber:0]] forChain:chain storeSeedPhrase:YES])) return nil;
    
    return self;
}

+(BOOL)verifyUniqueId:(NSString*)uniqueId {
    NSError * error = nil;
    BOOL hasData = hasKeychainData(uniqueId, &error);
    return (!error && hasData);
}

+ (DSWallet*)walletWithIdentifier:(NSString*)uniqueId forChain:(DSChain*)chain {
    if (![self verifyUniqueId:(NSString*)uniqueId]) return nil;
    DSWallet * wallet = [[DSWallet alloc] initWithChain:chain];
    wallet.uniqueID = uniqueId;
    return wallet;
}

-(NSString*)walletBlockchainUsersKey {
    return [NSString stringWithFormat:@"%@_%@",WALLET_BLOCKCHAIN_USERS_KEY,[self uniqueID]];
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

-(NSString*)creationTimeUniqueID {
    return [DSWallet creationTimeUniqueIDForUniqueID:self.uniqueID];
}

// MARK: - Seed

// generates a random seed, saves to keychain and returns the associated seedPhrase
+ (NSString *)generateRandomSeed
{
    NSMutableData *entropy = [NSMutableData secureDataWithLength:SEED_ENTROPY_LENGTH];
    
    if (SecRandomCopyBytes(kSecRandomDefault, entropy.length, entropy.mutableBytes) != 0) return nil;
    
    NSString *phrase = [[DSBIP39Mnemonic sharedInstance] encodePhrase:entropy];
    
    return phrase;
}

- (void)seedPhraseAfterAuthentication:(void (^)(NSString * _Nullable))completion
{
    [self seedPhraseWithPrompt:nil completion:completion];
}

-(BOOL)hasSeedPhrase {
    NSError * error = nil;
    BOOL hasSeed = hasKeychainData(self.uniqueID, &error);
    return hasSeed;
}

-(NSTimeInterval)walletCreationTime {
    if (_walletCreationTime) return _walletCreationTime;
    // interval since refrence date, 00:00:00 01/01/01 GMT
    NSData *d = getKeychainData(self.creationTimeUniqueID, nil);
    
    if (d.length == sizeof(NSTimeInterval)) return *(const NSTimeInterval *)d.bytes;
    return ([DSEnvironment sharedInstance].watchOnly) ? 0 : BIP39_CREATION_TIME;
}

+ (NSString*)setSeedPhrase:(NSString *)seedPhrase withAccounts:(NSArray*)accounts storeOnKeychain:(BOOL)storeOnKeychain
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
        
        NSData * publicKey = [DSKey keyWithSecret:*(UInt256 *)&I compressed:YES].publicKey;
        uniqueID = [NSData dataWithUInt256:[publicKey SHA256]].shortHexString; //one way injective function
        if (storeOnKeychain) {
            if (! setKeychainString(seedPhrase, [DSWallet mnemonicUniqueIDForUniqueID:uniqueID], YES) || ! setKeychainData([NSData dataWithBytes:&time length:sizeof(time)], [DSWallet creationTimeUniqueIDForUniqueID:uniqueID], NO)) {
                NSAssert(FALSE, @"error setting wallet seed");
                
                return nil;
            }
            
            for (DSAccount * account in accounts) {
                for (DSDerivationPath * derivationPath in account.derivationPaths) {
                    [derivationPath generateExtendedPublicKeyFromSeed:derivedKeyData storeUnderWalletUniqueId:uniqueID];
                }
            }
        }
    }
    return uniqueID;
}

// authenticates user and returns seed
- (void)seedWithPrompt:(NSString *)authprompt forAmount:(uint64_t)amount completion:(_Nullable SeedCompletionBlock)completion
{
    @autoreleasepool {
        BOOL touchid = amount?((self.totalSent + amount < getKeychainInt(SPEND_LIMIT_KEY, nil)) ? YES : NO):NO;
        
        [[DSAuthenticationManager sharedInstance] authenticateWithPrompt:authprompt andTouchId:touchid alertIfLockout:YES completion:^(BOOL authenticated,BOOL cancelled) {
            if (!authenticated) {
                completion(nil);
            } else {
                // BUG: if user manually chooses to enter pin, the Touch ID spending limit is reset, but the tx being authorized
                // still counts towards the next Touch ID spending limit
                if (! touchid) setKeychainInt(self.totalSent + amount + [DSPriceManager sharedInstance].spendingLimit, SPEND_LIMIT_KEY, NO);
                completion([[DSBIP39Mnemonic sharedInstance] deriveKeyFromPhrase:getKeychainString(self.mnemonicUniqueID, nil) withPassphrase:nil]);
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
- (void)seedPhraseWithPrompt:(NSString *)authprompt completion:(void (^)(NSString * seedPhrase))completion
{
    @autoreleasepool {
        [[DSAuthenticationManager sharedInstance] authenticateWithPrompt:authprompt andTouchId:NO alertIfLockout:YES completion:^(BOOL authenticated,BOOL cancelled) {
            NSString * rSeedPhrase = authenticated?getKeychainString(self.uniqueID, nil):nil;
            completion(rSeedPhrase);
        }];
    }
}

// MARK: - Authentication

// private key for signing authenticated api calls

-(void)authPrivateKey:(void (^ _Nullable)(NSString * _Nullable authKey))completion;
{
    @autoreleasepool {
        self.seedRequestBlock(@"Please authorize", 0, ^(NSData * _Nullable seed) {
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
    NSMutableArray * mArray = [NSMutableArray array];
    for (DSAccount * account in self.accounts) {
        [mArray addObjectsFromArray:account.allTransactions];
    }
    return mArray;
}

- (DSTransaction *)transactionForHash:(UInt256)txHash {
    for (DSAccount * account in self.accounts) {
        DSTransaction * transaction = [account transactionForHash:txHash];
        if (transaction) return transaction;
    }
    return nil;
}

-(NSArray *) unspentOutputs {
    NSMutableArray * mArray = [NSMutableArray array];
    for (DSAccount * account in self.accounts) {
        [mArray addObjectsFromArray:account.unspentOutputs];
    }
    return mArray;
}

// true if the address is controlled by the wallet
- (BOOL)containsAddress:(NSString *)address {
    for (DSAccount * account in self.accounts) {
        if ([account containsAddress:address]) return TRUE;
    }
    return FALSE;
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

- (DSBlockchainUserRegistrationTransaction *)registrationTransactionForPublicKeyHash:(UInt160)publicKeyHash {
    for (DSAccount * account in self.accounts) {
        DSBlockchainUserRegistrationTransaction * transaction = [account registrationTransactionForPublicKeyHash:publicKeyHash];
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
        DSBlockchainUserResetTransaction * transaction = [account resetTransactionForPublicKeyHash:publicKeyHash];
        if (transaction) return transaction;
    }
    return nil;
}

-(DSBlockchainUserRegistrationTransaction *)registrationTransactionForIndex:(uint32_t)index {
    DSDerivationPath * derivationPath = [DSDerivationPath blockchainUsersDerivationPathForWallet:self];
    UInt160 hash160 = [derivationPath publicKeyAtIndex:index].hash160;
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
        [[NSNotificationCenter defaultCenter] postNotificationName:DSChainBlockchainUsersDidChangeNotification object:nil userInfo:@{DSChainPeerManagerNotificationChainKey:self}];
    });
}
-(void)addBlockchainUser:(DSBlockchainUser *)blockchainUser {
    [self.mBlockchainUsers setObject:@(blockchainUser.index) forKey:blockchainUser.username];
}

- (void)registerBlockchainUser:(DSBlockchainUser *)blockchainUser
{
    if (![self.mBlockchainUsers objectForKey:blockchainUser.username]) {
        [self addBlockchainUser:blockchainUser];
    }
    NSError * error = nil;
    NSMutableDictionary * keyChainDictionary = [getKeychainDict(self.walletBlockchainUsersKey, &error) mutableCopy];
    if (!keyChainDictionary) keyChainDictionary = [NSMutableDictionary dictionary];
    [keyChainDictionary setObject:@(blockchainUser.index) forKey:blockchainUser.username];
    setKeychainDict(keyChainDictionary, self.walletBlockchainUsersKey, NO);
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DSChainBlockchainUsersDidChangeNotification object:nil userInfo:@{DSChainPeerManagerNotificationChainKey:self}];
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
    return max?([max unsignedIntValue] + 1):0;
}

-(DSBlockchainUser*)createBlockchainUserForUsername:(NSString*)username {
    DSBlockchainUser * blockchainUser = [[DSBlockchainUser alloc] initWithUsername:username atIndex:[self unusedBlockchainUserIndex] inWallet:self];
    return blockchainUser;
}

@end
