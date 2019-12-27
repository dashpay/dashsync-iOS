//
//  DSBlockchainIdentityRegistrationTransition.m
//  DashSync
//
//  Created by Sam Westrich on 7/12/18.
//

#import "DSBlockchainIdentityRegistrationTransition.h"
#import "NSData+Bitcoin.h"
#import "NSMutableData+Dash.h"
#import "DSECDSAKey.h"
#import "NSString+Bitcoin.h"
#import "DSTransactionFactory.h"
#import "DSBlockchainIdentityRegistrationTransitionEntity+CoreDataClass.h"

@interface DSBlockchainIdentityRegistrationTransition()

@end

@implementation DSBlockchainIdentityRegistrationTransition

- (instancetype)initWithMessage:(NSData *)message onChain:(DSChain *)chain
{
    NSParameterAssert(message);
    NSParameterAssert(chain);
    
    if (! (self = [super initWithMessage:message onChain:chain])) return nil;
    self.type = DSTransactionType_SubscriptionRegistration;
    NSUInteger length = message.length;
    uint32_t off = self.payloadOffset;
    
    if (length - off < 1) return nil;
    NSNumber * payloadLengthSize = nil;
    uint64_t payloadLength = [message varIntAtOffset:off length:&payloadLengthSize];
    off += payloadLengthSize.unsignedLongValue;
    
    if (length - off < 2) return nil;
    self.blockchainIdentityRegistrationTransactionVersion = [message UInt16AtOffset:off];
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
    NSUInteger messageSignatureSize = (NSUInteger)[message varIntAtOffset:off length:&messageSignatureSizeLength];
    off += messageSignatureSizeLength.unsignedIntegerValue;
    if (length - off < messageSignatureSize) return nil;
    self.payloadSignature = [message subdataWithRange:NSMakeRange(off, messageSignatureSize)];
    off+= messageSignatureSize;
    self.payloadOffset = off;
    if ([self payloadData].length != payloadLength) return nil;
    self.txHash = self.data.SHA256_2;
    
    return self;
}

//-(void)setBlockHeight:(uint32_t)blockHeight {
//    DSDLog(@"%@ height %d, ST %@",self.username, blockHeight,[NSThread callStackSymbols]);
//    [super setBlockHeight:blockHeight];
//}

-(instancetype)initWithBlockchainIdentityRegistrationTransitionVersion:(uint16_t)version username:(NSString*)username pubkeyHash:(UInt160)pubkeyHash onChain:(DSChain *)chain {
    NSParameterAssert(username);
    NSParameterAssert(chain);
    
    if (!(self = [super initOnChain:chain])) return nil;
    self.type = DSTransactionType_SubscriptionRegistration;
    self.version = SPECIAL_TX_VERSION;
    self.blockchainIdentityRegistrationTransactionVersion = version;
    self.username = username;
    self.pubkeyHash = pubkeyHash;
    DSDLog(@"Creating blockchain user with pubkeyHash %@",uint160_data(pubkeyHash));
    return self;
}

- (instancetype)initWithInputHashes:(NSArray *)hashes inputIndexes:(NSArray *)indexes inputScripts:(NSArray *)scripts inputSequences:(NSArray*)inputSequences outputAddresses:(NSArray *)addresses outputAmounts:(NSArray *)amounts blockchainIdentityRegistrationTransactionVersion:(uint16_t)version username:(NSString *)username pubkeyHash:(UInt160)pubkeyHash topupAmount:(uint64_t)topupAmount topupIndex:(uint16_t)topupIndex onChain:(DSChain *)chain {
    NSParameterAssert(hashes);
    NSParameterAssert(indexes);
    NSParameterAssert(scripts);
    NSParameterAssert(inputSequences);
    NSParameterAssert(addresses);
    NSParameterAssert(amounts);
    NSParameterAssert(username);
    NSParameterAssert(chain);
    
    NSMutableArray * realOutputAddresses = [addresses mutableCopy];
    [realOutputAddresses insertObject:[NSNull null] atIndex:topupIndex];
    NSMutableArray * realAmounts = [amounts mutableCopy];
    [realAmounts insertObject:@(topupAmount) atIndex:topupIndex];
    if (!(self = [super initWithInputHashes:hashes inputIndexes:indexes inputScripts:scripts inputSequences:inputSequences outputAddresses:realOutputAddresses outputAmounts:realAmounts onChain:chain])) return nil;
    self.type = DSTransactionType_SubscriptionRegistration;
    self.version = SPECIAL_TX_VERSION;
    self.blockchainIdentityRegistrationTransactionVersion = version;
    self.username = username;
    self.pubkeyHash = pubkeyHash;
    DSDLog(@"Creating blockchain user with pubkeyHash %@",uint160_data(pubkeyHash));
    return self;
}

-(UInt256)payloadHash {
    return [self payloadDataForHash].SHA256_2;
}

-(BOOL)checkPayloadSignature {
    DSECDSAKey * blockchainIdentityPublicKey = [DSECDSAKey keyRecoveredFromCompactSig:self.payloadSignature andMessageDigest:[self payloadHash]];
    return uint160_eq([blockchainIdentityPublicKey hash160], self.pubkeyHash);
}

-(void)signPayloadWithKey:(DSECDSAKey*)privateKey {
    NSParameterAssert(privateKey);
    
    DSDLog(@"Private Key is %@",[privateKey privateKeyStringForChain:self.chain]);
    self.payloadSignature = [privateKey compactSign:[self payloadHash]];
}

-(NSData*)payloadDataForHash {
    NSMutableData * data = [NSMutableData data];
    [data appendUInt16:self.blockchainIdentityRegistrationTransactionVersion];
    [data appendString:self.username];
    [data appendUInt160:self.pubkeyHash];
    [data appendUInt8:0];
    return data;
}

-(NSData*)payloadData {
    NSMutableData * data = [NSMutableData data];
    [data appendUInt16:self.blockchainIdentityRegistrationTransactionVersion];
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

-(uint64_t)topupAmount {
    for (int i =0;i<self.outputScripts.count;i++) {
        NSData * data = self.outputScripts[i];
        if ([data UInt8AtOffset:0] == OP_RETURN) {
            return [self.amounts[i] unsignedLongLongValue];
        }
    }
    return 0;
}

-(NSString*)pubkeyAddress {
    return [[NSData dataWithUInt160:self.pubkeyHash] addressFromHash160DataForChain:self.chain];
}

- (size_t)size
{
    return [super size] + [self payloadData].length;
}

-(Class)entityClass {
    return [DSBlockchainIdentityRegistrationTransitionEntity class];
}

- (NSString *)description
{
    NSString *txid = [NSString hexWithData:[NSData dataWithBytes:self.txHash.u8 length:sizeof(UInt256)].reverse];
    return [NSString stringWithFormat:@"%@<%p>(id=%@,username=%@,confirmedInBlock=%d)", [self class],self, txid,self.username,self.blockHeight];
}

@end
