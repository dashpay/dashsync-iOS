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

#import "DSAccount.h"
#import "DSBlockchainIdentityEntity+CoreDataClass.h"
#import "DSBlockchainIdentityUsernameEntity+CoreDataClass.h"
#import "DSChain+Params.h"
#import "DSChainManager.h"
#import "DSDashpayUserEntity+CoreDataClass.h"
#import "DSDerivationPathFactory.h"
#import "DSDerivationPath+Protected.h"
#import "DSFriendRequestEntity+CoreDataClass.h"
#import "DSIncomingFundsDerivationPath.h"
#import "DSWallet+Identity.h"
#import "NSIndexPath+FFI.h"
#import "NSManagedObject+Sugar.h"
#import "NSMutableData+Dash.h"

#define DERIVATION_PATH_STANDALONE_INFO_TERMINAL_INDEX @"DP_SI_T_INDEX"
#define DERIVATION_PATH_STANDALONE_INFO_TERMINAL_HARDENED @"DP_SI_T_HARDENED"
#define DERIVATION_PATH_STANDALONE_INFO_DEPTH @"DP_SI_DEPTH"

@interface DSDerivationPath ()

@property (nonatomic, copy) NSString *walletBasedExtendedPublicKeyLocationString;
@property (nonatomic, copy) NSString *walletBasedExtendedPrivateKeyLocationString;
@property (nonatomic, weak) DSAccount *account;
@property (nonatomic, strong) DSChain *chain;
@property (nonatomic, strong) NSNumber *depth;
@property (nonatomic, strong) NSString *stringRepresentation;

@end

@implementation DSDerivationPath

// MARK: - Derivation Path initialization

+ (instancetype)masterIdentityContactsDerivationPathForAccountNumber:(uint32_t)accountNumber
                                                                       onChain:(DSChain *)chain {
    UInt256 indexes[] = {uint256_from_long(FEATURE_PURPOSE), uint256_from_long(chain.coinType), uint256_from_long(FEATURE_PURPOSE_DASHPAY), uint256_from_long(accountNumber)};
    //todo full uint256 derivation
    BOOL hardenedIndexes[] = {YES, YES, YES, YES};
    
    dash_spv_crypto_keys_key_KeyKind *key_kind = dash_spv_crypto_keys_key_KeyKind_ECDSA_ctor();
    return [self derivationPathWithIndexes:indexes
                                  hardened:hardenedIndexes
                                    length:4
                                      type:DSDerivationPathType_PartialPath
                          signingAlgorithm:key_kind
                                 reference:DSDerivationPathReference_ContactBasedFundsRoot
                                   onChain:chain];
}


+ (instancetype _Nullable)derivationPathWithIndexes:(const UInt256[_Nullable])indexes
                                           hardened:(const BOOL[_Nullable])hardenedIndexes
                                             length:(NSUInteger)length
                                               type:(DSDerivationPathType)type
                                   signingAlgorithm:(dash_spv_crypto_keys_key_KeyKind *)signingAlgorithm
                                          reference:(DSDerivationPathReference)reference
                                            onChain:(DSChain *)chain {
    return [[self alloc] initWithIndexes:indexes
                                hardened:hardenedIndexes
                                  length:length
                                    type:type
                        signingAlgorithm:signingAlgorithm
                               reference:reference
                                 onChain:chain];
}

//+ (instancetype _Nullable)derivationPathWithSerializedExtendedPrivateKey:(NSString *)serializedExtendedPrivateKey
//                                                               fundsType:(DSDerivationPathType)fundsType
//                                                        signingAlgorithm:(dash_spv_crypto_keys_key_KeyKind *)signingAlgorithm
//                                                                 onChain:(DSChain *)chain {
//    UInt256 indexes[] = {};
//    BOOL hardenedIndexes[] = {};
//    
//    
//    dash_spv_crypto_keys_key_KeyKind *key_kind = dash_spv_crypto_keys_key_KeyKind_ECDSA_ctor();
//    DSDerivationPath *derivationPath = [[self alloc] initWithIndexes:indexes
//                                                            hardened:hardenedIndexes
//                                                              length:0
//                                                                type:fundsType
//                                                    signingAlgorithm:key_kind
//                                                           reference:DSDerivationPathReference_Unknown
//                                                             onChain:chain];
//    @autoreleasepool {
//        uint8_t depth;
//        uint32_t fingerprint;
//        UInt256 child;
//        BOOL hardened;
//        UInt256 chainHash;
//        NSData *privkey = nil;
//        NSMutableData *masterPrivateKey = [NSMutableData secureData];
//        BOOL valid = deserialize(serializedExtendedPrivateKey, &depth, &fingerprint, &hardened, &child, &chainHash, &privkey, [chain isMainnet]);
//        if (!valid) return nil;
//        [masterPrivateKey appendUInt32:fingerprint];
//        [masterPrivateKey appendBytes:&chainHash length:32];
//        [masterPrivateKey appendData:privkey];
//        SLICE *slice = slice_ctor(masterPrivateKey);
//        derivationPath.extendedPublicKey = dash_spv_crypto_keys_key_KeyKind_key_with_private_key_data(key_kind, slice);
//    }
//    [derivationPath standaloneSaveExtendedPublicKeyToKeyChain];
//    return derivationPath;
//}

+ (instancetype _Nullable)derivationPathWithSerializedExtendedPublicKey:(NSString *)serializedExtendedPublicKey
                                                                onChain:(DSChain *)chain {
    uint8_t depth = 0;
    BOOL terminalHardened;
    UInt256 terminalIndex = UINT256_ZERO;
    NSData *extendedPublicKeyData = [DSDerivationPathFactory deserializedExtendedPublicKey:serializedExtendedPublicKey
                                                                                   onChain:chain
                                                                                    rDepth:&depth
                                                                         rTerminalHardened:&terminalHardened
                                                                            rTerminalIndex:&terminalIndex];
    UInt256 indexes[] = {terminalIndex};
    BOOL hardenedIndexes[] = {terminalHardened};
    dash_spv_crypto_keys_key_KeyKind *key_kind = dash_spv_crypto_keys_key_KeyKind_ECDSA_ctor();
    DSDerivationPath *derivationPath = [[self alloc] initWithIndexes:indexes
                                                            hardened:hardenedIndexes
                                                              length:0
                                                                type:DSDerivationPathType_ViewOnlyFunds
                                                    signingAlgorithm:key_kind
                                                           reference:DSDerivationPathReference_Unknown
                                                             onChain:chain]; //we are going to assume this is only ecdsa for now
    SLICE *slice = slice_ctor(extendedPublicKeyData);
    DMaybeOpaqueKey *result = dash_spv_crypto_keys_key_KeyKind_key_init_with_extended_public_key_data(key_kind, slice);
    derivationPath.extendedPublicKey = result;
    derivationPath.depth = @(depth);
    [derivationPath standaloneSaveExtendedPublicKeyToKeyChain];
    [derivationPath loadAddresses];
    return derivationPath;
}

- (instancetype _Nullable)initWithExtendedPublicKeyIdentifier:(NSString *_Nonnull)extendedPublicKeyIdentifier
                                                      onChain:(DSChain *_Nonnull)chain {
    NSError *error = nil;
    NSDictionary *infoDictionary = getKeychainDict([DSDerivationPathFactory standaloneInfoDictionaryLocationStringForUniqueID:extendedPublicKeyIdentifier], @[[NSString class], [NSNumber class]], &error);
    if (error) return nil;

    UInt256 terminalIndex = [((NSData *)infoDictionary[DERIVATION_PATH_STANDALONE_INFO_TERMINAL_INDEX]) UInt256];
    BOOL terminalHardened = [((NSNumber *)infoDictionary[DERIVATION_PATH_STANDALONE_INFO_TERMINAL_HARDENED]) boolValue];
    UInt256 indexes[] = {terminalIndex};
    BOOL hardenedIndexes[] = {terminalHardened};
    dash_spv_crypto_keys_key_KeyKind *key_kind = dash_spv_crypto_keys_key_KeyKind_ECDSA_ctor();
    if (!(self = [self initWithIndexes:indexes
                              hardened:hardenedIndexes
                                length:0
                                  type:DSDerivationPathType_ViewOnlyFunds
                      signingAlgorithm:key_kind
                             reference:DSDerivationPathReference_Unknown
                               onChain:chain])) return nil;
    _walletBasedExtendedPublicKeyLocationString = extendedPublicKeyIdentifier;
    NSData *data = getKeychainData([DSDerivationPathFactory standaloneExtendedPublicKeyLocationStringForUniqueID:extendedPublicKeyIdentifier], &error);
    if (error) return nil;
    SLICE *slice = slice_ctor(data);
    DMaybeOpaqueKey *result = dash_spv_crypto_keys_key_KeyKind_key_with_extended_public_key_data(key_kind, slice);
    _extendedPublicKey = result;
    _depth = infoDictionary[DERIVATION_PATH_STANDALONE_INFO_DEPTH];
    [self loadAddresses];
    return self;
}

- (instancetype)initWithIndexes:(const UInt256[_Nullable])indexes
                       hardened:(const BOOL[_Nullable])hardenedIndexes
                         length:(NSUInteger)length
                           type:(DSDerivationPathType)type
               signingAlgorithm:(dash_spv_crypto_keys_key_KeyKind *)signingAlgorithm
                      reference:(DSDerivationPathReference)reference
                        onChain:(DSChain *)chain {
    if (length) {
        if (!(self = [super initWithIndexes:indexes length:length])) return nil;
    } else {
        if (!(self = [super init])) return nil;
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

- (void)dealloc {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    if (_hardenedIndexes != NULL) {
        free(_hardenedIndexes);
    }
    if (_extendedPublicKey != NULL) {
        DMaybeOpaqueKeyDtor(_extendedPublicKey);
    }
    if (_signingAlgorithm != NULL)
        DKeyKindDtor(_signingAlgorithm);

}

// MARK: - Hardening

- (BOOL)isHardenedAtPosition:(NSUInteger)position {
    if (position >= self.length) {
        return NO;
    }
    return _hardenedIndexes[position];
}

- (UInt256)terminalIndex {
    if (![self length]) return UINT256_ZERO;
    return [self indexAtPosition:[self length] - 1];
}

- (BOOL)terminalHardened {
    if (![self length]) return NO;
    return [self isHardenedAtPosition:[self length] - 1];
}

- (NSIndexPath *)baseIndexPath {
    NSUInteger indexes[self.length];
    for (NSUInteger position = 0; position < self.length; position++) {
        if ([self isHardenedAtPosition:position]) {
            indexes[position] = [self indexAtPosition:position].u64[0] | BIP32_HARD;
        } else {
            indexes[position] = [self indexAtPosition:position].u64[0];
        }
    }
    return [NSIndexPath indexPathWithIndexes:indexes length:self.length];
}

// MARK: - Account

- (NSUInteger)accountNumber {
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

- (DSWallet *)wallet {
    if (_wallet) return _wallet;
    if (_account.wallet) return _account.wallet;
    return nil;
}

- (DSChain *)chain {
    if (_chain) return _chain;
    return self.chain;
}

- (BOOL)hasExtendedPublicKey {
    if (_extendedPublicKey) return YES;
    if (self.wallet && (self.length || self.reference == DSDerivationPathReference_Root)) {
        return hasKeychainData([self walletBasedExtendedPublicKeyLocationString], nil);
    } else {
        return hasKeychainData([self standaloneExtendedPublicKeyLocationString], nil);
    }
    return NO;
}

- (NSData *)extendedPublicKeyData {
    if (self.extendedPublicKey != NULL && self.extendedPublicKey->ok != NULL)
        return [DSKeyManager extendedPublicKeyData:self.extendedPublicKey->ok];
    else
        return nil;
}

- (DMaybeOpaqueKey *)extendedPublicKey {
    if (!_extendedPublicKey) {
        if (self.wallet && (self.length || self.reference == DSDerivationPathReference_Root)) {
            NSData *extendedPublicKeyData = getKeychainData([self walletBasedExtendedPublicKeyLocationString], nil);
            if (extendedPublicKeyData) {
                _extendedPublicKey = dash_spv_crypto_keys_key_KeyKind_key_with_extended_public_key_data(self.signingAlgorithm, slice_ctor(extendedPublicKeyData));
            }
        } else {
            NSData *extendedPublicKeyData = getKeychainData([self standaloneExtendedPublicKeyLocationString], nil);
            _extendedPublicKey = dash_spv_crypto_keys_key_KeyKind_key_with_extended_public_key_data(self.signingAlgorithm, slice_ctor(extendedPublicKeyData));
        }
    }
    return _extendedPublicKey;
}

- (void)standaloneSaveExtendedPublicKeyToKeyChain {
    if (!_extendedPublicKey) return;
    setKeychainData([self extendedPublicKeyData], [self standaloneExtendedPublicKeyLocationString], NO);

    NSString *dictionaryLocationString = self.standaloneExtendedPublicKeyUniqueID ? [DSDerivationPathFactory standaloneInfoDictionaryLocationStringForUniqueID:_standaloneExtendedPublicKeyUniqueID] : nil;

    setKeychainDict(@{DERIVATION_PATH_STANDALONE_INFO_TERMINAL_INDEX: uint256_data([self terminalIndex]), DERIVATION_PATH_STANDALONE_INFO_TERMINAL_HARDENED: @([self terminalHardened]), DERIVATION_PATH_STANDALONE_INFO_DEPTH: self.depth}, dictionaryLocationString, NO);
    [self.managedObjectContext performBlockAndWait:^{
        [DSDerivationPathEntity derivationPathEntityMatchingDerivationPath:self inContext:self.managedObjectContext];
    }];
}

// MARK: - Derivation Path Addresses

- (NSIndexPath *)indexPathForKnownAddress:(NSString *)address {
    NSAssert(FALSE, @"This must be implemented in subclasses");
    return nil;
}

// gets an address at an index path
- (NSString *)addressAtIndexPath:(NSIndexPath *)indexPath {
    NSData *pubKey = [self publicKeyDataAtIndexPath:indexPath];
    return [DSKeyManager NSStringFrom:dash_spv_crypto_util_address_address_with_public_key_data(slice_ctor(pubKey), self.chain.chainType)];
}

// true if the address is controlled by the wallet
- (BOOL)containsAddress:(NSString *)address {
    return address && [self.mAllAddresses containsObject:address];
}
- (BOOL)containsAddressHash:(UInt160)hash {
    NSString *address = [DSKeyManager addressFromHash160:hash forChain:self.chain];
    return [self containsAddress:address];
}

// true if the address was previously used as an input or output in any wallet transaction
- (BOOL)addressIsUsed:(NSString *)address {
    return address && [self.mUsedAddresses containsObject:address];
}

- (BOOL)registerTransactionAddress:(NSString *_Nonnull)address {
    if ([self containsAddress:address]) {
        if (![self.mUsedAddresses containsObject:address])
            [self.mUsedAddresses addObject:address];
        return TRUE;
    }
    return FALSE;
}

- (NSSet *)allAddresses {
    return [self.mAllAddresses copy];
}


- (NSSet *)usedAddresses {
    return [self.mUsedAddresses copy];
}

- (void)loadAddresses {
}

- (void)reloadAddresses {
}

- (NSNumber *)depth {
    if (_depth != nil)
        return _depth;
    else
        return @(self.length);
}

- (BOOL)isDerivationPathEqual:(id)object {
    return [super isEqual:object];
}

- (BOOL)isEqual:(id)object {
    return [self.standaloneExtendedPublicKeyUniqueID isEqualToString:((DSDerivationPath *)object).standaloneExtendedPublicKeyUniqueID];
}

- (NSUInteger)hash {
    return [self.standaloneExtendedPublicKeyUniqueID hash];
}


- (NSString *)stringRepresentation {
    if (_stringRepresentation) return _stringRepresentation;
    NSMutableString *mutableString = [NSMutableString stringWithFormat:@"m"];
    if (self.length) {
        for (NSInteger i = 0; i < self.length; i++) {
            [mutableString appendString:[DSDerivationPathFactory stringRepresentationOfIndex:[self indexAtPosition:i] hardened:[self isHardenedAtPosition:i] inContext:self.managedObjectContext]];
        }
    } else if ([self.depth integerValue]) {
        for (NSInteger i = 0; i < [self.depth integerValue] - 1; i++) {
            [mutableString appendFormat:@"/?'"];
        }
        UInt256 terminalIndex = [self terminalIndex];
        BOOL terminalHardened = [self terminalHardened];
        [mutableString appendString:[DSDerivationPathFactory stringRepresentationOfIndex:terminalIndex hardened:terminalHardened inContext:self.managedObjectContext]];
    } else {
        if ([self isKindOfClass:[DSIncomingFundsDerivationPath class]]) {
            mutableString = [NSMutableString stringWithFormat:@"inc"];
            DSIncomingFundsDerivationPath *incomingFundsDerivationPath = (DSIncomingFundsDerivationPath *)self;
            [self.managedObjectContext performBlockAndWait:^{
                DSDashpayUserEntity *sourceDashpayUserEntity = [DSDashpayUserEntity anyObjectInContext:self.managedObjectContext matching:@"associatedBlockchainIdentity.uniqueID == %@", uint256_data(incomingFundsDerivationPath.contactSourceIdentityUniqueId)];
                if (sourceDashpayUserEntity) {
                    DSBlockchainIdentityUsernameEntity *usernameEntity = [sourceDashpayUserEntity.associatedBlockchainIdentity.usernames anyObject];
                    [mutableString appendFormat:@"/%@", usernameEntity.stringValue];
                } else {
                    [mutableString appendFormat:@"/0x%@", uint256_hex(incomingFundsDerivationPath.contactSourceIdentityUniqueId)];
                }
            }];
            DSIdentity *identity = [self.wallet identityForUniqueId:incomingFundsDerivationPath.contactDestinationIdentityUniqueId];
            [mutableString appendFormat:@"/%@", identity.currentDashpayUsername];
        }
    }
    _stringRepresentation = [mutableString copy];
    return _stringRepresentation;
}

- (NSString *)referenceName {
    switch (self.reference) {
        case DSDerivationPathReference_Root:
            return @"Root";
            break;
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
        case DSDerivationPathReference_Identities:
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
        case DSDerivationPathReference_IdentityCreditRegistrationFunding:
            return @"BI Credit Registration Funding";
            break;
        case DSDerivationPathReference_IdentityCreditTopupFunding:
            return @"BI Credit Topup Funding";
            break;
        case DSDerivationPathReference_IdentityCreditInvitationFunding:
            return @"BI Credit Invitation Funding";
            break;
        default:
            return @"Unknown";
            break;
    }
}

- (NSString *)debugDescription {
    return [[super debugDescription] stringByAppendingString:[NSString stringWithFormat:@" {%@}", [self stringRepresentation]]];
}

// MARK: - Identifiers

//Derivation paths can be stored based on the wallet and derivation or based solely on the public key

- (NSString *)createIdentifierForDerivationPath {
    Result_ok_u8_arr_32_err_dash_spv_crypto_keys_KeyError *result = dash_spv_crypto_keys_key_OpaqueKey_create_identifier(self.extendedPublicKey->ok);
    NSData *identifier = NSDataFromPtr(result->ok);
    Result_ok_u8_arr_32_err_dash_spv_crypto_keys_KeyError_destroy(result);
    return identifier.shortHexString;
}

- (NSString *)standaloneExtendedPublicKeyUniqueID {
    if (!_standaloneExtendedPublicKeyUniqueID) {
        if (!_extendedPublicKey && !self.wallet) {
            NSAssert(FALSE, @"we really should have a wallet");
            return nil;
        }
        _standaloneExtendedPublicKeyUniqueID = [self createIdentifierForDerivationPath];
    }
    return _standaloneExtendedPublicKeyUniqueID;
}

- (NSString *)standaloneExtendedPublicKeyLocationString {
    if (!self.standaloneExtendedPublicKeyUniqueID) return nil;
    return [DSDerivationPathFactory standaloneExtendedPublicKeyLocationStringForUniqueID:self.standaloneExtendedPublicKeyUniqueID];
}

- (NSString *)walletBasedExtendedPublicKeyLocationStringForWalletUniqueID:(NSString *)uniqueID {
    NSMutableString *mutableString = [NSMutableString string];
    for (NSInteger i = 0; i < self.length; i++) {
        [mutableString appendFormat:@"_%lu", (unsigned long)([self isHardenedAtPosition:i] ? [self indexAtPosition:i].u64[0] | BIP32_HARD : [self indexAtPosition:i].u64[0])];
    }
    char *key_storage_prefix = dash_spv_crypto_keys_key_KeyKind_key_storage_prefix(self.signingAlgorithm);
    NSString *keyStoragePrefix = [NSString stringWithCString:key_storage_prefix encoding:NSUTF8StringEncoding];
    str_destroy(key_storage_prefix);
    return [NSString stringWithFormat:@"%@%@%@",
            [DSDerivationPathFactory walletBasedExtendedPublicKeyLocationStringForUniqueID:uniqueID],
            keyStoragePrefix,
            mutableString];
}

- (NSString *)walletBasedExtendedPublicKeyLocationString {
    if (_walletBasedExtendedPublicKeyLocationString) return _walletBasedExtendedPublicKeyLocationString;
    _walletBasedExtendedPublicKeyLocationString = [self walletBasedExtendedPublicKeyLocationStringForWalletUniqueID:self.wallet.uniqueIDString];
    return _walletBasedExtendedPublicKeyLocationString;
}


- (NSString *)walletBasedExtendedPrivateKeyLocationStringForWalletUniqueID:(NSString *)uniqueID {
    NSMutableString *mutableString = [NSMutableString string];
    for (NSInteger i = 0; i < self.length; i++) {
        [mutableString appendFormat:@"_%lu", (unsigned long)([self isHardenedAtPosition:i] ? [self indexAtPosition:i].u64[0] | BIP32_HARD : [self indexAtPosition:i].u64[0])];
    }
    // TODO: ED25519 has own prefix
    char *key_storage_prefix = dash_spv_crypto_keys_key_KeyKind_key_storage_prefix(self.signingAlgorithm);
    NSString *keyStoragePrefix = [NSString stringWithCString:key_storage_prefix encoding:NSUTF8StringEncoding];
    str_destroy(key_storage_prefix);

    return [NSString stringWithFormat:@"%@%@%@",
            [DSDerivationPathFactory walletBasedExtendedPrivateKeyLocationStringForUniqueID:uniqueID],
            keyStoragePrefix,
            mutableString];
}

- (NSString *)walletBasedExtendedPrivateKeyLocationString {
    if (_walletBasedExtendedPrivateKeyLocationString) return _walletBasedExtendedPrivateKeyLocationString;
    _walletBasedExtendedPrivateKeyLocationString = [self walletBasedExtendedPrivateKeyLocationStringForWalletUniqueID:self.wallet.uniqueIDString];
    return _walletBasedExtendedPrivateKeyLocationString;
}

// MARK: - Key Generation

- (DMaybeOpaqueKey *_Nullable)generateExtendedPublicKeyFromSeed:(NSData *)seed
                                  storeUnderWalletUniqueId:(NSString *)walletUniqueId {
    return [self generateExtendedPublicKeyFromSeed:seed
                          storeUnderWalletUniqueId:walletUniqueId
                                   storePrivateKey:NO];
}

- (DMaybeOpaqueKey *_Nullable)generateExtendedPublicKeyFromSeed:(NSData *)seed
                                       storeUnderWalletUniqueId:(NSString *)walletUniqueId
                                                storePrivateKey:(BOOL)storePrivateKey {
    if (!seed) return nil;
    if (![self length] && self.reference != DSDerivationPathReference_Root) return nil; //there needs to be at least 1 length
    @autoreleasepool {
        if (_extendedPublicKey)
            DMaybeOpaqueKeyDtor(_extendedPublicKey);
        
        SLICE *slice = slice_ctor(seed);
        dash_spv_crypto_keys_key_IndexPathU256 *path = [DSDerivationPath ffi_to:self];
        DMaybeOpaqueKey *result = dash_spv_crypto_keys_key_KeyKind_public_key_from_extended_public_key_data_at_index_path_256(self.signingAlgorithm, slice, path);
        _extendedPublicKey = result;
        NSAssert(_extendedPublicKey, @"extendedPublicKey should be set");
        if (_extendedPublicKey == NULL) {
            return nil;
        }
        if (walletUniqueId) {
            NSData *publicKeyData = [DSKeyManager extendedPublicKeyData:_extendedPublicKey->ok];
            setKeychainData(publicKeyData, [self walletBasedExtendedPublicKeyLocationStringForWalletUniqueID:walletUniqueId], NO);
            if (storePrivateKey) {
                NSData *privateKeyData = [DSKeyManager extendedPrivateKeyData:_extendedPublicKey->ok];
                setKeychainData(privateKeyData, [self walletBasedExtendedPrivateKeyLocationStringForWalletUniqueID:walletUniqueId], YES);
            }
        }
        dash_spv_crypto_keys_key_OpaqueKey_forget_private_key(_extendedPublicKey->ok);
    }
    return _extendedPublicKey;
}

- (DMaybeOpaqueKey *)generateExtendedPublicKeyFromParentDerivationPath:(DSDerivationPath *)parentDerivationPath
                                              storeUnderWalletUniqueId:(NSString *)walletUniqueId {
    
    NSAssert(dash_spv_crypto_keys_key_KeyKind_index(parentDerivationPath.signingAlgorithm) == dash_spv_crypto_keys_key_KeyKind_index(self.signingAlgorithm), @"The signing algorithms must be the same");
    NSParameterAssert(parentDerivationPath);
    NSAssert(self.length > parentDerivationPath.length, @"length must be inferior to the parent derivation path length");
    NSAssert(parentDerivationPath.extendedPublicKey, @"the parent derivation path must have an extended public key");
    if (![self length]) return nil;                             //there needs to be at least 1 length
    if (self.length <= parentDerivationPath.length) return nil; // we need to be longer
    if (!parentDerivationPath.extendedPublicKey) return nil;    //parent derivation path
    if (dash_spv_crypto_keys_key_KeyKind_index(parentDerivationPath.signingAlgorithm) != dash_spv_crypto_keys_key_KeyKind_index(self.signingAlgorithm)) return nil;
    for (NSInteger i = 0; i < [parentDerivationPath length] - 1; i++) {
        NSAssert(uint256_eq([parentDerivationPath indexAtPosition:i], [self indexAtPosition:i]), @"This derivation path must start with elements of the parent derivation path");
        if (!uint256_eq([parentDerivationPath indexAtPosition:i], [self indexAtPosition:i])) return nil;
    }
    if (_extendedPublicKey)
        DMaybeOpaqueKeyDtor(_extendedPublicKey);
    
    DIndexPathU256 *path = [DSDerivationPath ffi_to:self];
    _extendedPublicKey = dash_spv_crypto_keys_key_OpaqueKey_public_derive_to_256_path_with_offset(parentDerivationPath.extendedPublicKey->ok, path, parentDerivationPath.length);
    NSAssert(_extendedPublicKey, @"extendedPublicKey should be set");

    if (walletUniqueId) {
        NSData *publicKeyData = [DSKeyManager extendedPublicKeyData:_extendedPublicKey->ok];
        setKeychainData(publicKeyData, [self walletBasedExtendedPublicKeyLocationStringForWalletUniqueID:walletUniqueId], NO);
    }
    return _extendedPublicKey;
}

- (DMaybeOpaqueKey *_Nullable)privateKeyAtIndexPath:(NSIndexPath *)indexPath
                                           fromSeed:(NSData *)seed {
    NSParameterAssert(indexPath);
    NSParameterAssert(seed);
    if (!seed || !indexPath) return nil;
    if (!self->_length) return nil; //there needs to be at least 1 length
    SLICE *seed_slice = slice_ctor(seed);
    Vec_u32 *index_path = [NSIndexPath ffi_to:indexPath];
    DIndexPathU256 *path = [DSDerivationPath ffi_to:self];
    DMaybeOpaqueKey *result = dash_spv_crypto_keys_key_KeyKind_private_key_at_index_path_wrapped(self.signingAlgorithm, seed_slice, index_path, path);
    return result;
}

- (DMaybeOpaqueKey *_Nullable)publicKeyAtIndexPath:(NSIndexPath *)indexPath {
    NSData *publicKeyData = [self publicKeyDataAtIndexPath:indexPath];
    //NSLog(@"publicKeyDataAtIndexPath: %@: %@", indexPath, publicKeyData.hexString);

    return dash_spv_crypto_keys_key_KeyKind_key_with_public_key_data(self.signingAlgorithm, slice_ctor(publicKeyData));
}

- (NSData *)publicKeyDataAtIndexPath:(NSIndexPath *)indexPath {
    return [DSKeyManager publicKeyDataAtIndexPath:self.extendedPublicKey->ok indexPath:indexPath];
}

@end


@implementation DSDerivationPath (dash_spv_crypto_keys_key_IndexPathU256)

+ (dash_spv_crypto_keys_key_IndexPathU256 *)ffi_to:(DSDerivationPath *)obj {
    uintptr_t length = obj.length;
    u256 **indexes = malloc(length * sizeof(u256 *));
    bool *hardened = malloc(length * sizeof(bool));
    for (NSUInteger i = 0; i < length; i++) {
        indexes[i] = u256_ctor_u(obj->_indexes[i]);
        hardened[i] = obj->_hardenedIndexes[i];
    }
    Vec_u8_32 *i = Vec_u8_32_ctor(length, indexes);
    Vec_bool *h = Vec_bool_ctor(length, hardened);
    return dash_spv_crypto_keys_key_IndexPathU256_ctor(i, h);
}
+ (void)ffi_destroy:(dash_spv_crypto_keys_key_IndexPathU256 *)ffi_ref {
    dash_spv_crypto_keys_key_IndexPathU256_destroy(ffi_ref);
}
@end
