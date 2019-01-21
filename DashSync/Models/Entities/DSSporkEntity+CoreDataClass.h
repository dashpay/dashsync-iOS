//
//  DSSporkEntity+CoreDataClass.h
//  DashSync
//
//  Created by Sam Westrich on 5/28/18.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

@class DSSpork,DSChainEntity,DSSporkHashEntity;

@interface DSSporkEntity : NSManagedObject

+ (NSArray<DSSporkEntity*>*)sporksOnChain:(DSChainEntity*)chainEntity;
+ (void)deleteSporksOnChain:(DSChainEntity*)chainEntity;
- (void)setAttributesFromSpork:(DSSpork *)spork withSporkHash:(DSSporkHashEntity*)sporkHash;

@end

NS_ASSUME_NONNULL_END

#import "DSSporkEntity+CoreDataProperties.h"
