//
//  DSProviderUpdateServiceTransaction.m
//  DashSync
//
//  Created by Sam Westrich on 2/21/19.
//

#import "DSProviderUpdateServiceTransaction.h"
#import "DSBLSKey.h"
#import "DSChainManager.h"
#import "DSLocalMasternode.h"
#import "DSMasternodeManager.h"
#import "DSProviderRegistrationTransaction.h"
#import "DSProviderRegistrationTransactionEntity+CoreDataClass.h"
#import "DSProviderUpdateServiceTransactionEntity+CoreDataClass.h"
#import "DSTransactionFactory.h"
#import "DSTransactionInput.h"
#import "DSTransactionManager.h"
#import "NSData+Dash.h"
#import "NSMutableData+Dash.h"
#import "NSString+Bitcoin.h"
#import "NSString+Dash.h"

@interface DSProviderUpdateServiceTransaction ()

@property (nonatomic, strong) DSProviderRegistrationTransaction *providerRegistrationTransaction;

@end

@implementation DSProviderUpdateServiceTransaction

- (instancetype)initWithMessage:(NSData *)message onChain:(DSChain *)chain {
    if (!(self = [super initWithMessage:message onChain:chain])) return nil;
    self.type = DSTransactionType_ProviderUpdateService;
    NSUInteger length = message.length;
    uint32_t off = self.payloadOffset;

    if (length - off < 1) return nil;
    NSNumber *payloadLengthSize = nil;
    uint64_t payloadLength = [message varIntAtOffset:off length:&payloadLengthSize];
    off += payloadLengthSize.unsignedLongValue;

    if (length - off < 2) return nil;
    self.providerUpdateServiceTransactionVersion = [message UInt16AtOffset:off];
    off += 2;

    if (length - off < 32) return nil;
    self.providerRegistrationTransactionHash = [message UInt256AtOffset:off];
    off += 32;

    if (length - off < 16) return nil;
    self.ipAddress = [message UInt128AtOffset:off];
    off += 16;

    if (length - off < 2) return nil;
    self.port = CFSwapInt16HostToBig([message UInt16AtOffset:off]);
    off += 2;

    NSNumber *scriptPayoutLength = nil;
    self.scriptPayout = [message dataAtOffset:off length:&scriptPayoutLength];
    off += scriptPayoutLength.unsignedIntegerValue;

    if (length - off < 32) return nil;
    self.inputsHash = [message UInt256AtOffset:off];
    off += 32;

    if (length - off < 96) return nil;
    self.payloadSignature = [message subdataWithRange:NSMakeRange(off, 96)];
    off += 96;
    self.payloadOffset = off;

    //todo verify inputs hash

    if ([self payloadData].length != payloadLength) return nil;
    self.txHash = self.data.SHA256_2;

    return self;
}


- (instancetype)initWithInputHashes:(NSArray *)hashes inputIndexes:(NSArray *)indexes inputScripts:(NSArray *)scripts inputSequences:(NSArray *)inputSequences outputAddresses:(NSArray *)addresses outputAmounts:(NSArray *)amounts providerUpdateServiceTransactionVersion:(uint16_t)version providerTransactionHash:(UInt256)providerTransactionHash ipAddress:(UInt128)ipAddress port:(uint16_t)port scriptPayout:(NSData *)scriptPayout onChain:(DSChain *_Nonnull)chain {
    if (!(self = [super initWithInputHashes:hashes inputIndexes:indexes inputScripts:scripts inputSequences:inputSequences outputAddresses:addresses outputAmounts:amounts onChain:chain])) return nil;
    self.type = DSTransactionType_ProviderUpdateService;
    self.version = SPECIAL_TX_VERSION;
    self.providerUpdateServiceTransactionVersion = version;
    self.providerRegistrationTransactionHash = providerTransactionHash;
    self.ipAddress = ipAddress;
    self.port = port;
    self.scriptPayout = scriptPayout;
    return self;
}

- (instancetype)initWithProviderUpdateServiceTransactionVersion:(uint16_t)version providerTransactionHash:(UInt256)providerTransactionHash ipAddress:(UInt128)ipAddress port:(uint16_t)port scriptPayout:(NSData *)scriptPayout onChain:(DSChain *_Nonnull)chain {
    if (!(self = [super initOnChain:chain])) return nil;
    self.type = DSTransactionType_ProviderUpdateService;
    self.version = SPECIAL_TX_VERSION;
    self.providerUpdateServiceTransactionVersion = version;
    self.providerRegistrationTransactionHash = providerTransactionHash;
    self.ipAddress = ipAddress;
    self.port = port;
    self.scriptPayout = scriptPayout;
    return self;
}

- (void)setProviderRegistrationTransactionHash:(UInt256)providerTransactionHash {
    _providerRegistrationTransactionHash = providerTransactionHash;
    self.providerRegistrationTransaction = (DSProviderRegistrationTransaction *)[self.chain transactionForHash:self.providerRegistrationTransactionHash];
}

- (DSProviderRegistrationTransaction *)providerRegistrationTransaction {
    if (!_providerRegistrationTransaction) self.providerRegistrationTransaction = (DSProviderRegistrationTransaction *)[self.chain transactionForHash:self.providerRegistrationTransactionHash];
    return _providerRegistrationTransaction;
}

- (UInt256)payloadHash {
    return [self payloadDataForHash].SHA256_2;
}

- (BOOL)checkPayloadSignature {
    NSAssert(self.providerRegistrationTransaction, @"We need a provider registration transaction");
    return [self checkPayloadSignature:[DSBLSKey keyWithPublicKey:self.providerRegistrationTransaction.operatorKey]];
}

- (BOOL)checkPayloadSignature:(DSBLSKey *)publicKey {
    return [publicKey verify:[self payloadHash] signature:[self payloadSignature].UInt768];
}

- (void)signPayloadWithKey:(DSBLSKey *)privateKey {
    self.payloadSignature = [NSData dataWithUInt768:[privateKey signData:[self payloadDataForHash]]];
}

- (NSString *_Nullable)payoutAddress {
    if (self.scriptPayout.length == 0) {
        return nil; //no payout address
    } else {
        return [NSString addressWithScriptPubKey:self.scriptPayout onChain:self.providerRegistrationTransaction.chain];
    }
}

- (NSData *)basePayloadData {
    NSMutableData *data = [NSMutableData data];
    [data appendUInt16:self.providerUpdateServiceTransactionVersion];
    [data appendUInt256:self.providerRegistrationTransactionHash];
    [data appendUInt128:self.ipAddress];
    [data appendUInt16:CFSwapInt16BigToHost(self.port)];
    [data appendVarInt:self.scriptPayout.length];
    [data appendData:self.scriptPayout];
    [data appendUInt256:self.inputsHash];
    return data;
}

- (NSData *)payloadDataForHash {
    NSMutableData *data = [NSMutableData data];
    [data appendData:[self basePayloadData]];
    //no need to add 0 here
    return data;
}

- (NSData *)payloadData {
    NSMutableData *data = [NSMutableData data];
    [data appendData:[self basePayloadData]];
    [data appendData:self.payloadSignature];
    return data;
}

- (NSData *)toDataWithSubscriptIndex:(NSUInteger)subscriptIndex {
    NSMutableData *data = [[super toDataWithSubscriptIndex:subscriptIndex] mutableCopy];
    NSData *payloadData = [self payloadData];
    [data appendVarInt:payloadData.length];
    [data appendData:payloadData];
    if (subscriptIndex != NSNotFound) [data appendUInt32:SIGHASH_ALL];
    return data;
}


- (size_t)size {
    if (uint256_is_not_zero(self.txHash)) return self.data.length;
    return [super size] + [NSMutableData sizeOfVarInt:self.payloadData.length] + ([self basePayloadData].length + 96);
}

- (Class)entityClass {
    return [DSProviderUpdateServiceTransactionEntity class];
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
}

@end
