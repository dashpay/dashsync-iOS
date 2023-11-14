//
//  DSProviderRegistrationTransaction.m
//  DashSync
//
//  Created by Sam Westrich on 2/9/19.
//

#import "DSProviderRegistrationTransaction.h"
#import "DSChain+Protected.h"
#import "DSChainManager+Protected.h"
#import "DSMasternodeManager+LocalMasternode.h"
#import "DSProviderRegistrationTransactionEntity+CoreDataClass.h"
#import "DSTransactionFactory.h"
#import "DSTransactionInput.h"
#import "DSTransactionOutput.h"
#import "NSData+Dash.h"
#import "NSMutableData+Dash.h"
#import "NSString+Dash.h"
#include <arpa/inet.h>

@interface DSProviderRegistrationTransaction ()

@end

@implementation DSProviderRegistrationTransaction

- (instancetype)initWithMessage:(NSData *)message onChain:(DSChain *)chain {
    if (!(self = [super initWithMessage:message onChain:chain])) return nil;
    self.type = DSTransactionType_ProviderRegistration;
    NSUInteger length = message.length;
    uint32_t off = self.payloadOffset;

    if (length - off < 1) return nil;
    NSNumber *payloadLengthSize = nil;
    uint64_t payloadLength = [message varIntAtOffset:off length:&payloadLengthSize];
    off += payloadLengthSize.unsignedLongValue;

    if (length - off < 2) return nil;
    self.providerRegistrationTransactionVersion = [message UInt16AtOffset:off];
    off += 2;

    if (length - off < 2) return nil;
    self.providerType = [message UInt16AtOffset:off];
    off += 2;

    if (length - off < 2) return nil;
    self.providerMode = [message UInt16AtOffset:off];
    off += 2;

    if (length - off < 36) return nil;
    self.collateralOutpoint = (DSUTXO){.hash = [message UInt256AtOffset:off], .n = [message UInt32AtOffset:off + 32]};
    off += 36;

    if (length - off < 16) return nil;
    self.ipAddress = [message UInt128AtOffset:off];
    off += 16;

    if (length - off < 2) return nil;
    self.port = CFSwapInt16HostToBig([message UInt16AtOffset:off]);
    off += 2;

    if (length - off < 20) return nil;
    self.ownerKeyHash = [message UInt160AtOffset:off];
    off += 20;

    if (length - off < 48) return nil;
    self.operatorKey = [message UInt384AtOffset:off];
    off += 48;
    
    if (length - off < 20) return nil;
    self.votingKeyHash = [message UInt160AtOffset:off];
    off += 20;

    if (length - off < 2) return nil;
    self.operatorReward = [message UInt16AtOffset:off];
    off += 2;

    NSNumber *scriptPayoutLength = nil;
    self.scriptPayout = [message dataAtOffset:off length:&scriptPayoutLength];
    off += scriptPayoutLength.unsignedIntegerValue;

    if (length - off < 32) return nil;
    self.inputsHash = [message UInt256AtOffset:off];
    off += 32;
    
    if ([self usesBasicBLS] && [self usesHPMN]) {
        if (length - off < 20) return nil;
        self.platformNodeID = [message UInt160AtOffset:off];
        off += 20;
        if (length - off < 2) return nil;
        self.platformP2PPort = CFSwapInt16HostToBig([message UInt16AtOffset:off]);
        off += 2;
        if (length - off < 2) return nil;
        self.platformHTTPPort = CFSwapInt16HostToBig([message UInt16AtOffset:off]);
        off += 2;
    }
    
    if (length - off < 1) return nil;
    NSNumber *messageSignatureSizeLength = nil;
    NSUInteger messageSignatureSize = (NSUInteger)[message varIntAtOffset:off length:&messageSignatureSizeLength];
    off += messageSignatureSizeLength.unsignedIntegerValue;
    if (length - off < messageSignatureSize) return nil;
    self.payloadSignature = [message subdataWithRange:NSMakeRange(off, messageSignatureSize)];
    off += messageSignatureSize;
    self.payloadOffset = off;

    //todo verify inputs hash

    if ([self payloadData].length != payloadLength) return nil;
    self.txHash = self.data.SHA256_2;

    return self;
}


- (instancetype)initWithProviderRegistrationTransactionVersion:(uint16_t)version type:(uint16_t)providerType mode:(uint16_t)providerMode collateralOutpoint:(DSUTXO)collateralOutpoint ipAddress:(UInt128)ipAddress port:(uint16_t)port ownerKeyHash:(UInt160)ownerKeyHash operatorKey:(UInt384)operatorKey operatorKeyVersion:(uint16_t)operatorKeyVersion votingKeyHash:(UInt160)votingKeyHash platformNodeID:(UInt160)platformNodeID operatorReward:(uint16_t)operatorReward scriptPayout:(NSData *)scriptPayout onChain:(DSChain *)chain {
    NSParameterAssert(scriptPayout);
    NSParameterAssert(chain);

    if (!(self = [super initOnChain:chain])) return nil;
    self.type = DSTransactionType_ProviderRegistration;
    self.version = SPECIAL_TX_VERSION;
    self.providerRegistrationTransactionVersion = version;
    self.providerType = providerType;
    self.providerMode = providerMode;
    self.ipAddress = ipAddress;
    self.collateralOutpoint = collateralOutpoint;
    self.port = port;
    self.ownerKeyHash = ownerKeyHash;
    self.operatorKey = operatorKey;
    self.operatorKeyVersion = operatorKeyVersion;
    self.votingKeyHash = votingKeyHash;
    self.platformNodeID = platformNodeID;
    self.operatorReward = operatorReward;
    self.scriptPayout = scriptPayout;
    DSLogPrivate(@"Creating provider (masternode) with ownerKeyHash %@", uint160_data(ownerKeyHash));
    return self;
}

- (instancetype)initWithInputHashes:(NSArray *)hashes inputIndexes:(NSArray *)indexes inputScripts:(NSArray *)scripts inputSequences:(NSArray *)inputSequences outputAddresses:(NSArray *)addresses outputAmounts:(NSArray *)amounts providerRegistrationTransactionVersion:(uint16_t)version type:(uint16_t)providerType mode:(uint16_t)providerMode collateralOutpoint:(DSUTXO)collateralOutpoint ipAddress:(UInt128)ipAddress port:(uint16_t)port ownerKeyHash:(UInt160)ownerKeyHash operatorKey:(UInt384)operatorKey operatorKeyVersion:(uint16_t)operatorKeyVersion votingKeyHash:(UInt160)votingKeyHash operatorReward:(uint16_t)operatorReward scriptPayout:(NSData *)scriptPayout onChain:(DSChain *_Nonnull)chain {
    NSParameterAssert(hashes);
    NSParameterAssert(indexes);
    NSParameterAssert(scripts);
    NSParameterAssert(inputSequences);
    NSParameterAssert(addresses);
    NSParameterAssert(amounts);
    NSParameterAssert(scriptPayout);
    NSParameterAssert(chain);

    if (!(self = [super initWithInputHashes:hashes inputIndexes:indexes inputScripts:scripts inputSequences:inputSequences outputAddresses:addresses outputAmounts:amounts onChain:chain])) return nil;
    self.type = DSTransactionType_ProviderRegistration;
    self.version = SPECIAL_TX_VERSION;
    self.providerRegistrationTransactionVersion = version;
    self.providerType = providerType;
    self.providerMode = providerMode;
    self.collateralOutpoint = collateralOutpoint;
    self.ipAddress = ipAddress;
    self.port = port;
    self.ownerKeyHash = ownerKeyHash;
    self.operatorKey = operatorKey;
    self.operatorKeyVersion = operatorKeyVersion;
    self.votingKeyHash = votingKeyHash;
    self.operatorReward = operatorReward;
    self.scriptPayout = scriptPayout;
    [self hasSetInputsAndOutputs];

    DSLogPrivate(@"Creating provider (masternode) with ownerKeyHash %@", uint160_data(ownerKeyHash));
    return self;
}

- (UInt256)payloadHash {
    return [self payloadDataForHash].SHA256_2;
}

- (NSString *)payloadCollateralString {
    return [NSString stringWithFormat:@"%@|%d|%@|%@|%@", self.payoutAddress, self.operatorReward, self.ownerAddress, self.votingAddress, uint256_reverse_hex(self.payloadHash)];
}

- (UInt256)payloadCollateralDigest {
    return [DSKeyManager proRegTXPayloadCollateralDigest:[self payloadDataForHash]
                                            scriptPayout:self.scriptPayout
                                                  reward:self.operatorReward
                                            ownerKeyHash:self.ownerKeyHash
                                            voterKeyHash:self.votingKeyHash
                                               chainType:self.chain.chainType].UInt256;
}

- (BOOL)checkPayloadSignature {
    return [DSKeyManager verifyProRegTXPayloadSignature:self.payloadSignature
                                                payload:[self payloadDataForHash]
                                           ownerKeyHash:self.ownerKeyHash];
}

- (NSData *)basePayloadData {
    NSMutableData *data = [NSMutableData data];
    [data appendUInt16:self.providerRegistrationTransactionVersion]; //16
    [data appendUInt16:self.providerType];                           //32
    [data appendUInt16:self.providerMode];                           //48
    [data appendUTXO:self.collateralOutpoint];                       //84
    [data appendUInt128:self.ipAddress];                             //212
    [data appendUInt16:CFSwapInt16BigToHost(self.port)];             //228
    [data appendUInt160:self.ownerKeyHash];                          //388
    // TODO: check case with legacy/non-legacy
    [data appendUInt384:self.operatorKey];                           //772
    [data appendUInt160:self.votingKeyHash];                         //788
    [data appendUInt16:self.operatorReward];                         //804
    [data appendVarInt:self.scriptPayout.length];
    [data appendData:self.scriptPayout];
    [data appendUInt256:self.inputsHash];
    if ([self usesBasicBLS] && [self usesHPMN]) {
        [data appendUInt160:self.platformNodeID];
        [data appendUInt16:CFSwapInt16BigToHost(self.platformP2PPort)];
        [data appendUInt16:CFSwapInt16BigToHost(self.platformHTTPPort)];
    }
    return data;
}

- (NSData *)payloadDataForHash {
    NSMutableData *data = [NSMutableData data];
    [data appendData:[self basePayloadData]];
    return data;
}

- (NSData *)payloadData {
    NSMutableData *data = [NSMutableData data];
    [data appendData:[self basePayloadData]];
    [data appendUInt8:self.payloadSignature.length];
    [data appendData:self.payloadSignature];
    return data;
}

- (NSData *)toDataWithSubscriptIndex:(NSUInteger)subscriptIndex {
    @synchronized(self) {
        NSMutableData *data = [[super toDataWithSubscriptIndex:subscriptIndex] mutableCopy];
        [data appendCountedData:[self payloadData]];
        if (subscriptIndex != NSNotFound) [data appendUInt32:SIGHASH_ALL];
        return data;
    }
}


- (NSString *)ownerAddress {
    return [DSKeyManager addressFromHash160:self.ownerKeyHash forChain:self.chain];
}

- (NSString *)platformNodeAddress {
    return [DSKeyManager addressFromHash160:self.platformNodeID forChain:self.chain];
}

- (NSString *)operatorAddress {
    return [DSKeyManager addressWithPublicKeyData:uint384_data(self.operatorKey) forChain:self.chain];
}

- (NSString *)operatorKeyString {
    return uint384_hex(self.operatorKey);
}

- (NSString *)votingAddress {
    return [DSKeyManager addressFromHash160:self.votingKeyHash forChain:self.chain];
}

- (NSString *)holdingAddress {
    NSInteger index = [self masternodeOutputIndex];
    if (uint256_is_zero(self.collateralOutpoint.hash) && index != NSNotFound) {
        return [self outputs][index].address;
    } else {
        return nil;
    }
}

- (NSString *)payoutAddress {
    return [DSKeyManager addressWithScriptPubKey:self.scriptPayout forChain:self.chain];
}

- (NSString *)location {
    char s[INET6_ADDRSTRLEN];
    NSString *ipAddressString = @(inet_ntop(AF_INET, &self.ipAddress.u32[3], s, sizeof(s)));
    return [NSString stringWithFormat:@"%@:%hu", ipAddressString, self.port];
}

- (NSString *)coreRegistrationCommand {
    return [NSString stringWithFormat:@"protx register_prepare %@ %lu %@ %@ %@ %@ %hu %@", uint256_reverse_hex(self.collateralOutpoint.hash), self.collateralOutpoint.n, self.location, self.ownerAddress, self.operatorKeyString, self.votingAddress, self.operatorReward, self.payoutAddress];
}

- (size_t)size {
    @synchronized(self) {
        if (uint256_is_not_zero(self.txHash)) return self.data.length;
        return [super size] + [NSMutableData sizeOfVarInt:self.payloadData.length] + ([self basePayloadData].length + MAX_ECDSA_SIGNATURE_SIZE);
    }
}

- (Class)entityClass {
    return [DSProviderRegistrationTransactionEntity class];
}

- (void)updateInputsHash {
    NSMutableData *data = [NSMutableData data];
    for (DSTransactionInput *input in self.inputs) {
        [data appendUInt256:input.inputHash];
        [data appendUInt32:input.index];
    }
    self.inputsHash = [data SHA256_2];
}

- (void)hasSetInputsAndOutputs {
    [self updateInputsHash];
    if (dsutxo_is_zero(self.collateralOutpoint)) {
        NSInteger index = [self masternodeOutputIndex];
        if (index == NSNotFound)
            return;
        self.collateralOutpoint = (DSUTXO){.hash = UINT256_ZERO, .n = index};
        self.payloadSignature = [NSData data];
    }
}

- (DSLocalMasternode *)localMasternode {
    return [self.chain.chainManager.masternodeManager localMasternodeFromProviderRegistrationTransaction:self save:TRUE];
}

- (DSWallet *)masternodeHoldingWallet {
    return [self.chain walletContainingMasternodeHoldingAddressForProviderRegistrationTransaction:self foundAtIndex:nil];
}

- (NSUInteger)masternodeOutputIndex {
    // What if a masternode's cost is equal to smth another?
    return [self.outputs indexOfObjectPassingTest:^BOOL(DSTransactionOutput *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
        return obj.amount == MASTERNODE_COST;
    }];
}

- (BOOL)usesBasicBLS {
    return self.providerRegistrationTransactionVersion == 2;
}

- (BOOL)usesHPMN {
    return self.providerType == 1;
}

@end
