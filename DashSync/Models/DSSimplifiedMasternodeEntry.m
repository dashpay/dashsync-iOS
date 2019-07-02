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
#import <arpa/inet.h>
#import "DSWallet.h"

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
@property(nonatomic,strong) NSMutableDictionary * mPreviousOperatorPublicKeys;
@property(nonatomic,strong) NSMutableDictionary * mPreviousValidity;
@property(nonatomic,strong) NSMutableDictionary * mPreviousSimplifiedMasternodeEntryHashes;

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

+(instancetype)simplifiedMasternodeEntryWithProviderRegistrationTransactionHash:(UInt256)providerRegistrationTransactionHash confirmedHash:(UInt256)confirmedHash address:(UInt128)address port:(uint16_t)port operatorBLSPublicKey:(UInt384)operatorBLSPublicKey previousOperatorBLSPublicKeys:(NSDictionary*)previousOperatorBLSPublicKeys keyIDVoting:(UInt160)keyIDVoting isValid:(BOOL)isValid previousValidity:(NSDictionary *)previousValidity simplifiedMasternodeEntryHash:(UInt256)simplifiedMasternodeEntryHash previousSimplifiedMasternodeEntryHashes:(NSDictionary *)previousSimplifiedMasternodeEntryHashes onChain:(DSChain *)chain {
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
    simplifiedMasternodeEntry.mPreviousOperatorPublicKeys = previousOperatorBLSPublicKeys?[previousOperatorBLSPublicKeys mutableCopy]:[NSMutableDictionary
                                                                                                                                        dictionary];
    simplifiedMasternodeEntry.mPreviousSimplifiedMasternodeEntryHashes = previousSimplifiedMasternodeEntryHashes?[previousSimplifiedMasternodeEntryHashes mutableCopy]:[NSMutableDictionary dictionary];
    simplifiedMasternodeEntry.mPreviousValidity = previousValidity?[previousValidity mutableCopy]:[NSMutableDictionary dictionary];
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
    self.mPreviousOperatorPublicKeys = [NSMutableDictionary dictionary];
    self.mPreviousSimplifiedMasternodeEntryHashes = [NSMutableDictionary dictionary];
    self.mPreviousValidity = [NSMutableDictionary dictionary];
    self.chain = chain;
    
    return self;
}

-(void)keepInfoOfPreviousEntryVersion:(DSSimplifiedMasternodeEntry*)masternodeEntry atBlockHash:(UInt256)blockHash {
    [self updatePreviousValidity:masternodeEntry atBlockHash:blockHash];
    [self updatePreviousOperatorPublicKeysFromPreviousSimplifiedMasternodeEntry:masternodeEntry atBlockHash:blockHash];
    [self updatePreviousSimplifiedMasternodeEntryHashesFromPreviousSimplifiedMasternodeEntry:masternodeEntry atBlockHash:blockHash];
}

-(void)updatePreviousValidity:(DSSimplifiedMasternodeEntry *)masternodeEntry atBlockHash:(UInt256)blockHash {
    if (!uint256_eq(self.providerRegistrationTransactionHash,masternodeEntry.providerRegistrationTransactionHash)) return;
    self.mPreviousValidity = [masternodeEntry.previousValidity mutableCopy];
    if (masternodeEntry.isValid != self.isValid) {
        //we changed validity
        DSDLog(@"Changed validity from %u to %u on %@",masternodeEntry.isValid, self.isValid,uint256_hex(self.providerRegistrationTransactionHash));
        [self.mPreviousValidity setObject:@(masternodeEntry.isValid) forKey:uint256_data(blockHash)];
    }
}

-(void)updatePreviousOperatorPublicKeysFromPreviousSimplifiedMasternodeEntry:(DSSimplifiedMasternodeEntry*)masternodeEntry atBlockHash:(UInt256)blockHash {
    if (!uint256_eq(self.providerRegistrationTransactionHash,masternodeEntry.providerRegistrationTransactionHash)) return;
    self.mPreviousOperatorPublicKeys = [masternodeEntry.previousOperatorPublicKeys mutableCopy];
    if (!uint384_eq(masternodeEntry.operatorPublicKey,self.operatorPublicKey)) {
        //the operator public key changed
        DSDLog(@"Changed sme operator keys from %@ to %@ on %@",uint384_hex(masternodeEntry.operatorPublicKey), uint384_hex(self.operatorPublicKey),uint256_hex(self.providerRegistrationTransactionHash));
        [self.mPreviousOperatorPublicKeys setObject:uint384_data(masternodeEntry.operatorPublicKey) forKey:uint256_data(blockHash)];
    }
}

-(void)updatePreviousSimplifiedMasternodeEntryHashesFromPreviousSimplifiedMasternodeEntry:(DSSimplifiedMasternodeEntry*)masternodeEntry atBlockHash:(UInt256)blockHash {
    if (!uint256_eq(self.providerRegistrationTransactionHash,masternodeEntry.providerRegistrationTransactionHash)) return;
    self.mPreviousSimplifiedMasternodeEntryHashes = [masternodeEntry.previousSimplifiedMasternodeEntryHashes mutableCopy];
    if (!uint256_eq(masternodeEntry.simplifiedMasternodeEntryHash,self.simplifiedMasternodeEntryHash)) {
        //the hashes changed
        DSDLog(@"Changed sme hashes from %@ to %@ on %@",uint256_hex(masternodeEntry.simplifiedMasternodeEntryHash),uint256_hex(self.simplifiedMasternodeEntryHash),uint256_hex(self.providerRegistrationTransactionHash));
        [self.mPreviousSimplifiedMasternodeEntryHashes setObject:uint256_data(masternodeEntry.simplifiedMasternodeEntryHash) forKey:uint256_data(blockHash)];
    }
}

-(NSDictionary*)previousValidity {
    return [self.mPreviousValidity copy];
}

-(NSDictionary*)previousOperatorPublicKeys {
    return [self.mPreviousOperatorPublicKeys copy];
}

-(NSDictionary*)previousSimplifiedMasternodeEntryHashes {
    return [self.mPreviousSimplifiedMasternodeEntryHashes copy];
}

-(BOOL)isValidAtBlockHash:(UInt256)blockHash {
    if (![self.mPreviousValidity count]) return self.isValid;
    uint32_t blockHeight = [self.chain heightForBlockHash:blockHash];
    NSDictionary <NSData*,NSNumber*> * previousValidity = self.previousValidity;
    uint32_t usedHeight = 0;
    BOOL isValid = self.isValid;
    for (NSData * block in previousValidity) {
        uint32_t height = [self.chain heightForBlockHash:block.UInt256];
        if (blockHeight < height && height > usedHeight) {
            usedHeight = height;
            DSDLog(@"Using %@ instead of %@ for list <%@> at block height %u",previousValidity[block].boolValue?@"YES":@"NO",isValid?@"YES":@"NO",uint256_hex(blockHash), blockHeight);
            isValid = previousValidity[block].boolValue;
        }
    }
    return isValid;
}

-(UInt256)simplifiedMasternodeEntryHashAtBlockHash:(UInt256)blockHash {
    if (![self.mPreviousSimplifiedMasternodeEntryHashes count]) return self.simplifiedMasternodeEntryHash;
    uint32_t blockHeight = [self.chain heightForBlockHash:blockHash];
    NSDictionary <NSData*,NSData*> * previousSimplifiedMasternodeEntryHashes = self.previousSimplifiedMasternodeEntryHashes;
    uint32_t usedHeight = 0;
    UInt256 usedSimplifiedMasternodeEntryHash = self.simplifiedMasternodeEntryHash;
    for (NSData * block in previousSimplifiedMasternodeEntryHashes) {
        uint32_t height = [self.chain heightForBlockHash:block.UInt256];
        if (blockHeight < height && height > usedHeight) {
            usedHeight = height;
            DSDLog(@"Using %@ instead of %@ for list <%@> at block height %u",uint256_hex(previousSimplifiedMasternodeEntryHashes[block].UInt256),uint256_hex(usedSimplifiedMasternodeEntryHash),uint256_hex(blockHash), blockHeight);
            usedSimplifiedMasternodeEntryHash = previousSimplifiedMasternodeEntryHashes[block].UInt256;
        }
    }
    return usedSimplifiedMasternodeEntryHash;
}

-(UInt384)operatorPublicKeyAtBlockHash:(UInt256)blockHash {
    if (![self.mPreviousOperatorPublicKeys count]) return self.operatorPublicKey;
    uint32_t blockHeight = [self.chain heightForBlockHash:blockHash];
    NSDictionary <NSData*,NSData*> * previousOperatorPublicKeyAtBlockHashes = self.previousOperatorPublicKeys;
    uint32_t usedHeight = 0;
    UInt384 usedPreviousOperatorPublicKeyAtBlockHash = self.operatorPublicKey;
    for (NSData * block in previousOperatorPublicKeyAtBlockHashes) {
        uint32_t height = [self.chain heightForBlockHash:block.UInt256];
        if (blockHeight < height && height > usedHeight) {
            usedHeight = height;
            DSDLog(@"Using %@ instead of %@ for list at block height %u",uint256_hex(previousOperatorPublicKeyAtBlockHashes[block].UInt256),uint384_hex(usedPreviousOperatorPublicKeyAtBlockHash),blockHeight);
            usedPreviousOperatorPublicKeyAtBlockHash = previousOperatorPublicKeyAtBlockHashes[block].UInt384;
        }
    }
    return usedPreviousOperatorPublicKeyAtBlockHash;
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
    NSData * confirmedHashData = [NSData dataWithUInt256:self.confirmedHash];
    NSData * providerRegistrationTransactionHashData = [NSData dataWithUInt256:self.providerRegistrationTransactionHash];
    [combinedData appendData:providerRegistrationTransactionHashData];
    [combinedData appendData:confirmedHashData];
    NSData * confirmedHashHashedWithProviderRegistrationTransactionHashData = [NSData dataWithUInt256:combinedData.SHA256];
    self.confirmedHashHashedWithProviderRegistrationTransactionHash = confirmedHashHashedWithProviderRegistrationTransactionHashData.UInt256;
}

+(uint32_t)payloadLength {
    return 151;
}

-(NSString*)host {
    char s[INET6_ADDRSTRLEN];
    
    if (_address.u64[0] == 0 && _address.u32[2] == CFSwapInt32HostToBig(0xffff)) {
        return @(inet_ntop(AF_INET, &_address.u32[3], s, sizeof(s)));
    }
    else return @(inet_ntop(AF_INET6, &_address, s, sizeof(s)));
}

-(NSString*)uniqueID {
    return [NSData dataWithUInt256:self.providerRegistrationTransactionHash].shortHexString;
}

-(DSSimplifiedMasternodeEntryEntity*)simplifiedMasternodeEntryEntity {
    DSSimplifiedMasternodeEntryEntity * simplifiedMasternodeEntryEntity = [DSSimplifiedMasternodeEntryEntity anyObjectMatching:@"providerRegistrationTransactionHash = %@",[NSData dataWithUInt256:self.providerRegistrationTransactionHash]];
    return simplifiedMasternodeEntryEntity;
}

-(DSBLSKey*)operatorPublicBLSKey {
    if (!_operatorPublicBLSKey && !uint384_is_zero(self.operatorPublicKey)) {
        _operatorPublicBLSKey = [DSBLSKey blsKeyWithPublicKey:self.operatorPublicKey onChain:self.chain];
    }
    return _operatorPublicBLSKey;
}

-(BOOL)verifySignature:(UInt768)signature forMessageDigest:(UInt256)messageDigest {
    DSBLSKey * operatorPublicBLSKey = [self operatorPublicBLSKey];
    if (!operatorPublicBLSKey) return NO;
    return [operatorPublicBLSKey verify:messageDigest signature:signature];
}

-(NSString*)votingAddress {
    return [[NSData dataWithUInt160:self.keyIDVoting] addressFromHash160DataForChain:self.chain];
}

-(NSString*)operatorAddress {
    return [DSKey addressWithPublicKeyData:[NSData dataWithUInt384:self.operatorPublicKey] forChain:self.chain];
}

-(NSString*)description {
    return [NSString stringWithFormat:@"<DSSimplifiedMasternodeEntry: %@ {valid:%@}>",self.host,@(self.isValid)];
}

- (BOOL)isEqual:(id)other
{
    DSSimplifiedMasternodeEntry* entry = (DSSimplifiedMasternodeEntry*)other;
    if (![other isKindOfClass:[DSSimplifiedMasternodeEntry class]]) return NO;
    if (other == self) {
        return YES;
    } else if (uint256_eq(self.providerRegistrationTransactionHash, entry.providerRegistrationTransactionHash)) {
        return YES;
    } else {
        return NO;
    }
}


-(NSDictionary*)compare:(DSSimplifiedMasternodeEntry*)other ourBlockHash:(UInt256)ourBlockHash theirBlockHash:(UInt256)theirBlockHash {
    NSMutableDictionary * differences = [NSMutableDictionary dictionary];
    
    if (!uint128_eq(_address, other.address)) {
        differences[@"address"] = @{@"ours":uint128_data(_address),@"theirs":uint128_data(other.address)};
    }
    
    if (_port != other.port) {
        differences[@"port"] = @{@"ours":@(_port),@"theirs":@(other.port)};
    }
    
    if (!uint384_eq(_operatorPublicKey, other.operatorPublicKey)) {
        differences[@"operatorPublicKey"] = @{@"ours":uint384_data(_operatorPublicKey),@"theirs":uint384_data(other.operatorPublicKey)};
    }
    
    if (!uint160_eq(_keyIDVoting, other.keyIDVoting)) {
        differences[@"keyIDVoting"] = @{@"ours":uint160_data(_keyIDVoting),@"theirs":uint160_data(other.keyIDVoting)};
    }
    
    BOOL ourIsValid = [self isValidAtBlockHash:ourBlockHash];
    BOOL theirIsValid = [other isValidAtBlockHash:theirBlockHash];
    
    if (ourIsValid != theirIsValid) {
        differences[@"isValid"] = @{@"ours":ourIsValid?@"YES":@"NO",@"theirs":theirIsValid?@"YES":@"NO"};
    }
    
    UInt256 ourSimplifiedMasternodeEntryHash = [self simplifiedMasternodeEntryHashAtBlockHash:ourBlockHash];
    UInt256 theirSimplifiedMasternodeEntryHash = [other simplifiedMasternodeEntryHashAtBlockHash:theirBlockHash];
    
    if (!uint256_eq(ourSimplifiedMasternodeEntryHash,theirSimplifiedMasternodeEntryHash)) {
        differences[@"simplifiedMasternodeEntryHashAtBlockHash"] = @{@"ours":uint256_hex(ourSimplifiedMasternodeEntryHash),@"theirs":uint256_hex(theirSimplifiedMasternodeEntryHash),@"ourBlockHeight":@([self.chain heightForBlockHash:ourBlockHash]),@"theirBlockHeight":@([self.chain heightForBlockHash:theirBlockHash])};
    }
    
    if (![self.previousSimplifiedMasternodeEntryHashes isEqualToDictionary:other.previousSimplifiedMasternodeEntryHashes]) {
        differences[@"previousSimplifiedMasternodeEntryHashes"] = @{@"ours":self.previousSimplifiedMasternodeEntryHashes,@"theirs":other.previousSimplifiedMasternodeEntryHashes};
    }
    
    if (!uint256_eq(_confirmedHash, other.confirmedHash)) {
        differences[@"confirmedHash"] = @{@"ours":uint256_data(_confirmedHash),@"theirs":uint256_data(other.confirmedHash)};
    }
    
    return differences;
}

-(NSDictionary*)compare:(DSSimplifiedMasternodeEntry*)other atBlockHash:(UInt256)blockHash {
    return [self compare:other ourBlockHash:blockHash theirBlockHash:blockHash];
//    @property(nonatomic,assign) UInt256 confirmedHashHashedWithProviderRegistrationTransactionHash;
//    @property(nonatomic,assign) UInt256 simplifiedMasternodeEntryHash;

//    @property(nonatomic,strong) NSMutableDictionary * mPreviousOperatorPublicKeys;
//    @property(nonatomic,strong) NSMutableDictionary * mPreviousSimplifiedMasternodeEntryHashes;
}

@end
