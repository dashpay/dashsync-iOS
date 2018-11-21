//
//  DSChainManager.m
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

#import "DSChainManager.h"
#import "DSPeerManager+Protected.h"
#import "DSEventManager.h"
#import "DSChain.h"
#import "DSSporkManager.h"
#import "DSOptionsManager.h"
#import "DSMasternodeManager.h"
#import "DSGovernanceSyncManager.h"
#import "DSDAPIPeerManager.h"
#import "DSTransactionManager+Protected.h"
#import "DSMempoolManager.h"
#import "DSBloomFilter.h"
#import "DSMerkleBlock.h"
#import "DSWallet.h"
#import "DSDerivationPath.h"
#import "NSString+Bitcoin.h"
#import "NSDate+Utils.h"

#define SYNC_STARTHEIGHT_KEY @"SYNC_STARTHEIGHT"

@interface DSChainManager ()

@property (nonatomic, strong) DSChain * chain;
@property (nonatomic, strong) DSSporkManager * sporkManager;
@property (nonatomic, strong) DSMasternodeManager * masternodeManager;
@property (nonatomic, strong) DSGovernanceSyncManager * governanceSyncManager;
@property (nonatomic, strong) DSDAPIPeerManager * DAPIPeerManager;
@property (nonatomic, strong) DSTransactionManager * transactionManager;
@property (nonatomic, strong) DSPeerManager * peerManager;
@property (nonatomic, strong) DSMempoolManager * mempoolManager;
@property (nonatomic, strong) DSBloomFilter *bloomFilter;
@property (nonatomic, assign) uint32_t syncStartHeight, filterUpdateHeight;
@property (nonatomic, assign) double fpRate;
@property (nonatomic, assign) NSTimeInterval lastChainRelayTime;

@end

@implementation DSChainManager

- (instancetype)initWithChain:(DSChain*)chain
{
    if (! (self = [super init])) return nil;
    
    self.chain = chain;
    self.sporkManager = [[DSSporkManager alloc] initWithChain:chain];
    self.masternodeManager = [[DSMasternodeManager alloc] initWithChain:chain];
    self.DAPIPeerManager = [[DSDAPIPeerManager alloc] initWithChainPeerManager:self];
    self.governanceSyncManager = [[DSGovernanceSyncManager alloc] initWithChain:chain];
    self.transactionManager = [[DSTransactionManager alloc] initWithChain:chain];
    self.peerManager = [[DSPeerManager alloc] initWithChain:chain];
    self.mempoolManager = [[DSMempoolManager alloc] initWithChain:chain];
    
    return self;
}

// MARK: - Bloom Filters

- (void)updateFilter
{
    if (self.peerManager.downloadPeer.needsFilterUpdate) return;
    self.peerManager.downloadPeer.needsFilterUpdate = YES;
    NSLog(@"filter update needed, waiting for pong");
    
    [self.peerManager.downloadPeer sendPingMessageWithPongHandler:^(BOOL success) { // wait for pong so we include already sent tx
        if (! success) return;
        NSLog(@"updating filter with newly created wallet addresses");
        self->_bloomFilter = nil;
        
        if (self.chain.lastBlockHeight < self.chain.estimatedBlockHeight) { // if we're syncing, only update download peer
            [self.peerManager.downloadPeer sendFilterloadMessage:[self bloomFilterForPeer:self.peerManager.downloadPeer].data];
            [self.peerManager.downloadPeer sendPingMessageWithPongHandler:^(BOOL success) { // wait for pong so filter is loaded
                if (! success) return;
                self.peerManager.downloadPeer.needsFilterUpdate = NO;
                [self.peerManager.downloadPeer rerequestBlocksFrom:self.chain.lastBlock.blockHash];
                [self.peerManager.downloadPeer sendPingMessageWithPongHandler:^(BOOL success) {
                    if (! success || self.peerManager.downloadPeer.needsFilterUpdate) return;
                    [self.peerManager.downloadPeer sendGetblocksMessageWithLocators:[self.chain blockLocatorArray]
                                                            andHashStop:UINT256_ZERO];
                }];
            }];
        }
        else {
            for (DSPeer *p in self.peerManager.connectedPeers) {
                if (p.status != DSPeerStatus_Connected) continue;
                [p sendFilterloadMessage:[self bloomFilterForPeer:p].data];
                [p sendPingMessageWithPongHandler:^(BOOL success) { // wait for pong so we know filter is loaded
                    if (! success) return;
                    p.needsFilterUpdate = NO;
                    [p sendMempoolMessage:self.transactionManager.publishedTx.allKeys completion:nil];
                }];
            }
        }
    }];
}


- (DSBloomFilter *)bloomFilterForPeer:(DSPeer *)peer
{
    NSMutableSet * allAddresses = [NSMutableSet set];
    NSMutableSet * allUTXOs = [NSMutableSet set];
    for (DSWallet * wallet in self.chain.wallets) {
        // every time a new wallet address is added, the bloom filter has to be rebuilt, and each address is only used for
        // one transaction, so here we generate some spare addresses to avoid rebuilding the filter each time a wallet
        // transaction is encountered during the blockchain download
        [wallet registerAddressesWithGapLimit:SEQUENCE_GAP_LIMIT_EXTERNAL + 100 internal:NO];
        [wallet registerAddressesWithGapLimit:SEQUENCE_GAP_LIMIT_INTERNAL + 100 internal:YES];
        NSSet *addresses = [wallet.allReceiveAddresses setByAddingObjectsFromSet:wallet.allChangeAddresses];
        [allAddresses addObjectsFromArray:[addresses allObjects]];
        [allUTXOs addObjectsFromArray:wallet.unspentOutputs];
        
        //we should also add the blockchain user public keys to the filter
        [allAddresses addObjectsFromArray:[wallet blockchainUserAddresses]];
    }
    
    for (DSDerivationPath * derivationPath in self.chain.standaloneDerivationPaths) {
        [derivationPath registerAddressesWithGapLimit:SEQUENCE_GAP_LIMIT_EXTERNAL + 100 internal:NO];
        [derivationPath registerAddressesWithGapLimit:SEQUENCE_GAP_LIMIT_INTERNAL + 100 internal:YES];
        NSArray *addresses = [derivationPath.allReceiveAddresses arrayByAddingObjectsFromArray:derivationPath.allChangeAddresses];
        [allAddresses addObjectsFromArray:addresses];
    }
    
    
    [self.chain clearOrphans];
    self.filterUpdateHeight = self.chain.lastBlockHeight;
    self.fpRate = BLOOM_REDUCED_FALSEPOSITIVE_RATE;
    
    DSUTXO o;
    NSData *d;
    NSUInteger i, elemCount = allAddresses.count + allUTXOs.count;
    NSMutableArray *inputs = [NSMutableArray new];
    
    for (DSWallet * wallet in self.chain.wallets) {
        for (DSTransaction *tx in wallet.allTransactions) { // find TXOs spent within the last 100 blocks
            [self.transactionManager addTransactionToPublishList:tx]; // also populate the tx publish list
            if (tx.blockHeight != TX_UNCONFIRMED && tx.blockHeight + 100 < self.chain.lastBlockHeight) break;
            i = 0;
            
            for (NSValue *hash in tx.inputHashes) {
                [hash getValue:&o.hash];
                o.n = [tx.inputIndexes[i++] unsignedIntValue];
                
                DSTransaction *t = [wallet transactionForHash:o.hash];
                
                if (o.n < t.outputAddresses.count && [wallet containsAddress:t.outputAddresses[o.n]]) {
                    [inputs addObject:dsutxo_data(o)];
                    elemCount++;
                }
            }
        }
    }
    
    DSBloomFilter *filter = [[DSBloomFilter alloc] initWithFalsePositiveRate:self.fpRate
                                                             forElementCount:(elemCount < 200 ? 300 : elemCount + 100) tweak:(uint32_t)peer.hash
                                                                       flags:BLOOM_UPDATE_ALL];
    
    for (NSString *addr in allAddresses) {// add addresses to watch for tx receiveing money to the wallet
        NSData *hash = addr.addressToHash160;
        
        if (hash && ! [filter containsData:hash]) [filter insertData:hash];
    }
    
    for (NSValue *utxo in allUTXOs) { // add UTXOs to watch for tx sending money from the wallet
        [utxo getValue:&o];
        d = dsutxo_data(o);
        if (! [filter containsData:d]) [filter insertData:d];
    }
    
    for (d in inputs) { // also add TXOs spent within the last 100 blocks
        if (! [filter containsData:d]) [filter insertData:d];
    }
    
    // TODO: XXXX if already synced, recursively add inputs of unconfirmed receives
    _bloomFilter = filter;
    return _bloomFilter;
}

// MARK: - Info

-(NSString*)syncStartHeightKey {
    return [NSString stringWithFormat:@"%@_%@",SYNC_STARTHEIGHT_KEY,[self.chain uniqueID]];
}

- (double)syncProgress
{
    if (! self.peerManager.downloadPeer && self.syncStartHeight == 0) return 0.0;
    //if (self.downloadPeer.status != DSPeerStatus_Connected) return 0.05;
    if (self.chain.lastBlockHeight >= self.chain.estimatedBlockHeight) return 1.0;
    return 0.1 + 0.9*(self.chain.lastBlockHeight - self.syncStartHeight)/(self.chain.estimatedBlockHeight - self.syncStartHeight);
}

-(void)resetSyncStartHeight {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    if (self.syncStartHeight == 0) self.syncStartHeight = (uint32_t)[userDefaults integerForKey:self.syncStartHeightKey];
    
    if (self.syncStartHeight == 0) {
        self.syncStartHeight = self.chain.lastBlockHeight;
        [[NSUserDefaults standardUserDefaults] setInteger:self.syncStartHeight forKey:self.syncStartHeightKey];
    }
}

-(void)restartSyncStartHeight {
    self.syncStartHeight = 0;
    [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:self.syncStartHeightKey];
}

// MARK: - Blockchain Sync

// rescans blocks and transactions after earliestKeyTime, a new random download peer is also selected due to the
// possibility that a malicious node might lie by omitting transactions that match the bloom filter
- (void)rescan
{
    if (!self.peerManager.connected) return;
    
    dispatch_async(self.chainPeerManagerQueue, ^{
        [self.chain setLastBlockHeightForRescan];
        
        if (self.downloadPeer) { // disconnect the current download peer so a new random one will be selected
            [self.peers removeObject:self.downloadPeer];
            [self.downloadPeer disconnect];
        }
        
        self.syncStartHeight = self.chain.lastBlockHeight;
        [[NSUserDefaults standardUserDefaults] setInteger:self.syncStartHeight forKey:self.syncStartHeightKey];
        [self connect];
    });
}

// MARK: - DSChainDelegate

-(void)chain:(DSChain*)chain didSetBlockHeight:(int32_t)height andTimestamp:(NSTimeInterval)timestamp forTxHashes:(NSArray *)txHashes updatedTx:(NSArray *)updatedTx {
    [self.transactionManager chain:chain didSetBlockHeight:height andTimestamp:timestamp forTxHashes:txHashes updatedTx:updatedTx];
}

-(void)chainWasWiped:(DSChain*)chain {
    [self.transactionManager chainWasWiped:chain];
    _bloomFilter = nil;
}

-(void)chainFinishedSyncing:(DSChain*)chain fromPeer:(DSPeer*)peer onMainChain:(BOOL)onMainChain {
    if (onMainChain && (peer == self.downloadPeer)) self.lastChainRelayTime = [NSDate timeIntervalSince1970];
    NSLog(@"chain finished syncing");
    self.syncStartHeight = 0;
    [self.mempoolManager loadMempools];
    [self.sporkManager getSporks];
    [self.governanceSyncManager startGovernanceSync];
    [self.masternodeManager getMasternodeList];
}

-(void)chain:(DSChain*)chain badBlockReceivedFromPeer:(DSPeer*)peer {
    NSLog(@"peer at address %@ is misbehaving",peer.host);
    [self.peerManager peerMisbehavin:peer];
}

-(void)chain:(DSChain*)chain receivedOrphanBlock:(DSMerkleBlock*)block fromPeer:(DSPeer*)peer {
    // ignore orphans older than one week ago
    if (block.timestamp < [NSDate timeIntervalSince1970] - 7*24*60*60) return;
    
    // call getblocks, unless we already did with the previous block, or we're still downloading the chain
    if (self.chain.lastBlockHeight >= peer.lastblock && ! uint256_eq(self.chain.lastOrphan.blockHash, block.prevBlock)) {
        NSLog(@"%@:%d calling getblocks", peer.host, peer.port);
        [peer sendGetblocksMessageWithLocators:[self.chain blockLocatorArray] andHashStop:UINT256_ZERO];
    }
}


// MARK: - DSChainDelegate



@end
