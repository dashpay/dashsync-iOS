//
//  DSBlockchainUserTopupTransaction.m
//  DashSync
//
//  Created by Sam Westrich on 7/30/18.
//

#import "DSBlockchainUserTopupTransaction.h"
#import "NSData+Bitcoin.h"
#import "NSMutableData+Dash.h"
#import "DSKey.h"
#import "NSString+Bitcoin.h"
#import "DSTransactionFactory.h"

@interface DSBlockchainUserTopupTransaction()

@property (nonatomic,assign) uint16_t blockchainUserTopupTransactionVersion;
@property (nonatomic,assign) UInt256 registrationTransactionHash;
@property (nonatomic,assign) UInt256 previousSubscriptionTransactionHash;
@property (nonatomic,copy) NSNumber * topupAmount;
@property (nonatomic,assign) uint16_t topupIndex;

@end

@implementation DSBlockchainUserTopupTransaction

- (instancetype)initWithMessage:(NSData *)message onChain:(DSChain *)chain
{
    if (! (self = [super initWithMessage:message onChain:chain])) return nil;
    self.type = DSTransactionType_SubscriptionTopUp;
    NSUInteger length = message.length;
    uint32_t off = self.payloadOffset;
    
    if (length - off < 2) return nil;
    self.blockchainUserTopupTransactionVersion = [message UInt16AtOffset:off];
    off += 2;
    
    if (length - off < 32) return nil;
    self.registrationTransactionHash = [message UInt256AtOffset:off];
    off += 32;
    
    if (length - off < 32) return nil;
    self.previousSubscriptionTransactionHash = [message UInt256AtOffset:off];
    off += 32;
    
    self.payloadOffset = off;
    
    return self;
}

- (instancetype)initWithInputHashes:(NSArray *)hashes inputIndexes:(NSArray *)indexes inputScripts:(NSArray *)scripts inputSequences:(NSArray*)inputSequences outputAddresses:(NSArray *)addresses outputAmounts:(NSArray *)amounts BlockchainUserTopupTransactionVersion:(uint16_t)version registrationTransactionHash:(UInt256)registrationTransactionHash previousSubscriptionTransactionHash:(UInt256)previousSubscriptionTransactionHash topupAmount:(NSNumber*)topupAmount topupIndex:(uint16_t)topupIndex onChain:(DSChain *)chain {
    NSMutableArray * realOutputAddresses = [addresses mutableCopy];
    [realOutputAddresses insertObject:[NSNull null] atIndex:topupIndex];
    NSMutableArray * realAmounts = [amounts mutableCopy];
    [realAmounts insertObject:topupAmount atIndex:topupIndex];
    if (!(self = [super initWithInputHashes:hashes inputIndexes:indexes inputScripts:scripts inputSequences:inputSequences outputAddresses:realOutputAddresses outputAmounts:realAmounts onChain:chain])) return nil;
    self.type = DSTransactionType_SubscriptionTopUp;
    self.blockchainUserTopupTransactionVersion = version;
    self.registrationTransactionHash = registrationTransactionHash;
    self.previousSubscriptionTransactionHash = previousSubscriptionTransactionHash;
    self.topupAmount = topupAmount;
    self.topupIndex = topupIndex;
    return self;
}

-(instancetype)initWithBlockchainUserTopupTransactionVersion:(uint16_t)version registrationTransactionHash:(UInt256)registrationTransactionHash previousSubscriptionTransactionHash:(UInt256)previousSubscriptionTransactionHash onChain:(DSChain *)chain {
    if (!(self = [super initOnChain:chain])) return nil;
    self.type = DSTransactionType_SubscriptionTopUp;
    self.blockchainUserTopupTransactionVersion = version;
    self.registrationTransactionHash = registrationTransactionHash;
    self.previousSubscriptionTransactionHash = previousSubscriptionTransactionHash;
    return self;
}

-(NSData*)payloadData {
    NSMutableData * data = [NSMutableData data];
    [data appendUInt16:self.blockchainUserTopupTransactionVersion];
    [data appendUInt256:self.registrationTransactionHash];
    [data appendUInt256:self.previousSubscriptionTransactionHash];
    return data;
}

- (NSData *)toDataWithSubscriptIndex:(NSUInteger)subscriptIndex
{
    NSMutableData * data = [[super toDataWithSubscriptIndex:subscriptIndex] mutableCopy];
    NSData * payloadData = [self payloadData];
    [data appendVarInt:payloadData.length];
    [data appendData:payloadData];
    return data;
}

- (size_t)size
{
    return [super size] + [self payloadData].length;
}

@end
