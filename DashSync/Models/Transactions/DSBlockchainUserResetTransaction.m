//
//  DSBlockchainUserResetUserKeyTransaction.m
//  DashSync
//
//  Created by Sam Westrich on 8/13/18.
//

#import "DSBlockchainUserResetTransaction.h"
#import "NSData+Bitcoin.h"
#import "NSMutableData+Dash.h"
#import "DSKey.h"
#import "NSString+Bitcoin.h"
#import "DSTransactionFactory.h"
#import "DSBlockchainUserResetTransactionEntity+CoreDataClass.h"

@implementation DSBlockchainUserResetTransaction

- (instancetype)initWithMessage:(NSData *)message onChain:(DSChain *)chain
{
    if (! (self = [super initWithMessage:message onChain:chain])) return nil;
    self.type = DSTransactionType_SubscriptionResetKey;
    NSUInteger length = message.length;
    uint32_t off = self.payloadOffset;
    
    if (length - off < 1) return nil;
    NSNumber * payloadLengthSize = nil;
    uint64_t payloadLength = [message varIntAtOffset:off length:&payloadLengthSize];
    off += payloadLengthSize.unsignedLongValue;
    
    if (length - off < 2) return nil;
    self.blockchainUserResetTransactionVersion = [message UInt16AtOffset:off];
    off += 2;
    
    if (length - off < 32) return nil;
    self.registrationTransactionHash = [message UInt256AtOffset:off];
    off += 32;
    
    if (length - off < 32) return nil;
    self.previousBlockchainUserTransactionHash = [message UInt256AtOffset:off];
    off += 32;
    
    if (length - off < 8) return nil;
    self.creditFee = [message UInt64AtOffset:off];
    off += 8;
    
    if (length - off < 1) return nil;
    NSNumber * replacementPubKeyLength = nil;
    self.replacementPublicKey = [message dataAtOffset:off length:&replacementPubKeyLength];
    off += replacementPubKeyLength.unsignedLongValue;
    
    if (length - off < 1) return nil;
    NSNumber * oldPublicKeyPayloadSignatureLength = nil;
    self.oldPublicKeyPayloadSignature = [message dataAtOffset:off length:&oldPublicKeyPayloadSignatureLength];
    off += oldPublicKeyPayloadSignatureLength.unsignedLongValue;
    
    
    self.payloadOffset = off;
    if ([self payloadData].length != payloadLength) return nil;
    self.txHash = self.data.SHA256_2;
    
    return self;
}

- (instancetype)initWithInputHashes:(NSArray *)hashes inputIndexes:(NSArray *)indexes inputScripts:(NSArray *)scripts inputSequences:(NSArray*)inputSequences outputAddresses:(NSArray *)addresses outputAmounts:(NSArray *)amounts blockchainUserResetTransactionVersion:(uint16_t)version registrationTransactionHash:(UInt256)registrationTransactionHash previousBlockchainUserTransactionHash:(UInt256)previousBlockchainUserTransactionHash replacementPublicKey:(NSData*)replacementPublicKey creditFee:(uint64_t)creditFee onChain:(DSChain *)chain {
    if (!(self = [super initWithInputHashes:hashes inputIndexes:indexes inputScripts:scripts inputSequences:inputSequences outputAddresses:addresses outputAmounts:amounts onChain:chain])) return nil;
    self.type = DSTransactionType_SubscriptionResetKey;
    self.version = SPECIAL_TX_VERSION;
    self.blockchainUserResetTransactionVersion = version;
    self.registrationTransactionHash = registrationTransactionHash;
    self.previousBlockchainUserTransactionHash = previousBlockchainUserTransactionHash;
    self.creditFee = creditFee;
    self.replacementPublicKey = replacementPublicKey;
    return self;
}

-(instancetype)initWithBlockchainUserResetTransactionVersion:(uint16_t)version registrationTransactionHash:(UInt256)registrationTransactionHash previousBlockchainUserTransactionHash:(UInt256)previousBlockchainUserTransactionHash replacementPublicKey:(NSData*)replacementPublicKey creditFee:(uint64_t)creditFee onChain:(DSChain *)chain {
    if (!(self = [super initOnChain:chain])) return nil;
    self.type = DSTransactionType_SubscriptionTopUp;
    self.version = SPECIAL_TX_VERSION;
    self.blockchainUserResetTransactionVersion = version;
    self.registrationTransactionHash = registrationTransactionHash;
    self.previousBlockchainUserTransactionHash = previousBlockchainUserTransactionHash;
    self.creditFee = creditFee;
    self.replacementPublicKey = replacementPublicKey;
    return self;
}

-(NSData*)payloadData {
    NSMutableData * data = [NSMutableData data];
    [data appendUInt16:self.blockchainUserResetTransactionVersion];
    [data appendUInt256:self.registrationTransactionHash];
    [data appendUInt256:self.previousBlockchainUserTransactionHash];
    [data appendUInt64:self.creditFee];
    [data appendVarInt:self.replacementPublicKey.length];
    [data appendData:self.replacementPublicKey];
    [data appendVarInt:self.oldPublicKeyPayloadSignature.length];
    [data appendData:self.oldPublicKeyPayloadSignature];
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

- (size_t)size
{
    return [super size] + [self payloadData].length;
}

-(Class)entityClass {
    return [DSBlockchainUserResetTransactionEntity class];
}

@end
