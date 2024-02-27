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

#import "DSBlockchainIdentityEntity+CoreDataClass.h"
#import "DSBlockchainIdentityUsernameEntity+CoreDataClass.h"
#import "DSChainManager.h"
#import "DSDashpayUserEntity+CoreDataClass.h"
#import "DSDerivationPath+Protected.h"
#import "DSFriendRequestEntity+CoreDataClass.h"
#import "DSIncomingFundsDerivationPath.h"
#import "NSIndexPath+FFI.h"
#import "NSManagedObject+Sugar.h"
#import "NSMutableData+Dash.h"

#define DERIVATION_PATH_EXTENDED_PUBLIC_KEY_WALLET_BASED_LOCATION @"DP_EPK_WBL"
#define DERIVATION_PATH_EXTENDED_PUBLIC_KEY_STANDALONE_BASED_LOCATION @"DP_EPK_SBL"
#define DERIVATION_PATH_EXTENDED_SECRET_KEY_WALLET_BASED_LOCATION @"DP_ESK_WBL"
#define DERIVATION_PATH_STANDALONE_INFO_DICTIONARY_LOCATION @"DP_SIDL"
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

+ (instancetype)masterBlockchainIdentityContactsDerivationPathForAccountNumber:(uint32_t)accountNumber onChain:(DSChain *)chain {
    UInt256 indexes[] = {uint256_from_long(FEATURE_PURPOSE), uint256_from_long((uint64_t) chain_coin_type(chain.chainType)), uint256_from_long(FEATURE_PURPOSE_DASHPAY), uint256_from_long(accountNumber)};
    //todo full uint256 derivation
    BOOL hardenedIndexes[] = {YES, YES, YES, YES};
    return [self derivationPathWithIndexes:indexes hardened:hardenedIndexes length:4 type:DSDerivationPathType_PartialPath signingAlgorithm:KeyKind_ECDSA reference:DSDerivationPathReference_ContactBasedFundsRoot onChain:chain];
}


+ (instancetype _Nullable)derivationPathWithIndexes:(const UInt256[_Nullable])indexes hardened:(const BOOL[_Nullable])hardenedIndexes length:(NSUInteger)length
                                               type:(DSDerivationPathType)type
                                   signingAlgorithm:(KeyKind)signingAlgorithm
                                          reference:(DSDerivationPathReference)reference
                                            onChain:(DSChain *)chain {
    return [[self alloc] initWithIndexes:indexes hardened:hardenedIndexes length:length type:type signingAlgorithm:signingAlgorithm reference:reference onChain:chain];
}

+ (instancetype _Nullable)derivationPathWithSerializedExtendedPrivateKey:(NSString *)serializedExtendedPrivateKey fundsType:(DSDerivationPathType)fundsType signingAlgorithm:(KeyKind)signingAlgorithm onChain:(DSChain *)chain {
    UInt256 indexes[] = {};
    BOOL hardenedIndexes[] = {};
    DSDerivationPath *derivationPath = [[self alloc] initWithIndexes:indexes hardened:hardenedIndexes length:0 type:fundsType signingAlgorithm:KeyKind_ECDSA reference:DSDerivationPathReference_Unknown onChain:chain];
    NSData *extendedPrivateKey = [self deserializedExtendedPrivateKey:serializedExtendedPrivateKey onChain:chain];
    derivationPath.extendedPublicKey = key_create_ecdsa_from_secret(extendedPrivateKey.bytes, 32, true);
    [derivationPath standaloneSaveExtendedPublicKeyToKeyChain];
    return derivationPath;
}

+ (instancetype _Nullable)derivationPathWithSerializedExtendedPublicKey:(NSString *)serializedExtendedPublicKey onChain:(DSChain *)chain {
    uint8_t depth = 0;
    BOOL terminalHardened;
    UInt256 terminalIndex = UINT256_ZERO;
    NSData *extendedPublicKeyData = [self deserializedExtendedPublicKey:serializedExtendedPublicKey onChain:chain rDepth:&depth rTerminalHardened:&terminalHardened rTerminalIndex:&terminalIndex];
    UInt256 indexes[] = {terminalIndex};
    BOOL hardenedIndexes[] = {terminalHardened};
    DSDerivationPath *derivationPath = [[self alloc] initWithIndexes:indexes hardened:hardenedIndexes length:0 type:DSDerivationPathType_ViewOnlyFunds signingAlgorithm:KeyKind_ECDSA reference:DSDerivationPathReference_Unknown onChain:chain]; //we are going to assume this is only ecdsa for now
    derivationPath.extendedPublicKey = key_create_ecdsa_from_extended_public_key_data(extendedPublicKeyData.bytes, extendedPublicKeyData.length);
    derivationPath.depth = @(depth);
    [derivationPath standaloneSaveExtendedPublicKeyToKeyChain];
    [derivationPath loadAddresses];
    return derivationPath;
}

- (instancetype _Nullable)initWithExtendedPublicKeyIdentifier:(NSString *_Nonnull)extendedPublicKeyIdentifier onChain:(DSChain *_Nonnull)chain {
    NSError *error = nil;
    NSDictionary *infoDictionary = getKeychainDict([DSDerivationPath standaloneInfoDictionaryLocationStringForUniqueID:extendedPublicKeyIdentifier], @[[NSString class], [NSNumber class]], &error);
    if (error) return nil;

    UInt256 terminalIndex = [((NSData *)infoDictionary[DERIVATION_PATH_STANDALONE_INFO_TERMINAL_INDEX]) UInt256];
    BOOL terminalHardened = [((NSNumber *)infoDictionary[DERIVATION_PATH_STANDALONE_INFO_TERMINAL_HARDENED]) boolValue];
    UInt256 indexes[] = {terminalIndex};
    BOOL hardenedIndexes[] = {terminalHardened};
    if (!(self = [self initWithIndexes:indexes hardened:hardenedIndexes length:0 type:DSDerivationPathType_ViewOnlyFunds signingAlgorithm:KeyKind_ECDSA reference:DSDerivationPathReference_Unknown onChain:chain])) return nil;
    _walletBasedExtendedPublicKeyLocationString = extendedPublicKeyIdentifier;
    NSData *data = getKeychainData([DSDerivationPath standaloneExtendedPublicKeyLocationStringForUniqueID:extendedPublicKeyIdentifier], &error);
    if (error) return nil;
    _extendedPublicKey = key_create_ecdsa_from_extended_public_key_data(data.bytes, data.length);
    _depth = infoDictionary[DERIVATION_PATH_STANDALONE_INFO_DEPTH];

    [self loadAddresses];
    return self;
}

- (instancetype)initWithIndexes:(const UInt256[_Nullable])indexes hardened:(const BOOL[_Nullable])hardenedIndexes length:(NSUInteger)length
                           type:(DSDerivationPathType)type
               signingAlgorithm:(KeyKind)signingAlgorithm
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
        processor_destroy_opaque_key(_extendedPublicKey);
    }

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

// MARK: - Purpose

- (BOOL)isBIP32Only {
    if (self.length == 1) return true;
    return false;
}

- (BOOL)isBIP43Based {
    if (self.length != 1) return true;
    return false;
}

- (NSUInteger)purpose {
    if ([self isBIP43Based]) return [self indexAtPosition:0].u64[0];
    return 0;
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
    if (self.extendedPublicKey != NULL)
        return [DSKeyManager extendedPublicKeyData:self.extendedPublicKey];
    else
        return nil;
}

- (void)maybeRevertBLSMigration:(NSData *)extendedPublicKeyData {
    // revert
    // for those who already migrated from legacy to basic BLS derivation scheme
    // we revert back their extended public key to legacy
    BOOL isBasicBLS = self.signingAlgorithm == KeyKind_BLSBasic;
    if (isBasicBLS) {
        _extendedPublicKey = key_bls_migrate_from_basic_extended_public_key_data(extendedPublicKeyData.bytes, extendedPublicKeyData.length);
        if (_extendedPublicKey) {
            setKeychainData([DSKeyManager extendedPublicKeyData:_extendedPublicKey], [self standaloneExtendedPublicKeyLocationString], NO);
        }
    }
}

- (OpaqueKey *)extendedPublicKey {
    if (!_extendedPublicKey) {
        if (self.wallet && (self.length || self.reference == DSDerivationPathReference_Root)) {
            NSData *extendedPublicKeyData = getKeychainData([self walletBasedExtendedPublicKeyLocationString], nil);
            if (extendedPublicKeyData) {
                _extendedPublicKey = key_create_from_extended_public_key_data(extendedPublicKeyData.bytes, extendedPublicKeyData.length, (int16_t) self.signingAlgorithm);
                [self maybeRevertBLSMigration:extendedPublicKeyData];
                NSAssert(_extendedPublicKey, @"extended public key not set");
            }
        } else {
            NSData *extendedPublicKeyData = getKeychainData([self standaloneExtendedPublicKeyLocationString], nil);
#ifdef DEBUG
            if (!extendedPublicKeyData) {
                if ([self isKindOfClass:[DSIncomingFundsDerivationPath class]]) {
                    DSFriendRequestEntity *friendRequest = [DSFriendRequestEntity anyObjectInContext:self.managedObjectContext matching:@"derivationPath.publicKeyIdentifier == %@", self.standaloneExtendedPublicKeyUniqueID];

                    NSAssert(friendRequest, @"friend request must exist");

                    DSBlockchainIdentityUsernameEntity *sourceUsernameEntity = [friendRequest.sourceContact.associatedBlockchainIdentity.usernames anyObject];
                    DSBlockchainIdentityUsernameEntity *destinationUsernameEntity = [friendRequest.destinationContact.associatedBlockchainIdentity.usernames anyObject];
#if DEBUG
                    DSLogPrivate(@"[%@] No extended public key set for the relationship between %@ and %@ (%@ receiving payments) ", self.chain.name, sourceUsernameEntity.stringValue, destinationUsernameEntity.stringValue, sourceUsernameEntity.stringValue);
#else
                    DSLog(@"[%@] No extended public key set for the relationship between %@ and %@ (%@ receiving payments) ", self.chain.name, 
                        @"<REDACTED-1>",
                        @"<REDACTED-2>",
                        @"<REDACTED-1>");
#endif /* DEBUG */
                }
            }
#endif
            _extendedPublicKey = key_create_from_extended_public_key_data(extendedPublicKeyData.bytes, extendedPublicKeyData.length, (int16_t) self.signingAlgorithm);
            [self maybeRevertBLSMigration:extendedPublicKeyData];
        }
    }
    return _extendedPublicKey;
}

- (void)standaloneSaveExtendedPublicKeyToKeyChain {
    if (!_extendedPublicKey) return;
    setKeychainData([self extendedPublicKeyData], [self standaloneExtendedPublicKeyLocationString], NO);
    setKeychainDict(@{DERIVATION_PATH_STANDALONE_INFO_TERMINAL_INDEX: uint256_data([self terminalIndex]), DERIVATION_PATH_STANDALONE_INFO_TERMINAL_HARDENED: @([self terminalHardened]), DERIVATION_PATH_STANDALONE_INFO_DEPTH: self.depth}, [self standaloneInfoDictionaryLocationString], NO);
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
    return [DSKeyManager NSStringFrom:key_address_with_public_key_data(pubKey.bytes, pubKey.length, self.chain.chainType)];
}

// true if the address is controlled by the wallet
- (BOOL)containsAddress:(NSString *)address {
    return (address && [self.mAllAddresses containsObject:address]) ? YES : NO;
}

// true if the address was previously used as an input or output in any wallet transaction
- (BOOL)addressIsUsed:(NSString *)address {
    return (address && [self.mUsedAddresses containsObject:address]) ? YES : NO;
}

// true if the address at index path was previously used as an input or output in any wallet transaction
- (BOOL)addressIsUsedAtIndexPath:(NSIndexPath *)indexPath {
    return [self addressIsUsed:[self addressAtIndexPath:indexPath]];
}

- (BOOL)registerTransactionAddress:(NSString *_Nonnull)address {
    if ([self containsAddress:address]) {
        if (![self.mUsedAddresses containsObject:address]) {
            [self.mUsedAddresses addObject:address];
        }
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

// MARK: - Derivation Path Information

- (DSDerivationPathEntity *)derivationPathEntity {
    return [DSDerivationPathEntity derivationPathEntityMatchingDerivationPath:self inContext:self.managedObjectContext];
}

- (DSDerivationPathEntity *)derivationPathEntityInContext:(NSManagedObjectContext *)context {
    return [DSDerivationPathEntity derivationPathEntityMatchingDerivationPath:self inContext:context];
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

+ (NSString *)stringRepresentationOfIndex:(UInt256)index hardened:(BOOL)hardened inContext:(NSManagedObjectContext *)context {
    if (uint256_is_31_bits(index)) {
        return [NSString stringWithFormat:@"/%lu%@", (unsigned long)index.u64[0], hardened ? @"'" : @""];
    } else if (context) {
        __block NSString *rString = nil;
        [context performBlockAndWait:^{
            DSDashpayUserEntity *dashpayUserEntity = [DSDashpayUserEntity anyObjectInContext:context matching:@"associatedBlockchainIdentity.uniqueID == %@", uint256_data(index)];
            if (dashpayUserEntity) {
                DSBlockchainIdentityUsernameEntity *usernameEntity = [dashpayUserEntity.associatedBlockchainIdentity.usernames anyObject];
                rString = [NSString stringWithFormat:@"/%@%@", usernameEntity.stringValue, hardened ? @"'" : @""];
            } else {
                rString = [NSString stringWithFormat:@"/0x%@%@", uint256_hex(index), hardened ? @"'" : @""];
            }
        }];
        return rString;
    } else {
        return [NSString stringWithFormat:@"/0x%@%@", uint256_hex(index), hardened ? @"'" : @""];
    }
}

- (NSString *)stringRepresentation {
    if (_stringRepresentation) return _stringRepresentation;
    NSMutableString *mutableString = [NSMutableString stringWithFormat:@"m"];
    if (self.length) {
        for (NSInteger i = 0; i < self.length; i++) {
            [mutableString appendString:[DSDerivationPath stringRepresentationOfIndex:[self indexAtPosition:i] hardened:[self isHardenedAtPosition:i] inContext:self.managedObjectContext]];
        }
    } else if ([self.depth integerValue]) {
        for (NSInteger i = 0; i < [self.depth integerValue] - 1; i++) {
            [mutableString appendFormat:@"/?'"];
        }
        UInt256 terminalIndex = [self terminalIndex];
        BOOL terminalHardened = [self terminalHardened];
        [mutableString appendString:[DSDerivationPath stringRepresentationOfIndex:terminalIndex hardened:terminalHardened inContext:self.managedObjectContext]];
    } else {
        if ([self isKindOfClass:[DSIncomingFundsDerivationPath class]]) {
            mutableString = [NSMutableString stringWithFormat:@"inc"];
            DSIncomingFundsDerivationPath *incomingFundsDerivationPath = (DSIncomingFundsDerivationPath *)self;
            [self.managedObjectContext performBlockAndWait:^{
                DSDashpayUserEntity *sourceDashpayUserEntity = [DSDashpayUserEntity anyObjectInContext:self.managedObjectContext matching:@"associatedBlockchainIdentity.uniqueID == %@", uint256_data(incomingFundsDerivationPath.contactSourceBlockchainIdentityUniqueId)];
                if (sourceDashpayUserEntity) {
                    DSBlockchainIdentityUsernameEntity *usernameEntity = [sourceDashpayUserEntity.associatedBlockchainIdentity.usernames anyObject];
                    [mutableString appendFormat:@"/%@", usernameEntity.stringValue];
                } else {
                    [mutableString appendFormat:@"/0x%@", uint256_hex(incomingFundsDerivationPath.contactSourceBlockchainIdentityUniqueId)];
                }
            }];
            DSBlockchainIdentity *blockchainIdentity = [self.wallet blockchainIdentityForUniqueId:incomingFundsDerivationPath.contactDestinationBlockchainIdentityUniqueId];
            [mutableString appendFormat:@"/%@", blockchainIdentity.currentDashpayUsername];
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
        case DSDerivationPathReference_BlockchainIdentityCreditRegistrationFunding:
            return @"BI Credit Registration Funding";
            break;
        case DSDerivationPathReference_BlockchainIdentityCreditTopupFunding:
            return @"BI Credit Topup Funding";
            break;
        case DSDerivationPathReference_BlockchainIdentityCreditInvitationFunding:
            return @"BI Credit Invitation Funding";
            break;
        case DSDerivationPathReference_CoinJoin:
            return @"CoinJoin";
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
    // TODO: rust migration u64
    return [NSData dataWithUInt256:[[self extendedPublicKeyData] SHA256]].shortHexString;
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

+ (NSString *)standaloneExtendedPublicKeyLocationStringForUniqueID:(NSString *)uniqueID {
    return [NSString stringWithFormat:@"%@_%@", DERIVATION_PATH_EXTENDED_PUBLIC_KEY_STANDALONE_BASED_LOCATION, uniqueID];
}

- (NSString *)standaloneExtendedPublicKeyLocationString {
    if (!self.standaloneExtendedPublicKeyUniqueID) return nil;
    return [DSDerivationPath standaloneExtendedPublicKeyLocationStringForUniqueID:self.standaloneExtendedPublicKeyUniqueID];
}

+ (NSString *)standaloneInfoDictionaryLocationStringForUniqueID:(NSString *)uniqueID {
    return [NSString stringWithFormat:@"%@_%@", DERIVATION_PATH_STANDALONE_INFO_DICTIONARY_LOCATION, uniqueID];
}

- (NSString *)standaloneInfoDictionaryLocationString {
    if (!self.standaloneExtendedPublicKeyUniqueID) return nil;
    return [DSDerivationPath standaloneInfoDictionaryLocationStringForUniqueID:self.standaloneExtendedPublicKeyUniqueID];
}

+ (NSString *)walletBasedExtendedPublicKeyLocationStringForUniqueID:(NSString *)uniqueID {
    return [NSString stringWithFormat:@"%@_%@", DERIVATION_PATH_EXTENDED_PUBLIC_KEY_WALLET_BASED_LOCATION, uniqueID];
}

- (NSString *)walletBasedExtendedPublicKeyLocationStringForWalletUniqueID:(NSString *)uniqueID {
    NSMutableString *mutableString = [NSMutableString string];
    for (NSInteger i = 0; i < self.length; i++) {
        [mutableString appendFormat:@"_%lu", (unsigned long)([self isHardenedAtPosition:i] ? [self indexAtPosition:i].u64[0] | BIP32_HARD : [self indexAtPosition:i].u64[0])];
    }
    return [NSString stringWithFormat:@"%@%@%@",
            [DSDerivationPath walletBasedExtendedPublicKeyLocationStringForUniqueID:uniqueID],
            [DSKeyManager keyStoragePrefix:self.signingAlgorithm],
            mutableString];
}

- (NSString *)walletBasedExtendedPublicKeyLocationString {
    if (_walletBasedExtendedPublicKeyLocationString) return _walletBasedExtendedPublicKeyLocationString;
    _walletBasedExtendedPublicKeyLocationString = [self walletBasedExtendedPublicKeyLocationStringForWalletUniqueID:self.wallet.uniqueIDString];
    return _walletBasedExtendedPublicKeyLocationString;
}

+ (NSString *)walletBasedExtendedPrivateKeyLocationStringForUniqueID:(NSString *)uniqueID {
    return [NSString stringWithFormat:@"%@_%@", DERIVATION_PATH_EXTENDED_SECRET_KEY_WALLET_BASED_LOCATION, uniqueID];
}

- (NSString *)walletBasedExtendedPrivateKeyLocationStringForWalletUniqueID:(NSString *)uniqueID {
    NSMutableString *mutableString = [NSMutableString string];
    for (NSInteger i = 0; i < self.length; i++) {
        [mutableString appendFormat:@"_%lu", (unsigned long)([self isHardenedAtPosition:i] ? [self indexAtPosition:i].u64[0] | BIP32_HARD : [self indexAtPosition:i].u64[0])];
    }
    // TODO: ED25519 has own prefix
    return [NSString stringWithFormat:@"%@%@%@",
            [DSDerivationPath walletBasedExtendedPrivateKeyLocationStringForUniqueID:uniqueID],
            [DSKeyManager keyStoragePrefix:self.signingAlgorithm],
            mutableString];
}

- (NSString *)walletBasedExtendedPrivateKeyLocationString {
    if (_walletBasedExtendedPrivateKeyLocationString) return _walletBasedExtendedPrivateKeyLocationString;
    _walletBasedExtendedPrivateKeyLocationString = [self walletBasedExtendedPrivateKeyLocationStringForWalletUniqueID:self.wallet.uniqueIDString];
    return _walletBasedExtendedPrivateKeyLocationString;
}

// MARK: - Key Generation

- (OpaqueKey *)generateExtendedPublicKeyFromSeed:(NSData *)seed storeUnderWalletUniqueId:(NSString *)walletUniqueId {
    return [self generateExtendedPublicKeyFromSeed:seed storeUnderWalletUniqueId:walletUniqueId storePrivateKey:NO];
}

- (OpaqueKey *)generateExtendedPublicKeyFromSeed:(NSData *)seed storeUnderWalletUniqueId:(NSString *)walletUniqueId storePrivateKey:(BOOL)storePrivateKey {
    if (!seed) return nil;
    if (![self length] && self.reference != DSDerivationPathReference_Root) return nil; //there needs to be at least 1 length
    @autoreleasepool {
        if (_extendedPublicKey)
            processor_destroy_opaque_key(_extendedPublicKey);
        _extendedPublicKey = generate_extended_public_key_from_seed(seed.bytes, seed.length, (int16_t) self.signingAlgorithm, (const uint8_t *) self->_indexes, self->_hardenedIndexes, self->_length);
        NSAssert(_extendedPublicKey, @"extendedPublicKey should be set");
        if (_extendedPublicKey == NULL) {
            return nil;
        }
        if (walletUniqueId) {
            NSData *publicKeyData = [DSKeyManager extendedPublicKeyData:_extendedPublicKey];
            setKeychainData(publicKeyData, [self walletBasedExtendedPublicKeyLocationStringForWalletUniqueID:walletUniqueId], NO);
            if (storePrivateKey) {
                NSData *privateKeyData = [DSKeyManager extendedPrivateKeyData:_extendedPublicKey];
                setKeychainData(privateKeyData, [self walletBasedExtendedPrivateKeyLocationStringForWalletUniqueID:walletUniqueId], YES);
            }
        }
        forget_private_key(_extendedPublicKey);
    }
    return _extendedPublicKey;
}

- (OpaqueKey *)generateExtendedPublicKeyFromParentDerivationPath:(DSDerivationPath *)parentDerivationPath storeUnderWalletUniqueId:(NSString *)walletUniqueId {
    NSAssert(parentDerivationPath.signingAlgorithm == self.signingAlgorithm, @"The signing algorithms must be the same");
    NSParameterAssert(parentDerivationPath);
    NSAssert(self.length > parentDerivationPath.length, @"length must be inferior to the parent derivation path length");
    NSAssert(parentDerivationPath.extendedPublicKey, @"the parent derivation path must have an extended public key");
    if (![self length]) return nil;                             //there needs to be at least 1 length
    if (self.length <= parentDerivationPath.length) return nil; // we need to be longer
    if (!parentDerivationPath.extendedPublicKey) return nil;    //parent derivation path
    if (parentDerivationPath.signingAlgorithm != self.signingAlgorithm) return nil;
    for (NSInteger i = 0; i < [parentDerivationPath length] - 1; i++) {
        NSAssert(uint256_eq([parentDerivationPath indexAtPosition:i], [self indexAtPosition:i]), @"This derivation path must start with elements of the parent derivation path");
        if (!uint256_eq([parentDerivationPath indexAtPosition:i], [self indexAtPosition:i])) return nil;
    }
    if (_extendedPublicKey)
        processor_destroy_opaque_key(_extendedPublicKey);
    _extendedPublicKey = [DSKeyManager keyPublicDeriveTo256Bit:parentDerivationPath childIndexes:self->_indexes childHardened:self->_hardenedIndexes length:self.length];
    NSAssert(_extendedPublicKey, @"extendedPublicKey should be set");

    if (walletUniqueId) {
        NSData *publicKeyData = [DSKeyManager extendedPublicKeyData:_extendedPublicKey];
        setKeychainData(publicKeyData, [self walletBasedExtendedPublicKeyLocationStringForWalletUniqueID:walletUniqueId], NO);
    }
    return _extendedPublicKey;
}

- (OpaqueKey *)privateKeyForKnownAddress:(NSString *)address fromSeed:(NSData *)seed {
    NSIndexPath *indexPathForAddress = [self indexPathForKnownAddress:address];
    return [self privateKeyAtIndexPath:indexPathForAddress fromSeed:seed];
}

- (OpaqueKey *_Nullable)privateKeyAtIndexPath:(NSIndexPath *)indexPath fromSeed:(NSData *)seed {
    return [DSKeyManager privateKeyAtIndexPath:self.signingAlgorithm indexes:self->_indexes hardened:self->_hardenedIndexes length:self.length indexPath:indexPath fromSeed:seed];
}

- (OpaqueKey *)publicKeyAtIndexPath:(NSIndexPath *)indexPath {
    return [DSKeyManager publicKeyAtIndexPath:self.extendedPublicKey indexPath:indexPath];
}

- (NSData *)publicKeyDataAtIndexPath:(NSIndexPath *)indexPath {
    return [DSKeyManager publicKeyDataAtIndexPath:self.extendedPublicKey indexPath:indexPath];
}

- (NSArray *)privateKeysAtIndexPaths:(NSArray *)indexPaths fromSeed:(NSData *)seed {
    if (!seed || !indexPaths) return nil;
    if (indexPaths.count == 0) return @[];

    NSUInteger count = indexPaths.count;
    IndexPathData *data = malloc(sizeof(IndexPathData) * count);
    for (NSUInteger i = 0; i < count; i++) {
        NSIndexPath *indexPath = indexPaths[i];
        NSUInteger length = indexPath.length;
        NSUInteger *indexes = malloc(sizeof(NSUInteger) * length);
        [indexPath getIndexes:indexes];
        data[i].indexes = indexes;
        data[i].len = length;
    }
    OpaqueKeys *keys = key_private_keys_at_index_paths(seed.bytes, seed.length, (int16_t) self.signingAlgorithm, data, count, (const uint8_t *) self->_indexes, self->_hardenedIndexes, self->_length);
    for (NSUInteger i = 0; i < count; i++) {
        free((void *)data[i].indexes);
    }
    free(data);
    NSMutableArray *privateKeys = [NSMutableArray arrayWithCapacity:keys->len];
    for (NSUInteger i = 0; i < keys->len; i++) {
        [privateKeys addObject:[NSValue valueWithPointer:keys->keys[i]]];
    }
    // TODO: destroy when keys don't need anymore
    // processor_destroy_opaque_keys(keys);
    
//    NSMutableArray *privateKeys = [NSMutableArray arrayWithCapacity:indexPaths.count];
//    DSKey *topKey = [DSKey keyWithSeedData:seed forKeyType:self.signingAlgorithm];
//    DSKey *derivationPathExtendedKey = [topKey privateDeriveTo256BitDerivationPath:self];
//
//#if DEBUG
//    if (_extendedPublicKey) {
//        NSData *publicKey = _extendedPublicKey.extendedPublicKeyData;
//        NSAssert([publicKey isEqualToData:derivationPathExtendedKey.extendedPublicKeyData], @"The derivation doesn't match the public key");
//    }
//#endif

    return privateKeys;
}


- (NSArray *)serializedPrivateKeysAtIndexPaths:(NSArray *)indexPaths fromSeed:(NSData *)seed {
    if (!seed || !indexPaths) return nil;
    if (indexPaths.count == 0) return @[];
    
    NSUInteger count = indexPaths.count;
    IndexPathData *data = malloc(sizeof(IndexPathData) * count);
    for (NSUInteger i = 0; i < count; i++) {
        NSIndexPath *indexPath = indexPaths[i];
        NSUInteger length = indexPath.length;
        NSUInteger *indexes = malloc(sizeof(NSUInteger) * length);
        [indexPath getIndexes:indexes];
        data[i].indexes = indexes;
        data[i].len = length;
    }
    OpaqueSerializedKeys *keys = serialized_key_private_keys_at_index_paths(seed.bytes, seed.length, (int16_t) self.signingAlgorithm, data, count, (const uint8_t *) self->_indexes, self->_hardenedIndexes, self.length, self.chain.chainType);
    for (NSUInteger i = 0; i < count; i++) {
        free((void *)data[i].indexes);
    }
    free(data);
    NSMutableArray *privateKeys = [NSMutableArray arrayWithCapacity:keys->len];
    for (NSUInteger i = 0; i < keys->len; i++) {
        [privateKeys addObject:[NSString stringWithUTF8String:keys->keys[i]]];
    }
    processor_destroy_serialized_opaque_keys(keys);
    return privateKeys;
}


// MARK: - Deprecated

//this is for upgrade purposes only
// TODO: check if this needed
- (OpaqueKey *)deprecatedIncorrectExtendedPublicKeyFromSeed:(NSData *)seed {
    if (!seed) return nil;
    if (![self length]) return nil; //there needs to be at least 1 length
    return [DSKeyManager keyDeprecatedExtendedPublicKeyFromSeed:seed indexes:self->_indexes hardened:self->_hardenedIndexes length:self.length];
}

// MARK: - Storage

- (BOOL)storeExtendedPublicKeyUnderWalletUniqueId:(NSString *)walletUniqueId {
    if (!_extendedPublicKey) return FALSE;
    NSParameterAssert(walletUniqueId);
    NSData *data = [DSKeyManager extendedPublicKeyData:_extendedPublicKey];
    setKeychainData(data, [self walletBasedExtendedPublicKeyLocationStringForWalletUniqueID:walletUniqueId], NO);
    return TRUE;
}

// MARK: - Serializations

- (NSString *_Nullable)serializedExtendedPrivateKeyFromSeedAtIndexPath:(NSData *)seed indexPath:(NSIndexPath *)indexPath {
    OpaqueKey *key = [self privateKeyAtIndexPath:indexPath fromSeed:seed];
    NSString *pk = [DSKeyManager NSStringFrom:key_serialized_private_key_for_chain(key, self.chain.chainType)];
    processor_destroy_opaque_key(key);
    return pk;
}
- (NSString *)serializedExtendedPrivateKeyFromSeed:(NSData *)seed {
    @autoreleasepool {
        if (!seed) return nil;
        return [DSKeyManager NSStringFrom:key_serialized_extended_private_key_from_seed(seed.bytes, seed.length, (const uint8_t *) self->_indexes, self->_hardenedIndexes, self->_length, self.chain.chainType)];
    }
}

+ (NSData *)deserializedExtendedPrivateKey:(NSString *)extendedPrivateKeyString onChain:(DSChain *)chain {
    @autoreleasepool {
        uint8_t depth;
        uint32_t fingerprint;
        UInt256 child;
        BOOL hardened;
        UInt256 chainHash;
        NSData *privkey = nil;
        NSMutableData *masterPrivateKey = [NSMutableData secureData];
        BOOL valid = deserialize(extendedPrivateKeyString, &depth, &fingerprint, &hardened, &child, &chainHash, &privkey, [chain isMainnet]);
        if (!valid) return nil;
        [masterPrivateKey appendUInt32:fingerprint];
        [masterPrivateKey appendBytes:&chainHash length:32];
        [masterPrivateKey appendData:privkey];
        return [masterPrivateKey copy];
    }
}

- (NSString *)serializedExtendedPublicKey {
    //todo make sure this works with BLS keys
    NSData *extPubKeyData = self.extendedPublicKeyData;
    if (extPubKeyData.length < 36) return nil;
    uint32_t fingerprint = [extPubKeyData UInt32AtOffset:0];
    UInt256 chain = [extPubKeyData UInt256AtOffset:4];
    DSECPoint pubKey = [extPubKeyData ECPointAtOffset:36];
    UInt256 child = UINT256_ZERO;
    BOOL isHardened = NO;
    if (self.length) {
        child = [self indexAtPosition:[self length] - 1];
        isHardened = [self isHardenedAtPosition:[self length] - 1];
    }

    return serialize([self.depth unsignedCharValue], fingerprint, isHardened, child, chain, [NSData dataWithBytes:&pubKey length:sizeof(pubKey)], [self.chain isMainnet]);
}

+ (NSData *)deserializedExtendedPublicKey:(NSString *)extendedPublicKeyString onChain:(DSChain *)chain rDepth:(uint8_t *)depth rTerminalHardened:(BOOL *)terminalHardened rTerminalIndex:(UInt256 *)terminalIndex {
    uint32_t fingerprint;
    UInt256 chainHash;
    NSData *pubkey = nil;
    NSMutableData *masterPublicKey = [NSMutableData secureData];
    BOOL valid = deserialize(extendedPublicKeyString, depth, &fingerprint, terminalHardened, terminalIndex, &chainHash, &pubkey, [chain isMainnet]);
    if (!valid) return nil;
    [masterPublicKey appendUInt32:fingerprint];
    [masterPublicKey appendBytes:&chainHash length:32];
    [masterPublicKey appendData:pubkey];
    return [masterPublicKey copy];
}

+ (NSData *)deserializedExtendedPublicKey:(NSString *)extendedPublicKeyString onChain:(DSChain *)chain {
    __unused uint8_t depth = 0;
    __unused BOOL terminalHardened = 0;
    __unused UInt256 terminalIndex = UINT256_ZERO;
    NSData *extendedPublicKey = [self deserializedExtendedPublicKey:extendedPublicKeyString onChain:chain rDepth:&depth rTerminalHardened:&terminalHardened rTerminalIndex:&terminalIndex];
    return extendedPublicKey;
}

- (NSData *)deserializedExtendedPublicKey:(NSString *)extendedPublicKeyString {
    return [DSDerivationPath deserializedExtendedPublicKey:extendedPublicKeyString onChain:self.chain];
}

@end
