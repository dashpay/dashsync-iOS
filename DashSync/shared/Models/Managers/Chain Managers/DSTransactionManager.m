//
//  DSTransactionManager.m
//  DashSync
//
//  Created by Sam Westrich on 11/21/18.
//  Copyright (c) 2018 Dash Core Group <contact@dash.org>
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

#import "DSTransactionManager.h"
#import "DSAccount.h"
#import "DSAuthenticationManager.h"
#import "DSBlock.h"
#import "DSIdentity+Protected.h"
#import "DSIdentityRegistrationTransition.h"
#import "DSBloomFilter.h"
#import "DSChain+Params.h"
#import "DSChain+Protected.h"
#import "DSChain+Transaction.h"
#import "DSChain+Wallet.h"
#import "DSChainLock.h"
#import "DSChainManager+Protected.h"
#import "DSDAPIPlatformNetworkService.h"
#import "DSError.h"
#import "DSEventManager.h"
#import "DSIdentitiesManager.h"
#import "DSInstantSendTransactionLock.h"
#import "DSMasternodeManager+Protected.h"
#import "DSMerkleBlock.h"
#import "DSOptionsManager.h"
#import "DSPaymentProtocol.h"
#import "DSPaymentRequest.h"
#import "DSPeerManager+Protected.h"
#import "DSPriceManager.h"
#import "DSSpecialTransactionsWalletHolder.h"
#import "DSTransaction.h"
#import "DSTransactionEntity+CoreDataClass.h"
#import "DSTransactionHashEntity+CoreDataClass.h"
#import "DSTransactionInput.h"
#import "DSTransition.h"
#import "DSWallet+Identity.h"
#import "DSWallet+Protected.h"
#import "NSData+Dash.h"
#import "NSDate+Utils.h"
#import "NSError+Dash.h"
#import "NSManagedObject+Sugar.h"
#import "NSMutableData+Dash.h"
#import "NSString+Bitcoin.h"
#import "NSString+Dash.h"

#if TARGET_OS_IOS
#import "UIWindow+DSUtils.h"
#endif

#define IX_INPUT_LOCKED_KEY @"IX_INPUT_LOCKED_KEY"
#define MAX_TOTAL_TRANSACTIONS_FOR_BLOOM_FILTER_RETARGETING 500

#define SAVE_MAX_TRANSACTIONS_INFO (DEBUG && 0)
#define DEBUG_CHAIN_LOCKS_WAITING_FOR_QUORUMS (DEBUG && 0)

#define ERROR_NOT_SIGNED [NSError errorWithCode:401 localizedDescriptionKey:@"Dash transaction not signed"]
#define ERROR_SIGNING [NSError errorWithCode:401 localizedDescriptionKey:@"Error signing transaction"]
#define ERROR_NOT_CONNECTED [NSError errorWithCode:-1009 localizedDescriptionKey:@"Not connected to the Dash network"]
#define ERROR_TIMEOUT [NSError errorWithCode:DASH_PEER_TIMEOUT_CODE localizedDescriptionKey:@"Transaction canceled, network timeout"]
#define ERROR_DOUBLE_SPEND [NSError errorWithCode:401 localizedDescriptionKey:@"Double spend"]

@interface DSTransactionManager ()

@property (nonatomic, strong) NSMutableDictionary *txRelays, *txRequests;
@property (nonatomic, strong) NSMutableDictionary *publishedTx, *publishedCallback;
@property (nonatomic, strong) NSMutableSet *nonFalsePositiveTransactions;

@property (nonatomic, strong) DSBloomFilter *bloomFilter;
@property (nonatomic, assign) uint32_t filterUpdateHeight;
@property (nonatomic, assign) double transactionsBloomFilterFalsePositiveRate;
@property (nonatomic, readonly) DSMasternodeManager *masternodeManager;
@property (nonatomic, readonly) DSPeerManager *peerManager;
@property (nonatomic, readonly) DSChainManager *chainManager;
@property (nonatomic, strong) NSMutableArray *removeUnrelayedTransactionsLocalRequests;
@property (nonatomic, strong) NSMutableDictionary *instantSendLocksWaitingForQuorums;
@property (nonatomic, strong) NSMutableDictionary *instantSendLocksWaitingForTransactions;
@property (nonatomic, strong) NSMutableDictionary *chainLocksWaitingForMerkleBlocks;
@property (nonatomic, strong) NSMutableDictionary *chainLocksWaitingForQuorums;

#if SAVE_MAX_TRANSACTIONS_INFO

@property (nonatomic, strong) NSMutableArray *totalTransactionsQueue;
@property (nonatomic, assign) uint32_t totalTransactionsSum;
@property (nonatomic, assign) uint32_t totalTransactionsMax;
@property (nonatomic, assign) uint32_t totalTransactionsMaxLastPosition;
@property (nonatomic, strong) NSMutableData *totalTransactionData;

#endif

@end

@implementation DSTransactionManager

- (instancetype)initWithChain:(id)chain {
    if (!(self = [super init])) return nil;
    _chain = chain;

#if SAVE_MAX_TRANSACTIONS_INFO
    self.totalTransactionsQueue = [NSMutableArray array];
    self.totalTransactionData = [NSMutableData data];
    self.totalTransactionsSum = 0;
#endif
    self.txRelays = [NSMutableDictionary dictionary];
    self.txRequests = [NSMutableDictionary dictionary];
    self.publishedTx = [NSMutableDictionary dictionary];
    self.publishedCallback = [NSMutableDictionary dictionary];
    self.nonFalsePositiveTransactions = [NSMutableSet set];
    self.removeUnrelayedTransactionsLocalRequests = [NSMutableArray array];
    self.instantSendLocksWaitingForQuorums = [NSMutableDictionary dictionary];
    self.instantSendLocksWaitingForTransactions = [NSMutableDictionary dictionary];
    self.chainLocksWaitingForMerkleBlocks = [NSMutableDictionary dictionary];
    self.chainLocksWaitingForQuorums = [NSMutableDictionary dictionary];
    [self recreatePublishedTransactionList];
    return self;
}

// MARK: - Managers

- (DSPeerManager *)peerManager {
    return self.chain.chainManager.peerManager;
}

- (DSMasternodeManager *)masternodeManager {
    return self.chain.chainManager.masternodeManager;
}

- (DSIdentitiesManager *)identitiesManager {
    return self.chain.chainManager.identitiesManager;
}

- (DSChainManager *)chainManager {
    return self.chain.chainManager;
}

// MARK: - Helpers

#if TARGET_OS_IOS
- (UIViewController *)presentingViewController {
    return [[UIWindow keyWindow] ds_presentingViewController];
}
#endif

// MARK: - Blockchain Transactions

// adds transaction to list of tx to be published, along with any unconfirmed inputs
- (void)addUnconfirmedTransactionToPublishList:(DSTransaction *)transaction {
    if (transaction.blockHeight == TX_UNCONFIRMED) {
#if DEBUG
        DSLogPrivate(@"[%@] [DSTransactionManager] add transaction to publish list %@ (%@)", self.chain.name, transaction, transaction.toData);
#else
        DSLog(@"[%@] [DSTransactionManager] add transaction to publish list", self.chain.name);
#endif
        if (!self.publishedTx[uint256_obj(transaction.txHash)]) {
            self.publishedTx[uint256_obj(transaction.txHash)] = transaction;
            for (DSTransactionInput *input in transaction.inputs) {
                UInt256 h = input.inputHash;
                DSTransaction *inputTransaction = [self.chain transactionForHash:h];
                if (inputTransaction) {
                    [self addUnconfirmedTransactionToPublishList:inputTransaction];
                }
            }
        }
    }
}

- (void)publishTransaction:(DSTransaction *)transaction completion:(void (^)(NSError * _Nullable error))completion {
#if DEBUG
    DSLogPrivate(@"[%@] [DSTransactionManager] publish transaction %@ %@", self.chain.name, transaction, transaction.toData);
#else
    DSLog(@"[%@] [DSTransactionManager] publish transaction", self.chain.name);
#endif
    if ([transaction transactionTypeRequiresInputs] && !transaction.isSigned) {
        if (completion) {
            [[DSEventManager sharedEventManager] saveEvent:@"transaction_manager:not_signed"];
            completion(ERROR_NOT_SIGNED);
        }

        return;
    } else if (!self.peerManager.connected && self.peerManager.connectFailures >= MAX_CONNECT_FAILURES) {
        if (completion) {
            [[DSEventManager sharedEventManager] saveEvent:@"transaction_manager:not_connected"];
            completion(ERROR_NOT_CONNECTED);
        }

        return;
    }

    NSMutableSet *peers = [NSMutableSet setWithSet:self.peerManager.connectedPeers];
    NSValue *hash = uint256_obj(transaction.txHash);

    [self addUnconfirmedTransactionToPublishList:transaction];
    if (completion) self.publishedCallback[hash] = completion;

    NSArray *txHashes = self.publishedTx.allKeys;

    // instead of publishing to all peers, leave out the download peer to see if the tx propogates and gets relayed back
    // TODO: XXX connect to a random peer with an empty or fake bloom filter just for publishing
    if (self.peerManager.connectedPeerCount > 1 && self.peerManager.downloadPeer) [peers removeObject:self.peerManager.downloadPeer];

    dispatch_async(self.chainManager.chain.networkingQueue, ^{
        [self performSelector:@selector(txTimeout:) withObject:hash afterDelay:PROTOCOL_TIMEOUT];

        for (DSPeer *p in peers) {
            if (p.status != DSPeerStatus_Connected) continue;
            [p sendTransactionInvMessagesforTransactionHashes:txHashes txLockRequestHashes:nil];
            [p sendPingMessageWithPongHandler:^(BOOL success) {
                if (!success) return;

                for (NSValue *h in txHashes) {
                    if ([self.txRelays[h] containsObject:p] || [self.txRequests[h] containsObject:p]) continue;
                    if (!self.txRequests[h]) self.txRequests[h] = [NSMutableSet set];
                    [self.txRequests[h] addObject:p];
                    //todo: to get lock requests instead if sent that way
                    [p sendGetdataMessageWithTxHashes:@[h] instantSendLockHashes:nil instantSendLockDHashes:nil blockHashes:nil chainLockHashes:nil];
                }
            }];
        }
    });
}

//This is used when re-entering app, the wallet needs to check all transactions that are in a publishing phase.
- (void)recreatePublishedTransactionList {
    for (DSWallet *wallet in self.chain.wallets) {
        for (DSTransaction *tx in wallet.allTransactions) { // find TXOs spent within the last 100 blocks
            if (tx.blockHeight == TX_UNCONFIRMED) {
                [self addUnconfirmedTransactionToPublishList:tx]; // also populate the tx publish list
            }
            if (tx.hasUnverifiedInstantSendLock) {
                [self.instantSendLocksWaitingForQuorums setObject:tx.instantSendLockAwaitingProcessing forKey:uint256_data(tx.txHash)];
            }
        }
    }
}


// unconfirmed transactions that aren't in the mempools of any of connected peers have likely dropped off the network
- (void)removeUnrelayedTransactionsFromPeer:(DSPeer *)peer {
    [self.removeUnrelayedTransactionsLocalRequests addObject:peer.location];
    // don't remove transactions until we're connected to maxConnectCount peers
    if (self.removeUnrelayedTransactionsLocalRequests.count < 2) {
        DSLog(@"[%@] [DSTransactionManager] not removing unrelayed transactions until we have synced mempools from 2 peers %lu", self.chain.name, (unsigned long)self.peerManager.connectedPeerCount);
        return;
    }

    for (DSPeer *p in self.peerManager.connectedPeers) { // don't remove tx until sendMempoolMessage
        DSLog(@"[%@: %@:%d] [DSTransactionManager] not removing unrelayed transactions because peer is not synced yet", self.chain.name, p.host, p.port);
        if (!p.synced) return;
    }
    DSLog(@"[%@] [DSTransactionManager] removing unrelayed transactions", self.chain.name);
    NSMutableSet *transactionsSet = [NSMutableSet set];
    NSMutableSet *specialTransactionsSet = [NSMutableSet set];

    NSMutableArray *transactionsToBeRemoved = [NSMutableArray array];

    for (DSWallet *wallet in self.chain.wallets) {
        [transactionsSet addObjectsFromArray:[wallet.specialTransactionsHolder allTransactions]];
        [specialTransactionsSet addObjectsFromArray:[wallet.specialTransactionsHolder allTransactions]];
        for (DSAccount *account in wallet.accounts) {
            [transactionsSet addObjectsFromArray:account.allTransactions];
        }
    }

    BOOL rescan = NO, notify = NO;
    NSValue *hash;

    for (DSTransaction *transaction in transactionsSet) {
        if (transaction.blockHeight != TX_UNCONFIRMED) continue;
        hash = uint256_obj(transaction.txHash);
        DSLog(@"[%@] checking published callback -> %@", self.chain.name, self.publishedCallback[hash] ? @"OK" : @"no callback");
        if (self.publishedCallback[hash] != NULL) continue;
        DSLog(@"[%@] transaction relays count %lu, transaction requests count %lu", self.chain.name, (unsigned long)[self.txRelays[hash] count], (unsigned long)[self.txRequests[hash] count]);
        DSAccount *account = [self.chain firstAccountThatCanContainTransaction:transaction];
        if (!account && ![specialTransactionsSet containsObject:transaction]) {
            //the following might be needed, it was in evopayments branch
            //            if (!self.chain.isDevnetAny || ![transaction isKindOfClass:[DSTransition class]]) {
            //                NSAssert(FALSE, @"This needs to be implemented for transitions, if you are here now is the time to do it.");
            //            }
            NSAssert(FALSE, @"This probably needs more implementation work, if you are here now is the time to do it.");
            continue;
        }
        if ([self.txRelays[hash] count] == 0 && [self.txRequests[hash] count] == 0) {
            // if this is for a transaction we sent, and it wasn't already known to be invalid, notify user of failure
            if (!rescan && account && [account amountSentByTransaction:transaction] > 0 && [account transactionIsValid:transaction]) {
#if DEBUG
                DSLogPrivate(@"[%@] failed transaction %@", self.chain.name, transaction);
#else
                DSLog(@"[%@] failed transaction <REDACTED>", self.chain.name);
#endif
                rescan = notify = YES;

                for (DSTransactionInput *input in transaction.inputs) { // only recommend a rescan if all inputs are confirmed
                    if ([account transactionForHash:input.inputHash].blockHeight != TX_UNCONFIRMED) continue;
                    rescan = NO;
                    break;
                }
            } else if (!account) {
#if DEBUG
                DSLogPrivate(@"[%@] serious issue in masternode transaction %@", self.chain.name, transaction);
#else
                DSLog(@"[%@] serious issue in masternode transaction <REDACTED>", self.chain.name);
#endif
            } else {
#if DEBUG
                DSLogPrivate(@"[%@] serious issue in transaction %@", self.chain.name, transaction);
#else
                DSLog(@"[%@] serious issue in transaction <REDACTED>", self.chain.name);
#endif
            }
#if DEBUG
            DSLogPrivate(@"[%@] removing transaction %@", self.chain.name, transaction);
#else
            DSLog(@"[%@] removing transaction <REDACTED>", self.chain.name);
#endif
            [transactionsToBeRemoved addObject:transaction];

        } else if ([self.txRelays[hash] count] < self.peerManager.maxConnectCount) {
            // set timestamp 0 to mark as unverified
#if DEBUG
            DSLogPrivate(@"[%@] setting transaction as unverified %@", self.chain.name, transaction);
#else
            DSLog(@"[%@] setting transaction as unverified <REDACTED>", self.chain.name);
#endif
            [self.chain setBlockHeight:TX_UNCONFIRMED
                          andTimestamp:0
                  forTransactionHashes:@[hash]];
        }
    }

    if (transactionsToBeRemoved.count) {
        NSManagedObjectContext *context = nil;
        for (DSTransaction *transaction in [transactionsToBeRemoved copy]) {
            NSArray *accounts = [self.chain accountsThatCanContainTransaction:transaction];
            for (DSAccount *account in accounts) {
                [account removeTransaction:transaction saveImmediately:NO];
                NSAssert(!context || context == account.managedObjectContext, @"All accounts should be on same context");
                context = account.managedObjectContext;
            }
        }
        [context ds_saveInBlockAndWait];
    }

    [self.removeUnrelayedTransactionsLocalRequests removeAllObjects];

    if (notify) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (rescan) {
                [[DSEventManager sharedEventManager] saveEvent:@"transaction_manager:tx_rejected_rescan"];
#if TARGET_OS_IOS
                UIAlertController *alert = [UIAlertController
                    alertControllerWithTitle:DSLocalizedString(@"Transaction rejected", nil)
                                     message:DSLocalizedString(@"Your wallet may be out of sync.\n"
                                                                "This can often be fixed by rescanning the blockchain.",
                                                 nil)
                              preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction *cancelButton = [UIAlertAction
                    actionWithTitle:DSLocalizedString(@"OK", nil)
                              style:UIAlertActionStyleCancel
                            handler:^(UIAlertAction *action){
                            }];
                UIAlertAction *rescanButton = [UIAlertAction
                    actionWithTitle:DSLocalizedString(@"Rescan", nil)
                              style:UIAlertActionStyleDefault
                            handler:^(UIAlertAction *action) {
                                [self.chainManager syncBlocksRescan];
                            }];
                [alert addAction:cancelButton];
                [alert addAction:rescanButton];
                [[self presentingViewController] presentViewController:alert animated:YES completion:nil];
#endif
            } else {
                [[DSEventManager sharedEventManager] saveEvent:@"transaction_manager_tx_rejected"];
#if TARGET_OS_IOS
                UIAlertController *alert = [UIAlertController
                    alertControllerWithTitle:DSLocalizedString(@"Transaction rejected", nil)
                                     message:@""
                              preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction *okButton = [UIAlertAction
                    actionWithTitle:DSLocalizedString(@"OK", nil)
                              style:UIAlertActionStyleCancel
                            handler:^(UIAlertAction *action){
                            }];
                [alert addAction:okButton];
                [[self presentingViewController] presentViewController:alert animated:YES completion:nil];
#endif
            }
        });
    }
}

// number of connected peers that have relayed the transaction
- (NSUInteger)relayCountForTransaction:(UInt256)txHash {
    return [self.txRelays[uint256_obj(txHash)] count];
}

- (void)txTimeout:(NSValue *)txHash {
    dispatch_async(dispatch_get_main_queue(), ^{
        void (^callback)(NSError *error) = self.publishedCallback[txHash];

        [self.publishedTx removeObjectForKey:txHash];
        [self.publishedCallback removeObjectForKey:txHash];

        dispatch_async(self.chainManager.chain.networkingQueue, ^{
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(txTimeout:) object:txHash];
        });

        if (callback) {
            [[DSEventManager sharedEventManager] saveEvent:@"transaction_manager:tx_canceled_timeout"];
            callback(ERROR_TIMEOUT);
        }
    });
}

- (void)clearTransactionRelaysForPeer:(DSPeer *)peer {
    for (NSValue *txHash in self.txRelays.allKeys) {
        [self.txRelays[txHash] removeObject:peer];
    }
}

// MARK: - Front end

- (void)confirmProtocolRequest:(DSPaymentProtocolRequest *)protoReq forAmount:(uint64_t)requestedAmount fromAccount:(DSAccount *)account addressIsFromPasteboard:(BOOL)addressIsFromPasteboard requiresSpendingAuthenticationPrompt:(BOOL)requiresSpendingAuthenticationPrompt
    keepAuthenticatedIfErrorAfterAuthentication:(BOOL)keepAuthenticatedIfErrorAfterAuthentication
                       requestingAdditionalInfo:(DSTransactionCreationRequestingAdditionalInfoBlock)additionalInfoRequest
                               presentChallenge:(DSTransactionChallengeBlock)challenge
                  transactionCreationCompletion:(DSTransactionCreationCompletionBlock)transactionCreationCompletion
                               signedCompletion:(DSTransactionSigningCompletionBlock)signedCompletion
                            publishedCompletion:(DSTransactionPublishedCompletionBlock)publishedCompletion
                         requestRelayCompletion:(DSTransactionRequestRelayCompletionBlock)requestRelayCompletion
                         errorNotificationBlock:(DSTransactionErrorNotificationBlock)errorNotificationBlock {
    return [self confirmProtocolRequest:protoReq
                                          forAmount:requestedAmount
                                        fromAccount:account
                              acceptInternalAddress:NO
                               acceptReusingAddress:NO
                            addressIsFromPasteboard:addressIsFromPasteboard
                             acceptUncertifiedPayee:NO
               requiresSpendingAuthenticationPrompt:requiresSpendingAuthenticationPrompt
        keepAuthenticatedIfErrorAfterAuthentication:keepAuthenticatedIfErrorAfterAuthentication
                           requestingAdditionalInfo:additionalInfoRequest
                                   presentChallenge:challenge
                      transactionCreationCompletion:transactionCreationCompletion
                                   signedCompletion:signedCompletion
                                publishedCompletion:publishedCompletion
                             requestRelayCompletion:requestRelayCompletion
                             errorNotificationBlock:errorNotificationBlock];
}

- (void)confirmProtocolRequest:(DSPaymentProtocolRequest *)protoReq forAmount:(uint64_t)requestedAmount fromAccount:(DSAccount *)account acceptInternalAddress:(BOOL)acceptInternalAddress acceptReusingAddress:(BOOL)acceptReusingAddress addressIsFromPasteboard:(BOOL)addressIsFromPasteboard acceptUncertifiedPayee:(BOOL)acceptUncertifiedPayee
           requiresSpendingAuthenticationPrompt:(BOOL)requiresSpendingAuthenticationPrompt
    keepAuthenticatedIfErrorAfterAuthentication:(BOOL)keepAuthenticatedIfErrorAfterAuthentication
                       requestingAdditionalInfo:(DSTransactionCreationRequestingAdditionalInfoBlock)additionalInfoRequest
                               presentChallenge:(DSTransactionChallengeBlock)challenge
                  transactionCreationCompletion:(DSTransactionCreationCompletionBlock)transactionCreationCompletion
                               signedCompletion:(DSTransactionSigningCompletionBlock)signedCompletion
                            publishedCompletion:(DSTransactionPublishedCompletionBlock)publishedCompletion
                         requestRelayCompletion:(DSTransactionRequestRelayCompletionBlock)requestRelayCompletion
                         errorNotificationBlock:(DSTransactionErrorNotificationBlock)errorNotificationBlock {
    DSChain *chain = account.wallet.chain;
    DSWallet *wallet = account.wallet;
    DSPriceManager *priceManager = [DSPriceManager sharedInstance];
    DSTransaction *tx = nil;
    uint64_t amount = 0, fee = 0;
    BOOL valid = protoReq.isValid, outputTooSmall = NO;

    if (!valid && [protoReq.errorMessage isEqual:DSLocalizedString(@"Request expired", nil)]) {
        NSString *errorTitle = DSLocalizedString(@"Bad payment request", nil);
        NSString *errorMessage = protoReq.errorMessage;
        NSString *localizedDescription = [NSString stringWithFormat:@"%@\n%@", errorTitle, errorMessage];
        NSError *error = [NSError errorWithDomain:DSErrorDomain
                                             code:DSErrorPaymentRequestExpired
                                         userInfo:@{NSLocalizedDescriptionKey: localizedDescription}];
        errorNotificationBlock(error, errorTitle, errorMessage, YES);
        return;
    }

    //TODO: check for duplicates of already paid requests

    if (requestedAmount == 0) {
        for (NSNumber *outputAmount in protoReq.details.outputAmounts) {
            if (outputAmount.unsignedLongLongValue > 0 && outputAmount.unsignedLongLongValue < TX_MIN_OUTPUT_AMOUNT) {
                outputTooSmall = YES;
            }
            amount += outputAmount.unsignedLongLongValue;
        }
    } else
        amount = requestedAmount;


    NSString *address = [DSKeyManager addressWithScriptPubKey:protoReq.details.outputScripts.firstObject forChain:chain];
    if (!acceptInternalAddress && [wallet accountsBaseDerivationPathsContainAddress:address]) {
        NSString *challengeTitle = DSLocalizedString(@"WARNING", nil);
        NSString *challengeMessage = DSLocalizedString(@"This payment address is already in your wallet", nil);
        NSString *challengeAction = DSLocalizedString(@"Ignore", nil);
        challenge(
            challengeTitle, challengeMessage, challengeAction, ^{
                [self confirmProtocolRequest:protoReq forAmount:requestedAmount fromAccount:account acceptInternalAddress:YES acceptReusingAddress:acceptReusingAddress addressIsFromPasteboard:addressIsFromPasteboard acceptUncertifiedPayee:acceptUncertifiedPayee requiresSpendingAuthenticationPrompt:requiresSpendingAuthenticationPrompt keepAuthenticatedIfErrorAfterAuthentication:keepAuthenticatedIfErrorAfterAuthentication requestingAdditionalInfo:additionalInfoRequest presentChallenge:challenge transactionCreationCompletion:transactionCreationCompletion signedCompletion:signedCompletion publishedCompletion:publishedCompletion requestRelayCompletion:requestRelayCompletion errorNotificationBlock:errorNotificationBlock];
            },
            ^{
                additionalInfoRequest(DSRequestingAdditionalInfo_CancelOrChangeAmount);
            });
        return;
    } else if ((amount == 0 || amount == UINT64_MAX) && !acceptReusingAddress && [wallet transactionAddressAlreadySeenInOutputs:address] && addressIsFromPasteboard) {
        NSString *challengeTitle = DSLocalizedString(@"WARNING", nil);
        NSString *challengeMessage = DSLocalizedString(@"\nADDRESS ALREADY USED\nDash addresses are intended for single use only\n\n"
                                                        "re-use reduces privacy for both you and the recipient and can result in loss if "
                                                        "the recipient doesn't directly control the address",
            nil);
        NSString *challengeAction = DSLocalizedString(@"Ignore", nil);
        challenge(
            challengeTitle, challengeMessage, challengeAction, ^{
                [self confirmProtocolRequest:protoReq
                                                      forAmount:requestedAmount
                                                    fromAccount:account
                                          acceptInternalAddress:acceptInternalAddress
                                           acceptReusingAddress:YES
                                        addressIsFromPasteboard:addressIsFromPasteboard
                                         acceptUncertifiedPayee:acceptUncertifiedPayee
                           requiresSpendingAuthenticationPrompt:requiresSpendingAuthenticationPrompt
                    keepAuthenticatedIfErrorAfterAuthentication:keepAuthenticatedIfErrorAfterAuthentication
                                       requestingAdditionalInfo:additionalInfoRequest
                                               presentChallenge:challenge
                                  transactionCreationCompletion:transactionCreationCompletion
                                               signedCompletion:signedCompletion
                                            publishedCompletion:publishedCompletion
                                         requestRelayCompletion:requestRelayCompletion
                                         errorNotificationBlock:errorNotificationBlock];
            },
            ^{
                additionalInfoRequest(DSRequestingAdditionalInfo_CancelOrChangeAmount);
            });
        return;
    } else if (protoReq.errorMessage.length > 0 && protoReq.commonName.length > 0 &&
               !acceptUncertifiedPayee) {
        NSString *challengeTitle = DSLocalizedString(@"Payee identity isn't certified", nil);
        NSString *challengeMessage = protoReq.errorMessage;
        NSString *challengeAction = DSLocalizedString(@"Ignore", nil);
        challenge(
            challengeTitle, challengeMessage, challengeAction, ^{
                [self confirmProtocolRequest:protoReq forAmount:requestedAmount fromAccount:account acceptInternalAddress:acceptInternalAddress acceptReusingAddress:acceptReusingAddress addressIsFromPasteboard:addressIsFromPasteboard acceptUncertifiedPayee:YES requiresSpendingAuthenticationPrompt:requiresSpendingAuthenticationPrompt keepAuthenticatedIfErrorAfterAuthentication:keepAuthenticatedIfErrorAfterAuthentication requestingAdditionalInfo:additionalInfoRequest presentChallenge:challenge transactionCreationCompletion:transactionCreationCompletion signedCompletion:signedCompletion publishedCompletion:publishedCompletion requestRelayCompletion:requestRelayCompletion errorNotificationBlock:errorNotificationBlock];
            },
            ^{
                additionalInfoRequest(DSRequestingAdditionalInfo_CancelOrChangeAmount);
            });

        return;
    } else if (amount == 0 || amount == UINT64_MAX) {
        additionalInfoRequest(DSRequestingAdditionalInfo_Amount);
        return;
    } else if (amount < TX_MIN_OUTPUT_AMOUNT) {
        NSString *errorTitle = DSLocalizedString(@"Couldn't make payment", nil);
        NSString *errorMessage = [NSString stringWithFormat:
                                               DSLocalizedString(@"Dash payments can't be less than %@", nil),
                                           [priceManager stringForDashAmount:TX_MIN_OUTPUT_AMOUNT]];
        NSString *localizedDescription = [NSString stringWithFormat:@"%@\n%@", errorTitle, errorMessage];
        NSError *error = [NSError errorWithDomain:DSErrorDomain
                                             code:DSErrorPaymentAmountLessThenMinOutputAmount
                                         userInfo:@{NSLocalizedDescriptionKey: localizedDescription}];
        errorNotificationBlock(error, errorTitle, errorMessage, YES);
        return;
    } else if (outputTooSmall) {
        NSString *errorTitle = DSLocalizedString(@"Couldn't make payment", nil);
        NSString *errorMessage = [NSString stringWithFormat:
                                               DSLocalizedString(@"Dash transaction outputs can't be less than %@", nil),
                                           [priceManager stringForDashAmount:TX_MIN_OUTPUT_AMOUNT]];
        NSString *localizedDescription = [NSString stringWithFormat:@"%@\n%@", errorTitle, errorMessage];
        NSError *error = [NSError errorWithDomain:DSErrorDomain
                                             code:DSErrorPaymentTransactionOutputTooSmall
                                         userInfo:@{NSLocalizedDescriptionKey: localizedDescription}];
        errorNotificationBlock(error, errorTitle, errorMessage, YES);
        return;
    }

    if (requestedAmount == 0) {
        tx = [account transactionForAmounts:protoReq.details.outputAmounts
                            toOutputScripts:protoReq.details.outputScripts
                                    withFee:YES];
    } else if (amount <= account.balance) {
        tx = [account transactionForAmounts:@[@(requestedAmount)]
                            toOutputScripts:@[protoReq.details.outputScripts.firstObject]
                                    withFee:YES];
    }

    if (tx) {
        amount = [account amountSentByTransaction:tx] - [account amountReceivedFromTransaction:tx]; //safeguard
        fee = [account feeForTransaction:tx];
    } else {
        DSTransaction *tempTx = [account transactionFor:account.balance
                                                     to:address
                                                withFee:NO];
        uint8_t additionalInputs = (((account.balance - amount) % 1024) >> 8); //get a random amount of additional inputs between 0 and 3, we don't use last bits because they are often 0
        fee = [chain feeForTxSize:tempTx.size + TX_INPUT_SIZE * additionalInputs];
        amount += fee; // pretty much a random fee
    }

    for (NSData *script in protoReq.details.outputScripts) {
        NSString *addr = [DSKeyManager addressWithScriptPubKey:script forChain:chain];
        if (!addr) addr = DSLocalizedString(@"Unrecognized address", nil);
        if ([address rangeOfString:addr].location != NSNotFound) continue;
        address = [address stringByAppendingFormat:@"%@%@", (address.length > 0) ? @", " : @"", addr];
    }

    NSParameterAssert(address);

    NSString *name = protoReq.commonName;
    NSString *memo = protoReq.details.memo;
    BOOL isSecure = (valid && ![protoReq.pkiType isEqual:@"none"]);
    NSString *localCurrency = protoReq.requestedFiatAmountCurrencyCode;
    NSString *suggestedPrompt = [[DSAuthenticationManager sharedInstance] promptForAmount:amount
                                                                                      fee:fee
                                                                                  address:address
                                                                                     name:name
                                                                                     memo:memo
                                                                                 isSecure:isSecure
                                                                             errorMessage:@""
                                                                            localCurrency:localCurrency];
    
    if (transactionCreationCompletion(tx, suggestedPrompt, amount, fee, address ? @[address] : @[], isSecure)) {
        CFRunLoopPerformBlock([[NSRunLoop mainRunLoop] getCFRunLoop], kCFRunLoopCommonModes, ^{
            [self signAndPublishTransaction:tx createdFromProtocolRequest:protoReq fromAccount:account toAddress:address requiresSpendingAuthenticationPrompt:YES promptMessage:suggestedPrompt forAmount:amount keepAuthenticatedIfErrorAfterAuthentication:keepAuthenticatedIfErrorAfterAuthentication requestingAdditionalInfo:additionalInfoRequest presentChallenge:challenge transactionCreationCompletion:transactionCreationCompletion signedCompletion:signedCompletion publishedCompletion:publishedCompletion requestRelayCompletion:requestRelayCompletion errorNotificationBlock:errorNotificationBlock];
        });
    }
}

- (void)signAndPublishTransaction:(DSTransaction *)tx createdFromProtocolRequest:(DSPaymentProtocolRequest *)protocolRequest fromAccount:(DSAccount *)account toAddress:(NSString *)address requiresSpendingAuthenticationPrompt:(BOOL)requiresSpendingAuthenticationPrompt promptMessage:(NSString *)promptMessage forAmount:(uint64_t)amount keepAuthenticatedIfErrorAfterAuthentication:(BOOL)keepAuthenticatedIfErrorAfterAuthentication requestingAdditionalInfo:(DSTransactionCreationRequestingAdditionalInfoBlock)additionalInfoRequest presentChallenge:(DSTransactionChallengeBlock)challenge transactionCreationCompletion:(DSTransactionCreationCompletionBlock)transactionCreationCompletion signedCompletion:(DSTransactionSigningCompletionBlock)signedCompletion publishedCompletion:(DSTransactionPublishedCompletionBlock)publishedCompletion requestRelayCompletion:(DSTransactionRequestRelayCompletionBlock)requestRelayCompletion errorNotificationBlock:(DSTransactionErrorNotificationBlock)errorNotificationBlock {
    DSAuthenticationManager *authenticationManager = [DSAuthenticationManager sharedInstance];
    __block BOOL previouslyWasAuthenticated = authenticationManager.didAuthenticate;

    if (!tx) { // tx is nil if there were insufficient wallet funds
        if (authenticationManager.didAuthenticate) {
            //the fee puts us over the limit
            [self insufficientFundsForTransactionCreatedFromProtocolRequest:protocolRequest fromAccount:account forAmount:amount toAddress:address requiresSpendingAuthenticationPrompt:requiresSpendingAuthenticationPrompt keepAuthenticatedIfErrorAfterAuthentication:keepAuthenticatedIfErrorAfterAuthentication requestingAdditionalInfo:additionalInfoRequest presentChallenge:challenge transactionCreationCompletion:transactionCreationCompletion signedCompletion:signedCompletion publishedCompletion:publishedCompletion requestRelayCompletion:requestRelayCompletion errorNotificationBlock:errorNotificationBlock];
        } else {
            [authenticationManager seedWithPrompt:promptMessage
                                        forWallet:account.wallet
                                        forAmount:amount
                              forceAuthentication:NO
                                       completion:^(NSData *_Nullable seed, BOOL cancelled) {
                                           if (seed) {
                                               //the fee puts us over the limit
                                               [self insufficientFundsForTransactionCreatedFromProtocolRequest:protocolRequest fromAccount:account forAmount:amount toAddress:address requiresSpendingAuthenticationPrompt:requiresSpendingAuthenticationPrompt keepAuthenticatedIfErrorAfterAuthentication:keepAuthenticatedIfErrorAfterAuthentication requestingAdditionalInfo:additionalInfoRequest presentChallenge:challenge transactionCreationCompletion:transactionCreationCompletion signedCompletion:signedCompletion publishedCompletion:publishedCompletion requestRelayCompletion:requestRelayCompletion errorNotificationBlock:errorNotificationBlock];
                                           } else {
                                               additionalInfoRequest(DSRequestingAdditionalInfo_CancelOrChangeAmount);
                                           }
                                           if (!previouslyWasAuthenticated && !keepAuthenticatedIfErrorAfterAuthentication) [authenticationManager deauthenticate];
                                       }];
        }
    } else {
        NSString *displayedPrompt = promptMessage;
        if (promptMessage && !requiresSpendingAuthenticationPrompt && authenticationManager.didAuthenticate) {
            displayedPrompt = nil; //don't display a confirmation
        } else if (!promptMessage && requiresSpendingAuthenticationPrompt) {
            displayedPrompt = @"";
        }
        [account signTransaction:tx
                      withPrompt:displayedPrompt
                      completion:^(BOOL signedTransaction, BOOL cancelled) {
                          if (cancelled) {
                              if (!previouslyWasAuthenticated && !keepAuthenticatedIfErrorAfterAuthentication) [authenticationManager deauthenticate];
                              if (signedCompletion) {
                                  dispatch_async(dispatch_get_main_queue(), ^{
                                      signedCompletion(tx, nil, YES);
                                  });
                              }

                              return;
                          }

                          if (!signedTransaction || !tx.isSigned) {
                              if (!previouslyWasAuthenticated && !keepAuthenticatedIfErrorAfterAuthentication) [authenticationManager deauthenticate];
                              dispatch_async(dispatch_get_main_queue(), ^{
                                  signedCompletion(tx, ERROR_SIGNING, NO);
                              });
                              return;
                          }

                          if (!previouslyWasAuthenticated) [authenticationManager deauthenticate];

                          if (!signedCompletion(tx, nil, NO)) return; //give the option to stop the process to clients

                          [self publishSignedTransaction:tx createdFromProtocolRequest:protocolRequest fromAccount:account publishedCompletion:publishedCompletion requestRelayCompletion:requestRelayCompletion errorNotificationBlock:errorNotificationBlock];
                      }];
    }
}

- (void)publishSignedTransaction:(DSTransaction *)tx createdFromProtocolRequest:(DSPaymentProtocolRequest *)protocolRequest fromAccount:(DSAccount *)account publishedCompletion:(DSTransactionPublishedCompletionBlock)publishedCompletion requestRelayCompletion:(DSTransactionRequestRelayCompletionBlock)requestRelayCompletion errorNotificationBlock:(DSTransactionErrorNotificationBlock)errorNotificationBlock {
    NSParameterAssert(tx);
    if (!tx || !tx.isSigned) return;

    __block BOOL sent = NO;

    if (protocolRequest.details.paymentURL.length == 0) {
        [account registerTransaction:tx saveImmediately:NO];

        [self publishTransaction:tx
                      completion:^(NSError *publishingError) {
                          if (publishingError) {
                              if (!sent) {
                                  [account removeTransaction:tx saveImmediately:YES]; //we save in case the transaction was registered and saved from another process
                                  dispatch_async(dispatch_get_main_queue(), ^{
                                      publishedCompletion(tx, publishingError, sent);
                                  });
                              }
                          } else if (!sent) {
                              sent = YES;
                              tx.timestamp = [NSDate timeIntervalSince1970];
                              [tx saveInitial];
                              dispatch_async(dispatch_get_main_queue(), ^{
                                  publishedCompletion(tx, nil, sent);
                              });
                          }
                      }];
    } else {
        uint64_t refundAmount = 0;
        NSData *refundScript = [DSKeyManager scriptPubKeyForAddress:account.receiveAddress forChain:account.wallet.chain];
        for (NSNumber *amt in protocolRequest.details.outputAmounts) {
            refundAmount += amt.unsignedLongLongValue;
        }

        // TODO: keep track of commonName/memo to associate them with outputScripts
        DSPaymentProtocolPayment *payment =
            [[DSPaymentProtocolPayment alloc] initWithMerchantData:protocolRequest.details.merchantData
                                                      transactions:@[tx]
                                                   refundToAmounts:@[@(refundAmount)]
                                                   refundToScripts:@[refundScript]
                                                              memo:nil
                                                           onChain:account.wallet.chain];

#if DEBUG
        DSLogPrivate(@"[%@] posting payment to: %@", self.chain.name, protocolRequest.details.paymentURL);
#else
        DSLog(@"[%@] posting payment to: <REDACTED>", self.chain.name);
#endif

        [DSPaymentRequest postPayment:payment
                               scheme:@"dash"
                                   to:protocolRequest.details.paymentURL
                              onChain:account.wallet.chain
                              timeout:20.0
                           completion:^(DSPaymentProtocolACK *ack, NSError *error) {
                               if (error) {
                                   dispatch_async(dispatch_get_main_queue(), ^{
                                       NSString *errorTitle = [NSString
                                           stringWithFormat:
                                               DSLocalizedString(@"Error from payment request server %@", nil),
                                           protocolRequest.details.paymentURL];
                                       NSString *errorMessage = error.localizedDescription;
                                       NSString *localizedDescription = [NSString
                                           stringWithFormat:@"%@\n%@",
                                           errorTitle, errorMessage];
                                       NSError *resError = [NSError
                                           errorWithDomain:DSErrorDomain
                                                      code:DSErrorPaymentRequestServerError
                                                  userInfo:@{
                                                      NSLocalizedDescriptionKey: localizedDescription,
                                                      NSUnderlyingErrorKey: error,
                                                  }];
                                       errorNotificationBlock(resError, errorTitle, errorMessage, YES);
                                   });
                               } else {
                                   dispatch_async(dispatch_get_main_queue(), ^{
                                       requestRelayCompletion(tx, ack, !error);
                                   });
                                   [account registerTransaction:tx saveImmediately:NO];

                                   [self publishTransaction:tx
                                                 completion:^(NSError *publishingError) {
                                                     if (publishingError) {
                                                         if (!sent) {
                                                             [account removeTransaction:tx saveImmediately:YES]; //we save in case the transaction was registered and saved from another process
                                                             dispatch_async(dispatch_get_main_queue(), ^{
                                                                 publishedCompletion(tx, publishingError, sent);
                                                             });
                                                         }
                                                     } else if (!sent) {
                                                         sent = YES;
                                                         tx.timestamp = [NSDate timeIntervalSince1970];
                                                         [tx saveInitial];
                                                         dispatch_async(dispatch_get_main_queue(), ^{
                                                             publishedCompletion(tx, nil, sent);
                                                         });
                                                     }
                                                 }];
                               }
                           }];
    }
}

- (void)insufficientFundsForTransactionCreatedFromProtocolRequest:(DSPaymentProtocolRequest *)protocolRequest fromAccount:(DSAccount *)account forAmount:(uint64_t)requestedSendAmount toAddress:(NSString *)address requiresSpendingAuthenticationPrompt:(BOOL)requiresSpendingAuthenticationPrompt
                      keepAuthenticatedIfErrorAfterAuthentication:(BOOL)keepAuthenticatedIfErrorAfterAuthentication
                                         requestingAdditionalInfo:(DSTransactionCreationRequestingAdditionalInfoBlock)additionalInfoRequest
                                                 presentChallenge:(DSTransactionChallengeBlock)challenge
                                    transactionCreationCompletion:(DSTransactionCreationCompletionBlock)transactionCreationCompletion
                                                 signedCompletion:(DSTransactionSigningCompletionBlock)signedCompletion
                                              publishedCompletion:(DSTransactionPublishedCompletionBlock)publishedCompletion
                                           requestRelayCompletion:(DSTransactionRequestRelayCompletionBlock)requestRelayCompletion
                                           errorNotificationBlock:(DSTransactionErrorNotificationBlock)errorNotificationBlock {
    DSPriceManager *manager = [DSPriceManager sharedInstance];
    uint64_t fuzz = [manager amountForLocalCurrencyString:[manager localCurrencyStringForDashAmount:1]] * 2;
    if (requestedSendAmount <= account.balance + fuzz && requestedSendAmount > 0 && !protocolRequest.details.paymentURL) {
        // if user selected an amount equal to or below wallet balance, but the fee will bring the total above the
        // balance, offer to reduce the amount to available funds minus fee
        int64_t amount = [account maxOutputAmount];

        if (amount > 0 && amount < requestedSendAmount) {
            NSString *challengeTitle = DSLocalizedString(@"Insufficient funds for Dash network fee", nil);
            NSString *challengeMessage = [NSString stringWithFormat:DSLocalizedString(@"Reduce payment amount by\n%@ (%@)?", nil),
                                                   [manager stringForDashAmount:requestedSendAmount - amount],
                                                   [manager localCurrencyStringForDashAmount:requestedSendAmount - amount]];

            NSString *reduceString = [NSString stringWithFormat:@"%@ (%@)",
                                               [manager stringForDashAmount:amount - requestedSendAmount],
                                               [manager localCurrencyStringForDashAmount:amount - requestedSendAmount]];

            void (^sendReducedBlock)(void) = ^{
                DSPaymentRequest *paymentRequest = [DSPaymentRequest requestWithString:address onChain:self.chain];
                paymentRequest.amount = amount;
                [self confirmProtocolRequest:paymentRequest.protocolRequest
                                                      forAmount:amount
                                                    fromAccount:account
                                          acceptInternalAddress:YES
                                           acceptReusingAddress:YES
                                        addressIsFromPasteboard:NO
                                         acceptUncertifiedPayee:YES
                           requiresSpendingAuthenticationPrompt:requiresSpendingAuthenticationPrompt
                    keepAuthenticatedIfErrorAfterAuthentication:keepAuthenticatedIfErrorAfterAuthentication
                                       requestingAdditionalInfo:additionalInfoRequest
                                               presentChallenge:challenge
                                  transactionCreationCompletion:transactionCreationCompletion
                                               signedCompletion:signedCompletion
                                            publishedCompletion:publishedCompletion
                                         requestRelayCompletion:requestRelayCompletion
                                         errorNotificationBlock:errorNotificationBlock];
            };

            challenge(challengeTitle, challengeMessage, reduceString, sendReducedBlock, ^{
                additionalInfoRequest(DSRequestingAdditionalInfo_CancelOrChangeAmount);
            });
        } else {
            NSString *errorTitle = DSLocalizedString(@"Insufficient funds for Dash network fee", nil);
            NSError *error = [NSError errorWithDomain:DSErrorDomain
                                                 code:DSErrorInsufficientFundsForNetworkFee
                                             userInfo:@{NSLocalizedDescriptionKey: errorTitle}];
            errorNotificationBlock(error, errorTitle, nil, NO);
        }
    } else {
        NSString *errorTitle = DSLocalizedString(@"Insufficient funds", nil);
        NSError *error = [NSError errorWithDomain:DSErrorDomain
                                             code:DSErrorInsufficientFunds
                                         userInfo:@{NSLocalizedDescriptionKey: errorTitle}];
        errorNotificationBlock(error, errorTitle, nil, NO);
    }
}

- (void)confirmPaymentRequest:(DSPaymentRequest *)paymentRequest
  usingUserIdentity:(DSIdentity *)identity
                  fromAccount:(DSAccount *)account
        acceptInternalAddress:(BOOL)acceptInternalAddress
         acceptReusingAddress:(BOOL)acceptReusingAddress
      addressIsFromPasteboard:(BOOL)addressIsFromPasteboard
requiresSpendingAuthenticationPrompt:(BOOL)requiresSpendingAuthenticationPrompt
    keepAuthenticatedIfErrorAfterAuthentication:(BOOL)keepAuthenticatedIfErrorAfterAuthentication
     requestingAdditionalInfo:(DSTransactionCreationRequestingAdditionalInfoBlock)additionalInfoRequest
             presentChallenge:(DSTransactionChallengeBlock)challenge
transactionCreationCompletion:(DSTransactionCreationCompletionBlock)transactionCreationCompletion
             signedCompletion:(DSTransactionSigningCompletionBlock)signedCompletion
          publishedCompletion:(DSTransactionPublishedCompletionBlock)publishedCompletion
       errorNotificationBlock:(DSTransactionErrorNotificationBlock)errorNotificationBlock {
    DSPaymentProtocolRequest *protocolRequest = [paymentRequest protocolRequestForIdentity:identity onAccount:account inContext:[NSManagedObjectContext viewContext]];
    [self confirmProtocolRequest:protocolRequest forAmount:paymentRequest.amount fromAccount:account acceptInternalAddress:acceptInternalAddress acceptReusingAddress:acceptReusingAddress addressIsFromPasteboard:addressIsFromPasteboard acceptUncertifiedPayee:NO requiresSpendingAuthenticationPrompt:requiresSpendingAuthenticationPrompt keepAuthenticatedIfErrorAfterAuthentication:keepAuthenticatedIfErrorAfterAuthentication requestingAdditionalInfo:additionalInfoRequest presentChallenge:challenge transactionCreationCompletion:transactionCreationCompletion signedCompletion:signedCompletion publishedCompletion:publishedCompletion requestRelayCompletion:nil errorNotificationBlock:errorNotificationBlock];
}

// MARK: - Mempools Sync

- (void)fetchMempoolFromPeer:(DSPeer *)peer {
    DSLog(@"[%@: %@:%d] [DSTransactionManager] fetching mempool from peer", self.chain.name, peer.host, peer.port);
    if (peer.status != DSPeerStatus_Connected) return;

    if ([self.chain canConstructAFilter] && (peer != self.peerManager.downloadPeer || self.transactionsBloomFilterFalsePositiveRate > BLOOM_REDUCED_FALSEPOSITIVE_RATE * 5.0)) {
        DSLog(@"[%@: %@:%d] [DSTransactionManager] sending filterload message from peer", self.chain.name, peer.host, peer.port);
        [peer sendFilterloadMessage:[self transactionsBloomFilterForPeer:peer].data];
    }

    [peer sendInvMessageForHashes:self.publishedTx.allKeys ofType:DSInvType_Tx]; // publish pending tx
    [peer sendPingMessageWithPongHandler:^(BOOL success) {
        if (success) {
            DSLog(@"[%@: %@:%d] [DSTransactionManager] fetching mempool ping success peer", self.chain.name, peer.host, peer.port);
            [peer sendMempoolMessage:self.publishedTx.allKeys
                          completion:^(BOOL success, BOOL needed, BOOL interruptedByDisconnect) {
                if (success) {
                    DSLog(@"[%@: %@:%d] [DSTransactionManager] fetching mempool message success peer", self.chain.name, peer.host, peer.port);
                    peer.synced = YES;
                    [self removeUnrelayedTransactionsFromPeer:peer];
                    if (!self.chainManager.peerManager.masternodeList) {
                        [peer sendGetaddrMessage]; // request a list of other dash peers
                    }
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[NSNotificationCenter defaultCenter] postNotificationName:DSTransactionManagerTransactionStatusDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey: self.chain}];
                    });
                } else {
                    if (!needed) {
                        DSLog(@"[%@: %@:%d] [DSTransactionManager] fetching mempool message not needed peer", self.chain.name, peer.host, peer.port);
                    } else if (interruptedByDisconnect) {
                        DSLog(@"[%@: %@:%d] [DSTransactionManager] fetching mempool message failure by disconnect peer", self.chain.name, peer.host, peer.port);
                    } else {
                        DSLog(@"[%@: %@:%d] [DSTransactionManager] fetching mempool message failure peer", self.chain.name, peer.host, peer.port);
                    }
                }
                if (peer == self.peerManager.downloadPeer) {
                    [self.peerManager chainSyncStopped];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[NSNotificationCenter defaultCenter] postNotificationName:DSChainManagerSyncFinishedNotification object:nil userInfo:@{DSChainManagerNotificationChainKey: self.chain}];
                    });
                }
            }];
        } else if (peer == self.peerManager.downloadPeer) {
            DSLog(@"[%@: %@:%d] [DSTransactionManager] fetching mempool ping failure on download peer", self.chain.name, peer.host, peer.port);
            [self.peerManager chainSyncStopped];

            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter]
                    postNotificationName:DSChainManagerSyncFinishedNotification
                                  object:nil
                                userInfo:@{DSChainManagerNotificationChainKey: self.chain}];
            });
        } else {
            DSLog(@"[%@: %@:%d] [DSTransactionManager] fetching mempool ping failure on peer", self.chain.name, peer.host, peer.port);
        }
    }];
}

- (void)fetchMempoolFromNetwork {
    // this can come from any queue
    if (!([[DSOptionsManager sharedInstance] syncType] & DSSyncType_Mempools)) return; // make sure we care about mempool
    for (DSPeer *peer in self.peerManager.connectedPeers) {                            // after syncing, load filters and get mempools from other peers
        [self fetchMempoolFromPeer:peer];
    }
}

//// MARK: - TransactionFetching
//
//- (void)fetchTransactionWithDAPIForTransactionHash:(UInt256)transactionHash success:(void (^)(DSTransaction *transaction))success
//                                           failure:(void (^)(NSError *error))failure {
//    DSDAPIPlatformNetworkService *networkService = self.chainManager.DAPIClient.DAPIPlatformNetworkService;
//    [networkService getTransactionById:uint256_hex(transactionHash)
//                               success:^(NSDictionary *_Nonnull transactionDictionary) {
//                                   //[DSTransaction transactionWithMessage:<#(nonnull NSData *)#>
//                                   //                              onChain:<#(nonnull DSChain *)#>]}
//                               }
//                               failure:failure];
//}

- (void)fetchTransactionHavingHash:(UInt256)transactionHash {
    for (DSPeer *peer in self.peerManager.connectedPeers) {
        [peer sendGetdataMessageForTxHash:transactionHash];
    }
}

// MARK: - Bloom Filters

//This returns the bloom filter for the peer, currently the filter is only tweaked per peer, and we only cache the filter of the download peer.
//It makes sense to keep this in this class because it is not a property of the chain, but intead of a effemeral item used in the synchronization of the chain.
- (DSBloomFilter *)transactionsBloomFilterForPeer:(DSPeer *)peer {
    self.filterUpdateHeight = self.chain.lastSyncBlockHeight;

    //Now lets calculate our ideal bloom filter false positive rate with the following assumptions: while the average 500 block max transactions stays around the same we should receive back on average 1 transaction every 2 days.
    self.transactionsBloomFilterFalsePositiveRate = BLOOM_REDUCED_FALSEPOSITIVE_RATE;


    // TODO: XXXX if already synced, recursively add inputs of unconfirmed receives
    _bloomFilter = [self.chain bloomFilterWithFalsePositiveRate:self.transactionsBloomFilterFalsePositiveRate withTweak:(uint32_t)peer.hash];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DSTransactionManagerFilterDidChangeNotification
                                                            object:nil
                                                          userInfo:@{DSChainManagerNotificationChainKey: self.chain}];
    });
    return _bloomFilter;
}

- (void)destroyTransactionsBloomFilter {
    if (!_bloomFilter) return; // bloom filter is aready being updated
    _bloomFilter = nil;
    [self.peerManager pauseBlockchainSynchronizationOnPeers];
}

- (void)updateTransactionsBloomFilter {
    if (!_bloomFilter) return; // bloom filter is aready being updated

    // the transaction likely consumed one or more wallet addresses, so check that at least the next <gap limit>
    // unused addresses are still matched by the bloom filter
    NSMutableArray *allAddressesArray = [NSMutableArray array];

    for (DSWallet *wallet in self.chain.wallets) {
        // every time a new wallet address is added, the bloom filter has to be rebuilt, and each address is only used for
        // one transaction, so here we generate some spare addresses to avoid rebuilding the filter each time a wallet
        // transaction is encountered during the blockchain download
        [wallet registerAddressesWithGapLimit:SEQUENCE_GAP_LIMIT_EXTERNAL unusedAccountGapLimit:SEQUENCE_UNUSED_GAP_LIMIT_EXTERNAL dashpayGapLimit:SEQUENCE_DASHPAY_GAP_LIMIT_INCOMING internal:NO error:nil];
        [wallet registerAddressesWithGapLimit:SEQUENCE_GAP_LIMIT_INTERNAL unusedAccountGapLimit:SEQUENCE_GAP_LIMIT_INTERNAL dashpayGapLimit:SEQUENCE_DASHPAY_GAP_LIMIT_INCOMING internal:YES error:nil];
        NSSet *addresses = [wallet.allReceiveAddresses setByAddingObjectsFromSet:wallet.allChangeAddresses];
        [allAddressesArray addObjectsFromArray:[addresses allObjects]];

        [allAddressesArray addObjectsFromArray:[wallet providerOwnerAddresses]];
        [allAddressesArray addObjectsFromArray:[wallet providerVotingAddresses]];
        [allAddressesArray addObjectsFromArray:[wallet providerOperatorAddresses]];
        [allAddressesArray addObjectsFromArray:[wallet platformNodeAddresses]];
    }

    for (DSFundsDerivationPath *derivationPath in self.chain.standaloneDerivationPaths) {
        [derivationPath registerAddressesWithGapLimit:SEQUENCE_GAP_LIMIT_EXTERNAL internal:NO error:nil];
        [derivationPath registerAddressesWithGapLimit:SEQUENCE_GAP_LIMIT_INTERNAL internal:YES error:nil];
        NSArray *addresses = [derivationPath.allReceiveAddresses arrayByAddingObjectsFromArray:derivationPath.allChangeAddresses];
        [allAddressesArray addObjectsFromArray:addresses];
    }

    for (NSString *address in allAddressesArray) {
        NSData *hash = address.addressToHash160;

        if (!hash || [_bloomFilter containsData:hash]) continue;
        _bloomFilter = nil; // reset bloom filter so it's recreated with new wallet addresses
        [self.peerManager updateFilterOnPeers];
        break;
    }
}

- (void)clearTransactionsBloomFilter {
    self.bloomFilter = nil;
}

// MARK: - DSChainTransactionsDelegate

- (void)chain:(DSChain *)chain didSetBlockHeight:(int32_t)height andTimestamp:(NSTimeInterval)timestamp forTransactionHashes:(NSArray *)transactionHashes updatedTransactions:(NSArray *)updatedTransactions {
    if (height != TX_UNCONFIRMED) { // remove confirmed tx from publish list and relay counts
        [self.publishedTx removeObjectsForKeys:transactionHashes];
        [self.publishedCallback removeObjectsForKeys:transactionHashes];
        [self.txRelays removeObjectsForKeys:transactionHashes];
    }
}

- (void)chainWasWiped:(DSChain *)chain {
    [self.txRelays removeAllObjects];
    [self.publishedTx removeAllObjects];
    [self.publishedCallback removeAllObjects];
    _bloomFilter = nil;
}

// MARK: - DSPeerTransactionsDelegate

// MARK: Outgoing Transactions

//The peer is requesting a transaction that it does not know about that we are publishing
- (DSTransaction *)peer:(DSPeer *)peer requestedTransaction:(UInt256)txHash {
    NSValue *hash = uint256_obj(txHash);
#if DEBUG
    DSLogPrivate(@"[%@: %@:%d] Peer requested transaction with hash %@", self.chain.name, peer.host, peer.port, hash);
#else
    DSLog(@"[%@: %@:%d] Peer requested transaction with hash <REDACTED>", self.chain.name, peer.host, peer.port);
#endif
    DSTransaction *transaction = self.publishedTx[hash];
    BOOL transactionIsPublished = !!transaction;
    NSArray<DSAccount *> *accounts = nil;
    if (transaction) {
        accounts = [self.chain accountsThatCanContainTransaction:transaction];
    }
    if (transactionIsPublished) {
        if (![accounts count]) {
            accounts = [self.chain accountsForTransactionHash:txHash transaction:nil];
        }
    } else {
        accounts = [self.chain accountsForTransactionHash:txHash transaction:&transaction];
    }
    if (![accounts count]) {
#if DEBUG
        DSLogPrivate(@"[%@: %@:%d] No transaction could be found on any account for hash %@", self.chain.name, peer.host, peer.port, hash);
#else
        DSLog(@"[%@: %@:%d] No transaction could be found on any account for hash <REDACTED>", self.chain.name, peer.host, peer.port);
#endif
        return nil;
    }
    void (^callback)(NSError *error) = self.publishedCallback[hash];
    NSError *error = nil;

    if (!self.txRelays[hash]) self.txRelays[hash] = [NSMutableSet set];
    [self.txRelays[hash] addObject:peer];
    [self.nonFalsePositiveTransactions addObject:hash];
    [self.publishedCallback removeObjectForKey:hash];

    BOOL isTransactionValid = YES;
    if (callback) {
        for (DSAccount *account in accounts) {
            isTransactionValid &= [account transactionIsValid:transaction];
        }
    }

    if (callback && !isTransactionValid) {
        [self.publishedTx removeObjectForKey:hash];
        error = ERROR_DOUBLE_SPEND;
    } else if (transaction) {
        for (DSAccount *account in accounts) {
            if (![account transactionForHash:txHash] && [account registerTransaction:transaction saveImmediately:YES])
                [[NSManagedObjectContext chainContext] ds_saveInBlock];
        }
    }

    dispatch_async(self.chainManager.chain.networkingQueue, ^{
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(txTimeout:) object:hash];
        dispatch_async(dispatch_get_main_queue(), ^{ if (callback) callback(error); });
    });

    //    [peer sendPingMessageWithPongHandler:^(BOOL success) { // check if peer will relay the transaction back
    //        if (! success) return;
    //
    //        if (! [self.txRequests[hash] containsObject:peer]) {
    //            if (! self.txRequests[hash]) self.txRequests[hash] = [NSMutableSet set];
    //            [self.txRequests[hash] addObject:peer];
    //            [peer sendGetdataMessageWithTxHashes:@[hash] andBlockHashes:nil];
    //        }
    //    }];

    return transaction;
}

// MARK: Incoming Transactions

//The peer is informing us that it has an inventory of a transaction we might be interested in, this might also be a transaction we sent out which we are checking has properly been relayed on the network

#define TEST_NO_RELAY (0 && !DEBUG)

- (void)peer:(DSPeer *)peer hasTransactionWithHash:(UInt256)txHash {
#if TEST_NO_RELAY
    return;
#endif
    NSValue *hash = uint256_obj(txHash);
    BOOL syncing = (self.chain.lastSyncBlockHeight < self.chain.estimatedBlockHeight);
    DSTransaction *transaction = self.publishedTx[hash];
    void (^callback)(NSError *error) = self.publishedCallback[hash];

#if DEBUG
    DSLogPrivate(@"[%@: %@:%d] has transaction %@", self.chain.name, peer.host, peer.port, hash);
#else
    DSLog(@"[%@: %@:%d] has transaction %@", self.chain.name, peer.host, peer.port, @"<REDACTED>");
#endif
    if (!transaction) transaction = [self.chain transactionForHash:txHash];
    if (!transaction) {
        DSLog(@"[%@: %@:%d] No transaction found on chain for this transaction", self.chain.name, peer.host, peer.port);
        return;
    }
    DSAccount *account = [self.chain firstAccountThatCanContainTransaction:transaction];
    if (syncing && !account) {
        DSLog(@"[%@: %@:%d] No account found for this transaction", self.chain.name, peer.host, peer.port);
        return;
    }
    if (![account registerTransaction:transaction saveImmediately:YES]) return;
    if (peer == self.peerManager.downloadPeer) [self.chainManager relayedNewItem];
    // keep track of how many peers have or relay a tx, this indicates how likely the tx is to confirm
    if (callback || (!syncing && ![self.txRelays[hash] containsObject:peer])) {
        if (!self.txRelays[hash]) self.txRelays[hash] = [NSMutableSet set];
        [self.txRelays[hash] addObject:peer];
        if (callback) [self.publishedCallback removeObjectForKey:hash];

        if ([self.txRelays[hash] count] >= self.peerManager.maxConnectCount &&
            [self.chain transactionForHash:txHash].blockHeight == TX_UNCONFIRMED &&
            [self.chain transactionForHash:txHash].timestamp == 0) {
            [self.chain setBlockHeight:TX_UNCONFIRMED
                          andTimestamp:[NSDate timeIntervalSince1970]
                  forTransactionHashes:@[hash]]; // set timestamp when tx is verified
        }

        dispatch_async(self.chainManager.chain.networkingQueue, ^{
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(txTimeout:) object:hash];
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:DSTransactionManagerTransactionStatusDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey: self.chain}];
                if (callback) callback(nil);
            });
        });
    }

    [self.nonFalsePositiveTransactions addObject:hash];
    [self.txRequests[hash] removeObject:peer];
}

//The peer has sent us a transaction we are interested in and that we did not send ourselves
- (void)peer:(DSPeer *)peer relayedTransaction:(DSTransaction *)transaction inBlock:(DSBlock *)block {
    NSValue *hash = uint256_obj(transaction.txHash);
    BOOL syncing = (self.chain.lastSyncBlockHeight < self.chain.estimatedBlockHeight);
    void (^callback)(NSError *error) = self.publishedCallback[hash];

    if (peer) {
#if DEBUG
        DSLogPrivate(@"[%@: %@:%d] relayed transaction %@", self.chain.name, peer.host, peer.port, hash);
#else
        DSLog(@"[%@: %@:%d] relayed transaction %@", self.chain.name, peer.host, peer.port, @"<REDACTED>");
#endif
    } else {
#if DEBUG
        DSLogPrivate(@"[%@: %@:%d] accepting local transaction %@", self.chain.name, peer.host, peer.port, hash);
#else
        DSLog(@"[%@: %@:%d] accepting local transaction %@", self.chain.name, peer.host, peer.port, @"<REDACTED>");
#endif
    }

    transaction.timestamp = block ? block.timestamp : [NSDate timeIntervalSince1970];
    NSArray<DSAccount *> *accounts = [self.chain accountsThatCanContainTransaction:transaction];
    NSMutableArray<DSAccount *> *accountsAcceptingTransaction = [NSMutableArray array];
    NSMutableArray<DSAccount *> *accountsWithValidTransaction = [NSMutableArray array];
    NSMutableArray<DSAccount *> *accountsSendingValueInTransaction = [NSMutableArray array];
    if (!accounts.count) {
        if (![self.chain transactionHasLocalReferences:transaction]) {
            if (peer) {
#if DEBUG
                DSLogPrivate(@"[%@: %@:%d] no account or local references for transaction %@", self.chain.name, peer.host, peer.port, hash);
#else
                DSLog(@"[%@: %@:%d] no account or local references for transaction %@", self.chain.name, peer.host, peer.port, @"<REDACTED>");
#endif
            } else {
#if DEBUG
                DSLogPrivate(@"[%@: %@:%d] no account or local references for transaction %@", self.chain.name, peer.host, peer.port, hash);
#else
                DSLog(@"[%@: %@:%d] no account or local references for transaction %@", self.chain.name, peer.host, peer.port, @"<REDACTED>");
#endif
            }
            return;
        } else {
            if (peer) {
#if DEBUG
                DSLogPrivate(@"[%@: %@:%d] no account for transaction with local references %@", self.chain.name, peer.host, peer.port, hash);
#else
                DSLog(@"[%@: %@:%d] no account for transaction with local references %@", self.chain.name, peer.host, peer.port, @"<REDACTED>");
#endif
            } else {
#if DEBUG
                DSLogPrivate(@"[%@: %@:%d] no account for transaction with local references %@", self.chain.name, peer.host, peer.port, hash);
#else
                DSLog(@"[%@: %@:%d] no account for transaction with local references %@", self.chain.name, peer.host, peer.port, @"<REDACTED>");
#endif
            }
        }
    } else {
        for (DSAccount *account in accounts) {
            if ([account registerTransaction:transaction saveImmediately:block ? NO : YES]) {
                [accountsAcceptingTransaction addObject:account];
                if ([account transactionIsValid:transaction]) {
                    [accountsWithValidTransaction addObject:account];
                }
                if ([account amountSentByTransaction:transaction] > 0) {
                    [accountsSendingValueInTransaction addObject:account];
                }
            } else {
                if (peer) {
#if DEBUG
                    DSLogPrivate(@"[%@: %@:%d] could not register transaction %@", self.chain.name, peer.host, peer.port, hash);
#else
                    DSLog(@"[%@: %@:%d] could not register transaction %@", self.chain.name, peer.host, peer.port, @"<REDACTED>");
#endif
                } else {
#if DEBUG
                    DSLogPrivate(@"[%@: %@:%d] could not register transaction %@", self.chain.name, peer.host, peer.port, hash);
#else
                    DSLog(@"[%@: %@:%d] could not register transaction %@", self.chain.name, peer.host, peer.port, @"<REDACTED>");
#endif
                }
            }
        }
        if (accountsAcceptingTransaction.count == 0) {
            return;
        }
    }

    BOOL isNewIdentity = FALSE;
    DSIdentity *identity = nil;

    if (![transaction isMemberOfClass:[DSTransaction class]]) {
        //it's a special transaction
        BOOL registered = YES; //default to yes
        if (![transaction isKindOfClass:[DSAssetLockTransaction class]]) {
            registered = [self.chain registerSpecialTransaction:transaction saveImmediately:!block];
        }

        if (registered) {
            if ([transaction isKindOfClass:[DSAssetLockTransaction class]]) {
                DSAssetLockTransaction *assetLockTransaction = (DSAssetLockTransaction *)transaction;
                uint32_t index;
                DSWallet *wallet = [self.chain walletHavingIdentityAssetLockRegistrationHash:assetLockTransaction.creditBurnPublicKeyHash foundAtIndex:&index];
                if (wallet)
                    identity = [wallet identityForUniqueId:transaction.creditBurnIdentityIdentifier];
                if (!identity) {
                    [self.chain triggerUpdatesForLocalReferences:transaction];
                    if (wallet) {
                        identity = [wallet identityForUniqueId:transaction.creditBurnIdentityIdentifier];
                        if (identity) isNewIdentity = TRUE;
                    }
                } else if (identity && !identity.registrationAssetLockTransaction) {
                    identity.registrationAssetLockTransactionHash = assetLockTransaction.txHash;
                }
            } else {
                [self.chain triggerUpdatesForLocalReferences:transaction];
            }
        }

        if (peer && peer == self.peerManager.downloadPeer) [self.chainManager relayedNewItem];

        //While we would only add to publish list is transaction sent amount was over 0 for a normal transaction, other transactions should be published immediately as they have other consequences
        if (accountsWithValidTransaction.count > 0) {
            [self addUnconfirmedTransactionToPublishList:transaction]; // add valid send tx to mempool
        } else if (accountsAcceptingTransaction.count == 0 && registered) {
            [self addUnconfirmedTransactionToPublishList:transaction];
        }

    } else {
        if (peer && peer == self.peerManager.downloadPeer) [self.chainManager relayedNewItem];
        if (accountsSendingValueInTransaction.count > 0 && accountsWithValidTransaction.count > 0) {
            [self addUnconfirmedTransactionToPublishList:transaction]; // add valid send tx to mempool
        }
    }

    DSInstantSendTransactionLock *transactionLockReceivedEarlier = [self.instantSendLocksWaitingForTransactions objectForKey:uint256_data(transaction.txHash)];

    if (transactionLockReceivedEarlier) {
        [self.instantSendLocksWaitingForTransactions removeObjectForKey:uint256_data(transaction.txHash)];
        [transaction setInstantSendReceivedWithInstantSendLock:transactionLockReceivedEarlier];
        [transactionLockReceivedEarlier saveInitial];
    }

    BOOL addedNewAccount = FALSE;

    for (DSAccount *account in accountsAcceptingTransaction) {
        if (([[DSOptionsManager sharedInstance] syncType] & DSSyncType_MultiAccountAutoDiscovery) && account.wallet.lastAccountNumber == account.accountNumber) {
            // We got a transaction for the last account, add an account to the wallet
            DSAccount *addedAccount = [account.wallet addAnotherAccountIfAuthenticated];
            if (addedAccount) {
                addedNewAccount = TRUE;
                // New account was created
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:DSAccountNewAccountFromTransactionNotification
                                                                        object:nil
                                                                      userInfo:@{
                        DSChainManagerNotificationChainKey: self.chain,
                        DSChainManagerNotificationWalletKey: account.wallet,
                        DSChainManagerNotificationAccountKey: account
                    }];
                });
            } else {
                // This means we were not authenticated, we should post a notification
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:DSAccountNewAccountShouldBeAddedFromTransactionNotification
                                                                        object:nil
                                                                      userInfo:@{
                        DSChainManagerNotificationChainKey: self.chain,
                        DSChainManagerNotificationWalletKey: account.wallet
                    }];
                });
            }
            break;
        }
    }

    // keep track of how many peers have or relay a tx, this indicates how likely the tx is to confirm
    if (callback || !peer || (!syncing && ![self.txRelays[hash] containsObject:peer])) {
        if (!self.txRelays[hash])
            self.txRelays[hash] = [NSMutableSet set];
        if (peer)
            [self.txRelays[hash] addObject:peer];
        if (callback) [self.publishedCallback removeObjectForKey:hash];

        for (DSAccount *account in accountsAcceptingTransaction) {
            if (account && [self.txRelays[hash] count] >= self.peerManager.maxConnectCount &&
                [account transactionForHash:transaction.txHash].blockHeight == TX_UNCONFIRMED &&
                [account transactionForHash:transaction.txHash].timestamp == 0) {
                [account setBlockHeight:TX_UNCONFIRMED
                           andTimestamp:[NSDate timeIntervalSince1970]
                   forTransactionHashes:@[hash]]; // set timestamp when tx is verified
            }
        }

        //todo: deal when the transaction received is not in an account


        dispatch_async(self.chainManager.chain.networkingQueue, ^{
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(txTimeout:) object:hash];

            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:DSTransactionManagerTransactionStatusDidChangeNotification
                                                                    object:nil
                                                                  userInfo:@{
                    DSChainManagerNotificationChainKey: self.chain,
                    DSTransactionManagerNotificationTransactionKey: transaction,
                    DSTransactionManagerNotificationTransactionChangesKey: @{DSTransactionManagerNotificationTransactionAcceptedStatusKey: @(YES)}
                }];
                [[NSNotificationCenter defaultCenter] postNotificationName:DSTransactionManagerTransactionReceivedNotification
                                                                    object:nil
                                                                  userInfo:@{
                    DSChainManagerNotificationChainKey: self.chain
                }];
                [[NSNotificationCenter defaultCenter] postNotificationName:DSWalletBalanceDidChangeNotification
                                                                    object:nil
                                                                  userInfo:@{
                    DSChainManagerNotificationChainKey: self.chain
                }];

                if (callback) callback(nil);
            });
        });
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSTransactionManagerTransactionStatusDidChangeNotification
                                                                object:nil
                                                              userInfo:@{DSChainManagerNotificationChainKey: self.chain,
                                                                  DSTransactionManagerNotificationTransactionKey: transaction,
                                                                  DSTransactionManagerNotificationTransactionChangesKey: @{DSTransactionManagerNotificationTransactionAcceptedStatusKey: @(YES)}}];
            [[NSNotificationCenter defaultCenter] postNotificationName:DSTransactionManagerTransactionReceivedNotification object:nil userInfo:@{DSChainManagerNotificationChainKey: self.chain}];
        });
    }


    [self.nonFalsePositiveTransactions addObject:hash];
    if (peer)
        [self.txRequests[hash] removeObject:peer];
    if (block && [transaction isKindOfClass:[DSAssetLockTransaction class]] && identity && isNewIdentity) {
        NSTimeInterval walletCreationTime = [identity.wallet walletCreationTime];
        if ((walletCreationTime == BIP39_WALLET_UNKNOWN_CREATION_TIME || walletCreationTime == BIP39_CREATION_TIME) && identity.wallet.defaultIdentity == identity) {
            [identity.wallet setGuessedWalletCreationTime:self.chain.lastSyncBlockTimestamp - HOUR_TIME_INTERVAL - (DAY_TIME_INTERVAL / arc4random() % DAY_TIME_INTERVAL)];
        }
        [self.identitiesManager checkAssetLockTransactionForPossibleNewIdentity:(DSAssetLockTransaction *)transaction];
        [self destroyTransactionsBloomFilter]; //We want to destroy it temporarily, while we wait for L2, no matter what the block should not be saved and needs to be refetched
    } else if (addedNewAccount) {
        [self destroyTransactionsBloomFilter];
    } else {
        [self updateTransactionsBloomFilter];
    }
}

// MARK: Transaction Issues

- (void)peer:(DSPeer *)peer relayedNotFoundMessagesWithTransactionHashes:(NSArray *)txHashes andBlockHashes:(NSArray *)blockhashes {
    for (NSValue *hash in txHashes) {
        [self.txRelays[hash] removeObject:peer];
        [self.txRequests[hash] removeObject:peer];
    }
}

- (void)peer:(DSPeer *)peer rejectedTransaction:(UInt256)txHash withCode:(uint8_t)code {
    DSTransaction *transaction = nil;
    NSArray<DSAccount *> *accounts = [self.chain accountsForTransactionHash:txHash transaction:&transaction];
    NSValue *hash = uint256_obj(txHash);

    if ([self.txRelays[hash] containsObject:peer]) {
        [self.txRelays[hash] removeObject:peer];

        if (transaction.blockHeight == TX_UNCONFIRMED) { // set timestamp 0 for unverified
            [self.chain setBlockHeight:TX_UNCONFIRMED andTimestamp:0 forTransactionHashes:@[hash]];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSTransactionManagerTransactionStatusDidChangeNotification
                                                                object:nil
                                                              userInfo:@{
                DSChainManagerNotificationChainKey: self.chain,
                DSTransactionManagerNotificationTransactionKey: transaction,
                DSTransactionManagerNotificationTransactionChangesKey: @{DSTransactionManagerNotificationTransactionAcceptedStatusKey: @(NO)}
            }];
            [[NSNotificationCenter defaultCenter] postNotificationName:DSWalletBalanceDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey: self.chain}];
#if TARGET_OS_IOS
#if DEBUG
            UIAlertController *alert = [UIAlertController
                alertControllerWithTitle:@"Transaction rejected"
                                 message:[NSString stringWithFormat:@"Rejected by %@:%d with code 0x%x", peer.host, peer.port, code]
                          preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *okButton = [UIAlertAction
                actionWithTitle:@"OK"
                          style:UIAlertActionStyleCancel
                        handler:^(UIAlertAction *action){
                        }];
            [alert addAction:okButton];
            [[self presentingViewController] presentViewController:alert animated:YES completion:nil];
#endif
#endif
        });
    }

    [self.txRequests[hash] removeObject:peer];

    // if we get rejected for any reason other than double-spend, the peer is likely misconfigured
    if (code != REJECT_SPENT) {
        BOOL sentSomething = FALSE;
        for (DSAccount *account in accounts) {
            sentSomething |= ([account amountSentByTransaction:transaction] > 0);
        }
        if (sentSomething) {
            for (DSTransactionInput *input in transaction.inputs) { // check that all inputs are confirmed before dropping peer
                if ([self.chain transactionForHash:input.inputHash].blockHeight == TX_UNCONFIRMED)
                    return;
            }
            [self.peerManager peerMisbehaving:peer
                                 errorMessage:@"Peer rejected the transaction"];
        }
    }
}

// MARK: Instant Send

- (void)peer:(DSPeer *)peer hasInstantSendLockHashes:(NSOrderedSet *)instantSendLockHashes {
}

- (void)peer:(DSPeer *)peer hasInstantSendLockDHashes:(NSOrderedSet *)instantSendLockDHashes {
}

- (void)peer:(DSPeer *)peer hasChainLockHashes:(NSOrderedSet *)chainLockHashes {
}

- (void)peer:(DSPeer *)peer relayedInstantSendTransactionLock:(DSInstantSendTransactionLock *)instantSendTransactionLock {
    //NSValue *transactionHashValue = uint256_obj(instantSendTransactionLock.transactionHash);
    DSTransaction *transaction = nil;
    DSWallet *wallet = nil;
    DSAccount *account = [self.chain firstAccountForTransactionHash:instantSendTransactionLock.transactionHash transaction:&transaction wallet:&wallet];

    if (account && transaction && transaction.instantSendReceived) {
        return; //no point to retrieve the instant send lock if we already have it
    }

    BOOL verified = [instantSendTransactionLock verifySignature];

#if DEBUG
    DSLogPrivate(@"[%@: %@:%d] relayed instant send transaction lock %@ %@", self.chain.name, peer.host, peer.port, verified ? @"Verified" : @"Not Verified", uint256_reverse_hex(instantSendTransactionLock.transactionHash));
#else
    DSLog(@"[%@: %@:%d] relayed instant send transaction lock %@ %@", self.chain.name, peer.host, peer.port, verified ? @"Verified" : @"Not Verified", @"<REDACTED>");
#endif


    if (account && transaction) {
        [transaction setInstantSendReceivedWithInstantSendLock:instantSendTransactionLock];
        [instantSendTransactionLock saveInitial];
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSTransactionManagerTransactionStatusDidChangeNotification
                                                                object:nil
                                                              userInfo:@{DSChainManagerNotificationChainKey: self.chain,
                                                                  DSTransactionManagerNotificationTransactionKey: transaction,
                                                                  DSTransactionManagerNotificationTransactionChangesKey: @{DSTransactionManagerNotificationInstantSendTransactionLockKey: instantSendTransactionLock, DSTransactionManagerNotificationInstantSendTransactionLockVerifiedKey: @(verified)}}];
        });
    } else {
        [self.instantSendLocksWaitingForTransactions setObject:instantSendTransactionLock forKey:uint256_data(instantSendTransactionLock.transactionHash)];
    }

    if (!verified && !instantSendTransactionLock.intendedQuorumPublicKey) {
        //the quorum hasn't been retrieved yet
        [self.instantSendLocksWaitingForQuorums setObject:instantSendTransactionLock forKey:uint256_data(instantSendTransactionLock.transactionHash)];
    }
}

- (void)checkInstantSendLocksWaitingForQuorums {
    DSLog(@"[%@] Checking InstantSendLocks Waiting For Quorums", self.chain.name);
    for (NSData *transactionHashData in [self.instantSendLocksWaitingForQuorums copy]) {
        if (self.instantSendLocksWaitingForTransactions[transactionHashData]) continue;
        DSInstantSendTransactionLock *instantSendTransactionLock = self.instantSendLocksWaitingForQuorums[transactionHashData];
        BOOL verified = [instantSendTransactionLock verifySignature];
        if (verified) {
            DSLogPrivate(@"[%@] Verified %@", self.chain.name, instantSendTransactionLock);
            [instantSendTransactionLock saveSignatureValid];
            DSTransaction *transaction = nil;
            DSWallet *wallet = nil;
            DSAccount *account = [self.chain firstAccountForTransactionHash:instantSendTransactionLock.transactionHash transaction:&transaction wallet:&wallet];

            if (account && transaction) {
                [transaction setInstantSendReceivedWithInstantSendLock:instantSendTransactionLock];
            }
            [self.instantSendLocksWaitingForQuorums removeObjectForKey:uint256_data(instantSendTransactionLock.transactionHash)];
            if (account && transaction) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:DSTransactionManagerTransactionStatusDidChangeNotification
                                                                        object:nil
                                                                      userInfo:@{DSChainManagerNotificationChainKey: self.chain,
                                                                          DSTransactionManagerNotificationTransactionKey: transaction,
                                                                          DSTransactionManagerNotificationTransactionChangesKey: @{DSTransactionManagerNotificationInstantSendTransactionLockKey: instantSendTransactionLock, DSTransactionManagerNotificationInstantSendTransactionLockVerifiedKey: @(verified)}}];
                });
            }
        } else {
            DSTransaction *transaction = nil;
            DSWallet *wallet = nil;
            DSAccount *account = [self.chain firstAccountForTransactionHash:instantSendTransactionLock.transactionHash transaction:&transaction wallet:&wallet];

            // Either there is no account or no transaction that means the transaction was not meant for our wallet or the transaction is confirmed
            // Which means the instant send lock no longer needs verification.
            if (!account || !transaction || transaction.confirmed) {
                [self.instantSendLocksWaitingForQuorums removeObjectForKey:uint256_data(instantSendTransactionLock.transactionHash)];
            }
//#if DEBUG
//            DSMasternodeList *masternodeList = nil;
//            DSQuorumEntry *quorum = [instantSendTransactionLock findSigningQuorumReturnMasternodeList:&masternodeList];
//            if (quorum && masternodeList) {
//                NSArray<DSQuorumEntry *> *quorumEntries = [masternodeList quorumEntriesRankedForInstantSendRequestID:[instantSendTransactionLock requestID]];
//                NSUInteger index = [quorumEntries indexOfObject:quorum];
//                DSLog(@"[%@] Quorum %@ found at index %lu for masternodeList at height %lu", self.chain.name, quorum, (unsigned long)index, (unsigned long)masternodeList.height);
//                DSLog(@"[%@] Quorum entries are %@", self.chain.name, quorumEntries);
//            }
//            DSLog(@"[%@] Could not verify %@", self.chain.name, instantSendTransactionLock);
//#endif
        }
    }
}


// MARK: Blocks

- (void)peer:(DSPeer *)peer relayedHeader:(DSMerkleBlock *)block {
    //DSLogPrivate(@"relayed block %@ total transactions %d %u",uint256_hex(block.blockHash), block.totalTransactions,block.timestamp);
    // ignore block headers that are newer than 2 days before earliestKeyTime (headers have 0 totalTransactions)
    if (!self.chain.needsInitialTerminalHeadersSync &&
        (self.chain.earliestWalletCreationTime < block.timestamp + DAY_TIME_INTERVAL * 2) &&
        !self.chainManager.chainSynchronizationFingerprint) {
        DSLog(@"[%@: %@:%d] ignoring header %@", self.chain.name, peer.host, peer.port, uint256_hex(block.blockHash));
        return;
    }

    if (peer == self.peerManager.downloadPeer) [self.chainManager relayedNewItem];

    [self.chain addBlock:block receivedAsHeader:YES fromPeer:peer];
}

- (void)peer:(DSPeer *)peer relayedBlock:(DSMerkleBlock *)block {
    if (!self.chainManager.syncPhase) {
        DSLog(@"[%@: %@:%d] Block was received after reset, ignoring it", self.chain.name, peer.host, peer.port);
        return;
    }
    //DSLog(@"relayed block %@ total transactions %d %u",uint256_hex(block.blockHash), block.totalTransactions,block.timestamp);
    // ignore block headers that are newer than 2 days before earliestKeyTime (headers have 0 totalTransactions)
    if (block.totalTransactions == 0 &&
        block.timestamp + DAY_TIME_INTERVAL * 2 > self.chain.earliestWalletCreationTime) {
        DSLog(@"[%@: %@:%d] ignoring block %@", self.chain.name, peer.host, peer.port, uint256_hex(block.blockHash));
        return;
    }

    NSArray *txHashes = block.transactionHashes;

    // track the observed bloom filter false positive rate using a low pass filter to smooth out variance
    if (peer == self.peerManager.downloadPeer && block.transactionHashes.count > 0) {
        NSMutableSet *falsePositives = [NSMutableSet setWithArray:txHashes];

        // 1% low pass filter, also weights each block by total transactions, using 2800 tx per block as typical
        [falsePositives minusSet:self.nonFalsePositiveTransactions]; // wallet tx are not false-positives
        [self.nonFalsePositiveTransactions removeAllObjects];
        self.transactionsBloomFilterFalsePositiveRate = self.transactionsBloomFilterFalsePositiveRate * (1.0 - 0.01 * block.totalTransactions / 2800) + 0.01 * falsePositives.count / 2800;

        // false positive rate sanity check
        if (self.peerManager.downloadPeer.status == DSPeerStatus_Connected && self.transactionsBloomFilterFalsePositiveRate > BLOOM_DEFAULT_FALSEPOSITIVE_RATE * 10.0) {
            DSLog(@"[%@: %@:%d] bloom filter false positive rate %f too high after %d blocks, disconnecting...", self.chain.name, peer.host,
                peer.port, self.transactionsBloomFilterFalsePositiveRate, self.chain.lastSyncBlockHeight + 1 - self.filterUpdateHeight);
            [self.peerManager.downloadPeer disconnect];
        } else if (self.chain.lastSyncBlockHeight + 500 < peer.lastBlockHeight && self.transactionsBloomFilterFalsePositiveRate > BLOOM_REDUCED_FALSEPOSITIVE_RATE * 10.0) {
            DSLog(@"[%@: %@:%d] bloom filter false positive rate %f too high after %d blocks, rebuilding", self.chain.name, peer.host,
                peer.port, self.transactionsBloomFilterFalsePositiveRate, self.chain.lastSyncBlockHeight + 1 - self.filterUpdateHeight);
            [self updateTransactionsBloomFilter]; // rebuild bloom filter when it starts to degrade
        }
    }

    if (peer == self.peerManager.downloadPeer) [self.chainManager relayedNewItem];

    if (!_bloomFilter) { // ignore potentially incomplete blocks when a filter update is pending
        DSLog(@"[%@: %@:%d] ignoring block due to filter update %@", self.chain.name, peer.host, peer.port, uint256_hex(block.blockHash));
        return;
    }

#if !SAVE_MAX_TRANSACTIONS_INFO
    [self.chain addBlock:block receivedAsHeader:NO fromPeer:peer];
#else
    if ([self.chain addBlock:block isHeaderOnly:NO fromPeer:peer]) {
        if (block.height == self.chain.lastSyncBlockHeight) {
            [self.totalTransactionsQueue addObject:@(block.totalTransactions)];
            self.totalTransactionsSum += block.totalTransactions;
            if (block.totalTransactions >= self.totalTransactionsMax) {
                //NSLog(@"max is %d at %d",block.totalTransactions,block.height);
                self.totalTransactionsMax = block.totalTransactions;
                self.totalTransactionsMaxLastPosition = block.height;
            }
            if (self.totalTransactionsQueue.count > MAX_TOTAL_TRANSACTIONS_FOR_BLOOM_FILTER_RETARGETING) {
                self.totalTransactionsSum -= [[self.totalTransactionsQueue objectAtIndex:0] unsignedIntValue];
                [self.totalTransactionsQueue removeObjectAtIndex:0];
                if (self.totalTransactionsMaxLastPosition == block.height - MAX_TOTAL_TRANSACTIONS_FOR_BLOOM_FILTER_RETARGETING - 1) {
                    //NSLog(@"researching max at %d",block.height);
                    //we must find MAX again
                    uint32_t maxPosition = 0;
                    uint32_t max = 0;
                    for (uint32_t i = 0; i < self.totalTransactionsQueue.count; i++) {
                        if ([self.totalTransactionsQueue[i] intValue] > max) {
                            maxPosition = i;
                            max = [self.totalTransactionsQueue[i] intValue];
                        }
                    }
                    self.totalTransactionsMax = max;
                    self.totalTransactionsMaxLastPosition = block.height - MAX_TOTAL_TRANSACTIONS_FOR_BLOOM_FILTER_RETARGETING + maxPosition + 1;
                }
            }
            if (self.totalTransactionsQueue.count == MAX_TOTAL_TRANSACTIONS_FOR_BLOOM_FILTER_RETARGETING && (block.height % 500) == 499) {
                [self.totalTransactionData appendUInt16:(block.height - 499) / 500];
                [self.totalTransactionData appendUInt16:self.totalTransactionsSum / self.totalTransactionsQueue.count];
                [self.totalTransactionData appendUInt16:self.totalTransactionsMax];
                DSLog(@"[%@: %@:%d] max total tx %d;%lu;%u", self.chain.name, peer.host, peer.port, block.height - 499, self.totalTransactionsSum / self.totalTransactionsQueue.count, self.totalTransactionsMax);
            }
            if (block.height == self.chain.lastTerminalBlockHeight) {
                NSString *fileName = [NSString stringWithFormat:@"MaxTransactionInfo_%@.dat", self.chain.name];
                [self.totalTransactionData saveToFile:fileName inDirectory:NSCachesDirectory];
            }
        }
    }
#endif
}

- (void)peer:(DSPeer *)peer relayedTooManyOrphanBlocks:(NSUInteger)orphanBlockCount {
    [self.peerManager peerMisbehaving:peer errorMessage:@"Too many orphan blocks"];
}

- (void)peer:(DSPeer *)peer relayedChainLock:(DSChainLock *)chainLock {
    BOOL verified = [chainLock verifySignature];

    DSLog(@"[%@: %@:%d] relayed chain lock %@", self.chain.name, peer.host, peer.port, uint256_reverse_hex(chainLock.blockHash));

    DSMerkleBlock *block = [self.chain blockForBlockHash:chainLock.blockHash];

    if (block) {
        [self.chain addChainLock:chainLock];
        // TODO: duplicate saving check occurs in chain.addChainLock
        [chainLock saveInitial];
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSChainBlockWasLockedNotification object:nil userInfo:@{DSChainManagerNotificationChainKey: self.chain, DSChainNotificationBlockKey: block}];
        });
    } else {
        [self.chainLocksWaitingForMerkleBlocks setObject:chainLock forKey:uint256_data(chainLock.blockHash)];
    }

    if (!verified && !chainLock.intendedQuorumPublicKey) {
        //the quorum hasn't been retrieved yet
        [self.chainLocksWaitingForQuorums setObject:chainLock forKey:uint256_data(chainLock.blockHash)];
    }
}

- (void)checkChainLocksWaitingForQuorums {
    DSLog(@"[%@] Checking ChainLocks Waiting For Quorums", self.chain.name);
    for (NSData *chainLockHashData in [self.chainLocksWaitingForQuorums copy]) {
        if (self.chainLocksWaitingForMerkleBlocks[chainLockHashData]) continue;
        DSChainLock *chainLock = self.chainLocksWaitingForQuorums[chainLockHashData];
        BOOL verified = [chainLock verifySignature];
        if (verified) {
            DSLog(@"[%@] Verified %@", self.chain.name, chainLock);
            [chainLock saveSignatureValid];
            DSMerkleBlock *block = [self.chain blockForBlockHash:chainLock.blockHash];
            [self.chainLocksWaitingForQuorums removeObjectForKey:chainLockHashData];
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:DSChainBlockWasLockedNotification
                                                                    object:nil
                                                                  userInfo:@{
                    DSChainManagerNotificationChainKey: self.chain,
                    DSChainNotificationBlockKey: block
                }];
            });
        } else {
//#if DEBUG_CHAIN_LOCKS_WAITING_FOR_QUORUMS
//            DSMasternodeList *masternodeList = nil;
//            DSQuorumEntry *quorum = [chainLock findSigningQuorumReturnMasternodeList:&masternodeList];
//            if (quorum && masternodeList) {
//                NSArray<DSQuorumEntry *> *quorumEntries = [masternodeList quorumEntriesRankedForInstantSendRequestID:[chainLock requestID]];
//                NSUInteger index = [quorumEntries indexOfObject:quorum];
//                DSLog(@"[%@] Quorum %@ found at index %lu for masternodeList at height %lu", self.chain.name, quorum, (unsigned long)index, (unsigned long)masternodeList.height);
//                DSLog(@"[%@] Quorum entries are %@", self.chain.name, quorumEntries);
//            }
//            DSLog(@"[%@] Could not verify %@", self.chain.name, chainLock);
//#endif
        }
    }
}

// MARK: Fees

- (void)peer:(DSPeer *)peer setFeePerByte:(uint64_t)feePerKb {
    uint64_t maxFeePerByte = 0, secondFeePerByte = 0;

    for (DSPeer *p in self.peerManager.connectedPeers) { // find second highest fee rate
        if (p.status != DSPeerStatus_Connected) continue;
        if (p.feePerByte > maxFeePerByte) secondFeePerByte = maxFeePerByte, maxFeePerByte = p.feePerByte;
    }

    if (secondFeePerByte * 2 > MIN_FEE_PER_B && secondFeePerByte * 2 <= MAX_FEE_PER_B &&
        secondFeePerByte * 2 > self.chain.feePerByte) {
        DSLog(@"[%@] increasing feePerKb to %llu based on feefilter messages from peers", self.chain.name, secondFeePerByte * 2);
        self.chain.feePerByte = secondFeePerByte * 2;
    }
}

- (void)checkWaitingForQuorums {
    [self checkInstantSendLocksWaitingForQuorums];
    [self checkChainLocksWaitingForQuorums];
}

- (DSChainLock * _Nullable)chainLockForBlockHash:(UInt256)blockHash {
    DSChainLock *chainLock = [self.chainLocksWaitingForQuorums objectForKey:uint256_data(blockHash)];
    return chainLock;
}

@end
