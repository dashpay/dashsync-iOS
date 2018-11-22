//
//  DSTransactionManager+Protected.h
//  DashSync
//
//  Created by Sam Westrich on 11/21/18.
//

#import "DSTransactionManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSTransactionManager ()

@property (nonatomic, readonly) NSDictionary *txRelays, *txRequests;
@property (nonatomic, readonly) NSDictionary *publishedTx, *publishedCallback;

- (void)addTransactionToPublishList:(DSTransaction *)transaction;
- (void)clearTransactionRelaysForPeer:(DSPeer*)peer;
- (void)removeUnrelayedTransactions;
- (void)updateTransactionsBloomFilter;

@end

NS_ASSUME_NONNULL_END
