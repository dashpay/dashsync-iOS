//
//  DSWallet.h
//  DashSync
//
//  Created by Aaron Voisine on 5/12/13.
//  Copyright (c) 2013 Aaron Voisine <voisine@gmail.com>
//  Updated by Quantum Explorer on 05/11/18.
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
#import "DSKeySequence.h"
#import "NSData+Bitcoin.h"
#import "DSDerivationPath.h"

typedef void (^TransactionValidityCompletionBlock)(BOOL signedTransaction);
typedef void (^SeedCompletionBlock)(NSData * _Nullable seed);
typedef void (^SeedRequestBlock)(NSString * _Nullable authprompt, uint64_t amount, _Nullable SeedCompletionBlock seedCompletion);

typedef struct _DSUTXO {
    UInt256 hash;
    unsigned long n; // use unsigned long instead of uint32_t to avoid trailing struct padding (for NSValue comparisons)
} DSUTXO;

#define brutxo_obj(o) [NSValue value:&(o) withObjCType:@encode(DSUTXO)]
#define brutxo_data(o) [NSData dataWithBytes:&((struct { uint32_t u[256/32 + 1]; }) {\
    o.hash.u32[0], o.hash.u32[1], o.hash.u32[2], o.hash.u32[3],\
    o.hash.u32[4], o.hash.u32[5], o.hash.u32[6], o.hash.u32[7],\
    CFSwapInt32HostToLittle((uint32_t)o.n) }) length:sizeof(UInt256) + sizeof(uint32_t)]

@class DSTransaction;
@class DSChain;
@class DSWallet;
@class DSDerivationPath;

@protocol DSKeySequence;

@interface DSAccount : NSObject

// master public key
@property (nonatomic, readonly) NSData * extendedPublicKey;//master public key used to generate wallet addresses

// wallet for the account
@property (nonatomic, readonly) DSWallet * wallet;

// BIP 43 derivation path
@property (nonatomic, readonly) DSDerivationPath * derivationPath;

// chain for the wallet
@property (nonatomic, readonly) DSChain * chain;

// current wallet balance excluding transactions known to be invalid
@property (nonatomic, readonly) uint64_t balance;

// returns the first unused external address
@property (nonatomic, readonly) NSString * _Nullable receiveAddress;

// returns the first unused internal address
@property (nonatomic, readonly) NSString * _Nullable changeAddress;

// all previously generated external addresses
@property (nonatomic, readonly) NSSet * _Nonnull allReceiveAddresses;

// all previously generated internal addresses
@property (nonatomic, readonly) NSSet * _Nonnull allChangeAddresses;

// NSValue objects containing UTXO structs
@property (nonatomic, readonly) NSArray * _Nonnull unspentOutputs;

// the total amount spent from the account (excluding change)
@property (nonatomic, readonly) uint64_t totalSent;

// the total amount received to the wallet (excluding change)
@property (nonatomic, readonly) uint64_t totalReceived;

// fee per kb of transaction size to use when including tx fee
@property (nonatomic, assign) uint64_t feePerKb;

// outputs below this amount are uneconomical due to fees
@property (nonatomic, readonly) uint64_t minOutputAmount;

// largest amount that can be sent from the wallet after fees
- (uint64_t)maxOutputAmountUsingInstantSend:(BOOL)instantSend;

- (uint64_t)maxOutputAmountWithConfirmationCount:(uint64_t)confirmationCount usingInstantSend:(BOOL)instantSend;

- (instancetype _Nullable)initWithContext:(NSManagedObjectContext * _Nullable)context
                                 sequence:(id<DSKeySequence> _Nonnull)sequence
                                  onChain:(DSChain*)chain
                          masterPublicKey:(NSData * _Nonnull)masterPublicKey
                            requestSeedBlock:(_Nullable SeedRequestBlock)seed;

// true if the address is controlled by the wallet
- (BOOL)containsAddress:(NSString * _Nonnull)address;

// true if the address was previously used as an input or output in any wallet transaction
- (BOOL)addressIsUsed:(NSString * _Nonnull)address;

// Wallets are composed of chains of addresses. Each chain is traversed until a gap of a certain number of addresses is
// found that haven't been used in any transactions. This method returns an array of <gapLimit> unused addresses
// following the last used address in the chain. The internal chain is used for change addresses and the external chain
// for receive addresses.  These have a hardened purpose scheme of 44 as compliant with BIP 43 and 44
- (NSArray * _Nullable)addressesWithGapLimit:(NSUInteger)gapLimit internal:(BOOL)internal;

// returns an unsigned transaction that sends the specified amount from the wallet to the given address
- (DSTransaction * _Nullable)transactionFor:(uint64_t)amount to:(NSString * _Nonnull)address withFee:(BOOL)fee;

// returns an unsigned transaction that sends the specified amounts from the wallet to the specified output scripts
- (DSTransaction * _Nullable)transactionForAmounts:(NSArray * _Nonnull)amounts
                                   toOutputScripts:(NSArray * _Nonnull)scripts withFee:(BOOL)fee;

// returns an unsigned transaction that sends the specified amounts from the wallet to the specified output scripts
- (DSTransaction * _Nullable)transactionForAmounts:(NSArray * _Nonnull)amounts toOutputScripts:(NSArray * _Nonnull)scripts withFee:(BOOL)fee  isInstant:(BOOL)isInstant;

// returns an unsigned transaction that sends the specified amounts from the wallet to the specified output scripts
- (DSTransaction * _Nullable)transactionForAmounts:(NSArray * _Nonnull)amounts toOutputScripts:(NSArray * _Nonnull)scripts withFee:(BOOL)fee isInstant:(BOOL)isInstant toShapeshiftAddress:(NSString* _Nullable)shapeshiftAddress;

// sign any inputs in the given transaction that can be signed using private keys from the wallet
- (void)signTransaction:(DSTransaction * _Nonnull)transaction withPrompt:(NSString * _Nonnull)authprompt completion:(_Nonnull TransactionValidityCompletionBlock)completion;

// true if the given transaction is associated with the wallet (even if it hasn't been registered), false otherwise
- (BOOL)containsTransaction:(DSTransaction * _Nonnull)transaction;

// adds a transaction to the wallet, or returns false if it isn't associated with the wallet
- (BOOL)registerTransaction:(DSTransaction * _Nonnull)transaction;

// removes a transaction from the wallet along with any transactions that depend on its outputs
- (void)removeTransaction:(UInt256)txHash;

// returns the transaction with the given hash if it's been registered in the wallet (might also return non-registered)
- (DSTransaction * _Nullable)transactionForHash:(UInt256)txHash;

// true if no previous wallet transaction spends any of the given transaction's inputs, and no inputs are invalid
- (BOOL)transactionIsValid:(DSTransaction * _Nonnull)transaction;

// true if transaction cannot be immediately spent (i.e. if it or an input tx can be replaced-by-fee, via BIP125)
- (BOOL)transactionIsPending:(DSTransaction * _Nonnull)transaction;

// true if tx is considered 0-conf safe (valid and not pending, timestamp is greater than 0, and no unverified inputs)
- (BOOL)transactionIsVerified:(DSTransaction * _Nonnull)transaction;

// returns the amount received by the wallet from the transaction (total outputs to change and/or receive addresses)
- (uint64_t)amountReceivedFromTransaction:(DSTransaction * _Nonnull)transaction;

// retuns the amount sent from the wallet by the trasaction (total wallet outputs consumed, change and fee included)
- (uint64_t)amountSentByTransaction:(DSTransaction * _Nonnull)transaction;

// returns the fee for the given transaction if all its inputs are from wallet transactions, UINT64_MAX otherwise
- (uint64_t)feeForTransaction:(DSTransaction * _Nonnull)transaction;

// historical wallet balance after the given transaction, or current balance if transaction is not registered in wallet
- (uint64_t)balanceAfterTransaction:(DSTransaction * _Nonnull)transaction;

// returns the block height after which the transaction is likely to be processed without including a fee
- (uint32_t)blockHeightUntilFree:(DSTransaction * _Nonnull)transaction;

// fee that will be added for a transaction of the given size in bytes
- (uint64_t)feeForTxSize:(NSUInteger)size isInstant:(BOOL)isInstant inputCount:(NSInteger)inputCount;

@end
