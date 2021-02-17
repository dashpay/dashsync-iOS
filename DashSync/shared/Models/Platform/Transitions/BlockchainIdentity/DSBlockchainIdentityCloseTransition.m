//
//  DSBlockchainIdentityCloseTransition.m
//  DashSync
//
//  Created by Sam Westrich on 8/13/18.
//

#import "DSBlockchainIdentityCloseTransition.h"
#import "DSECDSAKey.h"
#import "DSTransactionFactory.h"
#import "NSData+Bitcoin.h"
#import "NSMutableData+Dash.h"
#import "NSString+Bitcoin.h"

@implementation DSBlockchainIdentityCloseTransition

//- (instancetype)initWithMessage:(NSData *)message onChain:(DSChain *)chain
//{
//    if (! (self = [super initWithMessage:message onChain:chain])) return nil;
//    self.type = DSTransactionType_SubscriptionCloseAccount;
//    NSUInteger length = message.length;
//    uint32_t off = self.payloadOffset;
//
//    if (length - off < 1) return nil;
//    NSNumber * payloadLengthSize = nil;
//    uint64_t payloadLength = [message varIntAtOffset:off length:&payloadLengthSize];
//    off += payloadLengthSize.unsignedLongValue;
//
//    if (length - off < 2) return nil;
//    self.blockchainIdentityCloseTransactionVersion = [message UInt16AtOffset:off];
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
//    if (length - off < 1) return nil;
//    NSNumber * payloadSignatureLength = nil;
//    self.payloadSignature = [message dataAtOffset:off length:&payloadSignatureLength];
//    off += payloadSignatureLength.unsignedLongValue;
//
//
//    self.payloadOffset = off;
//    if ([self payloadData].length != payloadLength) return nil;
//    self.txHash = self.data.SHA256_2;
//
//    return self;
//}
//
//- (instancetype)initWithInputHashes:(NSArray *)hashes inputIndexes:(NSArray *)indexes inputScripts:(NSArray *)scripts inputSequences:(NSArray*)inputSequences outputAddresses:(NSArray *)addresses outputAmounts:(NSArray *)amounts blockchainIdentityCloseTransactionVersion:(uint16_t)version registrationTransactionHash:(UInt256)registrationTransactionHash previousBlockchainIdentityTransactionHash:(UInt256)previousBlockchainIdentityTransactionHash creditFee:(uint64_t)creditFee onChain:(DSChain *)chain {
//    if (!(self = [super initWithInputHashes:hashes inputIndexes:indexes inputScripts:scripts inputSequences:inputSequences outputAddresses:addresses outputAmounts:amounts onChain:chain])) return nil;
//    self.type = DSTransactionType_SubscriptionCloseAccount;
//    self.version = SPECIAL_TX_VERSION;
//    self.blockchainIdentityCloseTransactionVersion = version;
//    self.registrationTransactionHash = registrationTransactionHash;
//    self.previousBlockchainIdentityTransactionHash = previousBlockchainIdentityTransactionHash;
//    self.creditFee = creditFee;
//    return self;
//}
//
//-(instancetype)initWithBlockchainIdentityCloseTransactionVersion:(uint16_t)version registrationTransactionHash:(UInt256)registrationTransactionHash previousBlockchainIdentityTransactionHash:(UInt256)previousBlockchainIdentityTransactionHash creditFee:(uint64_t)creditFee onChain:(DSChain *)chain {
//    if (!(self = [super initOnChain:chain])) return nil;
//    self.type = DSTransactionType_SubscriptionCloseAccount;
//    self.version = SPECIAL_TX_VERSION;
//    self.blockchainIdentityCloseTransactionVersion = version;
//    self.registrationTransactionHash = registrationTransactionHash;
//    self.previousBlockchainIdentityTransactionHash = previousBlockchainIdentityTransactionHash;
//    self.creditFee = creditFee;
//    return self;
//}
//
//-(NSData*)payloadData {
//    NSMutableData * data = [NSMutableData data];
//    [data appendUInt16:self.blockchainIdentityCloseTransactionVersion];
//    [data appendUInt256:self.registrationTransactionHash];
//    [data appendUInt256:self.previousBlockchainIdentityTransactionHash];
//    [data appendUInt64:self.creditFee];
//    [data appendVarInt:self.payloadSignature.length];
//    [data appendData:self.payloadSignature];
//    return data;
//}
//
//- (NSData *)toDataWithSubscriptIndex:(NSUInteger)subscriptIndex
//{
//    NSMutableData * data = [[super toDataWithSubscriptIndex:subscriptIndex] mutableCopy];
//    NSData * payloadData = [self payloadData];
//    [data appendVarInt:payloadData.length];
//    [data appendData:payloadData];
//    if (subscriptIndex != NSNotFound) [data appendUInt32:SIGHASH_ALL];
//    return data;
//}
//
//- (size_t)size
//{
//    return [super size] + [self payloadData].length;
//}
//
//-(Class)entityClass {
//    return [DSBlockchainIdentityCloseTransitionEntity class];
//}
//
//-(BOOL)transactionTypeRequiresInputs {
//    return NO;
//}


@end
