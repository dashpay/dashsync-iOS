//
//  DSTransactionLockVoteEntity+CoreDataClass.h
//  DashSync
//
//  Created by Sam Westrich on 1/9/19.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class DSChainEntity, DSSimplifiedMasternodeEntryEntity, DSTransactionEntity,DSTransactionLockVote,DSChain;

NS_ASSUME_NONNULL_BEGIN

@interface DSTransactionLockVoteEntity : NSManagedObject

- (DSTransactionLockVote *)transactionLockVoteForChain:(DSChain*)chain;
- (instancetype)setAttributesFromTransactionLockVote:(DSTransactionLockVote *)transactionLockVote;

@end

NS_ASSUME_NONNULL_END

#import "DSTransactionLockVoteEntity+CoreDataProperties.h"
