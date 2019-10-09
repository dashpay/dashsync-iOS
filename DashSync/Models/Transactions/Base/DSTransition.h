//
//  DSTransition.h
//  DashSync
//
//  Created by Sam Westrich on 7/12/18.
//

#import "DSTransaction.h"
#import "BigIntTypes.h"

NS_ASSUME_NONNULL_BEGIN

@class DSBLSKey;

@interface DSTransition : DSTransaction

@property (nonatomic,assign) uint16_t transitionVersion;
@property (nonatomic,assign) UInt256 registrationTransactionHash;
@property (nonatomic,assign) UInt256 previousTransitionHash;
@property (nonatomic,assign) uint64_t creditFee;
@property (nonatomic,assign) UInt256 packetHash;
@property (nonatomic,assign) UInt768 payloadSignature;

-(instancetype)initWithTransitionVersion:(uint16_t)version registrationTransactionHash:(UInt256)registrationTransactionHash previousTransitionHash:(UInt256)previousTransitionHash creditFee:(uint64_t)creditFee packetHash:(UInt256)packetHash onChain:(DSChain * _Nonnull)chain;

-(instancetype)initWithVersion:(uint16_t)version payloadData:(NSData *)message onChain:(DSChain *)chain;


-(void)signPayloadWithKey:(DSBLSKey *)privateKey;

@end

NS_ASSUME_NONNULL_END
