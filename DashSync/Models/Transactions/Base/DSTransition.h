//
//  DSTransition.h
//  DashSync
//
//  Created by Sam Westrich on 7/12/18.
//

#import "DSTransaction.h"

@interface DSTransition : DSTransaction

@property (nonatomic,assign) uint16_t transitionVersion;
@property (nonatomic,assign) UInt256 registrationTransactionHash;
@property (nonatomic,assign) UInt256 previousTransitionHash;
@property (nonatomic,assign) uint64_t creditFee;
@property (nonatomic,assign) UInt256 packetHash;
@property (nonatomic,strong) NSData * payloadSignature;

-(instancetype)initWithTransitionVersion:(uint16_t)version registrationTransactionHash:(UInt256)registrationTransactionHash previousTransitionHash:(UInt256)previousTransitionHash creditFee:(uint64_t)creditFee onChain:(DSChain *)chain;

@end
