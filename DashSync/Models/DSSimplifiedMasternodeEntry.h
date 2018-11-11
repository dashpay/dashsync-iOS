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
@property(nonatomic,readonly) UInt128 address;
@property(nonatomic,readonly) uint16_t port;
@property(nonatomic,readonly) UInt160 keyIDOperator;
@property(nonatomic,readonly) UInt160 keyIDVoting;
@property(nonatomic,readonly) BOOL isValid;
@property(nonatomic,readonly) UInt256 simplifiedMasternodeEntryHash;
@property(nonatomic,readonly) DSChain * chain;
@property(nonatomic,readonly) NSData * payloadData;
@property(nonatomic,readonly) NSString * uniqueID;
@property(nonatomic,readonly) DSSimplifiedMasternodeEntryEntity * simplifiedMasternodeEntryEntity;

+(instancetype)simplifiedMasternodeEntryWithData:(NSData*)data onChain:(DSChain*)chain;

+(instancetype)simplifiedMasternodeEntryWithProviderRegistrationTransactionHash:(UInt256)providerRegistrationTransactionHash address:(UInt128)address port:(uint16_t)port keyIDOperator:(UInt160)keyIDOperator keyIDVoting:(UInt160)keyIDVoting isValid:(BOOL)isValid onChain:(DSChain*)chain;

+(instancetype)simplifiedMasternodeEntryWithProviderRegistrationTransactionHash:(UInt256)providerRegistrationTransactionHash address:(UInt128)address port:(uint16_t)port keyIDOperator:(UInt160)keyIDOperator keyIDVoting:(UInt160)keyIDVoting isValid:(BOOL)isValid simplifiedMasternodeEntryHash:(UInt256)simplifiedMasternodeEntryHash onChain:(DSChain*)chain;

@end
