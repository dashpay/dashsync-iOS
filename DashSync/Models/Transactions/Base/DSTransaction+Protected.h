//
//  DSTransaction+Protected.h
//  DashSync
//
//  Created by Sam Westrich on 4/9/19.
//

#import "DSTransaction.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, DSTransactionPersistenceStatus) {
    DSTransactionPersistenceStatus_NotSaved,
    DSTransactionPersistenceStatus_Saving,
    DSTransactionPersistenceStatus_Saved
};

@interface DSTransaction ()

@property (nonatomic, assign) DSTransactionPersistenceStatus persistenceStatus;
@property (nonatomic, readonly) DSTransactionEntity * transactionEntity;
@property (nonatomic, strong, nullable) DSInstantSendTransactionLock * instantSendLockAwaitingProcessing;
@property (nonatomic, assign) BOOL instantSendReceived;
@property (nonatomic, assign) BOOL hasUnverifiedInstantSendLock;

@end

NS_ASSUME_NONNULL_END
