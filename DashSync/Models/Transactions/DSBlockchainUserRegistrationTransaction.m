//
//  DSBlockchainUserRegistrationTransaction.m
//  DashSync
//
//  Created by Sam Westrich on 7/12/18.
//

#import "DSBlockchainUserRegistrationTransaction.h"
#import "NSData+Bitcoin.h"
#import "NSMutableData+Dash.h"

@implementation DSBlockchainUserRegistrationTransaction

- (instancetype)initWithMessage:(NSData *)message onChain:(DSChain *)chain
{
    if (! (self = [super initWithMessage:message onChain:chain])) return nil;
    NSUInteger length = message.length;
    uint32_t off = self.payloadOffset;
    
    if (length - off < 2) return nil;
    self.blockchainUserRegistrationTransactionVersion = [message UInt16AtOffset:off];
    off += 2;
    
    if (length - off < 1) return nil;
    NSNumber * usernameLength;
    self.username = [message stringAtOffset:off length:&usernameLength];
    off += [usernameLength unsignedLongValue];
    
    if (length - off < 20) return nil;
    self.pubkeyHash = [message UInt160AtOffset:off];
    off += 20;
    
    if (length - off < 1) return nil;
    uint8_t messageSignatureSize = [message UInt8AtOffset:off];
    off += 1;
    if (length - off < messageSignatureSize) return nil;
    self.signature = [message subdataWithRange:NSMakeRange(off, messageSignatureSize)];
    off+= messageSignatureSize;
    
    self.payloadOffset = off;
    
    return self;
}

- (NSData *)toDataWithSubscriptIndex:(NSUInteger)subscriptIndex
{
    NSMutableData * data = [[super toDataWithSubscriptIndex:subscriptIndex] mutableCopy];
    [data appendUInt16:self.blockchainUserRegistrationTransactionVersion];
    [data appendString:self.username];
    [data appendUInt160:self.pubkeyHash];
    [data appendUInt8:self.signature.length];
    [data appendData:self.signature];
    return data;
}

@end
