//
//  DSIdentityTopupTransition.h
//  DashSync
//
//  Created by Sam Westrich on 7/30/18.
//

#import "BigIntTypes.h"
#import "DSTransition.h"

@class DSChain;

@interface DSIdentityTopupTransition : DSTransition

@property (nonatomic, assign) uint16_t identityTopupTransactionVersion;
@property (nonatomic, readonly) uint64_t topupAmount;


@end
