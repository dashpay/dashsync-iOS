//
//  DSCoinbaseTransaction.m
//  DashSync
//
//  Created by Sam Westrich on 7/12/18.
//

#import "DSCoinbaseTransaction.h"
#import "DSCoinbaseTransactionEntity+CoreDataClass.h"
#import "DSTransactionFactory.h"
#import "NSData+Dash.h"
#import "NSMutableData+Dash.h"

@implementation DSCoinbaseTransaction

- (instancetype)initWithMessage:(NSData *)message onChain:(DSChain *)chain {
    if (!(self = [super initWithMessage:message onChain:chain])) return nil;
    self.type = DSTransactionType_Coinbase;
    NSUInteger length = message.length;
    uint32_t off = self.payloadOffset;
    if (length - off < 1) return nil;
    NSNumber *extraPayloadNumber = nil;
    __unused uint64_t extraPayloadSize = [message varIntAtOffset:off length:&extraPayloadNumber]; //!OCLINT
    off += [extraPayloadNumber unsignedLongValue];

    if (length - off < 2) return nil;
    uint16_t version = [message UInt16AtOffset:off];
    off += 2;
    if (length - off < 4) return nil;
    self.height = [message UInt32AtOffset:off];
    off += 4;
    if (length - off < 32) return nil;
    self.merkleRootMNList = [message UInt256AtOffset:off];
    off += 32;

    if (version >= COINBASE_TX_CORE_19) {
        if (length - off < 32) return nil;
        self.merkleRootLLMQList = [message UInt256AtOffset:off];
        off += 32;
        
        if (version >= COINBASE_TX_CORE_20) {
            if (length - off < 4) return nil;
            self.bestCLHeightDiff = [message UInt32AtOffset:off];
            off += 4;
            if (length - off < 96) return nil;
            self.bestCLSignature = [message UInt768AtOffset:off];
            off += 96;
            if (length - off < 8) return nil;
            NSNumber *len;
            self.creditPoolBalance = [message varIntAtOffset:off length:&len];
            off += len.unsignedIntegerValue;
        }
    }
    self.coinbaseTransactionVersion = version;

    self.payloadOffset = off;
    self.txHash = self.data.SHA256_2;
    return self;
}

- (instancetype)initWithCoinbaseMessage:(NSString *)coinbaseMessage atHeight:(uint32_t)height onChain:(DSChain *)chain {
    if (!(self = [super initOnChain:chain])) return nil;
    NSMutableData *coinbaseData = [NSMutableData data];
    [coinbaseData appendCoinbaseMessage:coinbaseMessage atHeight:height];
    [self addInputHash:UINT256_ZERO index:UINT32_MAX script:nil signature:coinbaseData sequence:UINT32_MAX];
    NSMutableData *outputScript = [NSMutableData data];
    [outputScript appendUInt8:OP_RETURN];
    [self addOutputScript:outputScript amount:chain.baseReward];
    self.txHash = self.toData.SHA256_2;
    self.height = height;
    return self;
}

// TODO: add lockedAmount for cbtx version 3
- (instancetype)initWithCoinbaseMessage:(NSString *)coinbaseMessage paymentAddresses:(NSArray<NSString *> *)paymentAddresses atHeight:(uint32_t)height onChain:(DSChain *)chain {
    if (!(self = [super initOnChain:chain])) return nil;
    NSMutableData *coinbaseData = [NSMutableData data];
    [coinbaseData appendCoinbaseMessage:coinbaseMessage atHeight:height];
    [self addInputHash:UINT256_ZERO index:UINT32_MAX script:nil signature:coinbaseData sequence:UINT32_MAX];
    for (NSString *paymentAddress in paymentAddresses) {
        [self addOutputAddress:paymentAddress amount:chain.baseReward / paymentAddresses.count];
    }
    self.txHash = self.toData.SHA256_2;
    self.height = height;
    return self;
}

- (NSData *)payloadData {
    NSMutableData *data = [NSMutableData data];
    [data appendUInt16:self.coinbaseTransactionVersion];
    [data appendUInt32:self.height];
    [data appendUInt256:self.merkleRootMNList];
    if (self.coinbaseTransactionVersion >= COINBASE_TX_CORE_19) {
        [data appendUInt256:self.merkleRootLLMQList];
        if (self.coinbaseTransactionVersion >= COINBASE_TX_CORE_20) {
            [data appendUInt32:self.bestCLHeightDiff];
            // TODO: check whether it matters to check for optionals
            [data appendUInt768:self.bestCLSignature];
            [data appendInt64:self.creditPoolBalance];
        }
    }
    return data;
}

// Returns the binary transaction data that needs to be hashed and signed with the private key for the tx input at
// subscriptIndex. A subscriptIndex of NSNotFound will return the entire signed transaction.
- (NSData *)toDataWithSubscriptIndex:(NSUInteger)subscriptIndex {
    @synchronized(self) {
        NSMutableData *data = [[super toDataWithSubscriptIndex:subscriptIndex] mutableCopy];
        return [data appendCountedData:[self payloadData]];
    }
}

- (size_t)size {
    @synchronized(self) {
        if (uint256_is_not_zero(self.txHash)) return self.data.length;
        return [super size] + [NSMutableData sizeOfVarInt:self.payloadData.length];
    }
}

- (Class)entityClass {
    return [DSCoinbaseTransactionEntity class];
}

@end
