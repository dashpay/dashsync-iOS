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
#import "NSString+Bitcoin.h"
#import "DSTransactionFactory.h"
#import "DSBlockchainUserRegistrationTransactionEntity+CoreDataClass.h"

@interface DSBlockchainUserRegistrationTransaction()

@end

@implementation DSBlockchainUserRegistrationTransaction

- (instancetype)initWithMessage:(NSData *)message onChain:(DSChain *)chain
{
    if (! (self = [super initWithMessage:message onChain:chain])) return nil;
    self.type = DSTransactionType_SubscriptionRegistration;
    NSUInteger length = message.length;
    uint32_t off = self.payloadOffset;
    
    if (length - off < 1) return nil;
    NSNumber * payloadLengthSize = nil;
    uint64_t payloadLength = [message varIntAtOffset:off length:&payloadLengthSize];
    off += payloadLengthSize.unsignedLongValue;
    
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
    NSNumber * messageSignatureSizeLength = nil;
    uint64_t messageSignatureSize = [message varIntAtOffset:off length:&messageSignatureSizeLength];
    off += messageSignatureSizeLength.unsignedIntegerValue;
    if (length - off < messageSignatureSize) return nil;
    self.payloadSignature = [message subdataWithRange:NSMakeRange(off, messageSignatureSize)];
    off+= messageSignatureSize;
    self.payloadOffset = off;
    if ([self payloadData].length != payloadLength) return nil;
    self.txHash = self.data.SHA256_2;
    
    return self;
}

-(instancetype)initWithBlockchainUserRegistrationTransactionVersion:(uint16_t)version username:(NSString*)username pubkeyHash:(UInt160)pubkeyHash onChain:(DSChain *)chain {
    if (!(self = [super initOnChain:chain])) return nil;
    self.type = DSTransactionType_SubscriptionRegistration;
    self.version = SPECIAL_TX_VERSION;
    self.blockchainUserRegistrationTransactionVersion = version;
    self.username = username;
    self.pubkeyHash = pubkeyHash;
    NSLog(@"Creating blockchain user with pubkeyHash %@",uint160_data(pubkeyHash));
    return self;
}

- (instancetype)initWithInputHashes:(NSArray *)hashes inputIndexes:(NSArray *)indexes inputScripts:(NSArray *)scripts inputSequences:(NSArray*)inputSequences outputAddresses:(NSArray *)addresses outputAmounts:(NSArray *)amounts blockchainUserRegistrationTransactionVersion:(uint16_t)version username:(NSString* _Nonnull)username pubkeyHash:(UInt160)pubkeyHash topupAmount:(uint64_t)topupAmount topupIndex:(uint16_t)topupIndex onChain:(DSChain *)chain {
    NSMutableArray * realOutputAddresses = [addresses mutableCopy];
    [realOutputAddresses insertObject:[NSNull null] atIndex:topupIndex];
    NSMutableArray * realAmounts = [amounts mutableCopy];
    [realAmounts insertObject:@(topupAmount) atIndex:topupIndex];
    if (!(self = [super initWithInputHashes:hashes inputIndexes:indexes inputScripts:scripts inputSequences:inputSequences outputAddresses:realOutputAddresses outputAmounts:realAmounts onChain:chain])) return nil;
    self.type = DSTransactionType_SubscriptionRegistration;
    self.version = SPECIAL_TX_VERSION;
    self.blockchainUserRegistrationTransactionVersion = version;
    self.username = username;
    self.pubkeyHash = pubkeyHash;
    self.topupAmount = topupAmount;
    NSLog(@"Creating blockchain user with pubkeyHash %@",uint160_data(pubkeyHash));
    return self;
}

-(UInt256)payloadHash {
    return [self payloadDataForHash].SHA256_2;
}

-(BOOL)checkPayloadSignature {
    DSKey * blockchainUserPublicKey = [DSKey keyRecoveredFromCompactSig:self.payloadSignature andMessageDigest:[self payloadHash]];
    return uint160_eq([blockchainUserPublicKey hash160], self.pubkeyHash);
}

-(void)signPayloadWithKey:(DSKey*)privateKey {
    NSLog(@"Private Key is %@",[privateKey privateKeyStringForChain:self.chain]);
    self.payloadSignature = [privateKey compactSign:[self payloadHash]];
}

-(NSData*)payloadDataForHash {
    NSMutableData * data = [NSMutableData data];
    [data appendUInt16:self.blockchainUserRegistrationTransactionVersion];
    [data appendString:self.username];
    [data appendUInt160:self.pubkeyHash];
    [data appendUInt8:0];
    return data;
}

-(NSData*)payloadData {
    NSMutableData * data = [NSMutableData data];
    [data appendUInt16:self.blockchainUserRegistrationTransactionVersion];
    [data appendString:self.username];
    [data appendUInt160:self.pubkeyHash];
    [data appendUInt8:self.payloadSignature.length];
    [data appendData:self.payloadSignature];
    return data;
}

- (NSData *)toDataWithSubscriptIndex:(NSUInteger)subscriptIndex
{
    NSMutableData * data = [[super toDataWithSubscriptIndex:subscriptIndex] mutableCopy];
    [data appendVarInt:self.payloadData.length];
    [data appendData:[self payloadData]];
    if (subscriptIndex != NSNotFound) [data appendUInt32:SIGHASH_ALL];
    return data;
}

- (size_t)size
{
    return [super size] + [self payloadData].length;
}

-(Class)entityClass {
    return [DSBlockchainUserRegistrationTransactionEntity class];
}

@end
