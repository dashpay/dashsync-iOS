//
//  DSSimplifiedMasternodeEntry.m
//  DashSync
//
//  Created by Sam Westrich on 7/12/18.
//

#import "DSSimplifiedMasternodeEntry.h"
#import "DSBLSKey.h"
#import "DSBlock.h"
#import "DSMerkleBlock.h"
#import "DSMutableOrderedDataKeyDictionary.h"
#import "DSSimplifiedMasternodeEntryEntity+CoreDataProperties.h"
#import "DSWallet.h"
#import "NSData+Dash.h"
#import "NSDictionary+Dash.h"
#import "NSManagedObject+Sugar.h"
#import "NSMutableData+Dash.h"
#import <arpa/inet.h>

#define LOG_SMNE_CHANGES 1

#if LOG_SMNE_CHANGES
#define DSDSMNELog(s, ...) DSLog(s, ##__VA_ARGS__)
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
@property (nonatomic, assign) uint16_t operatorPublicKeyVersion; // 1: legacy | 2: basic
@property (nonatomic, assign) UInt160 keyIDVoting;
@property (nonatomic, assign) BOOL isValid;
@property (nonatomic, assign) uint32_t knownConfirmedAtHeight;
@property (nonatomic, assign) uint32_t updateHeight;
@property (nonatomic, strong) DSChain *chain;
@property (null_resettable, nonatomic, copy) NSString *host;
@property (null_resettable, nonatomic, copy) NSString *ipAddressString;
@property (null_resettable, nonatomic, copy) NSString *portString;
@property (nonatomic, strong) DSBLSKey *operatorPublicBLSKey;
@property (nonatomic, strong) NSDictionary<DSBlock *, NSData *> *previousOperatorPublicKeys;
@property (nonatomic, strong) NSDictionary<DSBlock *, NSNumber *> *previousValidity;
@property (nonatomic, strong) NSDictionary<DSBlock *, NSData *> *previousSimplifiedMasternodeEntryHashes;
@property (nonatomic, assign) uint64_t platformPing;
@property (nonatomic, strong) NSDate *platformPingDate;

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

+ (instancetype)simplifiedMasternodeEntryWithProviderRegistrationTransactionHash:(UInt256)providerRegistrationTransactionHash confirmedHash:(UInt256)confirmedHash address:(UInt128)address port:(uint16_t)port operatorBLSPublicKey:(UInt384)operatorBLSPublicKey operatorPublicKeyVersion:(uint16_t)operatorPublicKeyVersion previousOperatorBLSPublicKeys:(NSDictionary<DSBlock *, NSData *> *)previousOperatorBLSPublicKeys keyIDVoting:(UInt160)keyIDVoting isValid:(BOOL)isValid previousValidity:(NSDictionary<DSBlock *, NSNumber *> *)previousValidity knownConfirmedAtHeight:(uint32_t)knownConfirmedAtHeight updateHeight:(uint32_t)updateHeight simplifiedMasternodeEntryHash:(UInt256)simplifiedMasternodeEntryHash previousSimplifiedMasternodeEntryHashes:(NSDictionary<DSBlock *, NSData *> *)previousSimplifiedMasternodeEntryHashes onChain:(DSChain *)chain {
    DSSimplifiedMasternodeEntry *simplifiedMasternodeEntry = [[DSSimplifiedMasternodeEntry alloc] init];
    simplifiedMasternodeEntry.providerRegistrationTransactionHash = providerRegistrationTransactionHash;
    simplifiedMasternodeEntry.confirmedHash = confirmedHash;
    simplifiedMasternodeEntry.address = address;
    simplifiedMasternodeEntry.port = port;
    simplifiedMasternodeEntry.keyIDVoting = keyIDVoting;
    simplifiedMasternodeEntry.operatorPublicKey = operatorBLSPublicKey;
    simplifiedMasternodeEntry.operatorPublicKeyVersion = operatorPublicKeyVersion;
    simplifiedMasternodeEntry.isValid = isValid;
    simplifiedMasternodeEntry.knownConfirmedAtHeight = knownConfirmedAtHeight;
    simplifiedMasternodeEntry.updateHeight = updateHeight;
    simplifiedMasternodeEntry.simplifiedMasternodeEntryHash = uint256_is_not_zero(simplifiedMasternodeEntryHash) ? simplifiedMasternodeEntryHash : [simplifiedMasternodeEntry calculateSimplifiedMasternodeEntryHash];
    simplifiedMasternodeEntry.chain = chain;
    simplifiedMasternodeEntry.previousOperatorPublicKeys = previousOperatorBLSPublicKeys ? [previousOperatorBLSPublicKeys copy] : [NSDictionary dictionary];
    simplifiedMasternodeEntry.previousSimplifiedMasternodeEntryHashes = previousSimplifiedMasternodeEntryHashes ? [previousSimplifiedMasternodeEntryHashes copy] : [NSDictionary dictionary];
    simplifiedMasternodeEntry.previousValidity = previousValidity ? [previousValidity copy] : [NSDictionary dictionary];
    return simplifiedMasternodeEntry;
}

- (BOOL)isValidAtBlock:(DSBlock *)block {
    if (!block || block.height == UINT32_MAX) {
        NSAssert(NO, @"Block should be set");
        return self.isValid;
    }
    if (![self.previousValidity count]) return self.isValid;
    return [self isValidAtBlockHeight:block.height];
}

- (BOOL)isValidAtBlockHash:(UInt256)blockHash {
    if (![self.previousValidity count]) return self.isValid;
    uint32_t blockHeight = [self.chain heightForBlockHash:blockHash];
    return [self isValidAtBlockHeight:blockHeight];
}

- (BOOL)isValidAtBlockHash:(UInt256)blockHash usingBlockHeightLookup:(BlockHeightFinder)blockHeightLookup {
    if (![self.previousValidity count]) return self.isValid;
    uint32_t blockHeight = blockHeightLookup(blockHash);
    return [self isValidAtBlockHeight:blockHeight];
}

- (BOOL)isValidAtBlockHeight:(uint32_t)blockHeight {
    if (![self.previousValidity count]) return self.isValid;
    NSAssert(blockHeight != UINT32_MAX, @"block height should be set");
    if (blockHeight == UINT32_MAX) {
        return self.isValid;
    }
    NSDictionary<DSBlock *, NSNumber *> *previousValidity = self.previousValidity;
    uint32_t minDistance = UINT32_MAX;
    BOOL isValid = self.isValid;
    for (DSBlock *previousBlock in previousValidity) {
        if (previousBlock.height <= blockHeight) continue;
        uint32_t distance = previousBlock.height - blockHeight;
        if (distance < minDistance) {
            minDistance = distance;
            DSDSMNELog(@"Validity for proTxHash %@ : Using %@ instead of %@ for list at block height %u (previousBlock.height %u)", uint256_hex(self.providerRegistrationTransactionHash), previousValidity[previousBlock].boolValue ? @"YES" : @"NO", isValid ? @"YES" : @"NO", blockHeight, previousBlock.height);
            isValid = [previousValidity[previousBlock] boolValue];
        }
    }
    return isValid;
}

- (UInt256)simplifiedMasternodeEntryHashAtBlock:(DSBlock *)block {
    if (!block || block.height == UINT32_MAX) {
        NSAssert(NO, @"Block should be set");
        return self.simplifiedMasternodeEntryHash;
    }
    if (![self.previousSimplifiedMasternodeEntryHashes count]) return self.simplifiedMasternodeEntryHash;
    return [self simplifiedMasternodeEntryHashAtBlockHeight:block.height];
}

- (UInt256)simplifiedMasternodeEntryHashAtBlockHash:(UInt256)blockHash {
    if (![self.previousSimplifiedMasternodeEntryHashes count]) return self.simplifiedMasternodeEntryHash;
    uint32_t blockHeight = [self.chain heightForBlockHash:blockHash];
    return [self simplifiedMasternodeEntryHashAtBlockHeight:blockHeight];
}

- (UInt256)simplifiedMasternodeEntryHashAtBlockHash:(UInt256)blockHash usingBlockHeightLookup:(BlockHeightFinder)blockHeightLookup {
    if (![self.previousSimplifiedMasternodeEntryHashes count]) return self.simplifiedMasternodeEntryHash;
    uint32_t blockHeight = blockHeightLookup(blockHash);
    return [self simplifiedMasternodeEntryHashAtBlockHeight:blockHeight];
}

- (UInt256)simplifiedMasternodeEntryHashAtBlockHeight:(uint32_t)blockHeight {
    if (![self.previousSimplifiedMasternodeEntryHashes count]) return self.simplifiedMasternodeEntryHash;
    NSAssert(blockHeight != UINT32_MAX, @"block height should be set");
    if (blockHeight == UINT32_MAX) {
        return self.simplifiedMasternodeEntryHash;
    }
    NSDictionary<DSBlock *, NSData *> *previousSimplifiedMasternodeEntryHashes = self.previousSimplifiedMasternodeEntryHashes;
    uint32_t minDistance = UINT32_MAX;
    UInt256 usedSimplifiedMasternodeEntryHash = self.simplifiedMasternodeEntryHash;
    for (DSBlock *previousBlock in previousSimplifiedMasternodeEntryHashes) {
        //NSLog(@"simplifiedMasternodeEntryHashAtBlockHeight: %u %@: prev: %u: %@", blockHeight, uint256_hex(usedSimplifiedMasternodeEntryHash), previousBlock.height, uint256_hex(previousSimplifiedMasternodeEntryHashes[previousBlock].UInt256));
        if (previousBlock.height <= blockHeight) continue;
        uint32_t distance = previousBlock.height - blockHeight;
        if (distance < minDistance) {
            minDistance = distance;
            NSLog(@"SME Hash for proTxHash %@ : Using %@ instead of %@ for list at block height %u", uint256_hex(self.providerRegistrationTransactionHash), uint256_hex(previousSimplifiedMasternodeEntryHashes[previousBlock].UInt256), uint256_hex(usedSimplifiedMasternodeEntryHash), blockHeight);
            usedSimplifiedMasternodeEntryHash = previousSimplifiedMasternodeEntryHashes[previousBlock].UInt256;
        }
    }
    return usedSimplifiedMasternodeEntryHash;
}

- (UInt384)operatorPublicKeyAtBlock:(DSBlock *)block {
    if (!block || block.height == UINT32_MAX) {
        NSAssert(NO, @"Block should be set");
        return self.operatorPublicKey;
    }
    if (![self.previousOperatorPublicKeys count]) return self.operatorPublicKey;
    return [self operatorPublicKeyAtBlockHeight:block.height];
}

- (UInt384)operatorPublicKeyAtBlockHash:(UInt256)blockHash {
    if (![self.previousOperatorPublicKeys count]) return self.operatorPublicKey;
    uint32_t blockHeight = [self.chain heightForBlockHash:blockHash];
    return [self operatorPublicKeyAtBlockHeight:blockHeight];
}

- (UInt384)operatorPublicKeyAtBlockHash:(UInt256)blockHash usingBlockHeightLookup:(BlockHeightFinder)blockHeightLookup {
    if (![self.previousOperatorPublicKeys count]) return self.operatorPublicKey;
    uint32_t blockHeight = blockHeightLookup(blockHash);
    return [self operatorPublicKeyAtBlockHeight:blockHeight];
}

- (UInt384)operatorPublicKeyAtBlockHeight:(uint32_t)blockHeight {
    if (![self.previousOperatorPublicKeys count]) return self.operatorPublicKey;
    NSDictionary<DSBlock *, NSData *> *previousOperatorPublicKeyAtBlockHashes = self.previousOperatorPublicKeys;
    uint32_t minDistance = UINT32_MAX;
    UInt384 usedPreviousOperatorPublicKeyAtBlockHash = self.operatorPublicKey;
    for (DSBlock *previousBlock in previousOperatorPublicKeyAtBlockHashes) {
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

- (UInt256)confirmedHashAtBlock:(DSBlock *)block {
    if (!block || block.height == UINT32_MAX) {
        NSAssert(NO, @"Block should be set");
        return self.confirmedHash;
    }
    if (!self.knownConfirmedAtHeight) return self.confirmedHash;
    return [self confirmedHashAtBlockHeight:block.height];
}

- (UInt256)confirmedHashAtBlockHash:(UInt256)blockHash {
    if (!self.knownConfirmedAtHeight) return self.confirmedHash;
    uint32_t blockHeight = [self.chain heightForBlockHash:blockHash];
    return [self confirmedHashAtBlockHeight:blockHeight];
}

- (UInt256)confirmedHashAtBlockHash:(UInt256)blockHash usingBlockHeightLookup:(BlockHeightFinder)blockHeightLookup {
    if (!self.knownConfirmedAtHeight) return self.confirmedHash;
    uint32_t blockHeight = blockHeightLookup(blockHash);
    return [self confirmedHashAtBlockHeight:blockHeight];
}

- (UInt256)confirmedHashAtBlockHeight:(uint32_t)blockHeight {
    if (!self.knownConfirmedAtHeight) return self.confirmedHash;
    if (self.knownConfirmedAtHeight > blockHeight) {
        return UINT256_ZERO;
    } else {
        return self.confirmedHash;
    }
}

- (UInt256)confirmedHashHashedWithProviderRegistrationTransactionHashAtBlockHeight:(uint32_t)blockHeight {
    if (!self.knownConfirmedAtHeight) return self.confirmedHashHashedWithProviderRegistrationTransactionHash;
    if (self.knownConfirmedAtHeight > blockHeight) {
        return [DSSimplifiedMasternodeEntry hashConfirmedHash:UINT256_ZERO withProviderRegistrationTransactionHash:self.providerRegistrationTransactionHash];
    } else {
        return self.confirmedHashHashedWithProviderRegistrationTransactionHash;
    }
}

- (void)setConfirmedHash:(UInt256)confirmedHash {
    _confirmedHash = confirmedHash;
    if (uint256_is_not_zero(self.providerRegistrationTransactionHash)) {
        [self updateConfirmedHashHashedWithProviderRegistrationTransactionHash];
    }
}

- (void)setProviderRegistrationTransactionHash:(UInt256)providerRegistrationTransactionHash {
    _providerRegistrationTransactionHash = providerRegistrationTransactionHash;
    if (uint256_is_not_zero(self.confirmedHash)) {
        [self updateConfirmedHashHashedWithProviderRegistrationTransactionHash];
    }
}

+ (UInt256)hashConfirmedHash:(UInt256)confirmedHash withProviderRegistrationTransactionHash:(UInt256)providerRegistrationTransactionHash {
    NSMutableData *combinedData = [NSMutableData data];
    NSData *confirmedHashData = [NSData dataWithUInt256:confirmedHash];
    NSData *providerRegistrationTransactionHashData = [NSData dataWithUInt256:providerRegistrationTransactionHash];
    [combinedData appendData:providerRegistrationTransactionHashData];
    [combinedData appendData:confirmedHashData];
    NSData *confirmedHashHashedWithProviderRegistrationTransactionHashData = [NSData dataWithUInt256:combinedData.SHA256];
    return confirmedHashHashedWithProviderRegistrationTransactionHashData.UInt256;
}

- (void)updateConfirmedHashHashedWithProviderRegistrationTransactionHash {
    self.confirmedHashHashedWithProviderRegistrationTransactionHash = [DSSimplifiedMasternodeEntry hashConfirmedHash:self.confirmedHash withProviderRegistrationTransactionHash:self.providerRegistrationTransactionHash];
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
    } else {
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
    return self.isValid ? DSLocalizedString(@"Up", @"The server is up and running") : DSLocalizedString(@"Down", @"The server is not working");
}

- (NSString *)uniqueID {
    return [NSData dataWithUInt256:self.providerRegistrationTransactionHash].shortHexString;
}

- (DSSimplifiedMasternodeEntryEntity *)simplifiedMasternodeEntryEntityInContext:(NSManagedObjectContext *)context {
    DSSimplifiedMasternodeEntryEntity *simplifiedMasternodeEntryEntity = [DSSimplifiedMasternodeEntryEntity anyObjectInContext:context matching:@"providerRegistrationTransactionHash = %@", [NSData dataWithUInt256:self.providerRegistrationTransactionHash]];
    return simplifiedMasternodeEntryEntity;
}

//- (DSBLSKey *)operatorPublicBLSKey {
//    if (!_operatorPublicBLSKey && !uint384_is_zero(self.operatorPublicKey)) {
//        _operatorPublicBLSKey = [DSBLSKey keyWithPublicKey:self.operatorPublicKey];
//    }
//    return _operatorPublicBLSKey;
//}

//- (BOOL)verifySignature:(UInt768)signature forMessageDigest:(UInt256)messageDigest {
//    DSBLSKey *operatorPublicBLSKey = [self operatorPublicBLSKey];
//    if (!operatorPublicBLSKey) return NO;
//    return [operatorPublicBLSKey verify:messageDigest signature:signature];
//}

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
    } else if (uint256_eq(self.providerRegistrationTransactionHash, entry.providerRegistrationTransactionHash)) {
        return YES;
    } else {
        return NO;
    }
}

- (NSUInteger)hash {
    return self.providerRegistrationTransactionHash.u64[0];
}

- (NSDictionary *)toDictionaryAtBlockHash:(UInt256)blockHash usingBlockHeightLookup:(BlockHeightFinder)blockHeightLookup {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];

    dictionary[@"address"] = [uint128_data(_address) base64String];
    dictionary[@"port"] = @(_port);

    UInt384 ourOperatorPublicKeyAtBlockHash = [self operatorPublicKeyAtBlockHash:blockHash usingBlockHeightLookup:blockHeightLookup];
    dictionary[@"operatorPublicKey"] = [uint384_data(ourOperatorPublicKeyAtBlockHash) base64String];
    dictionary[@"keyIDVoting"] = [uint160_data(_keyIDVoting) base64String];


    BOOL ourIsValid = [self isValidAtBlockHash:blockHash usingBlockHeightLookup:blockHeightLookup];
    dictionary[@"isValid"] = ourIsValid ? @"YES" : @"NO";


    UInt256 ourSimplifiedMasternodeEntryHash = [self simplifiedMasternodeEntryHashAtBlockHash:blockHash usingBlockHeightLookup:blockHeightLookup];
    dictionary[@"simplifiedMasternodeEntryHashAtBlockHash"] = @{@"SimplifiedMasternodeEntryHash": uint256_base64(ourSimplifiedMasternodeEntryHash), @"blockHeight": @(blockHeightLookup(blockHash))};
    dictionary[@"previousSimplifiedMasternodeEntryHashes"] = @{@"PreviousSimplifiedMasternodeEntryHash": self.previousSimplifiedMasternodeEntryHashes};
    dictionary[@"previousValidity"] = self.previousValidity;
    dictionary[@"previousOperatorPublicKeys"] = self.previousOperatorPublicKeys;
    dictionary[@"confirmedHash"] = uint256_base64(_confirmedHash);

    return dictionary;
}

- (NSDictionary *)compare:(DSSimplifiedMasternodeEntry *)other ourBlockHash:(UInt256)ourBlockHash theirBlockHash:(UInt256)theirBlockHash {
    return [self compare:other ourBlockHash:ourBlockHash theirBlockHash:theirBlockHash usingOurString:@"ours" usingTheirString:@"theirs"];
}

- (NSDictionary *)compare:(DSSimplifiedMasternodeEntry *)other ourBlockHash:(UInt256)ourBlockHash theirBlockHash:(UInt256)theirBlockHash usingOurString:(NSString *)ours usingTheirString:(NSString *)theirs {
    return [self compare:other
             ourBlockHash:ourBlockHash
           theirBlockHash:theirBlockHash
           usingOurString:ours
         usingTheirString:theirs
        blockHeightLookup:^uint32_t(UInt256 blockHash) {
            return [self.chain heightForBlockHash:blockHash];
        }];
}

- (NSDictionary *)compare:(DSSimplifiedMasternodeEntry *)other ourBlockHash:(UInt256)ourBlockHash theirBlockHash:(UInt256)theirBlockHash usingOurString:(NSString *)ours usingTheirString:(NSString *)theirs blockHeightLookup:(BlockHeightFinder)blockHeightLookup {
    NSMutableDictionary *differences = [NSMutableDictionary dictionary];

    if (!ours) ours = @"ours";
    if (!theirs) theirs = @"theirs";

    if (!uint128_eq(_address, other.address)) {
        differences[@"address"] = @{ours: uint128_data(_address), theirs: uint128_data(other.address)};
    }

    if (_port != other.port) {
        differences[@"port"] = @{ours: @(_port), theirs: @(other.port)};
    }

    UInt384 ourOperatorPublicKeyAtBlockHash = [self operatorPublicKeyAtBlockHash:ourBlockHash usingBlockHeightLookup:blockHeightLookup];
    UInt384 theirOperatorPublicKeyAtBlockHash = [other operatorPublicKeyAtBlockHash:theirBlockHash usingBlockHeightLookup:blockHeightLookup];

    if (!uint384_eq(ourOperatorPublicKeyAtBlockHash, theirOperatorPublicKeyAtBlockHash)) {
        differences[@"operatorPublicKey"] = @{ours: uint384_data(ourOperatorPublicKeyAtBlockHash), theirs: uint384_data(theirOperatorPublicKeyAtBlockHash)};
    }

    if (!uint160_eq(_keyIDVoting, other.keyIDVoting)) {
        differences[@"keyIDVoting"] = @{ours: uint160_data(_keyIDVoting), theirs: uint160_data(other.keyIDVoting)};
    }

    BOOL ourIsValid = [self isValidAtBlockHash:ourBlockHash usingBlockHeightLookup:blockHeightLookup];
    BOOL theirIsValid = [other isValidAtBlockHash:theirBlockHash usingBlockHeightLookup:blockHeightLookup];

    if (ourIsValid != theirIsValid) {
        differences[@"isValid"] = @{ours: ourIsValid ? @"YES" : @"NO", theirs: theirIsValid ? @"YES" : @"NO"};
        differences[@"previousValidity"] = @{ours: self.previousValidity, theirs: other.previousValidity};
    }

    UInt256 ourSimplifiedMasternodeEntryHash = [self simplifiedMasternodeEntryHashAtBlockHash:ourBlockHash usingBlockHeightLookup:blockHeightLookup];
    UInt256 theirSimplifiedMasternodeEntryHash = [other simplifiedMasternodeEntryHashAtBlockHash:theirBlockHash usingBlockHeightLookup:blockHeightLookup];

    if (!uint256_eq(ourSimplifiedMasternodeEntryHash, theirSimplifiedMasternodeEntryHash)) {
        differences[@"simplifiedMasternodeEntryHashAtBlockHash"] = @{ours: uint256_hex(ourSimplifiedMasternodeEntryHash), theirs: uint256_hex(theirSimplifiedMasternodeEntryHash), @"ourBlockHeight": @(blockHeightLookup(ourBlockHash)), @"theirBlockHeight": @(blockHeightLookup(theirBlockHash))};
    }

    if (![self.previousSimplifiedMasternodeEntryHashes isEqualToDictionary:other.previousSimplifiedMasternodeEntryHashes]) {
        differences[@"previousSimplifiedMasternodeEntryHashes"] = @{ours: self.previousSimplifiedMasternodeEntryHashes, theirs: other.previousSimplifiedMasternodeEntryHashes};
    }

    if (![self.previousValidity isEqualToDictionary:other.previousValidity] && ourIsValid == theirIsValid) {
        differences[@"previousValidity"] = @{ours: self.previousValidity, theirs: other.previousValidity};
    }

    if (![self.previousOperatorPublicKeys isEqualToDictionary:other.previousOperatorPublicKeys]) {
        differences[@"previousOperatorPublicKeys"] = @{ours: self.previousOperatorPublicKeys, theirs: other.previousOperatorPublicKeys};
    }

    if (!uint256_eq(_confirmedHash, other.confirmedHash)) {
        differences[@"confirmedHash"] = @{ours: uint256_data(_confirmedHash), theirs: uint256_data(other.confirmedHash)};
    }

    return differences;
}

- (NSDictionary *)compare:(DSSimplifiedMasternodeEntry *)other atBlockHash:(UInt256)blockHash {
    return [self compare:other ourBlockHash:blockHash theirBlockHash:blockHash];
}

- (void)setPlatformPing:(uint64_t)platformPing at:(NSDate *)time {
    self.platformPing = platformPing;
    self.platformPingDate = time;
}

- (void)savePlatformPingInfoInContext:(NSManagedObjectContext *)context {
    DSSimplifiedMasternodeEntryEntity *masternodeEntity = [self simplifiedMasternodeEntryEntityInContext:context];
    masternodeEntity.platformPing = self.platformPing;
    masternodeEntity.platformPingDate = self.platformPingDate;
}

- (void)mergedWithSimplifiedMasternodeEntry:(DSSimplifiedMasternodeEntry *)masternodeEntry atBlockHeight:(uint32_t)blockHeight {
    if (self.updateHeight < blockHeight) {
        self.updateHeight = blockHeight;
        if (!uint128_eq(self.address, masternodeEntry.address)) {
            self.address = masternodeEntry.address;
        }
        if (!uint256_eq(self.confirmedHash, masternodeEntry.confirmedHash)) {
            self.confirmedHash = masternodeEntry.confirmedHash;
            self.knownConfirmedAtHeight = masternodeEntry.knownConfirmedAtHeight;
        }
        if (self.port != masternodeEntry.port) {
            self.port = masternodeEntry.port;
        }
        if (!uint160_eq(self.keyIDVoting, masternodeEntry.keyIDVoting)) {
            self.keyIDVoting = masternodeEntry.keyIDVoting;
        }
        if (!uint384_eq(self.operatorPublicKey, masternodeEntry.operatorPublicKey)) {
            self.operatorPublicKey = masternodeEntry.operatorPublicKey;
            self.operatorPublicKeyVersion = masternodeEntry.operatorPublicKeyVersion;
        }
        if (self.isValid != masternodeEntry.isValid) {
            self.isValid = masternodeEntry.isValid;
        }
        self.simplifiedMasternodeEntryHash = masternodeEntry.simplifiedMasternodeEntryHash;
        [self mergePreviousFieldsUsingSimplifiedMasternodeEntrysPreviousFields:masternodeEntry atBlockHeight:blockHeight];
    }
    else if (blockHeight < self.updateHeight) {
        [self mergePreviousFieldsUsingSimplifiedMasternodeEntrysPreviousFields:masternodeEntry atBlockHeight:blockHeight];
    }
}

- (NSDictionary<NSData *, id> *)blockHashDictionaryFromBlockDictionary:(NSDictionary<DSBlock *, id> *)blockHashDictionary {
    NSMutableDictionary *rDictionary = [NSMutableDictionary dictionary];
    for (DSBlock *block in blockHashDictionary) {
        NSData *blockHash = uint256_data(block.blockHash);
        if (blockHash) {
            rDictionary[blockHash] = blockHashDictionary[block];
        }
    }
    return rDictionary;
}

- (void)mergePreviousFieldsUsingSimplifiedMasternodeEntrysPreviousFields:(DSSimplifiedMasternodeEntry *)entry atBlockHeight:(uint32_t)blockHeight {
    //SimplifiedMasternodeEntryHashes
    NSDictionary *oldPreviousSimplifiedMasternodeEntryHashesDictionary = entry.previousSimplifiedMasternodeEntryHashes;
    if (oldPreviousSimplifiedMasternodeEntryHashesDictionary && oldPreviousSimplifiedMasternodeEntryHashesDictionary.count) {
        self.previousSimplifiedMasternodeEntryHashes = [NSDictionary mergeDictionary:self.previousSimplifiedMasternodeEntryHashes withDictionary:oldPreviousSimplifiedMasternodeEntryHashesDictionary];
    }

    //OperatorBLSPublicKeys
    NSDictionary *oldPreviousOperatorBLSPublicKeysDictionary = entry.previousOperatorPublicKeys;
    if (oldPreviousOperatorBLSPublicKeysDictionary && oldPreviousOperatorBLSPublicKeysDictionary.count) {
        self.previousOperatorPublicKeys = [NSDictionary mergeDictionary:self.previousOperatorPublicKeys withDictionary:oldPreviousOperatorBLSPublicKeysDictionary];
    }

    //MasternodeValidity
    NSDictionary *oldPreviousValidityDictionary = entry.previousValidity;
    if (oldPreviousValidityDictionary && oldPreviousValidityDictionary.count) {
        self.previousValidity = [NSDictionary mergeDictionary:self.previousValidity withDictionary:oldPreviousValidityDictionary];
    }

    if (uint256_is_not_zero(self.confirmedHash) && uint256_is_not_zero(entry.confirmedHash) && (self.knownConfirmedAtHeight > blockHeight)) {
        //we now know it was confirmed earlier so update to earlier
        self.knownConfirmedAtHeight = blockHeight;
    }

}

@end
