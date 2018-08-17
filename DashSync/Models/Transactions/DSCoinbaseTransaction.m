//
//  DSCoinbaseTransaction.m
//  DashSync
//
//  Created by Sam Westrich on 7/12/18.
//

#import "DSCoinbaseTransaction.h"
#import "NSData+Bitcoin.h"
#import "NSMutableData+Dash.h"

@implementation DSCoinbaseTransaction

- (instancetype)initWithMessage:(NSData *)message onChain:(DSChain *)chain
{
    if (! (self = [super initWithMessage:message onChain:chain])) return nil;
    NSUInteger length = message.length;
    uint32_t off = self.payloadOffset;
    if (length - off < 1) return nil;
    NSNumber * extraPayloadNumber = nil;
    uint64_t extraPayloadSize = [message varIntAtOffset:off length:&extraPayloadNumber];
    off += [extraPayloadNumber unsignedLongValue];
    
//    if (length - off < 2) return nil;
//    uint16_t version = [message UInt16AtOffset:off];
//    off += 2;
    if (length - off < 4) return nil;
    uint32_t height = [message UInt32AtOffset:off];
    off += 4;
    if (length - off < 32) return nil;
    UInt256 merkleRootMNList = [message UInt256AtOffset:off];
    off += 32;
    
    //self.coinbaseTransactionVersion = version;
    self.height = height;
    self.merkleRootMNList = merkleRootMNList;
    
    self.payloadOffset = off;
    self.txHash = self.data.SHA256_2;
    return self;
}

-(NSData*)payloadData {
    NSMutableData * data = [NSMutableData data];
    [data appendUInt32:self.height];
    [data appendUInt256:self.merkleRootMNList];
    return data;
}

// Returns the binary transaction data that needs to be hashed and signed with the private key for the tx input at
// subscriptIndex. A subscriptIndex of NSNotFound will return the entire signed transaction.
- (NSData *)toDataWithSubscriptIndex:(NSUInteger)subscriptIndex
{
    NSMutableData * data = [[super toDataWithSubscriptIndex:subscriptIndex] mutableCopy];
  
        NSData * payloadData = [self payloadData];
        [data appendVarInt:payloadData.length];
        [data appendData:[self payloadData]];
    
    
    return data;
}

@end
