//
//  DSTransition.h
//  DashSync
//
//  Created by Sam Westrich on 7/12/18.
//

#import "BigIntTypes.h"
#import "DPBaseObject.h"
#import "DSBlockchainIdentity.h"

NS_ASSUME_NONNULL_BEGIN

//Special Transaction
//https://github.com/dashpay/dips/blob/master/dip-0002-special-transactions.md
typedef NS_ENUM(NSUInteger, DSTransitionType)
{
    DSTransitionType_DataContract = 0,
    DSTransitionType_Documents = 1,
    DSTransitionType_IdentityRegistration = 2,
    DSTransitionType_IdentityTopUp = 3,
    DSTransitionType_IdentityUpdateKey = 4,
    DSTransitionType_IdentityCloseAccount = 5,
};


#define TS_VERSION 0x00000001u

@class DSKey, DSBlockchainIdentity;

@interface DSTransition : DPBaseObject

@property (nonatomic, readonly) uint16_t version;
@property (nonatomic, readonly) DSTransitionType type;
@property (nonatomic, readonly) UInt256 blockchainIdentityUniqueId;
@property (nonatomic, readonly) uint64_t creditFee;
@property (nonatomic, readonly) UInt256 transitionHash;

@property (nonatomic, readonly, getter=toData) NSData *data;

@property (nonatomic, readonly) DSChain *chain;

@property (nonatomic, readonly) NSTimeInterval createdTimestamp;
@property (nonatomic, readonly) NSTimeInterval registeredTimestamp;

@property (nonatomic, readonly) DSKeyType signatureType;
@property (nonatomic, readonly) NSData *signatureData;
@property (nonatomic, readonly) uint32_t signaturePublicKeyId;

- (instancetype)initWithTransitionVersion:(uint16_t)version blockchainIdentityUniqueId:(UInt256)blockchainIdentityUniqueId onChain:(DSChain *_Nonnull)chain; //local creation

- (instancetype)initWithData:(NSData *)data onChain:(DSChain *)chain;

- (void)signWithKey:(DSKey *)privateKey atIndex:(uint32_t)index fromIdentity:(DSBlockchainIdentity *_Nullable)blockchainIdentity;

@end

NS_ASSUME_NONNULL_END
