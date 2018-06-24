//
//  DSSpork.m
//  dashwallet
//
//  Created by Sam Westrich on 10/18/17.
//  Copyright © 2017 Aaron Voisine. All rights reserved.
//

#import "DSSpork.h"
#import "NSData+Dash.h"
#import "NSData+Bitcoin.h"
#import "NSString+Dash.h"
#import "NSMutableData+Dash.h"
#import "DSKey.h"
#import "DSChain.h"

#define SPORK_PUBLIC_KEY_MAINNET @"04549ac134f694c0243f503e8c8a9a986f5de6610049c40b07816809b0d1d06a21b07be27b9bb555931773f62ba6cf35a25fd52f694d4e1106ccd237a7bb899fdd"

#define SPORK_PUBLIC_KEY_TESTNET @"046f78dcf911fbd61910136f7f0f8d90578f68d0b3ac973b5040fb7afb501b5939f39b108b0569dca71488f5bbf498d92e4d1194f6f941307ffd95f75e76869f0e"


#define SPORK_ADDRESS_MAINNET @"Xgtyuk76vhuFW2iT7UAiHgNdWXCf3J34wh"
#define SPORK_ADDRESS_TESTNET @"yjPtiKh2uwk3bDutTEA2q9mCtXyiZRWn55"

@interface DSSpork()

@property (nonatomic,strong) NSData * signature;
@property (nonatomic,strong) DSChain * chain;
    
@end

@implementation DSSpork


-(UInt256)sporkHash {
    //hash calculation
    NSMutableData * hashImportantData = [NSMutableData data];
    uint32_t index = (uint32_t)self.identifier;
    [hashImportantData appendBytes:&index length:4];
    uint64_t value = (uint64_t)self.value;
    [hashImportantData appendBytes:&value length:8];
    uint64_t timeSigned = (uint64_t)self.timeSigned;
    [hashImportantData appendBytes:&timeSigned length:8];
    return hashImportantData.SHA256_2;
}
    
    
+ (instancetype)sporkWithMessage:(NSData *)message onChain:(DSChain*)chain
    {
        return [[DSSpork alloc] initWithMessage:message onChain:chain];
    }
    
- (instancetype)initWithMessage:(NSData *)message onChain:(DSChain*)chain
{
    if (! (self = [self init])) return nil;
    _chain = chain;
    _identifier = [message UInt32AtOffset:0];
    _value = [message UInt64AtOffset:4];
    _timeSigned = [message UInt64AtOffset:12];
    NSNumber * lNumber = nil;
    NSData * signature = [message dataAtOffset:20 length:&lNumber];
//    NSUInteger l = lNumber.unsignedIntegerValue;
    _valid = [self checkSignature:signature];
    self.signature = signature;
    return self;
}
    
- (instancetype)initWithIdentifier:(DSSporkIdentifier)identifier value:(uint64_t)value timeSigned:(uint64_t)timeSigned signature:(NSData*)signature onChain:(DSChain*)chain {
    if (! (self = [self init])) return nil;
    _chain = chain;
    _identifier = identifier;
    _value = value;
    _timeSigned = timeSigned;
    _valid = TRUE;
    self.signature = signature;
    return self;
}
    
-(BOOL)isEqualToSpork:(DSSpork*)spork {
    return (([self.chain isEqual:spork.chain]) && (self.identifier == spork.identifier) && (self.value == spork.value) && (self.timeSigned == spork.timeSigned) && (self.valid == spork.valid));
}

-(BOOL)checkSignature70208Method:(NSData*)signature {
    NSString * stringMessage = [NSString stringWithFormat:@"%d%llu%llu",self.identifier,self.value,self.timeSigned];
    NSMutableData * stringMessageData = [NSMutableData data];
    [stringMessageData appendString:DASH_MESSAGE_MAGIC];
    [stringMessageData appendString:stringMessage];
    UInt256 messageDigest = stringMessageData.SHA256_2;
    DSKey * messagePublicKey = [DSKey keyRecoveredFromCompactSig:signature andMessageDigest:messageDigest];
    DSKey * sporkPublicKey = [DSKey keyWithPublicKey:[NSData dataFromHexString:[self sporkKey]]];
    return [sporkPublicKey.publicKey isEqualToData:messagePublicKey.publicKey];
}
    
-(BOOL)checkSignature:(NSData*)signature {

    if (self.chain.protocolVersion < 70209) {
        return [self checkSignature70208Method:signature];
    } else {
        DSKey * messagePublicKey = [DSKey keyRecoveredFromCompactSig:signature andMessageDigest:self.sporkHash];
        NSString * sporkAddress = [messagePublicKey addressForChain:self.chain];
        return [[self sporkAddress] isEqualToString:sporkAddress] | [self checkSignature70208Method:signature];
    }
}

-(NSString*)sporkKey {
    if ([self.chain isMainnet]) {
        return SPORK_PUBLIC_KEY_MAINNET;
    } else {
        return SPORK_PUBLIC_KEY_TESTNET;
    }
}

//starting in 12.3 sporks use addresses instead of public keys
-(NSString*)sporkAddress {
    if ([self.chain isMainnet]) {
        return SPORK_ADDRESS_MAINNET;
    } else {
        return SPORK_ADDRESS_TESTNET;
    }
}

-(NSString*) identifierString {
    switch (self.identifier) {
        case DSSporkIdentifier_Spork2InstantSendEnabled:
            return @"Instant Send enabled";
        case DSSporkIdentifier_Spork3InstantSendBlockFiltering:
            return @"Instant Send block filtering";
        case DSSporkIdentifier_Spork5InstantSendMaxValue:
            return @"Instant Send max value";
        case DSSporkIdentifier_Spork6NewSigs:
            return @"New Signature/Message Format";
        case DSSporkIdentifier_Spork8MasternodePaymentEnforcement:
            return @"Masternode payment enforcement";
        case DSSporkIdentifier_Spork9SuperblocksEnabled:
            return @"Superblocks enabled";
        case DSSporkIdentifier_Spork10MasternodePayUpdatedNodes:
            return @"Masternode pay updated nodes";
        case DSSporkIdentifier_Spork12ReconsiderBlocks:
            return @"Reconsider blocks";
        case DSSporkIdentifier_Spork13OldSuperblockFlag:
            return @"Old superblock flag";
        case DSSporkIdentifier_Spork14RequireSentinelFlag:
            return @"Require sentinel flag";
        case DSSporkIdentifier_Spork15DeterministicMasternodesEnabled:
            return @"Deterministic masternodese enabled at block";
        default:
            return @"Unknown spork";
            break;
    }
}
    
@end
