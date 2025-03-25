//
//  DSInstantSendLockEntity+CoreDataClass.h
//  DashSync
//
//  Created by Sam Westrich on 5/19/19.
//
//

#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

@class DSTransactionEntity, DSInstantSendTransactionLock, DSChain;

NS_ASSUME_NONNULL_BEGIN

@interface DSInstantSendLockEntity : NSManagedObject

+ (DSInstantSendLockEntity *)instantSendLockEntityFromInstantSendLock:(DSInstantSendTransactionLock *)instantSendTransactionLock inContext:(NSManagedObjectContext *)context;
- (DSInstantSendTransactionLock *)instantSendTransactionLockForChain:(DSChain *)chain;
- (instancetype)setAttributesFromInstantSendTransactionLock:(DSInstantSendTransactionLock *)instantSendTransactionLock;

@end

NS_ASSUME_NONNULL_END

#import "DSInstantSendLockEntity+CoreDataProperties.h"
