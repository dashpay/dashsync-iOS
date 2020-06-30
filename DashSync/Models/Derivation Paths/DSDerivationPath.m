//
//  DSDerivationPath.m
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

#import "DSDerivationPath+Protected.h"
#import "DSIncomingFundsDerivationPath.h"
#import "NSManagedObject+Sugar.h"
#import "DSDashpayUserEntity+CoreDataClass.h"
#import "DSFriendRequestEntity+CoreDataClass.h"
#import "NSManagedObject+Sugar.h"
#import "DSBlockchainIdentityUsernameEntity+CoreDataClass.h"
#import "DSBlockchainIdentityEntity+CoreDataClass.h"

#define DERIVATION_PATH_EXTENDED_PUBLIC_KEY_WALLET_BASED_LOCATION @"DP_EPK_WBL"
#define DERIVATION_PATH_EXTENDED_PUBLIC_KEY_STANDALONE_BASED_LOCATION @"DP_EPK_SBL"
#define DERIVATION_PATH_EXTENDED_SECRET_KEY_WALLET_BASED_LOCATION @"DP_ESK_WBL"
#define DERIVATION_PATH_STANDALONE_INFO_DICTIONARY_LOCATION @"DP_SIDL"
#define DERIVATION_PATH_STANDALONE_INFO_CHILD @"DP_SI_CHILD"
#define DERIVATION_PATH_STANDALONE_INFO_DEPTH @"DP_SI_DEPTH"

@interface DSDerivationPath()

@property (nonatomic, copy) NSString * walletBasedExtendedPublicKeyLocationString;
@property (nonatomic, copy) NSString * walletBasedExtendedPrivateKeyLocationString;
@property (nonatomic, weak) DSAccount * account;
@property (nonatomic, strong) DSChain * chain;
@property (nonatomic, strong) NSNumber * depth;
@property (nonatomic, assign) NSNumber * child;
@property (nonatomic, strong) NSString * stringRepresentation;

@end

@implementation DSDerivationPath


// MARK: - Derivation Path initialization

+ (instancetype)masterBlockchainIdentityContactsDerivationPathForAccountNumber:(uint32_t)accountNumber onChain:(DSChain*)chain {
    NSUInteger coinType = (chain.chainType == DSChainType_MainNet)?5:1;
    UInt256 indexes[] = {uint256_from_long(FEATURE_PURPOSE),uint256_from_long(coinType), uint256_from_long(5), uint256_from_long(1), uint256_from_long(accountNumber)};
    //todo full uint256 derivation
    BOOL hardenedIndexes[] = {YES,YES,YES,YES,YES};
    return [self derivationPathWithIndexes:indexes hardened:hardenedIndexes length:5 type:DSDerivationPathType_PartialPath signingAlgorithm:DSKeyType_ECDSA reference:DSDerivationPathReference_ContactBasedFundsRoot onChain:chain];
}


+ (instancetype _Nullable)derivationPathWithIndexes:(const UInt256[_Nullable])indexes hardened:(const BOOL[_Nullable])hardenedIndexes length:(NSUInteger)length
                                               type:(DSDerivationPathType)type signingAlgorithm:(DSKeyType)signingAlgorithm reference:(DSDerivationPathReference)reference onChain:(DSChain*)chain {
    return [[self alloc] initWithIndexes:indexes hardened:hardenedIndexes length:length type:type signingAlgorithm:signingAlgorithm reference:reference onChain:chain];
}

+ (instancetype _Nullable)derivationPathWithSerializedExtendedPrivateKey:(NSString*)serializedExtendedPrivateKey fundsType:(DSDerivationPathType)fundsType signingAlgorithm:(DSKeyType)signingAlgorithm onChain:(DSChain*)chain {
    NSData * extendedPrivateKey = [self deserializedExtendedPrivateKey:serializedExtendedPrivateKey onChain:chain];
    UInt256 indexes[] = {};
    BOOL hardenedIndexes[] = {};
    DSDerivationPath * derivationPath = [[self alloc] initWithIndexes:indexes hardened:hardenedIndexes length:0 type:fundsType signingAlgorithm:DSKeyType_ECDSA reference:DSDerivationPathReference_Unknown onChain:chain];
    derivationPath.extendedPublicKey = [DSECDSAKey keyWithSecret:*(UInt256*)extendedPrivateKey.bytes compressed:YES];
    [derivationPath standaloneSaveExtendedPublicKeyToKeyChain];
    return derivationPath;
}

+ (instancetype _Nullable)derivationPathWithSerializedExtendedPublicKey:(NSString*)serializedExtendedPublicKey onChain:(DSChain*)chain {
    uint8_t depth = 0;
    uint32_t child = 0;
    NSData * extendedPublicKeyData = [self deserializedExtendedPublicKey:serializedExtendedPublicKey onChain:chain rDepth:&depth rChild:&child];
    UInt256 indexes[] = {};
    BOOL hardenedIndexes[] = {};
    DSDerivationPath * derivationPath = [[self alloc] initWithIndexes:indexes hardened:hardenedIndexes length:0 type:DSDerivationPathType_ViewOnlyFunds signingAlgorithm:DSKeyType_ECDSA reference:DSDerivationPathReference_Unknown onChain:chain]; //we are going to assume this is only ecdsa for now
    derivationPath.extendedPublicKey = [DSKey keyWithExtendedPublicKeyData:extendedPublicKeyData forKeyType:DSKeyType_ECDSA];
    derivationPath.depth = @(depth);
    derivationPath.child = @(child);
    [derivationPath standaloneSaveExtendedPublicKeyToKeyChain];
    [derivationPath loadAddresses];
    return derivationPath;
}

- (instancetype _Nullable)initWithExtendedPublicKeyIdentifier:(NSString* _Nonnull)extendedPublicKeyIdentifier onChain:(DSChain* _Nonnull)chain {
    UInt256 indexes[] = {};
    BOOL hardenedIndexes[] = {};
    if (!(self = [self initWithIndexes:indexes hardened:hardenedIndexes length:0 type:DSDerivationPathType_ViewOnlyFunds signingAlgorithm:DSKeyType_ECDSA reference:DSDerivationPathReference_Unknown onChain:chain])) return nil;
    NSError * error = nil;
    _walletBasedExtendedPublicKeyLocationString = extendedPublicKeyIdentifier;
    NSData * data = getKeychainData([DSDerivationPath standaloneExtendedPublicKeyLocationStringForUniqueID:extendedPublicKeyIdentifier], &error);
    if (error) return nil;
    _extendedPublicKey = [DSKey keyWithExtendedPublicKeyData:data forKeyType:DSKeyType_ECDSA];
    
    NSDictionary * infoDictionary = getKeychainDict([DSDerivationPath standaloneInfoDictionaryLocationStringForUniqueID:extendedPublicKeyIdentifier], &error);
    if (error) return nil;
    _depth = infoDictionary[DERIVATION_PATH_STANDALONE_INFO_DEPTH];
    _child = infoDictionary[DERIVATION_PATH_STANDALONE_INFO_CHILD];
    
    [self loadAddresses];
    return self;
}

- (instancetype)initWithIndexes:(const UInt256[_Nullable])indexes hardened:(const BOOL[_Nullable])hardenedIndexes length:(NSUInteger)length
                           type:(DSDerivationPathType)type signingAlgorithm:(DSKeyType)signingAlgorithm reference:(DSDerivationPathReference)reference onChain:(DSChain*)chain {
    if (length) {
        if (! (self = [super initWithIndexes:indexes length:length])) return nil;
    } else {
        if (! (self = [super init])) return nil;
    }
    
    _chain = chain;
    _reference = reference;
    _type = type;
    _signingAlgorithm = signingAlgorithm;
    _derivationPathIsKnown = YES;
    self.addressesLoaded = FALSE;
    self.mAllAddresses = [NSMutableSet set];
    self.mUsedAddresses = [NSMutableSet set];
    self.managedObjectContext = [NSManagedObjectContext chainContext];
    
    const size_t size = sizeof(BOOL);
    const size_t memorySize = length * size;
    _hardenedIndexes = calloc(memorySize, size);
    if (_hardenedIndexes == NULL) {
        @throw [NSException exceptionWithName:NSMallocException
                                       reason:@"DSDerivationPath could not allocate memory"
                                     userInfo:nil];
    }
    memcpy(_hardenedIndexes, hardenedIndexes, memorySize);
    
    return self;
}

- (void)dealloc
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    if (_hardenedIndexes != NULL) {
        free(_hardenedIndexes);
    }
}

// MARK: - Hardening

-(BOOL)isHardenedAtPosition:(NSUInteger)position {
    if (position >= self.length) {
        return NO;
    }
    return _hardenedIndexes[position];
}

-(NSIndexPath*)baseIndexPath {
    NSUInteger indexes[self.length];
    for (NSUInteger position = 0;position < self.length;position++) {
        if ([self isHardenedAtPosition:position]) {
            indexes[position] = [self indexAtPosition:position].u64[0] | BIP32_HARD;
        } else {
            indexes[position] = [self indexAtPosition:position].u64[0];
        }
    }
    return [NSIndexPath indexPathWithIndexes:indexes length:self.length];
}

// MARK: - Purpose

-(BOOL)isBIP32Only {
    if (self.length == 1) return true;
    return false;
}

-(BOOL)isBIP43Based {
    if (self.length != 1) return true;
    return false;
}

-(NSUInteger)purpose {
    if ([self isBIP43Based]) return [self indexAtPosition:0].u64[0];
    return 0;
}

// MARK: - Account

-(NSUInteger)accountNumber {
    return [self indexAtPosition:[self length] - 1].u64[0] & ~BIP32_HARD;
}

- (void)setAccount:(DSAccount *)account {
    if (!_account) {
        if (self.length) {
            NSAssert(account.accountNumber == [self accountNumber], @"account number doesn't match derivation path ending");
        }
        _account = account;
        //when we set the account load addresses
        
    }
}

// MARK: - Wallet and Chain

-(DSWallet*)wallet {
    if (_wallet) return _wallet;
    if (_account.wallet) return _account.wallet;
    return nil;
}

-(DSChain*)chain {
    if (_chain) return _chain;
    return self.chain;
}

-(BOOL)hasExtendedPublicKey {
    if (_extendedPublicKey) return YES;
    if (self.wallet) {
        return hasKeychainData([self walletBasedExtendedPublicKeyLocationString], nil);
    } else {
        return hasKeychainData([self standaloneExtendedPublicKeyLocationString], nil);
    }
    return NO;
}

-(NSData*)extendedPublicKeyData {
    return self.extendedPublicKey.extendedPublicKeyData;
}

-(DSKey*)extendedPublicKey {
    if (!_extendedPublicKey) {
        if (self.wallet && self.length) {
            NSData * extendedPublicKeyData = getKeychainData([self walletBasedExtendedPublicKeyLocationString], nil);
            NSAssert(extendedPublicKeyData, @"extended public key data not set");
            _extendedPublicKey = [DSKey keyWithExtendedPublicKeyData:extendedPublicKeyData forKeyType:self.signingAlgorithm];
            NSAssert(_extendedPublicKey, @"extended public key not set");
        } else {
            NSData * extendedPublicKeyData = getKeychainData([self standaloneExtendedPublicKeyLocationString], nil);
                #ifdef DEBUG
            if (!extendedPublicKeyData) {
                if ([self isKindOfClass:[DSIncomingFundsDerivationPath class]]) {
                    DSFriendRequestEntity * friendRequest = [DSFriendRequestEntity anyObjectInContext:self.managedObjectContext matching:@"derivationPath.publicKeyIdentifier == %@",self.standaloneExtendedPublicKeyUniqueID];
                    
                    NSAssert(friendRequest, @"friend request must exist");

                    DSBlockchainIdentityUsernameEntity * sourceUsernameEntity = [friendRequest.sourceContact.associatedBlockchainIdentity.usernames anyObject];
                    DSBlockchainIdentityUsernameEntity * destinationUsernameEntity = [friendRequest.destinationContact.associatedBlockchainIdentity.usernames anyObject];
                    DSDLog(@"No extended public key set for the relationship between %@ and %@ (%@ receiving payments) ",sourceUsernameEntity.stringValue,destinationUsernameEntity.stringValue,sourceUsernameEntity.stringValue);

                }
            }
            #endif
            NSAssert(extendedPublicKeyData, @"extended public key data not set");
            _extendedPublicKey = [DSKey keyWithExtendedPublicKeyData:extendedPublicKeyData forKeyType:self.signingAlgorithm];
            NSAssert(_extendedPublicKey, @"extended public key not set");
        }
    }
    return _extendedPublicKey;
}

-(void)standaloneSaveExtendedPublicKeyToKeyChain {
    if (!_extendedPublicKey) return;
    setKeychainData([self extendedPublicKeyData], [self standaloneExtendedPublicKeyLocationString], NO);
    setKeychainDict(@{DERIVATION_PATH_STANDALONE_INFO_CHILD:self.child,DERIVATION_PATH_STANDALONE_INFO_DEPTH:self.depth}, [self standaloneInfoDictionaryLocationString], NO);
    [self.managedObjectContext performBlockAndWait:^{
        [DSDerivationPathEntity derivationPathEntityMatchingDerivationPath:self inContext:self.managedObjectContext];
    }];
}

// MARK: - Derivation Path Addresses

- (NSIndexPath*)indexPathForKnownAddress:(NSString*)address {
    NSAssert(FALSE, @"This must be implemented in subclasses");
    return nil;
}

// gets an address at an index path
- (NSString *)addressAtIndexPath:(NSIndexPath *)indexPath
{
    NSData *pubKey = [self publicKeyDataAtIndexPath:indexPath];
    return [DSKey addressWithPublicKeyData:pubKey forChain:self.chain];
}

// true if the address is controlled by the wallet
- (BOOL)containsAddress:(NSString *)address
{
    return (address && [self.mAllAddresses containsObject:address]) ? YES : NO;
}

// true if the address was previously used as an input or output in any wallet transaction
- (BOOL)addressIsUsed:(NSString *)address
{
    return (address && [self.mUsedAddresses containsObject:address]) ? YES : NO;
}

// true if the address at index path was previously used as an input or output in any wallet transaction
- (BOOL)addressIsUsedAtIndexPath:(NSIndexPath *)indexPath
{
    return [self addressIsUsed:[self addressAtIndexPath:indexPath]];
}

- (BOOL)registerTransactionAddress:(NSString * _Nonnull)address {
    if ([self containsAddress:address]) {
        if (![self.mUsedAddresses containsObject:address]) {
            [self.mUsedAddresses addObject:address];
        }
        return TRUE;
    }
    return FALSE;
}

-(NSSet*)allAddresses {
    return [self.mAllAddresses copy];
}


-(NSSet*)usedAddresses {
    return [self.mUsedAddresses copy];
}

-(void)loadAddresses {
    
}

-(void)reloadAddresses {

}

// MARK: - Derivation Path Information

-(DSDerivationPathEntity*)derivationPathEntity {
    return [DSDerivationPathEntity derivationPathEntityMatchingDerivationPath:self inContext:self.managedObjectContext];
}

-(NSNumber*)depth {
    if (_depth != nil) return _depth;
    else return @(self.length);
}

-(BOOL)isDerivationPathEqual:(id)object {
    return [super isEqual:object];
}

-(BOOL)isEqual:(id)object {
    return [self.standaloneExtendedPublicKeyUniqueID isEqualToString:((DSDerivationPath*)object).standaloneExtendedPublicKeyUniqueID];
}

-(NSUInteger)hash {
    return [self.standaloneExtendedPublicKeyUniqueID hash];
}

-(NSString*)stringRepresentation {
    if (_stringRepresentation) return _stringRepresentation;
    NSMutableString * mutableString = [NSMutableString stringWithFormat:@"m"];
    if (self.length) {
        for (NSInteger i = 0;i<self.length;i++) {
            if (uint256_is_31_bits([self indexAtPosition:i])) {
                [mutableString appendFormat:@"/%lu%@",(unsigned long)[self indexAtPosition:i].u64[0],[self isHardenedAtPosition:i]?@"'":@""];
            } else {
                UInt256 index = [self indexAtPosition:i];
                [self.managedObjectContext performBlockAndWait:^{
                    DSDashpayUserEntity * dashpayUserEntity = [DSDashpayUserEntity anyObjectInContext:self.managedObjectContext matching:@"associatedBlockchainIdentity.uniqueID == %@",uint256_data(index)];
                    if (dashpayUserEntity) {
                        DSBlockchainIdentityUsernameEntity * usernameEntity = [dashpayUserEntity.associatedBlockchainIdentity.usernames anyObject];
                        [mutableString appendFormat:@"/%@%@",usernameEntity.stringValue,[self isHardenedAtPosition:i]?@"'":@""];
                    } else {
                        [mutableString appendFormat:@"/0x%@%@",uint256_hex([self indexAtPosition:i]),[self isHardenedAtPosition:i]?@"'":@""];
                    }
                }];
                
            }
        }
    } else if ([self.depth integerValue]) {
        for (NSInteger i = 0;i<[self.depth integerValue] - 1;i++) {
            [mutableString appendFormat:@"/?'"];
        }
        if (self.child != nil) {
            if ([self.child unsignedIntValue] & BIP32_HARD) {
                [mutableString appendFormat:@"/%lu'",[self.child unsignedLongValue] - BIP32_HARD];
            } else {
                [mutableString appendFormat:@"/%lu",[self.child unsignedLongValue]];
            }
        } else {
            [mutableString appendFormat:@"/?'"];
        }
        
    } else {
        if ([self isKindOfClass:[DSIncomingFundsDerivationPath class]]) {
            mutableString = [NSMutableString stringWithFormat:@"inc"];
            DSIncomingFundsDerivationPath * incomingFundsDerivationPath = (DSIncomingFundsDerivationPath*)self;
            [self.managedObjectContext performBlockAndWait:^{
                DSDashpayUserEntity * sourceDashpayUserEntity = [DSDashpayUserEntity anyObjectInContext:self.managedObjectContext matching:@"associatedBlockchainIdentity.uniqueID == %@",uint256_data(incomingFundsDerivationPath.contactSourceBlockchainIdentityUniqueId)];
                if (sourceDashpayUserEntity) {
                    DSBlockchainIdentityUsernameEntity * usernameEntity = [sourceDashpayUserEntity.associatedBlockchainIdentity.usernames anyObject];
                    [mutableString appendFormat:@"/%@",usernameEntity.stringValue];
                } else {
                    [mutableString appendFormat:@"/0x%@",uint256_hex(incomingFundsDerivationPath.contactSourceBlockchainIdentityUniqueId)];
                }
            }];
            DSBlockchainIdentity * blockchainIdentity = [self.wallet blockchainIdentityForUniqueId:incomingFundsDerivationPath.contactDestinationBlockchainIdentityUniqueId];
            [mutableString appendFormat:@"/%@",blockchainIdentity.currentUsername];
        }
    }
    _stringRepresentation = [mutableString copy];
    return _stringRepresentation;
}

-(NSString*)referenceName {
    switch (self.reference) {
        case DSDerivationPathReference_BIP32:
            return @"BIP 32";
            break;
        case DSDerivationPathReference_BIP44:
            return @"BIP 44";
            break;
        case DSDerivationPathReference_ProviderFunds:
            return @"Provider Holding Funds Keys";
            break;
        case DSDerivationPathReference_ProviderOwnerKeys:
            return @"Provider Owner Keys";
            break;
        case DSDerivationPathReference_ProviderOperatorKeys:
            return @"Provider Operator Keys";
            break;
        case DSDerivationPathReference_ProviderVotingKeys:
            return @"Provider Voting Keys";
            break;
        case DSDerivationPathReference_BlockchainIdentities:
            return @"Blockchain Identities";
            break;
        case DSDerivationPathReference_ContactBasedFunds:
            return @"Contact Funds";
            break;
        case DSDerivationPathReference_ContactBasedFundsExternal:
            return @"Contact Funds External";
            break;
        case DSDerivationPathReference_ContactBasedFundsRoot:
            return @"Contact Funds Root";
            break;
        default:
            return @"Unknown";
            break;
    }
}

-(NSString*)debugDescription {
    return [[super debugDescription] stringByAppendingString:[NSString stringWithFormat:@" {%@}",[self stringRepresentation]]];
}

// MARK: - Identifiers

//Derivation paths can be stored based on the wallet and derivation or based solely on the public key

-(NSString*)createIdentifierForDerivationPath {
    return [NSData dataWithUInt256:[[self extendedPublicKeyData] SHA256]].shortHexString;
}

-(NSString *)standaloneExtendedPublicKeyUniqueID {
    if (!_standaloneExtendedPublicKeyUniqueID) {
        if (!_extendedPublicKey && !self.wallet) {
            NSAssert(FALSE, @"we really should have a wallet");
            return nil;
        }
        _standaloneExtendedPublicKeyUniqueID = [self createIdentifierForDerivationPath];
    }
    return _standaloneExtendedPublicKeyUniqueID;
}

+(NSString*)standaloneExtendedPublicKeyLocationStringForUniqueID:(NSString*)uniqueID {
    return [NSString stringWithFormat:@"%@_%@",DERIVATION_PATH_EXTENDED_PUBLIC_KEY_STANDALONE_BASED_LOCATION,uniqueID];
}

-(NSString*)standaloneExtendedPublicKeyLocationString {
    if (!self.standaloneExtendedPublicKeyUniqueID) return nil;
    return [DSDerivationPath standaloneExtendedPublicKeyLocationStringForUniqueID:self.standaloneExtendedPublicKeyUniqueID];
}

+(NSString*)standaloneInfoDictionaryLocationStringForUniqueID:(NSString*)uniqueID {
    return [NSString stringWithFormat:@"%@_%@",DERIVATION_PATH_STANDALONE_INFO_DICTIONARY_LOCATION,uniqueID];
}

-(NSString*)standaloneInfoDictionaryLocationString {
    if (!self.standaloneExtendedPublicKeyUniqueID) return nil;
    return [DSDerivationPath standaloneInfoDictionaryLocationStringForUniqueID:self.standaloneExtendedPublicKeyUniqueID];
}

+(NSString*)walletBasedExtendedPublicKeyLocationStringForUniqueID:(NSString*)uniqueID {
    return [NSString stringWithFormat:@"%@_%@",DERIVATION_PATH_EXTENDED_PUBLIC_KEY_WALLET_BASED_LOCATION,uniqueID];
}

-(NSString*)walletBasedExtendedPublicKeyLocationStringForWalletUniqueID:(NSString*)uniqueID {
    NSMutableString * mutableString = [NSMutableString string];
    for (NSInteger i = 0;i<self.length;i++) {
        [mutableString appendFormat:@"_%lu",(unsigned long)([self isHardenedAtPosition:i]?[self indexAtPosition:i].u64[0] | BIP32_HARD:[self indexAtPosition:i].u64[0])];
    }
    return [NSString stringWithFormat:@"%@%@%@",[DSDerivationPath walletBasedExtendedPublicKeyLocationStringForUniqueID:uniqueID],self.signingAlgorithm==DSKeyType_BLS?@"_BLS_":@"",mutableString];
}

-(NSString*)walletBasedExtendedPublicKeyLocationString {
    if (_walletBasedExtendedPublicKeyLocationString) return _walletBasedExtendedPublicKeyLocationString;
    _walletBasedExtendedPublicKeyLocationString = [self walletBasedExtendedPublicKeyLocationStringForWalletUniqueID:self.wallet.uniqueIDString];
    return _walletBasedExtendedPublicKeyLocationString;
}

+(NSString*)walletBasedExtendedPrivateKeyLocationStringForUniqueID:(NSString*)uniqueID {
    return [NSString stringWithFormat:@"%@_%@",DERIVATION_PATH_EXTENDED_SECRET_KEY_WALLET_BASED_LOCATION,uniqueID];
}

-(NSString*)walletBasedExtendedPrivateKeyLocationStringForWalletUniqueID:(NSString*)uniqueID {
    NSMutableString * mutableString = [NSMutableString string];
    for (NSInteger i = 0;i<self.length;i++) {
        [mutableString appendFormat:@"_%lu",(unsigned long)([self isHardenedAtPosition:i]?[self indexAtPosition:i].u64[0] | BIP32_HARD:[self indexAtPosition:i].u64[0])];
    }
    return [NSString stringWithFormat:@"%@%@%@",[DSDerivationPath walletBasedExtendedPrivateKeyLocationStringForUniqueID:uniqueID],self.signingAlgorithm==DSKeyType_BLS?@"_BLS_":@"",mutableString];
}

-(NSString*)walletBasedExtendedPrivateKeyLocationString {
    if (_walletBasedExtendedPrivateKeyLocationString) return _walletBasedExtendedPrivateKeyLocationString;
    _walletBasedExtendedPrivateKeyLocationString = [self walletBasedExtendedPrivateKeyLocationStringForWalletUniqueID:self.wallet.uniqueIDString];
    return _walletBasedExtendedPrivateKeyLocationString;
}

// MARK: - Key Generation

- (DSKey *)generateExtendedPublicKeyFromSeed:(NSData *)seed storeUnderWalletUniqueId:(NSString*)walletUniqueId {
    return [self generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:walletUniqueId storePrivateKey:NO];
}

- (DSKey *)generateExtendedPublicKeyFromSeed:(NSData *)seed storeUnderWalletUniqueId:(NSString*)walletUniqueId storePrivateKey:(BOOL)storePrivateKey
{
    if (! seed) return nil;
    if (![self length]) return nil; //there needs to be at least 1 length
    DSKey * seedKey = [DSKey keyWithSeedData:seed forKeyType:self.signingAlgorithm];
    if (!seedKey) return nil;
    _extendedPublicKey = [seedKey privateDeriveTo256BitDerivationPath:self];
    NSAssert(_extendedPublicKey, @"extendedPublicKey should be set");
    if (!_extendedPublicKey) return nil;
    
    if (walletUniqueId) {
        setKeychainData(_extendedPublicKey.extendedPublicKeyData,[self walletBasedExtendedPublicKeyLocationStringForWalletUniqueID:walletUniqueId],NO);
        if (storePrivateKey) {
            setKeychainData(_extendedPublicKey.extendedPrivateKeyData,[self walletBasedExtendedPrivateKeyLocationStringForWalletUniqueID:walletUniqueId],YES);
        }
    }

    [_extendedPublicKey forgetPrivateKey];
    
    return _extendedPublicKey;
}

- (DSKey *)generateExtendedPublicKeyFromParentDerivationPath:(DSDerivationPath*)parentDerivationPath storeUnderWalletUniqueId:(NSString*)walletUniqueId {
    NSAssert(parentDerivationPath.signingAlgorithm == self.signingAlgorithm, @"The signing algorithms must be the same");
    NSParameterAssert(parentDerivationPath);
    NSAssert(self.length > parentDerivationPath.length, @"length must be inferior to the parent derivation path length");
    NSAssert(parentDerivationPath.extendedPublicKey, @"the parent derivation path must have an extended public key");
    if (![self length]) return nil; //there needs to be at least 1 length
    if (self.length <= parentDerivationPath.length) return nil; // we need to be longer
    if (!parentDerivationPath.extendedPublicKey) return nil; //parent derivation path
    if (parentDerivationPath.signingAlgorithm != self.signingAlgorithm) return nil;
    for (NSInteger i = 0;i<[parentDerivationPath length] - 1;i++) {
        NSAssert(uint256_eq([parentDerivationPath indexAtPosition:i],[self indexAtPosition:i]), @"This derivation path must start with elements of the parent derivation path");
        if (!uint256_eq([parentDerivationPath indexAtPosition:i],[self indexAtPosition:i])) return nil;
    }
    
    _extendedPublicKey = [parentDerivationPath.extendedPublicKey publicDeriveTo256BitDerivationPath:self derivationPathOffset:parentDerivationPath.length];
    
    NSAssert(_extendedPublicKey, @"extendedPublicKey should be set");
    
    if (walletUniqueId) {
        setKeychainData(_extendedPublicKey.extendedPublicKeyData,[self walletBasedExtendedPublicKeyLocationStringForWalletUniqueID:walletUniqueId],NO);
    }
    
    return _extendedPublicKey;

}

- (DSKey *)privateKeyForKnownAddress:(NSString*)address fromSeed:(NSData *)seed {
    NSIndexPath * indexPathForAddress = [self indexPathForKnownAddress:address];
    return [self privateKeyAtIndexPath:indexPathForAddress fromSeed:seed];
}

- (DSKey *)privateKeyAtIndexPath:(NSIndexPath*)indexPath fromSeed:(NSData *)seed {
    NSParameterAssert(indexPath);
    NSParameterAssert(seed);
    if (! seed || !indexPath) return nil;
    if (![self length]) return nil; //there needs to be at least 1 length
    DSKey * topKey = [DSKey keyWithSeedData:seed forKeyType:self.signingAlgorithm];
    NSAssert(topKey, @"Top key should exist");
    if (!topKey) return nil;
    DSKey * derivationPathExtendedKey = [topKey privateDeriveTo256BitDerivationPath:self];
    NSAssert(derivationPathExtendedKey, @"Top key should exist");
    if (!derivationPathExtendedKey) return nil;
    return [derivationPathExtendedKey privateDeriveToPath:indexPath];
}

-(DSKey*)publicKeyAtIndexPath:(NSIndexPath*)indexPath {
    if (self.signingAlgorithm == DSKeyType_ECDSA) {
        return [DSECDSAKey keyWithPublicKeyData:[self publicKeyDataAtIndexPath:indexPath]];
    } else if (self.signingAlgorithm == DSKeyType_BLS) {
        return [DSBLSKey keyWithPublicKey:[self publicKeyDataAtIndexPath:indexPath].UInt384];
    }
    return nil;
}

- (NSData *)publicKeyDataAtIndexPath:(NSIndexPath*)indexPath
{
    if (self.signingAlgorithm == DSKeyType_ECDSA) {
        if (self.extendedPublicKeyData.length < 4 + sizeof(UInt256) + sizeof(DSECPoint)) {
            NSAssert(NO, @"Extended public key is wrong size");
            return nil;
        }
        
        UInt256 chain = *(const UInt256 *)((const uint8_t *)self.extendedPublicKeyData.bytes + 4);
        DSECPoint pubKey = *(const DSECPoint *)((const uint8_t *)self.extendedPublicKeyData.bytes + 36);
        for (NSInteger i = 0;i<[indexPath length];i++) {
            uint32_t derivation = (uint32_t)[indexPath indexAtPosition:i];
            CKDpub(&pubKey, &chain, derivation);
        }
        NSData * data = [NSData dataWithBytes:&pubKey length:sizeof(pubKey)];
        NSAssert(data, @"Public key should be created");
        return data;
    } else if (self.signingAlgorithm == DSKeyType_BLS) {
        DSBLSKey * extendedPublicKey = [DSBLSKey keyWithExtendedPublicKeyData:self.extendedPublicKeyData];
        DSBLSKey * extendedPublicKeyAtIndexPath = [extendedPublicKey publicDeriveToPath:indexPath];
        NSData * data = [NSData dataWithUInt384:extendedPublicKeyAtIndexPath.publicKey];
        NSAssert(data, @"Public key should be created");
        return data;
    }
    return nil;
}

- (NSArray *)privateKeysAtIndexPaths:(NSArray*)indexPaths fromSeed:(NSData *)seed {
    if (! seed || ! indexPaths) return nil;
    if (indexPaths.count == 0) return @[];
    NSMutableArray *privateKeys = [NSMutableArray arrayWithCapacity:indexPaths.count];
    DSKey * topKey = [DSKey keyWithSeedData:seed forKeyType:self.signingAlgorithm];
    DSKey * derivationPathExtendedKey = [topKey privateDeriveTo256BitDerivationPath:self];
    
#if DEBUG
    if (_extendedPublicKey) {
        NSData * publicKey = _extendedPublicKey.extendedPublicKeyData;
        NSAssert([publicKey isEqualToData:derivationPathExtendedKey.extendedPublicKeyData], @"The derivation doesn't match the public key");
    }
#endif
    
    for (NSIndexPath *indexPath in indexPaths) {
        DSKey * privateKey = [derivationPathExtendedKey privateDeriveToPath:indexPath];
        [privateKeys addObject:privateKey];
    }
    
    return privateKeys;
}



- (NSArray *)serializedPrivateKeysAtIndexPaths:(NSArray*)indexPaths fromSeed:(NSData *)seed {
    if (! seed || ! indexPaths) return nil;
    if (indexPaths.count == 0) return @[];
    
    NSMutableArray *serializedPrivateKeys = [NSMutableArray arrayWithCapacity:indexPaths.count];
    DSKey * topKey = [DSKey keyWithSeedData:seed forKeyType:self.signingAlgorithm];
    DSKey * derivationPathExtendedKey = [topKey privateDeriveTo256BitDerivationPath:self];
    
    for (NSIndexPath *indexPath in indexPaths) {
        DSKey * privateKey = [derivationPathExtendedKey privateDeriveToPath:indexPath];
        NSString * serializedPrivateKey = [privateKey serializedPrivateKeyForChain:self.chain];
        NSAssert(serializedPrivateKey, @"The serialized private key should exist");
        [serializedPrivateKeys addObject:serializedPrivateKey];
    }
    
    return serializedPrivateKeys;
}


// MARK: - Deprecated

//this is for upgrade purposes only
- (DSKey *)deprecatedIncorrectExtendedPublicKeyFromSeed:(NSData *)seed
{
    if (! seed) return nil;
    if (![self length]) return nil; //there needs to be at least 1 length
    NSMutableData *mpk = [NSMutableData secureData];
    UInt512 I;
    
    HMAC(&I, SHA512, sizeof(UInt512), BIP32_SEED_KEY, strlen(BIP32_SEED_KEY), seed.bytes, seed.length);
    
    UInt256 secret = *(UInt256 *)&I, chain = *(UInt256 *)&I.u8[sizeof(UInt256)];
    
    [mpk appendBytes:[DSECDSAKey keyWithSecret:secret compressed:YES].hash160.u32 length:4];
    
    for (NSInteger i = 0;i<[self length];i++) {
        uint32_t derivation = (uint32_t)[self indexAtPosition:i].u64[0];
        CKDpriv(&secret, &chain, derivation);
    }
    
    [mpk appendBytes:&chain length:sizeof(chain)];
    [mpk appendData:[DSECDSAKey keyWithSecret:secret compressed:YES].publicKeyData];
    
    return [DSKey keyWithExtendedPublicKeyData:mpk forKeyType:DSKeyType_ECDSA];
}

// MARK: - Storage

-(BOOL)storeExtendedPublicKeyUnderWalletUniqueId:(NSString*)walletUniqueId {
    if (!_extendedPublicKey) return FALSE;
    NSParameterAssert(walletUniqueId);
    setKeychainData(_extendedPublicKey.extendedPublicKeyData,[self walletBasedExtendedPublicKeyLocationStringForWalletUniqueID:walletUniqueId],NO);
    return TRUE;
}

// MARK: - Serializations

- (NSString *)serializedExtendedPrivateKeyFromSeed:(NSData *)seed
{
    @autoreleasepool {
        if (! seed) return nil;
        
        UInt512 I;
        
        HMAC(&I, SHA512, sizeof(UInt512), BIP32_SEED_KEY, strlen(BIP32_SEED_KEY), seed.bytes, seed.length);
        
        UInt256 secret = *(UInt256 *)&I, chain = *(UInt256 *)&I.u8[sizeof(UInt256)];
        
        for (NSInteger i = 0;i<[self length] - 1;i++) {
            CKDpriv256(&secret, &chain, [self indexAtPosition:i],[self isHardenedAtPosition:i]);
        }
        uint32_t fingerprint = [DSECDSAKey keyWithSecret:secret compressed:YES].hash160.u32[0];
        CKDpriv256(&secret, &chain, [self indexAtPosition:[self length] - 1],[self isHardenedAtPosition:[self length] - 1]); // account 0H
        
        return serialize([self length], fingerprint, self.account.accountNumber | BIP32_HARD, chain, [NSData dataWithBytes:&secret length:sizeof(secret)],[self.chain isMainnet]);
    }
}

+ (NSData *)deserializedExtendedPrivateKey:(NSString *)extendedPrivateKeyString onChain:(DSChain*)chain
{
    @autoreleasepool {
        uint8_t depth;
        uint32_t fingerprint;
        uint32_t child;
        UInt256 chainHash;
        NSData * privkey = nil;
        NSMutableData * masterPrivateKey = [NSMutableData secureData];
        BOOL valid = deserialize(extendedPrivateKeyString, &depth, &fingerprint, &child, &chainHash, &privkey,[chain isMainnet]);
        if (!valid) return nil;
        [masterPrivateKey appendUInt32:CFSwapInt32HostToBig(fingerprint)];
        [masterPrivateKey appendBytes:&chainHash length:32];
        [masterPrivateKey appendData:privkey];
        return [masterPrivateKey copy];
    }
}

- (NSString *)serializedExtendedPublicKey
{
    //todo make sure this works with BLS keys
    if (self.extendedPublicKeyData.length < 36) return nil;
    
    uint32_t fingerprint = CFSwapInt32BigToHost(*(const uint32_t *)self.extendedPublicKeyData.bytes);
    UInt256 chain = *(UInt256 *)((const uint8_t *)self.extendedPublicKeyData.bytes + 4);
    DSECPoint pubKey = *(DSECPoint *)((const uint8_t *)self.extendedPublicKeyData.bytes + 36);
    uint32_t child = self.child != nil ? [self.child unsignedIntValue] : self.account.accountNumber | BIP32_HARD;
    return serialize([self.depth unsignedCharValue], fingerprint, child, chain, [NSData dataWithBytes:&pubKey length:sizeof(pubKey)],[self.chain isMainnet]);
}

+ (NSData *)deserializedExtendedPublicKey:(NSString *)extendedPublicKeyString onChain:(DSChain*)chain rDepth:(uint8_t*)depth rChild:(uint32_t*)child
{
    uint32_t fingerprint;
    UInt256 chainHash;
    NSData * pubkey = nil;
    NSMutableData * masterPublicKey = [NSMutableData secureData];
    BOOL valid = deserialize(extendedPublicKeyString, depth, &fingerprint, child, &chainHash, &pubkey,[chain isMainnet]);
    if (!valid) return nil;
    [masterPublicKey appendUInt32:CFSwapInt32HostToBig(fingerprint)];
    [masterPublicKey appendBytes:&chainHash length:32];
    [masterPublicKey appendData:pubkey];
    return [masterPublicKey copy];
}

+ (NSData *)deserializedExtendedPublicKey:(NSString *)extendedPublicKeyString onChain:(DSChain *)chain
{
    __unused uint8_t depth = 0;
    __unused uint32_t child = 0;
    NSData * extendedPublicKey = [self deserializedExtendedPublicKey:extendedPublicKeyString onChain:chain rDepth:&depth rChild:&child];
    return extendedPublicKey;
}

- (NSData *)deserializedExtendedPublicKey:(NSString *)extendedPublicKeyString
{
    return [DSDerivationPath deserializedExtendedPublicKey:extendedPublicKeyString onChain:self.chain];
}

@end

