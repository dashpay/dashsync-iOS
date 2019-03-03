//
//  DSProviderUpdateRegistrarTransaction.m
//  DashSync
//
//  Created by Sam Westrich on 2/21/19.
//

#import "DSProviderUpdateRegistrarTransaction.h"
#import "NSData+Bitcoin.h"
#import "NSMutableData+Dash.h"
#import "DSECDSAKey.h"
#import "NSString+Bitcoin.h"
#import "DSTransactionFactory.h"
#import "DSProviderRegistrationTransactionEntity+CoreDataClass.h"
#import "DSProviderUpdateRegistrarTransactionEntity+CoreDataClass.h"
#import "DSMasternodeManager.h"
#import "DSChainManager.h"
#import "DSProviderRegistrationTransaction.h"
#import "DSTransactionManager.h"
#import "DSLocalMasternode.h"

@interface DSProviderUpdateRegistrarTransaction()

@property (nonatomic,strong) DSProviderRegistrationTransaction * providerRegistrationTransaction;

@end

@implementation DSProviderUpdateRegistrarTransaction

- (instancetype)initWithMessage:(NSData *)message onChain:(DSChain *)chain
{
    if (! (self = [super initWithMessage:message onChain:chain])) return nil;
    self.type = DSTransactionType_ProviderUpdateRegistrar;
    NSUInteger length = message.length;
    uint32_t off = self.payloadOffset;
    
    if (length - off < 1) return nil;
    NSNumber * payloadLengthSize = nil;
    uint64_t payloadLength = [message varIntAtOffset:off length:&payloadLengthSize];
    off += payloadLengthSize.unsignedLongValue;
    
    if (length - off < 2) return nil;
    self.providerUpdateRegistrarTransactionVersion = [message UInt16AtOffset:off];
    off += 2;
    
    if (length - off < 32) return nil;
    self.providerRegistrationTransactionHash = [message UInt256AtOffset:off];
    off += 32;
    
    if (length - off < 2) return nil;
    self.providerMode = [message UInt16AtOffset:off];
    off += 2;
    
    if (length - off < 48) return nil;
    self.operatorKey = [message UInt384AtOffset:off];
    off += 48;
    
    if (length - off < 20) return nil;
    self.votingKeyHash = [message UInt160AtOffset:off];
    off += 20;
    
    NSNumber * scriptPayoutLength = nil;
    self.scriptPayout = [message dataAtOffset:off length:&scriptPayoutLength];
    off += scriptPayoutLength.unsignedIntegerValue;
    
    if (length - off < 32) return nil;
    self.inputsHash = [message UInt256AtOffset:off];
    off += 32;
    
    if (length - off < 1) return nil;
    NSNumber * messageSignatureSizeLength = nil;
    NSUInteger messageSignatureSize = (NSUInteger)[message varIntAtOffset:off length:&messageSignatureSizeLength];
    off += messageSignatureSizeLength.unsignedIntegerValue;
    if (length - off < messageSignatureSize) return nil;
    self.payloadSignature = [message subdataWithRange:NSMakeRange(off, messageSignatureSize)];
    off+= messageSignatureSize;
    self.payloadOffset = off;
    
    //todo verify inputs hash
    
    if ([self payloadData].length != payloadLength) return nil;
    self.txHash = self.data.SHA256_2;
    
    return self;
}


- (instancetype)initWithInputHashes:(NSArray *)hashes inputIndexes:(NSArray *)indexes inputScripts:(NSArray *)scripts inputSequences:(NSArray*)inputSequences outputAddresses:(NSArray *)addresses outputAmounts:(NSArray *)amounts providerUpdateRegistrarTransactionVersion:(uint16_t)version providerTransactionHash:(UInt256)providerTransactionHash mode:(uint16_t)providerMode operatorKey:(UInt384)operatorKey votingKeyHash:(UInt160)votingKeyHash scriptPayout:(NSData*)scriptPayout onChain:(DSChain * _Nonnull)chain {
    if (!(self = [super initWithInputHashes:hashes inputIndexes:indexes inputScripts:scripts inputSequences:inputSequences outputAddresses:addresses outputAmounts:amounts onChain:chain])) return nil;
    self.type = DSTransactionType_ProviderUpdateRegistrar;
    self.version = SPECIAL_TX_VERSION;
    self.providerUpdateRegistrarTransactionVersion = version;
    self.providerRegistrationTransactionHash = providerTransactionHash;
    self.votingKeyHash = votingKeyHash;
    self.providerMode = providerMode;
    self.operatorKey = operatorKey;
    self.scriptPayout = scriptPayout;
    return self;
}

-(instancetype)initWithProviderUpdateRegistrarTransactionVersion:(uint16_t)version providerTransactionHash:(UInt256)providerTransactionHash mode:(uint16_t)providerMode operatorKey:(UInt384)operatorKey votingKeyHash:(UInt160)votingKeyHash scriptPayout:(NSData*)scriptPayout onChain:(DSChain * _Nonnull)chain {
    if (!(self = [super initOnChain:chain])) return nil;
    self.type = DSTransactionType_ProviderUpdateRegistrar;
    self.version = SPECIAL_TX_VERSION;
    self.providerUpdateRegistrarTransactionVersion = version;
    self.providerRegistrationTransactionHash = providerTransactionHash;
    self.votingKeyHash = votingKeyHash;
    self.providerMode = providerMode;
    self.operatorKey = operatorKey;
    self.scriptPayout = scriptPayout;
    return self;
}

-(void)setProviderRegistrationTransactionHash:(UInt256)providerTransactionHash {
    _providerRegistrationTransactionHash = providerTransactionHash;
    self.providerRegistrationTransaction = (DSProviderRegistrationTransaction*)[self.chain transactionForHash:self.providerRegistrationTransactionHash];
}

-(UInt256)payloadHash {
    return [self payloadDataForHash].SHA256_2;
}

-(BOOL)checkPayloadSignature:(DSECDSAKey*)providerOwnerPublicKey {
    return uint160_eq([providerOwnerPublicKey hash160], self.providerRegistrationTransaction.ownerKeyHash);
}

-(BOOL)checkPayloadSignature {
    DSECDSAKey * providerOwnerPublicKey = [DSECDSAKey keyRecoveredFromCompactSig:self.payloadSignature andMessageDigest:[self payloadHash]];
    return [self checkPayloadSignature:providerOwnerPublicKey];
}

-(void)signPayloadWithKey:(DSECDSAKey*)privateKey {
    //ATTENTION If this ever changes from ECDSA, change the max signature size defined above
    DSDLog(@"Private Key is %@",[privateKey privateKeyStringForChain:self.chain]);
    self.payloadSignature = [privateKey compactSign:[self payloadHash]];
}

-(NSData*)basePayloadData {
    NSMutableData * data = [NSMutableData data];
    [data appendUInt16:self.providerUpdateRegistrarTransactionVersion];
    [data appendUInt256:self.providerRegistrationTransactionHash];
    [data appendUInt16:self.providerMode];
    [data appendUInt384:self.operatorKey];
    [data appendUInt160:self.votingKeyHash];
    [data appendVarInt:self.scriptPayout.length];
    [data appendData:self.scriptPayout];
    [data appendUInt256:self.inputsHash];
    return data;
}

-(NSData*)payloadDataForHash {
    NSMutableData * data = [NSMutableData data];
    [data appendData:[self basePayloadData]];
    return data;
}

-(NSData*)payloadData {
    NSMutableData * data = [NSMutableData data];
    [data appendData:[self basePayloadData]];
    [data appendUInt8:self.payloadSignature.length];
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
    return [super size] + [NSMutableData sizeOfVarInt:self.payloadData.length] + ([self basePayloadData].length + MAX_ECDSA_SIGNATURE_SIZE);
}

-(Class)entityClass {
    return [DSProviderUpdateRegistrarTransactionEntity class];
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
