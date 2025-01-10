//
//  DSIdentityRegistrationTransition.h
//  DashSync
//
//  Created by Sam Westrich on 7/12/18.
//

#import "BigIntTypes.h"
#import "DSIdentity.h"
#import "DSTransition.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSIdentityRegistrationTransition : DSTransition

@property (nonatomic, readonly) NSDictionary<NSNumber *, NSValue *> *publicKeys;
@property (nonatomic, readonly) DSUTXO lockedOutpoint;

- (instancetype)initWithVersion:(uint16_t)version
          registeringPublicKeys:(NSDictionary<NSNumber *, NSValue *> *)publicKeys
      usingAssetLockTransaction:(DSAssetLockTransaction *)assetLockTransaction
                        onChain:(DSChain *)chain;

@end

NS_ASSUME_NONNULL_END
