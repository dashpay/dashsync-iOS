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
#import "NSData+Bitcoin.h"
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
@property (nonatomic, assign) UInt160 keyIDVoting;
@property (nonatomic, assign) BOOL isValid;
@property (nonatomic, assign) uint32_t knownConfirmedAtHeight;
@property (nonatomic, assign) uint32_t updateHeight;
@property (nonatomic, strong) DSChain *chain;
@property (null_resettable, nonatomic, copy) NSString *host;
@property (null_resettable, nonatomic, copy) NSString *ipAddressString;
@property (null_resettable, nonatomic, copy) NSString *portString;
@property (nonatomic, strong) DSBLSKey *operatorPublicBLSKey;
@property (nonatomic, strong) NSMutableDictionary<DSBlock *, NSData *> *mPreviousOperatorPublicKeys;
@property (nonatomic, strong) NSMutableDictionary<DSBlock *, NSNumber *> *mPreviousValidity;
@property (nonatomic, strong) NSMutableDictionary<DSBlock *, NSData *> *mPreviousSimplifiedMasternodeEntryHashes;
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

+ (instancetype)simplifiedMasternodeEntryWithData:(NSData *)data atBlockHeight:(uint32_t)blockHeight onChain:(DSChain *)chain {
    return [[self alloc] initWithMessage:data atBlockHeight:blockHeight onChain:chain];
}

+ (instancetype)simplifiedMasternodeEntryWithProviderRegistrationTransactionHash:(UInt256)providerRegistrationTransactionHash confirmedHash:(UInt256)confirmedHash address:(UInt128)address port:(uint16_t)port operatorBLSPublicKey:(UInt384)operatorBLSPublicKey previousOperatorBLSPublicKeys:(NSDictionary<DSBlock *, NSData *> *)previousOperatorBLSPublicKeys keyIDVoting:(UInt160)keyIDVoting isValid:(BOOL)isValid previousValidity:(NSDictionary<DSBlock *, NSData *> *)previousValidity knownConfirmedAtHeight:(uint32_t)knownConfirmedAtHeight updateHeight:(uint32_t)updateHeight simplifiedMasternodeEntryHash:(UInt256)simplifiedMasternodeEntryHash previousSimplifiedMasternodeEntryHashes:(NSDictionary<DSBlock *, NSData *> *)previousSimplifiedMasternodeEntryHashes onChain:(DSChain *)chain {
    DSSimplifiedMasternodeEntry *simplifiedMasternodeEntry = [[DSSimplifiedMasternodeEntry alloc] init];
    simplifiedMasternodeEntry.providerRegistrationTransactionHash = providerRegistrationTransactionHash;
    simplifiedMasternodeEntry.confirmedHash = confirmedHash;
    simplifiedMasternodeEntry.address = address;
    simplifiedMasternodeEntry.port = port;
    simplifiedMasternodeEntry.keyIDVoting = keyIDVoting;
    simplifiedMasternodeEntry.operatorPublicKey = operatorBLSPublicKey;
    simplifiedMasternodeEntry.isValid = isValid;
    simplifiedMasternodeEntry.knownConfirmedAtHeight = knownConfirmedAtHeight;
    simplifiedMasternodeEntry.updateHeight = updateHeight;
    simplifiedMasternodeEntry.simplifiedMasternodeEntryHash = uint256_is_not_zero(simplifiedMasternodeEntryHash) ? simplifiedMasternodeEntryHash : [simplifiedMasternodeEntry calculateSimplifiedMasternodeEntryHash];
    simplifiedMasternodeEntry.chain = chain;
    simplifiedMasternodeEntry.mPreviousOperatorPublicKeys = previousOperatorBLSPublicKeys ? [previousOperatorBLSPublicKeys mutableCopy] : [NSMutableDictionary dictionary];
    simplifiedMasternodeEntry.mPreviousSimplifiedMasternodeEntryHashes = previousSimplifiedMasternodeEntryHashes ? [previousSimplifiedMasternodeEntryHashes mutableCopy] : [NSMutableDictionary dictionary];
    simplifiedMasternodeEntry.mPreviousValidity = previousValidity ? [previousValidity mutableCopy] : [NSMutableDictionary dictionary];
    return simplifiedMasternodeEntry;
}

- (instancetype)initWithMessage:(NSData *)message atBlockHeight:(uint32_t)blockHeight onChain:(DSChain *)chain {
    if (!(self = [super init])) return nil;
    NSUInteger length = message.length;
    NSUInteger offset = 0;
    if (length - offset < 32) return nil;
    self.providerRegistrationTransactionHash = [message UInt256AtOffset:offset];
    offset += 32;

    if (length - offset < 32) return nil;
    self.confirmedHash = [message UInt256AtOffset:offset];
    offset += 32;

    if (uint256_is_not_zero(self.confirmedHash) && blockHeight != UINT32_MAX) {
        self.knownConfirmedAtHeight = blockHeight;
    }

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
    self.updateHeight = blockHeight;

    return self;
}

- (void)keepInfoOfPreviousEntryVersion:(DSSimplifiedMasternodeEntry *)masternodeEntry atBlockHash:(UInt256)blockHash atBlockHeight:(uint32_t)blockHeight {
    DSBlock *block = [self.chain blockForBlockHash:blockHash];
    if (!block) block = [[DSBlock alloc] initWithBlockHash:blockHash height:blockHeight onChain:self.chain];
    if (masternodeEntry.updateHeight < self.updateHeight) {
        [self updatePreviousValidity:masternodeEntry atBlock:block];
        [self updatePreviousOperatorPublicKeysFromPreviousSimplifiedMasternodeEntry:masternodeEntry atBlock:block];
        [self updatePreviousSimplifiedMasternodeEntryHashesFromPreviousSimplifiedMasternodeEntry:masternodeEntry atBlock:block];
        [self updateKnownConfirmedHashAtHeight:masternodeEntry atBlock:block];
    }
}

- (void)updateKnownConfirmedHashAtHeight:(DSSimplifiedMasternodeEntry *)masternodeEntry atBlock:(DSBlock *)block {
    //if the masternodeEntry.confirmedHash is not set we do not need to do anything
    //the knownConfirmedHashAtHeight will be higher
    //and
    //if the masternodeEntry.confirmedHash is set we might need to update our knownConfirmedAtHeight
    if (uint256_is_not_zero(masternodeEntry.confirmedHash) && (masternodeEntry.knownConfirmedAtHeight > block.height)) {
        //we found it confirmed at a previous height
        masternodeEntry.knownConfirmedAtHeight = block.height;
    }
}

- (void)updatePreviousValidity:(DSSimplifiedMasternodeEntry *)masternodeEntry atBlock:(DSBlock *)block {
    if (!uint256_eq(self.providerRegistrationTransactionHash, masternodeEntry.providerRegistrationTransactionHash)) return;
    self.mPreviousValidity = [NSMutableDictionary dictionary];
    //if for example we are getting a masternode list at block 402 when we already got the masternode list at block 414
    //then the other sme might have previousValidity that is in our future
    //we need to ignore them
    for (DSBlock *block in masternodeEntry.previousValidity) {
        if (block.height < self.updateHeight) {
            [self.mPreviousValidity setObject:masternodeEntry.previousValidity[block] forKey:block];
        }
    }
    if ([masternodeEntry isValidAtBlockHeight:self.updateHeight] != self.isValid) {
        //we changed validity
        DSDSMNELog(@"Changed validity from %u to %u on %@", masternodeEntry.isValid, self.isValid, uint256_hex(self.providerRegistrationTransactionHash));
        [self.mPreviousValidity setObject:@(masternodeEntry.isValid) forKey:block];
    }
}

- (void)updatePreviousOperatorPublicKeysFromPreviousSimplifiedMasternodeEntry:(DSSimplifiedMasternodeEntry *)masternodeEntry atBlock:(DSBlock *)block {
    if (!uint256_eq(self.providerRegistrationTransactionHash, masternodeEntry.providerRegistrationTransactionHash)) return;
    self.mPreviousOperatorPublicKeys = [NSMutableDictionary dictionary];
    //if for example we are getting a masternode list at block 402 when we already got the masternode list at block 414
    //then the other sme might have previousOperatorPublicKeys that is in our future
    //we need to ignore them
    for (DSBlock *pBlock in masternodeEntry.previousOperatorPublicKeys) {
        if (pBlock.height < self.updateHeight) {
            [self.mPreviousOperatorPublicKeys setObject:masternodeEntry.previousOperatorPublicKeys[pBlock] forKey:pBlock];
        }
    }
    if (!uint384_eq([masternodeEntry operatorPublicKeyAtBlockHeight:self.updateHeight], self.operatorPublicKey)) {
        //the operator public key changed
        DSDSMNELog(@"Changed sme operator keys from %@ to %@ on %@", uint384_hex(masternodeEntry.operatorPublicKey), uint384_hex(self.operatorPublicKey), uint256_hex(self.providerRegistrationTransactionHash));
        [self.mPreviousOperatorPublicKeys setObject:uint384_data(masternodeEntry.operatorPublicKey) forKey:block];
    }
}

- (void)updatePreviousSimplifiedMasternodeEntryHashesFromPreviousSimplifiedMasternodeEntry:(DSSimplifiedMasternodeEntry *)masternodeEntry atBlock:(DSBlock *)block {
    NSAssert(masternodeEntry, @"Masternode entry must be present");
    if (!uint256_eq(self.providerRegistrationTransactionHash, masternodeEntry.providerRegistrationTransactionHash)) return;
    self.mPreviousSimplifiedMasternodeEntryHashes = [NSMutableDictionary dictionary];
    //if for example we are getting a masternode list at block 402 when we already got the masternode list at block 414
    //then the other sme might have previousSimplifiedMasternodeEntryHashes that is in our future
    //we need to ignore them
    for (DSBlock *pBlock in masternodeEntry.previousSimplifiedMasternodeEntryHashes) {
        if (pBlock.height < self.updateHeight) {
            [self.mPreviousSimplifiedMasternodeEntryHashes setObject:masternodeEntry.previousSimplifiedMasternodeEntryHashes[pBlock] forKey:pBlock];
        }
    }
    if (!uint256_eq([masternodeEntry simplifiedMasternodeEntryHashAtBlockHeight:self.updateHeight], self.simplifiedMasternodeEntryHash)) {
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

- (BOOL)isValidAtBlockHash:(UInt256)blockHash usingBlockHeightLookup:(uint32_t (^)(UInt256 blockHash))blockHeightLookup {
    if (![self.previousValidity count]) return self.isValid;
    uint32_t blockHeight = blockHeightLookup(blockHash);
    return [self isValidAtBlockHeight:blockHeight];
}

- (BOOL)isValidAtBlockHeight:(uint32_t)blockHeight {
    if (![self.mPreviousValidity count]) return self.isValid;
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
    if (![self.mPreviousSimplifiedMasternodeEntryHashes count]) return self.simplifiedMasternodeEntryHash;
    return [self simplifiedMasternodeEntryHashAtBlockHeight:block.height];
}

- (UInt256)simplifiedMasternodeEntryHashAtBlockHash:(UInt256)blockHash {
    if (![self.mPreviousSimplifiedMasternodeEntryHashes count]) return self.simplifiedMasternodeEntryHash;
    uint32_t blockHeight = [self.chain heightForBlockHash:blockHash];
    return [self simplifiedMasternodeEntryHashAtBlockHeight:blockHeight];
}

- (UInt256)simplifiedMasternodeEntryHashAtBlockHash:(UInt256)blockHash usingBlockHeightLookup:(uint32_t (^)(UInt256 blockHash))blockHeightLookup {
    if (![self.mPreviousSimplifiedMasternodeEntryHashes count]) return self.simplifiedMasternodeEntryHash;
    uint32_t blockHeight = blockHeightLookup(blockHash);
    return [self simplifiedMasternodeEntryHashAtBlockHeight:blockHeight];
}

- (UInt256)simplifiedMasternodeEntryHashAtBlockHeight:(uint32_t)blockHeight {
    if (![self.mPreviousSimplifiedMasternodeEntryHashes count]) return self.simplifiedMasternodeEntryHash;
    NSAssert(blockHeight != UINT32_MAX, @"block height should be set");
    if (blockHeight == UINT32_MAX) {
        return self.simplifiedMasternodeEntryHash;
    }
    NSDictionary<DSBlock *, NSData *> *previousSimplifiedMasternodeEntryHashes = self.previousSimplifiedMasternodeEntryHashes;
    uint32_t minDistance = UINT32_MAX;
    UInt256 usedSimplifiedMasternodeEntryHash = self.simplifiedMasternodeEntryHash;
    for (DSBlock *previousBlock in previousSimplifiedMasternodeEntryHashes) {
        if (previousBlock.height <= blockHeight) continue;
        uint32_t distance = previousBlock.height - blockHeight;
        if (distance < minDistance) {
            minDistance = distance;
            DSDSMNELog(@"SME Hash for proTxHash %@ : Using %@ instead of %@ for list at block height %u", uint256_hex(self.providerRegistrationTransactionHash), uint256_hex(previousSimplifiedMasternodeEntryHashes[previousBlock].UInt256), uint256_hex(usedSimplifiedMasternodeEntryHash), blockHeight);
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
    if (![self.mPreviousOperatorPublicKeys count]) return self.operatorPublicKey;
    return [self operatorPublicKeyAtBlockHeight:block.height];
}

- (UInt384)operatorPublicKeyAtBlockHash:(UInt256)blockHash {
    if (![self.mPreviousOperatorPublicKeys count]) return self.operatorPublicKey;
    uint32_t blockHeight = [self.chain heightForBlockHash:blockHash];
    return [self operatorPublicKeyAtBlockHeight:blockHeight];
}

- (UInt384)operatorPublicKeyAtBlockHash:(UInt256)blockHash usingBlockHeightLookup:(uint32_t (^)(UInt256 blockHash))blockHeightLookup {
    if (![self.mPreviousOperatorPublicKeys count]) return self.operatorPublicKey;
    uint32_t blockHeight = blockHeightLookup(blockHash);
    return [self operatorPublicKeyAtBlockHeight:blockHeight];
}

- (UInt384)operatorPublicKeyAtBlockHeight:(uint32_t)blockHeight {
    if (![self.mPreviousOperatorPublicKeys count]) return self.operatorPublicKey;
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

- (UInt256)confirmedHashAtBlockHash:(UInt256)blockHash usingBlockHeightLookup:(uint32_t (^)(UInt256 blockHash))blockHeightLookup {
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

- (DSBLSKey *)operatorPublicBLSKey {
    if (!_operatorPublicBLSKey && !uint384_is_zero(self.operatorPublicKey)) {
        _operatorPublicBLSKey = [DSBLSKey keyWithPublicKey:self.operatorPublicKey];
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
    } else if (uint256_eq(self.providerRegistrationTransactionHash, entry.providerRegistrationTransactionHash)) {
        return YES;
    } else {
        return NO;
    }
}

- (NSUInteger)hash {
    return self.providerRegistrationTransactionHash.u64[0];
}

- (NSDictionary *)toDictionaryAtBlockHash:(UInt256)blockHash usingBlockHeightLookup:(uint32_t (^)(UInt256 blockHash))blockHeightLookup {
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

- (NSDictionary *)compare:(DSSimplifiedMasternodeEntry *)other ourBlockHash:(UInt256)ourBlockHash theirBlockHash:(UInt256)theirBlockHash usingOurString:(NSString *)ours usingTheirString:(NSString *)theirs blockHeightLookup:(uint32_t (^)(UInt256 blockHash))blockHeightLookup {
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

@end
