//
//  DSSimplifiedMasternodeEntry.m
//  DashSync
//
//  Created by Sam Westrich on 7/12/18.
//

#import "DSSimplifiedMasternodeEntry.h"
#import "DSBLSKey.h"
#import "DSMerkleBlock.h"
#import "DSMutableOrderedDataKeyDictionary.h"
#import "DSSimplifiedMasternodeEntryEntity+CoreDataProperties.h"
#import "DSWallet.h"
#import "NSData+Bitcoin.h"
#import "NSManagedObject+Sugar.h"
#import "NSMutableData+Dash.h"
#import <arpa/inet.h>

#define LOG_SMNE_CHANGES 0

#if LOG_SMNE_CHANGES
#define DSDSMNELog(s, ...) DSDLog(s, ##__VA_ARGS__)
#else
#define DSDSMNELog(s, ...)
#endif

@interface DSSimplifiedMasternodeEntry ()

@property (nonatomic, assign) UInt256 providerRegistrationTransactionHash;
@property (nonatomic, assign) UInt256 confirmedHash;
@property (nonatomic, assign) UInt256 confirmedHashHashedWithProviderRegistrationTransactionHash;
@property (nonatomic, assign) UInt256 simplifiedMasternodeEntryHash;
@property (nonatomic, assign) UInt128 address;
@property (nonatomic, assign) uint16_t port;
@property (nonatomic, assign) UInt384 operatorPublicKey; //this is using BLS
@property (nonatomic, assign) UInt160 keyIDVoting;
@property (nonatomic, assign) BOOL isValid;
@property (nonatomic, strong) DSChain *chain;
@property (null_resettable, nonatomic, copy) NSString *host;
@property (null_resettable, nonatomic, copy) NSString *ipAddressString;
@property (null_resettable, nonatomic, copy) NSString *portString;
@property (nonatomic, strong) DSBLSKey *operatorPublicBLSKey;
@property (nonatomic, strong) NSMutableDictionary<DSMerkleBlock *, NSData *> *mPreviousOperatorPublicKeys;
@property (nonatomic, strong) NSMutableDictionary<DSMerkleBlock *, NSNumber *> *mPreviousValidity;
@property (nonatomic, strong) NSMutableDictionary<DSMerkleBlock *, NSData *> *mPreviousSimplifiedMasternodeEntryHashes;

@end


@implementation DSSimplifiedMasternodeEntry

- (NSData *)payloadData {
    NSMutableData *hashImportantData = [NSMutableData data];
    [hashImportantData appendUInt256:self.providerRegistrationTransactionHash];
    [hashImportantData appendUInt256:self.confirmedHash];
    [hashImportantData appendUInt128:self.address];
    [hashImportantData appendUInt16:CFSwapInt16HostToBig(self.port)];

    [hashImportantData appendUInt384:self.operatorPublicKey];
    [hashImportantData appendUInt160:self.keyIDVoting];
    [hashImportantData appendUInt8:self.isValid];
    return [hashImportantData copy];
}

- (UInt256)calculateSimplifiedMasternodeEntryHash {
    return [self payloadData].SHA256_2;
}

+ (instancetype)simplifiedMasternodeEntryWithData:(NSData *)data onChain:(DSChain *)chain {
    return [[self alloc] initWithMessage:data onChain:chain];
}

+ (instancetype)simplifiedMasternodeEntryWithProviderRegistrationTransactionHash:(UInt256)providerRegistrationTransactionHash confirmedHash:(UInt256)confirmedHash address:(UInt128)address port:(uint16_t)port operatorBLSPublicKey:(UInt384)operatorBLSPublicKey previousOperatorBLSPublicKeys:(NSDictionary<DSMerkleBlock *, NSData *> *)previousOperatorBLSPublicKeys keyIDVoting:(UInt160)keyIDVoting isValid:(BOOL)isValid previousValidity:(NSDictionary<DSMerkleBlock *, NSData *> *)previousValidity simplifiedMasternodeEntryHash:(UInt256)simplifiedMasternodeEntryHash previousSimplifiedMasternodeEntryHashes:(NSDictionary<DSMerkleBlock *, NSData *> *)previousSimplifiedMasternodeEntryHashes onChain:(DSChain *)chain {
    DSSimplifiedMasternodeEntry *simplifiedMasternodeEntry = [[DSSimplifiedMasternodeEntry alloc] init];
    simplifiedMasternodeEntry.providerRegistrationTransactionHash = providerRegistrationTransactionHash;
    simplifiedMasternodeEntry.confirmedHash = confirmedHash;
    simplifiedMasternodeEntry.address = address;
    simplifiedMasternodeEntry.port = port;
    simplifiedMasternodeEntry.keyIDVoting = keyIDVoting;
    simplifiedMasternodeEntry.operatorPublicKey = operatorBLSPublicKey;
    simplifiedMasternodeEntry.isValid = isValid;
    simplifiedMasternodeEntry.simplifiedMasternodeEntryHash = !uint256_is_zero(simplifiedMasternodeEntryHash) ? simplifiedMasternodeEntryHash : [simplifiedMasternodeEntry calculateSimplifiedMasternodeEntryHash];
    simplifiedMasternodeEntry.chain = chain;
    simplifiedMasternodeEntry.mPreviousOperatorPublicKeys = previousOperatorBLSPublicKeys ? [previousOperatorBLSPublicKeys mutableCopy] : [NSMutableDictionary dictionary];
    simplifiedMasternodeEntry.mPreviousSimplifiedMasternodeEntryHashes = previousSimplifiedMasternodeEntryHashes ? [previousSimplifiedMasternodeEntryHashes mutableCopy] : [NSMutableDictionary dictionary];
    simplifiedMasternodeEntry.mPreviousValidity = previousValidity ? [previousValidity mutableCopy] : [NSMutableDictionary dictionary];
    return simplifiedMasternodeEntry;
}

- (instancetype)initWithMessage:(NSData *)message onChain:(DSChain *)chain {
    if (!(self = [super init])) return nil;
    NSUInteger length = message.length;
    NSUInteger offset = 0;
    if (length - offset < 32) return nil;
    self.providerRegistrationTransactionHash = [message UInt256AtOffset:offset];
    offset += 32;

    if (length - offset < 32) return nil;
    self.confirmedHash = [message UInt256AtOffset:offset];
    offset += 32;

    if (length - offset < 16) return nil;
    self.address = [message UInt128AtOffset:offset];
    offset += 16;

    if (length - offset < 2) return nil;
    self.port = CFSwapInt16HostToBig([message UInt16AtOffset:offset]);
    offset += 2;

    if (length - offset < 48) return nil;
    self.operatorPublicKey = [message UInt384AtOffset:offset];
    offset += 48;

    if (length - offset < 20) return nil;
    self.keyIDVoting = [message UInt160AtOffset:offset];
    offset += 20;

    if (length - offset < 1) return nil;
    self.isValid = [message UInt8AtOffset:offset];
    offset += 1;

    self.simplifiedMasternodeEntryHash = [self calculateSimplifiedMasternodeEntryHash];
    self.mPreviousOperatorPublicKeys = [NSMutableDictionary dictionary];
    self.mPreviousSimplifiedMasternodeEntryHashes = [NSMutableDictionary dictionary];
    self.mPreviousValidity = [NSMutableDictionary dictionary];
    self.chain = chain;

    return self;
}

- (void)keepInfoOfPreviousEntryVersion:(DSSimplifiedMasternodeEntry *)masternodeEntry atBlockHash:(UInt256)blockHash {
    DSMerkleBlock *block = [self.chain blockForBlockHash:blockHash];
    if (!block) return;
    [self updatePreviousValidity:masternodeEntry atBlock:block];
    [self updatePreviousOperatorPublicKeysFromPreviousSimplifiedMasternodeEntry:masternodeEntry atBlock:block];
    [self updatePreviousSimplifiedMasternodeEntryHashesFromPreviousSimplifiedMasternodeEntry:masternodeEntry atBlock:block];
}

- (void)updatePreviousValidity:(DSSimplifiedMasternodeEntry *)masternodeEntry atBlock:(DSMerkleBlock *)block {
    if (!uint256_eq(self.providerRegistrationTransactionHash, masternodeEntry.providerRegistrationTransactionHash)) return;
    self.mPreviousValidity = [masternodeEntry.previousValidity mutableCopy];
    if (masternodeEntry.isValid != self.isValid) {
        //we changed validity
        DSDSMNELog(@"Changed validity from %u to %u on %@", masternodeEntry.isValid, self.isValid, uint256_hex(self.providerRegistrationTransactionHash));
        [self.mPreviousValidity setObject:@(masternodeEntry.isValid) forKey:block];
    }
}

- (void)updatePreviousOperatorPublicKeysFromPreviousSimplifiedMasternodeEntry:(DSSimplifiedMasternodeEntry *)masternodeEntry atBlock:(DSMerkleBlock *)block {
    if (!uint256_eq(self.providerRegistrationTransactionHash, masternodeEntry.providerRegistrationTransactionHash)) return;
    self.mPreviousOperatorPublicKeys = [masternodeEntry.previousOperatorPublicKeys mutableCopy];
    if (!uint384_eq(masternodeEntry.operatorPublicKey, self.operatorPublicKey)) {
        //the operator public key changed
        DSDSMNELog(@"Changed sme operator keys from %@ to %@ on %@", uint384_hex(masternodeEntry.operatorPublicKey), uint384_hex(self.operatorPublicKey), uint256_hex(self.providerRegistrationTransactionHash));
        [self.mPreviousOperatorPublicKeys setObject:uint384_data(masternodeEntry.operatorPublicKey) forKey:block];
    }
}

- (void)updatePreviousSimplifiedMasternodeEntryHashesFromPreviousSimplifiedMasternodeEntry:(DSSimplifiedMasternodeEntry *)masternodeEntry atBlock:(DSMerkleBlock *)block {
    NSAssert(masternodeEntry, @"Masternode entry must be present");
    if (!uint256_eq(self.providerRegistrationTransactionHash, masternodeEntry.providerRegistrationTransactionHash)) return;
    self.mPreviousSimplifiedMasternodeEntryHashes = [masternodeEntry.previousSimplifiedMasternodeEntryHashes mutableCopy];
    if (!uint256_eq(masternodeEntry.simplifiedMasternodeEntryHash, self.simplifiedMasternodeEntryHash)) {
        //the hashes changed
        DSDSMNELog(@"Changed sme hashes from %@ to %@ on %@", uint256_hex(masternodeEntry.simplifiedMasternodeEntryHash), uint256_hex(self.simplifiedMasternodeEntryHash), uint256_hex(self.providerRegistrationTransactionHash));
        [self.mPreviousSimplifiedMasternodeEntryHashes setObject:uint256_data(masternodeEntry.simplifiedMasternodeEntryHash) forKey:block];
    }
}

- (NSDictionary *)previousValidity {
    return [self.mPreviousValidity copy];
}

- (NSDictionary *)previousOperatorPublicKeys {
    return [self.mPreviousOperatorPublicKeys copy];
}

- (NSDictionary *)previousSimplifiedMasternodeEntryHashes {
    return [self.mPreviousSimplifiedMasternodeEntryHashes copy];
}


- (BOOL)isValidAtBlock:(DSMerkleBlock *)merkleBlock {
    if (!merkleBlock || merkleBlock.height == UINT32_MAX) {
        NSAssert(NO, @"Merkle Block should be set");
        return self.isValid;
    }
    if (![self.previousValidity count]) return self.isValid;
    return [self isValidAtBlockHeight:merkleBlock.height];
}

- (BOOL)isValidAtBlockHash:(UInt256)blockHash {
    if (![self.previousValidity count]) return self.isValid;
    uint32_t blockHeight = [self.chain heightForBlockHash:blockHash];
    return [self isValidAtBlockHeight:blockHeight];
}

- (BOOL)isValidAtBlockHeight:(uint32_t)blockHeight {
    if (![self.mPreviousValidity count]) return self.isValid;
    NSAssert(blockHeight != UINT32_MAX, @"block height should be set");
    if (blockHeight == UINT32_MAX) {
        return self.isValid;
    }
    NSDictionary<DSMerkleBlock *, NSNumber *> *previousValidity = self.previousValidity;
    uint32_t minDistance = UINT32_MAX;
    BOOL isValid = self.isValid;
    for (DSMerkleBlock *previousBlock in previousValidity) {
        if (previousBlock.height <= blockHeight) continue;
        uint32_t distance = previousBlock.height - blockHeight;
        if (distance < minDistance) {
            minDistance = distance;
            DSDSMNELog(@"Validity : Using %@ instead of %@ for list at block height %u", previousValidity[previousBlock].boolValue ? @"YES" : @"NO", isValid ? @"YES" : @"NO", blockHeight);
            isValid = [previousValidity[previousBlock] boolValue];
        }
    }
    return isValid;
}

- (UInt256)simplifiedMasternodeEntryHashAtBlock:(DSMerkleBlock *)merkleBlock {
    if (!merkleBlock || merkleBlock.height == UINT32_MAX) {
        NSAssert(NO, @"Merkle Block should be set");
        return self.simplifiedMasternodeEntryHash;
    }
    if (![self.mPreviousSimplifiedMasternodeEntryHashes count]) return self.simplifiedMasternodeEntryHash;
    return [self simplifiedMasternodeEntryHashAtBlockHeight:merkleBlock.height];
}

- (UInt256)simplifiedMasternodeEntryHashAtBlockHash:(UInt256)blockHash {
    if (![self.mPreviousSimplifiedMasternodeEntryHashes count]) return self.simplifiedMasternodeEntryHash;
    uint32_t blockHeight = [self.chain heightForBlockHash:blockHash];
    return [self simplifiedMasternodeEntryHashAtBlockHeight:blockHeight];
}

- (UInt256)simplifiedMasternodeEntryHashAtBlockHeight:(uint32_t)blockHeight {
    if (![self.mPreviousSimplifiedMasternodeEntryHashes count]) return self.simplifiedMasternodeEntryHash;
    NSAssert(blockHeight != UINT32_MAX, @"block height should be set");
    if (blockHeight == UINT32_MAX) {
        return self.simplifiedMasternodeEntryHash;
    }
    NSDictionary<DSMerkleBlock *, NSData *> *previousSimplifiedMasternodeEntryHashes = self.previousSimplifiedMasternodeEntryHashes;
    uint32_t minDistance = UINT32_MAX;
    UInt256 usedSimplifiedMasternodeEntryHash = self.simplifiedMasternodeEntryHash;
    for (DSMerkleBlock *previousBlock in previousSimplifiedMasternodeEntryHashes) {
        if (previousBlock.height <= blockHeight) continue;
        uint32_t distance = previousBlock.height - blockHeight;
        if (distance < minDistance) {
            minDistance = distance;
            DSDSMNELog(@"SME Hash : Using %@ instead of %@ for list at block height %u", uint256_hex(previousSimplifiedMasternodeEntryHashes[previousBlock].UInt256), uint256_hex(usedSimplifiedMasternodeEntryHash), blockHeight);
            usedSimplifiedMasternodeEntryHash = previousSimplifiedMasternodeEntryHashes[previousBlock].UInt256;
        }
    }
    return usedSimplifiedMasternodeEntryHash;
}

- (UInt384)operatorPublicKeyAtBlock:(DSMerkleBlock *)merkleBlock {
    if (!merkleBlock || merkleBlock.height == UINT32_MAX) {
        NSAssert(NO, @"Merkle Block should be set");
        return self.operatorPublicKey;
    }
    if (![self.mPreviousOperatorPublicKeys count]) return self.operatorPublicKey;
    return [self operatorPublicKeyAtBlockHeight:merkleBlock.height];
}

- (UInt384)operatorPublicKeyAtBlockHash:(UInt256)blockHash {
    if (![self.mPreviousOperatorPublicKeys count]) return self.operatorPublicKey;
    uint32_t blockHeight = [self.chain heightForBlockHash:blockHash];
    return [self operatorPublicKeyAtBlockHeight:blockHeight];
}

- (UInt384)operatorPublicKeyAtBlockHeight:(uint32_t)blockHeight {
    if (![self.mPreviousOperatorPublicKeys count]) return self.operatorPublicKey;
    NSDictionary<DSMerkleBlock *, NSData *> *previousOperatorPublicKeyAtBlockHashes = self.previousOperatorPublicKeys;
    uint32_t minDistance = UINT32_MAX;
    UInt384 usedPreviousOperatorPublicKeyAtBlockHash = self.operatorPublicKey;
    for (DSMerkleBlock *previousBlock in previousOperatorPublicKeyAtBlockHashes) {
        if (previousBlock.height <= blockHeight) continue;
        uint32_t distance = previousBlock.height - blockHeight;
        if (distance < minDistance) {
            minDistance = distance;
            DSDSMNELog(@"OperatorKey : Using %@ instead of %@ for list at block height %u", uint384_hex(previousOperatorPublicKeyAtBlockHashes[previousBlock].UInt384), uint384_hex(usedPreviousOperatorPublicKeyAtBlockHash), blockHeight);
            usedPreviousOperatorPublicKeyAtBlockHash = previousOperatorPublicKeyAtBlockHashes[previousBlock].UInt384;
        }
    }
    return usedPreviousOperatorPublicKeyAtBlockHash;
}

- (void)setConfirmedHash:(UInt256)confirmedHash {
    _confirmedHash = confirmedHash;
    if (!uint256_is_zero(self.providerRegistrationTransactionHash)) {
        [self updateConfirmedHashHashedWithProviderRegistrationTransactionHash];
    }
}

- (void)setProviderRegistrationTransactionHash:(UInt256)providerRegistrationTransactionHash {
    _providerRegistrationTransactionHash = providerRegistrationTransactionHash;
    if (!uint256_is_zero(self.confirmedHash)) {
        [self updateConfirmedHashHashedWithProviderRegistrationTransactionHash];
    }
}

- (void)updateConfirmedHashHashedWithProviderRegistrationTransactionHash {
    NSMutableData *combinedData = [NSMutableData data];
    NSData *confirmedHashData = [NSData dataWithUInt256:self.confirmedHash];
    NSData *providerRegistrationTransactionHashData = [NSData dataWithUInt256:self.providerRegistrationTransactionHash];
    [combinedData appendData:providerRegistrationTransactionHashData];
    [combinedData appendData:confirmedHashData];
    NSData *confirmedHashHashedWithProviderRegistrationTransactionHashData = [NSData dataWithUInt256:combinedData.SHA256];
    self.confirmedHashHashedWithProviderRegistrationTransactionHash = confirmedHashHashedWithProviderRegistrationTransactionHashData.UInt256;
}

+ (uint32_t)payloadLength {
    return 151;
}

- (NSString *)host {
    if (_host) return _host;
    _host = [NSString stringWithFormat:@"%@:%d", [self ipAddressString], self.port];
    return _host;
}

- (NSString *)ipAddressString {
    if (_ipAddressString) return _ipAddressString;
    char s[INET6_ADDRSTRLEN];

    if (_address.u64[0] == 0 && _address.u32[2] == CFSwapInt32HostToBig(0xffff)) {
        _ipAddressString = @(inet_ntop(AF_INET, &_address.u32[3], s, sizeof(s)));
    }
    else {
        _ipAddressString = @(inet_ntop(AF_INET6, &_address, s, sizeof(s)));
    }
    return _ipAddressString;
}

- (NSString *)portString {
    if (_portString) return _portString;
    _portString = [NSString stringWithFormat:@"%d", self.port];
    return _portString;
}

- (NSString *)validString {
    return self.isValid
               ? DSLocalizedString(@"Up", @"The server is up and running")
               : DSLocalizedString(@"Down", @"The server is not working");
}

- (NSString *)uniqueID {
    return [NSData dataWithUInt256:self.providerRegistrationTransactionHash].shortHexString;
}

- (DSSimplifiedMasternodeEntryEntity *)simplifiedMasternodeEntryEntity {
    DSSimplifiedMasternodeEntryEntity *simplifiedMasternodeEntryEntity = [DSSimplifiedMasternodeEntryEntity anyObjectMatching:@"providerRegistrationTransactionHash = %@", [NSData dataWithUInt256:self.providerRegistrationTransactionHash]];
    return simplifiedMasternodeEntryEntity;
}

- (DSBLSKey *)operatorPublicBLSKey {
    if (!_operatorPublicBLSKey && !uint384_is_zero(self.operatorPublicKey)) {
        _operatorPublicBLSKey = [DSBLSKey blsKeyWithPublicKey:self.operatorPublicKey onChain:self.chain];
    }
    return _operatorPublicBLSKey;
}

- (BOOL)verifySignature:(UInt768)signature forMessageDigest:(UInt256)messageDigest {
    DSBLSKey *operatorPublicBLSKey = [self operatorPublicBLSKey];
    if (!operatorPublicBLSKey) return NO;
    return [operatorPublicBLSKey verify:messageDigest signature:signature];
}

- (NSString *)votingAddress {
    return [[NSData dataWithUInt160:self.keyIDVoting] addressFromHash160DataForChain:self.chain];
}

- (NSString *)operatorAddress {
    return [DSKey addressWithPublicKeyData:[NSData dataWithUInt384:self.operatorPublicKey] forChain:self.chain];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<DSSimplifiedMasternodeEntry: %@ {valid:%@}>", self.host, @(self.isValid)];
}

- (BOOL)isEqual:(id)other {
    DSSimplifiedMasternodeEntry *entry = (DSSimplifiedMasternodeEntry *)other;
    if (![other isKindOfClass:[DSSimplifiedMasternodeEntry class]]) return NO;
    if (other == self) {
        return YES;
    }
    else if (uint256_eq(self.providerRegistrationTransactionHash, entry.providerRegistrationTransactionHash)) {
        return YES;
    }
    else {
        return NO;
    }
}

- (NSDictionary *)compare:(DSSimplifiedMasternodeEntry *)other ourBlockHash:(UInt256)ourBlockHash theirBlockHash:(UInt256)theirBlockHash {
    return [self compare:other ourBlockHash:ourBlockHash theirBlockHash:theirBlockHash usingOurString:@"ours" usingTheirString:@"theirs"];
}

- (NSDictionary *)compare:(DSSimplifiedMasternodeEntry *)other ourBlockHash:(UInt256)ourBlockHash theirBlockHash:(UInt256)theirBlockHash usingOurString:(NSString *)ours usingTheirString:(NSString *)theirs {
    NSMutableDictionary *differences = [NSMutableDictionary dictionary];

    if (!ours) ours = @"ours";
    if (!theirs) theirs = @"theirs";

    if (!uint128_eq(_address, other.address)) {
        differences[@"address"] = @{ours : uint128_data(_address), theirs : uint128_data(other.address)};
    }

    if (_port != other.port) {
        differences[@"port"] = @{ours : @(_port), theirs : @(other.port)};
    }

    UInt384 ourOperatorPublicKeyAtBlockHash = [self operatorPublicKeyAtBlockHash:ourBlockHash];
    UInt384 theirOperatorPublicKeyAtBlockHash = [other operatorPublicKeyAtBlockHash:theirBlockHash];

    if (!uint384_eq(ourOperatorPublicKeyAtBlockHash, theirOperatorPublicKeyAtBlockHash)) {
        differences[@"operatorPublicKey"] = @{ours : uint384_data(ourOperatorPublicKeyAtBlockHash), theirs : uint384_data(theirOperatorPublicKeyAtBlockHash)};
    }

    if (!uint160_eq(_keyIDVoting, other.keyIDVoting)) {
        differences[@"keyIDVoting"] = @{ours : uint160_data(_keyIDVoting), theirs : uint160_data(other.keyIDVoting)};
    }

    BOOL ourIsValid = [self isValidAtBlockHash:ourBlockHash];
    BOOL theirIsValid = [other isValidAtBlockHash:theirBlockHash];

    if (ourIsValid != theirIsValid) {
        differences[@"isValid"] = @{ours : ourIsValid ? @"YES" : @"NO", theirs : theirIsValid ? @"YES" : @"NO"};
    }

    UInt256 ourSimplifiedMasternodeEntryHash = [self simplifiedMasternodeEntryHashAtBlockHash:ourBlockHash];
    UInt256 theirSimplifiedMasternodeEntryHash = [other simplifiedMasternodeEntryHashAtBlockHash:theirBlockHash];

    if (!uint256_eq(ourSimplifiedMasternodeEntryHash, theirSimplifiedMasternodeEntryHash)) {
        differences[@"simplifiedMasternodeEntryHashAtBlockHash"] = @{ours : uint256_hex(ourSimplifiedMasternodeEntryHash), theirs : uint256_hex(theirSimplifiedMasternodeEntryHash), @"ourBlockHeight" : @([self.chain heightForBlockHash:ourBlockHash]), @"theirBlockHeight" : @([self.chain heightForBlockHash:theirBlockHash])};
    }

    if (![self.previousSimplifiedMasternodeEntryHashes isEqualToDictionary:other.previousSimplifiedMasternodeEntryHashes]) {
        differences[@"previousSimplifiedMasternodeEntryHashes"] = @{ours : self.previousSimplifiedMasternodeEntryHashes, theirs : other.previousSimplifiedMasternodeEntryHashes};
    }

    if (![self.previousValidity isEqualToDictionary:other.previousValidity]) {
        differences[@"previousValidity"] = @{ours : self.previousValidity, theirs : other.previousValidity};
    }

    if (![self.previousOperatorPublicKeys isEqualToDictionary:other.previousOperatorPublicKeys]) {
        differences[@"previousOperatorPublicKeys"] = @{ours : self.previousOperatorPublicKeys, theirs : other.previousOperatorPublicKeys};
    }

    if (!uint256_eq(_confirmedHash, other.confirmedHash)) {
        differences[@"confirmedHash"] = @{ours : uint256_data(_confirmedHash), theirs : uint256_data(other.confirmedHash)};
    }

    return differences;
}

- (NSDictionary *)compare:(DSSimplifiedMasternodeEntry *)other atBlockHash:(UInt256)blockHash {
    return [self compare:other ourBlockHash:blockHash theirBlockHash:blockHash];
}

@end
