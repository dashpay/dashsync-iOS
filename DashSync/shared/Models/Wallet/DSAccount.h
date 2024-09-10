//
//  DSWallet.h
//  DashSync
//
//  Created by Quantum Explorer on 05/11/18.
//  Copyright (c) 2018 Quantum Explorer <quantum@dash.org>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "DSFundsDerivationPath.h"
#import "DSIncomingFundsDerivationPath.h"
#import "DSTransaction.h"
#import "DSCoinControl.h"
#import "NSData+Dash.h"
#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *_Nonnull const DSAccountNewAccountFromTransactionNotification;
FOUNDATION_EXPORT NSString *_Nonnull const DSAccountNewAccountShouldBeAddedFromTransactionNotification;

@class DSFundsDerivationPath, DSIncomingFundsDerivationPathDSWallet, DSBlockchainIdentityRegistrationTransition, DSBlockchainIdentityUpdateTransition, DSCreditFundingTransaction;
@class DSCoinbaseTransaction, DSPotentialOneWayFriendship;

@interface DSAccount : NSObject

// BIP 43 derivation paths
@property (nullable, nonatomic, readonly) NSArray<DSDerivationPath *> *fundDerivationPaths;

@property (nullable, nonatomic, readonly) NSArray<DSDerivationPath *> *outgoingFundDerivationPaths;

@property (nullable, nonatomic, strong) DSFundsDerivationPath *defaultDerivationPath;

@property (nullable, nonatomic, readonly) DSFundsDerivationPath *bip44DerivationPath;

@property (nullable, nonatomic, readonly) DSFundsDerivationPath *bip32DerivationPath;

@property (nullable, nonatomic, readonly) DSDerivationPath *masterContactsDerivationPath;

@property (nullable, nonatomic, readonly) DSFundsDerivationPath *coinJoinDerivationPath;

@property (nullable, nonatomic, weak) DSWallet *wallet;

@property (nonatomic, readonly) NSString *uniqueID;

@property (nonatomic, readonly) uint32_t accountNumber;

@property (nonatomic, readonly) NSManagedObjectContext *managedObjectContext;

// current wallet balance excluding transactions known to be invalid
@property (nonatomic, readonly) uint64_t balance;

// NSValue objects containing UTXO structs
@property (nonatomic, readonly) NSArray<NSValue *> *unspentOutputs;

// latest 100 transactions sorted by date, most recent first
@property (atomic, readonly) NSArray<DSTransaction *> *recentTransactions;

// latest 100 transactions sorted by date, most recent first
@property (atomic, readonly) NSArray<DSTransaction *> *recentTransactionsWithInternalOutput;

// all wallet transactions sorted by date, most recent first
@property (atomic, readonly) NSArray<DSTransaction *> *allTransactions;

// all wallet transactions sorted by date, most recent first
@property (atomic, readonly) NSArray<DSCoinbaseTransaction *> *coinbaseTransactions;

// Does this account have any coinbase rewards
@property (nonatomic, readonly) BOOL hasCoinbaseTransaction;

// returns the first unused external address
@property (nullable, nonatomic, readonly) NSString *receiveAddress;

// returns the first unused internal address
@property (nullable, nonatomic, readonly) NSString *changeAddress;

// all previously generated external addresses
@property (nonatomic, readonly) NSArray<NSString *> *externalAddresses;

// all previously generated internal addresses
@property (nonatomic, readonly) NSArray<NSString *> *internalAddresses;

// returns the first unused coinjoin address
@property (nullable, nonatomic, readonly) NSString *coinJoinReceiveAddress;

// returns the first unused coinjoin internal address
@property (nullable, nonatomic, readonly) NSString *coinJoinChangeAddress;

// returns all issued CoinJoin receive addresses
@property (nullable, nonatomic, readonly) NSArray *usedCoinJoinReceiveAddresses;

// returns all used CoinJoin receive addresses
@property (nullable, nonatomic, readonly) NSArray *allCoinJoinReceiveAddresses;

// all the contacts for an account
@property (nonatomic, readonly) NSArray<DSPotentialOneWayFriendship *> *_Nonnull contacts;

// has an extended public key missing in one of the account derivation paths
@property (nonatomic, readonly) BOOL hasAnExtendedPublicKeyMissing;

- (NSArray *_Nullable)registerAddressesWithGapLimit:(NSUInteger)gapLimit unusedAccountGapLimit:(NSUInteger)unusedAccountGapLimit dashpayGapLimit:(NSUInteger)dashpayGapLimit internal:(BOOL)internal error:(NSError **)error;

+ (DSAccount *)accountWithAccountNumber:(uint32_t)accountNumber withDerivationPaths:(NSArray<DSDerivationPath *> *)derivationPaths inContext:(NSManagedObjectContext *_Nullable)context;

+ (NSArray<DSAccount *> *)standardAccountsToAccountNumber:(uint32_t)accountNumber onChain:(DSChain *)chain inContext:(NSManagedObjectContext *_Nullable)context;

- (instancetype)initWithAccountNumber:(uint32_t)accountNumber withDerivationPaths:(NSArray<DSDerivationPath *> *)derivationPaths inContext:(NSManagedObjectContext *_Nullable)context;

- (instancetype)initAsViewOnlyWithAccountNumber:(uint32_t)accountNumber withDerivationPaths:(NSArray<DSDerivationPath *> *)derivationPaths inContext:(NSManagedObjectContext *_Nullable)context;

- (void)removeDerivationPath:(DSDerivationPath *)derivationPath;

- (DSIncomingFundsDerivationPath *)derivationPathForFriendshipWithIdentifier:(NSData *)friendshipIdentifier;

- (void)removeIncomingDerivationPathForFriendshipWithIdentifier:(NSData *)friendshipIdentifier;

- (void)addDerivationPath:(DSDerivationPath *)derivationPath;

- (void)addIncomingDerivationPath:(DSIncomingFundsDerivationPath *)derivationPath forFriendshipIdentifier:(NSData *)friendshipIdentifier inContext:(NSManagedObjectContext *)context;

- (void)addOutgoingDerivationPath:(DSIncomingFundsDerivationPath *)derivationPath forFriendshipIdentifier:(NSData *)friendshipIdentifier inContext:(NSManagedObjectContext *)context;

- (void)addDerivationPathsFromArray:(NSArray<DSDerivationPath *> *)derivationPaths;

// largest amount that can be sent from the account after fees
@property (nonatomic, readonly) uint64_t maxOutputAmount;

- (uint64_t)maxOutputAmountWithConfirmationCount:(uint64_t)confirmationCount returnInputCount:(uint32_t *_Nullable)rInputCount;

// true if the address is controlled by the wallet
- (BOOL)containsAddress:(NSString *)address;

// true if the coinjoin address is controlled by the wallet
- (BOOL)containsCoinJoinAddress:(NSString *)coinJoinAddress;

// true if the address is internal and is controlled by the wallet
- (BOOL)containsInternalAddress:(NSString *)address;

// true if the address is external and is controlled by the wallet
- (BOOL)containsExternalAddress:(NSString *)address;

// true if the address is controlled by the wallet except for evolution addresses
- (BOOL)baseDerivationPathsContainAddress:(NSString *)address;

// the high level (hardened) derivation path containing the address
- (DSDerivationPath *_Nullable)derivationPathContainingAddress:(NSString *)address;

// the high level (hardened) derivation path containing the address that is external to the wallet, basically a friend's address
- (DSIncomingFundsDerivationPath *_Nullable)externalDerivationPathContainingAddress:(NSString *)address;

- (BOOL)transactionAddressAlreadySeenInOutputs:(NSString *)address;

// true if the address was previously used as an input or output in any wallet transaction (from this wallet only)
- (BOOL)addressIsUsed:(NSString *)address;

// returns an unsigned transaction that sends the specified amount from the wallet to the given address
- (DSTransaction *_Nullable)transactionFor:(uint64_t)amount to:(NSString *)address withFee:(BOOL)fee;

// returns an unsigned transaction that sends the specified amount from the wallet to the given address intended for conversion to L2 credits
- (DSCreditFundingTransaction *_Nullable)creditFundingTransactionFor:(uint64_t)amount to:(NSString *)address withFee:(BOOL)fee;

// returns an unsigned transaction that sends the specified amounts from the wallet to the specified output scripts
- (DSTransaction *_Nullable)transactionForAmounts:(NSArray *)amounts
                                  toOutputScripts:(NSArray *)scripts
                                          withFee:(BOOL)fee;

- (DSTransaction *)transactionForAmounts:(NSArray *)amounts toOutputScripts:(NSArray *)scripts withFee:(BOOL)fee coinControl:(DSCoinControl *)coinControl;

// returns an unsigned transaction that sends the specified amounts from the wallet to the specified output scripts
- (DSTransaction *_Nullable)transactionForAmounts:(NSArray *)amounts toOutputScripts:(NSArray *)scripts withFee:(BOOL)fee toShapeshiftAddress:(NSString *_Nullable)shapeshiftAddress;

- (DSTransaction *)updateTransaction:(DSTransaction *)transaction forAmounts:(NSArray *)amounts toOutputScripts:(NSArray *)scripts withFee:(BOOL)fee;


- (DSTransaction *)updateTransaction:(DSTransaction *)transaction forAmounts:(NSArray *)amounts toOutputScripts:(NSArray *)scripts withFee:(BOOL)fee sortType:(DSTransactionSortType)sortType;

/// Sign any inputs in the given transaction that can be signed using private keys from the wallet
///
/// - Parameters:
///   - transaction: Instance of `DSTransaction` you want to sign
///
/// - Returns: boolean value indicating if the transaction was signed
///
/// - Note: Using this method to sign a tx doesn't present pin controller, use this method carefully from UI
///
- (BOOL)signTransaction:(DSTransaction *)transaction;

/// Sign any inputs in the given transaction that can be signed using private keys from the wallet
///
/// - Parameters:
///   - transaction: Instance of `DSTransaction` you want to sign
///   - anyoneCanPay: apply SIGHASH_ANYONECANPAY signature type
///
/// - Returns: boolean value indicating if the transaction was signed
///
/// - Note: Using this method to sign a tx doesn't present pin controller, use this method carefully from UI
///
- (BOOL)signTransaction:(DSTransaction *)transaction anyoneCanPay:(BOOL)anyoneCanPay;

/// Sign any inputs in the given transaction that can be signed using private keys from the wallet
///
/// - Parameters:
///   - transaction: Instance of `DSTransaction` you want to sign
///   - completion: Completion block that has type `TransactionValidityCompletionBlock`
///
/// - Note: Using this method to sign a tx presents pin controller for auth purpose
///
- (void)signTransaction:(DSTransaction *)transaction withPrompt:(NSString *_Nullable)authprompt completion:(_Nonnull TransactionValidityCompletionBlock)completion;

// true if the given transaction is associated with the account (even if it hasn't been registered), false otherwise
- (BOOL)canContainTransaction:(DSTransaction *)transaction;

// adds a transaction to the account, or returns false if it isn't associated with the account
- (BOOL)registerTransaction:(DSTransaction *)transaction saveImmediately:(BOOL)saveImmediately;

// this is used to save transactions atomically with the block, needs to be called before switching threads to save the block
- (void)prepareForIncomingTransactionPersistenceForBlockSaveWithNumber:(uint32_t)blockNumber;

// this is used to save transactions atomically with the block
- (void)persistIncomingTransactionsAttributesForBlockSaveWithNumber:(uint32_t)blockNumber inContext:(NSManagedObjectContext *)context;

// removes a transaction from the account along with any transactions that depend on its outputs, returns TRUE if a transaction was removed
- (BOOL)removeTransaction:(DSTransaction *)transaction saveImmediately:(BOOL)saveImmediately;

// removes a transaction by hash from the account along with any transactions that depend on its outputs, returns TRUE if a transaction was removed
- (BOOL)removeTransactionWithHash:(UInt256)txHash saveImmediately:(BOOL)saveImmediately;

// returns the transaction with the given hash if it's been registered in the account (might also return non-registered)
- (DSTransaction *_Nullable)transactionForHash:(UInt256)txHash;

// true if no previous account transaction spends any of the given transaction's inputs, and no inputs are invalid
- (BOOL)transactionIsValid:(DSTransaction *)transaction;

- (BOOL)isSpent:(NSValue *)output;

// returns input value if no previous account transaction spends this input, and the input is valid, -1 otherwise.
- (int64_t)inputValue:(UInt256)txHash inputIndex:(uint32_t)index;

// received, sent or moved inside an account
- (DSTransactionDirection)directionOfTransaction:(DSTransaction *)transaction;

// true if transaction cannot be immediately spent because of a time lock (i.e. if it or an input tx can be replaced-by-fee, via BIP125)
- (BOOL)transactionIsPending:(DSTransaction *)transaction;

// true if transaction cannot be immediately spent
- (BOOL)transactionOutputsAreLocked:(DSTransaction *)transaction;

// block height at which transaction oututs can be spent
- (uint32_t)transactionOutputsAreLockedTill:(DSTransaction *)transaction;

// true if tx is considered 0-conf safe (valid and not pending, timestamp is greater than 0, and no unverified inputs)
- (BOOL)transactionIsVerified:(DSTransaction *)transaction;

// returns the amount received by the account from the transaction (total outputs to change and/or receive addresses)
- (uint64_t)amountReceivedFromTransaction:(DSTransaction *)transaction;

// returns the amount received by the account from the transaction (total outputs to receive addresses)
- (uint64_t)amountReceivedFromTransactionOnExternalAddresses:(DSTransaction *)transaction;

// returns the amount received by the account from the transaction (total outputs to change addresses)
- (uint64_t)amountReceivedFromTransactionOnInternalAddresses:(DSTransaction *)transaction;

// retuns the amount sent from the account by the trasaction (total account outputs consumed, change and fee included)
- (uint64_t)amountSentByTransaction:(DSTransaction *)transaction;

// Returns the amounts sent by the transaction
- (NSArray *)amountsSentByTransaction:(DSTransaction *)transaction;

// returns the external (receive) addresses of a transaction
- (NSArray<NSString *> *)externalAddressesOfTransaction:(DSTransaction *)transaction;

// returns the fee for the given transaction if all its inputs are from wallet transactions, UINT64_MAX otherwise
- (uint64_t)feeForTransaction:(DSTransaction *)transaction;

// historical wallet balance after the given transaction, or current balance if transaction is not registered in wallet
- (uint64_t)balanceAfterTransaction:(DSTransaction *)transaction;

- (void)chainUpdatedBlockHeight:(int32_t)height;

- (NSArray *)setBlockHeight:(int32_t)height andTimestamp:(NSTimeInterval)timestamp forTransactionHashes:(NSArray *)txHashes;

// This loads the derivation paths addresses once the account is set to a wallet
- (void)loadDerivationPaths;

// This loads transactions once the account is set to a wallet
- (void)loadTransactions;

//This removes all transactions from the account
- (void)wipeBlockchainInfo;

//This creates a proposal transaction
- (DSTransaction *)proposalCollateralTransactionWithData:(NSData *)data;

// given a private key, queries api.dashwallet.com for unspent outputs and calls the completion block with a signed
// transaction that will sweep the balance into wallet (doesn't publish the tx)
- (void)sweepPrivateKey:(NSString *)privKey withFee:(BOOL)fee
             completion:(void (^_Nonnull)(DSTransaction *_Nonnull tx, uint64_t fee, NSError *_Null_unspecified error))completion;

@end

NS_ASSUME_NONNULL_END
