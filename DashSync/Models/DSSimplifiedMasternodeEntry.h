//
//  DSSimplifiedMasternodeEntry.h
//  DashSync
//
//  Created by Sam Westrich on 7/12/18.
//

#import <Foundation/Foundation.h>
#import "BigIntTypes.h"

@class DSChain,DSSimplifiedMasternodeEntryEntity;

@interface DSSimplifiedMasternodeEntry : NSObject

@property(nonatomic,readonly) UInt256 providerRegistrationTransactionHash;
@property(nonatomic,readonly) UInt256 confirmedHash;
@property(nonatomic,readonly) UInt256 confirmedHashHashedWithProviderRegistrationTransactionHash;
@property(nonatomic,readonly) UInt128 address;
@property(nonatomic,readonly) uint16_t port;
@property(nonatomic,readonly) UInt384 operatorPublicKey;
@property(nonatomic,readonly) UInt160 keyIDVoting;
@property(nonatomic,readonly) BOOL isValid;
@property(nonatomic,readonly) UInt256 simplifiedMasternodeEntryHash;
@property(nonatomic,readonly) DSChain * chain;
@property(nonatomic,readonly) NSData * payloadData;
@property(nonatomic,readonly) NSString * uniqueID;
@property(nonatomic,readonly,class) uint32_t payloadLength;
@property(nonatomic,readonly) DSSimplifiedMasternodeEntryEntity * simplifiedMasternodeEntryEntity;

+(instancetype)simplifiedMasternodeEntryWithData:(NSData*)data onChain:(DSChain*)chain;

+(instancetype)simplifiedMasternodeEntryWithProviderRegistrationTransactionHash:(UInt256)providerRegistrationTransactionHash confirmedHash:(UInt256)confirmedHash address:(UInt128)address port:(uint16_t)port operatorBLSPublicKey:(UInt384)operatorBLSPublicKey keyIDVoting:(UInt160)keyIDVoting isValid:(BOOL)isValid onChain:(DSChain*)chain;

+(instancetype)simplifiedMasternodeEntryWithProviderRegistrationTransactionHash:(UInt256)providerRegistrationTransactionHash confirmedHash:(UInt256)confirmedHash address:(UInt128)address port:(uint16_t)port operatorBLSPublicKey:(UInt384)operatorBLSPublicKey keyIDVoting:(UInt160)keyIDVoting isValid:(BOOL)isValid simplifiedMasternodeEntryHash:(UInt256)simplifiedMasternodeEntryHash onChain:(DSChain*)chain;

-(BOOL)verifySignature:(UInt768)signature forMessageDigest:(UInt256)messageDigest;

@end
