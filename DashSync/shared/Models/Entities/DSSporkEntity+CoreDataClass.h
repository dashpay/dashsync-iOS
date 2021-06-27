//
//  DSSporkEntity+CoreDataClass.h
//  DashSync
//
//  Created by Sam Westrich on 5/28/18.
//
//

#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class DSSpork, DSChainEntity, DSSporkHashEntity;

@interface DSSporkEntity : NSManagedObject

+ (NSArray<DSSporkEntity *> *)sporksonChainEntity:(DSChainEntity *)chainEntity;
+ (void)deleteSporksOnChainEntity:(DSChainEntity *)chainEntity;
- (void)setAttributesFromSpork:(DSSpork *)spork withSporkHash:(DSSporkHashEntity *)sporkHash;

@end

NS_ASSUME_NONNULL_END

#import "DSSporkEntity+CoreDataProperties.h"
