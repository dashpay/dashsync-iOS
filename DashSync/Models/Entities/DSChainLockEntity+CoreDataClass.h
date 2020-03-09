//
//  DSChainLockEntity+CoreDataClass.h
//  DashSync
//
//  Created by Sam Westrich on 11/25/19.
//
//

#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

@class DSMerkleBlockEntity, DSQuorumEntryEntity, DSChain, DSChainLock;

NS_ASSUME_NONNULL_BEGIN

@interface DSChainLockEntity : NSManagedObject

- (DSChainLock *)chainLockForChain:(DSChain *)chain;
- (instancetype)setAttributesFromChainLock:(DSChainLock *)chainLock;

@end

NS_ASSUME_NONNULL_END

#import "DSChainLockEntity+CoreDataProperties.h"
