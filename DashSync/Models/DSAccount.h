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

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "DSTransaction.h"
#import "NSData+Bitcoin.h"
#import "DSFundsDerivationPath.h"

NS_ASSUME_NONNULL_BEGIN

@class DSFundsDerivationPath,DSWallet,DSBlockchainUserRegistrationTransaction,DSBlockchainUserResetTransaction,DSPotentialContact;

@interface DSAccount : NSObject

// BIP 43 derivation paths
@property (nullable, nonatomic, readonly) NSArray<DSFundsDerivationPath *> * fundDerivationPaths;

@property (nullable, nonatomic, strong) DSFundsDerivationPath * defaultDerivationPath;

@property (nullable, nonatomic, readonly) DSFundsDerivationPath * bip44DerivationPath;

@property (nullable, nonatomic, readonly) DSFundsDerivationPath * bip32DerivationPath;

@property (nullable, nonatomic, readonly) DSDerivationPath * masterContactsDerivationPath;

@property (nullable, nonatomic, weak) DSWallet * wallet;

@property (nonatomic, readonly) NSString * uniqueID;

@property (nonatomic, readonly) uint32_t accountNumber;

// current wallet balance excluding transactions known to be invalid
@property (nonatomic, readonly) uint64_t balance;

// NSValue objects containing UTXO structs
@property (nonatomic, readonly) NSArray * unspentOutputs;

// latest 100 transactions sorted by date, most recent first
@property (nonatomic, readonly) NSArray * recentTransactions;

// latest 100 transactions sorted by date, most recent first
@property (nonatomic, readonly) NSArray * recentTransactionsWithInternalOutput;

// all wallet transactions sorted by date, most recent first
@property (nonatomic, readonly) NSArray * allTransactions;

// returns the first unused external address
@property (nullable, nonatomic, readonly) NSString * receiveAddress;

// returns the first unused internal address
@property (nullable, nonatomic, readonly) NSString * changeAddress;

// all previously generated external addresses
@property (nonatomic, readonly) NSArray * externalAddresses;

// all previously generated internal addresses
@property (nonatomic, readonly) NSArray * internalAddresses;

// all the contacts for an account
@property (nonatomic, readonly) NSArray <DSPotentialContact*> * _Nonnull contacts;

-(NSArray * _Nullable)registerAddressesWithGapLimit:(NSUInteger)gapLimit internal:(BOOL)internal;

+(DSAccount*)accountWithDerivationPaths:(NSArray<DSDerivationPath *> *)derivationPaths inContext:(NSManagedObjectContext* _Nullable)context;

-(instancetype)initWithDerivationPaths:(NSArray<DSDerivationPath *> *)derivationPaths inContext:(NSManagedObjectContext* _Nullable)context ;

-(instancetype)initAsViewOnlyWithDerivationPaths:(NSArray<DSDerivationPath *> *)derivationPaths inContext:(NSManagedObjectContext* _Nullable)context ;

-(void)removeDerivationPath:(DSDerivationPath*)derivationPath;

-(void)addDerivationPath:(DSDerivationPath*)derivationPath;

-(void)addDerivationPathsFromArray:(NSArray<DSDerivationPath *> *)derivationPaths;

// largest amount that can be sent from the account after fees
- (uint64_t)maxOutputAmountUsingInstantSend:(BOOL)instantSend;

- (uint64_t)maxOutputAmountWithConfirmationCount:(uint64_t)confirmationCount usingInstantSend:(BOOL)instantSend returnInputCount:(uint32_t* _Nullable)rInputCount;

// true if AutoLocks enabled and can be used with provided amount
- (BOOL)canUseAutoLocksForAmount:(uint64_t)requiredAmount;

// true if the address is controlled by the wallet
- (BOOL)containsAddress:(NSString *)address;

// the high level (hardened) derivation path containing the address
-(DSFundsDerivationPath*)derivationPathContainingAddress:(NSString *)address;

- (BOOL)transactionAddressAlreadySeenInOutputs:(NSString *)address;

// true if the address was previously used as an input or output in any wallet transaction (from this wallet only)
- (BOOL)addressIsUsed:(NSString *)address;

// returns an unsigned transaction that sends the specified amount from the wallet to the given address
- (DSTransaction * _Nullable)transactionFor:(uint64_t)amount to:(NSString *)address withFee:(BOOL)fee;

// returns an unsigned transaction that sends the specified amounts from the wallet to the specified output scripts
- (DSTransaction * _Nullable)transactionForAmounts:(NSArray *)amounts
                                   toOutputScripts:(NSArray *)scripts withFee:(BOOL)fee;

// returns an unsigned transaction that sends the specified amounts from the wallet to the specified output scripts
- (DSTransaction * _Nullable)transactionForAmounts:(NSArray *)amounts toOutputScripts:(NSArray *)scripts withFee:(BOOL)fee isInstant:(BOOL)isInstant;

// returns an unsigned transaction that sends the specified amounts from the wallet to the specified output scripts
- (DSTransaction * _Nullable)transactionForAmounts:(NSArray *)amounts toOutputScripts:(NSArray *)scripts withFee:(BOOL)fee isInstant:(BOOL)isInstant toShapeshiftAddress:(NSString* _Nullable)shapeshiftAddress;

- (DSTransaction *)updateTransaction:(DSTransaction *)transaction forAmounts:(NSArray *)amounts toOutputScripts:(NSArray *)scripts withFee:(BOOL)fee isInstant:(BOOL)isInstant;

// sign any inputs in the given transaction that can be signed using private keys from the wallet
- (void)signTransaction:(DSTransaction *)transaction withPrompt:(NSString * _Nullable)authprompt completion:(_Nonnull TransactionValidityCompletionBlock)completion;

// true if the given transaction is associated with the account (even if it hasn't been registered), false otherwise
- (BOOL)canContainTransaction:(DSTransaction *)transaction;

// adds a transaction to the account, or returns false if it isn't associated with the account
- (BOOL)registerTransaction:(DSTransaction *)transaction;

// removes a transaction from the account along with any transactions that depend on its outputs, returns TRUE if a transaction was removed
- (BOOL)removeTransaction:(DSTransaction *)transaction;

// removes a transaction by hash from the account along with any transactions that depend on its outputs, returns TRUE if a transaction was removed
- (BOOL)removeTransactionWithHash:(UInt256)txHash;

// returns the transaction with the given hash if it's been registered in the account (might also return non-registered)
- (DSTransaction * _Nullable)transactionForHash:(UInt256)txHash;

// true if no previous account transaction spends any of the given transaction's inputs, and no inputs are invalid
- (BOOL)transactionIsValid:(DSTransaction *)transaction;

// true if transaction cannot be immediately spent because of a time lock (i.e. if it or an input tx can be replaced-by-fee, via BIP125)
- (BOOL)transactionIsPending:(DSTransaction *)transaction;

// true if transaction cannot be immediately spent
- (BOOL)transactionOutputsAreLocked:(DSTransaction *)transaction;

// true if tx is considered 0-conf safe (valid and not pending, timestamp is greater than 0, and no unverified inputs)
- (BOOL)transactionIsVerified:(DSTransaction *)transaction;

// returns the amount received by the account from the transaction (total outputs to change and/or receive addresses)
- (uint64_t)amountReceivedFromTransaction:(DSTransaction *)transaction;

// retuns the amount sent from the account by the trasaction (total account outputs consumed, change and fee included)
- (uint64_t)amountSentByTransaction:(DSTransaction *)transaction;

// returns the fee for the given transaction if all its inputs are from wallet transactions, UINT64_MAX otherwise
- (uint64_t)feeForTransaction:(DSTransaction *)transaction;

// historical wallet balance after the given transaction, or current balance if transaction is not registered in wallet
- (uint64_t)balanceAfterTransaction:(DSTransaction *)transaction;

- (void)chainUpdatedBlockHeight:(int32_t)height;

- (NSArray *)setBlockHeight:(int32_t)height andTimestamp:(NSTimeInterval)timestamp forTxHashes:(NSArray *)txHashes;

// This loads the derivation paths addresses once the account is set to a wallet
- (void)loadDerivationPaths;

// This loads transactions once the account is set to a wallet
- (void)loadTransactions;

//This removes all transactions from the account
- (void)wipeBlockchainInfo;

//This creates a proposal transaction
- (DSTransaction *)proposalCollateralTransactionWithData:(NSData*)data;

// given a private key, queries api.dashwallet.com for unspent outputs and calls the completion block with a signed
// transaction that will sweep the balance into wallet (doesn't publish the tx)
- (void)sweepPrivateKey:(NSString *)privKey withFee:(BOOL)fee
             completion:(void (^ _Nonnull)(DSTransaction * _Nonnull tx, uint64_t fee, NSError * _Null_unspecified error))completion;

-(void)contactForBlockchainUser:(DSBlockchainUser*)blockchainUser;

@end

NS_ASSUME_NONNULL_END
