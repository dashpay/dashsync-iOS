//
//  DSTransition.h
//  DashSync
//
//  Created by Sam Westrich on 7/12/18.
//

#import "BigIntTypes.h"
#import "DSBlockchainIdentity.h"

NS_ASSUME_NONNULL_BEGIN

//Special Transaction
//https://github.com/dashpay/dips/blob/master/dip-0002-special-transactions.md
typedef NS_ENUM(NSUInteger, DSTransitionType) {
    DSTransitionType_Classic = 12,
    DSTransitionType_IdentityRegistration = 8,
    DSTransitionType_IdentityTopUp = 9,
    DSTransitionType_IdentityUpdateKey = 10,
    DSTransitionType_IdentityCloseAccount = 11,
};


#define TS_VERSION    0x00000001u

@class DSKey, DSBlockchainIdentity;

@interface DSTransition : NSObject

@property (nonatomic, readonly) uint16_t version;
@property (nonatomic, readonly) uint16_t type;
@property (nonatomic, readonly) DSBlockchainIdentity * owner;
@property (nonatomic, readonly) UInt256 registrationTransactionHash;
@property (nonatomic, readonly) uint64_t creditFee;
@property (nonatomic, readonly) UInt256 transitionHash;

@property (nonatomic, readonly, getter = toData) NSData *data;

@property (nonatomic, readonly) DSChain * chain;
@property (nonatomic, readonly) DSAccount * account;
@property (nonatomic, readonly) Class entityClass;

@property (nonatomic, readonly) DSBlockchainIdentitySigningType payloadSignatureType;
@property (nonatomic, readonly) NSData * payloadSignatureData;

-(instancetype)initWithTransitionVersion:(uint16_t)version registrationTransactionHash:(UInt256)registrationTransactionHash previousTransitionHash:(UInt256)previousTransitionHash creditFee:(uint64_t)creditFee onChain:(DSChain * _Nonnull)chain;

-(instancetype)initWithVersion:(uint16_t)version payloadData:(NSData *)message onChain:(DSChain *)chain;


-(void)signPayloadWithKey:(DSKey *)privateKey;

@end

NS_ASSUME_NONNULL_END
