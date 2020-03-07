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
#import "DSBlockchainIdentity+Protected.h"
#import "DSBlockchainIdentityEntity+CoreDataClass.h"
#import "DSBlockchainIdentityRegistrationTransition.h"
#import "DSBlockchainIdentityUpdateTransition.h"
#import "DSProviderRegistrationTransaction.h"
#import "NSDate+Utils.h"
#import "DSLocalMasternode.h"
#import "DSAuthenticationKeysDerivationPath+Protected.h"
#import "DSMasternodeHoldingsDerivationPath+Protected.h"
#import "DSDerivationPathFactory.h"
#import "DSSpecialTransactionsWalletHolder.h"
#import "DSContactEntity+CoreDataClass.h"
#import "DSAccountEntity+CoreDataClass.h"
#import "DSIncomingFundsDerivationPath.h"
#import "DSFriendRequestEntity+CoreDataClass.h"
#import "DSDerivationPathEntity+CoreDataClass.h"
#import "DSCreditFundingDerivationPath+Protected.h"
#import "DSCreditFundingTransaction.h"
#import "DSCreditFundingTransactionEntity+CoreDataClass.h"
#import "DSBlockchainIdentityUsernameEntity+CoreDataClass.h"
#import "DSBlockchainIdentityKeyPathEntity+CoreDataClass.h"

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

@property (nonatomic, strong) NSMutableDictionary<NSData *,NSNumber *> * mMasternodeOperatorIndexes;
@property (nonatomic, strong) NSMutableDictionary<NSData *,NSNumber *> * mMasternodeOwnerIndexes;
@property (nonatomic, strong) NSMutableDictionary<NSData *,NSNumber *> * mMasternodeVoterIndexes;
@property (nonatomic, strong) NSMutableDictionary<NSData *,NSString *> * mMasternodeOperatorPublicKeyLocations;
@property (nonatomic, strong) NSMutableDictionary<NSData *,NSString *> * mMasternodeOwnerPrivateKeyLocations;
@property (nonatomic, strong) NSMutableDictionary<NSData *,NSString *> * mMasternodeVoterKeyLocations;

@property (nonatomic, strong) SeedRequestBlock seedRequestBlock;
@property (nonatomic, assign, getter=isTransient) BOOL transient;
@property (nonatomic, strong) NSMutableDictionary <NSData *,DSBlockchainIdentity*> * mBlockchainIdentities;

@end

@implementation DSWallet

+ (DSWallet*)standardWalletWithSeedPhrase:(NSString*)seedPhrase setCreationDate:(NSTimeInterval)creationDate forChain:(DSChain*)chain storeSeedPhrase:(BOOL)store isTransient:(BOOL)isTransient {
    NSParameterAssert(seedPhrase);
    NSParameterAssert(chain);
    
    DSAccount * account = [DSAccount accountWithAccountNumber:0 withDerivationPaths:[chain standardDerivationPathsForAccountNumber:0] inContext:chain.managedObjectContext];
    
    NSString * uniqueId = [self setSeedPhrase:seedPhrase createdAt:creationDate withAccounts:@[account] storeOnKeychain:store forChain:chain]; //make sure we can create the wallet first
    if (!uniqueId) return nil;
    [self registerSpecializedDerivationPathsForSeedPhrase:seedPhrase underUniqueId:uniqueId onChain:chain];
    DSWallet * wallet = [[DSWallet alloc] initWithUniqueID:uniqueId andAccount:account forChain:chain storeSeedPhrase:store isTransient:isTransient];
    
    return wallet;
}

+ (DSWallet*)standardWalletWithRandomSeedPhraseForChain:(DSChain*)chain storeSeedPhrase:(BOOL)store isTransient:(BOOL)isTransient {
    NSParameterAssert(chain);
    
    return [self standardWalletWithRandomSeedPhraseInLanguage:DSBIP39Language_Default forChain:chain storeSeedPhrase:store isTransient:isTransient];
}

+ (DSWallet*)standardWalletWithRandomSeedPhraseInLanguage:(DSBIP39Language)language forChain:(DSChain*)chain storeSeedPhrase:(BOOL)store isTransient:(BOOL)isTransient {
    NSParameterAssert(chain);
    
    return [self standardWalletWithSeedPhrase:[self generateRandomSeedForLanguage:language] setCreationDate:[NSDate timeIntervalSince1970] forChain:chain storeSeedPhrase:store isTransient:isTransient];
}

//this is for testing purposes only
+ (DSWallet*)transientWalletWithDerivedKeyData:(NSData*)derivedData forChain:(DSChain*)chain {
    NSParameterAssert(derivedData);
    NSParameterAssert(chain);
    
    DSAccount * account = [DSAccount accountWithAccountNumber:0 withDerivationPaths:[chain standardDerivationPathsForAccountNumber:0] inContext:chain.managedObjectContext];
    
    NSString * uniqueId = [self setTransientDerivedKeyData:derivedData withAccounts:@[account] forChain:chain]; //make sure we can create the wallet first
    if (!uniqueId) return nil;
    //[self registerSpecializedDerivationPathsForSeedPhrase:seedPhrase underUniqueId:uniqueId onChain:chain];
    DSWallet * wallet = [[DSWallet alloc] initWithUniqueID:uniqueId andAccount:account forChain:chain storeSeedPhrase:NO isTransient:YES];
    
    return wallet;
}

-(instancetype)initWithChain:(DSChain*)chain {
    NSParameterAssert(chain);
    
    if (! (self = [super init])) return nil;
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

-(instancetype)initWithUniqueID:(NSString*)uniqueID andAccount:(DSAccount*)account forChain:(DSChain*)chain storeSeedPhrase:(BOOL)store isTransient:(BOOL)isTransient {
    NSParameterAssert(uniqueID);
    NSParameterAssert(account);
    NSParameterAssert(chain);
    
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
    
    [[DSDerivationPathFactory sharedInstance] loadedSpecializedDerivationPathsForWallet:self];
    
    self.specialTransactionsHolder = [[DSSpecialTransactionsWalletHolder alloc] initWithWallet:self inContext:self.chain.managedObjectContext];
    
    NSError * error = nil;
    
    self.mBlockchainIdentities = nil;
    [self blockchainIdentities];
    
    //blockchain users are loaded
    
    //add blockchain user derivation paths to account
    
    [self.chain.managedObjectContext performBlockAndWait:^{
        
        NSMutableArray * usedFriendshipIdentifiers = [NSMutableArray array];
        for (NSData * blockchainIdentityData in self.mBlockchainIdentities) {
            DSBlockchainIdentity * blockchainIdentity = [self.mBlockchainIdentities objectForKey:blockchainIdentityData];
            for (DSFriendRequestEntity * friendRequest in blockchainIdentity.ownContact.outgoingRequests) {
                DSAccount * account = [self accountWithNumber:friendRequest.account.index];
                DSIncomingFundsDerivationPath * fundsDerivationPath = [DSIncomingFundsDerivationPath
                                                               contactBasedDerivationPathWithDestinationBlockchainIdentityUniqueId:friendRequest.destinationContact.associatedBlockchainIdentityUniqueId.UInt256 sourceBlockchainIdentityUniqueId:blockchainIdentity.uniqueID forAccountNumber:account.accountNumber onChain:self.chain];
                fundsDerivationPath.wallet = self;
                fundsDerivationPath.account = account;
                NSLog(@"%@",blockchainIdentity.ownContact.outgoingRequests);
                [account addIncomingDerivationPath:fundsDerivationPath forFriendshipIdentifier:friendRequest.friendshipIdentifier];
                [usedFriendshipIdentifiers addObject:friendRequest.friendshipIdentifier];
            }
        }
        
        for (NSData * blockchainUniqueIdData in self.mBlockchainIdentities) {
            DSBlockchainIdentity * blockchainIdentity = [self.mBlockchainIdentities objectForKey:blockchainUniqueIdData];
            for (DSFriendRequestEntity * friendRequest in blockchainIdentity.ownContact.incomingRequests) {
                
                DSAccount * account = [self accountWithNumber:friendRequest.account.index];
                DSIncomingFundsDerivationPath * fundsDerivationPath = [account derivationPathForFriendshipWithIdentifier:friendRequest.friendshipIdentifier];
                if (fundsDerivationPath) {
                    //both contacts are on device
                    [account addOutgoingDerivationPath:fundsDerivationPath forFriendshipIdentifier:friendRequest.friendshipIdentifier];
                } else {
                    DSDerivationPathEntity * derivationPathEntity = friendRequest.derivationPath;
                    
                    DSIncomingFundsDerivationPath * incomingFundsDerivationPath = [DSIncomingFundsDerivationPath
                                                                       externalDerivationPathWithExtendedPublicKeyUniqueID:derivationPathEntity.publicKeyIdentifier withDestinationBlockchainIdentityUniqueId:friendRequest.destinationContact.associatedBlockchainIdentityUniqueId.UInt256 sourceBlockchainIdentityUniqueId:friendRequest.sourceContact.associatedBlockchainIdentityUniqueId.UInt256 onChain:self.chain];
                    incomingFundsDerivationPath.wallet = self;
                    incomingFundsDerivationPath.account = account;
                    [account addOutgoingDerivationPath:incomingFundsDerivationPath forFriendshipIdentifier:friendRequest.friendshipIdentifier];
                }
            }
        }
    }];

    if (error) return nil;
    return self;
}


+(void)registerSpecializedDerivationPathsForSeedPhrase:(NSString*)seedPhrase underUniqueId:(NSString*)walletUniqueId onChain:(DSChain*)chain {
    @autoreleasepool {
        seedPhrase = [[DSBIP39Mnemonic sharedInstance] normalizePhrase:seedPhrase];
        
        NSData * derivedKeyData = (seedPhrase) ?[[DSBIP39Mnemonic sharedInstance]
                                                 deriveKeyFromPhrase:seedPhrase withPassphrase:nil]:nil;
        
        DSAuthenticationKeysDerivationPath * providerOwnerKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerOwnerKeysDerivationPathForChain:chain];
        [providerOwnerKeysDerivationPath generateExtendedPublicKeyFromSeed:derivedKeyData storeUnderWalletUniqueId:walletUniqueId];
        DSAuthenticationKeysDerivationPath * providerOperatorKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerOperatorKeysDerivationPathForChain:chain];
        [providerOperatorKeysDerivationPath generateExtendedPublicKeyFromSeed:derivedKeyData storeUnderWalletUniqueId:walletUniqueId];
        DSAuthenticationKeysDerivationPath * providerVotingKeysDerivationPath = [DSAuthenticationKeysDerivationPath providerVotingKeysDerivationPathForChain:chain];
        [providerVotingKeysDerivationPath generateExtendedPublicKeyFromSeed:derivedKeyData storeUnderWalletUniqueId:walletUniqueId];
        DSMasternodeHoldingsDerivationPath * providerFundsDerivationPath = [DSMasternodeHoldingsDerivationPath providerFundsDerivationPathForChain:chain];
        [providerFundsDerivationPath generateExtendedPublicKeyFromSeed:derivedKeyData storeUnderWalletUniqueId:walletUniqueId];
        
        if (chain.isDevnetAny) {
            DSAuthenticationKeysDerivationPath * blockchainIdentityBLSKeysDerivationPath = [DSAuthenticationKeysDerivationPath blockchainIdentityBLSKeysDerivationPathForChain:chain];
            [blockchainIdentityBLSKeysDerivationPath generateExtendedPublicKeyFromSeed:derivedKeyData storeUnderWalletUniqueId:walletUniqueId];
            
            DSAuthenticationKeysDerivationPath * blockchainIdentityECDSAKeysDerivationPath = [DSAuthenticationKeysDerivationPath blockchainIdentityECDSAKeysDerivationPathForChain:chain];
            [blockchainIdentityECDSAKeysDerivationPath generateExtendedPublicKeyFromSeed:derivedKeyData storeUnderWalletUniqueId:walletUniqueId];
            
            DSCreditFundingDerivationPath * blockchainIdentityRegistrationFundingDerivationPath = [DSCreditFundingDerivationPath blockchainIdentityRegistrationFundingDerivationPathForChain:chain];
            [blockchainIdentityRegistrationFundingDerivationPath generateExtendedPublicKeyFromSeed:derivedKeyData storeUnderWalletUniqueId:walletUniqueId];
            
            DSCreditFundingDerivationPath * blockchainIdentityTopupFundingDerivationPath = [DSCreditFundingDerivationPath blockchainIdentityTopupFundingDerivationPathForChain:chain];
            [blockchainIdentityTopupFundingDerivationPath generateExtendedPublicKeyFromSeed:derivedKeyData storeUnderWalletUniqueId:walletUniqueId];
        }
    }
}

-(instancetype)initWithUniqueID:(NSString*)uniqueID forChain:(DSChain*)chain {
    if (! (self = [self initWithUniqueID:uniqueID andAccount:[DSAccount accountWithAccountNumber:0 withDerivationPaths:[chain standardDerivationPathsForAccountNumber:0] inContext:chain.managedObjectContext] forChain:chain storeSeedPhrase:NO isTransient:NO])) return nil;
    return self;
}

-(NSString*)walletBlockchainIdentitiesKey {
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
    NSParameterAssert(account);
    
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
    NSString *prompt = [NSString stringWithFormat:DSLocalizedString(@"Please authenticate to create your %@ wallet",
    @"Please authenticate to create your Testnet wallet"),
                        chain.localizedName];
    
    [self seedPhraseAfterAuthenticationWithPrompt:prompt completion:^(NSString * _Nullable seedPhrase) {
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
    NSParameterAssert(uniqueID);
    
    return [NSString stringWithFormat:@"%@_%@",WALLET_CREATION_TIME_KEY,uniqueID];
}

+(NSString*)creationGuessTimeUniqueIDForUniqueID:(NSString*)uniqueID {
    NSParameterAssert(uniqueID);
    
    return [NSString stringWithFormat:@"%@_%@",WALLET_CREATION_GUESS_TIME_KEY,uniqueID];
}

+(NSString*)didVerifyCreationTimeUniqueIDForUniqueID:(NSString*)uniqueID {
    NSParameterAssert(uniqueID);
    
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

+ (NSString*)setTransientDerivedKeyData:(NSData *)derivedKeyData withAccounts:(NSArray*)accounts forChain:(DSChain*)chain
{
    if (!derivedKeyData) return nil;
    NSString * uniqueID = nil;
    @autoreleasepool { // @autoreleasepool ensures sensitive data will be deallocated immediately
        // we store the wallet creation time on the keychain because keychain data persists even when an app is deleted
        UInt512 I;
        
        HMAC(&I, SHA512, sizeof(UInt512), BIP32_SEED_KEY, strlen(BIP32_SEED_KEY), derivedKeyData.bytes, derivedKeyData.length);
        
        NSData * publicKey = [DSECDSAKey keyWithSecret:*(UInt256 *)&I compressed:YES].publicKeyData;
        NSMutableData * uniqueIDData = [[NSData dataWithUInt256:chain.genesisHash] mutableCopy];
        [uniqueIDData appendData:publicKey];
        uniqueID = [NSData dataWithUInt256:[uniqueIDData SHA256]].shortHexString; //one way injective function
        
        for (DSAccount * account in accounts) {
            for (DSDerivationPath * derivationPath in account.fundDerivationPaths) {
                [derivationPath generateExtendedPublicKeyFromSeed:derivedKeyData storeUnderWalletUniqueId:nil];
            }
            if ([chain isDevnetAny]) {
                [account.masterContactsDerivationPath generateExtendedPublicKeyFromSeed:derivedKeyData storeUnderWalletUniqueId:nil];
            }
        }
    }
    return uniqueID;
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
            for (DSDerivationPath * derivationPath in account.fundDerivationPaths) {
                [derivationPath generateExtendedPublicKeyFromSeed:derivedKeyData storeUnderWalletUniqueId:storeOnUniqueId];
            }
            if ([chain isDevnetAny]) {
                [account.masterContactsDerivationPath generateExtendedPublicKeyFromSeed:derivedKeyData storeUnderWalletUniqueId:storeOnUniqueId];
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
        
        [[DSAuthenticationManager sharedInstance] authenticateWithPrompt:authprompt usingBiometricAuthentication:touchid alertIfLockout:YES completion:^(BOOL authenticated,BOOL cancelled) {
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
        [[DSAuthenticationManager sharedInstance] authenticateWithPrompt:authprompt usingBiometricAuthentication:NO alertIfLockout:YES completion:^(BOOL authenticated,BOOL cancelled) {
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

- (DSAccount*)firstAccountThatCanContainTransaction:(DSTransaction *)transaction {
    NSParameterAssert(transaction);
    
    for (DSAccount * account in self.accounts) {
        if ([account canContainTransaction:transaction]) return account;
    }
    return FALSE;
}

- (NSArray*)accountsThatCanContainTransaction:(DSTransaction *)transaction {
    NSParameterAssert(transaction);
    
    NSMutableArray * mArray = [NSMutableArray array];
    for (DSAccount * account in self.accounts) {
        if ([account canContainTransaction:transaction]) [mArray addObject:account];
    }
    return [mArray copy];
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
        [mSet addObjectsFromArray:[account.allTransactions copy]];
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
    NSParameterAssert(address);
    
    for (DSAccount * account in self.accounts) {
        if ([account containsAddress:address]) return TRUE;
    }
    return FALSE;
}

// true if the address is controlled by the wallet, this can also be for paths that are not accounts (todo)
- (BOOL)accountsBaseDerivationPathsContainAddress:(NSString *)address {
    NSParameterAssert(address);
    
    for (DSAccount * account in self.accounts) {
        if ([account baseDerivationPathsContainAddress:address]) return TRUE;
    }
    return FALSE;
}

- (DSAccount*)accountForAddress:(NSString *)address {
    NSParameterAssert(address);
    
    for (DSAccount * account in self.accounts) {
        if ([account containsAddress:address]) return account;
    }
    return nil;
}

// true if the address was previously used as an input or output in any wallet transaction
- (BOOL)addressIsUsed:(NSString *)address {
    NSParameterAssert(address);
    
    for (DSAccount * account in self.accounts) {
        if ([account addressIsUsed:address]) return TRUE;
    }
    return FALSE;
}

- (BOOL)transactionAddressAlreadySeenInOutputs:(NSString *)address {
    NSParameterAssert(address);
    
    for (DSAccount * account in self.accounts) {
        if ([account transactionAddressAlreadySeenInOutputs:address]) return TRUE;
    }
    return FALSE;
}

// returns the amount received by the wallet from the transaction (total outputs to change and/or receive addresses)
- (uint64_t)amountReceivedFromTransaction:(DSTransaction *)transaction {
    NSParameterAssert(transaction);
    
    uint64_t received = 0;
    for (DSAccount * account in self.accounts) {
        received += [account amountReceivedFromTransaction:transaction];
    }
    return received;
}

// retuns the amount sent from the wallet by the trasaction (total wallet outputs consumed, change and fee included)
- (uint64_t)amountSentByTransaction:(DSTransaction *)transaction {
    NSParameterAssert(transaction);
    
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
    NSParameterAssert(txHashes);
    
    NSMutableArray *updated = [NSMutableArray array];
    
    for (DSAccount * account in self.accounts) {
        NSArray * fromAccount = [account setBlockHeight:height andTimestamp:timestamp forTxHashes:txHashes];
        if (fromAccount) {
            [updated addObjectsFromArray:fromAccount];
        } else {
            [self chainUpdatedBlockHeight:height];
        }
    }
    return updated;
}

-(void)chainUpdatedBlockHeight:(int32_t)height {
    for (DSAccount * account in self.accounts) {
        [account chainUpdatedBlockHeight:height];
    }
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
    NSParameterAssert(transaction);
    
    for (DSAccount * account in self.accounts) {
        if (![account transactionIsValid:transaction]) return FALSE;
    }
    return TRUE;
}

-(DSKey*)privateKeyForAddress:(NSString*)address fromSeed:(NSData*)seed {
    NSParameterAssert(address);
    NSParameterAssert(seed);
    
    DSAccount * account = [self accountForAddress:address];
    if (!account) return nil;
    DSFundsDerivationPath * derivationPath = (DSFundsDerivationPath *)[account derivationPathContainingAddress:address];
    if (!derivationPath) return nil;
    NSIndexPath * indexPath = [derivationPath indexPathForKnownAddress:address];
    return [derivationPath privateKeyAtIndexPath:indexPath fromSeed:seed];
}

-(void)reloadDerivationPaths {
    for (DSAccount * account in self.accounts) {
        for (DSDerivationPath * derivationPath in account.fundDerivationPaths) {
            [derivationPath reloadAddresses];
        }
    }
    for (DSDerivationPath * derivationPath in self.specializedDerivationPaths) {
        [derivationPath reloadAddresses];
    }
}

-(NSArray*)specializedDerivationPaths {
    return [[DSDerivationPathFactory sharedInstance] loadedSpecializedDerivationPathsForWallet:self];
}

// MARK: - Wiping

- (void)wipeBlockchainInfo {
    for (DSAccount * account in self.accounts) {
        [account wipeBlockchainInfo];
    }
    [self.specialTransactionsHolder removeAllTransactions];
    [self wipeBlockchainIdentities];
}

// MARK: - Blockchain Identities

-(NSArray*)blockchainIdentityAddresses {
    DSAuthenticationKeysDerivationPath * derivationPath = [[DSDerivationPathFactory sharedInstance] blockchainIdentityBLSKeysDerivationPathForWallet:self];
    if (!derivationPath.hasExtendedPublicKey) return @[];
    return [derivationPath addressesToIndex:[self unusedBlockchainIdentityIndex] + 10];
}

//- (DSBlockchainIdentityRegistrationTransition *)registrationTransactionForPublicKeyHash:(UInt160)publicKeyHash {
//    DSBlockchainIdentityRegistrationTransition * transition = [_specialTransactionsHolder blockchainIdentityRegistrationTransactionForPublicKeyHash:publicKeyHash];
//    if (transition) return transition;
//    return nil;
//}
//
//- (DSBlockchainIdentityUpdateTransition *)resetTransactionForPublicKeyHash:(UInt160)publicKeyHash {
//    DSBlockchainIdentityUpdateTransition * transition = [_specialTransactionsHolder blockchainIdentityResetTransactionForPublicKeyHash:publicKeyHash];
//    if (transition) return transition;
//    return nil;
//}
//
//-(DSBlockchainIdentityRegistrationTransition *)blockchainIdentityRegistrationTransactionForIndex:(uint32_t)index {
//    DSAuthenticationKeysDerivationPath * derivationPath = [[DSDerivationPathFactory sharedInstance] blockchainIdentityBLSKeysDerivationPathForWallet:self];
//    UInt160 hash160 = [derivationPath publicKeyDataAtIndex:index].hash160;
//    return [self registrationTransactionForPublicKeyHash:hash160];
//}

-(void)unregisterBlockchainIdentity:(DSBlockchainIdentity *)blockchainIdentity {
    NSParameterAssert(blockchainIdentity);
    NSAssert(blockchainIdentity.wallet == self, @"the blockchainIdentity you are trying to remove is not in this wallet");
    
    [self.mBlockchainIdentities removeObjectForKey:blockchainIdentity.lockedOutpointData];
    NSError * error = nil;
    NSMutableDictionary * keyChainDictionary = [getKeychainDict(self.walletBlockchainIdentitiesKey, &error) mutableCopy];
    if (!keyChainDictionary) keyChainDictionary = [NSMutableDictionary dictionary];
    [keyChainDictionary removeObjectForKey:blockchainIdentity.lockedOutpointData];
    setKeychainDict(keyChainDictionary, self.walletBlockchainIdentitiesKey, NO);
}
-(void)addBlockchainIdentity:(DSBlockchainIdentity *)blockchainIdentity {

    NSParameterAssert(blockchainIdentity);
    [self.mBlockchainIdentities setObject:blockchainIdentity forKey:blockchainIdentity.lockedOutpointData];

}

- (void)registerBlockchainIdentity:(DSBlockchainIdentity *)blockchainIdentity
{
    NSParameterAssert(blockchainIdentity);
    
    if ([self.mBlockchainIdentities objectForKey:blockchainIdentity.lockedOutpointData] == nil) {
        [self addBlockchainIdentity:blockchainIdentity];
    }
    NSError * error = nil;
    NSMutableDictionary * keyChainDictionary = [getKeychainDict(self.walletBlockchainIdentitiesKey, &error) mutableCopy];
    if (!keyChainDictionary) keyChainDictionary = [NSMutableDictionary dictionary];
    
    NSAssert(!uint256_is_zero(blockchainIdentity.uniqueID), @"registrationTransactionHashData must not be null");
    [keyChainDictionary setObject:@(blockchainIdentity.index) forKey:blockchainIdentity.lockedOutpointData];
    setKeychainDict(keyChainDictionary, self.walletBlockchainIdentitiesKey, NO);
}

-(void)wipeBlockchainIdentities {
    for (DSBlockchainIdentity * blockchainIdentity in [_mBlockchainIdentities allValues]) {
        [self unregisterBlockchainIdentity:blockchainIdentity];
        [blockchainIdentity deletePersistentObject];
    }
}

-(DSBlockchainIdentity*)blockchainIdentityForUniqueId:(UInt256)uniqueId {
    DSBlockchainIdentity * foundBlockchainIdentity = nil;
    for (DSBlockchainIdentity * blockchainIdentity in [_mBlockchainIdentities allValues]) {
        if (uint256_eq([blockchainIdentity uniqueID],uniqueId)) {
            foundBlockchainIdentity = blockchainIdentity;
        }
    }
    return foundBlockchainIdentity;
}

-(uint32_t)blockchainIdentitiesCount {
    return (uint32_t)[self.mBlockchainIdentities count];
}


//This loads all the identities that the wallet knows about. If the app was deleted and reinstalled the identity information will remain from the keychain but must be reaquired from the network.
-(NSMutableDictionary*)blockchainIdentities {
    //setKeychainDict(@{}, self.walletBlockchainIdentitiesKey, NO);
    if (!_mBlockchainIdentities) {
        NSError * error = nil;
        NSMutableDictionary * keyChainDictionary = [getKeychainDict(self.walletBlockchainIdentitiesKey, &error) mutableCopy];
        NSMutableDictionary * rDictionary = [NSMutableDictionary dictionary];
        
        if (keyChainDictionary) {
            for (NSData * blockchainIdentityLockedOutpointData in keyChainDictionary) {
                uint32_t index = [keyChainDictionary[blockchainIdentityLockedOutpointData] unsignedIntValue];
                DSUTXO blockchainIdentityLockedOutpoint = blockchainIdentityLockedOutpointData.transactionOutpoint;
                //DSDLog(@"Blockchain identity unique Id is %@",uint256_hex(blockchainIdentityUniqueId));
//                UInt256 lastTransitionHash = [self.specialTransactionsHolder lastSubscriptionTransactionHashForRegistrationTransactionHash:registrationTransactionHash];
//                DSDLog(@"reg %@ last %@",uint256_hex(registrationTransactionHash),uint256_hex(lastTransitionHash));
//                DSBlockchainIdentityRegistrationTransition * blockchainIdentityRegistrationTransaction = [self blockchainIdentityRegistrationTransactionForIndex:index];
                
                //either the identity is known in core data (and we can pull it) or the wallet has been wiped and we need to get it from DAPI (the unique Id was saved in the keychain, so we don't need to resync)
                //TODO: get the identity from core data
                
                [self.chain.managedObjectContext performBlockAndWait:^{
                    NSUInteger blockchainIdentityEntitiesCount = [DSBlockchainIdentityEntity countObjectsMatching:@"chain == %@",self.chain.chainEntity];
                    if (blockchainIdentityEntitiesCount != keyChainDictionary.count) {
                        DSDLog(@"Unmatching blockchain entities count");
                    }
                    DSBlockchainIdentityEntity * blockchainIdentityEntity = [DSBlockchainIdentityEntity anyObjectMatching:@"uniqueID == %@",uint256_data([dsutxo_data(blockchainIdentityLockedOutpoint) SHA256_2])];
                    DSBlockchainIdentity * blockchainIdentity = nil;
                    if (blockchainIdentityEntity) {
                        if (blockchainIdentityEntity.registrationFundingTransaction) {
                            //Everything is good
                            DSCreditFundingTransaction * registrationTransaction = (DSCreditFundingTransaction *)[blockchainIdentityEntity.registrationFundingTransaction transactionForChain:self.chain];
                            NSMutableDictionary * usernameStatuses = [NSMutableDictionary dictionary];
                            for (DSBlockchainIdentityUsernameEntity * usernameEntity in blockchainIdentityEntity.usernames) {
                                NSData * salt = usernameEntity.salt;
                                if (salt) {
                                    [usernameStatuses setObject:@{BLOCKCHAIN_USERNAME_STATUS:@(usernameEntity.status),BLOCKCHAIN_USERNAME_SALT:usernameEntity.salt} forKey:usernameEntity.stringValue];
                                } else {
                                    DSDLog(@"No salt found for username");
                                    [usernameStatuses setObject:@{BLOCKCHAIN_USERNAME_STATUS:@(usernameEntity.status)} forKey:usernameEntity.stringValue];
                                }
                            }
                            blockchainIdentity = [[DSBlockchainIdentity alloc] initWithType:blockchainIdentityEntity.type atIndex:index withFundingTransaction:registrationTransaction withUsernameDictionary:usernameStatuses havingCredits:blockchainIdentityEntity.creditBalance registrationStatus:blockchainIdentityEntity.registrationStatus inWallet:self inContext:self.chain.managedObjectContext];
                        } else {
                            //Identity is known by core data, but registration transaction hasn't synced yet
                            //Lets first see if the output exists just to sanity check
                            NSData * transactionHashData = uint256_data(uint256_reverse(blockchainIdentityLockedOutpoint.hash));
                            DSTransactionEntity * creditRegitrationTransactionEntity = [DSTransactionEntity anyObjectMatching:@"transactionHash.txHash == %@",transactionHashData];
                            if (creditRegitrationTransactionEntity) {
                                //Weird but we should recover in this situation
                                DSCreditFundingTransaction * registrationTransaction = (DSCreditFundingTransaction *)[creditRegitrationTransactionEntity transactionForChain:self.chain];
                                NSMutableDictionary * usernameStatuses = [NSMutableDictionary dictionary];
                                for (DSBlockchainIdentityUsernameEntity * usernameEntity in blockchainIdentityEntity.usernames) {
                                    NSData * salt = usernameEntity.salt;
                                    if (salt) {
                                        [usernameStatuses setObject:@{BLOCKCHAIN_USERNAME_STATUS:@(usernameEntity.status),BLOCKCHAIN_USERNAME_SALT:usernameEntity.salt} forKey:usernameEntity.stringValue];
                                    } else {
                                        DSDLog(@"No salt found for username");
                                        [usernameStatuses setObject:@{BLOCKCHAIN_USERNAME_STATUS:@(usernameEntity.status)} forKey:usernameEntity.stringValue];
                                    }
                                }
                                blockchainIdentity = [[DSBlockchainIdentity alloc] initWithType:blockchainIdentityEntity.type atIndex:index withFundingTransaction:registrationTransaction withUsernameDictionary:usernameStatuses havingCredits:blockchainIdentityEntity.creditBalance registrationStatus:blockchainIdentityEntity.registrationStatus inWallet:self inContext:self.chain.managedObjectContext];
                            } else {
                                blockchainIdentity = [[DSBlockchainIdentity alloc] initWithType:blockchainIdentityEntity.type atIndex:index withLockedOutpoint:blockchainIdentityLockedOutpoint inWallet:self inContext:self.chain.managedObjectContext];
                            }
                        }
                        for (DSBlockchainIdentityKeyPathEntity * keyPath in blockchainIdentityEntity.keyPaths) {
                            NSIndexPath *keyIndexPath = (NSIndexPath *)[NSKeyedUnarchiver unarchiveObjectWithData:(NSData*)[keyPath path]];
                            [blockchainIdentity registerKeyIsActive:YES atIndexPath:keyIndexPath ofType:DSDerivationPathSigningAlgorith_ECDSA];
                        }
                    } else {
                        //No blockchain identity is known in core data
                        NSData * transactionHashData = uint256_data(uint256_reverse(blockchainIdentityLockedOutpoint.hash));
                        DSTransactionEntity * creditRegitrationTransactionEntity = [DSTransactionEntity anyObjectMatching:@"transactionHash.txHash == %@",transactionHashData];
                        if (creditRegitrationTransactionEntity) {
                            //The registration funding transaction exists
                            //Weird but we should recover in this situation
                            DSCreditFundingTransaction * registrationTransaction = (DSCreditFundingTransaction *)[creditRegitrationTransactionEntity transactionForChain:self.chain];
                            blockchainIdentity = [[DSBlockchainIdentity alloc] initWithType:DSBlockchainIdentityType_Unknown atIndex:[registrationTransaction usedDerivationPathIndexForWallet:self] withFundingTransaction:registrationTransaction withUsernameDictionary:nil inWallet:self inContext:self.chain.managedObjectContext];
                            [blockchainIdentity registerInWallet];
                        } else {
                            //We also don't have the registration funding transaction
                            blockchainIdentity = [[DSBlockchainIdentity alloc] initWithType:DSBlockchainIdentityType_Unknown atIndex:index withLockedOutpoint:blockchainIdentityLockedOutpoint inWallet:self inContext:self.chain.managedObjectContext];
                            [blockchainIdentity registerInWalletForBlockchainIdentityUniqueId:[dsutxo_data(blockchainIdentityLockedOutpoint) SHA256_2]];
                        }
                    }
                    [rDictionary setObject:blockchainIdentity forKey:blockchainIdentityLockedOutpointData];
                    
                }];
            }
        }
        _mBlockchainIdentities = rDictionary;
    }
    return _mBlockchainIdentities;
}

-(uint32_t)unusedBlockchainIdentityIndex {
    NSArray * blockchainIdentities = [_mBlockchainIdentities allValues];
    NSNumber * max = [blockchainIdentities valueForKeyPath:@"index.@max.intValue"];
    return max != nil ? ([max unsignedIntValue] + 1) : 0;
}

-(DSBlockchainIdentity*)createBlockchainIdentityOfType:(DSBlockchainIdentityType)type {
    DSBlockchainIdentity * blockchainIdentity = [[DSBlockchainIdentity alloc] initWithType:type atIndex:[self unusedBlockchainIdentityIndex] inWallet:self inContext:self.chain.managedObjectContext ];
    return blockchainIdentity;
}

-(DSBlockchainIdentity*)createBlockchainIdentityOfType:(DSBlockchainIdentityType)type usingDerivationIndex:(uint32_t)index {
    DSBlockchainIdentity * blockchainIdentity = [[DSBlockchainIdentity alloc] initWithType:type atIndex:[self unusedBlockchainIdentityIndex] inWallet:self inContext:self.chain.managedObjectContext ];
    return blockchainIdentity;
}

-(DSBlockchainIdentity*)createBlockchainIdentityOfType:(DSBlockchainIdentityType)type forUsername:(NSString*)username {
    DSBlockchainIdentity * blockchainIdentity = [self createBlockchainIdentityOfType:type];
    [blockchainIdentity addUsername:username save:NO];
    return blockchainIdentity;
}

-(DSBlockchainIdentity*)createBlockchainIdentityOfType:(DSBlockchainIdentityType)type forUsername:(NSString*)username usingDerivationIndex:(uint32_t)index {
    DSBlockchainIdentity * blockchainIdentity = [self createBlockchainIdentityOfType:type usingDerivationIndex:index];
    [blockchainIdentity addUsername:username save:NO];
    return blockchainIdentity;
}

// MARK: - Masternodes (Providers)

-(NSArray*)providerOwnerAddresses {
    DSAuthenticationKeysDerivationPath * derivationPath = [[DSDerivationPathFactory sharedInstance] providerOwnerKeysDerivationPathForWallet:self];
    if (!derivationPath.hasExtendedPublicKey) return @[];
    return [derivationPath addressesToIndex:[self unusedProviderOwnerIndex] + 10];
}

-(uint32_t)unusedProviderOwnerIndex {
    NSArray * indexes = [_mMasternodeOwnerIndexes allValues];
    NSNumber * max = [indexes valueForKeyPath:@"@max.intValue"];
    return max != nil ? ([max unsignedIntValue] + 1) : 0;
}

-(NSArray*)providerVotingAddresses {
    DSAuthenticationKeysDerivationPath * derivationPath = [[DSDerivationPathFactory sharedInstance] providerVotingKeysDerivationPathForWallet:self];
    if (!derivationPath.hasExtendedPublicKey) return @[];
    return [derivationPath addressesToIndex:[self unusedProviderVotingIndex] + 10];
}

-(uint32_t)unusedProviderVotingIndex {
    NSArray * indexes = [_mMasternodeVoterIndexes allValues];
    NSNumber * max = [indexes valueForKeyPath:@"@max.intValue"];
    return max != nil ? ([max unsignedIntValue] + 1) : 0;
}

-(NSArray*)providerOperatorAddresses {
    DSAuthenticationKeysDerivationPath * derivationPath = [[DSDerivationPathFactory sharedInstance] providerOperatorKeysDerivationPathForWallet:self];
    if (!derivationPath.hasExtendedPublicKey) return @[];
    return [derivationPath addressesToIndex:[self unusedProviderOperatorIndex] + 10];
}

-(uint32_t)unusedProviderOperatorIndex {
    NSArray * indexes = [_mMasternodeOperatorIndexes allValues];
    NSNumber * max = [indexes valueForKeyPath:@"@max.intValue"];
    return max != nil ? ([max unsignedIntValue] + 1) : 0;
}

- (void)registerMasternodeOperator:(DSLocalMasternode *)masternode
{
    NSParameterAssert(masternode);
    
    if ([self.mMasternodeOperatorIndexes objectForKey:uint256_data(masternode.providerRegistrationTransaction.txHash)] == nil) {
        [self.mMasternodeOperatorIndexes setObject:@(masternode.operatorWalletIndex) forKey:uint256_data(masternode.providerRegistrationTransaction.txHash)];
        NSError * error = nil;
        NSMutableDictionary * keyChainDictionary = [getKeychainDict(self.walletMasternodeOperatorsKey, &error) mutableCopy];
        if (!keyChainDictionary) keyChainDictionary = [NSMutableDictionary dictionary];
        [keyChainDictionary setObject:@(masternode.operatorWalletIndex) forKey:uint256_data(masternode.providerRegistrationTransaction.txHash)];
        setKeychainDict(keyChainDictionary, self.walletMasternodeOperatorsKey, NO);
    }
}

- (void)registerMasternodeOperator:(DSLocalMasternode *)masternode withOperatorPublicKey:(DSBLSKey*)operatorKey
{
    NSParameterAssert(masternode);
    
    if ([self.mMasternodeOperatorPublicKeyLocations objectForKey:uint256_data(masternode.providerRegistrationTransaction.txHash)] == nil) {
        NSData * hashedOperatorKey = [NSData dataWithUInt256:[operatorKey publicKeyData].SHA256];
        NSString * operatorKeyStorageLocation = [NSString stringWithFormat:@"DS_OPERATOR_KEY_LOC_%@",hashedOperatorKey.hexString];
        [self.mMasternodeOperatorPublicKeyLocations setObject:operatorKeyStorageLocation forKey:uint256_data(masternode.providerRegistrationTransaction.txHash)];
        NSError * error = nil;
        NSMutableDictionary * keyChainDictionary = [getKeychainDict(self.walletMasternodeOperatorsKey, &error) mutableCopy];
        if (!keyChainDictionary) keyChainDictionary = [NSMutableDictionary dictionary];
        [keyChainDictionary setObject:hashedOperatorKey forKey:uint256_data(masternode.providerRegistrationTransaction.txHash)];
        setKeychainDict(keyChainDictionary, self.walletMasternodeOperatorsKey, NO);
        setKeychainData([operatorKey publicKeyData], operatorKeyStorageLocation, NO);
    }
}

- (void)registerMasternodeOwner:(DSLocalMasternode *)masternode
{
    NSParameterAssert(masternode);
    
    if ([self.mMasternodeOwnerIndexes objectForKey:uint256_data(masternode.providerRegistrationTransaction.txHash)] == nil) {
        if (masternode.ownerWalletIndex != UINT32_MAX) {
            [self.mMasternodeOwnerIndexes setObject:@(masternode.ownerWalletIndex) forKey:uint256_data(masternode.providerRegistrationTransaction.txHash)];
            NSError * error = nil;
            NSMutableDictionary * keyChainDictionary = [getKeychainDict(self.walletMasternodeOwnersKey, &error) mutableCopy];
            if (!keyChainDictionary) keyChainDictionary = [NSMutableDictionary dictionary];
            [keyChainDictionary setObject:@(masternode.ownerWalletIndex) forKey:uint256_data(masternode.providerRegistrationTransaction.txHash)];
            setKeychainDict(keyChainDictionary, self.walletMasternodeOwnersKey, NO);
        }
    }
}

- (void)registerMasternodeOwner:(DSLocalMasternode *)masternode withOwnerPrivateKey:(DSECDSAKey*)ownerKey
{
    NSParameterAssert(masternode);
    
    if ([self.mMasternodeOwnerPrivateKeyLocations objectForKey:uint256_data(masternode.providerRegistrationTransaction.txHash)] == nil) {
        NSData * hashedOwnerKey = [NSData dataWithUInt256:[ownerKey publicKeyData].SHA256];
        NSString * ownerKeyStorageLocation = [NSString stringWithFormat:@"DS_OWNER_KEY_LOC_%@",hashedOwnerKey.hexString];
        [self.mMasternodeOwnerPrivateKeyLocations setObject:ownerKeyStorageLocation forKey:uint256_data(masternode.providerRegistrationTransaction.txHash)];
        NSError * error = nil;
        NSMutableDictionary * keyChainDictionary = [getKeychainDict(self.walletMasternodeOwnersKey, &error) mutableCopy];
        if (!keyChainDictionary) keyChainDictionary = [NSMutableDictionary dictionary];
        [keyChainDictionary setObject:hashedOwnerKey forKey:uint256_data(masternode.providerRegistrationTransaction.txHash)];
        setKeychainDict(keyChainDictionary, self.walletMasternodeOwnersKey, NO);
        setKeychainData([ownerKey secretKeyData], ownerKeyStorageLocation, NO);
    }
}
- (void)registerMasternodeVoter:(DSLocalMasternode *)masternode
{
    NSParameterAssert(masternode);
    
    if ([self.mMasternodeVoterIndexes objectForKey:uint256_data(masternode.providerRegistrationTransaction.txHash)] == nil) {
        [self.mMasternodeVoterIndexes setObject:@(masternode.votingWalletIndex) forKey:uint256_data(masternode.providerRegistrationTransaction.txHash)];
        NSError * error = nil;
        NSMutableDictionary * keyChainDictionary = [getKeychainDict(self.walletMasternodeVotersKey, &error) mutableCopy];
        if (!keyChainDictionary) keyChainDictionary = [NSMutableDictionary dictionary];
        [keyChainDictionary setObject:@(masternode.votingWalletIndex) forKey:uint256_data(masternode.providerRegistrationTransaction.txHash)];
        setKeychainDict(keyChainDictionary, self.walletMasternodeVotersKey, NO);
    }
}

- (void)registerMasternodeVoter:(DSLocalMasternode *)masternode withVotingKey:(DSECDSAKey*)votingKey {
    if ([self.mMasternodeVoterKeyLocations objectForKey:uint256_data(masternode.providerRegistrationTransaction.txHash)] == nil) {
        NSData * hashedVoterKey = [NSData dataWithUInt256:[votingKey publicKeyData].SHA256];
        NSString * ownerKeyStorageLocation = [NSString stringWithFormat:@"DS_VOTING_KEY_LOC_%@",hashedVoterKey.hexString];
        [self.mMasternodeVoterKeyLocations setObject:ownerKeyStorageLocation forKey:uint256_data(masternode.providerRegistrationTransaction.txHash)];
        NSError * error = nil;
        NSMutableDictionary * keyChainDictionary = [getKeychainDict(self.walletMasternodeVotersKey, &error) mutableCopy];
        if (!keyChainDictionary) keyChainDictionary = [NSMutableDictionary dictionary];
        [keyChainDictionary setObject:hashedVoterKey forKey:uint256_data(masternode.providerRegistrationTransaction.txHash)];
        setKeychainDict(keyChainDictionary, self.walletMasternodeVotersKey, NO);
        if ([votingKey hasPrivateKey]) {
            setKeychainData([votingKey secretKeyData], ownerKeyStorageLocation, NO);
        } else {
            setKeychainData([votingKey publicKeyData], ownerKeyStorageLocation, NO);
        }
    }
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

- (BOOL)containsBlockchainIdentityBLSAuthenticationHash:(UInt160)blockchainIdentityAuthenticationHash {
    DSAuthenticationKeysDerivationPath * derivationPath = [DSAuthenticationKeysDerivationPath blockchainIdentitiesBLSKeysDerivationPathForWallet:self];
    return [derivationPath containsAddress:[[NSData dataWithUInt160:blockchainIdentityAuthenticationHash] addressFromHash160DataForChain:self.chain]];
}

- (BOOL)containsHoldingAddress:(NSString*)holdingAddress {
    NSParameterAssert(holdingAddress);
    
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
    NSParameterAssert(holdingAddress);
    
    DSMasternodeHoldingsDerivationPath * derivationPath = [DSMasternodeHoldingsDerivationPath providerFundsDerivationPathForWallet:self];
    return [derivationPath indexOfKnownAddress:holdingAddress];
}

- (NSUInteger)indexOfBlockchainIdentityAuthenticationHash:(UInt160)blockchainIdentityAuthenticationHash {
    DSAuthenticationKeysDerivationPath * derivationPath = [DSAuthenticationKeysDerivationPath blockchainIdentitiesBLSKeysDerivationPathForWallet:self];
    return [derivationPath indexOfKnownAddress:[[NSData dataWithUInt160:blockchainIdentityAuthenticationHash] addressFromHash160DataForChain:self.chain]];
}

- (NSUInteger)indexOfBlockchainIdentityCreditFundingRegistrationHash:(UInt160)creditFundingRegistrationHash {
    DSCreditFundingDerivationPath * derivationPath = [DSCreditFundingDerivationPath blockchainIdentityRegistrationFundingDerivationPathForWallet:self];
    return [derivationPath indexOfKnownAddress:[[NSData dataWithUInt160:creditFundingRegistrationHash] addressFromHash160DataForChain:self.chain]];
}

@end
