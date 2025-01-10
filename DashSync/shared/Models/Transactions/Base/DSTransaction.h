//
//  DSTransaction.h
//  DashSync
//
//  Created by Aaron Voisine for BreadWallet on 5/16/13.
//  Copyright (c) 2013 Aaron Voisine <voisine@gmail.com>
//  Copyright (c) 2018 Dash Core Group <contact@dash.org>
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

#import "DSShapeshiftEntity+CoreDataClass.h"
#import <Foundation/Foundation.h>
#import "DSChain.h"
#import "DSKeyManager.h"
#import "DSTransactionInput.h"
#import "DSTransactionOutput.h"

NS_ASSUME_NONNULL_BEGIN

@class DSChain, DSAccount, DSWallet, DSTransactionLockVote, DSTransactionEntity, DSInstantSendTransactionLock, DSIdentity, DSDerivationPath, DSTransactionInput, DSTransactionOutput;

#define TX_FEE_PER_B 1ULL                                                          // standard tx fee per b of tx size
#define TX_FEE_PER_INPUT 10000ULL                                                  // standard ix fee per input
#define TX_OUTPUT_SIZE 34                                                          // estimated size for a typical transaction output
#define TX_INPUT_SIZE 148                                                          // estimated size for a typical compact pubkey transaction input
#define TX_MIN_OUTPUT_AMOUNT (TX_FEE_PER_B * 3 * (TX_OUTPUT_SIZE + TX_INPUT_SIZE)) //no txout can be below this amount
#define TX_MAX_SIZE 100000                                                         // no tx can be larger than this size in bytes
//#define TX_UNCONFIRMED INT32_MAX                                                   // block height indicating transaction is unconfirmed
//#define TX_MAX_LOCK_HEIGHT 500000000                                               // a lockTime below this value is a block height, otherwise a timestamp

#define TX_VERSION 0x00000001u
#define SPECIAL_TX_VERSION 0x00000003u
#define TX_LOCKTIME 0x00000000u
#define TXIN_SEQUENCE UINT32_MAX
#define SIGHASH_ALL 0x00000001u

#define MAX_ECDSA_SIGNATURE_SIZE 75

typedef union _UInt256 UInt256;
typedef union _UInt160 UInt160;


typedef NS_ENUM(NSInteger, DSTransactionSortType)
{
    /// No sorting
    DSTransactionSortType_None,
    /// Shuffle outputs
    DSTransactionSortType_Shuffle,
    /// Sorting inputs & outputs according to BIP-69
    DSTransactionSortType_BIP69,
};

typedef NS_ENUM(NSUInteger, DSTransactionDirection)
{
    DSTransactionDirection_Sent,
    DSTransactionDirection_Received,
    DSTransactionDirection_Moved,
    DSTransactionDirection_NotAccountFunds,
};

@interface DSTransaction : NSObject

@property (nonatomic, readonly) NSArray<DSTransactionInput *> *inputs;
@property (nonatomic, readonly) NSArray<DSTransactionOutput *> *outputs;

@property (nonatomic, readonly) NSArray *inputAddresses;
@property (nonatomic, readonly) NSArray *outputAddresses;

@property (nonatomic, readonly) NSSet<DSIdentity *> *sourceIdentities;
@property (nonatomic, readonly) NSSet<DSIdentity *> *destinationIdentities;

@property (nonatomic, readonly) BOOL instantSendReceived;
@property (nonatomic, readonly) BOOL confirmed;

@property (nonatomic, readonly) BOOL hasUnverifiedInstantSendLock;

@property (nonatomic, readonly) DSInstantSendTransactionLock *instantSendLockAwaitingProcessing;

@property (nonatomic, assign) UInt256 txHash;
@property (nonatomic, assign) uint16_t version;
@property (nonatomic, assign) uint16_t type;
@property (nonatomic, assign) uint32_t lockTime;
@property (nonatomic, assign) uint64_t feeUsed;
@property (nonatomic, assign) uint64_t roundedFeeCostPerByte;
@property (nonatomic, readonly) uint64_t amountSent;
@property (nonatomic, readonly) NSData *payloadData;
@property (nonatomic, readonly) NSData *payloadDataForHash;
@property (nonatomic, assign) uint32_t payloadOffset;
@property (nonatomic, assign) uint32_t blockHeight;
@property (nonatomic, readonly) uint32_t confirmations;
@property (nonatomic, assign) NSTimeInterval timestamp; // time interval since 1970
@property (nonatomic, readonly) size_t size;            // size in bytes if signed, or estimated size assuming compact pubkey sigs
@property (nonatomic, readonly) uint64_t standardFee;
@property (nonatomic, readonly) uint64_t standardInstantFee;
@property (nonatomic, readonly) BOOL isSigned; // checks if all signatures exist, but does not verify them
@property (nonatomic, readonly, getter=toData) NSData *data;

@property (nonatomic, readonly) NSString *longDescription;
@property (nonatomic, readonly) BOOL isCoinbaseClassicTransaction;
//@property (nonatomic, readonly) BOOL isCreditFundingTransaction;
@property (nonatomic, readonly) UInt256 creditBurnIdentityIdentifier;

@property (nonatomic, strong) DSShapeshiftEntity *associatedShapeshift;
@property (nonatomic, readonly) DSChain *chain;
@property (nonatomic, readonly) DSAccount *firstAccount;
@property (nonatomic, readonly) NSArray *accounts;
@property (nonatomic, readonly) Class entityClass;

@property (nonatomic, readonly) BOOL transactionTypeRequiresInputs;

+ (instancetype)transactionWithMessage:(NSData *)message onChain:(DSChain *)chain;
+ (UInt256)devnetGenesisCoinbaseTxHash:(dash_spv_crypto_network_chain_type_DevnetType *)devnetType onProtocolVersion:(uint32_t)protocolVersion forChain:(DSChain *)chain;

- (instancetype)initOnChain:(DSChain *)chain;
- (instancetype)initWithMessage:(NSData *)message onChain:(DSChain *)chain;
- (instancetype)initWithInputHashes:(NSArray *)hashes inputIndexes:(NSArray *)indexes inputScripts:(NSArray *)scripts
                    outputAddresses:(NSArray *)addresses
                      outputAmounts:(NSArray *)amounts
                            onChain:(DSChain *)chain; //for v1

- (instancetype)initWithInputHashes:(NSArray *)hashes inputIndexes:(NSArray *)indexes inputScripts:(NSArray *)scripts inputSequences:(NSArray *)inputSequences outputAddresses:(NSArray *)addresses outputAmounts:(NSArray *)amounts onChain:(DSChain *)chain; //for v2 onwards

- (void)addInputHash:(UInt256)hash index:(NSUInteger)index script:(NSData *_Nullable)script;
- (void)addInputHash:(UInt256)hash index:(NSUInteger)index script:(NSData *_Nullable)script signature:(NSData *_Nullable)signature
            sequence:(uint32_t)sequence;
- (void)addOutputAddress:(NSString *)address amount:(uint64_t)amount;
- (void)addOutputScript:(NSData *)script withAddress:(NSString *_Nullable)address amount:(uint64_t)amount;
- (void)addOutputShapeshiftAddress:(NSString *)address;
- (void)addOutputBurnAmount:(uint64_t)amount;
- (void)addOutputCreditAddress:(NSString *)address amount:(uint64_t)amount;
- (void)addOutputScript:(NSData *)script amount:(uint64_t)amount;
- (void)setInputAddress:(NSString *)address atIndex:(NSUInteger)index;
- (void)shuffleOutputOrder;
- (void)sortInputsAccordingToBIP69;
- (void)sortOutputsAccordingToBIP69;
- (void)hasSetInputsAndOutputs;
- (BOOL)signWithSerializedPrivateKeys:(NSArray *)privateKeys;
- (BOOL)signWithPrivateKeys:(NSArray *)keys;
// TMP method to handle specific c structures
- (BOOL)signWithMaybePrivateKeys:(NSArray *)keys;
- (BOOL)signWithPreorderedPrivateKeys:(NSArray *)keys;

- (NSString *_Nullable)shapeshiftOutboundAddress;
- (NSString *_Nullable)shapeshiftOutboundAddressForceScript;
+ (NSString *_Nullable)shapeshiftOutboundAddressForScript:(NSData *)script onChain:(DSChain *)chain;

// priority = sum(input_amount_in_satoshis*input_age_in_blocks)/tx_size_in_bytes
- (uint64_t)priorityForAmounts:(NSArray *)amounts withAges:(NSArray *)ages;

- (NSData *)toDataWithSubscriptIndex:(NSUInteger)subscriptIndex;

- (BOOL)hasNonDustOutputInWallet:(DSWallet *)wallet;

- (DSTransactionEntity *)save;

- (DSTransactionEntity *)saveInContext:(NSManagedObjectContext *)context;

- (BOOL)saveInitial; //returns if the save took place

- (BOOL)setInitialPersistentAttributesInContext:(NSManagedObjectContext *)context;

//instant send

- (void)setInstantSendReceivedWithInstantSendLock:(DSInstantSendTransactionLock *)instantSendLock;

- (void)loadIdentitiesFromDerivationPaths:(NSArray<DSDerivationPath *> *)derivationPaths;

@end
//typedef NSUInteger DSTransactionDirection;

@interface DSTransaction (Extensions)
- (DSTransactionDirection)direction;
@end

NS_ASSUME_NONNULL_END
