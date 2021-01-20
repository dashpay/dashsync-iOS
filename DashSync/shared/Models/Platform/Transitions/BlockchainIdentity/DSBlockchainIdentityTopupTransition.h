//
//  DSBlockchainIdentityTopupTransition.h
//  DashSync
//
//  Created by Sam Westrich on 7/30/18.
//

#import "BigIntTypes.h"
#import "DSTransition.h"

@class DSECDSAKey, DSChain;

@interface DSBlockchainIdentityTopupTransition : DSTransition

@property (nonatomic, assign) uint16_t blockchainIdentityTopupTransactionVersion;
@property (nonatomic, readonly) uint64_t topupAmount;


@end
