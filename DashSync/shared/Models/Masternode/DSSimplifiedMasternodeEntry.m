//
//  DSSimplifiedMasternodeEntry.m
//  DashSync
//
//  Created by Sam Westrich on 7/12/18.
//

#import "DSSimplifiedMasternodeEntry.h"
#import "DSBlock.h"
#import "DSChain+Params.h"
#import "DSKeyManager.h"
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
@property (nonatomic, assign) uint16_t type;
@property (nonatomic, assign) uint16_t platformHTTPPort;
@property (nonatomic, assign) UInt160 platformNodeID;
@property (nonatomic, assign) uint32_t knownConfirmedAtHeight;
@property (nonatomic, assign) uint32_t updateHeight;
@property (nonatomic, strong) DSChain *chain;
@property (null_resettable, nonatomic, copy) NSString *host;
@property (null_resettable, nonatomic, copy) NSString *ipAddressString;
@property (null_resettable, nonatomic, copy) NSString *portString;
@property (nonatomic, strong) NSDictionary<NSData *, NSData *> *previousOperatorPublicKeys;
@property (nonatomic, strong) NSDictionary<NSData *, NSNumber *> *previousValidity;
@property (nonatomic, strong) NSDictionary<NSData *, NSData *> *previousSimplifiedMasternodeEntryHashes;
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

+ (instancetype)simplifiedMasternodeEntryWithProviderRegistrationTransactionHash:(UInt256)providerRegistrationTransactionHash
                                                                   confirmedHash:(UInt256)confirmedHash
                                                                         address:(UInt128)address
                                                                            port:(uint16_t)port
                                                            operatorBLSPublicKey:(UInt384)operatorBLSPublicKey
                                                        operatorPublicKeyVersion:(uint16_t)operatorPublicKeyVersion
                                                   previousOperatorBLSPublicKeys:(NSDictionary<NSData *, NSData *> *)previousOperatorBLSPublicKeys
                                                                     keyIDVoting:(UInt160)keyIDVoting
                                                                         isValid:(BOOL)isValid
                                                                            type:(uint16_t)type
                                                                platformHTTPPort:(uint16_t)platformHTTPPort
                                                                  platformNodeID:(UInt160)platformNodeID
                                                                previousValidity:(NSDictionary<NSData *, NSNumber *> *)previousValidity
                                                          knownConfirmedAtHeight:(uint32_t)knownConfirmedAtHeight
                                                                    updateHeight:(uint32_t)updateHeight
                                                   simplifiedMasternodeEntryHash:(UInt256)simplifiedMasternodeEntryHash
                                         previousSimplifiedMasternodeEntryHashes:(NSDictionary<NSData *, NSData *> *)previousSimplifiedMasternodeEntryHashes
                                                                         onChain:(DSChain *)chain {
    DSSimplifiedMasternodeEntry *simplifiedMasternodeEntry = [[DSSimplifiedMasternodeEntry alloc] init];
    simplifiedMasternodeEntry.providerRegistrationTransactionHash = providerRegistrationTransactionHash;
    simplifiedMasternodeEntry.confirmedHash = confirmedHash;
    simplifiedMasternodeEntry.address = address;
    simplifiedMasternodeEntry.port = port;
    simplifiedMasternodeEntry.keyIDVoting = keyIDVoting;
    simplifiedMasternodeEntry.operatorPublicKey = operatorBLSPublicKey;
    simplifiedMasternodeEntry.operatorPublicKeyVersion = operatorPublicKeyVersion;
    simplifiedMasternodeEntry.isValid = isValid;
    simplifiedMasternodeEntry.type = type;
    simplifiedMasternodeEntry.platformHTTPPort = platformHTTPPort;
    simplifiedMasternodeEntry.platformNodeID = platformNodeID;
    simplifiedMasternodeEntry.knownConfirmedAtHeight = knownConfirmedAtHeight;
    simplifiedMasternodeEntry.updateHeight = updateHeight;
    simplifiedMasternodeEntry.simplifiedMasternodeEntryHash = uint256_is_not_zero(simplifiedMasternodeEntryHash) ? simplifiedMasternodeEntryHash : [simplifiedMasternodeEntry calculateSimplifiedMasternodeEntryHash];
    simplifiedMasternodeEntry.chain = chain;
    simplifiedMasternodeEntry.previousOperatorPublicKeys = previousOperatorBLSPublicKeys ? previousOperatorBLSPublicKeys : [NSDictionary dictionary];
    simplifiedMasternodeEntry.previousSimplifiedMasternodeEntryHashes = previousSimplifiedMasternodeEntryHashes ? previousSimplifiedMasternodeEntryHashes : [NSDictionary dictionary];
    simplifiedMasternodeEntry.previousValidity = previousValidity ? previousValidity : [NSDictionary dictionary];
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
    NSDictionary<NSData *, NSNumber *> *previousValidity = self.previousValidity;
    uint32_t minDistance = UINT32_MAX;
    BOOL isValid = self.isValid;
    for (NSData *previousBlock in previousValidity) {
        DSBlockInfo blockInfo = *(DSBlockInfo *)(previousBlock.bytes);
        uint32_t prevHeight = blockInfo.u32[8];
        if (prevHeight <= blockHeight) continue;
        uint32_t distance = prevHeight - blockHeight;
        if (distance < minDistance) {
            minDistance = distance;
            DSDSMNELog(@"Validity for proTxHash %@ : Using %@ instead of %@ for list at block height %u (previousBlock.height %u)", uint256_hex(self.providerRegistrationTransactionHash), previousValidity[previousBlock].boolValue ? @"YES" : @"NO", isValid ? @"YES" : @"NO", blockHeight, prevHeight);
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
    NSDictionary<NSData *, NSData *> *previousSimplifiedMasternodeEntryHashes = self.previousSimplifiedMasternodeEntryHashes;
    uint32_t minDistance = UINT32_MAX;
    UInt256 usedSimplifiedMasternodeEntryHash = self.simplifiedMasternodeEntryHash;
    for (NSData *previousBlock in previousSimplifiedMasternodeEntryHashes) {
        DSBlockInfo blockInfo = *(DSBlockInfo *)(previousBlock.bytes);
        uint32_t prevHeight = blockInfo.u32[8];
        if (prevHeight <= blockHeight) continue;
        uint32_t distance = prevHeight - blockHeight;
        if (distance < minDistance) {
            minDistance = distance;
            DSLog(@"[%@] SME Hash for proTxHash %@ : Using %@ instead of %@ for list at block height %u", self.chain.name,  uint256_hex(self.providerRegistrationTransactionHash), uint256_hex(*(UInt256 *)(blockInfo.u8)), uint256_hex(usedSimplifiedMasternodeEntryHash), blockHeight);
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
    NSDictionary<NSData *, NSData *> *previousOperatorPublicKeyAtBlockHashes = self.previousOperatorPublicKeys;
    uint32_t minDistance = UINT32_MAX;
    UInt384 usedPreviousOperatorPublicKeyAtBlockHash = self.operatorPublicKey;
    for (NSData *previousBlock in previousOperatorPublicKeyAtBlockHashes) {
        DSBlockInfo blockInfo = *(DSBlockInfo *)(previousBlock.bytes);
        uint32_t prevHeight = blockInfo.u32[8];
        if (prevHeight <= blockHeight) continue;
        uint32_t distance = prevHeight - blockHeight;
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
    u256 *confirmed_hash = u256_ctor_u(confirmedHash);
    u256 *provider_reg_tx_hash = u256_ctor_u(providerRegistrationTransactionHash);
    u256 *result = dash_spv_masternode_processor_models_masternode_entry_MasternodeEntry_hash_confirmed_hash(confirmed_hash, provider_reg_tx_hash);
    UInt256 hash = u256_cast(result);
    u256_dtor(result);
    return hash;
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

- (NSString *)votingAddress {
    return [DSKeyManager addressFromHash160:self.keyIDVoting forChain:self.chain];
}

- (NSString *)platformNodeAddress {
    return [DSKeyManager addressFromHash160:self.platformNodeID forChain:self.chain];
}

- (NSString *)operatorAddress {
    return [DSKeyManager addressWithPublicKeyData:uint384_data(self.operatorPublicKey) forChain:self.chain];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<DSSimplifiedMasternodeEntry: %@ {valid:%@}>", self.host, @(self.isValid)];
}

- (BOOL)isEqual:(id)other {
    DSSimplifiedMasternodeEntry *entry = (DSSimplifiedMasternodeEntry *)other;
    if (![other isKindOfClass:[DSSimplifiedMasternodeEntry class]]) return NO;
    return other == self || uint256_eq(self.providerRegistrationTransactionHash, entry.providerRegistrationTransactionHash);
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
    dictionary[@"isValid"] = [self isValidAtBlockHash:blockHash usingBlockHeightLookup:blockHeightLookup] ? @"YES" : @"NO";
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

//- (void)mergedWithSimplifiedMasternodeEntry:(DMasternodeEntry *)masternodeEntry atBlockHeight:(uint32_t)blockHeight {
//    if (self.updateHeight < blockHeight) {
//        self.updateHeight = blockHeight;
//        u128 *addr = u128_ctor_u(self.address);
//        BOOL addr_are_equal = dash_spv_masternode_processor_models_masternode_entry_MasternodeEntry_address_is_equal_to(masternodeEntry, addr);
//        u128_dtor(addr);
//        if (!addr_are_equal) {
//            self.address = *((UInt128 *)masternodeEntry->socket_address->ip_address);
//        }
//        u256 *confirmed_hash = u256_ctor_u(self.confirmedHash);
//        BOOL confirmed_hashes_are_equal = dash_spv_masternode_processor_models_masternode_entry_MasternodeEntry_confirmed_hash_is_equal_to(masternodeEntry, confirmed_hash);
//        u256_dtor(confirmed_hash);
//        if (!confirmed_hashes_are_equal) {
//            self.confirmedHash = *((UInt256 *)masternodeEntry->confirmed_hash->values);
//            self.knownConfirmedAtHeight = *(masternodeEntry->known_confirmed_at_height);
//        }
//        if (self.port != masternodeEntry->socket_address->port) {
//            self.port = masternodeEntry->socket_address->port;
//        }
//        u160 *key_id = u160_ctor_u(self.keyIDVoting);
//        BOOL key_ids_are_equal = dash_spv_masternode_processor_models_masternode_entry_MasternodeEntry_key_id_is_equal_to(masternodeEntry, key_id);
//        u160_dtor(key_id);
//        if (!key_ids_are_equal) {
//            self.keyIDVoting = *((UInt160 *)masternodeEntry->key_id_voting->values);
//        }
//        u384 *pub_key = u384_ctor_u(self.operatorPublicKey);
//        BOOL pubkeys_are_equal = dash_spv_masternode_processor_models_masternode_entry_MasternodeEntry_operator_pub_key_is_equal_to(masternodeEntry, pub_key);
//        u384_dtor(pub_key);
//        if (!pubkeys_are_equal) {
//            self.operatorPublicKey = *((UInt384 *)masternodeEntry->operator_public_key->data->values);
//            self.operatorPublicKeyVersion = masternodeEntry->operator_public_key->version;
//        }
//        if (self.isValid != masternodeEntry->is_valid) {
//            self.isValid = masternodeEntry->is_valid;
//        }
//        self.simplifiedMasternodeEntryHash = *((UInt256 *)masternodeEntry->entry_hash->values);
//        [self mergePreviousFieldsUsingSimplifiedMasternodeEntrysPreviousFields:masternodeEntry atBlockHeight:blockHeight];
//    }
//    else if (blockHeight < self.updateHeight) {
//        [self mergePreviousFieldsUsingSimplifiedMasternodeEntrysPreviousFields:masternodeEntry atBlockHeight:blockHeight];
//    }
//}

- (NSDictionary<NSData *, id> *)blockHashDictionaryFromBlockDictionary:(NSDictionary<NSData *, id> *)blockHashDictionary {
    NSMutableDictionary *rDictionary = [NSMutableDictionary dictionary];
    for (NSData *block in blockHashDictionary) {
        DSBlockInfo blockInfo = *(DSBlockInfo *)(block.bytes);
        UInt256 blockHash = *(UInt256 *)(blockInfo.u8);
        NSData *blockHashData = uint256_data(blockHash);
        if (blockHashData) {
            rDictionary[blockHashData] = blockHashDictionary[block];
        }
    }
    return rDictionary;
}

- (void)mergePreviousFieldsUsingSimplifiedMasternodeEntrysPreviousFields:(DMasternodeEntry *)entry
                                                           atBlockHeight:(uint32_t)blockHeight {
    std_collections_Map_keys_dash_spv_masternode_processor_common_block_Block_values_u8_arr_32 *prev_entry_hashes = entry->previous_entry_hashes;
    NSMutableDictionary *prevEntryHashes = [NSMutableDictionary dictionaryWithCapacity:prev_entry_hashes->count];
    for (int i = 0; i < prev_entry_hashes->count; i++) {
        DBlock *key = prev_entry_hashes->keys[i];
        NSMutableData *d = [NSMutableData dataWithBytes:key->hash->values length:32];
        [d appendUInt32:key->height];
        u256 *value = prev_entry_hashes->values[i];
        [prevEntryHashes setObject:NSDataFromPtr(value) forKey:d];
    }
    if (!self.previousSimplifiedMasternodeEntryHashes || [self.previousSimplifiedMasternodeEntryHashes count] == 0) {
        self.previousSimplifiedMasternodeEntryHashes = prevEntryHashes;
    } else {
        NSMutableDictionary *mergedDictionary = [self.previousSimplifiedMasternodeEntryHashes mutableCopy];
        [mergedDictionary addEntriesFromDictionary:prevEntryHashes];
        self.previousSimplifiedMasternodeEntryHashes = mergedDictionary;
    }
    std_collections_Map_keys_dash_spv_masternode_processor_common_block_Block_values_dash_spv_crypto_keys_operator_public_key_OperatorPublicKey *prev_operator_keys = entry->previous_operator_public_keys;
    NSMutableDictionary *prevOperatorKeys = [NSMutableDictionary dictionaryWithCapacity:prev_operator_keys->count];
    // TODO: key version lost here
    for (int i = 0; i < prev_operator_keys->count; i++) {
        DBlock *key = prev_operator_keys->keys[i];
        NSMutableData *d = [NSMutableData dataWithBytes:key->hash->values length:32];
        [d appendUInt32:key->height];
        dash_spv_crypto_keys_operator_public_key_OperatorPublicKey *value = prev_operator_keys->values[i];
        [prevOperatorKeys setObject:NSDataFromPtr(value->data) forKey:d];
    }
    if (!self.previousOperatorPublicKeys || [self.previousOperatorPublicKeys count] == 0) {
        self.previousOperatorPublicKeys = prevOperatorKeys;
    } else {
        NSMutableDictionary *mergedDictionary = [self.previousOperatorPublicKeys mutableCopy];
        [mergedDictionary addEntriesFromDictionary:prevOperatorKeys];
        self.previousOperatorPublicKeys = mergedDictionary;
    }
    std_collections_Map_keys_dash_spv_masternode_processor_common_block_Block_values_bool *prev_validity = entry->previous_validity;
    NSMutableDictionary *prevValidity = [NSMutableDictionary dictionaryWithCapacity:prev_validity->count];
    for (int i = 0; i < prev_validity->count; i++) {
        DBlock *key = prev_validity->keys[i];
        NSMutableData *d = [NSMutableData dataWithBytes:key->hash->values length:32];
        [d appendUInt32:key->height];
        bool value = prev_validity->values[i];
        [prevValidity setObject:@(value) forKey:d];
    }
    if (!self.previousValidity || [self.previousValidity count] == 0) {
        self.previousValidity = prevValidity;
    } else {
        NSMutableDictionary *mergedDictionary = [self.previousValidity mutableCopy];
        [mergedDictionary addEntriesFromDictionary:prevValidity];
        self.previousValidity = mergedDictionary;
    }

    
    
//    NSDictionary *oldPreviousSimplifiedMasternodeEntryHashesDictionary = entry.previousSimplifiedMasternodeEntryHashes;
//    if (oldPreviousSimplifiedMasternodeEntryHashesDictionary && oldPreviousSimplifiedMasternodeEntryHashesDictionary.count) {
//        self.previousSimplifiedMasternodeEntryHashes = [NSDictionary mergeDictionary:self.previousSimplifiedMasternodeEntryHashes withDictionary:oldPreviousSimplifiedMasternodeEntryHashesDictionary];
//    }
//
//    //OperatorBLSPublicKeys
//    NSDictionary *oldPreviousOperatorBLSPublicKeysDictionary = entry.previousOperatorPublicKeys;
//    if (oldPreviousOperatorBLSPublicKeysDictionary && oldPreviousOperatorBLSPublicKeysDictionary.count) {
//        self.previousOperatorPublicKeys = [NSDictionary mergeDictionary:self.previousOperatorPublicKeys withDictionary:oldPreviousOperatorBLSPublicKeysDictionary];
//    }
//
//    //MasternodeValidity
//    NSDictionary *oldPreviousValidityDictionary = entry.previousValidity;
//    if (oldPreviousValidityDictionary && oldPreviousValidityDictionary.count) {
//        self.previousValidity = [NSDictionary mergeDictionary:self.previousValidity withDictionary:oldPreviousValidityDictionary];
//    }
    
    if (uint256_is_not_zero(self.confirmedHash) && !u_is_zero(entry->confirmed_hash) && (self.knownConfirmedAtHeight > blockHeight)) {
        //we now know it was confirmed earlier so update to earlier
        self.knownConfirmedAtHeight = blockHeight;
    }

}

@end
