//
//  DSProviderUpdateRevocationTransaction.m
//  DashSync
//
//  Created by Sam Westrich on 2/26/19.
//

#import "DSProviderUpdateRevocationTransaction.h"
#import "DSChain+Transaction.h"
#import "DSChainManager.h"
#import "DSLocalMasternode.h"
#import "DSMasternodeManager.h"
#import "DSProviderRegistrationTransaction.h"
#import "DSProviderRegistrationTransactionEntity+CoreDataClass.h"
#import "DSProviderUpdateRevocationTransactionEntity+CoreDataClass.h"
#import "DSTransactionFactory.h"
#import "DSTransactionInput.h"
#import "DSTransactionManager.h"
#import "NSData+Dash.h"
#import "NSMutableData+Dash.h"
#import "NSString+Bitcoin.h"

@interface DSProviderUpdateRevocationTransaction ()

@property (nonatomic, strong) DSProviderRegistrationTransaction *providerRegistrationTransaction;

@end

@implementation DSProviderUpdateRevocationTransaction

- (instancetype)initWithMessage:(NSData *)message onChain:(DSChain *)chain {
    if (!(self = [super initWithMessage:message onChain:chain])) return nil;
    self.type = DSTransactionType_ProviderUpdateRevocation;
    NSUInteger length = message.length;
    uint32_t off = self.payloadOffset;

    if (length - off < 1) return nil;
    NSNumber *payloadLengthSize = nil;
    uint64_t payloadLength = [message varIntAtOffset:off length:&payloadLengthSize];
    off += payloadLengthSize.unsignedLongValue;

    if (length - off < 2) return nil;
    self.providerUpdateRevocationTransactionVersion = [message UInt16AtOffset:off];
    off += 2;

    if (length - off < 32) return nil;
    self.providerRegistrationTransactionHash = [message UInt256AtOffset:off];
    off += 32;

    if (length - off < 2) return nil;
    self.reason = [message UInt16AtOffset:off];
    off += 2;

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


- (instancetype)initWithInputHashes:(NSArray *)hashes inputIndexes:(NSArray *)indexes inputScripts:(NSArray *)scripts inputSequences:(NSArray *)inputSequences outputAddresses:(NSArray *)addresses outputAmounts:(NSArray *)amounts providerUpdateRevocationTransactionVersion:(uint16_t)version providerTransactionHash:(UInt256)providerTransactionHash reason:(uint16_t)reason onChain:(DSChain *_Nonnull)chain {
    if (!(self = [super initWithInputHashes:hashes inputIndexes:indexes inputScripts:scripts inputSequences:inputSequences outputAddresses:addresses outputAmounts:amounts onChain:chain])) return nil;
    self.type = DSTransactionType_ProviderUpdateRevocation;
    self.version = SPECIAL_TX_VERSION;
    self.providerUpdateRevocationTransactionVersion = version;
    self.providerRegistrationTransactionHash = providerTransactionHash;
    self.reason = reason;
    return self;
}

- (instancetype)initWithProviderUpdateRevocationTransactionVersion:(uint16_t)version providerTransactionHash:(UInt256)providerTransactionHash reason:(uint16_t)reason onChain:(DSChain *_Nonnull)chain {
    if (!(self = [super initOnChain:chain])) return nil;
    self.type = DSTransactionType_ProviderUpdateRevocation;
    self.version = SPECIAL_TX_VERSION;
    self.providerUpdateRevocationTransactionVersion = version;
    self.providerRegistrationTransactionHash = providerTransactionHash;
    self.reason = reason;
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
    u384 *pubkey = u384_ctor_u(self.providerRegistrationTransaction.operatorKey);
    Slice_u8 *digest = slice_u256_ctor_u([self payloadHash]);
    u768 *sig = u768_ctor([self payloadSignature]);
    BOOL verified = DBLSKeyVerifySig(pubkey, ![self.providerRegistrationTransaction usesBasicBLS], digest, sig);
    return verified;
}

- (BOOL)checkPayloadSignature:(DOpaqueKey *)publicKey {
    return [DSKeyManager verifyMessageDigest:publicKey digest:[self payloadHash] signature:[self payloadSignature]];
}

- (void)signPayloadWithKey:(DOpaqueKey *)privateKey {
    NSData *payload = [self payloadDataForHash];
    Slice_u8 *p = slice_ctor(payload);
    u768 *signed_data = DBLSKeySignData(privateKey->bls, p);
    self.payloadSignature = NSDataFromPtr(signed_data);
    u768_dtor(signed_data);
}

- (NSData *)basePayloadData {
    NSMutableData *data = [NSMutableData data];
    [data appendUInt16:self.providerUpdateRevocationTransactionVersion];
    [data appendUInt256:self.providerRegistrationTransactionHash];
    [data appendUInt16:self.reason];
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

- (NSData *)toDataWithSubscriptIndex:(NSUInteger)subscriptIndex
                        anyoneCanPay:(BOOL)anyoneCanPay {
    @synchronized(self) {
        NSMutableData *data = [[super toDataWithSubscriptIndex:subscriptIndex anyoneCanPay:anyoneCanPay] mutableCopy];
        [data appendCountedData:[self payloadData]];
        if (subscriptIndex != NSNotFound) [data appendUInt32:SIGHASH_ALL];
        return data;
    }
}

- (size_t)size {
    @synchronized(self) {
        if (uint256_is_not_zero(self.txHash)) return self.data.length;
        return [super size] + [NSMutableData sizeOfVarInt:self.payloadData.length] + ([self basePayloadData].length + 96);
    }
}

- (Class)entityClass {
    return [DSProviderUpdateRevocationTransactionEntity class];
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
