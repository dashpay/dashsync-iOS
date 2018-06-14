//
//  DSGovernanceObject.m
//  DashSync
//
//  Created by Sam Westrich on 6/11/18.
//

#import "DSGovernanceObject.h"
#import "NSData+Bitcoin.h"
#import "DSChain.h"

@interface DSGovernanceObject()

@property (nonatomic, assign) UInt256 collateralHash;
@property (nonatomic, assign) UInt256 parentHash;
@property (nonatomic, assign) uint32_t revision;
@property (nonatomic, strong) NSData *signature;
@property (nonatomic, assign) NSTimeInterval timestamp;
@property (nonatomic, assign) DSGovernanceObjectType type;
@property (nonatomic, assign) UInt256 governanceObjectHash;
@property (nonatomic, strong) NSString * governanceMessage;
@property (nonatomic, strong) DSChain * chain;

@end

@implementation DSGovernanceObject

//From the reference implementation
//
//uint256 CGovernanceObject::GetHash() const
//{
//    // Note: doesn't match serialization
//
//    // CREATE HASH OF ALL IMPORTANT PIECES OF DATA
//
//    CHashWriter ss(SER_GETHASH, PROTOCOL_VERSION);
//    ss << nHashParent;
//    ss << nRevision;
//    ss << nTime;
//    ss << GetDataAsHexString();
//    ss << masternodeOutpoint << uint8_t{} << 0xffffffff; // adding dummy values here to match old hashing
//    ss << vchSig;
//    // fee_tx is left out on purpose
//
//    DBG( printf("CGovernanceObject::GetHash %i %li %s\n", nRevision, nTime, GetDataAsHexString().c_str()); );
//
//    return ss.GetHash();
//}

+(UInt256)hashWithParentHash:(NSData*)parentHashData revision:(uint32_t)revision timeStampData:(NSData*)timestampData hexData:(NSData*)hexData masternodeUTXO:(DSUTXO)masternodeUTXO signature:(NSData*)signature {
    //hash calculation
    NSMutableData * hashImportantData = [NSMutableData data];
    [hashImportantData appendData:parentHashData];
    [hashImportantData appendBytes:&revision length:4];
    [hashImportantData appendData:timestampData];
    
    [hashImportantData appendData:hexData];

    uint32_t index = (uint32_t)masternodeUTXO.n;
    [hashImportantData appendData:[NSData dataWithUInt256:masternodeUTXO.hash]];
    [hashImportantData appendBytes:&index length:4];
    uint8_t emptyByte = 0;
    uint32_t fullBits = UINT32_MAX;
    [hashImportantData appendBytes:&emptyByte length:1];
    [hashImportantData appendBytes:&fullBits length:4];
    uint8_t signatureSize = [signature length];
    [hashImportantData appendBytes:&signatureSize length:1];
    [hashImportantData appendData:signature];
    return hashImportantData.SHA256_2;
}

+(DSGovernanceObject* _Nullable)governanceObjectFromMessage:(NSData * _Nonnull)message onChain:(DSChain* _Nonnull)chain {
    NSUInteger length = message.length;
    NSUInteger offset = 0;
    if (length - offset < 32) return nil;
    NSData * parentHashData = [message subdataWithRange:NSMakeRange(offset, 32)];
    UInt256 parentHash = [message UInt256AtOffset:offset];
    offset += 32;
    if (length - offset < 4) return nil;
    uint32_t revision = [message UInt32AtOffset:offset];
    offset += 4;
    if (length - offset < 8) return nil;
    NSData * timestampData = [message subdataWithRange:NSMakeRange(offset, 8)];
    uint64_t timestamp = [message UInt64AtOffset:offset];
    offset += 8;
    if (length - offset < 32) return nil;
    UInt256 collateralHash = [message UInt256AtOffset:offset];
    offset += 32;
    NSNumber * varIntLength = nil;
    NSString * governanceMessage = [message stringAtOffset:offset length:&varIntLength];
    NSData * hexData = [message subdataWithRange:NSMakeRange(offset, varIntLength.integerValue)];
    offset += [varIntLength integerValue];
    DSGovernanceObjectType governanceObjectType = [message UInt32AtOffset:offset];
    offset += 4;
    
    DSUTXO masternodeUTXO;
    if (length - offset < 32) return nil;
    masternodeUTXO.hash = [message UInt256AtOffset:offset];
    offset += 32;
    if (length - offset < 4) return nil;
    masternodeUTXO.n = [message UInt32AtOffset:offset];
    offset += 4;
    if (length - offset < 1) return nil;
    uint8_t sigscriptSize = [message UInt8AtOffset:offset];
    offset += 1;
    if (length - offset < sigscriptSize) return nil;
    //NSData * sigscript = [message subdataWithRange:NSMakeRange(offset, sigscriptSize)];
    offset += sigscriptSize;
    if (length - offset < 4) return nil;
    //uint32_t sequenceNumber = [message UInt32AtOffset:offset];
    offset += 4;
    
    if (length - offset < 1) return nil;
    uint8_t messageSignatureSize = [message UInt8AtOffset:offset];
    offset += 1;
    if (length - offset < messageSignatureSize) return nil;
    NSData * messageSignature = [message subdataWithRange:NSMakeRange(offset, messageSignatureSize)];
    offset+= messageSignatureSize;
    
    UInt256 governanceObjectHash = [self hashWithParentHash:parentHashData revision:revision timeStampData:timestampData hexData:hexData masternodeUTXO:masternodeUTXO signature:messageSignature];
    
    DSGovernanceObject * governanceObject = [[DSGovernanceObject alloc] initWithType:governanceObjectType governanceMessage:governanceMessage parentHash:parentHash revision:revision timestamp:timestamp signature:messageSignature collateralHash:collateralHash governanceObjectHash:governanceObjectHash onChain:chain];
    return governanceObject;
    
}

-(instancetype)initWithType:(DSGovernanceObjectType)governanceObjectType governanceMessage:(NSString*)governanceMessage parentHash:(UInt256)parentHash revision:(uint32_t)revision timestamp:(NSTimeInterval)timestamp signature:(NSData*)signature collateralHash:(UInt256)collateralHash governanceObjectHash:(UInt256)governanceObjectHash onChain:(DSChain* _Nonnull)chain {
    if (!(self = [super init])) return nil;

    _signature = signature;
    _revision = revision;
    _timestamp = timestamp;
    _collateralHash = collateralHash;
    _governanceMessage = governanceMessage;
    _parentHash = parentHash;
    _type = governanceObjectType;
    _chain = chain;
    _governanceObjectHash = governanceObjectHash;
    return self;
}

@end
