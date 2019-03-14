//
//  DSTransition.m
//  DashSync
//
//  Created by Sam Westrich on 7/12/18.
//

#import "DSTransition.h"
#import "BigIntTypes.h"
#import "NSData+Bitcoin.h"
#import "NSMutableData+Dash.h"
#import "DSECDSAKey.h"
#import "NSString+Bitcoin.h"
#import "DSTransactionFactory.h"
#import "DSBlockchainUserRegistrationTransaction.h"
#import "DSTransitionEntity+CoreDataClass.h"

@interface DSTransition()

@property (nonatomic,strong) DSBlockchainUserRegistrationTransaction * blockchainUserRegistrationTransaction;

@end

@implementation DSTransition

- (instancetype)initWithInputHashes:(NSArray *)hashes inputIndexes:(NSArray *)indexes inputScripts:(NSArray *)scripts
                    outputAddresses:(NSArray *)addresses outputAmounts:(NSArray *)amounts onChain:(DSChain*)chain {
    NSAssert(FALSE, @"This initializer is not permitted on transitions");
    return nil;
}

- (instancetype)initWithInputHashes:(NSArray *)hashes inputIndexes:(NSArray *)indexes inputScripts:(NSArray *)scripts inputSequences:(NSArray*)inputSequences outputAddresses:(NSArray *)addresses outputAmounts:(NSArray *)amounts onChain:(DSChain *)chain {
    NSAssert(FALSE, @"This initializer is not permitted on transitions");
    return nil;
}

- (void)addInputHash:(UInt256)hash index:(NSUInteger)index script:(NSData *)script {
    NSAssert(FALSE, @"This operation is not permitted on transitions");
}
- (void)addInputHash:(UInt256)hash index:(NSUInteger)index script:(NSData *)script signature:(NSData *)signature
            sequence:(uint32_t)sequence {
    NSAssert(FALSE, @"This operation is not permitted on transitions");
}
- (void)addOutputAddress:(NSString *)address amount:(uint64_t)amount {
    NSAssert(FALSE, @"This operation is not permitted on transitions");
}
- (void)addOutputShapeshiftAddress:(NSString *)address {
    NSAssert(FALSE, @"This operation is not permitted on transitions");
}
- (void)addOutputBurnAmount:(uint64_t)amount {
    NSAssert(FALSE, @"This operation is not permitted on transitions");
}
- (void)addOutputScript:(NSData *)script amount:(uint64_t)amount {
    NSAssert(FALSE, @"This operation is not permitted on transitions");
}

- (instancetype)initWithMessage:(NSData *)message onChain:(DSChain *)chain
{
    if (! (self = [super initWithMessage:message onChain:chain])) return nil;
    self.type = DSTransactionType_Transition;
    NSUInteger length = message.length;
    uint32_t off = self.payloadOffset;
    
    if (length - off < 1) return nil;
    NSNumber * payloadLengthSize = nil;
    uint64_t payloadLength = [message varIntAtOffset:off length:&payloadLengthSize];
    off += payloadLengthSize.unsignedLongValue;
    
    if (length - off < 2) return nil;
    self.transitionVersion = [message UInt16AtOffset:off];
    off += 2;
    
    if (length - off < 32) return nil;
    self.registrationTransactionHash = [message UInt256AtOffset:off];
    off += 32;
    
    if (length - off < 32) return nil;
    self.previousTransitionHash = [message UInt256AtOffset:off];
    off += 32;
    
    if (length - off < 8) return nil;
    self.creditFee = [message UInt64AtOffset:off];
    off += 8;
    
    if (length - off < 32) return nil;
    self.packetHash = [message UInt256AtOffset:off];
    off += 32;
    
    if (length - off < 1) return nil;
    NSNumber * payloadSignatureLength = nil;
    self.payloadSignature = [message dataAtOffset:off length:&payloadSignatureLength];
    off += payloadSignatureLength.unsignedLongValue;
    
    
    self.payloadOffset = off;
    if ([self payloadData].length != payloadLength) return nil;
    self.txHash = self.data.SHA256_2;
    
    return self;
}

-(instancetype)initWithTransitionVersion:(uint16_t)version registrationTransactionHash:(UInt256)registrationTransactionHash previousTransitionHash:(UInt256)previousTransitionHash creditFee:(uint64_t)creditFee packetHash:(UInt256)packetHash onChain:(DSChain *)chain {
    if (!(self = [super initOnChain:chain])) return nil;
    self.type = DSTransactionType_Transition;
    self.version = SPECIAL_TX_VERSION;
    self.transitionVersion = version;
    self.registrationTransactionHash = registrationTransactionHash;
    self.previousTransitionHash = previousTransitionHash;
    self.packetHash = packetHash;
    self.creditFee = creditFee;
    return self;
}

-(NSData*)basePayloadData {
    NSMutableData * data = [NSMutableData data];
    [data appendUInt16:self.transitionVersion];
    [data appendUInt256:self.registrationTransactionHash];
    [data appendUInt256:self.previousTransitionHash];
    [data appendUInt64:self.creditFee];
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
    NSData * payloadData = [self payloadData];
    [data appendVarInt:payloadData.length];
    [data appendData:payloadData];
    if (subscriptIndex != NSNotFound) [data appendUInt32:SIGHASH_ALL];
    return data;
}

-(UInt256)payloadHash {
    return [self payloadDataForHash].SHA256_2;
}

-(void)setRegistrationTransactionHash:(UInt256)registrationTransactionHash {
    _registrationTransactionHash = registrationTransactionHash;
    self.blockchainUserRegistrationTransaction = (DSBlockchainUserRegistrationTransaction*)[self.chain transactionForHash:registrationTransactionHash];
}

-(DSBlockchainUserRegistrationTransaction*)blockchainUserRegistrationTransaction {
    if (!_blockchainUserRegistrationTransaction) self.blockchainUserRegistrationTransaction = (DSBlockchainUserRegistrationTransaction*)[self.chain transactionForHash:self.registrationTransactionHash];
    return _blockchainUserRegistrationTransaction;
}

-(BOOL)checkPayloadSignature:(DSECDSAKey*)transitionRecoveredPublicKey {
    return uint160_eq([transitionRecoveredPublicKey hash160], self.blockchainUserRegistrationTransaction.pubkeyHash);
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

- (size_t)size
{
    return [super size] + [self payloadData].length;
}

-(Class)entityClass {
    return [DSTransitionEntity class];
}

-(BOOL)transactionTypeRequiresInputs {
    return NO;
}

@end
