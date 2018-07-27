//
//  DSBlockchainUserRegistrationTransaction.m
//  DashSync
//
//  Created by Sam Westrich on 7/12/18.
//

#import "DSBlockchainUserRegistrationTransaction.h"
#import "NSData+Bitcoin.h"
#import "NSMutableData+Dash.h"
#import "DSKey.h"
#import "DSTransactionFactory.h"

@interface DSBlockchainUserRegistrationTransaction()

@property (nonatomic,assign) uint16_t blockchainUserRegistrationTransactionVersion;
@property (nonatomic,copy) NSString * username;
@property (nonatomic,assign) UInt160 pubkeyHash;
@property (nonatomic,strong) NSData * signature;

@end

@implementation DSBlockchainUserRegistrationTransaction

- (instancetype)initWithMessage:(NSData *)message onChain:(DSChain *)chain
{
    if (! (self = [super initWithMessage:message onChain:chain])) return nil;
    self.type = DSTransactionType_SubscriptionRegistration;
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

-(instancetype)initWithBlockchainUserRegistrationTransactionVersion:(uint16_t)version username:(NSString*)username pubkeyHash:(UInt160)pubkeyHash onChain:(DSChain *)chain {
    if (!(self = [super initOnChain:chain])) return nil;
    self.type = DSTransactionType_SubscriptionRegistration;
    self.version = SPECIAL_TX_VERSION;
    self.blockchainUserRegistrationTransactionVersion = version;
    self.username = username;
    self.pubkeyHash = pubkeyHash;
    return self;
}

-(UInt256)payloadHash {
    NSMutableData * data = [NSMutableData data];
    [data appendUInt16:self.blockchainUserRegistrationTransactionVersion];
    [data appendData:[self.username dataUsingEncoding:NSUTF8StringEncoding]];
    [data appendUInt160:self.pubkeyHash];
    return [data SHA256_2];
}

-(BOOL)checkPayloadSignature {
    DSKey * blockchainUserPublicKey = [DSKey keyRecoveredFromCompactSig:self.signature andMessageDigest:[self payloadHash]];
    return uint160_eq([blockchainUserPublicKey hash160], self.pubkeyHash);
}

-(void)signPayloadWithKey:(DSKey*)privateKey {
    self.signature = [privateKey compactSign:[self payloadHash]];
}

-(NSData*)payloadData {
    NSMutableData * data = [NSMutableData data];
    [data appendUInt16:self.blockchainUserRegistrationTransactionVersion];
    [data appendString:self.username];
    [data appendUInt160:self.pubkeyHash];
    [data appendUInt8:self.signature.length];
    [data appendData:self.signature];
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
