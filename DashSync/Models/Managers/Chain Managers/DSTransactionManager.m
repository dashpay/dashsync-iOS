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
#import "DSTransaction.h"
#import "DSChain.h"
#import "DSEventManager.h"
#import "DSPeerManager+Protected.h"
#import "DSChainManager+Protected.h"
#import "DSWallet.h"
#import "DSAccount.h"
#import "NSDate+Utils.h"
#import "DSTransactionEntity+CoreDataClass.h"
#import "NSManagedObject+Sugar.h"
#import "DSMerkleBlock.h"
#import "DSBloomFilter.h"
#import "NSString+Bitcoin.h"
#import "DSOptionsManager.h"
#import "DSPaymentRequest.h"
#import "DSPaymentProtocol.h"
#import "UIWindow+DSUtils.h"
#import "DSAuthenticationManager.h"
#import "DSPriceManager.h"
#import "DSTransactionHashEntity+CoreDataClass.h"
#import "DSTransactionLockVote.h"
#import "DSMasternodeManager+Protected.h"
#import "DSSpecialTransactionsWalletHolder.h"
#import "NSString+Dash.h"
#import "NSMutableData+Dash.h"
#import "DSTransition.h"

#define IX_INPUT_LOCKED_KEY @"IX_INPUT_LOCKED_KEY"

@interface DSTransactionManager()

@property (nonatomic, strong) NSMutableDictionary *txRelays, *txRequests;
@property (nonatomic, strong) NSMutableDictionary *publishedTx, *publishedCallback;
@property (nonatomic, strong) NSMutableDictionary *transactionLockVoteDictionary;
@property (nonatomic, strong) NSMutableSet *nonFalsePositiveTransactions;
@property (nonatomic, strong) DSBloomFilter *bloomFilter;
@property (nonatomic, assign) uint32_t filterUpdateHeight;
@property (nonatomic, assign) double transactionsBloomFilterFalsePositiveRate;
@property (nonatomic, readonly) DSMasternodeManager * masternodeManager;
@property (nonatomic, readonly) DSPeerManager * peerManager;
@property (nonatomic, readonly) DSChainManager * chainManager;
@property (nonatomic, strong) NSMutableArray * removeUnrelayedTransactionsLocalRequests;

@end

@implementation DSTransactionManager

- (instancetype)initWithChain:(id)chain
{
    if (! (self = [super init])) return nil;
    _chain = chain;
    self.txRelays = [NSMutableDictionary dictionary];
    self.txRequests = [NSMutableDictionary dictionary];
    self.publishedTx = [NSMutableDictionary dictionary];
    self.publishedCallback = [NSMutableDictionary dictionary];
    self.nonFalsePositiveTransactions = [NSMutableSet set];
    self.transactionLockVoteDictionary = [NSMutableDictionary dictionary];
    self.removeUnrelayedTransactionsLocalRequests = [NSMutableArray array];
    [self recreatePublishedTransactionList];
    return self;
}

// MARK: - Managers

-(DSPeerManager*)peerManager {
    return self.chain.chainManager.peerManager;
}

-(DSMasternodeManager*)masternodeManager {
    return self.chain.chainManager.masternodeManager;
}

-(DSChainManager*)chainManager {
    return self.chain.chainManager;
}

// MARK: - Helpers

-(UIViewController *)presentingViewController {
    return [[[UIApplication sharedApplication] keyWindow] ds_presentingViewController];
}

// MARK: - Blockchain Transactions

// adds transaction to list of tx to be published, along with any unconfirmed inputs
- (void)addTransactionToPublishList:(DSTransaction *)transaction
{
    if (transaction.blockHeight == TX_UNCONFIRMED) {
        DSDLog(@"[DSTransactionManager] add transaction to publish list %@ (%@)", transaction,transaction.toData);
        self.publishedTx[uint256_obj(transaction.txHash)] = transaction;
        
        for (NSValue *hash in transaction.inputHashes) {
            UInt256 h = UINT256_ZERO;
            
            [hash getValue:&h];
            [self addTransactionToPublishList:[self.chain transactionForHash:h]];
        }
    }
}

- (void)publishTransaction:(DSTransaction *)transaction completion:(void (^)(NSError *error))completion
{
    DSDLog(@"[DSTransactionManager] publish transaction %@ %@", transaction,transaction.toData);
    if ([transaction transactionTypeRequiresInputs] && !transaction.isSigned) {
        if (completion) {
            [[DSEventManager sharedEventManager] saveEvent:@"transaction_manager:not_signed"];
            completion([NSError errorWithDomain:@"DashSync" code:401 userInfo:@{NSLocalizedDescriptionKey:
                                                                                    DSLocalizedString(@"dash transaction not signed", nil)}]);
        }
        
        return;
    }
    else if (! self.peerManager.connected && self.peerManager.connectFailures >= MAX_CONNECT_FAILURES) {
        if (completion) {
            [[DSEventManager sharedEventManager] saveEvent:@"transaction_manager:not_connected"];
            completion([NSError errorWithDomain:@"DashSync" code:-1009 userInfo:@{NSLocalizedDescriptionKey:
                                                                                      DSLocalizedString(@"not connected to the dash network", nil)}]);
        }
        
        return;
    }
    
    NSMutableSet *peers = [NSMutableSet setWithSet:self.peerManager.connectedPeers];
    NSValue *hash = uint256_obj(transaction.txHash);
    
    [self addTransactionToPublishList:transaction];
    if (completion) self.publishedCallback[hash] = completion;
    
    NSArray *txHashes = self.publishedTx.allKeys;
    
    // instead of publishing to all peers, leave out the download peer to see if the tx propogates and gets relayed back
    // TODO: XXX connect to a random peer with an empty or fake bloom filter just for publishing
    if (self.peerManager.connectedPeerCount > 1 && self.peerManager.downloadPeer) [peers removeObject:self.peerManager.downloadPeer];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self performSelector:@selector(txTimeout:) withObject:hash afterDelay:PROTOCOL_TIMEOUT];
        
        for (DSPeer *p in peers) {
            if (p.status != DSPeerStatus_Connected) continue;
            [p sendTransactionInvMessagesForTxHashes:txHashes txLockRequestHashes:nil];
            [p sendPingMessageWithPongHandler:^(BOOL success) {
                if (! success) return;
                
                for (NSValue *h in txHashes) {
                    if ([self.txRelays[h] containsObject:p] || [self.txRequests[h] containsObject:p]) continue;
                    if (! self.txRequests[h]) self.txRequests[h] = [NSMutableSet set];
                    [self.txRequests[h] addObject:p];
                    //todo: to get lock requests instead if sent that way
                    [p sendGetdataMessageWithTxHashes:@[h] txLockRequestHashes:nil txLockVoteHashes:nil blockHashes:nil];
                }
            }];
        }
    });
}

//This is used when re-entering app, the wallet needs to check all transactions that are in a publishing phase.
-(void)recreatePublishedTransactionList {
    for (DSWallet * wallet in self.chain.wallets) {
        for (DSTransaction *tx in wallet.allTransactions) { // find TXOs spent within the last 100 blocks
            [self addTransactionToPublishList:tx]; // also populate the tx publish list
        }
    }
}


// unconfirmed transactions that aren't in the mempools of any of connected peers have likely dropped off the network
- (void)removeUnrelayedTransactionsFromPeer:(DSPeer*)peer
{
    [self.removeUnrelayedTransactionsLocalRequests addObject:peer.location];
    // don't remove transactions until we're connected to maxConnectCount peers
    if (self.removeUnrelayedTransactionsLocalRequests.count < 2) {
        DSDLog(@"[DSTransactionManager] not removing unrelayed transactions until we have synced mempools from 2 peers %lu",(unsigned long)self.peerManager.connectedPeerCount);
        return;
    }
    
    for (DSPeer *p in self.peerManager.connectedPeers) { // don't remove tx until all peers have finished relaying their mempools
        DSDLog(@"[DSTransactionManager] not removing unrelayed transactions because %@ is not synced yet",p.host);
        if (! p.synced) return;
    }
    DSDLog(@"[DSTransactionManager] removing unrelayed transactions");
    NSMutableSet * transactionsSet = [NSMutableSet set];
    
    NSMutableArray * transactionsToBeRemoved = [NSMutableArray array];
    
    for (DSWallet * wallet in self.chain.wallets) {
        [transactionsSet addObjectsFromArray:[wallet.specialTransactionsHolder allTransactions]];
        for (DSAccount * account in wallet.accounts) {
            [transactionsSet addObjectsFromArray:account.allTransactions];
        }
    }
    
    BOOL rescan = NO, notify = NO;
    NSValue *hash;
    UInt256 h;
    
    for (DSTransaction *transaction in transactionsSet) {
        if (transaction.blockHeight != TX_UNCONFIRMED) continue;
        hash = uint256_obj(transaction.txHash);
        DSDLog(@"checking published callback -> %@", self.publishedCallback[hash]?@"OK":@"no callback");
        if (self.publishedCallback[hash] != NULL) continue;
        DSDLog(@"transaction relays count %lu, transaction requests count %lu",(unsigned long)[self.txRelays[hash] count],(unsigned long)[self.txRequests[hash] count]);
        DSAccount * account = [self.chain firstAccountThatCanContainTransaction:transaction];
        if (!account) {
            if (!self.chain.isDevnetAny || ![transaction isKindOfClass:[DSTransition class]]) {
                NSAssert(FALSE, @"This needs to be implemented for transitions, if you are here now is the time to do it.");
            }
            continue;
        }
        if ([self.txRelays[hash] count] == 0 && [self.txRequests[hash] count] == 0) {
            // if this is for a transaction we sent, and it wasn't already known to be invalid, notify user of failure
            if (! rescan && [account amountSentByTransaction:transaction] > 0 && [account transactionIsValid:transaction]) {
                DSDLog(@"failed transaction %@", transaction);
                rescan = notify = YES;
                
                for (NSValue *hash in transaction.inputHashes) { // only recommend a rescan if all inputs are confirmed
                    [hash getValue:&h];
                    if ([account transactionForHash:h].blockHeight != TX_UNCONFIRMED) continue;
                    rescan = NO;
                    break;
                }
            } else {
                DSDLog(@"serious issue in transaction %@", transaction);
            }
            DSDLog(@"removing transaction %@", transaction);
            [transactionsToBeRemoved addObject:transaction];
            
        }
        else if ([self.txRelays[hash] count] < self.peerManager.maxConnectCount) {
            // set timestamp 0 to mark as unverified
            DSDLog(@"setting transaction as unverified %@", transaction);
            [self.chain setBlockHeight:TX_UNCONFIRMED andTimestamp:0 forTxHashes:@[hash]];
        }
    }
    
    if (transactionsToBeRemoved.count) {
        for (DSTransaction * transaction in [transactionsToBeRemoved copy]) {
            NSArray * accounts = [self.chain accountsThatCanContainTransaction:transaction];
            for (DSAccount * account in accounts) {
                [account removeTransaction:transaction];
                
            }
        }
        [DSTransactionHashEntity saveContext];
    }
    
    [self.removeUnrelayedTransactionsLocalRequests removeAllObjects];
    
    if (notify) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (rescan) {
                [[DSEventManager sharedEventManager] saveEvent:@"transaction_manager:tx_rejected_rescan"];
                UIAlertController * alert = [UIAlertController
                                             alertControllerWithTitle:DSLocalizedString(@"transaction rejected", nil)
                                             message:DSLocalizedString(@"Your wallet may be out of sync.\n"
                                                                       "This can often be fixed by rescanning the blockchain.", nil)
                                             preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction* cancelButton = [UIAlertAction
                                               actionWithTitle:DSLocalizedString(@"ok", nil)
                                               style:UIAlertActionStyleCancel
                                               handler:^(UIAlertAction * action) {
                                               }];
                UIAlertAction* rescanButton = [UIAlertAction
                                               actionWithTitle:DSLocalizedString(@"rescan", nil)
                                               style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction * action) {
                                                   [self.chainManager rescan];
                                               }];
                [alert addAction:cancelButton];
                [alert addAction:rescanButton];
                [[self presentingViewController] presentViewController:alert animated:YES completion:nil];
                
            }
            else {
                [[DSEventManager sharedEventManager] saveEvent:@"transaction_manager_tx_rejected"];
                UIAlertController * alert = [UIAlertController
                                             alertControllerWithTitle:DSLocalizedString(@"transaction rejected", nil)
                                             message:@""
                                             preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction* okButton = [UIAlertAction
                                           actionWithTitle:DSLocalizedString(@"ok", nil)
                                           style:UIAlertActionStyleCancel
                                           handler:^(UIAlertAction * action) {
                                           }];
                [alert addAction:okButton];
                [[self presentingViewController] presentViewController:alert animated:YES completion:nil];
            }
        });
    }
}

// number of connected peers that have relayed the transaction
- (NSUInteger)relayCountForTransaction:(UInt256)txHash
{
    return [self.txRelays[uint256_obj(txHash)] count];
}

- (void)txTimeout:(NSValue *)txHash
{
    void (^callback)(NSError *error) = self.publishedCallback[txHash];
    
    [self.publishedTx removeObjectForKey:txHash];
    [self.publishedCallback removeObjectForKey:txHash];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(txTimeout:) object:txHash];
    
    if (callback) {
        [[DSEventManager sharedEventManager] saveEvent:@"transaction_manager:tx_canceled_timeout"];
        callback([NSError errorWithDomain:@"DashSync" code:DASH_PEER_TIMEOUT_CODE userInfo:@{NSLocalizedDescriptionKey:
                                                                                                 DSLocalizedString(@"transaction canceled, network timeout", nil)}]);
    }
}

- (void)clearTransactionRelaysForPeer:(DSPeer*)peer {
    for (NSValue *txHash in self.txRelays.allKeys) {
        [self.txRelays[txHash] removeObject:peer];
    }
}

// MARK: - Front end

- (void)confirmProtocolRequest:(DSPaymentProtocolRequest *)protoReq forAmount:(uint64_t)requestedAmount fromAccount:(DSAccount*)account addressIsFromPasteboard:(BOOL)addressIsFromPasteboard requestingAdditionalInfo:(DSTransactionCreationRequestingAdditionalInfoBlock)additionalInfoRequest presentChallenge:(DSTransactionChallengeBlock)challenge transactionCreationCompletion:(DSTransactionCreationCompletionBlock)transactionCreationCompletion signedCompletion:(DSTransactionSigningCompletionBlock)signedCompletion publishedCompletion:(DSTransactionPublishedCompletionBlock)publishedCompletion requestRelayCompletion:(DSTransactionRequestRelayCompletionBlock)requestRelayCompletion errorNotificationBlock:(DSTransactionErrorNotificationBlock)errorNotificationBlock {
    return [self confirmProtocolRequest:protoReq forAmount:requestedAmount fromAccount:account acceptReusingAddress:NO addressIsFromPasteboard:addressIsFromPasteboard acceptUncertifiedPayee:NO requestingAdditionalInfo:additionalInfoRequest presentChallenge:challenge transactionCreationCompletion:transactionCreationCompletion signedCompletion:signedCompletion publishedCompletion:publishedCompletion requestRelayCompletion:requestRelayCompletion errorNotificationBlock:errorNotificationBlock];
}

- (void)confirmProtocolRequest:(DSPaymentProtocolRequest *)protoReq forAmount:(uint64_t)requestedAmount fromAccount:(DSAccount*)account acceptReusingAddress:(BOOL)acceptReusingAddress addressIsFromPasteboard:(BOOL)addressIsFromPasteboard acceptUncertifiedPayee:(BOOL)acceptUncertifiedPayee requestingAdditionalInfo:(DSTransactionCreationRequestingAdditionalInfoBlock)additionalInfoRequest presentChallenge:(DSTransactionChallengeBlock)challenge transactionCreationCompletion:(DSTransactionCreationCompletionBlock)transactionCreationCompletion signedCompletion:(DSTransactionSigningCompletionBlock)signedCompletion publishedCompletion:(DSTransactionPublishedCompletionBlock)publishedCompletion requestRelayCompletion:(DSTransactionRequestRelayCompletionBlock)requestRelayCompletion errorNotificationBlock:(DSTransactionErrorNotificationBlock)errorNotificationBlock
{
    DSChain * chain = account.wallet.chain;
    DSWallet * wallet = account.wallet;
    DSPriceManager * priceManager = [DSPriceManager sharedInstance];
    DSTransaction *tx = nil;
    uint64_t amount = 0, fee = 0;
    BOOL valid = protoReq.isValid, outputTooSmall = NO;
    
    BOOL requestsInstantSend = protoReq.requestsInstantSend;
    
    if (! valid && [protoReq.errorMessage isEqual:DSLocalizedString(@"request expired", nil)]) {
        errorNotificationBlock(DSLocalizedString(@"bad payment request", nil),protoReq.errorMessage,YES);
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
    }
    else amount = requestedAmount;
    
    
    NSString *address = [NSString addressWithScriptPubKey:protoReq.details.outputScripts.firstObject onChain:chain];
    if ([wallet accountsBaseDerivationPathsContainAddress:address]) {
        errorNotificationBlock(@"",DSLocalizedString(@"this payment address is already in your wallet", nil),YES);
        return;
    }
    else if ((amount == 0 || amount == UINT64_MAX) && !acceptReusingAddress && [wallet transactionAddressAlreadySeenInOutputs:address] && addressIsFromPasteboard) {
        NSString * challengeTitle = DSLocalizedString(@"WARNING", nil);
        NSString * challengeMessage = DSLocalizedString(@"\nADDRESS ALREADY USED\ndash addresses are intended for single use only\n\n"
                                                        "re-use reduces privacy for both you and the recipient and can result in loss if "
                                                        "the recipient doesn't directly control the address", nil);
        NSString * challengeAction = DSLocalizedString(@"ignore", nil);
        challenge(challengeTitle,challengeMessage,challengeAction,^{[self confirmProtocolRequest:protoReq forAmount:requestedAmount fromAccount:account acceptReusingAddress:YES addressIsFromPasteboard:addressIsFromPasteboard acceptUncertifiedPayee:acceptUncertifiedPayee requestingAdditionalInfo:additionalInfoRequest presentChallenge:challenge transactionCreationCompletion:transactionCreationCompletion signedCompletion:signedCompletion publishedCompletion:publishedCompletion requestRelayCompletion:requestRelayCompletion errorNotificationBlock:errorNotificationBlock];}, ^{additionalInfoRequest(DSRequestingAdditionalInfo_CancelOrChangeAmount);});
        return;
    } else if (protoReq.errorMessage.length > 0 && protoReq.commonName.length > 0 &&
               !acceptUncertifiedPayee) {
        NSString * challengeTitle = DSLocalizedString(@"payee identity isn't certified", nil);
        NSString * challengeMessage = protoReq.errorMessage;
        NSString * challengeAction = DSLocalizedString(@"ignore", nil);
        challenge(challengeTitle,challengeMessage,challengeAction,^{[self confirmProtocolRequest:protoReq forAmount:requestedAmount fromAccount:account acceptReusingAddress:acceptReusingAddress addressIsFromPasteboard:addressIsFromPasteboard acceptUncertifiedPayee:YES requestingAdditionalInfo:additionalInfoRequest presentChallenge:challenge transactionCreationCompletion:transactionCreationCompletion signedCompletion:signedCompletion publishedCompletion:publishedCompletion requestRelayCompletion:requestRelayCompletion errorNotificationBlock:errorNotificationBlock];}, ^{additionalInfoRequest(DSRequestingAdditionalInfo_CancelOrChangeAmount);});
        
        return;
    }
    else if (amount == 0 || amount == UINT64_MAX) {
        additionalInfoRequest(DSRequestingAdditionalInfo_Amount);
        return;
    }
    else if (amount < TX_MIN_OUTPUT_AMOUNT) {
        errorNotificationBlock(DSLocalizedString(@"couldn't make payment", nil),[NSString stringWithFormat:DSLocalizedString(@"dash payments can't be less than %@", nil),
                                                                                 [priceManager stringForDashAmount:TX_MIN_OUTPUT_AMOUNT]],YES);
        return;
    }
    else if (outputTooSmall) {
        errorNotificationBlock(DSLocalizedString(@"couldn't make payment", nil),[NSString stringWithFormat:DSLocalizedString(@"dash transaction outputs can't be less than %@",
                                                                                                                             nil), [priceManager stringForDashAmount:TX_MIN_OUTPUT_AMOUNT]],YES);
        return;
    }
    
    if (requestedAmount == 0) {
        tx = [account transactionForAmounts:protoReq.details.outputAmounts
                            toOutputScripts:protoReq.details.outputScripts withFee:YES isInstant:requestsInstantSend];
    }
    else if (amount <= account.balance) {
        tx = [account transactionForAmounts:@[@(requestedAmount)]
                            toOutputScripts:@[protoReq.details.outputScripts.firstObject] withFee:YES isInstant:requestsInstantSend];
    }
    
    if (tx) {
        amount = [account amountSentByTransaction:tx] - [account amountReceivedFromTransaction:tx]; //safeguard
        fee = [account feeForTransaction:tx];
    }
    else {
        DSTransaction * tempTx = [account transactionFor:account.balance
                                                      to:address withFee:NO];
        uint8_t additionalInputs = (((account.balance - amount) % 1024) >> 8); //get a random amount of additional inputs between 0 and 3, we don't use last bits because they are often 0
        fee = [chain feeForTxSize:tempTx.size + TX_INPUT_SIZE*additionalInputs isInstant:requestsInstantSend inputCount:tempTx.inputHashes.count + additionalInputs];
        amount += fee; // pretty much a random fee
    }
    
    for (NSData *script in protoReq.details.outputScripts) {
        NSString *addr = [NSString addressWithScriptPubKey:script onChain:chain];
        
        if (! addr) addr = DSLocalizedString(@"unrecognized address", nil);
        if ([address rangeOfString:addr].location != NSNotFound) continue;
        address = [address stringByAppendingFormat:@"%@%@", (address.length > 0) ? @", " : @"", addr];
    }
    
    NSString *suggestedPrompt = [[DSAuthenticationManager sharedInstance] promptForAmount:amount
                                                                                      fee:fee
                                                                                  address:address
                                                                                     name:protoReq.commonName
                                                                                     memo:protoReq.details.memo
                                                                                 isSecure:(valid && ! [protoReq.pkiType isEqual:@"none"])
                                                                             errorMessage:@""
                                                                            localCurrency:protoReq.requestedFiatAmountCurrencyCode];
    if (transactionCreationCompletion(tx,suggestedPrompt,amount)) {
        CFRunLoopPerformBlock([[NSRunLoop mainRunLoop] getCFRunLoop], kCFRunLoopCommonModes, ^{
            [self signAndPublishTransaction:tx createdFromProtocolRequest:protoReq fromAccount:account toAddress:address withPrompt:suggestedPrompt forAmount:amount requestingAdditionalInfo:additionalInfoRequest presentChallenge:challenge transactionCreationCompletion:transactionCreationCompletion signedCompletion:signedCompletion publishedCompletion:publishedCompletion requestRelayCompletion:requestRelayCompletion errorNotificationBlock:errorNotificationBlock];
        });
    }
}


- (void)signAndPublishTransaction:(DSTransaction *)tx createdFromProtocolRequest:(DSPaymentProtocolRequest*)protocolRequest fromAccount:(DSAccount*)account toAddress:(NSString*)address withPrompt:(NSString *)prompt forAmount:(uint64_t)amount requestingAdditionalInfo:(DSTransactionCreationRequestingAdditionalInfoBlock)additionalInfoRequest presentChallenge:(DSTransactionChallengeBlock)challenge transactionCreationCompletion:(DSTransactionCreationCompletionBlock)transactionCreationCompletion signedCompletion:(DSTransactionSigningCompletionBlock)signedCompletion publishedCompletion:(DSTransactionPublishedCompletionBlock)publishedCompletion requestRelayCompletion:(DSTransactionRequestRelayCompletionBlock)requestRelayCompletion errorNotificationBlock:(DSTransactionErrorNotificationBlock)errorNotificationBlock
{
    DSAuthenticationManager *authenticationManager = [DSAuthenticationManager sharedInstance];
    __block BOOL previouslyWasAuthenticated = authenticationManager.didAuthenticate;
    
    if (! tx) { // tx is nil if there were insufficient wallet funds
        if (authenticationManager.didAuthenticate) {
            [self insufficientFundsForTransaction:tx createdFromProtocolRequest:protocolRequest fromAccount:account forAmount:amount toAddress:address requestingAdditionalInfo:additionalInfoRequest presentChallenge:challenge transactionCreationCompletion:transactionCreationCompletion signedCompletion:signedCompletion publishedCompletion:publishedCompletion requestRelayCompletion:requestRelayCompletion errorNotificationBlock:errorNotificationBlock];
        } else {
            [authenticationManager seedWithPrompt:prompt forWallet:account.wallet forAmount:amount forceAuthentication:NO completion:^(NSData * _Nullable seed, BOOL cancelled) {
                if (seed) {
                    [self insufficientFundsForTransaction:tx createdFromProtocolRequest:protocolRequest fromAccount:account forAmount:amount toAddress:address requestingAdditionalInfo:additionalInfoRequest presentChallenge:challenge transactionCreationCompletion:transactionCreationCompletion signedCompletion:signedCompletion publishedCompletion:publishedCompletion requestRelayCompletion:requestRelayCompletion errorNotificationBlock:errorNotificationBlock];
                } else {
                    additionalInfoRequest(DSRequestingAdditionalInfo_CancelOrChangeAmount);
                }
                if (!previouslyWasAuthenticated) [authenticationManager deauthenticate];
            }];
        }
    } else {
        [account signTransaction:tx withPrompt:prompt completion:^(BOOL signedTransaction, BOOL cancelled) {
            if (! previouslyWasAuthenticated) [authenticationManager deauthenticate];
            
            if (cancelled) return;
            
            if (!signedTransaction || ! tx.isSigned) {
                signedCompletion(tx,[NSError errorWithDomain:@"DashSync" code:401
                                                    userInfo:@{NSLocalizedDescriptionKey:DSLocalizedString(@"error signing dash transaction", nil)}],NO);
                return;
            }
            
            if (!signedCompletion(tx,nil,NO)) return; //give the option to stop the process to clients
            
            __block BOOL sent = NO;
            
            [self publishTransaction:tx completion:^(NSError *publishingError) {
                if (publishingError) {
                    if (!sent) {
                        publishedCompletion(tx,publishingError,sent);
                    }
                }
                else if (!sent) {
                    sent = YES;
                    tx.timestamp = [NSDate timeIntervalSince1970];
                    [account registerTransaction:tx];
                    publishedCompletion(tx,nil,sent);
                }
                
                if (protocolRequest.details.paymentURL.length > 0) {
                    uint64_t refundAmount = 0;
                    NSMutableData *refundScript = [NSMutableData data];
                    [refundScript appendScriptPubKeyForAddress:account.receiveAddress forChain:account.wallet.chain];
                    
                    for (NSNumber *amt in protocolRequest.details.outputAmounts) {
                        refundAmount += amt.unsignedLongLongValue;
                    }
                    
                    // TODO: keep track of commonName/memo to associate them with outputScripts
                    DSPaymentProtocolPayment *payment =
                    [[DSPaymentProtocolPayment alloc] initWithMerchantData:protocolRequest.details.merchantData
                                                              transactions:@[tx] refundToAmounts:@[@(refundAmount)] refundToScripts:@[refundScript] memo:nil onChain:account.wallet.chain];
                    
                    DSDLog(@"posting payment to: %@", protocolRequest.details.paymentURL);
                    
                    [DSPaymentRequest postPayment:payment scheme:@"dash" to:protocolRequest.details.paymentURL onChain:account.wallet.chain timeout:20.0
                                       completion:^(DSPaymentProtocolACK *ack, NSError *error) {
                                           dispatch_async(dispatch_get_main_queue(), ^{
                                               if (!publishingError && error) {
                                                   if (!sent) {
                                                       errorNotificationBlock([NSString stringWithFormat:DSLocalizedString(@"Error from payment request server %@",nil),protocolRequest.details.paymentURL],error.localizedDescription,YES);
                                                   }
                                               }
                                               else if (!sent) {
                                                   sent = TRUE;
                                                   tx.timestamp = [NSDate timeIntervalSince1970];
                                                   [account registerTransaction:tx];
                                               }
                                               requestRelayCompletion(tx,ack,!error);
                                               
                                           });
                                       }];
                }
            }];
        }];
    }
}

-(void)insufficientFundsForTransaction:(DSTransaction *)tx createdFromProtocolRequest:(DSPaymentProtocolRequest*)protocolRequest fromAccount:(DSAccount*)account forAmount:(uint64_t)requestedSendAmount toAddress:(NSString*)address requestingAdditionalInfo:(DSTransactionCreationRequestingAdditionalInfoBlock)additionalInfoRequest presentChallenge:(DSTransactionChallengeBlock)challenge transactionCreationCompletion:(DSTransactionCreationCompletionBlock)transactionCreationCompletion signedCompletion:(DSTransactionSigningCompletionBlock)signedCompletion publishedCompletion:(DSTransactionPublishedCompletionBlock)publishedCompletion  requestRelayCompletion:(DSTransactionRequestRelayCompletionBlock)requestRelayCompletion errorNotificationBlock:(DSTransactionErrorNotificationBlock)errorNotificationBlock {
    DSPriceManager * manager = [DSPriceManager sharedInstance];
    uint64_t fuzz = [manager amountForLocalCurrencyString:[manager localCurrencyStringForDashAmount:1]]*2;
    DSChain * chain = account.wallet.chain;
    if (requestedSendAmount <= account.balance && protocolRequest.requestsInstantSend && ([account maxOutputAmountWithConfirmationCount:chain.ixPreviousConfirmationsNeeded usingInstantSend:TRUE returnInputCount:nil] < requestedSendAmount)) {
        if (protocolRequest.requiresInstantSend) {
            NSString * challengeTitle = DSLocalizedString(@"instant payment", nil);
            NSString * challengeMessage = DSLocalizedString(@"This request requires an instant payment but you do not have enough inputs with 6 confirmations required by InstantSend, you may ask the merchant to accept a normal transaction or wait a few minutes.",
                                                            nil);
            void (^retryBlock) (void) = ^{
                
                [self confirmProtocolRequest:protocolRequest forAmount:requestedSendAmount fromAccount:account acceptReusingAddress:YES addressIsFromPasteboard:NO acceptUncertifiedPayee:YES requestingAdditionalInfo:additionalInfoRequest presentChallenge:challenge transactionCreationCompletion:transactionCreationCompletion signedCompletion:signedCompletion publishedCompletion:publishedCompletion requestRelayCompletion:requestRelayCompletion errorNotificationBlock:errorNotificationBlock];
                
            };
            challenge(challengeTitle,challengeMessage,DSLocalizedString(@"retry", nil),retryBlock,^{additionalInfoRequest(DSRequestingAdditionalInfo_CancelOrChangeAmount);});
        } else {
            NSString * challengeTitle = DSLocalizedString(@"instant payment", nil);
            NSString * challengeMessage = DSLocalizedString(@"InstantSend requires enough inputs with 6 confirmations, send anyways as regular transaction?",nil);
            
            void (^sendRegularBlock) (void) = ^{
                DSPaymentProtocolRequest * regularPaymentProtocolRequest = [[DSPaymentProtocolRequest alloc] initWithVersion:protocolRequest.version pkiType:protocolRequest.pkiType certs:protocolRequest.certs details:protocolRequest.details signature:protocolRequest.signature requestsInstantSend:NO requiresInstantSend:NO requestedAgainstFiatCurrency:protocolRequest.requestedFiatAmountCurrencyCode requestedFiatAmount:0 onChain:self.chain callbackScheme:protocolRequest.callbackScheme]; //we can put the requested fiat amount here to 0, as it was already calculated
                [self confirmProtocolRequest:regularPaymentProtocolRequest forAmount:requestedSendAmount fromAccount:account acceptReusingAddress:YES addressIsFromPasteboard:NO acceptUncertifiedPayee:YES requestingAdditionalInfo:additionalInfoRequest presentChallenge:challenge transactionCreationCompletion:transactionCreationCompletion signedCompletion:signedCompletion publishedCompletion:publishedCompletion requestRelayCompletion:requestRelayCompletion errorNotificationBlock:errorNotificationBlock];
                
            };
            
            challenge(challengeTitle,challengeMessage,DSLocalizedString(@"send", nil),sendRegularBlock,^{additionalInfoRequest(DSRequestingAdditionalInfo_CancelOrChangeAmount);});
            return;
        }
    } else if (requestedSendAmount <= account.balance + fuzz && requestedSendAmount > 0 && !protocolRequest.details.paymentURL) {
        // if user selected an amount equal to or below wallet balance, but the fee will bring the total above the
        // balance, offer to reduce the amount to available funds minus fee
        int64_t amount = [account maxOutputAmountUsingInstantSend:tx.desiresInstantSendSending];
        
        if (amount > 0 && amount < requestedSendAmount) {
            NSString * challengeTitle = DSLocalizedString(@"insufficient funds for dash network fee", nil);
            NSString * challengeMessage = [NSString stringWithFormat:DSLocalizedString(@"reduce payment amount by\n%@ (%@)?", nil),
                                           [manager stringForDashAmount:requestedSendAmount - amount],
                                           [manager localCurrencyStringForDashAmount:requestedSendAmount - amount]];
            
            NSString * reduceString = [NSString stringWithFormat:@"%@ (%@)",
                                       [manager stringForDashAmount:amount - requestedSendAmount],
                                       [manager localCurrencyStringForDashAmount:amount - requestedSendAmount]];
            
            void (^sendReducedBlock) (void) = ^{
                DSPaymentRequest * paymentRequest = [DSPaymentRequest requestWithString:address onChain:self.chain];
                paymentRequest.amount = amount;
                [self confirmProtocolRequest:paymentRequest.protocolRequest forAmount:amount fromAccount:account acceptReusingAddress:YES addressIsFromPasteboard:NO acceptUncertifiedPayee:YES requestingAdditionalInfo:additionalInfoRequest presentChallenge:challenge transactionCreationCompletion:transactionCreationCompletion signedCompletion:signedCompletion
                         publishedCompletion:publishedCompletion requestRelayCompletion:requestRelayCompletion errorNotificationBlock:errorNotificationBlock];
                
            };
            
            challenge(challengeTitle,challengeMessage,reduceString,sendReducedBlock,^{additionalInfoRequest(DSRequestingAdditionalInfo_CancelOrChangeAmount);});
        }
        else {
            errorNotificationBlock(DSLocalizedString(@"insufficient funds for dash network fee", nil),nil,NO);
        }
    }
    else {
        errorNotificationBlock(DSLocalizedString(@"insufficient funds", nil),nil,NO);
    }
}

- (void)confirmPaymentRequest:(DSPaymentRequest *)paymentRequest fromAccount:(DSAccount*)account acceptReusingAddress:(BOOL)acceptReusingAddress addressIsFromPasteboard:(BOOL)addressIsFromPasteboard requestingAdditionalInfo:(DSTransactionCreationRequestingAdditionalInfoBlock)additionalInfoRequest presentChallenge:(DSTransactionChallengeBlock)challenge transactionCreationCompletion:(DSTransactionCreationCompletionBlock)transactionCreationCompletion signedCompletion:(DSTransactionSigningCompletionBlock)signedCompletion publishedCompletion:(DSTransactionPublishedCompletionBlock)publishedCompletion errorNotificationBlock:(DSTransactionErrorNotificationBlock)errorNotificationBlock {
    DSPaymentProtocolRequest * protocolRequest = paymentRequest.protocolRequest;
    [self confirmProtocolRequest:protocolRequest forAmount:paymentRequest.amount fromAccount:account acceptReusingAddress:acceptReusingAddress addressIsFromPasteboard:addressIsFromPasteboard acceptUncertifiedPayee:NO requestingAdditionalInfo:additionalInfoRequest presentChallenge:challenge transactionCreationCompletion:transactionCreationCompletion signedCompletion:signedCompletion publishedCompletion:publishedCompletion requestRelayCompletion:nil errorNotificationBlock:errorNotificationBlock];
}


// MARK: - Mempools Sync

- (void)fetchMempoolFromPeer:(DSPeer*)peer {
    DSDLog(@"[DSTransactionManager] fetching mempool from peer %@",peer.host);
    if (peer.status != DSPeerStatus_Connected) return;
    
    if ([self.chain canConstructAFilter] && (peer != self.peerManager.downloadPeer || self.transactionsBloomFilterFalsePositiveRate > BLOOM_REDUCED_FALSEPOSITIVE_RATE*5.0)) {
        DSDLog(@"[DSTransactionManager] sending filterload message from peer %@",peer.host);
        [peer sendFilterloadMessage:[self transactionsBloomFilterForPeer:peer].data];
    }
    
    [peer sendInvMessageForHashes:self.publishedCallback.allKeys ofType:DSInvType_Tx]; // publish pending tx
    [peer sendPingMessageWithPongHandler:^(BOOL success) {
        if (success) {
            DSDLog(@"[DSTransactionManager] fetching mempool ping success peer %@",peer.host);
            [peer sendMempoolMessage:self.publishedTx.allKeys completion:^(BOOL success,BOOL needed,BOOL interruptedByDisconnect) {
                if (success) {
                    DSDLog(@"[DSTransactionManager] fetching mempool message success peer %@",peer.host);
                    peer.synced = YES;
                    [self removeUnrelayedTransactionsFromPeer:peer];
                    [peer sendGetaddrMessage]; // request a list of other dash peers
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[NSNotificationCenter defaultCenter]
                         postNotificationName:DSTransactionManagerTransactionStatusDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain}];
                    });
                } else {
                    if (!needed) {
                        DSDLog(@"[DSTransactionManager] fetching mempool message not needed peer %@",peer.host);
                    } else if (interruptedByDisconnect) {
                        DSDLog(@"[DSTransactionManager] fetching mempool message failure by disconnect peer %@",peer.host);
                    } else {
                        DSDLog(@"[DSTransactionManager] fetching mempool message failure peer %@",peer.host);
                    }
                    
                }
                
                if (peer == self.peerManager.downloadPeer) {
                    [self.peerManager syncStopped];
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[NSNotificationCenter defaultCenter]
                         postNotificationName:DSTransactionManagerSyncFinishedNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain}];
                    });
                }
            }];
        }
        else if (peer == self.peerManager.downloadPeer) {
            DSDLog(@"[DSTransactionManager] fetching mempool ping failure on download peer %@",peer.host);
            [self.peerManager syncStopped];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter]
                 postNotificationName:DSTransactionManagerSyncFinishedNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain}];
            });
        } else {
            DSDLog(@"[DSTransactionManager] fetching mempool ping failure on peer %@",peer.host);
        }
    }];
}

- (void)fetchMempoolFromNetwork
{
    // this can come from any queue
    if (!([[DSOptionsManager sharedInstance] syncType] & DSSyncType_Mempools)) return; // make sure we care about mempool
    for (DSPeer *peer in self.peerManager.connectedPeers) { // after syncing, load filters and get mempools from other peers
        [self fetchMempoolFromPeer:peer];
    }
}

// MARK: - TransactionFetching

- (void)fetchTransactionHavingHash:(UInt256)transactionHash {
    for (DSPeer *peer in self.peerManager.connectedPeers) {
        [peer sendGetdataMessageForTxHash:transactionHash];
    }
}

// MARK: - Bloom Filters

//This returns the bloom filter for the peer, currently the filter is only tweaked per peer, and we only cache the filter of the download peer.
//It makes sense to keep this in this class because it is not a property of the chain, but intead of a effemeral item used in the synchronization of the chain.
- (DSBloomFilter *)transactionsBloomFilterForPeer:(DSPeer *)peer
{
    self.filterUpdateHeight = self.chain.lastBlockHeight;
    self.transactionsBloomFilterFalsePositiveRate = BLOOM_REDUCED_FALSEPOSITIVE_RATE;
    
    
    // TODO: XXXX if already synced, recursively add inputs of unconfirmed receives
    _bloomFilter = [self.chain bloomFilterWithFalsePositiveRate:self.transactionsBloomFilterFalsePositiveRate withTweak:(uint32_t)peer.hash];
    return _bloomFilter;
}

-(void)updateTransactionsBloomFilter {
    if (! _bloomFilter) return; // bloom filter is aready being updated
    
    // the transaction likely consumed one or more wallet addresses, so check that at least the next <gap limit>
    // unused addresses are still matched by the bloom filter
    NSMutableArray *allAddressesArray = [NSMutableArray array];
    
    for (DSWallet * wallet in self.chain.wallets) {
        // every time a new wallet address is added, the bloom filter has to be rebuilt, and each address is only used for
        // one transaction, so here we generate some spare addresses to avoid rebuilding the filter each time a wallet
        // transaction is encountered during the blockchain download
        [wallet registerAddressesWithGapLimit:SEQUENCE_GAP_LIMIT_EXTERNAL internal:NO];
        [wallet registerAddressesWithGapLimit:SEQUENCE_GAP_LIMIT_INTERNAL internal:YES];
        NSSet *addresses = [wallet.allReceiveAddresses setByAddingObjectsFromSet:wallet.allChangeAddresses];
        [allAddressesArray addObjectsFromArray:[addresses allObjects]];
    }
    
    for (DSFundsDerivationPath * derivationPath in self.chain.standaloneDerivationPaths) {
        [derivationPath registerAddressesWithGapLimit:SEQUENCE_GAP_LIMIT_EXTERNAL internal:NO];
        [derivationPath registerAddressesWithGapLimit:SEQUENCE_GAP_LIMIT_INTERNAL internal:YES];
        NSArray *addresses = [derivationPath.allReceiveAddresses arrayByAddingObjectsFromArray:derivationPath.allChangeAddresses];
        [allAddressesArray addObjectsFromArray:addresses];
    }
    
    for (NSString *address in allAddressesArray) {
        NSData *hash = address.addressToHash160;
        
        if (! hash || [_bloomFilter containsData:hash]) continue;
        _bloomFilter = nil; // reset bloom filter so it's recreated with new wallet addresses
        [self.peerManager updateFilterOnPeers];
        break;
    }
}

- (void)clearTransactionsBloomFilter {
    self.bloomFilter = nil;
}

// MARK: - DSChainTransactionsDelegate

-(void)chain:(DSChain*)chain didSetBlockHeight:(int32_t)height andTimestamp:(NSTimeInterval)timestamp forTxHashes:(NSArray *)txHashes updatedTx:(NSArray *)updatedTx {
    if (height != TX_UNCONFIRMED) { // remove confirmed tx from publish list and relay counts
        [self.publishedTx removeObjectsForKeys:txHashes];
        [self.publishedCallback removeObjectsForKeys:txHashes];
        [self.txRelays removeObjectsForKeys:txHashes];
    }
}

-(void)chainWasWiped:(DSChain*)chain {
    [self.txRelays removeAllObjects];
    [self.publishedTx removeAllObjects];
    [self.publishedCallback removeAllObjects];
    _bloomFilter = nil;
}

// MARK: - DSPeerTransactionsDelegate

// MARK: Outgoing Transactions

//The peer is requesting a transaction that it does not know about that we are publishing
- (DSTransaction *)peer:(DSPeer *)peer requestedTransaction:(UInt256)txHash
{
    NSValue *hash = uint256_obj(txHash);
    DSDLog(@"Peer requested transaction with hash %@",hash);
    DSTransaction *transaction = self.publishedTx[hash];
    BOOL transactionIsPublished = !!transaction;
    DSAccount * account = [self.chain firstAccountThatCanContainTransaction:transaction];
    if (transactionIsPublished) {
        account = [self.chain firstAccountThatCanContainTransaction:transaction];
        if (!account) {
            account = [self.chain accountForTransactionHash:txHash transaction:nil wallet:nil];
        }
    } else {
        account = [self.chain accountForTransactionHash:txHash transaction:&transaction wallet:nil];
    }
    if (!account) {
        DSDLog(@"No transaction could be found on any account for hash %@",hash);
        return nil;
    }
    void (^callback)(NSError *error) = self.publishedCallback[hash];
    NSError *error = nil;
    
    if (! self.txRelays[hash]) self.txRelays[hash] = [NSMutableSet set];
    [self.txRelays[hash] addObject:peer];
    [self.nonFalsePositiveTransactions addObject:hash];
    [self.publishedCallback removeObjectForKey:hash];
    
    if (callback && ![account transactionIsValid:transaction]) {
        [self.publishedTx removeObjectForKey:hash];
        error = [NSError errorWithDomain:@"DashSync" code:401
                                userInfo:@{NSLocalizedDescriptionKey:DSLocalizedString(@"double spend", nil)}];
    }
    else if (transaction && ![account transactionForHash:txHash] && [account registerTransaction:transaction]) {
        [[DSTransactionEntity context] performBlock:^{
            [DSTransactionEntity saveContext]; // persist transactions to core data
        }];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(txTimeout:) object:hash];
        if (callback) callback(error);
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
- (void)peer:(DSPeer *)peer hasTransaction:(UInt256)txHash transactionIsRequestingInstantSendLock:(BOOL)transactionIsRequestingInstantSendLock;
{
    NSValue *hash = uint256_obj(txHash);
    BOOL syncing = (self.chain.lastBlockHeight < self.chain.estimatedBlockHeight);
    DSTransaction *transaction = self.publishedTx[hash];
    void (^callback)(NSError *error) = self.publishedCallback[hash];
    
    DSDLog(@"%@:%d has %@ transaction %@", peer.host, peer.port, transactionIsRequestingInstantSendLock?@"IX":@"TX", hash);
    if (!transaction) transaction = [self.chain transactionForHash:txHash];
    if (!transaction) {
        DSDLog(@"No transaction found on chain for this transaction");
        return;
    }
    DSAccount * account = [self.chain firstAccountThatCanContainTransaction:transaction];
    if (syncing && !account) {
        DSDLog(@"No account found for this transaction");
        return;
    }
    if (![account registerTransaction:transaction]) return;
    if (peer == self.peerManager.downloadPeer) [self.chainManager relayedNewItem];
    // keep track of how many peers have or relay a tx, this indicates how likely the tx is to confirm
    if (callback || (! syncing && ! [self.txRelays[hash] containsObject:peer])) {
        if (! self.txRelays[hash]) self.txRelays[hash] = [NSMutableSet set];
        [self.txRelays[hash] addObject:peer];
        if (callback) [self.publishedCallback removeObjectForKey:hash];
        
        if ([self.txRelays[hash] count] >= self.peerManager.maxConnectCount &&
            [self.chain transactionForHash:txHash].blockHeight == TX_UNCONFIRMED &&
            [self.chain transactionForHash:txHash].timestamp == 0) {
            [self.chain setBlockHeight:TX_UNCONFIRMED andTimestamp:[NSDate timeIntervalSince1970]
                           forTxHashes:@[hash]]; // set timestamp when tx is verified
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(txTimeout:) object:hash];
            [[NSNotificationCenter defaultCenter] postNotificationName:DSTransactionManagerTransactionStatusDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain}];
            if (callback) callback(nil);
        });
    }
    
    [self.nonFalsePositiveTransactions addObject:hash];
    [self.txRequests[hash] removeObject:peer];
}

//The peer has sent us a transaction we are interested in and that we did not send ourselves
- (void)peer:(DSPeer *)peer relayedTransaction:(DSTransaction *)transaction transactionIsRequestingInstantSendLock:(BOOL)transactionIsRequestingInstantSendLock
{
    NSValue *hash = uint256_obj(transaction.txHash);
    BOOL syncing = (self.chain.lastBlockHeight < self.chain.estimatedBlockHeight);
    void (^callback)(NSError *error) = self.publishedCallback[hash];
    
    DSDLog(@"%@:%d relayed transaction %@", peer.host, peer.port, hash);
    
    transaction.timestamp = [NSDate timeIntervalSince1970];
    DSAccount * account = [self.chain firstAccountThatCanContainTransaction:transaction];
    if (!account) {
        DSDLog(@"%@:%d no account for transaction %@", peer.host, peer.port, hash);
        if (![self.chain transactionHasLocalReferences:transaction]) return;
    } else {
        if (![account registerTransaction:transaction]) return;
    }
    
    if (![transaction isMemberOfClass:[DSTransaction class]]) {
        //it's a special transaction
        [self.chain registerSpecialTransaction:transaction];
        
        [self.chain triggerUpdatesForLocalReferences:transaction];
    }
    
    if (peer == self.peerManager.downloadPeer) [self.chainManager relayedNewItem];
    
    
    if (account && [account amountSentByTransaction:transaction] > 0 && [account transactionIsValid:transaction]) {
        [self addTransactionToPublishList:transaction]; // add valid send tx to mempool
    }
    
    // keep track of how many peers have or relay a tx, this indicates how likely the tx is to confirm
    if (callback || (!syncing && ! [self.txRelays[hash] containsObject:peer])) {
        if (! self.txRelays[hash]) self.txRelays[hash] = [NSMutableSet set];
        [self.txRelays[hash] addObject:peer];
        if (callback) [self.publishedCallback removeObjectForKey:hash];
        
        if (account && [self.txRelays[hash] count] >= self.peerManager.maxConnectCount &&
            [account transactionForHash:transaction.txHash].blockHeight == TX_UNCONFIRMED &&
            [account transactionForHash:transaction.txHash].timestamp == 0) {
            [account setBlockHeight:TX_UNCONFIRMED andTimestamp:[NSDate timeIntervalSince1970]
                        forTxHashes:@[hash]]; // set timestamp when tx is verified
        }
        
        //todo: deal when the transaction received is not in an account
        
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(txTimeout:) object:hash];
            
            [[NSNotificationCenter defaultCenter] postNotificationName:DSTransactionManagerTransactionStatusDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain}];
            [[NSNotificationCenter defaultCenter] postNotificationName:DSTransactionManagerTransactionReceivedNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain}];
            [[NSNotificationCenter defaultCenter] postNotificationName:DSWalletBalanceDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain}];
            
            if (callback) callback(nil);
            
        });
    }
    
    [self.nonFalsePositiveTransactions addObject:hash];
    [self.txRequests[hash] removeObject:peer];
    [self updateTransactionsBloomFilter];
}

// MARK: Transaction Issues

- (void)peer:(DSPeer *)peer relayedNotFoundMessagesWithTransactionHashes:(NSArray *)txHashes transactionLockRequestHashes:(NSArray *)transactionLockRequestHashes andBlockHashes:(NSArray *)blockhashes
{
    for (NSValue *hash in txHashes) {
        [self.txRelays[hash] removeObject:peer];
        [self.txRequests[hash] removeObject:peer];
    }
    
    for (NSValue *hash in transactionLockRequestHashes) {
        [self.txRelays[hash] removeObject:peer];
        [self.txRequests[hash] removeObject:peer];
    }
}

- (void)peer:(DSPeer *)peer rejectedTransaction:(UInt256)txHash withCode:(uint8_t)code
{
    DSTransaction *transaction = nil;
    DSAccount * account = [self.chain accountForTransactionHash:txHash transaction:&transaction wallet:nil];
    NSValue *hash = uint256_obj(txHash);
    
    if ([self.txRelays[hash] containsObject:peer]) {
        [self.txRelays[hash] removeObject:peer];
        
        if (transaction.blockHeight == TX_UNCONFIRMED) { // set timestamp 0 for unverified
            [self.chain setBlockHeight:TX_UNCONFIRMED andTimestamp:0 forTxHashes:@[hash]];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSTransactionManagerTransactionStatusDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain}];
            [[NSNotificationCenter defaultCenter] postNotificationName:DSWalletBalanceDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain}];
#if DEBUG
            UIAlertController * alert = [UIAlertController
                                         alertControllerWithTitle:@"transaction rejected"
                                         message:[NSString stringWithFormat:@"rejected by %@:%d with code 0x%x", peer.host, peer.port, code]
                                         preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction* okButton = [UIAlertAction
                                       actionWithTitle:@"ok"
                                       style:UIAlertActionStyleCancel
                                       handler:^(UIAlertAction * action) {
                                       }];
            [alert addAction:okButton];
            [[self presentingViewController] presentViewController:alert animated:YES completion:nil];
#endif
        });
    }
    
    [self.txRequests[hash] removeObject:peer];
    
    // if we get rejected for any reason other than double-spend, the peer is likely misconfigured
    if (code != REJECT_SPENT && [account amountSentByTransaction:transaction] > 0) {
        for (hash in transaction.inputHashes) { // check that all inputs are confirmed before dropping peer
            UInt256 h = UINT256_ZERO;
            
            [hash getValue:&h];
            if ([self.chain transactionForHash:h].blockHeight == TX_UNCONFIRMED) return;
        }
        
        [self.peerManager peerMisbehaving:peer errorMessage:@"Peer rejected the transaction"];
    }
}

// MARK: Instant Send

-(BOOL)checkAllLocksForTransaction:(DSTransaction*)transaction {
    DSDLog(@"Checking all locks for transaction %@",uint256_data(transaction.txHash).hexString);
    NSValue *transactionHashValue = uint256_obj(transaction.txHash);
    if (!transaction.inputHashes || !transaction.inputHashes.count) return NO;
    NSMutableDictionary * lockVotes = [NSMutableDictionary dictionary];
    
    for (uint32_t inputIndex = 0;inputIndex < [transaction.inputHashes count];inputIndex++) {
        NSValue * transactionOutputValue = transaction.inputHashes[inputIndex];
        uint32_t outputIndex = [transaction.inputIndexes[inputIndex] unsignedIntValue];
        UInt256 outputHash;
        [transactionOutputValue getValue:&outputHash];
        NSValue * transactionOutputUTXO = dsutxo_obj(((DSUTXO) { outputHash, outputIndex }));
        if (self.transactionLockVoteDictionary[transactionHashValue][transactionOutputUTXO][IX_INPUT_LOCKED_KEY]) {
            BOOL lockFailed = ![self.transactionLockVoteDictionary[transactionHashValue][transactionOutputUTXO][IX_INPUT_LOCKED_KEY] boolValue];
            if (lockFailed) return NO; //sanity check
            
        } else {
            return NO;
        }
        NSMutableDictionary * inputLockVotesDictionary = [self.transactionLockVoteDictionary[transactionHashValue][transactionOutputUTXO] mutableCopy];
        [inputLockVotesDictionary removeObjectForKey:IX_INPUT_LOCKED_KEY];
        
        lockVotes[transactionOutputUTXO] = [NSArray arrayWithArray:inputLockVotesDictionary.allValues];
    }
    [transaction setInstantSendReceivedWithTransactionLockVotes:lockVotes];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter]
         postNotificationName:DSTransactionManagerTransactionStatusDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain}];
    });
    return YES;
}

-(void)checkLocksForTransactionHash:(UInt256)transactionHash forInput:(DSUTXO)transactionOutput {
    //first check to see if transaction is known
    DSTransaction * transaction = nil;
    DSWallet * wallet = nil;
    DSAccount * account = [self.chain accountForTransactionHash:transactionHash transaction:&transaction wallet:&wallet];
    if (account && transaction) {
        //transaction and account are known
        NSValue *transactionHashValue = uint256_obj(transactionHash);
        NSValue *transactionOutputValue = dsutxo_obj(transactionOutput);
        if (self.transactionLockVoteDictionary[transactionHashValue][transactionOutputValue][IX_INPUT_LOCKED_KEY]) {
            BOOL lockFailed = ![self.transactionLockVoteDictionary[transactionHashValue][transactionOutputValue][IX_INPUT_LOCKED_KEY] boolValue];
            if (lockFailed) return; //sanity check
            //this input is alredy locked, let's check other inputs to see if they are locked as well
            [self checkAllLocksForTransaction:transaction];
            
        } else if ([self.transactionLockVoteDictionary[transactionHashValue][transactionOutputValue] count] > 5) {
            //there are over 6 votes already, check to see that the votes are coming from the right masternodes
            DSDLog(@"We have enough lock votes (%u)",(uint32_t)[self.transactionLockVoteDictionary[transactionHashValue][transactionOutputValue] count]);
            int yesVotes = 0;
            int noVotes = 0;//these might not be no votes, but they are a no for the masternode (might be an signature error)
            for (NSObject * value in [self.transactionLockVoteDictionary[transactionHashValue][transactionOutputValue] copy]) {
                if ([value isEqual:IX_INPUT_LOCKED_KEY]) continue;
                DSTransactionLockVote * lockVote = self.transactionLockVoteDictionary[transactionHashValue][transactionOutputValue][value];
                DSSimplifiedMasternodeEntry * masternode = [self.masternodeManager masternodeHavingProviderRegistrationTransactionHash:uint256_data(lockVote.masternodeProviderTransactionHash).reverse];
                if (!masternode) {
                    DSDLog(@"No known masternode");
                    continue;
                }
                if (!lockVote.quorumVerified) {
                    DSDLog(@"We got a lock vote from the wrong quorum");
                    DSDLog(@"Masternode %@ not in intended Quorum %@ with quorum modifier hash %@",lockVote.masternode,lockVote.intendedQuorum,[NSData dataWithUInt256:lockVote.quorumModifierHash].hexString);
                }
                DSDLog(@"signature is %@",lockVote.signatureVerified?@"verified":@"not good");
                if (lockVote.signatureVerified && lockVote.quorumVerified) yesVotes++;
                else noVotes++;
                if (yesVotes > 5) { // 6 or more
                    self.transactionLockVoteDictionary[transactionHashValue][transactionOutputValue][IX_INPUT_LOCKED_KEY] = @YES;
                    [self checkAllLocksForTransaction:transaction];
                } else if (noVotes > 4) { // 5 or more
                    self.transactionLockVoteDictionary[transactionHashValue][transactionOutputValue][IX_INPUT_LOCKED_KEY] = @NO;
                }
            }
        } else {
            DSDLog(@"There were only %u lock votes, waiting for more.",(uint32_t)[self.transactionLockVoteDictionary[transactionHashValue][transactionOutputValue] count]);
        }
    } else {
        DSDLog(@"No account or transaction found for transaction lock!");
    }
}

- (void)peer:(DSPeer *)peer hasTransactionLockVoteHashes:(NSOrderedSet *)transactionLockVoteHashes {
    
}

- (void)peer:(DSPeer *)peer relayedTransactionLockVote:(DSTransactionLockVote *)transactionLockVote {
    NSValue *transactionHashValue = uint256_obj(transactionLockVote.transactionHash);
    DSUTXO transactionOutput = transactionLockVote.transactionOutpoint;
    UInt256 masternodeProviderTransactionHash = transactionLockVote.masternodeProviderTransactionHash;
    NSValue *transactionOutputValue = dsutxo_obj(transactionOutput);
    NSValue *masternodeProviderTransactionHashValue = uint256_obj(masternodeProviderTransactionHash);
    if (!self.transactionLockVoteDictionary[transactionHashValue]) {
        self.transactionLockVoteDictionary[transactionHashValue] = [NSMutableDictionary dictionary];
    }
    if (!self.transactionLockVoteDictionary[transactionHashValue][transactionOutputValue]) {
        self.transactionLockVoteDictionary[transactionHashValue][transactionOutputValue] = [NSMutableDictionary dictionary];
    }
    
    self.transactionLockVoteDictionary[transactionHashValue][transactionOutputValue][masternodeProviderTransactionHashValue] = transactionLockVote;
    
    [transactionLockVote verifySignature];
    [transactionLockVote verifySentByIntendedQuorum];
    
    [self checkLocksForTransactionHash:transactionLockVote.transactionHash forInput:transactionOutput];
}

// MARK: Blocks

- (void)peer:(DSPeer *)peer relayedBlock:(DSMerkleBlock *)block
{
    //DSDLog(@"relayed block %@ total transactions %d %u",uint256_hex(block.blockHash), block.totalTransactions,block.timestamp);
    // ignore block headers that are newer than 2 days before earliestKeyTime (headers have 0 totalTransactions)
    if (block.totalTransactions == 0 &&
        block.timestamp + DAY_TIME_INTERVAL*2 > self.chain.earliestWalletCreationTime) {
        DSDLog(@"ignoring block %@",uint256_hex(block.blockHash));
        return;
    }
    
    NSArray *txHashes = block.txHashes;
    
    // track the observed bloom filter false positive rate using a low pass filter to smooth out variance
    if (peer == self.peerManager.downloadPeer && block.totalTransactions > 0) {
        NSMutableSet *falsePositives = [NSMutableSet setWithArray:txHashes];
        
        // 1% low pass filter, also weights each block by total transactions, using 1400 tx per block as typical
        [falsePositives minusSet:self.nonFalsePositiveTransactions]; // wallet tx are not false-positives
        [self.nonFalsePositiveTransactions removeAllObjects];
        self.transactionsBloomFilterFalsePositiveRate = self.transactionsBloomFilterFalsePositiveRate*(1.0 - 0.01*block.totalTransactions/1400) + 0.01*falsePositives.count/1400;
        
        // false positive rate sanity check
        if (self.peerManager.downloadPeer.status == DSPeerStatus_Connected && self.transactionsBloomFilterFalsePositiveRate > BLOOM_DEFAULT_FALSEPOSITIVE_RATE*10.0) {
            DSDLog(@"%@:%d bloom filter false positive rate %f too high after %d blocks, disconnecting...", peer.host,
                   peer.port, self.transactionsBloomFilterFalsePositiveRate, self.chain.lastBlockHeight + 1 - self.filterUpdateHeight);
            [self.peerManager.downloadPeer disconnect];
        }
        else if (self.chain.lastBlockHeight + 500 < peer.lastblock && self.transactionsBloomFilterFalsePositiveRate > BLOOM_REDUCED_FALSEPOSITIVE_RATE*10.0) {
            [self updateTransactionsBloomFilter]; // rebuild bloom filter when it starts to degrade
        }
    }
    
    if (! _bloomFilter) { // ignore potentially incomplete blocks when a filter update is pending
        if (peer == self.peerManager.downloadPeer) [self.chainManager relayedNewItem];
        DSDLog(@"ignoring block due to filter update %@",uint256_hex(block.blockHash));
        return;
    }
    
    [self.chain addBlock:block fromPeer:peer];
}

- (void)peer:(DSPeer *)peer relayedTooManyOrphanBlocks:(NSUInteger)orphanBlockCount {
    [self.peerManager peerMisbehaving:peer errorMessage:@"Too many orphan blocks"];
}

// MARK: Fees

- (void)peer:(DSPeer *)peer setFeePerByte:(uint64_t)feePerKb
{
    uint64_t maxFeePerByte = 0, secondFeePerByte = 0;
    
    for (DSPeer *p in self.peerManager.connectedPeers) { // find second highest fee rate
        if (p.status != DSPeerStatus_Connected) continue;
        if (p.feePerByte > maxFeePerByte) secondFeePerByte = maxFeePerByte, maxFeePerByte = p.feePerByte;
    }
    
    if (secondFeePerByte*2 > MIN_FEE_PER_B && secondFeePerByte*2 <= MAX_FEE_PER_B &&
        secondFeePerByte*2 > self.chain.feePerByte) {
        DSDLog(@"increasing feePerKb to %llu based on feefilter messages from peers", secondFeePerByte*2);
        self.chain.feePerByte = secondFeePerByte*2;
    }
}

@end
