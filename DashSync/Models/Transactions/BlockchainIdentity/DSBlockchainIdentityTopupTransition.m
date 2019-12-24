//
//  DSBlockchainIdentityTopupTransition.m
//  DashSync
//
//  Created by Sam Westrich on 7/30/18.
//

#import "DSBlockchainIdentityTopupTransition.h"
#import "NSData+Bitcoin.h"
#import "NSMutableData+Dash.h"
#import "DSECDSAKey.h"
#import "NSString+Bitcoin.h"
#import "DSTransactionFactory.h"
#import "DSBlockchainIdentityTopupTransitionEntity+CoreDataClass.h"

@interface DSBlockchainIdentityTopupTransition()

@end

@implementation DSBlockchainIdentityTopupTransition

- (instancetype)initWithMessage:(NSData *)message onChain:(DSChain *)chain
{
    if (! (self = [super initWithMessage:message onChain:chain])) return nil;
    self.type = DSTransactionType_SubscriptionTopUp;
    NSUInteger length = message.length;
    uint32_t off = self.payloadOffset;
    
    if (length - off < 1) return nil;
    NSNumber * payloadLengthSize = nil;
    uint64_t payloadLength = [message varIntAtOffset:off length:&payloadLengthSize];
    off += payloadLengthSize.unsignedLongValue;
    
    if (length - off < 2) return nil;
    self.blockchainIdentityTopupTransactionVersion = [message UInt16AtOffset:off];
    off += 2;
    
    if (length - off < 32) return nil;
    self.registrationTransactionHash = [message UInt256AtOffset:off];
    off += 32;
    
    self.payloadOffset = off;
    if ([self payloadData].length != payloadLength) return nil;
    self.txHash = self.data.SHA256_2;
    
    return self;
}

- (instancetype)initWithInputHashes:(NSArray *)hashes inputIndexes:(NSArray *)indexes inputScripts:(NSArray *)scripts inputSequences:(NSArray*)inputSequences outputAddresses:(NSArray *)addresses outputAmounts:(NSArray *)amounts blockchainIdentityTopupTransactionVersion:(uint16_t)version registrationTransactionHash:(UInt256)registrationTransactionHash topupAmount:(uint64_t)topupAmount topupIndex:(uint16_t)topupIndex onChain:(DSChain *)chain {
    NSMutableArray * realOutputAddresses = [addresses mutableCopy];
    [realOutputAddresses insertObject:[NSNull null] atIndex:topupIndex];
    NSMutableArray * realAmounts = [amounts mutableCopy];
    [realAmounts insertObject:@(topupAmount) atIndex:topupIndex];
    if (!(self = [super initWithInputHashes:hashes inputIndexes:indexes inputScripts:scripts inputSequences:inputSequences outputAddresses:realOutputAddresses outputAmounts:realAmounts onChain:chain])) return nil;
    self.type = DSTransactionType_SubscriptionTopUp;
    self.version = SPECIAL_TX_VERSION;
    self.blockchainIdentityTopupTransactionVersion = version;
    self.registrationTransactionHash = registrationTransactionHash;
    return self;
}

-(instancetype)initWithBlockchainIdentityTopupTransactionVersion:(uint16_t)version registrationTransactionHash:(UInt256)registrationTransactionHash onChain:(DSChain *)chain {
    if (!(self = [super initOnChain:chain])) return nil;
    self.type = DSTransactionType_SubscriptionTopUp;
    self.version = SPECIAL_TX_VERSION;
    self.blockchainIdentityTopupTransactionVersion = version;
    self.registrationTransactionHash = registrationTransactionHash;
    return self;
}

-(NSData*)payloadData {
    NSMutableData * data = [NSMutableData data];
    [data appendUInt16:self.blockchainIdentityTopupTransactionVersion];
    [data appendUInt256:self.registrationTransactionHash];
    NSLog(@"%@",data.hexString);
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

-(uint64_t)topupAmount {
    for (int i =0;i<self.outputScripts.count;i++) {
        NSData * data = self.outputScripts[i];
        if ([data UInt8AtOffset:0] == OP_RETURN) {
            return [self.amounts[i] unsignedLongLongValue];
        }
    }
    return 0;
}

- (size_t)size
{
    return [super size] + [self payloadData].length;
}

-(Class)entityClass {
    return [DSBlockchainIdentityTopupTransitionEntity class];
}

@end
