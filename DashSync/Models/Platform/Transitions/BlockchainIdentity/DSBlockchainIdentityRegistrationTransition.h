//
//  DSBlockchainIdentityRegistrationTransition.h
//  DashSync
//
//  Created by Sam Westrich on 7/12/18.
//

#import "BigIntTypes.h"
#import "DSBlockchainIdentity.h"
#import "DSTransition.h"

NS_ASSUME_NONNULL_BEGIN

@class DSECDSAKey, DSBLSKey;

@interface DSBlockchainIdentityRegistrationTransition : DSTransition

@property (nonatomic, readonly) NSDictionary<NSNumber *, DSKey *> *publicKeys;
@property (nonatomic, readonly) DSUTXO lockedOutpoint;

- (instancetype)initWithVersion:(uint16_t)version registeringPublicKeys:(NSDictionary<NSNumber *, DSKey *> *)publicKeys usingCreditFundingTransaction:(DSCreditFundingTransaction *)creditFundingTransaction onChain:(DSChain *)chain;

@end

NS_ASSUME_NONNULL_END
