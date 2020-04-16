//
//  DSSpecialTransactionsWalletHolder.h
//  DashSync
//
//  Created by Sam Westrich on 3/5/19.
//

#import <Foundation/Foundation.h>
#import "BigIntTypes.h"


@class DSWallet, DSTransaction, DSCreditFundingTransaction, DSBlockchainIdentityRegistrationTransition, DSBlockchainIdentityUpdateTransition;

NS_ASSUME_NONNULL_BEGIN

@interface DSSpecialTransactionsWalletHolder : NSObject

@property (nonatomic,readonly) NSArray * allTransactions;

-(instancetype)initWithWallet:(DSWallet*)wallet inContext:(NSManagedObjectContext* _Nullable)managedObjectContext;

-(DSTransaction* _Nullable)transactionForHash:(UInt256)transactionHash;

- (BOOL)registerTransaction:(DSTransaction*)transaction saveImmediately:(BOOL)saveImmediately;

- (void)removeAllTransactions;

-(DSCreditFundingTransaction*)creditFundingTransactionForBlockchainIdentityUniqueId:(UInt256)blockchainIdentityUniqueId;

//// This gets a blockchain user registration transaction that has a specific public key hash (will change to BLS pub key)
//- (DSBlockchainIdentityRegistrationTransition*)blockchainIdentityRegistrationTransactionForPublicKeyHash:(UInt160)publicKeyHash;
//
//// This gets a blockchain user reset transaction that has a specific public key hash (will change to BLS pub key)
//- (DSBlockchainIdentityUpdateTransition*)blockchainIdentityResetTransactionForPublicKeyHash:(UInt160)publicKeyHash;
//
//- (NSArray<DSTransaction*>*)identityTransitionsForRegistrationTransitionHash:(UInt256)blockchainIdentityRegistrationTransactionHash;
//
//- (UInt256)lastSubscriptionTransactionHashForRegistrationTransactionHash:(UInt256)blockchainIdentityRegistrationTransactionHash;

// this is used to save transactions atomically with the block, needs to be called before switching threads to save the block
- (void)prepareForIncomingTransactionPersistenceForBlockSaveWithNumber:(uint32_t)blockNumber;

// this is used to save transactions atomically with the block
- (void)persistIncomingTransactionsAttributesForBlockSaveWithNumber:(uint32_t)blockNumber inContext:(NSManagedObjectContext*)context;

@end

NS_ASSUME_NONNULL_END
