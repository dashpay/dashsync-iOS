//
//  DSBlockchainIdentityResetTransition.m
//  DashSync
//
//  Created by Sam Westrich on 8/13/18.
//

#import "DSBlockchainIdentityUpdateTransition.h"
#import "DSTransactionFactory.h"
#import "NSData+Dash.h"
#import "NSMutableData+Dash.h"
#import "NSString+Bitcoin.h"

@implementation DSBlockchainIdentityUpdateTransition

//- (instancetype)initWithMessage:(NSData *)message onChain:(DSChain *)chain
//{
//    NSParameterAssert(message);
//    NSParameterAssert(chain);
//
//    if (! (self = [super initWithMessage:message onChain:chain])) return nil;
//    self.type = DSTransactionType_SubscriptionResetKey;
//    NSUInteger length = message.length;
//    uint32_t off = self.payloadOffset;
//
//    if (length - off < 1) return nil;
//    NSNumber * payloadLengthSize = nil;
//    uint64_t payloadLength = [message varIntAtOffset:off length:&payloadLengthSize];
//    off += payloadLengthSize.unsignedLongValue;
//
//    if (length - off < 2) return nil;
//    self.blockchainIdentityResetTransactionVersion = [message UInt16AtOffset:off];
//    off += 2;
//
//    if (length - off < 32) return nil;
//    self.registrationTransactionHash = [message UInt256AtOffset:off];
//    off += 32;
//
//    if (length - off < 32) return nil;
//    self.previousBlockchainIdentityTransactionHash = [message UInt256AtOffset:off];
//    off += 32;
//
//    if (length - off < 8) return nil;
//    self.creditFee = [message UInt64AtOffset:off];
//    off += 8;
//
//    if (length - off < 20) return nil;
//    self.replacementPublicKeyHash = [message UInt160AtOffset:off];
//    off += 20;
//
////    if (length - off < 1) return nil;
////    NSNumber * replacementPubKeyLength = nil;
////    self.replacementPublicKey = [message dataAtOffset:off length:&replacementPubKeyLength];
////    off += replacementPubKeyLength.unsignedLongValue;
//
//    if (length - off < 1) return nil;
//    NSNumber * oldPublicKeyPayloadSignatureLength = nil;
//    self.oldPublicKeyPayloadSignature = [message dataAtOffset:off length:&oldPublicKeyPayloadSignatureLength];
//    off += oldPublicKeyPayloadSignatureLength.unsignedLongValue;
//
//
//    self.payloadOffset = off;
//    if ([self payloadData].length != payloadLength) return nil;
//    self.txHash = self.data.SHA256_2;
//
//    return self;
//}
//
//- (instancetype)initWithInputHashes:(NSArray *)hashes inputIndexes:(NSArray *)indexes inputScripts:(NSArray *)scripts inputSequences:(NSArray*)inputSequences outputAddresses:(NSArray *)addresses outputAmounts:(NSArray *)amounts blockchainIdentityResetTransactionVersion:(uint16_t)version registrationTransactionHash:(UInt256)registrationTransactionHash previousBlockchainIdentityTransactionHash:(UInt256)previousBlockchainIdentityTransactionHash replacementPublicKeyHash:(UInt160)replacementPublicKeyHash creditFee:(uint64_t)creditFee onChain:(DSChain *)chain {
//    NSParameterAssert(indexes);
//    NSParameterAssert(scripts);
//    NSParameterAssert(inputSequences);
//    NSParameterAssert(addresses);
//    NSParameterAssert(amounts);
//    NSParameterAssert(chain);
//
//    if (!(self = [super initWithInputHashes:hashes inputIndexes:indexes inputScripts:scripts inputSequences:inputSequences outputAddresses:addresses outputAmounts:amounts onChain:chain])) return nil;
//    self.type = DSTransactionType_SubscriptionResetKey;
//    self.version = SPECIAL_TX_VERSION;
//    self.blockchainIdentityResetTransactionVersion = version;
//    self.registrationTransactionHash = registrationTransactionHash;
//    self.previousBlockchainIdentityTransactionHash = previousBlockchainIdentityTransactionHash;
//    self.creditFee = creditFee;
//    self.replacementPublicKeyHash = replacementPublicKeyHash;
//    return self;
//}
//
//-(instancetype)initWithBlockchainIdentityResetTransactionVersion:(uint16_t)version registrationTransactionHash:(UInt256)registrationTransactionHash previousBlockchainIdentityTransactionHash:(UInt256)previousBlockchainIdentityTransactionHash replacementPublicKeyHash:(UInt160)replacementPublicKeyHash creditFee:(uint64_t)creditFee onChain:(DSChain *)chain {
//    NSParameterAssert(chain);
//
//    if (!(self = [super initOnChain:chain])) return nil;
//    self.type = DSTransactionType_SubscriptionResetKey;
//    self.version = SPECIAL_TX_VERSION;
//    self.blockchainIdentityResetTransactionVersion = version;
//    self.registrationTransactionHash = registrationTransactionHash;
//    self.previousBlockchainIdentityTransactionHash = previousBlockchainIdentityTransactionHash;
//    self.creditFee = creditFee;
//    self.replacementPublicKeyHash = replacementPublicKeyHash;
//    return self;
//}
//
////-(NSData*)payloadData {
////    NSMutableData * data = [NSMutableData data];
////    [data appendUInt16:self.blockchainIdentityResetTransactionVersion];
////    [data appendUInt256:self.registrationTransitionHash];
////    [data appendUInt256:self.previousBlockchainIdentityTransactionHash];
////    [data appendUInt64:self.creditFee];
////    [data appendVarInt:self.replacementPublicKey.length];
////    [data appendData:self.replacementPublicKey];
////    [data appendVarInt:self.oldPublicKeyPayloadSignature.length];
////    [data appendData:self.oldPublicKeyPayloadSignature];
////    return data;
////}
////
////-(NSData*)payloadDataForHash {
////    NSMutableData * data = [NSMutableData data];
////    [data appendUInt16:self.blockchainIdentityResetTransactionVersion];
////    [data appendUInt256:self.registrationTransitionHash];
////    [data appendUInt256:self.previousBlockchainIdentityTransactionHash];
////    [data appendUInt64:self.creditFee];
////    [data appendVarInt:self.replacementPublicKey.length];
////    [data appendData:self.replacementPublicKey];
////    [data appendUInt8:0];
////    return data;
////}
//
//-(NSData*)payloadData {
//    NSMutableData * data = [NSMutableData data];
//    [data appendUInt16:self.blockchainIdentityResetTransactionVersion];
//    [data appendUInt256:self.registrationTransactionHash];
//    [data appendUInt256:self.previousBlockchainIdentityTransactionHash];
//    [data appendUInt64:self.creditFee];
//    [data appendUInt160:self.replacementPublicKeyHash];
//    [data appendVarInt:self.oldPublicKeyPayloadSignature.length];
//    [data appendData:self.oldPublicKeyPayloadSignature];
//    return data;
//}
//
//-(NSData*)payloadDataForHash {
//    NSMutableData * data = [NSMutableData data];
//    [data appendUInt16:self.blockchainIdentityResetTransactionVersion];
//    [data appendUInt256:self.registrationTransactionHash];
//    [data appendUInt256:self.previousBlockchainIdentityTransactionHash];
//    [data appendUInt64:self.creditFee];
//    [data appendUInt160:self.replacementPublicKeyHash];
//    [data appendUInt8:0];
//    return data;
//}
//
//-(UInt256)payloadHash {
//    return [self payloadDataForHash].SHA256_2;
//}
//
//-(BOOL)checkTransitionSignatureIsSignedByPublicKeyWithHash:(UInt160)oldPublicKeyHash {
//    DSECDSAKey * blockchainIdentityPublicKey = [DSECDSAKey keyRecoveredFromCompactSig:self.oldPublicKeyPayloadSignature andMessageDigest:[self payloadHash]];
//    return uint160_eq([blockchainIdentityPublicKey hash160], oldPublicKeyHash);
//}
//
//-(void)signPayloadWithKey:(DSECDSAKey*)privateKey {
//    NSParameterAssert(privateKey);
//
//    DSLogPrivate(@"Private Key is %@",[privateKey privateKeyStringForChain:self.chain]);
//    self.oldPublicKeyPayloadSignature = [privateKey compactSign:[self payloadHash]];
//    self.txHash = self.data.SHA256_2; //once the payload is signed the transaction hash is ready to go.
//}
//
//
//- (NSData *)toDataWithSubscriptIndex:(NSUInteger)subscriptIndex anyoneCanPay:(BOOL)anyoneCanPay
//{
//    NSMutableData * data = [[super toDataWithSubscriptIndex:subscriptIndex anyoneCanPay:anyoneCanPay] mutableCopy];
//    NSData * payloadData = [self payloadData];
//    [data appendVarInt:payloadData.length];
//    [data appendData:payloadData];
//    if (subscriptIndex != NSNotFound) [data appendUInt32:SIGHASH_ALL];
//    return data;
//}
//
//-(NSString*)pubkeyAddress {
//    return [[NSData dataWithUInt160:self.replacementPublicKeyHash] addressFromHash160DataForChain:self.chain];
//}
//
//- (size_t)size
//{
//    return [super size] + [self payloadData].length;
//}

@end
