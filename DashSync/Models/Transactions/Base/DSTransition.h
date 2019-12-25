//
//  DSTransition.h
//  DashSync
//
//  Created by Sam Westrich on 7/12/18.
//

#import "BigIntTypes.h"
#import "DSBlockchainIdentity.h"

NS_ASSUME_NONNULL_BEGIN

@class DSKey, DSBlockchainIdentity;

@interface DSTransition : NSObject

@property (nonatomic, readonly) uint16_t transitionVersion;
@property (nonatomic, readonly) DSBlockchainIdentity * owner;
@property (nonatomic, readonly) UInt256 registrationTransactionHash;
@property (nonatomic, readonly) uint64_t creditFee;
@property (nonatomic, readonly) UInt256 packetHash;

@property (nonatomic, readonly) DSChain * chain;
@property (nonatomic, readonly) DSAccount * account;
@property (nonatomic, readonly) Class entityClass;

@property (nonatomic, readonly) DSBlockchainIdentitySigningType payloadSignatureType;
@property (nonatomic, readonly) NSData * payloadSignatureData;

-(instancetype)initWithTransitionVersion:(uint16_t)version registrationTransactionHash:(UInt256)registrationTransactionHash previousTransitionHash:(UInt256)previousTransitionHash creditFee:(uint64_t)creditFee packetHash:(UInt256)packetHash onChain:(DSChain * _Nonnull)chain;

-(instancetype)initWithVersion:(uint16_t)version payloadData:(NSData *)message onChain:(DSChain *)chain;


-(void)signPayloadWithKey:(DSKey *)privateKey;

@end

NS_ASSUME_NONNULL_END
