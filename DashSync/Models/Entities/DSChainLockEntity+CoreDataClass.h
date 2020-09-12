//
//  DSChainLockEntity+CoreDataClass.h
//  DashSync
//
//  Created by Sam Westrich on 11/25/19.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class DSMerkleBlockEntity, DSQuorumEntryEntity, DSChain, DSChainLock, DSChainEntity;

NS_ASSUME_NONNULL_BEGIN

@interface DSChainLockEntity : NSManagedObject

- (DSChainLock *)chainLockForChain:(DSChain*)chain;
+ (instancetype)chainLockEntityForChainLock:(DSChainLock *)chainLock inContext:(NSManagedObjectContext*)context;

@end

NS_ASSUME_NONNULL_END

#import "DSChainLockEntity+CoreDataProperties.h"
