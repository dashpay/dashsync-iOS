//
//  DSTransitionEntity+CoreDataClass.h
//  DashSync
//
//  Created by Sam Westrich on 12/25/19.
//
//

#import "BigIntTypes.h"
#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

@class DSBlockchainIdentityEntity, DSTransition, DSChainEntity, DSChain;

NS_ASSUME_NONNULL_BEGIN

@interface DSTransitionEntity : NSManagedObject

- (instancetype)setAttributesFromTransition:(DSTransition *)transition;
- (DSTransition *)transitionForChain:(DSChain *)chain;
//+ (NSArray<DSTransitionEntity*> * _Nonnull)transitionsForChain:(DSChainEntity*)chain;

@property (nonatomic, readonly) Class transitionClass;

@property (nonatomic, readonly) UInt256 blockchainIdentityUniqueId;
@property (nonatomic, readonly) UInt256 transitionHash;

@end

NS_ASSUME_NONNULL_END

#import "DSTransitionEntity+CoreDataProperties.h"
