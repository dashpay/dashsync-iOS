//
//  DSSpecialTransactionsWalletHolder.h
//  DashSync
//
//  Created by Sam Westrich on 3/5/19.
//

#import "BigIntTypes.h"
#import <Foundation/Foundation.h>


@class DSWallet, DSTransaction;

NS_ASSUME_NONNULL_BEGIN

@interface DSSpecialTransactionsWalletHolder : NSObject

@property (nonatomic, readonly) NSArray *allTransactions;

- (instancetype)initWithWallet:(DSWallet *)wallet inContext:(NSManagedObjectContext *_Nullable)managedObjectContext;

- (DSTransaction *_Nullable)transactionForHash:(UInt256)transactionHash;

- (BOOL)registerTransaction:(DSTransaction *)transaction saveImmediately:(BOOL)saveImmediately;

- (void)removeAllTransactions;


//- (DSCreditFundingTransaction *)creditFundingTransactionForIdentityUniqueId:(UInt256)identityUniqueId;

//// This gets a blockchain user registration transaction that has a specific public key hash (will change to BLS pub key)
//- (DSIdentityRegistrationTransition*)identityRegistrationTransactionForPublicKeyHash:(UInt160)publicKeyHash;
//
//// This gets a blockchain user reset transaction that has a specific public key hash (will change to BLS pub key)
//- (DSIdentityUpdateTransition*)identityResetTransactionForPublicKeyHash:(UInt160)publicKeyHash;
//
//- (NSArray<DSTransaction*>*)identityTransitionsForRegistrationTransitionHash:(UInt256)identityRegistrationTransactionHash;
//
//- (UInt256)lastSubscriptionTransactionHashForRegistrationTransactionHash:(UInt256)identityRegistrationTransactionHash;

// this is used to save transactions atomically with the block, needs to be called before switching threads to save the block
- (void)prepareForIncomingTransactionPersistenceForBlockSaveWithNumber:(uint32_t)blockNumber;

// this is used to save transactions atomically with the block
- (void)persistIncomingTransactionsAttributesForBlockSaveWithNumber:(uint32_t)blockNumber inContext:(NSManagedObjectContext *)context;

- (NSArray *)setBlockHeight:(int32_t)height andTimestamp:(NSTimeInterval)timestamp forTransactionHashes:(NSArray *)txHashes;

@end

NS_ASSUME_NONNULL_END
