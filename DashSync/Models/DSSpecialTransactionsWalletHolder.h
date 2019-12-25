//
//  DSSpecialTransactionsWalletHolder.h
//  DashSync
//
//  Created by Sam Westrich on 3/5/19.
//

#import <Foundation/Foundation.h>
#import "BigIntTypes.h"

@class DSWallet,DSTransaction,DSBlockchainIdentityRegistrationTransition,DSBlockchainIdentityResetTransition;

NS_ASSUME_NONNULL_BEGIN

@interface DSSpecialTransactionsWalletHolder : NSObject

@property (nonatomic,readonly) NSArray * allTransactions;

-(instancetype)initWithWallet:(DSWallet*)wallet inContext:(NSManagedObjectContext* _Nullable)managedObjectContext;

-(DSTransaction*)transactionForHash:(UInt256)transactionHash;

- (BOOL)registerTransaction:(DSTransaction*)transaction;

- (void)removeAllTransactions;

// This gets a blockchain user registration transaction that has a specific public key hash (will change to BLS pub key)
- (DSBlockchainIdentityRegistrationTransition*)blockchainIdentityRegistrationTransactionForPublicKeyHash:(UInt160)publicKeyHash;

// This gets a blockchain user reset transaction that has a specific public key hash (will change to BLS pub key)
- (DSBlockchainIdentityResetTransition*)blockchainIdentityResetTransactionForPublicKeyHash:(UInt160)publicKeyHash;

- (NSArray<DSTransaction*>*)identityTransitionsForRegistrationTransitionHash:(UInt256)blockchainIdentityRegistrationTransactionHash;

- (UInt256)lastSubscriptionTransactionHashForRegistrationTransactionHash:(UInt256)blockchainIdentityRegistrationTransactionHash;

@end

NS_ASSUME_NONNULL_END
