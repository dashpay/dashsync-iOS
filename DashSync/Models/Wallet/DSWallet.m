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

#import "DSWallet+Protected.h"
#import "DSChain+Protected.h"
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
#import "DSDashpayUserEntity+CoreDataClass.h"
#import "DSAccountEntity+CoreDataClass.h"
#import "DSIncomingFundsDerivationPath.h"
#import "DSFriendRequestEntity+CoreDataClass.h"
#import "DSDerivationPathEntity+CoreDataClass.h"
#import "DSCreditFundingDerivationPath+Protected.h"
#import "DSCreditFundingTransaction.h"
#import "DSCreditFundingTransactionEntity+CoreDataClass.h"
#import "DSBlockchainIdentityUsernameEntity+CoreDataClass.h"
#import "DSBlockchainIdentityKeyPathEntity+CoreDataClass.h"
#import "DSAuthenticationManager+Private.h"

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
@property (nonatomic, copy) NSString * uniqueIDString;
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

@property (nonatomic, assign, getter=isTransient) BOOL transient;
@property (nonatomic, strong) NSMutableDictionary <NSData *,DSBlockchainIdentity*> * mBlockchainIdentities;

@end

@implementation DSWallet

+ (DSWallet*)standardWalletWithSeedPhrase:(NSString*)seedPhrase setCreationDate:(NSTimeInterval)creationDate forChain:(DSChain*)chain storeSeedPhrase:(BOOL)store isTransient:(BOOL)isTransient {
    NSParameterAssert(seedPhrase);
    NSParameterAssert(chain);
    
    DSAccount * account = [DSAccount accountWithAccountNumber:0 withDerivationPaths:[chain standardDerivationPathsForAccountNumber:0] inContext:chain.chainManagedObjectContext];
    
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
    
    return [self standardWalletWithSeedPhrase:[self generateRandomSeedPhraseForLanguage:language] setCreationDate:[NSDate timeIntervalSince1970] forChain:chain storeSeedPhrase:store isTransient:isTransient];
}

//this is for testing purposes only
+ (DSWallet*)transientWalletWithDerivedKeyData:(NSData*)derivedData forChain:(DSChain*)chain {
    NSParameterAssert(derivedData);
    NSParameterAssert(chain);
    
    DSAccount * account = [DSAccount accountWithAccountNumber:0 withDerivationPaths:[chain standardDerivationPathsForAccountNumber:0] inContext:chain.chainManagedObjectContext];
    
    
    NSString * uniqueId = [self setTransientDerivedKeyData:derivedData withAccounts:@[account] forChain:chain]; //make sure we can create the wallet first
    if (!uniqueId) return nil;
    //[self registerSpecializedDerivationPathsForSeedPhrase:seedPhrase underUniqueId:uniqueId onChain:chain];
    DSWallet * wallet = [[DSWallet alloc] initWithUniqueID:uniqueId andAccount:account forChain:chain storeSeedPhrase:NO isTransient:YES];
    
    wallet.transientDerivedKeyData = derivedData;
    
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
    self.uniqueIDString = uniqueID;
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
    
    self.specialTransactionsHolder = [[DSSpecialTransactionsWalletHolder alloc] initWithWallet:self inContext:self.chain.chainManagedObjectContext];
    
    self.mBlockchainIdentities = nil;
    [self blockchainIdentities];
    
    //blockchain users are loaded
    
    //add blockchain user derivation paths to account
    
    return self;
}

-(void)loadBlockchainIdentities {
    [self.chain.chainManagedObjectContext performBlockAndWait:^{
        
        NSMutableArray * usedFriendshipIdentifiers = [NSMutableArray array];
        for (NSData * blockchainIdentityData in self.mBlockchainIdentities) {
            DSBlockchainIdentity * blockchainIdentity = [self.mBlockchainIdentities objectForKey:blockchainIdentityData];
            for (DSFriendRequestEntity * friendRequest in blockchainIdentity.matchingDashpayUserInViewContext.outgoingRequests) {
                DSAccount * account = [self accountWithNumber:friendRequest.account.index];
                DSIncomingFundsDerivationPath * fundsDerivationPath = [DSIncomingFundsDerivationPath
                                                               contactBasedDerivationPathWithDestinationBlockchainIdentityUniqueId:friendRequest.destinationContact.associatedBlockchainIdentity.uniqueID.UInt256 sourceBlockchainIdentityUniqueId:blockchainIdentity.uniqueID forAccountNumber:account.accountNumber onChain:self.chain];
                fundsDerivationPath.wallet = self;
                fundsDerivationPath.account = account;
                //DSLogPrivate(@"%@",blockchainIdentity.matchingDashpayUser.outgoingRequests);
                [account addIncomingDerivationPath:fundsDerivationPath forFriendshipIdentifier:friendRequest.friendshipIdentifier inContext:self.chain.chainManagedObjectContext];
                [usedFriendshipIdentifiers addObject:friendRequest.friendshipIdentifier];
            }
        }
        
        for (NSData * blockchainUniqueIdData in self.mBlockchainIdentities) {
            DSBlockchainIdentity * blockchainIdentity = [self.mBlockchainIdentities objectForKey:blockchainUniqueIdData];
            for (DSFriendRequestEntity * friendRequest in blockchainIdentity.matchingDashpayUserInViewContext.incomingRequests) {
                
                DSAccount * account = [self accountWithNumber:friendRequest.account.index];
                DSIncomingFundsDerivationPath * fundsDerivationPath = [account derivationPathForFriendshipWithIdentifier:friendRequest.friendshipIdentifier];
                if (fundsDerivationPath) {
                    //both contacts are on device
                    [account addOutgoingDerivationPath:fundsDerivationPath forFriendshipIdentifier:friendRequest.friendshipIdentifier inContext:self.chain.chainManagedObjectContext];
                } else {
                    DSDerivationPathEntity * derivationPathEntity = friendRequest.derivationPath;
                    
                    DSIncomingFundsDerivationPath * incomingFundsDerivationPath = [DSIncomingFundsDerivationPath
                                                                       externalDerivationPathWithExtendedPublicKeyUniqueID:derivationPathEntity.publicKeyIdentifier withDestinationBlockchainIdentityUniqueId:friendRequest.destinationContact.associatedBlockchainIdentity.uniqueID.UInt256 sourceBlockchainIdentityUniqueId:friendRequest.sourceContact.associatedBlockchainIdentity.uniqueID.UInt256 onChain:self.chain];
                    incomingFundsDerivationPath.wallet = self;
                    incomingFundsDerivationPath.account = account;
                    [account addOutgoingDerivationPath:incomingFundsDerivationPath forFriendshipIdentifier:friendRequest.friendshipIdentifier inContext:self.chain.chainManagedObjectContext];
                }
            }
        }
        
        //this adds the extra information to the transaction and must come after loading all blockchain identities.
        for (DSAccount * account in self.accounts) {
            for (DSTransaction * transaction in account.allTransactions) {
                [transaction loadBlockchainIdentitiesFromDerivationPaths:account.fundDerivationPaths];
                [transaction loadBlockchainIdentitiesFromDerivationPaths:account.outgoingFundDerivationPaths];
            }
        }
    }];
}


+(void)registerSpecializedDerivationPathsForSeedPhrase:(NSString*)seedPhrase underUniqueId:(NSString*)walletUniqueId onChain:(DSChain*)chain {
    @autoreleasepool {
        seedPhrase = [[DSBIP39Mnemonic sharedInstance] normalizePhrase:seedPhrase];
        
        NSData * derivedKeyData = (seedPhrase) ?[[DSBIP39Mnemonic sharedInstance]
                                                 deriveKeyFromPhrase:seedPhrase withPassphrase:nil]:nil;
        
        if (derivedKeyData) {
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
}

-(instancetype)initWithUniqueID:(NSString*)uniqueID forChain:(DSChain*)chain {
    if (! (self = [self initWithUniqueID:uniqueID andAccount:[DSAccount accountWithAccountNumber:0 withDerivationPaths:[chain standardDerivationPathsForAccountNumber:0] inContext:chain.chainManagedObjectContext] forChain:chain storeSeedPhrase:NO isTransient:NO])) return nil;
    return self;
}

-(NSString*)walletBlockchainIdentitiesKey {
    return [NSString stringWithFormat:@"%@_%@",WALLET_BLOCKCHAIN_USERS_KEY,[self uniqueIDString]];
}

-(NSString*)walletBlockchainIdentitiesDefaultIndexKey {
    return [NSString stringWithFormat:@"%@_%@_DEFAULT_INDEX",WALLET_BLOCKCHAIN_USERS_KEY,[self uniqueIDString]];
}

-(NSString*)walletMasternodeVotersKey {
    return [NSString stringWithFormat:@"%@_%@",WALLET_MASTERNODE_VOTERS_KEY,[self uniqueIDString]];
}

-(NSString*)walletMasternodeOwnersKey {
    return [NSString stringWithFormat:@"%@_%@",WALLET_MASTERNODE_OWNERS_KEY,[self uniqueIDString]];
}

-(NSString*)walletMasternodeOperatorsKey {
    return [NSString stringWithFormat:@"%@_%@",WALLET_MASTERNODE_OPERATORS_KEY,[self uniqueIDString]];
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
    return [DSWallet mnemonicUniqueIDForUniqueID:self.uniqueIDString];
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
    return [DSWallet creationTimeUniqueIDForUniqueID:self.uniqueIDString];
}

-(NSString*)creationGuessTimeUniqueID {
    return [DSWallet creationGuessTimeUniqueIDForUniqueID:self.uniqueIDString];
}

-(NSString*)didVerifyCreationTimeUniqueID {
    return [DSWallet didVerifyCreationTimeUniqueIDForUniqueID:self.uniqueIDString];
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
#if DEBUG
                DSLogPrivate(@"real wallet creation set to %@",realWalletCreationDate);
#else
                DSLog(@"real wallet creation set to %@",@"<REDACTED>");
#endif
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

// MARK: - Chain Synchronization Fingerprint

-(NSData*)chainSynchronizationFingerprint {
    NSArray * blockHeightsArray = [[[self allTransactions] mutableArrayValueForKey:@"blockHeight"] sortedArrayUsingSelector: @selector(compare:)];
    NSMutableOrderedSet * blockHeightZones = [NSMutableOrderedSet orderedSet];
    [blockHeightsArray enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [blockHeightZones addObject:@([obj unsignedLongValue] / 500)];
    }];

    return [[self class] chainSynchronizationFingerprintForBlockZones:blockHeightZones forChainHeight:self.chain.lastSyncBlockHeight];
}

+(NSOrderedSet*)blockZonesFromChainSynchronizationFingerprint:(NSData*)chainSynchronizationFingerprint rVersion:(uint8_t *)rVersion rChainHeight:(uint32_t*)rChainHeight {
    if (rVersion) {
        *rVersion = [chainSynchronizationFingerprint UInt8AtOffset:0];
    }
    if (rChainHeight) {
        *rChainHeight = ((uint32_t)[chainSynchronizationFingerprint UInt16BigAtOffset:1])*500;
    }
    uint16_t firstBlockZone = [chainSynchronizationFingerprint UInt16BigAtOffset:3];
    NSMutableOrderedSet * blockZones = [NSMutableOrderedSet orderedSet];
    [blockZones addObject:@(firstBlockZone)];
    uint16_t lastKnownBlockZone = firstBlockZone;
    uint16_t offset = 0;
    for (uint32_t i = 5;i< chainSynchronizationFingerprint.length;i+=2) {
        uint16_t currentData = [chainSynchronizationFingerprint UInt16BigAtOffset:i];
        if (currentData & (1 << 15)) {
            //We are in a continuation
            if (offset) {
                offset = - 15 + offset;
            }
            for (uint8_t i = 1;i<16;i++) {
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

+(NSData*)chainSynchronizationFingerprintForBlockZones:(NSOrderedSet *)blockHeightZones forChainHeight:(uint32_t)chainHeight {
    if (!blockHeightZones.count) {
        return [NSData data];
    }
    
    NSMutableData * fingerprintData = [NSMutableData data];
    [fingerprintData appendUInt8:1]; //version 1
    [fingerprintData appendUInt16BigEndian:chainHeight/500]; //last sync block height
    uint16_t previousBlockHeightZone = [blockHeightZones.firstObject unsignedShortValue];
    [fingerprintData appendUInt16BigEndian:previousBlockHeightZone]; //first one
    uint8_t currentOffset = 0;
    uint16_t currentContinuationData = 0;
    for (NSNumber * blockZoneNumber in blockHeightZones) {
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
+ (NSString *)generateRandomSeedPhraseForLanguage:(DSBIP39Language)language
{
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

- (void)seedPhraseAfterAuthentication:(void (^)(NSString * _Nullable))completion
{
    [self seedPhraseAfterAuthenticationWithPrompt:nil completion:completion];
}

-(BOOL)hasSeedPhrase {
    NSError * error = nil;
    BOOL hasSeed = hasKeychainData(self.uniqueIDString, &error);
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
        
        BOOL usingBiometricAuthentication = amount?[[DSAuthenticationManager sharedInstance] canUseBiometricAuthenticationForAmount:amount]:NO;
        
        [[DSAuthenticationManager sharedInstance] authenticateWithPrompt:authprompt usingBiometricAuthentication:usingBiometricAuthentication alertIfLockout:YES completion:^(BOOL authenticated, BOOL usedBiometrics, BOOL cancelled) {
            if (!authenticated) {
                completion(nil,cancelled);
            } else {
                if (usedBiometrics) {
                    BOOL loweredAmountSuccessfully = [[DSAuthenticationManager sharedInstance] updateBiometricsAmountLeftAfterSpendingAmount:amount];
                    if (!loweredAmountSuccessfully) {
                        completion(nil,cancelled);
                        return;
                    }
                }
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
        [[DSAuthenticationManager sharedInstance] authenticateWithPrompt:authprompt usingBiometricAuthentication:NO alertIfLockout:YES completion:^(BOOL authenticated, BOOL usedBiometrics, BOOL cancelled) {
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
                    privKey = [DSECDSAKey serializedAuthPrivateKeyFromSeed:seed forChain:self.chain];
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

-(NSArray *)registerAddressesWithGapLimit:(NSUInteger)gapLimit dashpayGapLimit:(NSUInteger)dashpayGapLimit internal:(BOOL)internal error:(NSError**)error {
    NSMutableArray * mArray = [NSMutableArray array];
    for (DSAccount * account in self.accounts) {
        [mArray addObjectsFromArray:[account registerAddressesWithGapLimit:gapLimit dashpayGapLimit:dashpayGapLimit internal:internal error:error]];
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

- (DSAccount*)accountForDashpayExternalDerivationPathAddress:(NSString *)address {
    NSParameterAssert(address);
    
    for (DSAccount * account in self.accounts) {
        if ([account externalDerivationPathContainingAddress:address]) return account;
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
- (NSArray *)setBlockHeight:(int32_t)height andTimestamp:(NSTimeInterval)timestamp forTransactionHashes:(NSArray *)txHashes
{
    NSParameterAssert(txHashes);
    if (![txHashes count]) return [NSArray array];
    
    NSMutableArray *updated = [NSMutableArray array];
    
    for (DSAccount * account in self.accounts) {
        NSArray * fromAccount = [account setBlockHeight:height andTimestamp:timestamp forTransactionHashes:txHashes];
        if (fromAccount) {
            [updated addObjectsFromArray:fromAccount];
        } else {
            [self chainUpdatedBlockHeight:height];
        }
    }
    [self.specialTransactionsHolder setBlockHeight:height andTimestamp:timestamp forTransactionHashes:txHashes];
    return [updated copy];
}

// this is used to save transactions atomically with the block, needs to be called before switching threads to save the block
- (void)prepareForIncomingTransactionPersistenceForBlockSaveWithNumber:(uint32_t)blockNumber {
    for (DSAccount * account in self.accounts) {
        [account prepareForIncomingTransactionPersistenceForBlockSaveWithNumber:blockNumber];
    }
    [self.specialTransactionsHolder prepareForIncomingTransactionPersistenceForBlockSaveWithNumber:blockNumber];
}

// this is used to save transactions atomically with the block
- (void)persistIncomingTransactionsAttributesForBlockSaveWithNumber:(uint32_t)blockNumber inContext:(NSManagedObjectContext*)context {
    for (DSAccount * account in self.accounts) {
        [account persistIncomingTransactionsAttributesForBlockSaveWithNumber:blockNumber inContext:context];
    }
    [self.specialTransactionsHolder persistIncomingTransactionsAttributesForBlockSaveWithNumber:blockNumber inContext:context];
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

-(BOOL)hasAnExtendedPublicKeyMissing {
    for (DSAccount * account in self.accounts) {
        if ([account hasAnExtendedPublicKeyMissing]) return YES;
    }
    //todo add non funds derivation paths
    return NO;
}

// MARK: - Wiping

- (void)wipeBlockchainInfoInContext:(NSManagedObjectContext*)context {
    for (DSAccount * account in self.accounts) {
        [account wipeBlockchainInfo];
    }
    [self.specialTransactionsHolder removeAllTransactions];
    [self wipeBlockchainIdentitiesInContext:context];
}

// MARK: - Blockchain Identities

-(NSArray*)blockchainIdentityAddresses {
    DSAuthenticationKeysDerivationPath * derivationPath = [[DSDerivationPathFactory sharedInstance] blockchainIdentityBLSKeysDerivationPathForWallet:self];
    if (!derivationPath.hasExtendedPublicKey) return @[];
    return [derivationPath addressesToIndex:[self unusedBlockchainIdentityIndex] + 10 useCache:YES addToCache:YES];
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
    NSMutableDictionary * keyChainDictionary = [getKeychainDict(self.walletBlockchainIdentitiesKey,@[[NSNumber class],[NSData class]], &error) mutableCopy];
    if (!keyChainDictionary) keyChainDictionary = [NSMutableDictionary dictionary];
    [keyChainDictionary removeObjectForKey:blockchainIdentity.lockedOutpointData];
    setKeychainDict(keyChainDictionary, self.walletBlockchainIdentitiesKey, NO);
}
-(void)addBlockchainIdentity:(DSBlockchainIdentity *)blockchainIdentity {

    NSParameterAssert(blockchainIdentity);
    [self.mBlockchainIdentities setObject:blockchainIdentity forKey:blockchainIdentity.lockedOutpointData];

}

-(BOOL)containsBlockchainIdentity:(DSBlockchainIdentity*)blockchainIdentity {
    if (blockchainIdentity.lockedOutpointData) {
        return [self.mBlockchainIdentities objectForKey:blockchainIdentity.lockedOutpointData];
    } else {
        return FALSE;
    }
}

- (void)registerBlockchainIdentity:(DSBlockchainIdentity *)blockchainIdentity
{
    NSParameterAssert(blockchainIdentity);
    
    if ([self.mBlockchainIdentities objectForKey:blockchainIdentity.lockedOutpointData] == nil) {
        [self addBlockchainIdentity:blockchainIdentity];
    }
    NSError * error = nil;
    NSMutableDictionary * keyChainDictionary = [getKeychainDict(self.walletBlockchainIdentitiesKey,@[[NSNumber class],[NSData class]], &error) mutableCopy];
    if (!keyChainDictionary) keyChainDictionary = [NSMutableDictionary dictionary];
    
    NSAssert(!uint256_is_zero(blockchainIdentity.uniqueID), @"registrationTransactionHashData must not be null");
    [keyChainDictionary setObject:@(blockchainIdentity.index) forKey:blockchainIdentity.lockedOutpointData];
    setKeychainDict(keyChainDictionary, self.walletBlockchainIdentitiesKey, NO);
    
    if (!_defaultBlockchainIdentity && (blockchainIdentity.index == 0)) {
        _defaultBlockchainIdentity = blockchainIdentity;
    }
}

-(void)wipeBlockchainIdentitiesInContext:(NSManagedObjectContext*)context {
    for (DSBlockchainIdentity * blockchainIdentity in [_mBlockchainIdentities allValues]) {
        [self unregisterBlockchainIdentity:blockchainIdentity];
        [blockchainIdentity deletePersistentObjectAndSave:NO inContext:context];
    }
    _defaultBlockchainIdentity = nil;
}

-(DSBlockchainIdentity* _Nullable)blockchainIdentityThatCreatedContract:(DPContract*)contract withContractId:(UInt256)contractId {
    NSParameterAssert(contract);
    NSAssert(!uint256_is_zero(contractId), @"contractId must not be null");
    DSBlockchainIdentity * foundBlockchainIdentity = nil;
    for (DSBlockchainIdentity * blockchainIdentity in [_mBlockchainIdentities allValues]) {
        if (uint256_eq([contract contractIdIfRegisteredByBlockchainIdentity:blockchainIdentity],contractId)) {
            foundBlockchainIdentity = blockchainIdentity;
        }
    }
    return foundBlockchainIdentity;
}

-(DSBlockchainIdentity*)blockchainIdentityForUniqueId:(UInt256)uniqueId {
    NSAssert(!uint256_is_zero(uniqueId), @"uniqueId must not be null");
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
        NSMutableDictionary * keyChainDictionary = [getKeychainDict(self.walletBlockchainIdentitiesKey,@[[NSNumber class],[NSData class]], &error) mutableCopy];
        if (error) {
            return nil;
        }
        uint64_t defaultIndex = getKeychainInt(self.walletBlockchainIdentitiesDefaultIndexKey, &error);
        if (error) {
            return nil;
        }
        NSMutableDictionary * rDictionary = [NSMutableDictionary dictionary];
        
        if (keyChainDictionary) {
            for (NSData * blockchainIdentityLockedOutpointData in keyChainDictionary) {
                uint32_t index = [keyChainDictionary[blockchainIdentityLockedOutpointData] unsignedIntValue];
                DSUTXO blockchainIdentityLockedOutpoint = blockchainIdentityLockedOutpointData.transactionOutpoint;
                //DSLogPrivate(@"Blockchain identity unique Id is %@",uint256_hex(blockchainIdentityUniqueId));
//                UInt256 lastTransitionHash = [self.specialTransactionsHolder lastSubscriptionTransactionHashForRegistrationTransactionHash:registrationTransactionHash];
//                DSLogPrivate(@"reg %@ last %@",uint256_hex(registrationTransactionHash),uint256_hex(lastTransitionHash));
//                DSBlockchainIdentityRegistrationTransition * blockchainIdentityRegistrationTransaction = [self blockchainIdentityRegistrationTransactionForIndex:index];
                
                //either the identity is known in core data (and we can pull it) or the wallet has been wiped and we need to get it from DAPI (the unique Id was saved in the keychain, so we don't need to resync)
                //TODO: get the identity from core data
                
                NSManagedObjectContext * context = [NSManagedObjectContext chainContext]; //shouldn't matter what context is used
                
                [context performBlockAndWait:^{
                    NSUInteger blockchainIdentityEntitiesCount = [DSBlockchainIdentityEntity countObjectsInContext:context matching:@"chain == %@ && isLocal == TRUE",[self.chain chainEntityInContext:context]];
                    if (blockchainIdentityEntitiesCount != keyChainDictionary.count) {
                        DSLog(@"Unmatching blockchain entities count");
                    }
                    DSBlockchainIdentityEntity * blockchainIdentityEntity = [DSBlockchainIdentityEntity anyObjectInContext:context matching:@"uniqueID == %@",uint256_data([dsutxo_data(blockchainIdentityLockedOutpoint) SHA256_2])];
                    DSBlockchainIdentity * blockchainIdentity = nil;
                    if (blockchainIdentityEntity) {
                        blockchainIdentity = [[DSBlockchainIdentity alloc] initAtIndex:index withLockedOutpoint:blockchainIdentityLockedOutpoint inWallet:self withBlockchainIdentityEntity:blockchainIdentityEntity];
                    } else {
                        //No blockchain identity is known in core data
                        NSData * transactionHashData = uint256_data(uint256_reverse(blockchainIdentityLockedOutpoint.hash));
                        DSTransactionEntity * creditRegitrationTransactionEntity = [DSTransactionEntity anyObjectInContext:context matching:@"transactionHash.txHash == %@",transactionHashData];
                        if (creditRegitrationTransactionEntity) {
                            //The registration funding transaction exists
                            //Weird but we should recover in this situation
                            DSCreditFundingTransaction * registrationTransaction = (DSCreditFundingTransaction *)[creditRegitrationTransactionEntity transactionForChain:self.chain];
                            
                            BOOL correctIndex = [registrationTransaction checkDerivationPathIndexForWallet:self isIndex:index];
                            if (!correctIndex) {
                                NSAssert(FALSE,@"We should implement this");
                            } else {
                                blockchainIdentity = [[DSBlockchainIdentity alloc] initAtIndex:index withFundingTransaction:registrationTransaction withUsernameDictionary:nil inWallet:self];
                                [blockchainIdentity registerInWallet];
                            }
                        } else {
                            //We also don't have the registration funding transaction
                            blockchainIdentity = [[DSBlockchainIdentity alloc] initAtIndex:index withLockedOutpoint:blockchainIdentityLockedOutpoint inWallet:self];
                            [blockchainIdentity registerInWalletForBlockchainIdentityUniqueId:[dsutxo_data(blockchainIdentityLockedOutpoint) SHA256_2]];
                        }
                    }
                    if (blockchainIdentity) {
                        [rDictionary setObject:blockchainIdentity forKey:blockchainIdentityLockedOutpointData];
                        if (index == defaultIndex) {
                            _defaultBlockchainIdentity = blockchainIdentity;
                        }
                    }
                    
                }];
            }
        }
        _mBlockchainIdentities = rDictionary;
    }
    return _mBlockchainIdentities;
}

-(void)setDefaultBlockchainIdentity:(DSBlockchainIdentity *)defaultBlockchainIdentity {
    if (![[self.blockchainIdentities allValues] containsObject:defaultBlockchainIdentity]) return;
    _defaultBlockchainIdentity = defaultBlockchainIdentity;
    setKeychainInt(defaultBlockchainIdentity.index, self.walletBlockchainIdentitiesDefaultIndexKey, NO);
}

-(uint32_t)unusedBlockchainIdentityIndex {
    NSArray * blockchainIdentities = [_mBlockchainIdentities allValues];
    NSNumber * max = [blockchainIdentities valueForKeyPath:@"index.@max.intValue"];
    return max != nil ? ([max unsignedIntValue] + 1) : 0;
}

-(DSBlockchainIdentity*)createBlockchainIdentity {
    DSBlockchainIdentity * blockchainIdentity = [[DSBlockchainIdentity alloc] initAtIndex:[self unusedBlockchainIdentityIndex] inWallet:self];
    return blockchainIdentity;
}

-(DSBlockchainIdentity*)createBlockchainIdentityUsingDerivationIndex:(uint32_t)index {
    DSBlockchainIdentity * blockchainIdentity = [[DSBlockchainIdentity alloc] initAtIndex:[self unusedBlockchainIdentityIndex] inWallet:self];
    return blockchainIdentity;
}

-(DSBlockchainIdentity*)createBlockchainIdentityForUsername:(NSString*)username {
    DSBlockchainIdentity * blockchainIdentity = [self createBlockchainIdentity];
    [blockchainIdentity addDashpayUsername:username save:NO];
    return blockchainIdentity;
}

-(DSBlockchainIdentity*)createBlockchainIdentityForUsername:(NSString*)username usingDerivationIndex:(uint32_t)index {
    DSBlockchainIdentity * blockchainIdentity = [self createBlockchainIdentityUsingDerivationIndex:index];
    [blockchainIdentity addDashpayUsername:username save:NO];
    return blockchainIdentity;
}

// MARK: - Masternodes (Providers)

-(NSArray*)providerOwnerAddresses {
    DSAuthenticationKeysDerivationPath * derivationPath = [[DSDerivationPathFactory sharedInstance] providerOwnerKeysDerivationPathForWallet:self];
    if (!derivationPath.hasExtendedPublicKey) return @[];
    return [derivationPath addressesToIndex:[self unusedProviderOwnerIndex] + 10 useCache:YES addToCache:YES];
}

-(uint32_t)unusedProviderOwnerIndex {
    NSArray * indexes = [_mMasternodeOwnerIndexes allValues];
    NSNumber * max = [indexes valueForKeyPath:@"@max.intValue"];
    return max != nil ? ([max unsignedIntValue] + 1) : 0;
}

-(NSArray*)providerVotingAddresses {
    DSAuthenticationKeysDerivationPath * derivationPath = [[DSDerivationPathFactory sharedInstance] providerVotingKeysDerivationPathForWallet:self];
    if (!derivationPath.hasExtendedPublicKey) return @[];
    return [derivationPath addressesToIndex:[self unusedProviderVotingIndex] + 10 useCache:YES addToCache:YES];
}

-(uint32_t)unusedProviderVotingIndex {
    NSArray * indexes = [_mMasternodeVoterIndexes allValues];
    NSNumber * max = [indexes valueForKeyPath:@"@max.intValue"];
    return max != nil ? ([max unsignedIntValue] + 1) : 0;
}

-(NSArray*)providerOperatorAddresses {
    DSAuthenticationKeysDerivationPath * derivationPath = [[DSDerivationPathFactory sharedInstance] providerOperatorKeysDerivationPathForWallet:self];
    if (!derivationPath.hasExtendedPublicKey) return @[];
    return [derivationPath addressesToIndex:[self unusedProviderOperatorIndex] + 10 useCache:YES addToCache:YES];
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
        NSMutableDictionary * keyChainDictionary = [getKeychainDict(self.walletMasternodeOperatorsKey,@[[NSNumber class],[NSData class]], &error) mutableCopy];
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
        NSMutableDictionary * keyChainDictionary = [getKeychainDict(self.walletMasternodeOperatorsKey,@[[NSNumber class],[NSData class]], &error) mutableCopy];
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
            NSMutableDictionary * keyChainDictionary = [getKeychainDict(self.walletMasternodeOwnersKey,@[[NSNumber class],[NSData class]], &error) mutableCopy];
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
        NSMutableDictionary * keyChainDictionary = [getKeychainDict(self.walletMasternodeOwnersKey,@[[NSNumber class],[NSData class]], &error) mutableCopy];
        if (!keyChainDictionary) keyChainDictionary = [NSMutableDictionary dictionary];
        [keyChainDictionary setObject:hashedOwnerKey forKey:uint256_data(masternode.providerRegistrationTransaction.txHash)];
        setKeychainDict(keyChainDictionary, self.walletMasternodeOwnersKey, NO);
        setKeychainData([ownerKey privateKeyData], ownerKeyStorageLocation, NO);
    }
}
- (void)registerMasternodeVoter:(DSLocalMasternode *)masternode
{
    NSParameterAssert(masternode);
    
    if ([self.mMasternodeVoterIndexes objectForKey:uint256_data(masternode.providerRegistrationTransaction.txHash)] == nil) {
        [self.mMasternodeVoterIndexes setObject:@(masternode.votingWalletIndex) forKey:uint256_data(masternode.providerRegistrationTransaction.txHash)];
        NSError * error = nil;
        NSMutableDictionary * keyChainDictionary = [getKeychainDict(self.walletMasternodeVotersKey,@[[NSNumber class],[NSData class]], &error) mutableCopy];
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
        NSMutableDictionary * keyChainDictionary = [getKeychainDict(self.walletMasternodeVotersKey,@[[NSNumber class],[NSData class]], &error) mutableCopy];
        if (!keyChainDictionary) keyChainDictionary = [NSMutableDictionary dictionary];
        [keyChainDictionary setObject:hashedVoterKey forKey:uint256_data(masternode.providerRegistrationTransaction.txHash)];
        setKeychainDict(keyChainDictionary, self.walletMasternodeVotersKey, NO);
        if ([votingKey hasPrivateKey]) {
            setKeychainData([votingKey privateKeyData], ownerKeyStorageLocation, NO);
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

- (NSUInteger)indexOfBlockchainIdentityCreditFundingTopupHash:(UInt160)creditFundingTopupHash {
    DSCreditFundingDerivationPath * derivationPath = [DSCreditFundingDerivationPath blockchainIdentityTopupFundingDerivationPathForWallet:self];
    return [derivationPath indexOfKnownAddress:[[NSData dataWithUInt160:creditFundingTopupHash] addressFromHash160DataForChain:self.chain]];
}

@end
