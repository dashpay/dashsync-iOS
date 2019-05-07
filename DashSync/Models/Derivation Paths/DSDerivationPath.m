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
#import "DSContactEntity+CoreDataClass.h"

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
    NSLog(@"c is %@, buf is %@",uint256_hex(*c),[NSData dataWithBytes:buf length:sizeof(DSECPoint) + sizeof(i)].hexString);
    HMAC(&I, SHA512, sizeof(UInt512), c, sizeof(*c), buf, sizeof(buf)); // I = HMAC-SHA512(c, k|P(k) || i)
    NSLog(@"c now is %@, I now is %@",uint256_hex(*c),uint512_hex(I));
    DSSecp256k1ModAdd(k, (UInt256 *)&I); // k = IL + k (mod n)
    *c = *(UInt256 *)&I.u8[sizeof(UInt256)]; // c = IR
    
    memset(buf, 0, sizeof(buf));
    memset(&I, 0, sizeof(I));
}

static void CKDpriv256(UInt256 *k, UInt256 *c, UInt256 i, BOOL hardened)
{
    BOOL iIs31Bits = uint256_is_31_bits(i);
    uint32_t smallI;
    uint32_t length = sizeof(DSECPoint) + (iIs31Bits?sizeof(smallI):(sizeof(i) + sizeof(hardened)));
    uint8_t buf[length];
    UInt512 I;
    
    if (hardened) {
        buf[0] = 0;
        *(UInt256 *)&buf[1] = *k;
    }
    else DSSecp256k1PointGen((DSECPoint *)buf, k);

    if (iIs31Bits) {
        //we are deriving a 31 bit integer
        smallI = i.u32[0];
        if (hardened) smallI |= BIP32_HARD;
        smallI = CFSwapInt32HostToBig(smallI);
        *(uint32_t *)&buf[sizeof(DSECPoint)] = smallI;
    } else {
        *(BOOL *)&buf[sizeof(DSECPoint)] = hardened;
        *(UInt256 *)&buf[sizeof(DSECPoint) + sizeof(hardened)] = i;
    }
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

static void CKDpub256(DSECPoint *K, UInt256 *c, UInt256 i, BOOL hardened)
{
    if (hardened) return; // can't derive private child key from public parent key
    BOOL iIs31Bits = uint256_is_31_bits(i);
    uint32_t smallI;
    uint32_t length = sizeof(*K) + (iIs31Bits?sizeof(smallI):(sizeof(i) + sizeof(hardened)));
    uint8_t buf[length];
    UInt512 I;
    
    *(DSECPoint *)buf = *K;
    
    if (iIs31Bits) {
        smallI = i.u32[0];
        if (hardened) smallI |= BIP32_HARD;
        smallI = CFSwapInt32HostToBig(smallI);
        
        *(uint32_t *)&buf[sizeof(*K)] = smallI;
    } else {
        *(BOOL *)&buf[sizeof(*K)] = hardened;
        *(UInt256 *)&buf[sizeof(*K)] = i;
    }
    
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
@property (nonatomic, strong) DSChain * chain;
@property (nonatomic, strong) NSNumber * depth;
@property (nonatomic, assign) NSNumber * child;
@property (nonatomic, strong) NSString * stringRepresentation;

@end

@implementation DSDerivationPath


// MARK: - Derivation Path initialization

+ (instancetype)masterBlockchainUserContactsDerivationPathForAccountNumber:(uint32_t)accountNumber onChain:(DSChain*)chain {
    NSUInteger coinType = (chain.chainType == DSChainType_MainNet)?5:1;
    UInt256 indexes[] = {uint256_from_long(FEATURE_PURPOSE),uint256_from_long(coinType), uint256_from_long(5), uint256_from_long(1), uint256_from_long(accountNumber)};
    //todo full uint256 derivation
    BOOL hardenedIndexes[] = {YES,YES,YES,YES,YES};
    return [self derivationPathWithIndexes:indexes hardened:hardenedIndexes length:5 type:DSDerivationPathType_PartialPath signingAlgorithm:DSDerivationPathSigningAlgorith_ECDSA reference:DSDerivationPathReference_ContactBasedFundsRoot onChain:chain];
}


+ (instancetype _Nullable)derivationPathWithIndexes:(const UInt256[_Nullable])indexes hardened:(const BOOL[_Nullable])hardenedIndexes length:(NSUInteger)length
                                               type:(DSDerivationPathType)type signingAlgorithm:(DSDerivationPathSigningAlgorith)signingAlgorithm reference:(DSDerivationPathReference)reference onChain:(DSChain*)chain {
    return [[self alloc] initWithIndexes:indexes hardened:hardenedIndexes length:length type:type signingAlgorithm:signingAlgorithm reference:reference onChain:chain];
}

+ (instancetype _Nullable)derivationPathWithSerializedExtendedPrivateKey:(NSString*)serializedExtendedPrivateKey fundsType:(DSDerivationPathType)fundsType signingAlgorithm:(DSDerivationPathSigningAlgorith)signingAlgorithm onChain:(DSChain*)chain {
    NSData * extendedPrivateKey = [self deserializedExtendedPrivateKey:serializedExtendedPrivateKey onChain:chain];
    UInt256 indexes[] = {};
    BOOL hardenedIndexes[] = {};
    DSDerivationPath * derivationPath = [[self alloc] initWithIndexes:indexes hardened:hardenedIndexes length:0 type:fundsType signingAlgorithm:DSDerivationPathSigningAlgorith_ECDSA reference:DSDerivationPathReference_Unknown onChain:chain];
    derivationPath.extendedPublicKey = [DSECDSAKey keyWithSecret:*(UInt256*)extendedPrivateKey.bytes compressed:YES].publicKeyData;
    [derivationPath standaloneSaveExtendedPublicKeyToKeyChain];
    return derivationPath;
}

+ (instancetype _Nullable)derivationPathWithSerializedExtendedPublicKey:(NSString*)serializedExtendedPublicKey onChain:(DSChain*)chain {
    uint8_t depth = 0;
    uint32_t child = 0;
    NSData * extendedPublicKey = [self deserializedExtendedPublicKey:serializedExtendedPublicKey onChain:chain rDepth:&depth rChild:&child];
    UInt256 indexes[] = {};
    BOOL hardenedIndexes[] = {};
    DSDerivationPath * derivationPath = [[self alloc] initWithIndexes:indexes hardened:hardenedIndexes length:0 type:DSDerivationPathType_ViewOnlyFunds signingAlgorithm:DSDerivationPathSigningAlgorith_ECDSA reference:DSDerivationPathReference_Unknown onChain:chain]; //we are going to assume this is only ecdsa for now
    derivationPath.extendedPublicKey = extendedPublicKey;
    derivationPath.depth = @(depth);
    derivationPath.child = @(child);
    [derivationPath standaloneSaveExtendedPublicKeyToKeyChain];
    [derivationPath loadAddresses];
    return derivationPath;
}

- (instancetype _Nullable)initWithExtendedPublicKeyIdentifier:(NSString* _Nonnull)extendedPublicKeyIdentifier onChain:(DSChain* _Nonnull)chain {
    UInt256 indexes[] = {};
    BOOL hardenedIndexes[] = {};
    if (!(self = [self initWithIndexes:indexes hardened:hardenedIndexes length:0 type:DSDerivationPathType_ViewOnlyFunds signingAlgorithm:DSDerivationPathSigningAlgorith_ECDSA reference:DSDerivationPathReference_Unknown onChain:chain])) return nil;
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

- (instancetype)initWithIndexes:(const UInt256[_Nullable])indexes hardened:(const BOOL[_Nullable])hardenedIndexes length:(NSUInteger)length
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

-(NSData*)extendedPublicKey {
    if (!_extendedPublicKey) {
        if (self.wallet && self.length) {
            _extendedPublicKey = getKeychainData([self walletBasedExtendedPublicKeyLocationString], nil);
            NSAssert(_extendedPublicKey, @"extended public key not set");
        } else {
            _extendedPublicKey = getKeychainData([self standaloneExtendedPublicKeyLocationString], nil);
            NSAssert(_extendedPublicKey, @"extended public key not set");
        }
    }
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

- (void)registerTransactionAddress:(NSString * _Nonnull)address {
    if ([self containsAddress:address]) {
        if (![self.mUsedAddresses containsObject:address]) {
            [self.mUsedAddresses addObject:address];
        }
    }
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
                [[DSContactEntity context] performBlockAndWait:^{
                    DSContactEntity * contactEntity = [DSContactEntity anyObjectMatching:@"associatedBlockchainUserRegistrationHash == %@",uint256_data(index)];
                    if (contactEntity) {
                        [mutableString appendFormat:@"/%@%@",contactEntity.username,[self isHardenedAtPosition:i]?@"'":@""];
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
        case DSDerivationPathReference_BlockchainUsers:
            return @"Blockchain Users";
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
    return [NSData dataWithUInt256:[[self extendedPublicKey] SHA256]].shortHexString;
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
    return [NSString stringWithFormat:@"%@%@%@",[DSDerivationPath walletBasedExtendedPublicKeyLocationStringForUniqueID:uniqueID],self.signingAlgorithm==DSDerivationPathSigningAlgorith_BLS?@"_BLS_":@"",mutableString];
}

-(NSString*)walletBasedExtendedPublicKeyLocationString {
    if (_walletBasedExtendedPublicKeyLocationString) return _walletBasedExtendedPublicKeyLocationString;
    _walletBasedExtendedPublicKeyLocationString = [self walletBasedExtendedPublicKeyLocationStringForWalletUniqueID:self.wallet.uniqueID];
    return _walletBasedExtendedPublicKeyLocationString;
}

// MARK: - Key Generation

- (NSData *)generateExtendedPublicKeyFromSeed:(NSData *)seed storeUnderWalletUniqueId:(NSString*)walletUniqueId
{
    if (! seed) return nil;
    if (![self length]) return nil; //there needs to be at least 1 length
    if (self.signingAlgorithm == DSDerivationPathSigningAlgorith_ECDSA) {
        return [self generateExtendedECDSAPublicKeyFromSeed:seed storeUnderWalletUniqueId:walletUniqueId];
    } else if (self.signingAlgorithm == DSDerivationPathSigningAlgorith_BLS) {
        return [self generateExtendedBLSPublicKeyFromSeed:seed storeUnderWalletUniqueId:walletUniqueId];
    }
    return nil;
}

- (NSData *)generateExtendedPublicKeyFromParentDerivationPath:(DSDerivationPath*)parentDerivationPath storeUnderWalletUniqueId:(NSString*)walletUniqueId {
    if (![self length]) return nil; //there needs to be at least 1 length
    if (self.signingAlgorithm == DSDerivationPathSigningAlgorith_ECDSA) {
        return [self generateExtendedECDSAPublicKeyFromParentDerivationPath:parentDerivationPath storeUnderWalletUniqueId:walletUniqueId];
    } else if (self.signingAlgorithm == DSDerivationPathSigningAlgorith_BLS) {
        NSAssert(FALSE, @"Not yet implemented");
        return nil; //todo
    }
    return nil;
}

- (DSKey *)privateKeyForKnownAddress:(NSString*)address fromSeed:(NSData *)seed {
    NSIndexPath * indexPathForAddress = [self indexPathForKnownAddress:address];
    return [self privateKeyAtIndexPath:indexPathForAddress fromSeed:seed];
}

- (DSKey *)privateKeyAtIndexPath:(NSIndexPath*)indexPath fromSeed:(NSData *)seed {
    if (! seed) return nil;
    if (![self length]) return nil; //there needs to be at least 1 length
    if (self.signingAlgorithm == DSDerivationPathSigningAlgorith_ECDSA) {
        return [self privateECDSAKeyAtIndexPath:indexPath fromSeed:seed];
    } else if (self.signingAlgorithm == DSDerivationPathSigningAlgorith_BLS) {
        return [self privateBLSKeyAtIndexPath:indexPath fromSeed:seed];
    }
    return nil;
}

- (NSData *)publicKeyDataAtIndexPath:(NSIndexPath*)indexPath
{
    if (self.signingAlgorithm == DSDerivationPathSigningAlgorith_ECDSA) {
        if (self.extendedPublicKey.length < 4 + sizeof(UInt256) + sizeof(DSECPoint)) return nil;
        
        UInt256 chain = *(const UInt256 *)((const uint8_t *)self.extendedPublicKey.bytes + 4);
        DSECPoint pubKey = *(const DSECPoint *)((const uint8_t *)self.extendedPublicKey.bytes + 36);
        for (NSInteger i = 0;i<[indexPath length];i++) {
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


- (NSArray *)serializedPrivateKeysAtIndexPaths:(NSArray*)indexPaths fromSeed:(NSData *)seed {
    if (self.signingAlgorithm == DSDerivationPathSigningAlgorith_ECDSA) {
        return [self serializedECDSAPrivateKeysAtIndexPaths:indexPaths fromSeed:seed];
    } else if (self.signingAlgorithm == DSDerivationPathSigningAlgorith_BLS) {
        return [self serializedBLSPrivateKeysAtIndexPaths:indexPaths fromSeed:seed];
    }
    return nil;
}


// MARK: - ECDSA Key Generation


+ (NSString *)serializedPrivateMasterFromSeed:(NSData *)seed forChain:(DSChain*)chain
{
    if (! seed) return nil;
    
    UInt512 I;
    
    HMAC(&I, SHA512, sizeof(UInt512), BIP32_SEED_KEY, strlen(BIP32_SEED_KEY), seed.bytes, seed.length);
    
    UInt256 secret = *(UInt256 *)&I, lChain = *(UInt256 *)&I.u8[sizeof(UInt256)];
    
    return serialize(0, 0, 0, lChain, [NSData dataWithBytes:&secret length:sizeof(secret)],[chain isMainnet]);
}


//this is for upgrade purposes only
- (NSData *)deprecatedIncorrectExtendedPublicKeyFromSeed:(NSData *)seed
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
    
    return mpk;
}

// master public key format is: 4 byte parent fingerprint || 32 byte chain code || 33 byte compressed public key
- (NSData *)generateExtendedECDSAPublicKeyFromSeed:(NSData *)seed storeUnderWalletUniqueId:(NSString*)walletUniqueId
{
    if (! seed) return nil;
    if (![self length]) return nil; //there needs to be at least 1 length
    NSMutableData *mpk = [NSMutableData secureData];
    UInt512 I;
    
    HMAC(&I, SHA512, sizeof(UInt512), BIP32_SEED_KEY, strlen(BIP32_SEED_KEY), seed.bytes, seed.length);
    
    UInt256 secret = *(UInt256 *)&I, chain = *(UInt256 *)&I.u8[sizeof(UInt256)];
    
    for (NSInteger i = 0;i<[self length] - 1;i++) {
        UInt256 derivation = [self indexAtPosition:i];
        BOOL isHardenedAtPosition = [self isHardenedAtPosition:i];
        CKDpriv256(&secret, &chain, derivation,isHardenedAtPosition);
    }
    [mpk appendBytes:[DSECDSAKey keyWithSecret:secret compressed:YES].hash160.u32 length:4];
    CKDpriv256(&secret, &chain, [self indexAtPosition:[self length] - 1],[self isHardenedAtPosition:[self length] - 1]); // account 0H
    
    [mpk appendBytes:&chain length:sizeof(chain)];
    [mpk appendData:[DSECDSAKey keyWithSecret:secret compressed:YES].publicKeyData];
    
    _extendedPublicKey = mpk;
    if (walletUniqueId) {
        setKeychainData(mpk,[self walletBasedExtendedPublicKeyLocationStringForWalletUniqueID:walletUniqueId],NO);
    }
    
    return mpk;
}

// master public key format is: 4 byte parent fingerprint || 32 byte chain code || 33 byte compressed public key
- (NSData *)generateExtendedECDSAPublicKeyFromParentDerivationPath:(DSDerivationPath *)parentDerivationPath storeUnderWalletUniqueId:(NSString*)walletUniqueId
{
    if (self.length <= parentDerivationPath.length) return nil; // we need to be longer
    if (!parentDerivationPath.extendedPublicKey) return nil; //parent derivation path
    if (![self length]) return nil; //there needs to be at least 1 length
    NSMutableData *mpk = [NSMutableData secureData];
    
    UInt256 chain = *(const UInt256 *)((const uint8_t *)parentDerivationPath.extendedPublicKey.bytes + 4);
    DSECPoint pubKey = *(const DSECPoint *)((const uint8_t *)parentDerivationPath.extendedPublicKey.bytes + 36);
    for (NSInteger i = 0;i<[self length] - 1;i++) {
        if (i < parentDerivationPath.length) {
            if (!uint256_eq([parentDerivationPath indexAtPosition:i],[self indexAtPosition:i])) return nil;
        } else {
            CKDpub256(&pubKey, &chain, [self indexAtPosition:i],[self isHardenedAtPosition:i]);
        }
    }
    NSData * publicKeyParentData = [NSData dataWithBytes:&pubKey length:sizeof(pubKey)];
    
    [mpk appendBytes:publicKeyParentData.hash160.u32 length:4];
    CKDpub256(&pubKey, &chain, [self indexAtPosition:[self length] - 1],[self isHardenedAtPosition:[self length] - 1]);
    [mpk appendBytes:&chain length:sizeof(chain)];
    
    NSData * publicKeyData = [NSData dataWithBytes:&pubKey length:sizeof(pubKey)];
    
    [mpk appendData:publicKeyData];
    
    _extendedPublicKey = mpk;
    if (walletUniqueId) {
        setKeychainData(mpk,[self walletBasedExtendedPublicKeyLocationStringForWalletUniqueID:walletUniqueId],NO);
    }
    
    return mpk;
}

-(BOOL)storeExtendedPublicKeyUnderWalletUniqueId:(NSString*)walletUniqueId {
    if (!_extendedPublicKey) return FALSE;
    NSParameterAssert(walletUniqueId);
    setKeychainData(_extendedPublicKey,[self walletBasedExtendedPublicKeyLocationStringForWalletUniqueID:walletUniqueId],NO);
    return TRUE;
}

- (NSData *)generateECDSAPublicKeyFromSeed:(NSData *)seed atIndexPath:(NSIndexPath*)indexPath storeUnderWalletUniqueId:(NSString*)walletUniqueId
{
    if (! seed) return nil;
    if (![self length]) return nil; //there needs to be at least 1 length
    NSMutableData *mpk = [NSMutableData secureData];
    UInt512 I;
    
    HMAC(&I, SHA512, sizeof(UInt512), BIP32_SEED_KEY, strlen(BIP32_SEED_KEY), seed.bytes, seed.length);
    
    UInt256 secret = *(UInt256 *)&I, chain = *(UInt256 *)&I.u8[sizeof(UInt256)];
    
    for (NSInteger i = 0;i<[self length];i++) {
        CKDpriv256(&secret, &chain, [self indexAtPosition:i],[self isHardenedAtPosition:i]);
    }
    for (NSInteger i = 0;i<[indexPath length] - 1;i++) {
        uint32_t derivation = (uint32_t)[indexPath indexAtPosition:i];
        CKDpriv(&secret, &chain, derivation);
    }
    
    [mpk appendBytes:[DSECDSAKey keyWithSecret:secret compressed:YES].hash160.u32 length:4];
    CKDpriv(&secret, &chain, (uint32_t)[indexPath indexAtPosition:[indexPath length] - 1]); // account 0H
    
    [mpk appendBytes:&chain length:sizeof(chain)];
    [mpk appendData:[DSECDSAKey keyWithSecret:secret compressed:YES].publicKeyData];
    
    return mpk;
}

- (DSECDSAKey *)privateECDSAKeyAtIndexPath:(NSIndexPath*)indexPath fromSeed:(NSData *)seed
{
    if (! seed || ! indexPath) return nil;
    if (indexPath.length == 0) return nil;
    
    UInt512 I;
    
    HMAC(&I, SHA512, sizeof(UInt512), BIP32_SEED_KEY, strlen(BIP32_SEED_KEY), seed.bytes, seed.length);
    
    UInt256 secret = *(UInt256 *)&I, chain = *(UInt256 *)&I.u8[sizeof(UInt256)];
    
    for (NSInteger i = 0;i<[self length];i++) {
        CKDpriv256(&secret, &chain, [self indexAtPosition:i],[self isHardenedAtPosition:i]);
    }
    
    for (NSInteger i = 0;i<[indexPath length];i++) {
        uint32_t derivation = (uint32_t)[indexPath indexAtPosition:i];
        CKDpriv(&secret, &chain, derivation);
    }
    
    return [DSECDSAKey keyWithSecret:secret compressed:YES];
}

- (NSArray *)serializedECDSAPrivateKeysAtIndexPaths:(NSArray*)indexPaths fromSeed:(NSData *)seed
{
    if (! seed || ! indexPaths) return nil;
    if (indexPaths.count == 0) return @[];
    
    NSMutableArray *a = [NSMutableArray arrayWithCapacity:indexPaths.count];
    UInt512 I;
    
    HMAC(&I, SHA512, sizeof(UInt512), BIP32_SEED_KEY, strlen(BIP32_SEED_KEY), seed.bytes, seed.length);
    
    UInt256 secretRoot = *(UInt256 *)&I, chainRoot = *(UInt256 *)&I.u8[sizeof(UInt256)];
    uint8_t version;
    if ([self.chain isMainnet]) {
        version = DASH_PRIVKEY;
    } else {
        version = DASH_PRIVKEY_TEST;
    }
    
    for (NSInteger i = 0;i<[self length];i++) {
//        uint32_t index = [self isHardenedAtPosition:i]?[self indexAtPosition:i].u32[7] | BIP32_HARD:[self indexAtPosition:i].u32[7];
//        CKDpriv(&secretRoot, &chainRoot, index);
        CKDpriv256(&secretRoot, &chainRoot, [self indexAtPosition:i],[self isHardenedAtPosition:i]);
    }

    
    for (NSIndexPath *indexPath in indexPaths) {
        
        UInt256 secret = secretRoot;
        UInt256 chain = chainRoot;
        
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
    DSBLSKey * topKey = [DSBLSKey blsKeyWithExtendedPrivateKeyFromSeed:seed onChain:self.chain];
    DSBLSKey * derivationPathExtendedKey = [topKey deriveToPath:[self baseIndexPath]];
    
    _extendedPublicKey = derivationPathExtendedKey.extendedPublicKeyData;
    if (walletUniqueId) {
        setKeychainData(_extendedPublicKey,[self walletBasedExtendedPublicKeyLocationStringForWalletUniqueID:walletUniqueId],NO);
    }
    
    return _extendedPublicKey;
}

- (DSBLSKey *)privateBLSKeyAtIndexPath:(NSIndexPath*)indexPath fromSeed:(NSData *)seed
{
    if (! seed) return nil;
    if (![self length]) return nil; //there needs to be at least 1 length
    DSBLSKey * topKey = [DSBLSKey blsKeyWithExtendedPrivateKeyFromSeed:seed onChain:self.chain];
    DSBLSKey * derivationPathExtendedKey = [topKey deriveToPath:[self baseIndexPath]];
    DSBLSKey * privateKey = [derivationPathExtendedKey deriveToPath:indexPath];
    
    return privateKey;
}

- (NSArray *)serializedBLSPrivateKeysAtIndexPaths:(NSArray*)indexPaths fromSeed:(NSData *)seed
{
    if (! seed || ! indexPaths) return nil;
    if (indexPaths.count == 0) return @[];
    
    NSMutableArray *a = [NSMutableArray arrayWithCapacity:indexPaths.count];
    uint8_t version;
    if ([self.chain isMainnet]) {
        version = DASH_PRIVKEY;
    } else {
        version = DASH_PRIVKEY_TEST;
    }
    DSBLSKey * topKey = [DSBLSKey blsKeyWithExtendedPrivateKeyFromSeed:seed onChain:self.chain];
    DSBLSKey * derivationPathExtendedKey = [topKey deriveToPath:[self baseIndexPath]];
    
    for (NSIndexPath *indexPath in indexPaths) {
        NSMutableData *privKey = [NSMutableData secureDataWithCapacity:34];
        DSBLSKey * privateKey = [derivationPathExtendedKey deriveToPath:indexPath];
        [privKey appendBytes:&version length:1];
        [privKey appendUInt256:[privateKey secretKey]];
        [privKey appendBytes:"\x01" length:1]; // specifies compressed pubkey format
        [a addObject:[NSString base58checkWithData:privKey]];
    }
    
    return a;
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

