//
//  DSSimplifiedMasternodeEntry.m
//  DashSync
//
//  Created by Sam Westrich on 7/12/18.
//

#import "DSSimplifiedMasternodeEntry.h"
#import "NSData+Bitcoin.h"
#import "NSMutableData+Dash.h"
#import "DSSimplifiedMasternodeEntryEntity+CoreDataProperties.h"
#import "NSManagedObject+Sugar.h"
#import "DSBLSKey.h"
#import "DSMutableOrderedDataKeyDictionary.h"

@interface DSSimplifiedMasternodeEntry()

@property(nonatomic,assign) UInt256 providerRegistrationTransactionHash;
@property(nonatomic,assign) UInt256 confirmedHash;
@property(nonatomic,assign) UInt256 confirmedHashHashedWithProviderRegistrationTransactionHash;
@property(nonatomic,assign) UInt256 simplifiedMasternodeEntryHash;
@property(nonatomic,assign) UInt128 address;
@property(nonatomic,assign) uint16_t port;
@property(nonatomic,assign) UInt384 operatorPublicKey; //this is using BLS
@property(nonatomic,assign) UInt160 keyIDVoting;
@property(nonatomic,assign) BOOL isValid;
@property(nonatomic,strong) DSChain * chain;
@property(nonatomic,strong) DSBLSKey * operatorPublicBLSKey;

@end


@implementation DSSimplifiedMasternodeEntry

-(NSData*)payloadData {
    NSMutableData * hashImportantData = [NSMutableData data];
    [hashImportantData appendUInt256:self.providerRegistrationTransactionHash];
    [hashImportantData appendUInt256:self.confirmedHash];
    [hashImportantData appendUInt128:self.address];
    [hashImportantData appendUInt16:CFSwapInt16HostToBig(self.port)];
    
    [hashImportantData appendUInt384:self.operatorPublicKey];
    [hashImportantData appendUInt160:self.keyIDVoting];
    [hashImportantData appendUInt8:self.isValid];
    return [hashImportantData copy];
}

-(UInt256)calculateSimplifiedMasternodeEntryHash {
    return [self payloadData].SHA256_2;
}

+(instancetype)simplifiedMasternodeEntryWithData:(NSData*)data onChain:(DSChain*)chain {
    return [[self alloc] initWithMessage:data onChain:chain];
}

+(instancetype)simplifiedMasternodeEntryWithProviderRegistrationTransactionHash:(UInt256)providerRegistrationTransactionHash confirmedHash:(UInt256)confirmedHash address:(UInt128)address port:(uint16_t)port operatorBLSPublicKey:(UInt384)operatorBLSPublicKey keyIDVoting:(UInt160)keyIDVoting isValid:(BOOL)isValid onChain:(DSChain*)chain {
    return [self simplifiedMasternodeEntryWithProviderRegistrationTransactionHash:providerRegistrationTransactionHash confirmedHash:confirmedHash address:address port:port operatorBLSPublicKey:operatorBLSPublicKey keyIDVoting:keyIDVoting isValid:isValid simplifiedMasternodeEntryHash:UINT256_ZERO onChain:chain];
}

+(instancetype)simplifiedMasternodeEntryWithProviderRegistrationTransactionHash:(UInt256)providerRegistrationTransactionHash confirmedHash:(UInt256)confirmedHash address:(UInt128)address port:(uint16_t)port operatorBLSPublicKey:(UInt384)operatorBLSPublicKey keyIDVoting:(UInt160)keyIDVoting isValid:(BOOL)isValid simplifiedMasternodeEntryHash:(UInt256)simplifiedMasternodeEntryHash onChain:(DSChain*)chain {
    DSSimplifiedMasternodeEntry * simplifiedMasternodeEntry = [[DSSimplifiedMasternodeEntry alloc] init];
    simplifiedMasternodeEntry.providerRegistrationTransactionHash = providerRegistrationTransactionHash;
    simplifiedMasternodeEntry.confirmedHash = confirmedHash;
    simplifiedMasternodeEntry.address = address;
    simplifiedMasternodeEntry.port = port;
    simplifiedMasternodeEntry.keyIDVoting = keyIDVoting;
    simplifiedMasternodeEntry.operatorPublicKey = operatorBLSPublicKey;
    simplifiedMasternodeEntry.isValid = isValid;
    simplifiedMasternodeEntry.simplifiedMasternodeEntryHash = !uint256_is_zero(simplifiedMasternodeEntryHash)?simplifiedMasternodeEntryHash:[simplifiedMasternodeEntry calculateSimplifiedMasternodeEntryHash];
    simplifiedMasternodeEntry.chain = chain;
    return simplifiedMasternodeEntry;
}

-(instancetype)initWithMessage:(NSData*)message onChain:(DSChain*)chain {
    if (!(self = [super init])) return nil;
    NSUInteger length = message.length;
    NSUInteger offset = 0;
    if (length - offset < 32) return nil;
    self.providerRegistrationTransactionHash = [message UInt256AtOffset:offset];
    offset += 32;
    
    if (length - offset < 32) return nil;
    self.confirmedHash = [message UInt256AtOffset:offset];
    offset += 32;
    
    if (length - offset < 16) return nil;
    self.address = [message UInt128AtOffset:offset];
    offset += 16;
    
    if (length - offset < 2) return nil;
    self.port = CFSwapInt16HostToBig([message UInt16AtOffset:offset]);
    offset += 2;
    
    if (length - offset < 48) return nil;
    self.operatorPublicKey = [message UInt384AtOffset:offset];
    offset += 48;
    
    if (length - offset < 20) return nil;
    self.keyIDVoting = [message UInt160AtOffset:offset];
    offset += 20;
    
    if (length - offset < 1) return nil;
    self.isValid = [message UInt8AtOffset:offset];
    offset += 1;
    
    self.simplifiedMasternodeEntryHash = [self calculateSimplifiedMasternodeEntryHash];
    self.chain = chain;
    
    return self;
}

-(void)setConfirmedHash:(UInt256)confirmedHash {
    _confirmedHash = confirmedHash;
    if (!uint256_is_zero(self.providerRegistrationTransactionHash)) {
        [self updateConfirmedHashHashedWithProviderRegistrationTransactionHash];
    }
}

-(void)setProviderRegistrationTransactionHash:(UInt256)providerRegistrationTransactionHash {
    _providerRegistrationTransactionHash = providerRegistrationTransactionHash;
    if (!uint256_is_zero(self.confirmedHash)) {
        [self updateConfirmedHashHashedWithProviderRegistrationTransactionHash];
    }
}

-(void)updateConfirmedHashHashedWithProviderRegistrationTransactionHash {
    NSMutableData * combinedData = [NSMutableData data];
    [combinedData appendData:[NSData dataWithUInt256:self.confirmedHash].reverse];
    [combinedData appendData:[NSData dataWithUInt256:self.providerRegistrationTransactionHash].reverse];
    self.confirmedHashHashedWithProviderRegistrationTransactionHash = [NSData dataWithUInt256:combinedData.SHA256].reverse.UInt256;
}

+(uint32_t)payloadLength {
    return 151;
}

-(NSString*)uniqueID {
    return [NSData dataWithUInt256:self.providerRegistrationTransactionHash].shortHexString;
}

-(DSSimplifiedMasternodeEntryEntity*)simplifiedMasternodeEntryEntity {
    DSSimplifiedMasternodeEntryEntity * simplifiedMasternodeEntryEntity = [DSSimplifiedMasternodeEntryEntity anyObjectMatching:@"providerRegistrationTransactionHash = %@",[NSData dataWithUInt256:self.providerRegistrationTransactionHash]];
    return simplifiedMasternodeEntryEntity;
}

-(DSBLSKey*)operatorPublicBLSKey {
    if (!_operatorPublicBLSKey) {
        _operatorPublicBLSKey = [DSBLSKey blsKeyWithPublicKey:self.operatorPublicKey onChain:self.chain];
    }
    return _operatorPublicBLSKey;
}

-(BOOL)verifySignature:(UInt768)signature forMessageDigest:(UInt256)messageDigest {
    DSBLSKey * operatorPublicBLSKey = [self operatorPublicBLSKey];
    return [operatorPublicBLSKey verify:messageDigest signature:signature];
}

@end
