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
#import "DSChainManager.h"
#import "DSWallet.h"
#import "DSAccount.h"

@interface DSTransactionManager()

@property (nonatomic, strong) NSMutableDictionary *txRelays, *txRequests;
@property (nonatomic, strong) NSMutableDictionary *publishedTx, *publishedCallback;

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
    return self;
}

-(DSPeerManager*)peerManager {
    return self.chain.chainManager.peerManager;
}

// MARK: - Blockchain Transactions

// adds transaction to list of tx to be published, along with any unconfirmed inputs
- (void)addTransactionToPublishList:(DSTransaction *)transaction
{
    if (transaction.blockHeight == TX_UNCONFIRMED) {
        NSLog(@"[DSTransactionManager] add transaction to publish list %@ (%@)", transaction,transaction.toData);
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
    NSLog(@"[DSTransactionManager] publish transaction %@", transaction);
    if ([transaction transactionTypeRequiresInputs] && !transaction.isSigned) {
        if (completion) {
            [[DSEventManager sharedEventManager] saveEvent:@"peer_manager:not_signed"];
            completion([NSError errorWithDomain:@"DashWallet" code:401 userInfo:@{NSLocalizedDescriptionKey:
                                                                                      DSLocalizedString(@"dash transaction not signed", nil)}]);
        }
        
        return;
    }
    else if (! self.peerManager.connected && self.peerManager.connectFailures >= MAX_CONNECT_FAILURES) {
        if (completion) {
            [[DSEventManager sharedEventManager] saveEvent:@"peer_manager:not_connected"];
            completion([NSError errorWithDomain:@"DashWallet" code:-1009 userInfo:@{NSLocalizedDescriptionKey:
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
    if (self.peerManager.connectedPeerCount > 1 && self.peerManager.downloadPeer) [peers removeObject:self.downloadPeer];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self performSelector:@selector(txTimeout:) withObject:hash afterDelay:PROTOCOL_TIMEOUT];
        
        for (DSPeer *p in peers) {
            if (p.status != DSPeerStatus_Connected) continue;
            [p sendInvMessageForHashes:txHashes ofType:DSInvType_Tx];
            [p sendPingMessageWithPongHandler:^(BOOL success) {
                if (! success) return;
                
                for (NSValue *h in txHashes) {
                    if ([self.txRelays[h] containsObject:p] || [self.txRequests[h] containsObject:p]) continue;
                    if (! self.txRequests[h]) self.txRequests[h] = [NSMutableSet set];
                    [self.txRequests[h] addObject:p];
                    [p sendGetdataMessageWithTxHashes:@[h] andBlockHashes:nil];
                }
            }];
        }
    });
}


// unconfirmed transactions that aren't in the mempools of any of connected peers have likely dropped off the network
- (void)removeUnrelayedTransactions
{
    BOOL rescan = NO, notify = NO;
    NSValue *hash;
    UInt256 h;
    
    // don't remove transactions until we're connected to maxConnectCount peers
    if (self.peerManager.connectedPeerCount < self.peerManager.maxConnectCount) return;
    
    for (DSPeer *p in self.peerManager.connectedPeers) { // don't remove tx until all peers have finished relaying their mempools
        if (! p.synced) return;
    }
    
    for (DSWallet * wallet in self.chain.wallets) {
        for (DSAccount * account in wallet.accounts) {
            for (DSTransaction *transaction in account.allTransactions) {
                if (transaction.blockHeight != TX_UNCONFIRMED) break;
                hash = uint256_obj(transaction.txHash);
                if (self.publishedCallback[hash] != NULL) continue;
                
                if ([self.txRelays[hash] count] == 0 && [self.txRequests[hash] count] == 0) {
                    // if this is for a transaction we sent, and it wasn't already known to be invalid, notify user of failure
                    if (! rescan && [account amountSentByTransaction:transaction] > 0 && [account transactionIsValid:transaction]) {
                        NSLog(@"failed transaction %@", transaction);
                        rescan = notify = YES;
                        
                        for (NSValue *hash in transaction.inputHashes) { // only recommend a rescan if all inputs are confirmed
                            [hash getValue:&h];
                            if ([wallet transactionForHash:h].blockHeight != TX_UNCONFIRMED) continue;
                            rescan = NO;
                            break;
                        }
                    }
                    
                    [account removeTransaction:transaction.txHash];
                }
                else if ([self.txRelays[hash] count] < self.peerManager.maxConnectCount) {
                    // set timestamp 0 to mark as unverified
                    [self.chain setBlockHeight:TX_UNCONFIRMED andTimestamp:0 forTxHashes:@[hash]];
                }
            }
        }
    }
    
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
                                               actionWithTitle:DSLocalizedString(@"cancel", nil)
                                               style:UIAlertActionStyleCancel
                                               handler:^(UIAlertAction * action) {
                                               }];
                UIAlertAction* rescanButton = [UIAlertAction
                                               actionWithTitle:DSLocalizedString(@"rescan", nil)
                                               style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction * action) {
                                                   [self rescan];
                                               }];
                [alert addAction:cancelButton];
                [alert addAction:rescanButton];
                [[[[UIApplication sharedApplication] keyWindow] rootViewController] presentViewController:alert animated:YES completion:nil];
                
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
                [[[[UIApplication sharedApplication] keyWindow] rootViewController] presentViewController:alert animated:YES completion:nil];
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
        callback([NSError errorWithDomain:@"DashWallet" code:BITCOIN_TIMEOUT_CODE userInfo:@{NSLocalizedDescriptionKey:
                                                                                                 DSLocalizedString(@"transaction canceled, network timeout", nil)}]);
    }
}

- (void)clearTransactionRelaysForPeer:(DSPeer*)peer {
for (NSValue *txHash in self.txRelays.allKeys) {
    [self.txRelays[txHash] removeObject:peer];
}
}

// MARK: - DSChainDelegate

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
}


@end
