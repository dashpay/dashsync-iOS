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

#if !DASH_TESTNET
#define SPORK_PUBLIC_KEY @"04549ac134f694c0243f503e8c8a9a986f5de6610049c40b07816809b0d1d06a21b07be27b9bb555931773f62ba6cf35a25fd52f694d4e1106ccd237a7bb899fdd"
#else
#define SPORK_PUBLIC_KEY @"046f78dcf911fbd61910136f7f0f8d90578f68d0b3ac973b5040fb7afb501b5939f39b108b0569dca71488f5bbf498d92e4d1194f6f941307ffd95f75e76869f0e"
#endif

@interface DSSpork()

@property (nonatomic,strong) NSData * signature;
    
@end

@implementation DSSpork
    
    
+ (instancetype)sporkWithMessage:(NSData *)message
    {
        return [[DSSpork alloc] initWithMessage:message];
    }
    
- (instancetype)initWithMessage:(NSData *)message
{
    if (! (self = [self init])) return nil;
    
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
    
- (instancetype)initWithIdentifier:(DSSporkIdentifier)identifier value:(uint64_t)value timeSigned:(uint64_t)timeSigned signature:(NSData*)signature {
    if (! (self = [self init])) return nil;
    _identifier = identifier;
    _value = value;
    _timeSigned = timeSigned;
    _valid = TRUE;
    self.signature = signature;
    return self;
}
    
-(BOOL)isEqualToSpork:(DSSpork*)spork {
    return ((self.identifier == spork.identifier) && (self.value == spork.value) && (self.timeSigned == spork.timeSigned) && (self.valid == spork.valid));
}
    
-(BOOL)checkSignature:(NSData*)signature {
    NSString * stringMessage = [NSString stringWithFormat:@"%d%llu%llu",self.identifier,self.value,self.timeSigned];
    NSMutableData * stringMessageData = [NSMutableData data];
    [stringMessageData appendString:DASH_MESSAGE_MAGIC];
    [stringMessageData appendString:stringMessage];
    DSKey * sporkPublicKey = [DSKey keyWithPublicKey:[NSData dataFromHexString:SPORK_PUBLIC_KEY]];
    UInt256 messageDigest = stringMessageData.SHA256_2;
    DSKey * messagePublicKey = [DSKey keyRecoveredFromCompactSig:signature andMessageDigest:messageDigest];
    return [sporkPublicKey.publicKey isEqualToData:messagePublicKey.publicKey];
}
    
@end
