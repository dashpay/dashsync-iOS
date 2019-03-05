//
//  DSWallet.h
//  DashSync
//
//  Created by Sam Westrich on 5/20/18.
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
#import "DSBlockchainUser.h"
#import "DSBIP39Mnemonic.h"
#import "BigIntTypes.h"

typedef void (^SeedCompletionBlock)(NSData * _Nullable seed, BOOL cancelled);
typedef void (^SeedRequestBlock)(NSString * _Nullable authprompt, uint64_t amount, _Nullable SeedCompletionBlock seedCompletion);

FOUNDATION_EXPORT NSString* _Nonnull const DSWalletBalanceDidChangeNotification;

#define DUFFS           100000000LL
#define MAX_MONEY          (21000000LL*DUFFS)

@class DSChain,DSAccount,DSTransaction,DSDerivationPath,DSLocalMasternode,DSKey,DSSpecialTransactionsWalletHolder;

@interface DSWallet : NSObject

@property (nonatomic, readonly) NSArray * accounts;

@property (nonatomic, readonly) DSSpecialTransactionsWalletHolder * specialTransactionsHolder;

@property (nonatomic, readonly) NSArray * blockchainUsers;

@property (nonatomic, readonly) NSArray * blockchainUserAddresses;

//This is unique among all wallets and all chains
@property (nonatomic, readonly) NSString * uniqueID;

@property (nonatomic, readonly) NSString * mnemonicUniqueID;

@property (nonatomic, readonly) NSString * creationTimeUniqueID;

@property (nonatomic, readonly) NSTimeInterval walletCreationTime;

// set to true if this wallet is not stored on disk
@property (nonatomic, readonly,getter=isTransient) BOOL transient;

// chain for the wallet
@property (nonatomic, readonly) DSChain * chain;

// current wallet balance excluding transactions known to be invalid
@property (nonatomic, readonly) uint64_t balance;

// all previously generated external addresses
@property (nonatomic, readonly) NSSet * _Nonnull allReceiveAddresses;

// all previously generated internal addresses
@property (nonatomic, readonly) NSSet * _Nonnull allChangeAddresses;

// NSValue objects containing UTXO structs
@property (nonatomic, readonly) NSArray * _Nonnull unspentOutputs;

// latest 100 transactions sorted by date, most recent first
@property (nonatomic, readonly) NSArray * _Nonnull recentTransactions;

// all wallet transactions sorted by date, most recent first
@property (nonatomic, readonly) NSArray * _Nonnull allTransactions;

// the total amount spent from the wallet (excluding change)
@property (nonatomic, readonly) uint64_t totalSent;

// the total amount received by the wallet (excluding change)
@property (nonatomic, readonly) uint64_t totalReceived;

// the first unused index for blockchain users
@property (nonatomic, readonly) uint32_t unusedBlockchainUserIndex;

@property (nonatomic, readonly) SeedRequestBlock seedRequestBlock;

-(void)authPrivateKey:(void (^ _Nullable)(NSString * _Nullable authKey))completion;

+ (DSWallet* _Nullable)standardWalletWithSeedPhrase:(NSString* _Nonnull)seedPhrase setCreationDate:(NSTimeInterval)creationDate forChain:(DSChain* _Nonnull)chain storeSeedPhrase:(BOOL)storeSeedPhrase isTransient:(BOOL)isTransient;
+ (DSWallet* _Nullable)standardWalletWithRandomSeedPhraseForChain:(DSChain* _Nonnull)chain storeSeedPhrase:(BOOL)store isTransient:(BOOL)isTransient;
+ (DSWallet* _Nullable)standardWalletWithRandomSeedPhraseInLanguage:(DSBIP39Language)language forChain:(DSChain* _Nonnull)chain storeSeedPhrase:(BOOL)store isTransient:(BOOL)isTransient;

-(instancetype)initWithUniqueID:(NSString*)uniqueID forChain:(DSChain*)chain;

// true if the address is controlled by the wallet
- (BOOL)containsAddress:(NSString * _Nonnull)address;

- (DSAccount* _Nullable)accountForAddress:(NSString *)address;

// true if the address was previously used as an input or output in any wallet transaction
- (BOOL)addressIsUsed:(NSString * _Nonnull)address;

// sets the block heights and timestamps for the given transactions, and returns an array of hashes of the updated tx
// use a height of TX_UNCONFIRMED and timestamp of 0 to indicate a transaction and it's dependents should remain marked
// as unverified (not 0-conf safe)
- (NSArray * _Nonnull)setBlockHeight:(int32_t)height andTimestamp:(NSTimeInterval)timestamp
                         forTxHashes:(NSArray * _Nonnull)txHashes;

//add an account to the wallet
- (void)addAccount:(DSAccount*)account;

// returns an account where all derivation paths have the following account number
- (DSAccount* _Nullable)accountWithNumber:(NSUInteger)accountNumber;

// returns an account to which the given transaction is associated with (even if it hasn't been registered), no account if the transaction is not associated with the wallet
- (DSAccount* _Nullable)accountContainingTransaction:(DSTransaction * _Nonnull)transaction;

// returns an account to which the given transaction hash is associated with, no account if the transaction hash is not associated with the wallet
- (DSAccount * _Nullable)accountForTransactionHash:(UInt256)txHash transaction:(DSTransaction **)transaction;

// returns the transaction with the given hash if it's been registered in the wallet (might also return non-registered)
- (DSTransaction * _Nullable)transactionForHash:(UInt256)txHash;

- (NSArray *)registerAddressesWithGapLimit:(NSUInteger)gapLimit internal:(BOOL)internal;

// returns the amount received by the wallet from the transaction (total outputs to change and/or receive addresses)
- (uint64_t)amountReceivedFromTransaction:(DSTransaction * _Nonnull)transaction;

// retuns the amount sent from the wallet by the trasaction (total wallet outputs consumed, change and fee included)
- (uint64_t)amountSentByTransaction:(DSTransaction * _Nonnull)transaction;

// true if no previous wallet transaction spends any of the given transaction's inputs, and no inputs are invalid
- (BOOL)transactionIsValid:(DSTransaction * _Nonnull)transaction;

//returns the seed phrase after authenticating
-(void)seedPhraseAfterAuthentication:(void (^ _Nullable)(NSString * _Nullable seedPhrase))completion;
- (void)seedPhraseAfterAuthenticationWithPrompt:(NSString *)authprompt completion:(void (^ _Nullable)(NSString * _Nullable seedPhrase))completion;

-(NSString* _Nullable)seedPhraseIfAuthenticated;

//this is used from the account to help determine best start sync position for future resync
-(void)setGuessedWalletCreationTime:(NSTimeInterval)guessedWalletCreationTime;

-(DSKey*)privateKeyForAddress:(NSString*)address fromSeed:(NSData*)seed;

//generate a random Mnemonic seed
+ (NSString *)generateRandomSeed;

//generate a random Mnemonic seed in a specified language
+ (NSString *)generateRandomSeedForLanguage:(DSBIP39Language)language;

//get the MNEMONIC KEY prefixed unique ID
+ (NSString*)mnemonicUniqueIDForUniqueID:(NSString*)uniqueID;

//get the CREATION TIME KEY prefixed unique ID
+ (NSString*)creationTimeUniqueIDForUniqueID:(NSString*)uniqueID;

//This removes all blockchain information from the wallet, used for resync
- (void)wipeBlockchainInfo;

//This removes all wallet based information from the wallet, used when deletion of wallet is wanted
- (void)wipeWalletInfo;

-(void)unregisterBlockchainUser:(DSBlockchainUser* _Nonnull)blockchainUser;
-(void)addBlockchainUser:(DSBlockchainUser* _Nonnull)blockchainUser;
-(void)registerBlockchainUser:(DSBlockchainUser* _Nonnull)blockchainUser;
-(DSBlockchainUser* _Nonnull)createBlockchainUserForUsername:(NSString* _Nonnull)username;

- (void)seedWithPrompt:(NSString * _Nonnull)authprompt forAmount:(uint64_t)amount completion:(_Nullable SeedCompletionBlock)completion;

-(void)copyForChain:(DSChain* _Nonnull)chain completion:(void (^ _Nonnull)(DSWallet * _Nullable copiedWallet))completion;

- (void)registerMasternodeOperator:(DSLocalMasternode * _Nonnull)masternode;

- (void)registerMasternodeOwner:(DSLocalMasternode * _Nonnull)masternode;

- (void)registerMasternodeVoter:(DSLocalMasternode * _Nonnull)masternode;
- (BOOL)containsProviderVotingAuthenticationHash:(UInt160)votingAuthenticationHash;
- (BOOL)containsProviderOwningAuthenticationHash:(UInt160)owningAuthenticationHash;
- (BOOL)containsProviderOperatorAuthenticationKey:(UInt384)providerOperatorAuthenticationKey;
- (BOOL)containsBlockchainUserAuthenticationHash:(UInt160)blockchainUserAuthenticationHash;
- (BOOL)containsHoldingAddress:(NSString*)holdingAddress;

- (NSUInteger)indexOfProviderVotingAuthenticationHash:(UInt160)votingAuthenticationHash;
- (NSUInteger)indexOfProviderOwningAuthenticationHash:(UInt160)owningAuthenticationHash;
- (NSUInteger)indexOfProviderOperatorAuthenticationKey:(UInt384)providerOperatorAuthenticationKey;
- (NSUInteger)indexOfHoldingAddress:(NSString*)holdingAddress;
- (NSUInteger)indexOfBlockchainUserAuthenticationHash:(UInt160)blockchainUserAuthenticationHash;

@end
