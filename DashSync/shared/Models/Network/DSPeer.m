//
//  DSPeer.m
//  DashSync
//
//  Created by Aaron Voisine for BreadWallet on 10/9/13.
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

#import "DSPeer.h"
#import "DSAddrRequest.h"
#import "DSBlockchainIdentityRegistrationTransition.h"
#import "DSBloomFilter.h"
#import "DSChain+Protected.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSChainLock.h"
#import "DSChainManager+Protected.h"
#import "DSChainManager+Transactions.h"
#import "DSChainManager.h"
#import "DSFilterLoadRequest.h"
#import "DSGetBlocksRequest.h"
#import "DSGetDataForTransactionHashRequest.h"
#import "DSGetDataForTransactionHashesRequest.h"
#import "DSGetHeadersRequest.h"
#import "DSGovernanceObject.h"
#import "DSGovernanceVote.h"
#import "DSGovernanceHashesRequest.h"
#import "DSGovernanceSyncRequest.h"
#import "DSInstantSendTransactionLock.h"
#import "DSInvRequest.h"
#import "DSKeyManager.h"
#import "DSMasternodeManager.h"
#import "DSMerkleBlock.h"
#import "DSNotFoundRequest.h"
#import "DSOptionsManager.h"
#import "DSPeerEntity+CoreDataClass.h"
#import "DSPeerManager.h"
#import "DSPingRequest.h"
#import "DSReachabilityManager.h"
#import "DSSimplifiedMasternodeEntry.h"
#import "DSSpork.h"
#import "DSSporkManager.h"
#import "DSTransaction.h"
#import "DSTransactionFactory.h"
#import "DSTransactionHashEntity+CoreDataClass.h"
#import "DSTransactionInvRequest.h"
#import "DSVersionRequest.h"
#import "NSData+DSHash.h"
#import "NSData+Dash.h"
#import "NSDate+Utils.h"
#import "NSError+Dash.h"
#import "NSManagedObject+Sugar.h"
#import "NSMutableData+Dash.h"
#import <arpa/inet.h>

#define PEER_LOGGING 1
#define LOG_ALL_HEADERS_IN_ACCEPT_HEADERS 0
#define LOG_TX_LOCK_VOTES 1
#define LOG_FULL_TX_MESSAGE 0

#if !PEER_LOGGING
#define DSLog(...)
#endif

#define MESSAGE_LOGGING (1 & DEBUG)
#define MESSAGE_CONTENT_LOGGING (0 & DEBUG)
#define MESSAGE_IN_DEPTH_TX_LOGGING (0 & DEBUG)

#define HEADER_LENGTH 24
#define MAX_MSG_LENGTH 0x02000000
#define CONNECT_TIMEOUT 3.0
#define MEMPOOL_TIMEOUT 3.0

#define LOCK(lock) dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
#define UNLOCK(lock) dispatch_semaphore_signal(lock);

#define DSLogWithLocation(obj, fmt, ...) DSLog(@"%@ " fmt, [obj debugLocation], ##__VA_ARGS__)
#define DSLogPrivateWithLocation(obj, fmt, ...) DSLogPrivate(@"%@ " fmt, [obj debugLocation], ##__VA_ARGS__)

@interface DSPeer ()

@property (nonatomic, weak) id<DSPeerDelegate> peerDelegate;
@property (nonatomic, weak) id<DSPeerChainDelegate> peerChainDelegate;
@property (nonatomic, weak) id<DSPeerTransactionDelegate> transactionDelegate;
@property (nonatomic, weak) id<DSPeerGovernanceDelegate> governanceDelegate;
@property (nonatomic, weak) id<DSPeerSporkDelegate> sporkDelegate;
@property (nonatomic, weak) id<DSPeerMasternodeDelegate> masternodeDelegate;
@property (nonatomic, strong) dispatch_queue_t delegateQueue;
@property (nonatomic, strong) NSInputStream *inputStream;
@property (nonatomic, strong) NSOutputStream *outputStream;
@property (nonatomic, strong) NSMutableData *msgHeader, *msgPayload, *outputBuffer;
@property (nonatomic, assign) BOOL sentVerack, gotVerack;
@property (nonatomic, assign) BOOL sentGetaddr, sentFilter, sentGetdataTxBlocks, sentGetdataMasternode, sentMempool, sentGetblocks;
@property (nonatomic, assign) BOOL receivedGovSync;
@property (nonatomic, strong) DSReachabilityManager *reachability;
@property (nonatomic, strong) id reachabilityObserver;
@property (nonatomic, assign) uint64_t localNonce;
@property (nonatomic, assign) NSTimeInterval pingStartTime, relayStartTime;
@property (nonatomic, strong) DSMerkleBlock *currentBlock;
@property (nonatomic, strong) NSMutableOrderedSet *knownBlockHashes, *knownChainLockHashes, *knownTxHashes, *knownInstantSendLockHashes, *knownInstantSendLockDHashes, *currentBlockTxHashes;
@property (nonatomic, strong) NSMutableOrderedSet *knownGovernanceObjectHashes, *knownGovernanceObjectVoteHashes;
@property (nonatomic, strong) NSData *lastBlockHash;
@property (nonatomic, strong) NSMutableArray *pongHandlers;
@property (nonatomic, strong) MempoolCompletionBlock mempoolTransactionCompletion;
@property (nonatomic, strong) NSRunLoop *runLoop;
@property (nonatomic, strong) DSChain *chain;
@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, assign) uint64_t receivedOrphanCount;
@property (nonatomic, assign) NSTimeInterval mempoolRequestTime;
@property (nonatomic, strong) dispatch_semaphore_t outputBufferSemaphore;
@property (strong, nonatomic) dispatch_source_t mempoolTimer;

@end

@implementation DSPeer

@dynamic host;

+ (instancetype)peerWithAddress:(UInt128)address andPort:(uint16_t)port onChain:(DSChain *)chain {
    return [[self alloc] initWithAddress:address andPort:port onChain:chain];
}

+ (instancetype)peerWithHost:(NSString *)host onChain:(DSChain *)chain {
    return [[self alloc] initWithHost:host onChain:chain];
}

+ (instancetype)peerWithSimplifiedMasternodeEntry:(DSSimplifiedMasternodeEntry *)simplifiedMasternodeEntry {
    return [[self alloc] initWithSimplifiedMasternodeEntry:simplifiedMasternodeEntry];
}

- (instancetype)initWithAddress:(UInt128)address andPort:(uint16_t)port onChain:(DSChain *)chain {
    if (!(self = [super init])) return nil;

    _address = address;
    _port = (port == 0) ? [chain standardPort] : port;
    self.chain = chain;
    _outputBufferSemaphore = dispatch_semaphore_create(1);
    return self;
}

- (instancetype)initWithSimplifiedMasternodeEntry:(DSSimplifiedMasternodeEntry *)simplifiedMasternodeEntry {
    return [self initWithAddress:simplifiedMasternodeEntry.address andPort:simplifiedMasternodeEntry.port onChain:simplifiedMasternodeEntry.chain];
}

- (instancetype)initWithHost:(NSString *)host onChain:(DSChain *)chain {
    if (!chain) return nil;
    if (!host) return nil;
    if (!(self = [super init])) return nil;

    NSArray *pair = [host componentsSeparatedByString:@":"];
    struct in_addr addr;

    if (pair.count > 1) {
        host = [[pair subarrayWithRange:NSMakeRange(0, pair.count - 1)] componentsJoinedByString:@":"];
        _port = [pair.lastObject intValue];
    }

    if (inet_pton(AF_INET, host.UTF8String, &addr) != 1) return nil;
    _address = (UInt128){.u32 = {0, 0, CFSwapInt32HostToBig(0xffff), addr.s_addr}};
    if (_port == 0) _port = chain.standardPort;
    self.chain = chain;
    _outputBufferSemaphore = dispatch_semaphore_create(1);
    return self;
}

- (instancetype)initWithAddress:(UInt128)address port:(uint16_t)port onChain:(DSChain *)chain timestamp:(NSTimeInterval)timestamp
                       services:(uint64_t)services {
    if (!(self = [self initWithAddress:address andPort:port onChain:chain])) return nil;

    _timestamp = timestamp;
    _services = services;
    return self;
}

- (void)dealloc {
    if (self.reachabilityObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.reachabilityObserver];
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

- (void)setChainDelegate:(id<DSPeerChainDelegate>)chainDelegate peerDelegate:(id<DSPeerDelegate>)peerDelegate transactionDelegate:(id<DSPeerTransactionDelegate>)transactionDelegate governanceDelegate:(id<DSPeerGovernanceDelegate>)governanceDelegate sporkDelegate:(id<DSPeerSporkDelegate>)sporkDelegate masternodeDelegate:(id<DSPeerMasternodeDelegate>)masternodeDelegate queue:(dispatch_queue_t)delegateQueue {
    _peerChainDelegate = chainDelegate;
    _peerDelegate = peerDelegate;
    _transactionDelegate = transactionDelegate;
    _governanceDelegate = governanceDelegate;
    _sporkDelegate = sporkDelegate;
    _masternodeDelegate = masternodeDelegate;

    _delegateQueue = (delegateQueue) ? delegateQueue : dispatch_get_main_queue();
}

- (NSString *)location {
    return [NSString stringWithFormat:@"%@:%d", self.host, self.port];
}

- (NSString *)debugLocation {
    return [NSString stringWithFormat:@"[%@: %@]", self.chain.name, self.location];
}

- (NSString *)host {
    char s[INET6_ADDRSTRLEN];

    if (_address.u64[0] == 0 && _address.u32[2] == CFSwapInt32HostToBig(0xffff)) {
        return @(inet_ntop(AF_INET, &_address.u32[3], s, sizeof(s)));
    } else
        return @(inet_ntop(AF_INET6, &_address, s, sizeof(s)));
}

- (void)connect {
    if (self.status != DSPeerStatus_Disconnected) return;
    _status = DSPeerStatus_Connecting;
    _pingTime = DBL_MAX;
    if (!self.reachability) self.reachability = [DSReachabilityManager sharedManager];

    if (self.reachability.networkReachabilityStatus == DSReachabilityStatusNotReachable) { // delay connect until network is reachable
        DSLogWithLocation(self, @"not reachable, waiting...");
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!self.reachabilityObserver) {
                self.reachabilityObserver =
                    [[NSNotificationCenter defaultCenter] addObserverForName:DSReachabilityDidChangeNotification
                                                                      object:nil
                                                                       queue:nil
                                                                  usingBlock:^(NSNotification *note) {
                        if (self.reachabilityObserver && self.reachability.networkReachabilityStatus != DSReachabilityStatusNotReachable) {
                            self->_status = DSPeerStatus_Disconnected;
                            [self connect];
                        }
                    }];
                if (!self.reachability.monitoring) {
                    [self.reachability startMonitoring];
                }
            }
        });

        return;
    } else if (self.reachabilityObserver) {
        self.reachability = nil;
        [[NSNotificationCenter defaultCenter] removeObserver:self.reachabilityObserver];
        self.reachabilityObserver = nil;
    }

    self.receivedOrphanCount = 0;
    self.msgHeader = [NSMutableData data];
    self.msgPayload = [NSMutableData data];
    self.outputBuffer = [NSMutableData data];
    self.gotVerack = self.sentVerack = NO;
    self.sentFilter = self.sentGetaddr = self.sentGetdataTxBlocks = self.sentGetdataMasternode = self.sentMempool = self.sentGetblocks = NO;
    self.needsFilterUpdate = NO;
    self.knownTxHashes = [NSMutableOrderedSet orderedSet];
    self.knownInstantSendLockHashes = [NSMutableOrderedSet orderedSet];
    self.knownInstantSendLockDHashes = [NSMutableOrderedSet orderedSet];
    self.knownBlockHashes = [NSMutableOrderedSet orderedSet];
    self.knownChainLockHashes = [NSMutableOrderedSet orderedSet];
    self.knownGovernanceObjectHashes = [NSMutableOrderedSet orderedSet];
    self.knownGovernanceObjectVoteHashes = [NSMutableOrderedSet orderedSet];
    self.currentBlock = nil;
    self.currentBlockTxHashes = nil;

    self.managedObjectContext = [NSManagedObjectContext peerContext];
    [self.managedObjectContext performBlockAndWait:^{
        NSArray<DSTransactionHashEntity *> *transactionHashEntities = [DSTransactionHashEntity standaloneTransactionHashEntitiesOnChainEntity:[self.chain chainEntityInContext:self.managedObjectContext]];
        for (DSTransactionHashEntity *hashEntity in transactionHashEntities) {
            [self.knownTxHashes addObject:hashEntity.txHash];
        }
    }];


    NSString *label = [NSString stringWithFormat:@"peer.%@:%u", self.host, self.port];

    // use a private serial queue for processing socket io
    dispatch_async(dispatch_queue_create(label.UTF8String, NULL), ^{
        CFReadStreamRef readStream = NULL;
        CFWriteStreamRef writeStream = NULL;
        DSLogWithLocation(self, @"connecting");
        CFStreamCreatePairWithSocketToHost(NULL, (__bridge CFStringRef)self.host, self.port, &readStream, &writeStream);
        self.inputStream = CFBridgingRelease(readStream);
        self.outputStream = CFBridgingRelease(writeStream);
        self.inputStream.delegate = self.outputStream.delegate = self;
        self.runLoop = [NSRunLoop currentRunLoop];
        [self.inputStream scheduleInRunLoop:self.runLoop forMode:NSRunLoopCommonModes];
        [self.outputStream scheduleInRunLoop:self.runLoop forMode:NSRunLoopCommonModes];

        // after the reachablity check, the radios should be warmed up and we can set a short socket connect timeout
        [self performSelector:@selector(disconnectWithError:)
                   withObject:[NSError errorWithCode:DASH_PEER_TIMEOUT_CODE localizedDescriptionKey:@"Connect timeout"]
                   afterDelay:CONNECT_TIMEOUT];

        [self.inputStream open];
        [self.outputStream open];
        [self sendVersionMessage];
        [self.runLoop run]; // this doesn't return until the runloop is stopped
    });
}

- (void)disconnect {
    [self disconnectWithError:nil];
}

- (void)disconnectWithError:(NSError *)error {
    if (_status == DSPeerStatus_Disconnected) return;
    DSLogWithLocation(self, @"Disconnected from peer (%@ protocol %d) with error: %@", self.useragent, self.version, error ? error : @"(None)");
    [NSObject cancelPreviousPerformRequestsWithTarget:self]; // cancel connect timeout

    _status = DSPeerStatus_Disconnected;
    if (self.reachabilityObserver) {
        self.reachability = nil;
        [[NSNotificationCenter defaultCenter] removeObserver:self.reachabilityObserver];
        self.reachabilityObserver = nil;
    }

    if (!self.runLoop) return;
    [self.inputStream close];
    [self.outputStream close];
    
    CFRunLoopStop([self.runLoop getCFRunLoop]);

    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    while (self.pongHandlers.count) {
        ((void (^)(BOOL))self.pongHandlers[0])(NO);
        [self.pongHandlers removeObjectAtIndex:0];
    }
    if (self.mempoolTransactionCompletion)
        self.mempoolTransactionCompletion(NO, YES, YES);
    self.mempoolTransactionCompletion = nil;
    [self dispatchAsyncInDelegateQueue:^{
        [self.peerDelegate peer:self disconnectedWithError:error];
    }];
}

- (void)error:(NSString *)message, ... NS_FORMAT_FUNCTION(1, 2) {
    va_list args;

    va_start(args, message);
    [self disconnectWithError:[NSError errorWithCode:500 descriptionKey:[[NSString alloc] initWithFormat:message arguments:args]]];
    va_end(args);
}

- (void)didConnect {
    if (self.status != DSPeerStatus_Connecting || !self.sentVerack || !self.gotVerack) return;

    DSLogWithLocation(self, @"handshake completed %@", (self.peerDelegate.downloadPeer == self) ? @"(download peer)" : @"");
    [NSObject cancelPreviousPerformRequestsWithTarget:self]; // cancel pending handshake timeout
    _status = DSPeerStatus_Connected;

    [self dispatchAsyncInDelegateQueue:^{
        if (self->_status == DSPeerStatus_Connected) [self.peerDelegate peerConnected:self];
    }];
}

- (void)receivedOrphanBlock {
    self.receivedOrphanCount++;
    if (self.receivedOrphanCount > 9) { //after 10 orphans mark this peer as bad by saying we got a bad block
        [self.transactionDelegate peer:self relayedTooManyOrphanBlocks:self.receivedOrphanCount];
    }
}

// MARK: - send

- (void)sendRequest:(DSMessageRequest *)request {
    NSString *type = [request type];
    NSData *payload = [request toData];
    //DSLog(@"%@:%u sendRequest: [%@]: %@", self.host, self.port, type, [payload hexString]);
    [self sendMessage:payload type:type];
}

- (void)sendMessage:(NSData *)message type:(NSString *)type {
    if (message.length > MAX_MSG_LENGTH) {
        DSLogWithLocation(self, @"failed to send %@, length %u is too long", type, (int)message.length);
#if DEBUG
        abort();
#endif
        return;
    }
    if (!self.runLoop) return;
    CFRunLoopPerformBlock([self.runLoop getCFRunLoop], kCFRunLoopCommonModes, ^{
#if MESSAGE_LOGGING
        if (![type isEqualToString:MSG_GETDATA] && ![type isEqualToString:MSG_VERSION] && ![type isEqualToString:MSG_GETBLOCKS]) { //we log this somewhere else for better accuracy of what data is being got
            DSLogWithLocation(self, @"%@sending %@", self.peerDelegate.downloadPeer == self ? @"(download peer) " : @"", type);
#if MESSAGE_IN_DEPTH_TX_LOGGING
            if ([type isEqualToString:@"ix"] || [type isEqualToString:@"tx"]) {
                DSTransaction *transactionBeingSent = [DSTransaction transactionWithMessage:message onChain:self.chain];
#if DEBUG
                DSLogPrivateWithLocation(self, @"transaction %@", transactionBeingSent.longDescription);
#else
                DSLogWithLocation(self, @"transaction %@", @"<REDACTED>");
#endif
            }
#endif
#if MESSAGE_CONTENT_LOGGING
#if DEBUG
            DSLogPrivateWithLocation(self, @"sending data (%lu bytes) %@", (unsigned long)message.length, message.hexString);
#else
            DSLogWithLocation(self, @"sending data (%lu bytes) %@", (unsigned long)message.length, @"<REDACTED>");
#endif
#endif
        }
#endif
        LOCK(self.outputBufferSemaphore);
        [self.outputBuffer appendMessage:message type:type forChain:self.chain];
        while (self.outputBuffer.length > 0 && self.outputStream.hasSpaceAvailable) {
            NSInteger l = [self.outputStream write:self.outputBuffer.bytes maxLength:self.outputBuffer.length];
            if (l > 0) [self.outputBuffer replaceBytesInRange:NSMakeRange(0, l) withBytes:NULL length:0];
            //if (self.outputBuffer.length == 0) DSLog(@"%@:%u output buffer cleared", self.host, self.port);
        }

        UNLOCK(self.outputBufferSemaphore);
    });
    CFRunLoopWakeUp([self.runLoop getCFRunLoop]);
}

- (void)sendVersionMessage {
    self.localNonce = ((uint64_t)arc4random() << 32) | (uint64_t)arc4random();                // random nonce
    NSString *agent;
    if (self.chain.isMainnet) {
        agent = [USER_AGENT stringByAppendingString:@"/"];
    } else if (self.chain.isTestnet) {
        agent = [USER_AGENT stringByAppendingString:@"(testnet)/"];
//    } else if (self.chain.protocolVersion >= 70220) {
//        agent = [USER_AGENT stringByAppendingString:[NSString stringWithFormat:@"(devnet.%u.%@)/", self.chain.devnetVersion, self.chain.devnetIdentifier]];
    } else {
        agent = [USER_AGENT stringByAppendingString:[NSString stringWithFormat:@"(devnet.%@)/", [DSKeyManager devnetIdentifierFor:self.chain.chainType]]];
    }
    DSVersionRequest *request = [DSVersionRequest requestWithAddress:_address
                                                                port:self.port
                                                     protocolVersion:self.chain.protocolVersion
                                                            services:self.services
                                                        standardPort:self.chain.standardPort
                                                          localNonce:self.localNonce
                                                           userAgent:agent];
    self.pingStartTime = [NSDate timeIntervalSince1970];

#if MESSAGE_LOGGING
    DSLogWithLocation(self, @"%@sending version with protocol version %d user agent %@", self.peerDelegate.downloadPeer == self ? @"(download peer) " : @"", self.chain.protocolVersion, agent);
#endif
    [self sendRequest:request];
}

- (void)sendVerackMessage {
    [self sendRequest:[DSMessageRequest requestWithType:MSG_VERACK]];
    self.sentVerack = YES;
    [self didConnect];
}

- (void)sendFilterloadMessage:(NSData *)filter {
    @synchronized (self) {
        self.sentFilter = YES;
    }
#if DEBUG
    DSLogPrivateWithLocation(self, @"Sending filter with fingerprint %@ to node %@", [NSData dataWithUInt256:filter.SHA256].shortHexString, self.peerDelegate.downloadPeer == self ? @"(download peer) " : @"");
#else
    DSLogWithLocation(self, @"Sending filter with fingerprint %@ to node %@", @"<REDACTED>", self.peerDelegate.downloadPeer == self ? @"(download peer) " : @"");
#endif
    [self sendRequest:[DSFilterLoadRequest requestWithBloomFilterData:filter]];
}

/**
 This method sends a mempool message to the connected peer for information about transactions in the memory pool of a peer.
 It is used to synchronize the local view of the peer's memory pool with the transactions known locally.

 @param publishedTxHashes An array of transaction hashes that the client has knowledge of. These are used to update the internal list of known transaction hashes.
 @param completion A completion block that is called when the mempool message processing is complete. This block is provided with three boolean arguments indicating various states of the transaction processing (e.g., if it was added, already known, or rejected).
*/
- (void)sendMempoolMessage:(NSArray *)publishedTxHashes completion:(MempoolCompletionBlock)completion {
#if DEBUG
    DSLogPrivateWithLocation(self, @"sendMempoolMessage %@", publishedTxHashes);
#else
    DSLogWithLocation(self, @"sendMempoolMessage %@", @"<REDACTED>");
#endif
    @synchronized (self.knownTxHashes) {
        [self.knownTxHashes addObjectsFromArray:publishedTxHashes];
    }
    self.sentMempool = YES;
    [self cancelMempoolTimer];
    @synchronized (self) {
        if (completion) {
            if (self.mempoolTransactionCompletion) {
                [self dispatchAsyncInDelegateQueue:^{
                    if (self->_status == DSPeerStatus_Connected) completion(NO, NO, NO);
                }];
            } else {
                self.mempoolTransactionCompletion = completion;
                self.mempoolTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.delegateQueue);
                if (self.mempoolTimer) {
                    dispatch_source_set_timer(self.mempoolTimer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(MEMPOOL_TIMEOUT * NSEC_PER_SEC)), DISPATCH_TIME_FOREVER, 1ull * NSEC_PER_SEC);
                    dispatch_source_set_event_handler(self.mempoolTimer, ^{
                        if ([NSDate timeIntervalSince1970] - self.mempoolRequestTime >= MEMPOOL_TIMEOUT) {
                            [self mempoolTimeout];
                        }
                    });
                    dispatch_resume(self.mempoolTimer);
                }
            }
        }
    }

    self.mempoolRequestTime = [NSDate timeIntervalSince1970];
    [self sendRequest:[DSMessageRequest requestWithType:MSG_MEMPOOL]];
}

- (void)cancelMempoolTimer {
    @synchronized (self) {
        if (self.mempoolTimer) {
            dispatch_source_cancel(self.mempoolTimer);
            self.mempoolTimer = nil;
        }
    }
}
- (void)mempoolTimeout {
    DSLogWithLocation(self, @"[DSPeer] mempool time out");
    __block MempoolCompletionBlock completion = self.mempoolTransactionCompletion;
    [self sendPingMessageWithPongHandler:^(BOOL success) {
        if (completion) {
            completion(success, YES, NO);
        }
    }];
    self.mempoolTransactionCompletion = nil;
}

// the standard blockchain download protocol works as follows (for SPV mode):
// - local peer sends getblocks
// - remote peer reponds with inv containing up to 500 block hashes
// - local peer sends getdata with the block hashes
// - remote peer responds with multiple merkleblock and tx messages
// - remote peer sends inv containg 1 hash, of the most recent block
// - local peer sends getdata with the most recent block hash
// - remote peer responds with merkleblock
// - if local peer can't connect the most recent block to the chain (because it started more than 500 blocks behind), go
//   back to first step and repeat until entire chain is downloaded
//
// we modify this sequence to improve sync performance and handle adding bip32 addresses to the bloom filter as needed:
// - local peer sends getheaders
// - remote peer responds with up to 2000 headers
// - local peer immediately sends getheaders again and then processes the headers
// - previous two steps repeat until a header within a week of earliestKeyTime is reached (further headers are ignored)
// - local peer sends getblocks
// - remote peer responds with inv containing up to 500 block hashes
// - local peer sends getdata with the block hashes
// - if there were 500 hashes, local peer sends getblocks again without waiting for remote peer
// - remote peer responds with multiple merkleblock and tx messages, followed by inv containing up to 500 block hashes
// - previous two steps repeat until an inv with fewer than 500 block hashes is received
// - local peer sends just getdata for the final set of fewer than 500 block hashes
// - remote peer responds with multiple merkleblock and tx messages
// - if at any point tx messages consume enough wallet addresses to drop below the bip32 chain gap limit, more addresses
//   are generated and local peer sends filterload with an updated bloom filter
// - after filterload is sent, getdata is sent to re-request recent blocks that may contain new tx matching the filter

- (void)sendGetheadersMessageWithLocators:(NSArray *)locators andHashStop:(UInt256)hashStop {
    DSGetHeadersRequest *request = [DSGetHeadersRequest requestWithLocators:locators andHashStop:hashStop protocolVersion:self.chain.protocolVersion];
    if (self.relayStartTime == 0)
        self.relayStartTime = [NSDate timeIntervalSince1970];
    [self sendRequest:request];
}

- (void)sendGetblocksMessageWithLocators:(NSArray *)locators andHashStop:(UInt256)hashStop {
    DSGetBlocksRequest *request = [DSGetBlocksRequest requestWithLocators:locators andHashStop:hashStop protocolVersion:self.chain.protocolVersion];
    self.sentGetblocks = YES;

#if MESSAGE_LOGGING
    NSMutableArray *locatorHexes = [NSMutableArray arrayWithCapacity:[locators count]];
    [locators enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        uint32_t knownHeight = [self.chain quickHeightForBlockHash:((NSData *)obj).UInt256];
        [locatorHexes addObject:[NSString stringWithFormat:@"%@ (block height %d)",
                                 ((NSData *)obj).reverse.hexString,
                                 knownHeight == UINT32_MAX ? 0 : knownHeight]];
    }];
#if DEBUG
    DSLogPrivateWithLocation(self, @"%@sending getblocks with locators %@", self.peerDelegate.downloadPeer == self ? @"(download peer) " : @"", locatorHexes);
#else
    DSLogWithLocation(self, @"%@sending getblocks with locators %@", self.peerDelegate.downloadPeer == self ? @"(download peer) " : @"", @"<REDACTED>");
#endif
//#if MESSAGE_CONTENT_LOGGING
//#if DEBUG
//    DSLogPrivate(@"%@:%u sending data %@", self.host, self.port, msg.hexString);
//#else
//    DSLog(@"%@:%u sending data %@", self.host, self.port, @"<REDACTED>");
//#endif
//#endif
#endif

    [self sendRequest:request];
}

- (void)sendInvMessageForHashes:(NSArray *)invHashes ofType:(DSInvType)invType {
    DSLogPrivateWithLocation(self, @"sending inv message of type %@ hashes count %lu", [self nameOfInvMessage:invType], invHashes.count);
    NSMutableOrderedSet *hashes = [NSMutableOrderedSet orderedSetWithArray:invHashes];
    @synchronized (self.knownTxHashes) {
        [hashes minusOrderedSet:self.knownTxHashes];
    }
    if (hashes.count == 0) return;
    DSInvRequest *request = [DSInvRequest requestWithHashes:hashes ofInvType:invType];
    [self sendRequest:request];
    
    switch (invType) {
        case DSInvType_Tx:
            @synchronized (self.knownTxHashes) {
                [self.knownTxHashes unionOrderedSet:hashes];
            }
            break;
        case DSInvType_GovernanceObjectVote:
            [self.knownGovernanceObjectVoteHashes unionOrderedSet:hashes];
            break;
        case DSInvType_GovernanceObject:
            [self.knownGovernanceObjectHashes unionOrderedSet:hashes];
            break;
        case DSInvType_Block:
            [self.knownBlockHashes unionOrderedSet:hashes];
            break;
        case DSInvType_ChainLockSignature:
            [self.knownChainLockHashes unionOrderedSet:hashes];
            break;
        default:
            break;
    }
}

- (void)sendTransactionInvMessagesforTransactionHashes:(NSArray *)txInvHashes txLockRequestHashes:(NSArray *)txLockRequestInvHashes {
    NSMutableOrderedSet *txHashes = txInvHashes ? [NSMutableOrderedSet orderedSetWithArray:txInvHashes] : nil;
    NSMutableOrderedSet *txLockRequestHashes = txLockRequestInvHashes ? [NSMutableOrderedSet orderedSetWithArray:txLockRequestInvHashes] : nil;
    @synchronized (self.knownTxHashes) {
        [txHashes minusOrderedSet:self.knownTxHashes];
        [txLockRequestHashes minusOrderedSet:self.knownTxHashes];
    }
    if (txHashes.count + txLockRequestHashes.count == 0) return;
    DSTransactionInvRequest *request = [DSTransactionInvRequest requestWithTransactionHashes:txHashes txLockRequestHashes:txLockRequestHashes];
    [self sendRequest:request];
    @synchronized (self.knownTxHashes) {
        txHashes ? [self.knownTxHashes unionOrderedSet:txHashes] : nil;
        txLockRequestHashes ? [self.knownTxHashes unionOrderedSet:txLockRequestHashes] : nil;
    }
}

- (void)sendGetdataMessageForTxHash:(UInt256)txHash {
    if (!([[DSOptionsManager sharedInstance] syncType] & DSSyncType_GetsNewBlocks)) return;
    DSGetDataForTransactionHashRequest *request = [DSGetDataForTransactionHashRequest requestForTransactionHash:txHash];
#if MESSAGE_LOGGING
#if DEBUG
    DSLogPrivateWithLocation(self, @"sending getdata for transaction %@", uint256_hex(txHash));
#else
    DSLogWithLocation(self, @"sending getdata for transaction %@", @"<REDACTED>");
#endif
#endif
    [self sendRequest:request];
}

- (void)sendGetdataMessageWithTxHashes:(NSArray *)txHashes instantSendLockHashes:(NSArray *)instantSendLockHashes instantSendLockDHashes:(NSArray *)instantSendLockDHashes blockHashes:(NSArray *)blockHashes chainLockHashes:(NSArray *)chainLockHashes {
    if (!([[DSOptionsManager sharedInstance] syncType] & DSSyncType_GetsNewBlocks)) return;
    NSUInteger totalCount = txHashes.count + instantSendLockHashes.count + instantSendLockDHashes.count + blockHashes.count + chainLockHashes.count;
    if (totalCount > MAX_GETDATA_HASHES) { // limit total hash count to MAX_GETDATA_HASHES
        DSLogWithLocation(self, @"couldn't send getdata, %lu is too many items, max is %u", totalCount, MAX_GETDATA_HASHES);
        return;
    } else if (totalCount == 0)
        return;

    DSGetDataForTransactionHashesRequest *request = [DSGetDataForTransactionHashesRequest requestForTransactionHashes:txHashes
                                                                                                instantSendLockHashes:instantSendLockHashes
                                                                                               instantSendLockDHashes:instantSendLockDHashes
                                                                                                          blockHashes:blockHashes
                                                                                                      chainLockHashes:chainLockHashes];
    self.sentGetdataTxBlocks = YES;
#if MESSAGE_LOGGING
    DSLogWithLocation(self, @"sending getdata (transactions and blocks)");
#endif
    [self sendRequest:request];
}

- (void)sendGovernanceRequest:(DSGovernanceHashesRequest *)request {
    if (request.hashes.count > MAX_GETDATA_HASHES) { // limit total hash count to MAX_GETDATA_HASHES
        DSLogWithLocation(self, @"couldn't send governance votes getdata, %lu is too many items, max is %u", request.hashes.count, MAX_GETDATA_HASHES);
        return;
    } else if (request.hashes.count == 0) {
        DSLogWithLocation(self, @"couldn't send governance getdata, there is no items");
        return;
    }
    
    #if MESSAGE_LOGGING
        DSLogWithLocation(self, @"sending getdata (%@)", request.description);
    #endif
    
    // Not used
    [self sendRequest:request];
}

- (void)sendGetaddrMessage {
    self.sentGetaddr = YES;
    [self sendRequest:[DSMessageRequest requestWithType:MSG_GETADDR]];
}

- (void)sendPingMessageWithPongHandler:(void (^)(BOOL success))pongHandler {
    if (!self.pongHandlers) self.pongHandlers = [NSMutableArray array];
    [self.pongHandlers addObject:(pongHandler) ? [pongHandler copy] : [^(BOOL success) {} copy]];
    uint64_t localNonce = self.localNonce;
    self.pingStartTime = [NSDate timeIntervalSince1970];

#if MESSAGE_LOGGING
    DSLogWithLocation(self, @"sending ping");
#endif
    [self dispatchAsyncInDelegateQueue:^{
        [self sendRequest:[DSPingRequest requestWithLocalNonce:localNonce]];
    }];
}

// re-request blocks starting from blockHash, useful for getting any additional transactions after a bloom filter update
- (void)rerequestBlocksFrom:(UInt256)blockHash {
    NSUInteger i = [self.knownBlockHashes indexOfObject:uint256_obj(blockHash)];

    if (i != NSNotFound) {
        [self.knownBlockHashes removeObjectsInRange:NSMakeRange(0, i)];
        DSLogWithLocation(self, @"re-requesting %lu blocks", self.knownBlockHashes.count);
        [self sendGetdataMessageWithTxHashes:nil instantSendLockHashes:nil instantSendLockDHashes:nil blockHashes:self.knownBlockHashes.array chainLockHashes:nil];
    }
}

// MARK: - send Dash Sporks

- (void)sendGetSporks {
    [self sendRequest:[DSMessageRequest requestWithType:MSG_GETSPORKS]];
}

// MARK: - send Dash Governance

// Governance Synchronization for Votes and Objects
- (void)sendGovernanceSyncRequest:(DSGovernanceSyncRequest *)request {
    // Make sure we aren't in a governance sync process
    DSLogWithLocation(self, @"Requesting Governance Object Vote Hashes");
    if (self.governanceRequestState != DSGovernanceRequestState_None) {
        DSLog(@"[%@: %@:%d] Requesting Governance Object Hashes out of resting state", self.chain.name, self.host, self.port);
        return;
    }

    DSLogWithLocation(self, @"Requesting %@", request.description);
    self.governanceRequestState = request.state;
    
    [self sendRequest:request];
    
    if (request.state == DSGovernanceRequestState_GovernanceObjectHashes) {
        //we aren't afraid of coming back here within 5 seconds because a peer can only sendGovSync once every 3 hours
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (self.governanceRequestState == DSGovernanceRequestState_GovernanceObjectHashes) {
                DSLogWithLocation(self, @"Peer ignored request for governance object hashes");
                [self.governanceDelegate peer:self ignoredGovernanceSync:DSGovernanceRequestState_GovernanceObjectHashes];
            }
        });
    }
}

- (void)sendGovObjectVote:(DSGovernanceVote *)governanceVote {
    [self sendMessage:[governanceVote dataMessage] type:MSG_GOVOBJVOTE];
}

- (void)sendGovObject:(DSGovernanceObject *)governanceObject {
    [self sendMessage:[governanceObject dataMessage] type:MSG_GOVOBJ];
}


// MARK: - accept

- (void)acceptMessage:(NSData *)message type:(NSString *)type {
#if MESSAGE_LOGGING
    if (![type isEqualToString:MSG_INV] && ![type isEqualToString:MSG_GOVOBJVOTE] && ![type isEqualToString:MSG_MERKLEBLOCK]) {
        DSLogWithLocation(self, @"accept message %@", type);
    }
#endif
    if (self.currentBlock && (!([MSG_TX isEqual:type] || [MSG_IX isEqual:type] || [MSG_ISLOCK isEqual:type]))) {
        // if we receive a non-tx message, merkleblock is done
        UInt256 hash = self.currentBlock.blockHash;
        NSUInteger txExpected = self.currentBlockTxHashes.count;
        self.currentBlock = nil;
        self.currentBlockTxHashes = nil;
        [self error:@"incomplete merkleblock %@, expected %lu more tx, got %@",
              uint256_obj(hash), txExpected, type];
    } else if ([MSG_VERSION isEqual:type])
        [self acceptVersionMessage:message];
    else if ([MSG_VERACK isEqual:type])
        [self acceptVerackMessage:message];
    else if ([MSG_ADDR isEqual:type])
        [self acceptAddrMessage:message];
    else if ([MSQ_SENDADDRV2 isEqual:type])
        [self acceptAddrV2Message:message];
    else if ([MSG_INV isEqual:type])
        [self acceptInvMessage:message];
    else if ([MSG_TX isEqual:type])
        [self acceptTxMessage:message];
    else if ([MSG_IX isEqual:type])
        [self acceptTxMessage:message];
    else if ([MSG_ISLOCK isEqual:type])
        [self acceptIslockMessage:message];
    else if ([MSG_ISDLOCK isEqual:type])
        [self acceptIsdlockMessage:message];
    else if ([MSG_HEADERS isEqual:type])
        [self acceptHeadersMessage:message];
    else if ([MSG_GETADDR isEqual:type])
        [self acceptGetaddrMessage:message];
    else if ([MSG_GETDATA isEqual:type])
        [self acceptGetdataMessage:message];
    else if ([MSG_NOTFOUND isEqual:type])
        [self acceptNotfoundMessage:message];
    else if ([MSG_PING isEqual:type])
        [self acceptPingMessage:message];
    else if ([MSG_PONG isEqual:type])
        [self acceptPongMessage:message];
    else if ([MSG_MERKLEBLOCK isEqual:type])
        [self acceptMerkleblockMessage:message];
    else if ([MSG_CHAINLOCK isEqual:type])
        [self acceptChainLockMessage:message];
    else if ([MSG_REJECT isEqual:type])
        [self acceptRejectMessage:message];
    else if ([MSG_FEEFILTER isEqual:type])
        [self acceptFeeFilterMessage:message];
    //control
    else if ([MSG_SPORK isEqual:type])
        [self acceptSporkMessage:message];
    //masternode
    else if ([MSG_SSC isEqual:type])
        [self acceptSSCMessage:message];
    else if ([MSG_MNB isEqual:type])
        [self acceptMNBMessage:message];
    else if ([MSG_MNLISTDIFF isEqual:type])
        [self acceptMNLISTDIFFMessage:message];
    else if ([MSG_QUORUMROTATIONINFO isEqual:type])
        [self acceptQRInfoMessage:message];
    //governance
    else if ([MSG_GOVOBJVOTE isEqual:type])
        [self acceptGovObjectVoteMessage:message];
    else if ([MSG_GOVOBJ isEqual:type])
        [self acceptGovObjectMessage:message];
    //else if ([MSG_GOVOBJSYNC isEqual:type]) [self acceptGovObjectSyncMessage:message];

    //private send
    else if ([MSG_DARKSENDANNOUNCE isEqual:type])
        [self acceptDarksendAnnounceMessage:message];
    else if ([MSG_DARKSENDCONTROL isEqual:type])
        [self acceptDarksendControlMessage:message];
    else if ([MSG_DARKSENDFINISH isEqual:type])
        [self acceptDarksendFinishMessage:message];
    else if ([MSG_DARKSENDINITIATE isEqual:type])
        [self acceptDarksendInitiateMessage:message];
    else if ([MSG_DARKSENDQUORUM isEqual:type])
        [self acceptDarksendQuorumMessage:message];
    else if ([MSG_DARKSENDSESSION isEqual:type])
        [self acceptDarksendSessionMessage:message];
    else if ([MSG_DARKSENDSESSIONUPDATE isEqual:type])
        [self acceptDarksendSessionUpdateMessage:message];
    else if ([MSG_DARKSENDTX isEqual:type])
        [self acceptDarksendTransactionMessage:message];
#if DROP_MESSAGE_LOGGING
    else {
        DSLogWithLocation(self, @"dropping %@, len:%u, not implemented", type, message.length);
    }
#endif
}

- (void)acceptVersionMessage:(NSData *)message {
    NSNumber *l = nil;
    if (message.length < 85) {
        [self error:@"malformed version message, length is %u, should be > 84", (int)message.length];
        return;
    }
    _version = [message UInt32AtOffset:0];
    _services = [message UInt64AtOffset:4];
    _timestamp = [message UInt64AtOffset:12];
    _useragent = [message stringAtOffset:80 length:&l];
    if (message.length < 80 + l.unsignedIntegerValue + sizeof(uint32_t)) {
        [self error:@"malformed version message, length is %u, should be %u", (int)message.length, (int)(80 + l.unsignedIntegerValue + 4)];
        return;
    }
    _lastBlockHeight = [message UInt32AtOffset:80 + l.unsignedIntegerValue];

    if (self.version < self.chain.minProtocolVersion /*|| self.version > self.chain.protocolVersion*/) {
#if MESSAGE_LOGGING
        DSLogWithLocation(self, @"protocol version %u not supported, valid versions are: [%u, %u], useragent:\"%@\", ", self.version, self.chain.minProtocolVersion, self.chain.protocolVersion, self.useragent);
#endif
        [self error:@"protocol version %u not supported", self.version];
        return;
    } else {
#if MESSAGE_LOGGING
        DSLogWithLocation(self, @"got version %u, useragent:\"%@\"", self.version, self.useragent);
#endif
    }
    [self sendVerackMessage];
}

- (void)acceptVerackMessage:(NSData *)message {
    if (self.gotVerack) {
        DSLogWithLocation(self, @"got unexpected verack");
        return;
    }

    _pingTime = [NSDate timeIntervalSince1970] - self.pingStartTime; // use verack time as initial ping time
    self.pingStartTime = 0;
#if MESSAGE_LOGGING
    DSLogWithLocation(self, @"got verack in %fs", self.pingTime);
#endif
    self.gotVerack = YES;
    [self didConnect];
}

// TODO: relay addresses
- (void)acceptAddrMessage:(NSData *)message {
    if (message.length > 0 && [message UInt8AtOffset:0] == 0) {
        DSLogWithLocation(self, @"got addr with 0 addresses");
        return;
    } else if (message.length < 5) {
        [self error:@"malformed addr message, length %u is too short", (int)message.length];
        return;
    } else if (!self.sentGetaddr)
        return; // simple anti-tarpitting tactic, don't accept unsolicited addresses

    NSTimeInterval now = [NSDate timeIntervalSince1970];
    NSNumber *l = nil;
    NSUInteger count = (NSUInteger)[message varIntAtOffset:0 length:&l];
    NSMutableArray *peers = [NSMutableArray array];

    if (count > 1000) {
        DSLogWithLocation(self, @"dropping addr message, %lu is too many addresses (max 1000)", count);
        return;
    } else if (message.length < l.unsignedIntegerValue + count * 30) {
        [self error:@"malformed addr message, length is %u, should be %u for %u addresses", (int)message.length,
              (int)(l.unsignedIntegerValue + count * 30), (int)count];
        return;
    } else
        DSLogWithLocation(self, @"got addr with %lu addresses", count);

    for (NSUInteger off = l.unsignedIntegerValue; off < l.unsignedIntegerValue + 30 * count; off += 30) {
        NSTimeInterval timestamp = [message UInt32AtOffset:off];
        uint64_t services = [message UInt64AtOffset:off + sizeof(uint32_t)];
        UInt128 address = *(UInt128 *)((const uint8_t *)message.bytes + off + sizeof(uint32_t) + sizeof(uint64_t));
        uint16_t port = CFSwapInt16BigToHost(*(const uint16_t *)((const uint8_t *)message.bytes + off +
                                                                 sizeof(uint32_t) + sizeof(uint64_t) +
                                                                 sizeof(UInt128)));

        if (!(services & SERVICES_NODE_NETWORK)) continue;                                   // skip peers that don't carry full blocks
        if (address.u64[0] != 0 || address.u32[2] != CFSwapInt32HostToBig(0xffff)) continue; // ignore IPv6 for now

        // if address time is more than 10 min in the future or older than reference date, set to 5 days old
        if (timestamp > now + 10 * 60 || timestamp < 0) timestamp = now - 5 * 24 * 60 * 60;

        // subtract two hours and add it to the list
        [peers addObject:[[DSPeer alloc] initWithAddress:address
                                                    port:port
                                                 onChain:self.chain
                                               timestamp:timestamp - 2 * 60 * 60
                                                services:services]];
    }
    [self dispatchAsyncInDelegateQueue:^{
        if (self->_status == DSPeerStatus_Connected) [self.peerDelegate peer:self relayedPeers:peers];
    }];
}

- (void)acceptAddrV2Message:(NSData *)message {
    DSLogWithLocation(self, @"sendaddrv2, len:%lu, (not implemented)", message.length);
}

- (NSString *)nameOfInvMessage:(DSInvType)type {
    switch (type) {
        case DSInvType_Tx:
            return @"Tx";
        case DSInvType_Block:
            return @"Block";
        case DSInvType_Merkleblock:
            return @"Merkleblock";
        case DSInvType_TxLockRequest:
            return @"TxLockRequest";
        case DSInvType_TxLockVote:
            return @"TxLockVote";
        case DSInvType_Spork:
            return @"Spork";
        case DSInvType_MasternodePaymentVote:
            return @"MasternodePaymentVote";
        case DSInvType_MasternodePaymentBlock:
            return @"MasternodePaymentBlock";
        case DSInvType_MasternodeBroadcast:
            return @"MasternodeBroadcast";
        case DSInvType_MasternodePing:
            return @"MasternodePing";
        case DSInvType_DSTx:
            return @"DSTx";
        case DSInvType_GovernanceObject:
            return @"GovernanceObject";
        case DSInvType_GovernanceObjectVote:
            return @"GovernanceObjectVote";
        case DSInvType_MasternodeVerify:
            return @"MasternodeVerify";
        case DSInvType_Error:
            return @"Error";
        case DSInvType_CompactBlock:
            return @"CompactBlock";
        case DSInvType_DummyCommitment:
            return @"DummyCommitment";
        case DSInvType_QuorumContribution:
            return @"QuorumContribution";
        case DSInvType_QuorumFinalCommitment:
            return @"QuorumFinalCommitment";
        case DSInvType_ChainLockSignature:
            return @"ChainLockSignature";
        case DSInvType_InstantSendLock:
            return @"InstantSendLock";
        case DSInvType_InstantSendDeterministicLock:
            return @"InstantSendDeterministicLock";
        default:
            return @"";
    }
}

#define RANDOM_ERROR_INV 0

- (void)acceptInvMessage:(NSData *)message {
    NSNumber *l = nil;
    NSUInteger count = (NSUInteger)[message varIntAtOffset:0 length:&l];
    NSMutableOrderedSet *txHashes = [NSMutableOrderedSet orderedSet];
    NSMutableOrderedSet *instantSendLockHashes = [NSMutableOrderedSet orderedSet];
    NSMutableOrderedSet *instantSendLockDHashes = [NSMutableOrderedSet orderedSet];
    NSMutableOrderedSet *chainLockHashes = [NSMutableOrderedSet orderedSet];
    NSMutableOrderedSet *blockHashes = [NSMutableOrderedSet orderedSet];
    NSMutableSet *sporkHashes = [NSMutableSet set];
    NSMutableSet *governanceObjectHashes = [NSMutableSet set];
    NSMutableSet *governanceObjectVoteHashes = [NSMutableSet set];

    if (l.unsignedIntegerValue == 0 || message.length < l.unsignedIntegerValue + count * 36) {
        [self error:@"malformed inv message, length is %u, should be %u for %u items", (int)message.length,
              (int)(((l.unsignedIntegerValue == 0) ? 1 : l.unsignedIntegerValue) + count * 36), (int)count];
        return;
    } else if (count > MAX_GETDATA_HASHES) {
        DSLogWithLocation(self, @"dropping inv message, %lu is too many items, max is %u", count, MAX_GETDATA_HASHES);
        return;
    }
#if MESSAGE_LOGGING
    if (count == 0) {
        DSLogWithLocation(self, @"Got empty Inv message");
    }
    if (count > 0 && ([message UInt32AtOffset:l.unsignedIntegerValue] != DSInvType_MasternodePing) && ([message UInt32AtOffset:l.unsignedIntegerValue] != DSInvType_MasternodePaymentVote) && ([message UInt32AtOffset:l.unsignedIntegerValue] != DSInvType_MasternodeVerify) && ([message UInt32AtOffset:l.unsignedIntegerValue] != DSInvType_GovernanceObjectVote) && ([message UInt32AtOffset:l.unsignedIntegerValue] != DSInvType_DSTx)) {
        DSLogWithLocation(self, @"got inv with %u item%@ (first item %@ with hash %@/%@)", (int)count, count == 1 ? @"" : @"s", [self nameOfInvMessage:[message UInt32AtOffset:l.unsignedIntegerValue]], [NSData dataWithUInt256:[message UInt256AtOffset:l.unsignedIntegerValue + sizeof(uint32_t)]].hexString, [NSData dataWithUInt256:[message UInt256AtOffset:l.unsignedIntegerValue + sizeof(uint32_t)]].reverse.hexString);
    }
#endif
    BOOL onlyPrivateSendTransactions = NO;

    for (NSUInteger off = l.unsignedIntegerValue; off < l.unsignedIntegerValue + 36 * count; off += 36) {
        DSInvType type = [message UInt32AtOffset:off];
        UInt256 hash = [message UInt256AtOffset:off + sizeof(uint32_t)];

        if (uint256_is_zero(hash)) continue;

        if (off == l.unsignedIntegerValue && type == DSInvType_DSTx) {
            onlyPrivateSendTransactions = YES;
        }

        if (type != DSInvType_DSTx) {
            onlyPrivateSendTransactions = NO;
        }

        switch (type) {
            case DSInvType_Tx: [txHashes addObject:uint256_obj(hash)]; break;
            case DSInvType_TxLockRequest: [txHashes addObject:uint256_obj(hash)]; break;
            case DSInvType_DSTx: break;
            case DSInvType_TxLockVote: break;
            case DSInvType_InstantSendDeterministicLock: [instantSendLockDHashes addObject:uint256_obj(hash)]; break;
            case DSInvType_InstantSendLock: [instantSendLockHashes addObject:uint256_obj(hash)]; break;
            case DSInvType_Block: [blockHashes addObject:uint256_obj(hash)]; break;
            case DSInvType_Merkleblock: [blockHashes addObject:uint256_obj(hash)]; break;
            case DSInvType_Spork: [sporkHashes addObject:[NSData dataWithUInt256:hash]]; break;
            case DSInvType_GovernanceObject: [governanceObjectHashes addObject:[NSData dataWithUInt256:hash]]; break;
            case DSInvType_GovernanceObjectVote: break; //[governanceObjectVoteHashes addObject:[NSData dataWithUInt256:hash]]; break;
            case DSInvType_MasternodePing: break;       //[masternodePingHashes addObject:uint256_obj(hash)]; break;
            case DSInvType_MasternodePaymentVote: break;
            case DSInvType_MasternodeVerify: break;
            case DSInvType_MasternodeBroadcast: break;
            case DSInvType_QuorumFinalCommitment: break;
            case DSInvType_DummyCommitment: break;
            case DSInvType_QuorumContribution: break;
            case DSInvType_CompactBlock: break;
            case DSInvType_ChainLockSignature: [chainLockHashes addObject:uint256_obj(hash)]; break;
            case DSInvType_QuorumPrematureCommitment:
                DSLog(@"[%@: %@:%d] Send premature commitment containing the quorum public key (intra-quorum communication)", self.chain.name, self.host, self.port);
                break;
            default: {
                NSString *desc = [NSString stringWithFormat:@"inventory type not dealt with: %u", type];
                NSAssert(FALSE, desc);
                break;
            }
        }
    }
    uint32_t currentHeight;
    BOOL isFilterNotLoaded;
    @synchronized (self) {
        currentHeight = self.currentBlockHeight;
        isFilterNotLoaded = !self.sentFilter && !self.sentMempool && !self.sentGetblocks;
    }
    
    if ([self.chain syncsBlockchain] && isFilterNotLoaded && (txHashes.count > 0) && !onlyPrivateSendTransactions) {
        [self error:@"got tx inv message before loading a filter"];
        return;
    } else if (txHashes.count + instantSendLockHashes.count + instantSendLockDHashes.count > 10000) { // this was happening on testnet, some sort of DOS/spam attack?
        DSLogWithLocation(self, @"too many transactions, disconnecting");
        [self disconnect]; // disconnecting seems to be the easiest way to mitigate it
        return;
    } else if (currentHeight > 0 && blockHashes.count > 2 && blockHashes.count < 500 &&
               currentHeight + self.knownBlockHashes.count + blockHashes.count < self.lastBlockHeight) {
        [self error:@"non-standard inv, %u is fewer block hashes than expected", (int)blockHashes.count];
        return;
    }
#if RANDOM_ERROR_INV
    if (!(arc4random() % 10)) {
        [self error:@"random error for testing"];
        return;
    }
#endif

    if (blockHashes.count == 1 && [self.lastBlockHash isEqual:blockHashes[0]]) [blockHashes removeAllObjects];
    if (blockHashes.count == 1) self.lastBlockHash = blockHashes[0];

    if (blockHashes.count > 0) { // remember blockHashes in case we need to re-request them with an updated bloom filter
        [self dispatchAsyncInDelegateQueue:^{
            [self.knownBlockHashes unionOrderedSet:blockHashes];
            while (self.knownBlockHashes.count > MAX_GETDATA_HASHES) {
                [self.knownBlockHashes removeObjectsInRange:NSMakeRange(0, self.knownBlockHashes.count / 3)];
            }
        }];
    }
    @synchronized (self.knownTxHashes) {
        if ([txHashes intersectsOrderedSet:self.knownTxHashes]) { // remove transactions we already have
            for (NSValue *hash in txHashes) {
                UInt256 h;
                if (![self.knownTxHashes containsObject:hash]) continue;
                [hash getValue:&h];
                [self dispatchAsyncInDelegateQueue:^{
                    if (self->_status == DSPeerStatus_Connected) [self.transactionDelegate peer:self hasTransactionWithHash:h];
                }];
            }
            [txHashes minusOrderedSet:self.knownTxHashes];
        }
        [self.knownTxHashes unionOrderedSet:txHashes];
    }

    if (instantSendLockHashes.count > 0) {
        for (NSValue *hash in instantSendLockHashes) {
            UInt256 h;

            if (![self.knownInstantSendLockHashes containsObject:hash]) continue;
            [hash getValue:&h];
        }

        [instantSendLockHashes minusOrderedSet:self.knownInstantSendLockHashes];
        [self dispatchAsyncInDelegateQueue:^{
            if (self->_status == DSPeerStatus_Connected) [self.transactionDelegate peer:self hasInstantSendLockHashes:instantSendLockHashes];
        }];

        [self.knownInstantSendLockHashes unionOrderedSet:instantSendLockHashes];
    }
    
    if (instantSendLockDHashes.count > 0) {
        for (NSValue *hash in instantSendLockDHashes) {
            UInt256 h;

            if (![self.knownInstantSendLockDHashes containsObject:hash]) continue;
            [hash getValue:&h];
        }

        [instantSendLockDHashes minusOrderedSet:self.knownInstantSendLockDHashes];

        [self dispatchAsyncInDelegateQueue:^{
            if (self->_status == DSPeerStatus_Connected) [self.transactionDelegate peer:self hasInstantSendLockDHashes:instantSendLockDHashes];
        }];

        [self.knownInstantSendLockDHashes unionOrderedSet:instantSendLockDHashes];
    }



    if (chainLockHashes.count > 0) {
        for (NSValue *hash in chainLockHashes) {
            UInt256 h;

            if (![self.knownChainLockHashes containsObject:hash]) continue;
            [hash getValue:&h];
        }

        [chainLockHashes minusOrderedSet:self.knownChainLockHashes];
        [self dispatchAsyncInDelegateQueue:^{
            if (self->_status == DSPeerStatus_Connected) [self.transactionDelegate peer:self hasChainLockHashes:chainLockHashes];
        }];

        [self.knownChainLockHashes unionOrderedSet:chainLockHashes];
    }

    if (txHashes.count + instantSendLockHashes.count + instantSendLockDHashes.count > 0 || (!self.needsFilterUpdate && ((blockHashes.count + chainLockHashes.count) > 0))) {
        [self sendGetdataMessageWithTxHashes:txHashes.array instantSendLockHashes:instantSendLockHashes.array instantSendLockDHashes:instantSendLockDHashes.array blockHashes:(self.needsFilterUpdate) ? nil : blockHashes.array chainLockHashes:chainLockHashes.array];
    }

    // to improve chain download performance, if we received 500 block hashes, we request the next 500 block hashes
    if (!self.needsFilterUpdate) {
        if (blockHashes.count >= 500) {
            if ([self.chain.chainManager shouldRequestMerkleBlocksForZoneAfterHeight:self.chain.lastSyncBlockHeight + 1]) {
                [self sendGetblocksMessageWithLocators:@[uint256_data_from_obj(blockHashes.lastObject), uint256_data_from_obj(blockHashes.firstObject)]
                                           andHashStop:UINT256_ZERO];
            } else {
                [self sendGetheadersMessageWithLocators:@[uint256_data_from_obj(blockHashes.lastObject), uint256_data_from_obj(blockHashes.firstObject)]
                                            andHashStop:UINT256_ZERO];
            }
        } else if (blockHashes.count >= 2 && self.chain.chainManager.syncPhase == DSChainSyncPhase_ChainSync) {
            BOOL foundLastHash = FALSE;
            UInt256 lastTerminalBlockHash = self.chain.lastTerminalBlock.blockHash;
            for (NSValue *blockHash in blockHashes) {
                if (uint256_eq(uint256_data_from_obj(blockHash).UInt256, lastTerminalBlockHash)) {
                    foundLastHash = TRUE;
                }
            }
            if (!foundLastHash) {
                //we did not find the last hash, lets ask the remote again for blocks as a race condition might have occured
                [self sendGetblocksMessageWithLocators:@[uint256_data_from_obj(blockHashes.lastObject), uint256_data_from_obj(blockHashes.firstObject)]
                                           andHashStop:UINT256_ZERO];
            }
        } else if (blockHashes.count == 1 && self.chain.chainManager.syncPhase == DSChainSyncPhase_ChainSync) {
            //this could either be a terminal block, or very rarely (1 in 500) the race condition dealt with above but block hashes being 1
            //First we ust find if the blockHash is a terminal block hash
            //

            BOOL foundInTerminalBlocks = (self.chain.terminalBlocks[blockHashes.firstObject] != nil);
            BOOL isLastTerminalBlock = uint256_eq(self.chain.lastTerminalBlock.blockHash, uint256_data_from_obj(blockHashes.firstObject).UInt256);
            if (foundInTerminalBlocks && !isLastTerminalBlock) {
                [self sendGetblocksMessageWithLocators:@[uint256_data_from_obj(blockHashes.lastObject), uint256_data_from_obj(blockHashes.firstObject)]
                                           andHashStop:UINT256_ZERO];
            }
        }
    }

    if (self.mempoolTransactionCompletion && (txHashes.count + governanceObjectHashes.count + sporkHashes.count > 0)) {
        self.mempoolRequestTime = [NSDate timeIntervalSince1970]; // this will cancel the mempool timeout
        DSLogWithLocation(self, @"[DSPeer] got mempool tx inv messages");
        __block MempoolCompletionBlock completion = self.mempoolTransactionCompletion;
        [self sendPingMessageWithPongHandler:^(BOOL success) {
            if (completion) {
                completion(success, YES, NO);
            }
        }];
        self.mempoolTransactionCompletion = nil;
    }

    if (governanceObjectHashes.count > 0) {
        [self.governanceDelegate peer:self hasGovernanceObjectHashes:governanceObjectHashes];
    }
    if (governanceObjectVoteHashes.count > 0) {
        [self.governanceDelegate peer:self hasGovernanceVoteHashes:governanceObjectVoteHashes];
    }
    if (sporkHashes.count > 0) {
        [self.sporkDelegate peer:self hasSporkHashes:sporkHashes];
    }
}

- (void)acceptTxMessage:(NSData *)message {
    DSTransaction *tx = [DSTransactionFactory transactionWithMessage:message onChain:self.chain];

    if (!tx && ![DSTransactionFactory shouldIgnoreTransactionMessage:message]) {
        [self error:@"malformed tx message: %@", message];
        return;
    } else if (!self.sentFilter && !self.sentGetdataTxBlocks) {
        [self error:@"got tx message before loading a filter"];
        return;
    }

    if (tx) {
        __block DSMerkleBlock *currentBlock = self.currentBlock;
        [self dispatchAsyncInDelegateQueue:^{
            [self.transactionDelegate peer:self relayedTransaction:tx inBlock:currentBlock];
        }];
#if LOG_FULL_TX_MESSAGE
#if DEBUG
        DSLogPrivateWithLocation(self, @"got tx %@ %@", uint256_obj(tx.txHash), message.hexString);
#else
        DSLogWithLocation(self, @"got tx %@ %@", @"<REDACTED>", @"<REDACTED>");
#endif
#else
#if DEBUG
        DSLogPrivateWithLocation(self, @"got tx (%hu): %@", tx.type, uint256_obj(tx.txHash));
#else
        DSLogWithLocation(self, @"got tx (%lu): %@", tx.type, @"<REDACTED>");
#endif
#endif
    }


    if (self.currentBlock) { // we're collecting tx messages for a merkleblock
        UInt256 txHash = tx ? tx.txHash : message.SHA256_2;
        if ([self.currentBlockTxHashes containsObject:uint256_obj(txHash)]) {
            [self.currentBlockTxHashes removeObject:uint256_obj(txHash)];
        } else {
#if DEBUG
            DSLogPrivateWithLocation(self, @"current block does not contain transaction %@ (contains %@)", uint256_hex(txHash), self.currentBlockTxHashes);
#else
            DSLogWithLocation(self, @"current block does not contain transaction %@ (contains %@)", @"<REDACTED>", @"<REDACTED>");
#endif
        }

        if (self.currentBlockTxHashes.count == 0) { // we received the entire block including all matched tx
            DSMerkleBlock *block = self.currentBlock;

            DSLogWithLocation(self, @"clearing current block");

            self.currentBlock = nil;
            self.currentBlockTxHashes = nil;

            dispatch_sync(self.delegateQueue, ^{ // syncronous dispatch so we don't get too many queued up tx
                [self.transactionDelegate peer:self relayedBlock:block];
            });
        }
    } else {
        DSLogWithLocation(self, @"no current block");
    }
}


- (void)acceptIslockMessage:(NSData *)message {
#if LOG_TX_LOCK_VOTES
    DSLogWithLocation(self, @"peer relayed islock message: %@", message.hexString);
#endif
    if (![self.chain.chainManager.sporkManager deterministicMasternodeListEnabled]) {
        DSLogWithLocation(self, @"returned instant send lock message when DML not enabled: %@", message); //no error here
        return;
    }
    if (![self.chain.chainManager.sporkManager llmqInstantSendEnabled]) {
        DSLogWithLocation(self, @"returned instant send lock message when llmq instant send is not enabled: %@", message); //no error here
        return;
    }
    DSInstantSendTransactionLock *instantSendTransactionLock = [DSInstantSendTransactionLock instantSendTransactionLockWithNonDeterministicMessage:message onChain:self.chain];

    if (!instantSendTransactionLock) {
        [self error:@"malformed islock message: %@", message];
        return;
    } else if (!self.sentFilter && !self.sentGetdataTxBlocks) {
        [self error:@"got islock message before loading a filter"];
        return;
    }
    [self dispatchAsyncInDelegateQueue:^{
        [self.transactionDelegate peer:self relayedInstantSendTransactionLock:instantSendTransactionLock];
    }];
}

- (void)acceptIsdlockMessage:(NSData *)message {
#if LOG_TX_LOCK_VOTES
    DSLogWithLocation(self, @"peer relayed isdlock message: %@", message.hexString);
#endif
    if (![self.chain.chainManager.sporkManager deterministicMasternodeListEnabled]) {
        DSLogWithLocation(self, @"returned instant send lock message when DML not enabled: %@", message); //no error here
        return;
    }
    if (![self.chain.chainManager.sporkManager llmqInstantSendEnabled]) {
        DSLogWithLocation(self, @"returned instant send lock message when llmq instant send is not enabled: %@", message); //no error here
        return;
    }
    DSInstantSendTransactionLock *instantSendTransactionLock = [DSInstantSendTransactionLock instantSendTransactionLockWithDeterministicMessage:message onChain:self.chain];

    if (!instantSendTransactionLock) {
        [self error:@"malformed isdlock message: %@", message];
        return;
    } else if (!self.sentFilter && !self.sentGetdataTxBlocks) {
        [self error:@"got isdlock message before loading a filter"];
        return;
    }
    [self dispatchAsyncInDelegateQueue:^{
        [self.transactionDelegate peer:self relayedInstantSendTransactionLock:instantSendTransactionLock];
    }];
}

// HEADER FORMAT:

// 01 ................................. Header count: 1
//
// 02000000 ........................... Block version: 2
// b6ff0b1b1680a2862a30ca44d346d9e8
// 910d334beb48ca0c0000000000000000 ... Hash of previous block's header
// 9d10aa52ee949386ca9385695f04ede2
// 70dda20810decd12bc9b048aaab31471 ... Merkle root
// 24d95a54 ........................... Unix time: 1415239972
// 30c31b18 ........................... Target (bits)
// fe9f0864 ........................... Nonce
//
// 00 ................................. Transaction count (0x00)

- (void)acceptHeadersMessage:(NSData *)message {
    NSNumber *lNumber = nil;
    NSUInteger count = (NSUInteger)[message varIntAtOffset:0 length:&lNumber];
    NSUInteger l = lNumber.unsignedIntegerValue;
    NSUInteger off = 0;

    if (message.length < l + 81 * count) {
        [self error:@"malformed headers message, length is %u, should be %u for %u items", (int)message.length,
              (int)(((l == 0) ? 1 : l) + count * 81), (int)count];
        return;
    }
    if (count == 0) {
#if DEBUG
        DSLogPrivateWithLocation(self, @"got 0 headers (%@)", message.hexString);
#else
        DSLogWithLocation(self, @"got 0 headers (%@)", @"<REDACTED>");
#endif
    } else {
        DSLogWithLocation(self, @"got %lu headers", count);
    }

#if LOG_ALL_HEADERS_IN_ACCEPT_HEADERS
    for (int i = 0; i < count; i++) {
        NSData *headerData = [message subdataWithRange:NSMakeRange(l + 81 * i, 80)];
        DSLogPrivate(@"BLOCK HEADER ----------");
        DSLogPrivate(@"block version %u", [headerData UInt8AtOffset:0]);
        DSLogPrivate(@"previous blockheader hash %@ (%@)", [NSData dataWithUInt256:[headerData UInt256AtOffset:4]].hexString, [NSData dataWithUInt256:[headerData UInt256AtOffset:4]].reverse.hexString);
        DSLogPrivate(@"merkle root %@", [NSData dataWithUInt256:[headerData UInt256AtOffset:36]].hexString);
        uint32_t timestamp = [headerData UInt32AtOffset:68];
        DSLogPrivate(@"timestamp %x (%u) time is %@", timestamp, timestamp, [NSDate dateWithTimeIntervalSince1970:timestamp]);
        DSLogPrivate(@"target is %x", [headerData UInt32AtOffset:72]);
        DSLogPrivate(@"nonce is %x", [headerData UInt32AtOffset:76]);
        DSLogPrivate(@"transaction count is %u", [headerData UInt8AtOffset:80]);
        DSLogPrivate(@"-----------------------");
    }
#endif

    if (_relayStartTime != 0) { // keep track of relay peformance
        NSTimeInterval speed = count / ([NSDate timeIntervalSince1970] - self.relayStartTime);

        if (_relaySpeed == 0) _relaySpeed = speed;
        _relaySpeed = _relaySpeed * 0.9 + speed * 0.1;
        _relayStartTime = 0;
    }
    //    for (int i = 0; i < count; i++) {
    //        UInt256 locator = [DSKeyManager x11:[message subdataWithRange:NSMakeRange(l + 81*i, 80)]];
    //        DSLog(@"%@:%u header: %@", self.host, self.port, uint256_obj(locator));
    //    }
    // To improve chain download performance, if this message contains 2000 headers then request the next 2000 headers
    // immediately, and switch to requesting blocks when we receive a header newer than earliestKeyTime
    // Devnets can run slower than usual
    NSTimeInterval lastTimestamp = [message UInt32AtOffset:l + 81 * (count - 1) + 68];
    NSTimeInterval firstTimestamp = [message UInt32AtOffset:l + 81 + 68];
    if (!self.chain.needsInitialTerminalHeadersSync && (firstTimestamp + DAY_TIME_INTERVAL * 2 >= self.earliestKeyTime) && [self.chain.chainManager shouldRequestMerkleBlocksForZoneAfterHeight:self.chain.lastSyncBlockHeight + 1]) {
        //this is a rare scenario where we called getheaders but the first header returned was actually past the cuttoff, but the previous header was before the cuttoff
        DSLogWithLocation(self, @"calling getblocks with locators: %@", [self.chain chainSyncBlockLocatorArray]);
        [self sendGetblocksMessageWithLocators:self.chain.chainSyncBlockLocatorArray andHashStop:UINT256_ZERO];
        return;
    }
    if (!count) return;
    if (count >= self.chain.headersMaxAmount || (((lastTimestamp + DAY_TIME_INTERVAL * 2) >= self.earliestKeyTime) && (!self.chain.needsInitialTerminalHeadersSync))) {
        UInt256 firstBlockHash = [DSKeyManager x11:[message subdataWithRange:NSMakeRange(l, 80)]];
        UInt256 lastBlockHash = [DSKeyManager x11:[message subdataWithRange:NSMakeRange(l + 81 * (count - 1), 80)]];
        NSData *firstHashData = uint256_data(firstBlockHash);
        NSData *lastHashData = uint256_data(lastBlockHash);
        if (((lastTimestamp + DAY_TIME_INTERVAL * 2) >= self.earliestKeyTime) &&
            (!self.chain.needsInitialTerminalHeadersSync) &&
            [self.chain.chainManager shouldRequestMerkleBlocksForZoneAfterHeight:self.chain.lastSyncBlockHeight + 1]) { // request blocks for the remainder of the chain
            NSTimeInterval timestamp = [message UInt32AtOffset:l + 81 + 68];
            for (off = l; timestamp > 0 && ((timestamp + DAY_TIME_INTERVAL * 2) < self.earliestKeyTime);) {
                off += 81;
                timestamp = [message UInt32AtOffset:off + 81 + 68];
            }
            lastBlockHash = [DSKeyManager x11:[message subdataWithRange:NSMakeRange(off, 80)]];
            lastHashData = uint256_data(lastBlockHash);
            DSLogWithLocation(self, @"calling getblocks with locators: [%@, %@]", lastHashData.reverse.hexString, firstHashData.reverse.hexString);
            [self sendGetblocksMessageWithLocators:@[lastHashData, firstHashData] andHashStop:UINT256_ZERO];
        } else {
            
            DSLogWithLocation(self, @"calling getheaders with locators: [%@, %@]", lastHashData.reverse.hexString, firstHashData.reverse.hexString);
            [self sendGetheadersMessageWithLocators:@[lastHashData, firstHashData] andHashStop:UINT256_ZERO];
        }
    }
    for (NSUInteger off = l; off < l + 81 * count; off += 81) {
        DSMerkleBlock *block = [DSMerkleBlock merkleBlockWithMessage:[message subdataWithRange:NSMakeRange(off, 81)] onChain:self.chain];
        if (!block.valid) {
            [self error:@"invalid block header %@", uint256_obj(block.blockHash)];
            return;
        }
        [self dispatchAsyncInDelegateQueue:^{
            [self.transactionDelegate peer:self relayedHeader:block];
        }];
    }
}

- (void)acceptGetaddrMessage:(NSData *)message {
    DSLogWithLocation(self, @"got getaddr");
    [self sendRequest:[DSAddrRequest request]];
}

- (void)acceptGetdataMessage:(NSData *)message {
    NSNumber *lNumber = nil;
    NSUInteger l, count = (NSUInteger)[message varIntAtOffset:0 length:&lNumber];
    l = lNumber.unsignedIntegerValue;

    if (l == 0 || message.length < l + count * 36) {
        [self error:@"malformed getdata message, length is %u, should be %u for %u items", (int)message.length,
              (int)(((l == 0) ? 1 : l) + count * 36), (int)count];
        return;
    } else if (count > MAX_GETDATA_HASHES) {
        DSLogWithLocation(self, @"dropping getdata message, %lu is too many items, max is %u", count, MAX_GETDATA_HASHES);
        return;
    }

    DSLogWithLocation(self, @"%@got getdata for %lu item%@", self.peerDelegate.downloadPeer == self ? @"(download peer)" : @"", count, count == 1 ? @"" : @"s");
    [self dispatchAsyncInDelegateQueue:^{
        NSMutableData *notfound = [NSMutableData data];

        for (NSUInteger off = l; off < l + count * 36; off += 36) {
            DSInvType type = [message UInt32AtOffset:off];
            UInt256 hash = [message UInt256AtOffset:off + sizeof(uint32_t)];
            DSTransaction *transaction = nil;

            if (uint256_is_zero(hash)) continue;

            switch (type) { //!OCLINT
                case DSInvType_Tx:
                case DSInvType_TxLockRequest:
                    transaction = [self.transactionDelegate peer:self requestedTransaction:hash];

                    if (transaction) {
                        [self sendMessage:transaction.data type:MSG_TX];
                        break;
                    } else {
#if DEBUG
                        DSLogPrivateWithLocation(self, @"peer requested transaction was not found with hash %@ reversed %@", [NSData dataWithUInt256:hash].hexString, [NSData dataWithUInt256:hash].reverse.hexString);
#else
                        DSLogWithLocation(self, @"peer requested transaction was not found with hash %@ reversed %@", @"<REDACTED>", @"<DETCADER>");
#endif
                        [notfound appendUInt32:type];
                        [notfound appendBytes:&hash length:sizeof(hash)];
                        break;
                    }
                case DSInvType_GovernanceObjectVote: {
                    DSGovernanceVote *vote = [self.governanceDelegate peer:self requestedVote:hash];
                    if (vote) {
                        [self sendMessage:vote.dataMessage type:MSG_GOVOBJVOTE];
                        break;
                    } else {
                        [notfound appendUInt32:type];
                        [notfound appendBytes:&hash length:sizeof(hash)];
                        break;
                    }
                }
                case DSInvType_GovernanceObject: {
                    DSGovernanceObject *governanceObject = [self.governanceDelegate peer:self requestedGovernanceObject:hash];
                    if (governanceObject) {
                        [self sendMessage:governanceObject.dataMessage type:MSG_GOVOBJ];
                        break;
                    } else {
                        [notfound appendUInt32:type];
                        [notfound appendBytes:&hash length:sizeof(hash)];
                        break;
                    }
                }
                    // fall through
                default:
                    [notfound appendUInt32:type];
                    [notfound appendBytes:&hash length:sizeof(hash)];
                    break;
            }
        }

        if (notfound.length > 0) {
            DSNotFoundRequest *request = [DSNotFoundRequest requestWithData:notfound];
            [self sendRequest:request];
        }
    }];
}

- (void)acceptNotfoundMessage:(NSData *)message {
    NSNumber *lNumber = nil;
    NSMutableArray *txHashes = [NSMutableArray array], *txLockRequestHashes = [NSMutableArray array], *blockHashes = [NSMutableArray array];
    NSUInteger l, count = (NSUInteger)[message varIntAtOffset:0 length:&lNumber];
    l = lNumber.unsignedIntegerValue;

    if (l == 0 || message.length < l + count * 36) {
        [self error:@"malformed notfound message, length is %u, should be %u for %u items", (int)message.length,
              (int)(((l == 0) ? 1 : l) + count * 36), (int)count];
        return;
    }

    DSLogWithLocation(self, @"got notfound with %lu item%@ (first item %@)", count, count == 1 ? @"" : @"s", [self nameOfInvMessage:[message UInt32AtOffset:l]]);

    for (NSUInteger off = l; off < l + 36 * count; off += 36) {
        if ([message UInt32AtOffset:off] == DSInvType_Tx) {
            [txHashes addObject:uint256_obj([message UInt256AtOffset:off + sizeof(uint32_t)])];
        } else if ([message UInt32AtOffset:off] == DSInvType_TxLockRequest) {
            [txLockRequestHashes addObject:uint256_obj([message UInt256AtOffset:off + sizeof(uint32_t)])];
        } else if ([message UInt32AtOffset:off] == DSInvType_Merkleblock) {
            [blockHashes addObject:uint256_obj([message UInt256AtOffset:off + sizeof(uint32_t)])];
        }
    }
    [self dispatchAsyncInDelegateQueue:^{
        [self.transactionDelegate peer:self relayedNotFoundMessagesWithTransactionHashes:txHashes andBlockHashes:blockHashes];
    }];
}

- (void)acceptPingMessage:(NSData *)message {
    if (message.length < sizeof(uint64_t)) {
        [self error:@"malformed ping message, length is %u, should be 4", (int)message.length];
        return;
    }
#if MESSAGE_LOGGING
    DSLogWithLocation(self, @"got ping");
#endif
    [self sendMessage:message type:MSG_PONG];
}

- (void)acceptPongMessage:(NSData *)message {
    if (message.length < sizeof(uint64_t)) {
        [self error:@"malformed pong message, length is %u, should be 4", (int)message.length];
        return;
    } else if ([message UInt64AtOffset:0] != self.localNonce) {
        [self error:@"pong message contained wrong nonce: %llu, expected: %llu", [message UInt64AtOffset:0], self.localNonce];
        return;
    } else {
        __block BOOL hasNoHandlers = ![self.pongHandlers count];
        if (hasNoHandlers) {
            DSLogWithLocation(self, @"got unexpected pong");
            return;
        }
    }

    if (self.pingStartTime > 1) {
        NSTimeInterval pingTime = [NSDate timeIntervalSince1970] - self.pingStartTime;

        // 50% low pass filter on current ping time
        _pingTime = self.pingTime * 0.5 + pingTime * 0.5;
        self.pingStartTime = 0;
    }

#if MESSAGE_LOGGING
    DSLogWithLocation(self, @"got pong in %fs", self.pingTime);
#endif
    if (self->_status == DSPeerStatus_Connected && self.pongHandlers.count) {
        void (^handler)(BOOL) = nil;
        @synchronized(self.pongHandlers) {
            if (self.pongHandlers.count > 0) {
                handler = [self.pongHandlers objectAtIndex:0];
                [self.pongHandlers removeObjectAtIndex:0];
            }
        }
        if (handler) {
            [self dispatchAsyncInDelegateQueue:^{ handler(YES); }];
        }
    }
}

#define SAVE_INCOMING_BLOCKS 0

- (void)acceptMerkleblockMessage:(NSData *)message {
    // Dash nodes don't support querying arbitrary transactions, only transactions not yet accepted in a block. After
    // a merkleblock message, the remote node is expected to send tx messages for the tx referenced in the block. When a
    // non-tx message is received we should have all the tx in the merkleblock.
    DSMerkleBlock *block = [DSMerkleBlock merkleBlockWithMessage:message onChain:self.chain];

    if (!block.valid) {
        [self error:@"invalid merkleblock: %@", uint256_obj(block.blockHash)];
        return;
    } else if (!self.sentFilter && !self.sentGetdataTxBlocks) {
        [self error:@"got merkleblock message before loading a filter"];
        return;
    }
    //else DSLog(@"[%@: %@:%d] got merkleblock %@", self.chain.name, self.host, self.port, uint256_hex(block.blockHash));
    
    NSMutableOrderedSet *txHashes = [NSMutableOrderedSet orderedSetWithArray:block.transactionHashes];
    @synchronized (self.knownTxHashes) {
        [txHashes minusOrderedSet:self.knownTxHashes];
    }

    if (txHashes.count > 0) { // wait til we get all the tx messages before processing the block
        self.currentBlock = block;
        self.currentBlockTxHashes = txHashes;
    } else {
        [self dispatchAsyncInDelegateQueue:^{
            [self.transactionDelegate peer:self relayedBlock:block];
#if SAVE_INCOMING_BLOCKS
            NSString *fileName = [NSString stringWithFormat:@"%@-%d-%@.block", self.chain.devnetIdentifier, block.height, uint256_hex(block.blockHash)];
            [message saveToFile:fileName inDirectory:NSCachesDirectory];
#endif
        }];
    }
}

// DIP08: https://github.com/dashpay/dips/blob/master/dip-0008.md
- (void)acceptChainLockMessage:(NSData *)message {
    if (![self.chain.chainManager.sporkManager chainLocksEnabled]) {
#if DEBUG
        DSLogPrivateWithLocation(self, @"returned chain lock message when chain locks are not enabled: %@", message); //no error here
#else
        DSLogWithLocation(self, @"returned chain lock message when chain locks are not enabled: %@", @"<REDACTED>"); //no error here
#endif
        return;
    }
    DSChainLock *chainLock = [DSChainLock chainLockWithMessage:message onChain:self.chain];

    if (!chainLock) {
        [self error:@"malformed chain lock message: %@", message];
        return;
    } else if (!self.sentFilter && !self.sentGetdataTxBlocks) {
        [self error:@"got chain lock message before loading a filter"];
        return;
    }
    [self dispatchAsyncInDelegateQueue:^{
        [self.transactionDelegate peer:self relayedChainLock:chainLock];
    }];
}

// BIP61: https://github.com/bitcoin/bips/blob/master/bip-0061.mediawiki
- (void)acceptRejectMessage:(NSData *)message {
    NSNumber *offNumber = nil, *lNumber = nil;
    NSUInteger off = 0, l = 0;
    NSString *type = [message stringAtOffset:0 length:&offNumber];
    off = offNumber.unsignedIntegerValue;
    uint8_t code = [message UInt8AtOffset:off++];
    NSString *reason = [message stringAtOffset:off length:&lNumber];
    l = lNumber.unsignedIntegerValue;
    UInt256 txHash = ([MSG_TX isEqual:type] || [MSG_IX isEqual:type]) ? [message UInt256AtOffset:off + l] : UINT256_ZERO;

#if DEBUG
    DSLogPrivateWithLocation(self, @"rejected %@ code: 0x%x reason: \"%@\"%@%@", type, code, reason,
        (uint256_is_zero(txHash) ? @"" : @" txid: "), (uint256_is_zero(txHash) ? @"" : uint256_obj(txHash)));
#else
    DSLogWithLocation(self, @"rejected %@ code: 0x%x reason: \"%@\"%@%@", type, code, reason,
        (uint256_is_zero(txHash) ? @"" : @" txid: "), (uint256_is_zero(txHash) ? @"" : @"<REDACTED>"));
#endif
    reason = nil; // fixes an unused variable warning for non-debug builds

    if (uint256_is_not_zero(txHash)) {
        [self dispatchAsyncInDelegateQueue:^{
            [self.transactionDelegate peer:self rejectedTransaction:txHash withCode:code];
        }];
    }
}

// BIP133: https://github.com/bitcoin/bips/blob/master/bip-0133.mediawiki
- (void)acceptFeeFilterMessage:(NSData *)message {
    if (message.length < sizeof(uint64_t)) {
        [self error:@"malformed freerate message, length is %u, should be 4", (int)message.length];
        return;
    }

    _feePerByte = ceilf((float)[message UInt64AtOffset:0] / 1000.0f);
    DSLogWithLocation(self, @"got feefilter with rate %llu per Byte", self.feePerByte);
    [self dispatchAsyncInDelegateQueue:^{
        [self.transactionDelegate peer:self setFeePerByte:self.feePerByte];
    }];
}

// MARK: - accept Control

- (void)acceptSporkMessage:(NSData *)message {
    [self.sporkDelegate peer:self relayedSpork:message];
}

// MARK: - accept Masternode

- (void)acceptSSCMessage:(NSData *)message {
    DSSyncCountInfo syncCountInfo = [message UInt32AtOffset:0];
    uint32_t count = [message UInt32AtOffset:4];
    DSLogWithLocation(self, @"received ssc message %d %d", syncCountInfo, count);
    switch (syncCountInfo) {
        case DSSyncCountInfo_GovernanceObject:
            if (self.governanceRequestState == DSGovernanceRequestState_GovernanceObjectHashes) {
                self.governanceRequestState = DSGovernanceRequestState_GovernanceObjectHashesCountReceived;
                [self.peerChainDelegate peer:self relayedSyncInfo:syncCountInfo count:count];
            } else if (self.governanceRequestState == DSGovernanceRequestState_GovernanceObjectHashesReceived) {
                self.governanceRequestState = DSGovernanceRequestState_GovernanceObjects;
                [self.peerChainDelegate peer:self relayedSyncInfo:syncCountInfo count:count];
            }
            break;
        case DSSyncCountInfo_GovernanceObjectVote:
            if (self.governanceRequestState == DSGovernanceRequestState_GovernanceObjectVoteHashes) {
                self.governanceRequestState = DSGovernanceRequestState_GovernanceObjectVoteHashesCountReceived;
                [self.peerChainDelegate peer:self relayedSyncInfo:syncCountInfo count:count];
            } else if (self.governanceRequestState == DSGovernanceRequestState_GovernanceObjectVoteHashesReceived) {
                self.governanceRequestState = DSGovernanceRequestState_GovernanceObjectVotes;
                [self.peerChainDelegate peer:self relayedSyncInfo:syncCountInfo count:count];
            }
            break;
        default:
            [self.peerChainDelegate peer:self relayedSyncInfo:syncCountInfo count:count];
            break;
    }
    //ignore when count = 0; (for votes)
}

- (void)acceptMNBMessage:(NSData *)message {
    //deprecated since version 70211
}

- (void)acceptMNLISTDIFFMessage:(NSData *)message {
    [self.masternodeDelegate peer:self relayedMasternodeDiffMessage:message];
}

- (void)acceptQRInfoMessage:(NSData *)message {
    [self.masternodeDelegate peer:self relayedQuorumRotationInfoMessage:message];
}

// MARK: - accept Governance

// https://dash-docs.github.io/en/developer-reference#govobj

- (void)acceptGovObjectMessage:(NSData *)message {
    DSGovernanceObject *governanceObject = [DSGovernanceObject governanceObjectFromMessage:message onChain:self.chain];
    if (governanceObject) {
        [self.governanceDelegate peer:self relayedGovernanceObject:governanceObject];
    }
}

- (void)acceptGovObjectVoteMessage:(NSData *)message {
    DSGovernanceVote *governanceVote = [DSGovernanceVote governanceVoteFromMessage:message onChain:self.chain];
    if (governanceVote) {
        [self.governanceDelegate peer:self relayedGovernanceVote:governanceVote];
    }
}

- (void)acceptGovObjectSyncMessage:(NSData *)message {
    DSLogWithLocation(self, @"Gov Object Sync");
}

// MARK: - Accept Dark send

- (void)acceptDarksendAnnounceMessage:(NSData *)message {
}

- (void)acceptDarksendControlMessage:(NSData *)message {
}

- (void)acceptDarksendFinishMessage:(NSData *)message {
}

- (void)acceptDarksendInitiateMessage:(NSData *)message {
}

- (void)acceptDarksendQuorumMessage:(NSData *)message {
}

- (void)acceptDarksendSessionMessage:(NSData *)message {
}

- (void)acceptDarksendSessionUpdateMessage:(NSData *)message {
}

- (void)acceptDarksendTransactionMessage:(NSData *)message {
    //    DSTransaction *tx = [DSTransaction transactionWithMessage:message];
    //
    //    if (! tx) {
    //        [self error:@"malformed tx message: %@", message];
    //        return;
    //    }
    //    else if (! self.sentFilter && ! self.sentTxAndBlockGetdata) {
    //        [self error:@"got tx message before loading a filter"];
    //        return;
    //    }
    //
    //    DSLogPrivate(@"%@:%u got tx %@", self.host, self.port, uint256_obj(tx.txHash));
    //
    //    dispatch_async(self.delegateQueue, ^{
    //        [self.delegate peer:self relayedTransaction:tx];
    //    });
    //
    //    if (self.currentBlock) { // we're collecting tx messages for a merkleblock
    //        [self.currentBlockTxHashes removeObject:uint256_obj(tx.txHash)];
    //
    //        if (self.currentBlockTxHashes.count == 0) { // we received the entire block including all matched tx
    //            BRMerkleBlock *block = self.currentBlock;
    //
    //            self.currentBlock = nil;
    //            self.currentBlockTxHashes = nil;
    //
    //            dispatch_sync(self.delegateQueue, ^{ // syncronous dispatch so we don't get too many queued up tx
    //                [self.delegate peer:self relayedBlock:block];
    //            });
    //        }
    //    }
}

// MARK: - hash

#define FNV32_PRIME 0x01000193u
#define FNV32_OFFSET 0x811C9dc5u

// FNV32-1a hash of the ip address and port number: http://www.isthe.com/chongo/tech/comp/fnv/index.html#FNV-1a
- (NSUInteger)hash {
    uint32_t hash = FNV32_OFFSET;

    for (int i = 0; i < sizeof(_address); i++) {
        hash = (hash ^ _address.u8[i]) * FNV32_PRIME;
    }

    hash = (hash ^ ((_port >> 8) & 0xff)) * FNV32_PRIME;
    hash = (hash ^ (_port & 0xff)) * FNV32_PRIME;
    return hash;
}

// two peer objects are equal if they share an ip address and port number
- (BOOL)isEqual:(id)object {
    return self == object ||
            ([object isKindOfClass:[DSPeer class]] &&
             _port == ((DSPeer *)object).port &&
             uint128_eq(_address, [(DSPeer *)object address]));
}

// MARK: - Info

- (NSString *)chainTip {
    return [NSData dataWithUInt256:self.currentBlock.blockHash].shortHexString;
}

// MARK: - Saving to Disk

- (void)save {
    [self.managedObjectContext performBlock:^{
        NSArray *peerEntities = [DSPeerEntity objectsInContext:self.managedObjectContext matching:@"address == %@ && port == %@", @(CFSwapInt32BigToHost(self.address.u32[3])), @(self.port)];
        if ([peerEntities count]) {
            DSPeerEntity *e = [peerEntities firstObject];

            @autoreleasepool {
                e.timestamp = self.timestamp;
                e.services = self.services;
                e.misbehavin = self.misbehaving;
                e.priority = self.priority;
                e.lowPreferenceTill = self.lowPreferenceTill;
                e.lastRequestedMasternodeList = self.lastRequestedMasternodeList;
                e.lastRequestedGovernanceSync = self.lastRequestedGovernanceSync;
            }
        } else {
            @autoreleasepool {
                [[DSPeerEntity managedObjectInBlockedContext:self.managedObjectContext] setAttributesFromPeer:self]; // add new peers
            }
        }
    }];
}

// MARK: - NSStreamDelegate

- (NSError *)connectionTimeoutError {
    static NSError *error;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        error = [NSError errorWithCode:DASH_PEER_TIMEOUT_CODE localizedDescriptionKey:@"Connect timeout"];
    });
    return error;
}

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
    switch (eventCode) { //!OCLINT
        case NSStreamEventOpenCompleted:
            DSLogWithLocation(self, @"%@ stream connected in %fs",
                (aStream == self.inputStream) ? @"input" : (aStream == self.outputStream ? @"output" : @"unknown"),
                [NSDate timeIntervalSince1970] - self.pingStartTime);

            if (aStream == self.outputStream) {
                self.pingStartTime = [NSDate timeIntervalSince1970];                                                                                 // don't count connect time in ping time
                [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(disconnectWithError:) object:self.connectionTimeoutError]; // cancel pending socket connect timeout
                [self performSelector:@selector(disconnectWithError:)
                           withObject:self.connectionTimeoutError
                           afterDelay:CONNECT_TIMEOUT];
            }

            // fall through to send any queued output
        case NSStreamEventHasSpaceAvailable:
            if (aStream != self.outputStream) return;

            LOCK(self.outputBufferSemaphore);

            while (self.outputBuffer.length > 0 && self.outputStream.hasSpaceAvailable) {
                NSInteger l = [self.outputStream write:self.outputBuffer.bytes maxLength:self.outputBuffer.length];

                if (l > 0) [self.outputBuffer replaceBytesInRange:NSMakeRange(0, l) withBytes:NULL length:0];
            }

            UNLOCK(self.outputBufferSemaphore);

            break;

        case NSStreamEventHasBytesAvailable:
            if (aStream != self.inputStream) return;
            // TODO: if it's a big message (a lot of messages) it could drop the app because of memory/cpu issues (a lot of heavy tasks: processing/x11calculation/reading_from_userDefaults/writing )
            while (self.inputStream.hasBytesAvailable) {
                @autoreleasepool {
                    NSData *message = nil;
                    NSString *type = nil;
                    NSInteger headerLen = self.msgHeader.length, payloadLen = self.msgPayload.length, l = 0;
                    uint32_t length = 0, checksum = 0;

                    if (headerLen < HEADER_LENGTH) { // read message header
                        self.msgHeader.length = HEADER_LENGTH;
                        l = [self.inputStream read:(uint8_t *)self.msgHeader.mutableBytes + headerLen
                                         maxLength:self.msgHeader.length - headerLen];

                        if (l < 0) {
                            DSLogWithLocation(self, @"error reading message");
                            goto reset; //!OCLINT
                        }

                        self.msgHeader.length = headerLen + l;

                        // consume one byte at a time, up to the magic number that starts a new message header
                        while (self.msgHeader.length >= sizeof(uint32_t) &&
                               [self.msgHeader UInt32AtOffset:0] != self.chain.magicNumber) {
#if DEBUG
                            printf("%c", *(const char *)self.msgHeader.bytes);
#endif
                            [self.msgHeader replaceBytesInRange:NSMakeRange(0, 1)
                                                      withBytes:NULL
                                                         length:0];
                        }

                        if (self.msgHeader.length < HEADER_LENGTH) continue; // wait for more stream input
                    }

                    //                    if ([self.msgHeader UInt8AtOffset:15] != 0) { // verify msg type field is null terminated
                    //                        [self error:@"malformed message header: %@", self.msgHeader];
                    //                        goto reset;
                    //                    }

                    type = @((const char *)self.msgHeader.bytes + 4);
                    length = [self.msgHeader UInt32AtOffset:16];
                    checksum = [self.msgHeader UInt32AtOffset:20];

                    if (length > MAX_MSG_LENGTH) { // check message length
                        [self error:@"error reading %@, message length %u is too long", type, length];
                        goto reset; //!OCLINT
                    }

                    if (payloadLen < length) { // read message payload
                        self.msgPayload.length = length;
                        l = [self.inputStream read:(uint8_t *)self.msgPayload.mutableBytes + payloadLen
                                         maxLength:self.msgPayload.length - payloadLen];

                        if (l < 0) {
                            DSLogWithLocation(self, @"error reading %@", type);
                            goto reset; //!OCLINT
                        }

                        self.msgPayload.length = payloadLen + l;
                        if (self.msgPayload.length < length) continue; // wait for more stream input
                    }

                    if (CFSwapInt32LittleToHost(self.msgPayload.SHA256_2.u32[0]) != checksum) { // verify checksum
                        [self error:@"error reading %@, invalid checksum %x, expected %x, payload length:%u, expected "
                                     "length:%u, SHA256_2:%@",
                              type, self.msgPayload.SHA256_2.u32[0], checksum,
                              (int)self.msgPayload.length, length, uint256_obj(self.msgPayload.SHA256_2)];
                        goto reset; //!OCLINT
                    }

                    message = self.msgPayload;
                    self.msgPayload = [NSMutableData data];
                    [self acceptMessage:message type:type]; // process message

                reset: //!OCLINT // reset for next message
                    self.msgHeader.length = self.msgPayload.length = 0;
                }
            }

            break;

        case NSStreamEventErrorOccurred:
            DSLogWithLocation(self, @"error connecting, %@", aStream.streamError);
            [self disconnectWithError:aStream.streamError];
            break;

        case NSStreamEventEndEncountered:
            DSLogWithLocation(self, @"connection closed");
            [self disconnectWithError:nil];
            break;

        default:
            DSLogWithLocation(self, @"unknown network stream eventCode:%lu", eventCode);
    }
}

- (void)dispatchAsyncInDelegateQueue:(void (^)(void))block {
    dispatch_async(self.delegateQueue, ^{ block(); });
}
@end
