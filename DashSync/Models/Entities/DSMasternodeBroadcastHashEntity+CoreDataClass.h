//
//  DSMasternodeBroadcastHashEntity+CoreDataClass.h
//  DashSync
//
//  Created by Sam Westrich on 6/8/18.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class DSMasternodeBroadcastEntity;

NS_ASSUME_NONNULL_BEGIN

@interface DSMasternodeBroadcastHashEntity : NSManagedObject

+(NSArray*)masternodeBroadcastHashEntitiesWithHashes:(NSOrderedSet*)masternodeBroadcastHashes;

@end

NS_ASSUME_NONNULL_END

#import "DSMasternodeBroadcastHashEntity+CoreDataProperties.h"
