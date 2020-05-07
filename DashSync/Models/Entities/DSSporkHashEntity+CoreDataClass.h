//
//  DSSporkHashEntity+CoreDataClass.h
//  DashSync
//
//  Created by Sam Westrich on 7/17/18.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class DSChainEntity, DSSporkEntity;

NS_ASSUME_NONNULL_BEGIN

@interface DSSporkHashEntity : NSManagedObject

+(DSSporkHashEntity*)sporkHashEntityWithHash:(NSData*)sporkHash onChainEntity:(DSChainEntity*)chainEntity;

+(NSArray*)sporkHashEntitiesWithHash:(NSOrderedSet*)sporkHashes onChainEntity:(DSChainEntity*)chainEntity;

+(NSArray*)standaloneSporkHashEntitiesOnChainEntity:(DSChainEntity*)chainEntity;

@end

NS_ASSUME_NONNULL_END

#import "DSSporkHashEntity+CoreDataProperties.h"
