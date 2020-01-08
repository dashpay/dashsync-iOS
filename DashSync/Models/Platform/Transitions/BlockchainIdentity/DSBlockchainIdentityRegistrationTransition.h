//
//  DSBlockchainIdentityRegistrationTransition.h
//  DashSync
//
//  Created by Sam Westrich on 7/12/18.
//

#import "DSTransition.h"
#import "BigIntTypes.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, DSBlockchainIdentityType) {
    DSBlockchainIdentityType_User = 1,
};

@class DSECDSAKey,DSBLSKey;

@interface DSBlockchainIdentityRegistrationTransition : DSTransition

@property (nonatomic,readonly) NSDictionary <NSNumber*,DSKey*>* publicKeys;
@property (nonatomic,readonly) DSUTXO lockedOutpoint;

-(instancetype)initWithVersion:(uint16_t)version forIdentityType:(DSBlockchainIdentityType)identityType registeringPublicKeys:(NSDictionary <NSNumber*,DSKey*>*)publicKeys usingLockedOutpoint:(DSUTXO)lockedOutpoint onChain:(DSChain *)chain;

@end

NS_ASSUME_NONNULL_END
