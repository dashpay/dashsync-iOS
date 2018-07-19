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
    
    return self;
}

// Returns the binary transaction data that needs to be hashed and signed with the private key for the tx input at
// subscriptIndex. A subscriptIndex of NSNotFound will return the entire signed transaction.
- (NSData *)toDataWithSubscriptIndex:(NSUInteger)subscriptIndex
{
    UInt256 hash = UINT256_ZERO;
    NSMutableData *d = [NSMutableData dataWithCapacity:10 + TX_INPUT_SIZE*self.hashes.count +
                        TX_OUTPUT_SIZE*self.addresses.count];
    
    [d appendUInt16:self.version];
    [d appendUInt16:self.type];
    [d appendVarInt:self.hashes.count];
    
    
    for (NSUInteger i = 0; i < self.hashes.count; i++) {
        [self.hashes[i] getValue:&hash];
        [d appendBytes:&hash length:sizeof(hash)];
        [d appendUInt32:[self.indexes[i] unsignedIntValue]];
        
        if (subscriptIndex == NSNotFound && self.signatures[i] != [NSNull null]) {
            [d appendVarInt:[self.signatures[i] length]];
            [d appendData:self.signatures[i]];
        }
        else if (subscriptIndex == i && self.inScripts[i] != [NSNull null]) {
            //TODO: to fully match the reference implementation, OP_CODESEPARATOR related checksig logic should go here
            [d appendVarInt:[self.inScripts[i] length]];
            [d appendData:self.inScripts[i]];
        }
        else [d appendVarInt:0];
        
        [d appendUInt32:[self.sequences[i] unsignedIntValue]];
    }
    
    [d appendVarInt:self.amounts.count];
    
    for (NSUInteger i = 0; i < self.amounts.count; i++) {
        [d appendUInt64:[self.amounts[i] unsignedLongLongValue]];
        [d appendVarInt:[self.outScripts[i] length]];
        [d appendData:self.outScripts[i]];
    }
    
    [d appendUInt32:self.lockTime];
    if (subscriptIndex != NSNotFound) [d appendUInt32:SIGHASH_ALL];
    return d;
}

@end
