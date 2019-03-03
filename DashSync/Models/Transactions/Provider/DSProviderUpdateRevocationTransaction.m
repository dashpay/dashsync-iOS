//
//  DSProviderUpdateRevocationTransaction.m
//  DashSync
//
//  Created by Sam Westrich on 2/26/19.
//

#import "DSProviderUpdateRevocationTransaction.h"
#import "NSData+Bitcoin.h"
#import "NSMutableData+Dash.h"
#import "DSBLSKey.h"
#import "NSString+Bitcoin.h"
#import "DSTransactionFactory.h"
#import "DSProviderRegistrationTransactionEntity+CoreDataClass.h"
#import "DSProviderUpdateRevocationTransactionEntity+CoreDataClass.h"
#import "DSMasternodeManager.h"
#import "DSChainManager.h"
#import "DSProviderRegistrationTransaction.h"
#import "DSTransactionManager.h"
#import "DSLocalMasternode.h"

@interface DSProviderUpdateRevocationTransaction()

@property (nonatomic,strong) DSProviderRegistrationTransaction * providerRegistrationTransaction;

@end

@implementation DSProviderUpdateRevocationTransaction

- (instancetype)initWithMessage:(NSData *)message onChain:(DSChain *)chain
{
    if (! (self = [super initWithMessage:message onChain:chain])) return nil;
    self.type = DSTransactionType_ProviderUpdateRevocation;
    NSUInteger length = message.length;
    uint32_t off = self.payloadOffset;
    
    if (length - off < 1) return nil;
    NSNumber * payloadLengthSize = nil;
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
    off+= 96;
    self.payloadOffset = off;
    
    //todo verify inputs hash
    
    if ([self payloadData].length != payloadLength) return nil;
    self.txHash = self.data.SHA256_2;
    
    return self;
}


- (instancetype)initWithInputHashes:(NSArray *)hashes inputIndexes:(NSArray *)indexes inputScripts:(NSArray *)scripts inputSequences:(NSArray*)inputSequences outputAddresses:(NSArray *)addresses outputAmounts:(NSArray *)amounts providerUpdateRevocationTransactionVersion:(uint16_t)version providerTransactionHash:(UInt256)providerTransactionHash reason:(uint16_t)reason onChain:(DSChain * _Nonnull)chain {
    if (!(self = [super initWithInputHashes:hashes inputIndexes:indexes inputScripts:scripts inputSequences:inputSequences outputAddresses:addresses outputAmounts:amounts onChain:chain])) return nil;
    self.type = DSTransactionType_ProviderUpdateRevocation;
    self.version = SPECIAL_TX_VERSION;
    self.providerUpdateRevocationTransactionVersion = version;
    self.providerRegistrationTransactionHash = providerTransactionHash;
    self.reason = reason;
    return self;
}

-(instancetype)initWithProviderUpdateRevocationTransactionVersion:(uint16_t)version providerTransactionHash:(UInt256)providerTransactionHash reason:(uint16_t)reason onChain:(DSChain * _Nonnull)chain {
    if (!(self = [super initOnChain:chain])) return nil;
    self.type = DSTransactionType_ProviderUpdateRevocation;
    self.version = SPECIAL_TX_VERSION;
    self.providerUpdateRevocationTransactionVersion = version;
    self.providerRegistrationTransactionHash = providerTransactionHash;
    self.reason = reason;
    return self;
}

-(void)setProviderRegistrationTransactionHash:(UInt256)providerTransactionHash {
    _providerRegistrationTransactionHash = providerTransactionHash;
    self.providerRegistrationTransaction = (DSProviderRegistrationTransaction*)[self.chain transactionForHash:self.providerRegistrationTransactionHash];
}

-(UInt256)payloadHash {
    return [self payloadDataForHash].SHA256_2;
}

-(BOOL)checkPayloadSignature {
    NSAssert(self.providerRegistrationTransaction, @"We need a provider registration transaction");
    return [self checkPayloadSignature:[DSBLSKey blsKeyWithPublicKey:self.providerRegistrationTransaction.operatorKey onChain:self.chain]];
}

-(BOOL)checkPayloadSignature:(DSBLSKey*)publicKey {
    return [publicKey verify:[self payloadHash] signature:[self payloadSignature].UInt768];
}

-(void)signPayloadWithKey:(DSBLSKey*)privateKey {
    self.payloadSignature = [NSData dataWithUInt768:[privateKey signData:[self payloadDataForHash]]];
}

-(NSData*)basePayloadData {
    NSMutableData * data = [NSMutableData data];
    [data appendUInt16:self.providerUpdateRevocationTransactionVersion];
    [data appendUInt256:self.providerRegistrationTransactionHash];
    [data appendUInt16:self.reason];
    [data appendUInt256:self.inputsHash];
    return data;
}

-(NSData*)payloadDataForHash {
    NSMutableData * data = [NSMutableData data];
    [data appendData:[self basePayloadData]];
    //no need to add 0 here
    return data;
}

-(NSData*)payloadData {
    NSMutableData * data = [NSMutableData data];
    [data appendData:[self basePayloadData]];
    [data appendData:self.payloadSignature];
    return data;
}

- (NSData *)toDataWithSubscriptIndex:(NSUInteger)subscriptIndex
{
    NSMutableData * data = [[super toDataWithSubscriptIndex:subscriptIndex] mutableCopy];
    [data appendVarInt:self.payloadData.length];
    [data appendData:[self payloadData]];
    if (subscriptIndex != NSNotFound) [data appendUInt32:SIGHASH_ALL];
    return data;
}

- (size_t)size
{
    if (! uint256_is_zero(self.txHash)) return self.data.length;
    return [super size] + [NSMutableData sizeOfVarInt:self.payloadData.length] + ([self basePayloadData].length + 96);
}

-(Class)entityClass {
    return [DSProviderUpdateRevocationTransactionEntity class];
}

-(void)updateInputsHash {
    NSMutableData * data = [NSMutableData data];
    for (NSUInteger i =0; i<self.inputHashes.count;i++) {
        UInt256 hash = UINT256_ZERO;
        NSValue * inputHash = self.inputHashes[i];
        [inputHash getValue:&hash];
        [data appendUInt256:hash];
        [data appendUInt32:[self.inputIndexes[i] unsignedIntValue]];
    }
    self.inputsHash = [data SHA256_2];
}

-(void)hasSetInputsAndOutputs {
    [self updateInputsHash];
}

@end
