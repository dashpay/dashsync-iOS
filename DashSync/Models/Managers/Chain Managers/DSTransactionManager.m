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
#import "UIWindow+DSUtils.h"

@interface DSTransactionManager()

@property (nonatomic, strong) NSMutableDictionary *txRelays, *txRequests;
@property (nonatomic, strong) NSMutableDictionary *publishedTx, *publishedCallback;
@property (nonatomic, strong) NSMutableSet *nonFalsePositiveTransactions;
@property (nonatomic, strong) DSBloomFilter *bloomFilter;
@property (nonatomic, assign) uint32_t filterUpdateHeight;
@property (nonatomic, assign) double transactionsBloomFilterFalsePositiveRate;

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
    return self;
}

-(DSPeerManager*)peerManager {
    return self.chain.chainManager.peerManager;
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
            [[DSEventManager sharedEventManager] saveEvent:@"transaction_manager:not_signed"];
            completion([NSError errorWithDomain:@"DashWallet" code:401 userInfo:@{NSLocalizedDescriptionKey:
                                                                                      DSLocalizedString(@"dash transaction not signed", nil)}]);
        }
        
        return;
    }
    else if (! self.peerManager.connected && self.peerManager.connectFailures >= MAX_CONNECT_FAILURES) {
        if (completion) {
            [[DSEventManager sharedEventManager] saveEvent:@"transaction_manager:not_connected"];
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
    if (self.peerManager.connectedPeerCount > 1 && self.peerManager.downloadPeer) [peers removeObject:self.peerManager.downloadPeer];
    
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
        callback([NSError errorWithDomain:@"DashWallet" code:BITCOIN_TIMEOUT_CODE userInfo:@{NSLocalizedDescriptionKey:
                                                                                                 DSLocalizedString(@"transaction canceled, network timeout", nil)}]);
    }
}

- (void)clearTransactionRelaysForPeer:(DSPeer*)peer {
for (NSValue *txHash in self.txRelays.allKeys) {
    [self.txRelays[txHash] removeObject:peer];
}
}

// MARK: - Mempools Sync

- (void)fetchMempoolFromNetwork
{
    if (!([[DSOptionsManager sharedInstance] syncType] & DSSyncType_Mempools)) return; // make sure we care about sporks
    for (DSPeer *p in self.peerManager.connectedPeers) { // after syncing, load filters and get mempools from other peers
        if (p.status != DSPeerStatus_Connected) continue;
        
        if ([self.chain canConstructAFilter] && (p != self.peerManager.downloadPeer || self.transactionsBloomFilterFalsePositiveRate > BLOOM_REDUCED_FALSEPOSITIVE_RATE*5.0)) {
            [p sendFilterloadMessage:[self transactionsBloomFilterForPeer:p].data];
        }
        
        [p sendInvMessageForHashes:self.publishedCallback.allKeys ofType:DSInvType_Tx]; // publish pending tx
        [p sendPingMessageWithPongHandler:^(BOOL success) {
            if (success) {
                [p sendMempoolMessage:self.publishedTx.allKeys completion:^(BOOL success) {
                    if (success) {
                        p.synced = YES;
                        [self removeUnrelayedTransactions];
                        [p sendGetaddrMessage]; // request a list of other bitcoin peers
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [[NSNotificationCenter defaultCenter]
                             postNotificationName:DSChainPeerManagerTxStatusNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain}];
                        });
                    }
                    
                    if (p == self.peerManager.downloadPeer) {
                        [self.peerManager syncStopped];
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [[NSNotificationCenter defaultCenter]
                             postNotificationName:DSChainPeerManagerSyncFinishedNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain}];
                        });
                    }
                }];
            }
            else if (p == self.peerManager.downloadPeer) {
                [self.peerManager syncStopped];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter]
                     postNotificationName:DSChainPeerManagerSyncFinishedNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain}];
                });
            }
        }];
    }
}

// MARK: - Bloom Filters

//This returns the bloom filter for the peer, currently the filter is only tweaked per peer, and we only cache the filter of the download peer.
//It makes sense to keep this in this class because it is not a property of the chain, but intead of a effemeral item used in the synchronization of the chain.
- (DSBloomFilter *)transactionsBloomFilterForPeer:(DSPeer *)peer
{
    
    //TODO: XXXX move this somewhere more suitable, not sure why we are adding transaction to publish list here
    for (DSWallet * wallet in self.chain.wallets) {
        for (DSTransaction *tx in wallet.allTransactions) { // find TXOs spent within the last 100 blocks
            [self addTransactionToPublishList:tx]; // also populate the tx publish list
        }
    }
    
    
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
    
    for (DSDerivationPath * derivationPath in self.chain.standaloneDerivationPaths) {
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

- (void)peer:(DSPeer *)peer relayedTransaction:(DSTransaction *)transaction
{
    NSValue *hash = uint256_obj(transaction.txHash);
    BOOL syncing = (self.chain.lastBlockHeight < self.chain.estimatedBlockHeight);
    void (^callback)(NSError *error) = self.publishedCallback[hash];
    
    NSLog(@"%@:%d relayed transaction %@", peer.host, peer.port, hash);
    
    transaction.timestamp = [NSDate timeIntervalSince1970];
    DSAccount * account = [self.chain accountContainingTransaction:transaction];
    if (syncing && !account) return;
    if (![account registerTransaction:transaction]) return;
    if (peer == self.peerManager.downloadPeer) [self.chainManager relayedNewItem];
    
    if ([account amountSentByTransaction:transaction] > 0 && [account transactionIsValid:transaction]) {
        [self addTransactionToPublishList:transaction]; // add valid send tx to mempool
    }
    
    // keep track of how many peers have or relay a tx, this indicates how likely the tx is to confirm
    if (callback || (! syncing && ! [self.txRelays[hash] containsObject:peer])) {
        if (! self.txRelays[hash]) self.txRelays[hash] = [NSMutableSet set];
        [self.txRelays[hash] addObject:peer];
        if (callback) [self.publishedCallback removeObjectForKey:hash];
        
        if ([self.txRelays[hash] count] >= self.peerManager.maxConnectCount &&
            [account transactionForHash:transaction.txHash].blockHeight == TX_UNCONFIRMED &&
            [account transactionForHash:transaction.txHash].timestamp == 0) {
            [account setBlockHeight:TX_UNCONFIRMED andTimestamp:[NSDate timeIntervalSince1970]
                        forTxHashes:@[hash]]; // set timestamp when tx is verified
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(txTimeout:) object:hash];
            [[NSNotificationCenter defaultCenter] postNotificationName:DSChainPeerManagerTxStatusNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain}];
            [[NSNotificationCenter defaultCenter] postNotificationName:DSWalletBalanceDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain}];
            if (callback) callback(nil);
            
        });
    }
    
    [self.nonFalsePositiveTransactions addObject:hash];
    [self.txRequests[hash] removeObject:peer];
    [self updateTransactionsBloomFilter];
}

- (void)peer:(DSPeer *)peer relayedBlock:(DSMerkleBlock *)block
{
    // ignore block headers that are newer than one week before earliestKeyTime (headers have 0 totalTransactions)
    if (block.totalTransactions == 0 &&
        block.timestamp + WEEK_TIME_INTERVAL/4 > self.chain.earliestWalletCreationTime + HOUR_TIME_INTERVAL/2) {
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
            NSLog(@"%@:%d bloom filter false positive rate %f too high after %d blocks, disconnecting...", peer.host,
                  peer.port, self.transactionsBloomFilterFalsePositiveRate, self.chain.lastBlockHeight + 1 - self.filterUpdateHeight);
            [self.peerManager.downloadPeer disconnect];
        }
        else if (self.chain.lastBlockHeight + 500 < peer.lastblock && self.transactionsBloomFilterFalsePositiveRate > BLOOM_REDUCED_FALSEPOSITIVE_RATE*10.0) {
            [self updateTransactionsBloomFilter]; // rebuild bloom filter when it starts to degrade
        }
    }
    
    if (! _bloomFilter) { // ignore potentially incomplete blocks when a filter update is pending
        if (peer == self.peerManager.downloadPeer) [self.chainManager relayedNewItem];
        return;
    }
    
    [self.chain addBlock:block fromPeer:peer];
}

- (void)peer:(DSPeer *)peer notfoundTxHashes:(NSArray *)txHashes andBlockHashes:(NSArray *)blockhashes
{
    for (NSValue *hash in txHashes) {
        [self.txRelays[hash] removeObject:peer];
        [self.txRequests[hash] removeObject:peer];
    }
}

- (void)peer:(DSPeer *)peer hasTransaction:(UInt256)txHash
{
    NSValue *hash = uint256_obj(txHash);
    BOOL syncing = (self.chain.lastBlockHeight < self.chain.estimatedBlockHeight);
    DSTransaction *transaction = self.publishedTx[hash];
    void (^callback)(NSError *error) = self.publishedCallback[hash];
    
    NSLog(@"%@:%d has transaction %@", peer.host, peer.port, hash);
    if (!transaction) transaction = [self.chain transactionForHash:txHash];
    if (!transaction) return;
    DSAccount * account = nil;
    if (syncing) {
        account = [self.chain accountContainingTransaction:transaction];
        if (!account) return;
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
            [[NSNotificationCenter defaultCenter] postNotificationName:DSChainPeerManagerTxStatusNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain}];
            if (callback) callback(nil);
            
        });
    }
    
    [self.nonFalsePositiveTransactions addObject:hash];
    [self.txRequests[hash] removeObject:peer];
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
            [[NSNotificationCenter defaultCenter] postNotificationName:DSChainPeerManagerTxStatusNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain}];
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
        
        [self.peerManager peerMisbehaving:peer];
    }
}

- (void)peer:(DSPeer *)peer hasTransactionLockVoteHashes:(NSSet *)transactionLockVoteHashes {
    
}


- (DSTransaction *)peer:(DSPeer *)peer requestedTransaction:(UInt256)txHash
{
    NSValue *hash = uint256_obj(txHash);
    DSTransaction *transaction = self.publishedTx[hash];
    DSAccount * account = [self.chain accountContainingTransaction:transaction];
    void (^callback)(NSError *error) = self.publishedCallback[hash];
    NSError *error = nil;
    
    if (! self.txRelays[hash]) self.txRelays[hash] = [NSMutableSet set];
    [self.txRelays[hash] addObject:peer];
    [self.nonFalsePositiveTransactions addObject:hash];
    [self.publishedCallback removeObjectForKey:hash];
    
    if (callback && ! [account transactionIsValid:transaction]) {
        [self.publishedTx removeObjectForKey:hash];
        error = [NSError errorWithDomain:@"DashWallet" code:401
                                userInfo:@{NSLocalizedDescriptionKey:DSLocalizedString(@"double spend", nil)}];
    }
    else if (transaction && ! [account transactionForHash:txHash] && [account registerTransaction:transaction]) {
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

- (void)peer:(DSPeer *)peer setFeePerByte:(uint64_t)feePerKb
{
    uint64_t maxFeePerByte = 0, secondFeePerByte = 0;
    
    for (DSPeer *p in self.peerManager.connectedPeers) { // find second highest fee rate
        if (p.status != DSPeerStatus_Connected) continue;
        if (p.feePerByte > maxFeePerByte) secondFeePerByte = maxFeePerByte, maxFeePerByte = p.feePerByte;
    }
    
    if (secondFeePerByte*2 > MIN_FEE_PER_B && secondFeePerByte*2 <= MAX_FEE_PER_B &&
        secondFeePerByte*2 > self.chain.feePerByte) {
        NSLog(@"increasing feePerKb to %llu based on feefilter messages from peers", secondFeePerByte*2);
        self.chain.feePerByte = secondFeePerByte*2;
    }
}

@end
