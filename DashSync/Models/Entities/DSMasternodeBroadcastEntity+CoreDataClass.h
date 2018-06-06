//
//  DSMasternodeBroadcastEntity+CoreDataClass.h
//  DashSync
//
//  Created by Sam Westrich on 6/4/18.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "DSMasternodeBroadcast.h"

NS_ASSUME_NONNULL_BEGIN

@class DSChainEntity;

@interface DSMasternodeBroadcastEntity : NSManagedObject

- (void)setAttributesFromMasternodeBroadcast:(DSMasternodeBroadcast * _Nonnull)masternodeBroadcast forChain:(DSChainEntity* _Nonnull)chainEntity;

@end

NS_ASSUME_NONNULL_END

#import "DSMasternodeBroadcastEntity+CoreDataProperties.h"
