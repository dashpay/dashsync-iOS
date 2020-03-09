//
//  DSSpecialTransactionsWalletHolder.h
//  DashSync
//
//  Created by Sam Westrich on 3/5/19.
//

#import "BigIntTypes.h"
#import <Foundation/Foundation.h>

@class DSWallet, DSTransaction, DSCreditFundingTransaction, DSBlockchainIdentityRegistrationTransition, DSBlockchainIdentityUpdateTransition;

NS_ASSUME_NONNULL_BEGIN

@interface DSSpecialTransactionsWalletHolder : NSObject

@property (nonatomic, readonly) NSArray *allTransactions;

- (instancetype)initWithWallet:(DSWallet *)wallet inContext:(NSManagedObjectContext *_Nullable)managedObjectContext;

- (DSTransaction *)transactionForHash:(UInt256)transactionHash;

- (BOOL)registerTransaction:(DSTransaction *)transaction;

- (void)removeAllTransactions;

- (DSCreditFundingTransaction *)creditFundingTransactionForBlockchainIdentityUniqueId:(UInt256)blockchainIdentityUniqueId;

//// This gets a blockchain user registration transaction that has a specific public key hash (will change to BLS pub key)
//- (DSBlockchainIdentityRegistrationTransition*)blockchainIdentityRegistrationTransactionForPublicKeyHash:(UInt160)publicKeyHash;
//
//// This gets a blockchain user reset transaction that has a specific public key hash (will change to BLS pub key)
//- (DSBlockchainIdentityUpdateTransition*)blockchainIdentityResetTransactionForPublicKeyHash:(UInt160)publicKeyHash;
//
//- (NSArray<DSTransaction*>*)identityTransitionsForRegistrationTransitionHash:(UInt256)blockchainIdentityRegistrationTransactionHash;
//
//- (UInt256)lastSubscriptionTransactionHashForRegistrationTransactionHash:(UInt256)blockchainIdentityRegistrationTransactionHash;

@end

NS_ASSUME_NONNULL_END
