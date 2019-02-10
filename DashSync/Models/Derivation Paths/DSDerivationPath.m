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

// BIP32 is a scheme for deriving chains of addresses from a seed value
// https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki

// Private parent key -> private child key
//
// CKDpriv((kpar, cpar), i) -> (ki, ci) computes a child extended private key from the parent extended private key:
//
// - Check whether i >= 2^31 (whether the child is a hardened key).
//     - If so (hardened child): let I = HMAC-SHA512(Key = cpar, Data = 0x00 || ser256(kpar) || ser32(i)).
//       (Note: The 0x00 pads the private key to make it 33 bytes long.)
//     - If not (normal child): let I = HMAC-SHA512(Key = cpar, Data = serP(point(kpar)) || ser32(i)).
// - Split I into two 32-byte sequences, IL and IR.
// - The returned child key ki is parse256(IL) + kpar (mod n).
// - The returned chain code ci is IR.
// - In case parse256(IL) >= n or ki = 0, the resulting key is invalid, and one should proceed with the next value for i
//   (Note: this has probability lower than 1 in 2^127.)
//
static void CKDpriv(UInt256 *k, UInt256 *c, uint32_t i)
{
    uint8_t buf[sizeof(DSECPoint) + sizeof(i)];
    UInt512 I;
    
    if (i & BIP32_HARD) {
        buf[0] = 0;
        *(UInt256 *)&buf[1] = *k;
    }
    else DSSecp256k1PointGen((DSECPoint *)buf, k);
    
    *(uint32_t *)&buf[sizeof(DSECPoint)] = CFSwapInt32HostToBig(i);
    
    HMAC(&I, SHA512, sizeof(UInt512), c, sizeof(*c), buf, sizeof(buf)); // I = HMAC-SHA512(c, k|P(k) || i)
    
    DSSecp256k1ModAdd(k, (UInt256 *)&I); // k = IL + k (mod n)
    *c = *(UInt256 *)&I.u8[sizeof(UInt256)]; // c = IR
    
    memset(buf, 0, sizeof(buf));
    memset(&I, 0, sizeof(I));
}

__unused static void CKDpriv256(UInt256 *k, UInt256 *c, UInt256 i)
{
    uint8_t buf[sizeof(DSECPoint) + sizeof(i)];
    UInt512 I;
    
    DSSecp256k1PointGen((DSECPoint *)buf, k);
    
    *(UInt256 *)&buf[sizeof(DSECPoint)] = i;
    
    HMAC(&I, SHA512, sizeof(UInt512), c, sizeof(*c), buf, sizeof(buf)); // I = HMAC-SHA512(c, k|P(k) || i)
    
    DSSecp256k1ModAdd(k, (UInt256 *)&I); // k = IL + k (mod n)
    *c = *(UInt256 *)&I.u8[sizeof(UInt256)]; // c = IR
    
    memset(buf, 0, sizeof(buf));
    memset(&I, 0, sizeof(I));
}

// Public parent key -> public child key
//
// CKDpub((Kpar, cpar), i) -> (Ki, ci) computes a child extended public key from the parent extended public key.
// It is only defined for non-hardened child keys.
//
// - Check whether i >= 2^31 (whether the child is a hardened key).
//     - If so (hardened child): return failure
//     - If not (normal child): let I = HMAC-SHA512(Key = cpar, Data = serP(Kpar) || ser32(i)).
// - Split I into two 32-byte sequences, IL and IR.
// - The returned child key Ki is point(parse256(IL)) + Kpar.
// - The returned chain code ci is IR.
// - In case parse256(IL) >= n or Ki is the point at infinity, the resulting key is invalid, and one should proceed with
//   the next value for i.
//
static void CKDpub(DSECPoint *K, UInt256 *c, uint32_t i)
{
    if (i & BIP32_HARD) return; // can't derive private child key from public parent key
    
    uint8_t buf[sizeof(*K) + sizeof(i)];
    UInt512 I;
    
    *(DSECPoint *)buf = *K;
    *(uint32_t *)&buf[sizeof(*K)] = CFSwapInt32HostToBig(i);
    
    HMAC(&I, SHA512, sizeof(UInt512), c, sizeof(*c), buf, sizeof(buf)); // I = HMAC-SHA512(c, P(K) || i)
    
    *c = *(UInt256 *)&I.u8[sizeof(UInt256)]; // c = IR
    DSSecp256k1PointAdd(K, (UInt256 *)&I); // K = P(IL) + K
    
    memset(buf, 0, sizeof(buf));
    memset(&I, 0, sizeof(I));
}

#define DERIVATION_PATH_EXTENDED_PUBLIC_KEY_WALLET_BASED_LOCATION @"DP_EPK_WBL"
#define DERIVATION_PATH_EXTENDED_PUBLIC_KEY_STANDALONE_BASED_LOCATION @"DP_EPK_SBL"
#define DERIVATION_PATH_STANDALONE_INFO_DICTIONARY_LOCATION @"DP_SIDL"
#define DERIVATION_PATH_STANDALONE_INFO_CHILD @"DP_SI_CHILD"
#define DERIVATION_PATH_STANDALONE_INFO_DEPTH @"DP_SI_DEPTH"

@interface DSDerivationPath()

@property (nonatomic, copy) NSString * walletBasedExtendedPublicKeyLocationString;
@property (nonatomic, weak) DSAccount * account;
@property (nonatomic, strong) NSData * extendedPublicKey;//master public key used to generate wallet addresses
@property (nonatomic, strong) DSChain * chain;
@property (nonatomic, strong) NSNumber * depth;
@property (nonatomic, assign) NSNumber * child;
@property (nonatomic, strong) NSString * standaloneExtendedPublicKeyUniqueID;
@property (nonatomic, strong) NSString * stringRepresentation;
@property (nonatomic, weak) DSWallet * wallet;

@end

@implementation DSDerivationPath


// MARK: - Derivation Path initialization

+ (instancetype _Nonnull)blockchainUsersDerivationPathForWallet:(DSWallet*)wallet {
    NSUInteger coinType = (wallet.chain.chainType == DSChainType_MainNet)?5:1;
    NSUInteger indexes[] = {5 | BIP32_HARD, coinType | BIP32_HARD, 11 | BIP32_HARD};
    DSDerivationPath * derivationPath = [self derivationPathWithIndexes:indexes length:3 type:DSDerivationPathType_Authentication signingAlgorithm:DSDerivationPathSigningAlgorith_BLS reference:DSDerivationPathReference_BlockchainUsers onChain:wallet.chain];
    derivationPath.wallet = wallet;
    return derivationPath;
}

+ (instancetype _Nullable)derivationPathWithIndexes:(NSUInteger *)indexes length:(NSUInteger)length
                                               type:(DSDerivationPathType)type signingAlgorithm:(DSDerivationPathSigningAlgorith)signingAlgorithm reference:(DSDerivationPathReference)reference onChain:(DSChain*)chain {
    return [[self alloc] initWithIndexes:indexes length:length type:type signingAlgorithm:signingAlgorithm reference:reference onChain:chain];
}

+ (instancetype _Nullable)derivationPathWithSerializedExtendedPrivateKey:(NSString*)serializedExtendedPrivateKey fundsType:(DSDerivationPathType)fundsType signingAlgorithm:(DSDerivationPathSigningAlgorith)signingAlgorithm onChain:(DSChain*)chain {
    NSData * extendedPrivateKey = [self deserializedExtendedPrivateKey:serializedExtendedPrivateKey onChain:chain];
    NSUInteger indexes[] = {};
    DSDerivationPath * derivationPath = [[self alloc] initWithIndexes:indexes length:0 type:fundsType signingAlgorithm:DSDerivationPathSigningAlgorith_ECDSA reference:DSDerivationPathReference_Unknown onChain:chain];
    derivationPath.extendedPublicKey = [DSKey keyWithSecret:*(UInt256*)extendedPrivateKey.bytes compressed:YES].publicKey;
    [derivationPath standaloneSaveExtendedPublicKeyToKeyChain];
    return derivationPath;
}

+ (instancetype _Nullable)derivationPathWithSerializedExtendedPublicKey:(NSString*)serializedExtendedPublicKey onChain:(DSChain*)chain {
    uint8_t depth = 0;
    uint32_t child = 0;
    NSData * extendedPublicKey = [self deserializedExtendedPublicKey:serializedExtendedPublicKey onChain:chain rDepth:&depth rChild:&child];
    NSUInteger indexes[] = {};
    DSDerivationPath * derivationPath = [[self alloc] initWithIndexes:indexes length:0 type:DSDerivationPathType_ViewOnlyFunds signingAlgorithm:DSDerivationPathSigningAlgorith_ECDSA reference:DSDerivationPathReference_Unknown onChain:chain]; //we are going to assume this is only ecdsa for now
    derivationPath.extendedPublicKey = extendedPublicKey;
    derivationPath.depth = @(depth);
    derivationPath.child = @(child);
    [derivationPath standaloneSaveExtendedPublicKeyToKeyChain];
    [derivationPath loadAddresses];
    return derivationPath;
}

- (instancetype _Nullable)initWithExtendedPublicKeyIdentifier:(NSString* _Nonnull)extendedPublicKeyIdentifier onChain:(DSChain* _Nonnull)chain {
    NSUInteger indexes[] = {};
    if (!(self = [self initWithIndexes:indexes length:0 type:DSDerivationPathType_ViewOnlyFunds signingAlgorithm:DSDerivationPathSigningAlgorith_ECDSA reference:DSDerivationPathReference_Unknown onChain:chain])) return nil;
    NSError * error = nil;
    _walletBasedExtendedPublicKeyLocationString = extendedPublicKeyIdentifier;
    _extendedPublicKey = getKeychainData([DSDerivationPath standaloneExtendedPublicKeyLocationStringForUniqueID:extendedPublicKeyIdentifier], &error);
    if (error) return nil;
    NSDictionary * infoDictionary = getKeychainDict([DSDerivationPath standaloneInfoDictionaryLocationStringForUniqueID:extendedPublicKeyIdentifier], &error);
    if (error) return nil;
    _depth = infoDictionary[DERIVATION_PATH_STANDALONE_INFO_DEPTH];
    _child = infoDictionary[DERIVATION_PATH_STANDALONE_INFO_CHILD];
    
    [self loadAddresses];
    return self;
}

- (instancetype)initWithIndexes:(NSUInteger *)indexes length:(NSUInteger)length
                           type:(DSDerivationPathType)type signingAlgorithm:(DSDerivationPathSigningAlgorith)signingAlgorithm reference:(DSDerivationPathReference)reference onChain:(DSChain*)chain {
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
    self.moc = [NSManagedObject context];
    
    return self;
}

- (void)dealloc
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
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
    if ([self isBIP43Based]) return [self indexAtPosition:0];
    return 0;
}

// MARK: - Account

-(NSUInteger)accountNumber {
    return [self indexAtPosition:[self length] - 1] & ~BIP32_HARD;
}

- (void)setAccount:(DSAccount *)account {
    if (!_account) {
        NSAssert(account.accountNumber == [self accountNumber], @"account number doesn't match derivation path ending");
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
    return (!!_extendedPublicKey);
}

-(NSData*)extendedPublicKey {
    if (!_extendedPublicKey) {
        if (self.wallet) {
            _extendedPublicKey = getKeychainData([self walletBasedExtendedPublicKeyLocationString], nil);
        }
    }
    NSAssert(_extendedPublicKey, @"extended public key not set");
    return _extendedPublicKey;
}

-(void)standaloneSaveExtendedPublicKeyToKeyChain {
    if (!_extendedPublicKey) return;
    setKeychainData(_extendedPublicKey, [self standaloneExtendedPublicKeyLocationString], NO);
    setKeychainDict(@{DERIVATION_PATH_STANDALONE_INFO_CHILD:self.child,DERIVATION_PATH_STANDALONE_INFO_DEPTH:self.depth}, [self standaloneInfoDictionaryLocationString], NO);
    [self.moc performBlockAndWait:^{
        [DSDerivationPathEntity setContext:self.moc];
        [DSDerivationPathEntity derivationPathEntityMatchingDerivationPath:self];
    }];
}

// MARK: - Derivation Path Addresses

// gets a public key at an index
- (NSData*)publicKeyAtIndex:(uint32_t)index
{
    return [self generatePublicKeyAtIndexPath:[NSIndexPath indexPathWithIndex:index]];
}

// gets a public key at an index path
- (NSData*)publicKeyAtIndexPath:(NSIndexPath *)indexPath
{
    return [self generatePublicKeyAtIndexPath:indexPath];
}

// gets an addess at an index
- (NSString *)addressAtIndex:(uint32_t)index
{
    NSData *pubKey = [self generatePublicKeyAtIndexPath:[NSIndexPath indexPathWithIndex:index]];
    return [[DSKey keyWithPublicKey:pubKey] addressForChain:self.chain];
}

// gets an address at an index path
- (NSString *)addressAtIndexPath:(NSIndexPath *)indexPath
{
    NSData *pubKey = [self generatePublicKeyAtIndexPath:indexPath];
    return [[DSKey keyWithPublicKey:pubKey] addressForChain:self.chain];
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

- (void)registerTransactionAddress:(NSString * _Nonnull)address {
    [self.mUsedAddresses addObject:address];
}

-(NSSet*)allAddresses {
    return [self.mAllAddresses copy];
}


-(NSSet*)usedAddresses {
    return [self.mUsedAddresses copy];
}

-(void)loadAddresses {
    
}

// MARK: - Blockchain User

- (NSArray *)publicKeysToIndex:(NSUInteger)index
{
    NSMutableArray * mArray = [NSMutableArray array];
    for (int i = 0;i<index;i++) {
        NSData *pubKey = [self generatePublicKeyAtIndexPath:[NSIndexPath indexPathWithIndex:i]];
        [mArray addObject:pubKey];
    }
    return [mArray copy];
}

- (NSArray *)addressesToIndex:(NSUInteger)index
{
    NSMutableArray * mArray = [NSMutableArray array];
    for (NSData * pubKey in [self publicKeysToIndex:index]) {
        NSString *addr = [[DSKey keyWithPublicKey:pubKey] addressForChain:self.chain];
        [mArray addObject:addr];
    }
    return [mArray copy];
}

// MARK: - Derivation Path Information

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
            if ([self indexAtPosition:i] & BIP32_HARD) {
                [mutableString appendFormat:@"/%lu'",(unsigned long)[self indexAtPosition:i] - BIP32_HARD];
            } else {
                [mutableString appendFormat:@"/%lu",(unsigned long)[self indexAtPosition:i]];
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
        
    }
    _stringRepresentation = [mutableString copy];
    return _stringRepresentation;
}

-(NSString*)debugDescription {
    return [[super debugDescription] stringByAppendingString:[NSString stringWithFormat:@" {%@}",[self stringRepresentation]]];
}

// MARK: - Identifiers

//Derivation paths can be stored based on the wallet and derivation or based solely on the public key


-(NSString *)standaloneExtendedPublicKeyUniqueID {
    if (!_standaloneExtendedPublicKeyUniqueID) _standaloneExtendedPublicKeyUniqueID = [NSData dataWithUInt256:[[self extendedPublicKey] SHA256]].shortHexString;
    return _standaloneExtendedPublicKeyUniqueID;
}

+(NSString*)standaloneExtendedPublicKeyLocationStringForUniqueID:(NSString*)uniqueID {
    return [NSString stringWithFormat:@"%@_%@",DERIVATION_PATH_EXTENDED_PUBLIC_KEY_STANDALONE_BASED_LOCATION,uniqueID];
}

-(NSString*)standaloneExtendedPublicKeyLocationString {
    return [DSDerivationPath standaloneExtendedPublicKeyLocationStringForUniqueID:self.standaloneExtendedPublicKeyUniqueID];
}

+(NSString*)standaloneInfoDictionaryLocationStringForUniqueID:(NSString*)uniqueID {
    return [NSString stringWithFormat:@"%@_%@",DERIVATION_PATH_STANDALONE_INFO_DICTIONARY_LOCATION,uniqueID];
}

-(NSString*)standaloneInfoDictionaryLocationString {
    return [DSDerivationPath standaloneInfoDictionaryLocationStringForUniqueID:self.standaloneExtendedPublicKeyUniqueID];
}

+(NSString*)walletBasedExtendedPublicKeyLocationStringForUniqueID:(NSString*)uniqueID {
    return [NSString stringWithFormat:@"%@_%@",DERIVATION_PATH_EXTENDED_PUBLIC_KEY_WALLET_BASED_LOCATION,uniqueID];
}

-(NSString*)walletBasedExtendedPublicKeyLocationStringForWalletUniqueID:(NSString*)uniqueID {
    NSMutableString * mutableString = [NSMutableString string];
    for (NSInteger i = 0;i<self.length;i++) {
        [mutableString appendFormat:@"_%lu",(unsigned long)[self indexAtPosition:i]];
    }
    return [NSString stringWithFormat:@"%@%@",[DSDerivationPath walletBasedExtendedPublicKeyLocationStringForUniqueID:uniqueID],mutableString];
}

-(NSString*)walletBasedExtendedPublicKeyLocationString {
    if (_walletBasedExtendedPublicKeyLocationString) return _walletBasedExtendedPublicKeyLocationString;
    _walletBasedExtendedPublicKeyLocationString = [self walletBasedExtendedPublicKeyLocationStringForWalletUniqueID:self.wallet.uniqueID];
    return _walletBasedExtendedPublicKeyLocationString;
}

// MARK: - ECDSA Key Generation

//this is for upgrade purposes only
- (NSData *)deprecatedIncorrectExtendedPublicKeyFromSeed:(NSData *)seed
{
    if (! seed) return nil;
    if (![self length]) return nil; //there needs to be at least 1 length
    NSMutableData *mpk = [NSMutableData secureData];
    UInt512 I;
    
    HMAC(&I, SHA512, sizeof(UInt512), BIP32_SEED_KEY, strlen(BIP32_SEED_KEY), seed.bytes, seed.length);
    
    UInt256 secret = *(UInt256 *)&I, chain = *(UInt256 *)&I.u8[sizeof(UInt256)];
    
    [mpk appendBytes:[DSKey keyWithSecret:secret compressed:YES].hash160.u32 length:4];
    
    for (NSInteger i = 0;i<[self length];i++) {
        uint32_t derivation = (uint32_t)[self indexAtPosition:i];
        CKDpriv(&secret, &chain, derivation);
    }
    
    [mpk appendBytes:&chain length:sizeof(chain)];
    [mpk appendData:[DSKey keyWithSecret:secret compressed:YES].publicKey];
    
    return mpk;
}

// master public key format is: 4 byte parent fingerprint || 32 byte chain code || 33 byte compressed public key
- (NSData *)generateExtendedPublicKeyFromSeed:(NSData *)seed storeUnderWalletUniqueId:(NSString*)walletUniqueId
{
    if (! seed) return nil;
    if (![self length]) return nil; //there needs to be at least 1 length
    NSMutableData *mpk = [NSMutableData secureData];
    UInt512 I;
    
    HMAC(&I, SHA512, sizeof(UInt512), BIP32_SEED_KEY, strlen(BIP32_SEED_KEY), seed.bytes, seed.length);
    
    UInt256 secret = *(UInt256 *)&I, chain = *(UInt256 *)&I.u8[sizeof(UInt256)];
    
    for (NSInteger i = 0;i<[self length] - 1;i++) {
        uint32_t derivation = (uint32_t)[self indexAtPosition:i];
        CKDpriv(&secret, &chain, derivation);
    }
    [mpk appendBytes:[DSKey keyWithSecret:secret compressed:YES].hash160.u32 length:4];
    CKDpriv(&secret, &chain, (uint32_t)[self indexAtPosition:[self length] - 1]); // account 0H
    
    [mpk appendBytes:&chain length:sizeof(chain)];
    [mpk appendData:[DSKey keyWithSecret:secret compressed:YES].publicKey];
    
    _extendedPublicKey = mpk;
    if (walletUniqueId) {
        setKeychainData(mpk,[self walletBasedExtendedPublicKeyLocationStringForWalletUniqueID:walletUniqueId],NO);
    }
    
    return mpk;
}

- (NSData *)generatePublicKeyFromSeed:(NSData *)seed atIndexPath:(NSIndexPath*)indexPath storeUnderWalletUniqueId:(NSString*)walletUniqueId
{
    if (! seed) return nil;
    if (![self length]) return nil; //there needs to be at least 1 length
    NSMutableData *mpk = [NSMutableData secureData];
    UInt512 I;
    
    HMAC(&I, SHA512, sizeof(UInt512), BIP32_SEED_KEY, strlen(BIP32_SEED_KEY), seed.bytes, seed.length);
    
    UInt256 secret = *(UInt256 *)&I, chain = *(UInt256 *)&I.u8[sizeof(UInt256)];
    
    for (NSInteger i = 0;i<[self length] - 1;i++) {
        uint32_t derivation = (uint32_t)[self indexAtPosition:i];
        CKDpriv(&secret, &chain, derivation);
    }
    for (NSInteger i = 0;i<[indexPath length];i++) {
        uint32_t derivation = (uint32_t)[indexPath indexAtPosition:i];
        CKDpriv(&secret, &chain, derivation);
    }
    
    [mpk appendBytes:[DSKey keyWithSecret:secret compressed:YES].hash160.u32 length:4];
    CKDpriv(&secret, &chain, (uint32_t)[self indexAtPosition:[self length] - 1]); // account 0H
    
    [mpk appendBytes:&chain length:sizeof(chain)];
    [mpk appendData:[DSKey keyWithSecret:secret compressed:YES].publicKey];
    
    _extendedPublicKey = mpk;
    if (walletUniqueId) {
        setKeychainData(mpk,[self walletBasedExtendedPublicKeyLocationStringForWalletUniqueID:walletUniqueId],NO);
    }
    
    return mpk;
}

- (NSData *)generatePublicKeyAtIndexPath:(NSIndexPath*)indexPath
{
    if (self.signingAlgorithm == DSDerivationPathSigningAlgorith_ECDSA) {
        if (self.extendedPublicKey.length < 4 + sizeof(UInt256) + sizeof(DSECPoint)) return nil;
        
        UInt256 chain = *(const UInt256 *)((const uint8_t *)self.extendedPublicKey.bytes + 4);
        DSECPoint pubKey = *(const DSECPoint *)((const uint8_t *)self.extendedPublicKey.bytes + 36);
        
        for (NSInteger i = 0;i<[self length] - 1;i++) {
            uint32_t derivation = (uint32_t)[indexPath indexAtPosition:i];
            CKDpub(&pubKey, &chain, derivation);
        }
        
        return [NSData dataWithBytes:&pubKey length:sizeof(pubKey)];
    } else if (self.signingAlgorithm == DSDerivationPathSigningAlgorith_BLS) {
        DSBLSKey * extendedPublicKey = [DSBLSKey blsKeyWithExtendedPublicKeyData:self.extendedPublicKey onChain:self.chain];
        DSBLSKey * extendedPublicKeyAtIndexPath = [extendedPublicKey publicDeriveToPath:indexPath];
        return [NSData dataWithUInt384:extendedPublicKeyAtIndexPath.publicKey];
    }
    return nil;
}

- (DSKey *)privateKeyAtIndexPath:(NSIndexPath*)indexPath fromSeed:(NSData *)seed
{
    if (! seed || ! indexPath) return nil;
    if (indexPath.length == 0) return nil;
    
    UInt512 I;
    
    HMAC(&I, SHA512, sizeof(UInt512), BIP32_SEED_KEY, strlen(BIP32_SEED_KEY), seed.bytes, seed.length);
    
    UInt256 secret = *(UInt256 *)&I, chain = *(UInt256 *)&I.u8[sizeof(UInt256)];
    
    for (NSInteger i = 0;i<[self length];i++) {
        uint32_t derivation = (uint32_t)[self indexAtPosition:i];
        CKDpriv(&secret, &chain, derivation);
    }
    
    for (NSInteger i = 0;i<[indexPath length];i++) {
        uint32_t derivation = (uint32_t)[indexPath indexAtPosition:i];
        CKDpriv(&secret, &chain, derivation);
    }
    
    return [DSKey keyWithSecret:secret compressed:YES];
}

- (NSArray *)serializedPrivateKeysAtIndexPaths:(NSArray*)indexPaths fromSeed:(NSData *)seed
{
    if (! seed || ! indexPaths) return nil;
    if (indexPaths.count == 0) return @[];
    
    NSMutableArray *a = [NSMutableArray arrayWithCapacity:indexPaths.count];
    UInt512 I;
    
    HMAC(&I, SHA512, sizeof(UInt512), BIP32_SEED_KEY, strlen(BIP32_SEED_KEY), seed.bytes, seed.length);
    
    UInt256 secret = *(UInt256 *)&I, chain = *(UInt256 *)&I.u8[sizeof(UInt256)];
    uint8_t version;
    if ([self.chain isMainnet]) {
        version = DASH_PRIVKEY;
    } else {
        version = DASH_PRIVKEY_TEST;
    }
    
    for (NSInteger i = 0;i<[self length];i++) {
        uint32_t derivation = (uint32_t)[self indexAtPosition:i];
        CKDpriv(&secret, &chain, derivation);
    }
    
    
    for (NSIndexPath *indexPath in indexPaths) {
        NSMutableData *privKey = [NSMutableData secureDataWithCapacity:34];
        
        for (NSInteger i = 0;i<[indexPath length];i++) {
            uint32_t derivation = (uint32_t)[indexPath indexAtPosition:i];
            CKDpriv(&secret, &chain, derivation);
        }
        
        [privKey appendBytes:&version length:1];
        [privKey appendBytes:&secret length:sizeof(secret)];
        [privKey appendBytes:"\x01" length:1]; // specifies compressed pubkey format
        [a addObject:[NSString base58checkWithData:privKey]];
    }
    
    return a;
}

// MARK: - BLS Key Generation

// master public key format is: 4 byte parent fingerprint || 32 byte chain code || 33 byte compressed public key
- (NSData *)generateExtendedBLSPublicKeyFromSeed:(NSData *)seed storeUnderWalletUniqueId:(NSString*)walletUniqueId
{
    if (! seed) return nil;
    if (![self length]) return nil; //there needs to be at least 1 length
    NSMutableData *mpk = [NSMutableData secureData];
    
    DSBLSKey * topKey = [DSBLSKey blsKeyWithExtendedPrivateKeyFromSeed:seed onChain:self.chain];
    DSBLSKey * derivationPathExtendedKey = [topKey deriveToPath:self];
    
    _extendedPublicKey = derivationPathExtendedKey.extendedPublicKeyData;
    if (walletUniqueId) {
        setKeychainData(mpk,[self walletBasedExtendedPublicKeyLocationStringForWalletUniqueID:walletUniqueId],NO);
    }
    
    return mpk;
}

// MARK: - Authentication Key Generation

+ (NSString *)authPrivateKeyFromSeed:(NSData *)seed forChain:(DSChain*)chain
{
    if (! seed) return nil;
    
    UInt512 I;
    
    HMAC(&I, SHA512, sizeof(UInt512), BIP32_SEED_KEY, strlen(BIP32_SEED_KEY), seed.bytes, seed.length);
    
    UInt256 secret = *(UInt256 *)&I, chainHash = *(UInt256 *)&I.u8[sizeof(UInt256)];
    
    uint8_t version;
    if ([chain isMainnet]) {
        version = DASH_PRIVKEY;
    } else {
        version = DASH_PRIVKEY_TEST;
    }
    
    // path m/1H/0 (same as copay uses for bitauth)
    CKDpriv(&secret, &chainHash, 1 | BIP32_HARD);
    CKDpriv(&secret, &chainHash, 0);
    
    NSMutableData *privKey = [NSMutableData secureDataWithCapacity:34];
    
    [privKey appendBytes:&version length:1];
    [privKey appendBytes:&secret length:sizeof(secret)];
    [privKey appendBytes:"\x01" length:1]; // specifies compressed pubkey format
    return [NSString base58checkWithData:privKey];
}

// key used for BitID: https://github.com/bitid/bitid/blob/master/BIP_draft.md
+ (NSString *)bitIdPrivateKey:(uint32_t)n forURI:(NSString *)uri fromSeed:(NSData *)seed forChain:(DSChain*)chain
{
    NSUInteger len = [uri lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    NSMutableData *data = [NSMutableData dataWithCapacity:sizeof(n) + len];
    
    [data appendUInt32:n];
    [data appendBytes:uri.UTF8String length:len];
    
    UInt256 hash = data.SHA256;
    UInt512 I;
    
    HMAC(&I, SHA512, sizeof(UInt512), BIP32_SEED_KEY, strlen(BIP32_SEED_KEY), seed.bytes, seed.length);
    
    UInt256 secret = *(UInt256 *)&I, chainHash = *(UInt256 *)&I.u8[sizeof(UInt256)];
    uint8_t version;
    if ([chain isMainnet]) {
        version = DASH_PRIVKEY;
    } else {
        version = DASH_PRIVKEY_TEST;
    }
    
    CKDpriv(&secret, &chainHash, 13 | BIP32_HARD); // m/13H
    CKDpriv(&secret, &chainHash, CFSwapInt32LittleToHost(hash.u32[0]) | BIP32_HARD); // m/13H/aH
    CKDpriv(&secret, &chainHash, CFSwapInt32LittleToHost(hash.u32[1]) | BIP32_HARD); // m/13H/aH/bH
    CKDpriv(&secret, &chainHash, CFSwapInt32LittleToHost(hash.u32[2]) | BIP32_HARD); // m/13H/aH/bH/cH
    CKDpriv(&secret, &chainHash, CFSwapInt32LittleToHost(hash.u32[3]) | BIP32_HARD); // m/13H/aH/bH/cH/dH
    
    NSMutableData *privKey = [NSMutableData secureDataWithCapacity:34];
    
    [privKey appendBytes:&version length:1];
    [privKey appendBytes:&secret length:sizeof(secret)];
    [privKey appendBytes:"\x01" length:1]; // specifies compressed pubkey format
    return [NSString base58checkWithData:privKey];
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
            uint32_t derivation = (uint32_t)[self indexAtPosition:i];
            CKDpriv(&secret, &chain, derivation);
        }
        uint32_t fingerprint = [DSKey keyWithSecret:secret compressed:YES].hash160.u32[0];
        CKDpriv(&secret, &chain, (uint32_t)[self indexAtPosition:[self length] - 1]); // account 0H
        
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
    if (self.extendedPublicKey.length < 36) return nil;
    
    uint32_t fingerprint = CFSwapInt32BigToHost(*(const uint32_t *)self.extendedPublicKey.bytes);
    UInt256 chain = *(UInt256 *)((const uint8_t *)self.extendedPublicKey.bytes + 4);
    DSECPoint pubKey = *(DSECPoint *)((const uint8_t *)self.extendedPublicKey.bytes + 36);
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

