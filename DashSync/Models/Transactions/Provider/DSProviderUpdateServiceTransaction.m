//
//  DSProviderUpdateServiceTransaction.m
//  DashSync
//
//  Created by Sam Westrich on 2/21/19.
//

#import "DSProviderUpdateServiceTransaction.h"
#import "NSData+Bitcoin.h"
#import "NSMutableData+Dash.h"
#import "DSECDSAKey.h"
#import "NSString+Bitcoin.h"
#import "DSTransactionFactory.h"
#import "DSProviderRegistrationTransactionEntity+CoreDataClass.h"
#import "DSProviderUpdateServiceTransactionEntity+CoreDataClass.h"
#import "DSMasternodeManager.h"
#import "DSChainManager.h"
#import "DSProviderRegistrationTransaction.h"
#import "DSTransactionManager.h"

@interface DSProviderUpdateServiceTransaction()

@property (nonatomic,strong) DSProviderRegistrationTransaction * providerRegistrationTransaction;

@end

@implementation DSProviderUpdateServiceTransaction

- (instancetype)initWithMessage:(NSData *)message onChain:(DSChain *)chain
{
    if (! (self = [super initWithMessage:message onChain:chain])) return nil;
    self.type = DSTransactionType_ProviderUpdateService;
    NSUInteger length = message.length;
    uint32_t off = self.payloadOffset;
    
    if (length - off < 1) return nil;
    NSNumber * payloadLengthSize = nil;
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


- (instancetype)initWithInputHashes:(NSArray *)hashes inputIndexes:(NSArray *)indexes inputScripts:(NSArray *)scripts inputSequences:(NSArray*)inputSequences outputAddresses:(NSArray *)addresses outputAmounts:(NSArray *)amounts providerUpdateServiceTransactionVersion:(uint16_t)version providerTransactionHash:(UInt256)providerTransactionHash ipAddress:(UInt128)ipAddress port:(uint16_t)port scriptPayout:(NSData*)scriptPayout onChain:(DSChain * _Nonnull)chain {
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

-(instancetype)initWithProviderUpdateServiceTransactionVersion:(uint16_t)version providerTransactionHash:(UInt256)providerTransactionHash ipAddress:(UInt128)ipAddress port:(uint16_t)port scriptPayout:(NSData*)scriptPayout onChain:(DSChain * _Nonnull)chain {
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

-(void)setProviderRegistrationTransactionHash:(UInt256)providerTransactionHash {
    _providerRegistrationTransactionHash = providerTransactionHash;
    self.providerRegistrationTransaction = (DSProviderRegistrationTransaction*)[self.chain transactionForHash:self.providerRegistrationTransactionHash];
}

-(UInt256)payloadHash {
    return [self payloadDataForHash].SHA256_2;
}

-(BOOL)checkPayloadSignature {
    DSECDSAKey * providerOwnerPublicKey = [DSECDSAKey keyRecoveredFromCompactSig:self.payloadSignature andMessageDigest:[self payloadHash]];
    return uint160_eq([providerOwnerPublicKey hash160], self.providerRegistrationTransaction.ownerKeyHash);
}

-(void)signPayloadWithKey:(DSECDSAKey*)privateKey {
    //ATTENTION If this ever changes from ECDSA, change the max signature size defined above
    DSDLog(@"Private Key is %@",[privateKey privateKeyStringForChain:self.chain]);
    self.payloadSignature = [privateKey compactSign:[self payloadHash]];
}

-(NSData*)basePayloadData {
    NSMutableData * data = [NSMutableData data];
    [data appendUInt16:self.providerUpdateServiceTransactionVersion];
    [data appendUInt256:self.providerRegistrationTransactionHash];
    [data appendUInt128:self.ipAddress];
    [data appendUInt16:CFSwapInt16BigToHost(self.port)];
    [data appendVarInt:self.scriptPayout.length];
    [data appendData:self.scriptPayout];
    [data appendUInt256:self.inputsHash];
    return data;
}

-(NSData*)payloadDataForHash {
    NSMutableData * data = [NSMutableData data];
    [data appendData:[self basePayloadData]];
    [data appendUInt8:0];
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

- (size_t)maxSizeEstimatedBeforePayloadSigning
{
    return [super size] + [self basePayloadData].length + MAX_SIGNATURE_SIZE;
}

- (size_t)size
{
    if (self.payloadSignature) {
        return [super size] + [self payloadData].length;
    } else {
        return [self maxSizeEstimatedBeforePayloadSigning];
    }
}

-(Class)entityClass {
    return [DSProviderUpdateServiceTransactionEntity class];
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
    self.payloadSignature = [NSData data];
}

@end
