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

#import "BigIntTypes.h"
#import "DSBIP39Mnemonic.h"
#import "DSBlockchainIdentity.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^SeedCompletionBlock)(NSData *_Nullable seed, BOOL cancelled);
typedef void (^SeedRequestBlock)(_Nullable SeedCompletionBlock seedCompletion);
typedef void (^SecureSeedRequestBlock)(NSString *_Nullable authprompt, uint64_t amount, _Nullable SeedCompletionBlock seedCompletion);

FOUNDATION_EXPORT NSString *_Nonnull const DSWalletBalanceDidChangeNotification;

#define DUFFS 100000000LL
#define MAX_MONEY (21000000LL * DUFFS)

@class DSChain, DSAccount, DSTransaction, DSDerivationPath, DSLocalMasternode, DSSpecialTransactionsWalletHolder, DSBlockchainInvitation;

@interface DSWallet : NSObject

@property (nonatomic, readonly) NSDictionary<NSNumber *, DSAccount *> *orderedAccounts;

@property (nonatomic, readonly) uint32_t lastAccountNumber;

@property (nonatomic, readonly) NSArray<DSAccount *> *accounts;

@property (nonatomic, readonly) DSSpecialTransactionsWalletHolder *specialTransactionsHolder;

@property (nonatomic, readonly) NSDictionary<NSData *, DSBlockchainIdentity *> *blockchainIdentities;

@property (nonatomic, readonly) NSDictionary<NSData *, DSBlockchainInvitation *> *blockchainInvitations;

@property (nonatomic, readonly, nullable) DSBlockchainIdentity *defaultBlockchainIdentity;

- (void)setDefaultBlockchainIdentity:(DSBlockchainIdentity *)defaultBlockchainIdentity;

@property (nonatomic, readonly) NSArray<NSString *> *blockchainIdentityAddresses;

@property (nonatomic, readonly) NSArray<NSString *> *providerOwnerAddresses;

@property (nonatomic, readonly) NSArray<NSString *> *providerVotingAddresses;

@property (nonatomic, readonly) NSArray<NSString *> *providerOperatorAddresses;

@property (nonatomic, readonly) NSArray<NSString *> *platformNodeAddresses;

//This is unique among all wallets and all chains
@property (nonatomic, readonly) NSString *uniqueIDString;

@property (nonatomic, readonly) NSTimeInterval walletCreationTime;

// set to true if this wallet is not stored on disk
@property (nonatomic, readonly, getter=isTransient) BOOL transient;

// chain for the wallet
@property (nonatomic, readonly) DSChain *chain;

// current wallet balance excluding transactions known to be invalid
@property (nonatomic, readonly) uint64_t balance;

// all previously generated external addresses
@property (nonatomic, readonly) NSSet<NSString *> *allReceiveAddresses;

// all previously generated internal addresses
@property (nonatomic, readonly) NSSet<NSString *> *allChangeAddresses;

// NSValue objects containing UTXO structs
@property (nonatomic, readonly) NSArray *unspentOutputs;

// latest 100 transactions sorted by date, most recent first
@property (nonatomic, readonly) NSArray<DSTransaction *> *recentTransactions;

// all wallet transactions sorted by date, most recent first
@property (nonatomic, readonly) NSArray<DSTransaction *> *allTransactions;

// the total amount spent from the wallet (excluding change)
@property (nonatomic, readonly) uint64_t totalSent;

// the total amount received by the wallet (excluding change)
@property (nonatomic, readonly) uint64_t totalReceived;

// the first unused index for blockchain identity registration funding
@property (nonatomic, readonly) uint32_t unusedBlockchainIdentityIndex;

// the first unused index for invitations
@property (nonatomic, readonly) uint32_t unusedBlockchainInvitationIndex;

// the amount of known blockchain identities
@property (nonatomic, readonly) uint32_t blockchainIdentitiesCount;

// the amount of known blockchain invitations
@property (nonatomic, readonly) uint32_t blockchainInvitationsCount;

// The fingerprint for currentTransactions
@property (nonatomic, readonly) NSData *chainSynchronizationFingerprint;

- (void)authPrivateKey:(void (^_Nullable)(NSString *_Nullable authKey))completion;

+ (DSWallet *_Nullable)standardWalletWithSeedPhrase:(NSString *)seedPhrase setCreationDate:(NSTimeInterval)creationDate forChain:(DSChain *)chain storeSeedPhrase:(BOOL)storeSeedPhrase isTransient:(BOOL)isTransient;
+ (DSWallet *_Nullable)standardWalletWithRandomSeedPhraseForChain:(DSChain *)chain storeSeedPhrase:(BOOL)store isTransient:(BOOL)isTransient;
+ (DSWallet *_Nullable)standardWalletWithRandomSeedPhraseInLanguage:(DSBIP39Language)language forChain:(DSChain *)chain storeSeedPhrase:(BOOL)store isTransient:(BOOL)isTransient;
+ (DSWallet *_Nullable)transientWalletWithDerivedKeyData:(NSData *)derivedData forChain:(DSChain *)chain;

- (instancetype)initWithUniqueID:(NSString *_Nonnull)uniqueID forChain:(DSChain *_Nonnull)chain;

// true if the address is controlled by the wallet
- (BOOL)containsAddress:(NSString *)address;

// true if the address is controlled by the wallet except for evolution addresses
- (BOOL)accountsBaseDerivationPathsContainAddress:(NSString *)address;

- (DSAccount *_Nullable)accountForAddress:(NSString *)address;

- (DSAccount *_Nullable)accountForDashpayExternalDerivationPathAddress:(NSString *)address;

// true if the address was previously used as an input or output for this wallet
- (BOOL)addressIsUsed:(NSString *)address;

- (BOOL)transactionAddressAlreadySeenInOutputs:(NSString *)address;

- (void)chainUpdatedBlockHeight:(int32_t)height;

// sets the block heights and timestamps for the given transactions, and returns an array of hashes of the updated tx
// use a height of TX_UNCONFIRMED and timestamp of 0 to indicate a transaction and it's dependents should remain marked
// as unverified (not 0-conf safe)
- (NSArray *)setBlockHeight:(int32_t)height
               andTimestamp:(NSTimeInterval)timestamp
       forTransactionHashes:(NSArray *)txHashes;

//add an account to the wallet
- (void)addAccount:(DSAccount *)account;

//add another account to the wallet if authenticated
- (DSAccount *_Nullable)addAnotherAccountIfAuthenticated;

// returns an account where all derivation paths have the following account number
- (DSAccount *_Nullable)accountWithNumber:(NSUInteger)accountNumber;

// returns the first account with a balance
- (DSAccount *_Nullable)firstAccountWithBalance;

// returns an account to which the given transaction is or can be associated with (even if it hasn't been registered), no account if the transaction is not associated with the wallet
- (DSAccount *_Nullable)firstAccountThatCanContainTransaction:(DSTransaction *)transaction;

// returns all accounts to which the given transaction is or can be associated with (even if it hasn't been registered)
- (NSArray *)accountsThatCanContainTransaction:(DSTransaction *)transaction;

// returns an account to which the given transaction hash is associated with, no account if the transaction hash is not associated with the wallet
- (DSAccount *_Nullable)accountForTransactionHash:(UInt256)txHash transaction:(DSTransaction *_Nullable __autoreleasing *_Nullable)transaction;

// returns the transaction with the given hash if it's been registered in the wallet (might also return non-registered)
- (DSTransaction *_Nullable)transactionForHash:(UInt256)txHash;

- (NSArray *)registerAddressesWithGapLimit:(NSUInteger)gapLimit unusedAccountGapLimit:(NSUInteger)unusedAccountGapLimit dashpayGapLimit:(NSUInteger)dashpayGapLimit coinJoinGapLimit:(NSUInteger)coinJoinGapLimit internal:(BOOL)internal error:(NSError *_Nullable *_Nullable)error;

// returns the amount received by the wallet from the transaction (total outputs to change and/or receive addresses)
- (uint64_t)amountReceivedFromTransaction:(DSTransaction *)transaction;

// retuns the amount sent from the wallet by the trasaction (total wallet outputs consumed, change and fee included)
- (uint64_t)amountSentByTransaction:(DSTransaction *)transaction;

// retuns all account transactions plus special transactions not bound to any account
- (NSArray *)allTransactionsForAccount:(DSAccount *)account;

// true if no previous wallet transaction spends any of the given transaction's inputs, and no inputs are invalid
- (BOOL)transactionIsValid:(DSTransaction *)transaction;

// returns input value if no previous wallet transaction spends this input, and the input is valid, -1 otherwise.
- (int64_t)inputValue:(UInt256)txHash inputIndex:(uint32_t)index;

// this is used to save transactions atomically with the block, needs to be called before switching threads to save the block
- (void)prepareForIncomingTransactionPersistenceForBlockSaveWithNumber:(uint32_t)blockNumber;

// this is used to save transactions atomically with the block
- (void)persistIncomingTransactionsAttributesForBlockSaveWithNumber:(uint32_t)blockNumber inContext:(NSManagedObjectContext *)context;

//returns the seed phrase after authenticating
- (void)seedPhraseAfterAuthentication:(void (^_Nullable)(NSString *_Nullable seedPhrase))completion;
- (void)seedPhraseAfterAuthenticationWithPrompt:(NSString *_Nullable)authprompt completion:(void (^_Nullable)(NSString *_Nullable seedPhrase))completion;

- (NSString *_Nullable)seedPhraseIfAuthenticated;

- (OpaqueKey *_Nullable)privateKeyForAddress:(NSString *_Nonnull)address fromSeed:(NSData *_Nonnull)seed;
- (NSString *_Nullable)privateKeyAddressForAddress:(NSString *)address fromSeed:(NSData *)seed;

//generate a random Mnemonic seed
+ (NSString *_Nullable)generateRandomSeedPhrase;

//generate a random Mnemonic seed in a specified language
+ (NSString *_Nullable)generateRandomSeedPhraseForLanguage:(DSBIP39Language)language;

//This removes all blockchain information from the wallet, used for resync
- (void)wipeBlockchainInfoInContext:(NSManagedObjectContext *)context;

//This removes all extra accounts, past the first (or sometimes second one).
- (void)wipeBlockchainExtraAccountsInContext:(NSManagedObjectContext *)context;

//This removes all wallet based information from the wallet, used when deletion of wallet is wanted
- (void)wipeWalletInfo;

//Recreate derivation paths and addresses
- (void)reloadDerivationPaths;

- (void)unregisterBlockchainIdentity:(DSBlockchainIdentity *)blockchainIdentity;
- (void)addBlockchainIdentities:(NSArray<DSBlockchainIdentity *> *)blockchainIdentities;
- (void)addBlockchainIdentity:(DSBlockchainIdentity *)blockchainIdentity;

//Verify makes sure the keys for the blockchain identity are good
- (BOOL)registerBlockchainIdentities:(NSArray<DSBlockchainIdentity *> *)blockchainIdentities verify:(BOOL)verify;
- (BOOL)registerBlockchainIdentity:(DSBlockchainIdentity *)blockchainIdentity verify:(BOOL)verify;
- (BOOL)registerBlockchainIdentity:(DSBlockchainIdentity *)blockchainIdentity;
- (BOOL)containsBlockchainIdentity:(DSBlockchainIdentity *)blockchainIdentity;

- (void)unregisterBlockchainInvitation:(DSBlockchainInvitation *)blockchainInvitation;
- (void)addBlockchainInvitation:(DSBlockchainInvitation *)blockchainInvitation;
- (void)registerBlockchainInvitation:(DSBlockchainInvitation *)blockchainInvitation;
- (BOOL)containsBlockchainInvitation:(DSBlockchainInvitation *)blockchainInvitation;

- (DSBlockchainIdentity *)createBlockchainIdentity;
- (DSBlockchainIdentity *)createBlockchainIdentityUsingDerivationIndex:(uint32_t)index;
- (DSBlockchainIdentity *)createBlockchainIdentityForUsername:(NSString *_Nullable)username;
- (DSBlockchainIdentity *)createBlockchainIdentityForUsername:(NSString *_Nullable)username usingDerivationIndex:(uint32_t)index;

- (DSBlockchainInvitation *)createBlockchainInvitation;
- (DSBlockchainInvitation *)createBlockchainInvitationUsingDerivationIndex:(uint32_t)index;

- (DSBlockchainIdentity *_Nullable)blockchainIdentityThatCreatedContract:(DPContract *)contract withContractId:(UInt256)contractId;

- (DSBlockchainIdentity *_Nullable)blockchainIdentityForUniqueId:(UInt256)uniqueId;

- (DSBlockchainInvitation *_Nullable)blockchainInvitationForUniqueId:(UInt256)uniqueId;

- (void)seedWithPrompt:(NSString *_Nullable)authprompt forAmount:(uint64_t)amount completion:(_Nullable SeedCompletionBlock)completion;

- (void)copyForChain:(DSChain *)chain completion:(void (^_Nonnull)(DSWallet *_Nullable copiedWallet))completion;

- (void)registerMasternodeOperator:(DSLocalMasternode *)masternode;                                               //will use indexes
- (void)registerMasternodeOperator:(DSLocalMasternode *)masternode withOperatorPublicKey:(OpaqueKey *)operatorKey; //will use defined key

- (void)registerMasternodeOwner:(DSLocalMasternode *)masternode;
- (void)registerMasternodeOwner:(DSLocalMasternode *)masternode withOwnerPrivateKey:(OpaqueKey *)ownerKey; //will use defined key

- (void)registerMasternodeVoter:(DSLocalMasternode *)masternode;
- (void)registerMasternodeVoter:(DSLocalMasternode *)masternode withVotingKey:(OpaqueKey *)votingKey; //will use defined key

- (void)registerPlatformNode:(DSLocalMasternode *)masternode;
- (void)registerPlatformNode:(DSLocalMasternode *)masternode withKey:(OpaqueKey *)key; //will use defined key

- (BOOL)containsProviderVotingAuthenticationHash:(UInt160)votingAuthenticationHash;
- (BOOL)containsProviderOwningAuthenticationHash:(UInt160)owningAuthenticationHash;
- (BOOL)containsProviderOperatorAuthenticationKey:(UInt384)providerOperatorAuthenticationKey;
- (BOOL)containsBlockchainIdentityBLSAuthenticationHash:(UInt160)blockchainIdentityAuthenticationHash;
- (BOOL)containsHoldingAddress:(NSString *)holdingAddress;

- (NSUInteger)indexOfProviderVotingAuthenticationHash:(UInt160)votingAuthenticationHash;
- (NSUInteger)indexOfProviderOwningAuthenticationHash:(UInt160)owningAuthenticationHash;
- (NSUInteger)indexOfProviderOperatorAuthenticationKey:(UInt384)providerOperatorAuthenticationKey;
- (NSUInteger)indexOfPlatformNodeAuthenticationHash:(UInt160)platformNodeAuthenticationHash;
- (NSUInteger)indexOfHoldingAddress:(NSString *)holdingAddress;
- (NSUInteger)indexOfBlockchainIdentityAuthenticationHash:(UInt160)blockchainIdentityAuthenticationHash;
- (NSUInteger)indexOfBlockchainIdentityCreditFundingRegistrationHash:(UInt160)creditFundingRegistrationHash;
- (NSUInteger)indexOfBlockchainIdentityCreditFundingTopupHash:(UInt160)creditFundingTopupHash;
- (NSUInteger)indexOfBlockchainIdentityCreditFundingInvitationHash:(UInt160)creditFundingInvitationHash;

@end

NS_ASSUME_NONNULL_END
