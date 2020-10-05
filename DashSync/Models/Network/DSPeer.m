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
#import "DSTransaction.h"
#import "DSChain+Protected.h"
#import "DSSpork.h"
#import "DSMerkleBlock.h"
#import "DSChainLock.h"
#import "NSMutableData+Dash.h"
#import "NSData+Bitcoin.h"
#import "NSData+Dash.h"
#import "DSReachabilityManager.h"
#import "DSGovernanceObject.h"
#import <arpa/inet.h>
#import "DSBloomFilter.h"
#import "DSGovernanceVote.h"
#import "DSPeerManager.h"
#import "DSOptionsManager.h"
#import "DSTransactionFactory.h"
#import "DSTransactionHashEntity+CoreDataClass.h"
#import "NSManagedObject+Sugar.h"
#import "DSChainEntity+CoreDataClass.h"
#import "NSDate+Utils.h"
#import "DSPeerEntity+CoreDataClass.h"
#import "DSChainManager.h"
#import "DSInstantSendTransactionLock.h"
#import "DSSporkManager.h"
#import "DSBlockchainIdentityRegistrationTransition.h"
#import "DSMasternodeManager.h"
#import "DSSimplifiedMasternodeEntry.h"
#import "DSChainManager+Protected.h"

#define PEER_LOGGING 1
#define LOG_ALL_HEADERS_IN_ACCEPT_HEADERS 0
#define LOG_TX_LOCK_VOTES 0
#define LOG_FULL_TX_MESSAGE 0

#if ! PEER_LOGGING
#define DSDLog(...)
#endif

#define MESSAGE_LOGGING (1 & DEBUG)
#define MESSAGE_CONTENT_LOGGING (1 & DEBUG)
#define MESSAGE_IN_DEPTH_TX_LOGGING (1 & DEBUG)

#define HEADER_LENGTH      24 
#define MAX_MSG_LENGTH     0x02000000
#define MAX_GETDATA_HASHES 50000
#define ENABLED_SERVICES   0     // we don't provide full blocks to remote nodes
#define LOCAL_HOST         0x7f000001
#define CONNECT_TIMEOUT    3.0
#define MEMPOOL_TIMEOUT    2.0

#define LOCK(lock) dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
#define UNLOCK(lock) dispatch_semaphore_signal(lock);


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
@property (nonatomic, assign) BOOL sentGetaddr, sentFilter, sentGetdataTxBlocks, sentGetdataMasternode,sentGetdataGovernance, sentMempool, sentGetblocks, sentGetdataGovernanceVotes, sentGovSync;
@property (nonatomic, assign) BOOL receivedGovSync;
@property (nonatomic, strong) DSReachabilityManager *reachability;
@property (nonatomic, strong) id reachabilityObserver;
@property (nonatomic, assign) uint64_t localNonce;
@property (nonatomic, assign) NSTimeInterval pingStartTime, relayStartTime;
@property (nonatomic, strong) DSMerkleBlock *currentBlock;
@property (nonatomic, strong) NSMutableOrderedSet *knownBlockHashes, *knownChainLockHashes, *knownTxHashes, *knownInstantSendLockHashes, *currentBlockTxHashes;
@property (nonatomic, strong) NSMutableOrderedSet *knownGovernanceObjectHashes, *knownGovernanceObjectVoteHashes;
@property (nonatomic, strong) NSData *lastBlockHash;
@property (nonatomic, strong) NSMutableArray *pongHandlers;
@property (nonatomic, strong) MempoolCompletionBlock mempoolTransactionCompletion;
@property (nonatomic, strong) NSRunLoop *runLoop;
@property (nonatomic, strong) DSChain * chain;
@property (nonatomic, strong) NSManagedObjectContext * managedObjectContext;
@property (nonatomic, assign) uint64_t receivedOrphanCount;
@property (nonatomic, assign) NSTimeInterval mempoolRequestTime;
@property (nonatomic, strong) dispatch_semaphore_t outputBufferSemaphore;

@end

@implementation DSPeer

@dynamic host;

+ (instancetype)peerWithAddress:(UInt128)address andPort:(uint16_t)port onChain:(DSChain*)chain
{
    return [[self alloc] initWithAddress:address andPort:port onChain:chain];
}

+ (instancetype)peerWithHost:(NSString *)host onChain:(DSChain*)chain
{
    return [[self alloc] initWithHost:host onChain:chain];
}

+ (instancetype)peerWithSimplifiedMasternodeEntry:(DSSimplifiedMasternodeEntry*)simplifiedMasternodeEntry {
    return [[self alloc] initWithSimplifiedMasternodeEntry:simplifiedMasternodeEntry];
}

- (instancetype)initWithAddress:(UInt128)address andPort:(uint16_t)port onChain:(DSChain*)chain
{
    if (! (self = [super init])) return nil;
    
    _address = address;
    _port = (port == 0) ? [chain standardPort] : port;
    self.chain = chain;
    _outputBufferSemaphore = dispatch_semaphore_create(1);
    return self;
}

- (instancetype)initWithSimplifiedMasternodeEntry:(DSSimplifiedMasternodeEntry*)simplifiedMasternodeEntry {
    return [self initWithAddress:simplifiedMasternodeEntry.address andPort:simplifiedMasternodeEntry.port onChain:simplifiedMasternodeEntry.chain];
}

- (instancetype)initWithHost:(NSString *)host onChain:(DSChain*)chain
{
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
    _address = (UInt128){ .u32 = { 0, 0, CFSwapInt32HostToBig(0xffff), addr.s_addr } };
    if (_port == 0) _port = chain.standardPort;
    self.chain = chain;
    _outputBufferSemaphore = dispatch_semaphore_create(1);
    return self;
}

- (instancetype)initWithAddress:(UInt128)address port:(uint16_t)port onChain:(DSChain*)chain timestamp:(NSTimeInterval)timestamp
                       services:(uint64_t)services
{
    if (! (self = [self initWithAddress:address andPort:port onChain:chain])) return nil;
    
    _timestamp = timestamp;
    _services = services;
    _outputBufferSemaphore = dispatch_semaphore_create(1);
    return self;
}

- (void)dealloc
{
    if (self.reachabilityObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.reachabilityObserver];
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

- (void)setChainDelegate:(id<DSPeerChainDelegate>)chainDelegate peerDelegate:(id<DSPeerDelegate>)peerDelegate transactionDelegate:(id<DSPeerTransactionDelegate>)transactionDelegate governanceDelegate:(id<DSPeerGovernanceDelegate>)governanceDelegate sporkDelegate:(id<DSPeerSporkDelegate>)sporkDelegate masternodeDelegate:(id<DSPeerMasternodeDelegate>)masternodeDelegate queue:(dispatch_queue_t)delegateQueue
{
    _peerChainDelegate = chainDelegate;
    _peerDelegate = peerDelegate;
    _transactionDelegate = transactionDelegate;
    _governanceDelegate = governanceDelegate;
    _sporkDelegate = sporkDelegate;
    _masternodeDelegate = masternodeDelegate;
    
    _delegateQueue = (delegateQueue) ? delegateQueue : dispatch_get_main_queue();
}

- (NSString *)location {
    return [NSString stringWithFormat:@"%@:%d",self.host,self.port];
}

- (NSString *)host
{
    char s[INET6_ADDRSTRLEN];
    
    if (_address.u64[0] == 0 && _address.u32[2] == CFSwapInt32HostToBig(0xffff)) {
        return @(inet_ntop(AF_INET, &_address.u32[3], s, sizeof(s)));
    }
    else return @(inet_ntop(AF_INET6, &_address, s, sizeof(s)));
}

- (void)connect
{
    if (self.status != DSPeerStatus_Disconnected) return;
    _status = DSPeerStatus_Connecting;
    _pingTime = DBL_MAX;
    if (! self.reachability) self.reachability = [DSReachabilityManager sharedManager];
    
    if (self.reachability.networkReachabilityStatus == DSReachabilityStatusNotReachable) { // delay connect until network is reachable
        DSDLog(@"%@:%u not reachable, waiting...", self.host, self.port);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (! self.reachabilityObserver) {
                self.reachabilityObserver =
                [[NSNotificationCenter defaultCenter] addObserverForName:DSReachabilityDidChangeNotification object:nil
                                                                   queue:nil usingBlock:^(NSNotification *note) {
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
    }
    else if (self.reachabilityObserver) {
        self.reachability = nil;
        [[NSNotificationCenter defaultCenter] removeObserver:self.reachabilityObserver];
        self.reachabilityObserver = nil;
    }
    
    self.receivedOrphanCount = 0;
    self.msgHeader = [NSMutableData data];
    self.msgPayload = [NSMutableData data];
    self.outputBuffer = [NSMutableData data];
    self.gotVerack = self.sentVerack = NO;
    self.sentFilter = self.sentGetaddr = self.sentGetdataTxBlocks = self.sentGetdataMasternode = self.sentMempool = self.sentGetblocks = self.sentGetdataGovernance = self.sentGetdataGovernanceVotes = NO ;
    self.needsFilterUpdate = NO;
    self.knownTxHashes = [NSMutableOrderedSet orderedSet];
    self.knownInstantSendLockHashes = [NSMutableOrderedSet orderedSet];
    
    self.knownBlockHashes = [NSMutableOrderedSet orderedSet];
    self.knownChainLockHashes = [NSMutableOrderedSet orderedSet];
    self.knownGovernanceObjectHashes = [NSMutableOrderedSet orderedSet];
    self.knownGovernanceObjectVoteHashes = [NSMutableOrderedSet orderedSet];
    self.currentBlock = nil;
    self.currentBlockTxHashes = nil;
    
    self.managedObjectContext = [NSManagedObjectContext peerContext];
    [self.managedObjectContext performBlockAndWait:^{
        NSArray<DSTransactionHashEntity*> * transactionHashEntities  = [DSTransactionHashEntity standaloneTransactionHashEntitiesOnChainEntity:[self.chain chainEntityInContext:self.managedObjectContext]];
        for (DSTransactionHashEntity * hashEntity in transactionHashEntities) {
            [self.knownTxHashes addObject:hashEntity.txHash];
        }
    }];
    
    
    NSString *label = [NSString stringWithFormat:@"peer.%@:%u", self.host, self.port];
    
    // use a private serial queue for processing socket io
    dispatch_async(dispatch_queue_create(label.UTF8String, NULL), ^{
        CFReadStreamRef readStream = NULL;
        CFWriteStreamRef writeStream = NULL;
        
        DSDLog(@"%@:%u connecting", self.host, self.port);
        CFStreamCreatePairWithSocketToHost(NULL, (__bridge CFStringRef)self.host, self.port, &readStream, &writeStream);
        self.inputStream = CFBridgingRelease(readStream);
        self.outputStream = CFBridgingRelease(writeStream);
        self.inputStream.delegate = self.outputStream.delegate = self;
        self.runLoop = [NSRunLoop currentRunLoop];
        [self.inputStream scheduleInRunLoop:self.runLoop forMode:NSRunLoopCommonModes];
        [self.outputStream scheduleInRunLoop:self.runLoop forMode:NSRunLoopCommonModes];
        
        // after the reachablity check, the radios should be warmed up and we can set a short socket connect timeout
        [self performSelector:@selector(disconnectWithError:)
                   withObject:[NSError errorWithDomain:@"DashSync" code:DASH_PEER_TIMEOUT_CODE
                                              userInfo:@{NSLocalizedDescriptionKey:DSLocalizedString(@"Connect timeout", nil)}]
                   afterDelay:CONNECT_TIMEOUT];
        
        [self.inputStream open];
        [self.outputStream open];
        [self sendVersionMessage];
        [self.runLoop run]; // this doesn't return until the runloop is stopped
    });
}

- (void)disconnect
{
    [self disconnectWithError:nil];
}

- (void)disconnectWithError:(NSError *)error
{
    if (_status == DSPeerStatus_Disconnected) return;
    if (!error) {
        DSDLog(@"Disconnected from peer %@ (%@ protocol %d) with no error",self.host,self.useragent,self.version);
    } else {
        DSDLog(@"Disconnected from peer %@ (%@ protocol %d) with error %@",self.host,self.useragent,self.version,error);
    }
    [NSObject cancelPreviousPerformRequestsWithTarget:self]; // cancel connect timeout

    _status = DSPeerStatus_Disconnected;
    
    if (self.reachabilityObserver) {
        self.reachability = nil;
        [[NSNotificationCenter defaultCenter] removeObserver:self.reachabilityObserver];
        self.reachabilityObserver = nil;
    }
    
    if (! self.runLoop) return;
    [self.inputStream close];
    [self.outputStream close];
    [self.inputStream removeFromRunLoop:self.runLoop forMode:NSRunLoopCommonModes];
    [self.outputStream removeFromRunLoop:self.runLoop forMode:NSRunLoopCommonModes];
    CFRunLoopStop([self.runLoop getCFRunLoop]);
    
    _status = DSPeerStatus_Disconnected;
    dispatch_async(self.delegateQueue, ^{
        [NSObject cancelPreviousPerformRequestsWithTarget:self];
        
        while (self.pongHandlers.count) {
            ((void (^)(BOOL))self.pongHandlers[0])(NO);
            [self.pongHandlers removeObjectAtIndex:0];
        }
        
        if (self.mempoolTransactionCompletion) self.mempoolTransactionCompletion(NO,YES,YES);
        self.mempoolTransactionCompletion = nil;
        [self.peerDelegate peer:self disconnectedWithError:error];
    });
}

- (void)error:(NSString *)message, ... NS_FORMAT_FUNCTION(1,2)
{
    va_list args;
    
    va_start(args, message);
    [self disconnectWithError:[NSError errorWithDomain:@"DashSync" code:500
                                              userInfo:@{NSLocalizedDescriptionKey:[[NSString alloc] initWithFormat:message arguments:args]}]];
    va_end(args);
}

- (void)didConnect
{
    if (self.status != DSPeerStatus_Connecting || ! self.sentVerack || ! self.gotVerack) return;
    
    DSDLog(@"%@:%u handshake completed %@", self.host, self.port, (self.peerDelegate.downloadPeer == self)?@"(download peer)":@"");
    [NSObject cancelPreviousPerformRequestsWithTarget:self]; // cancel pending handshake timeout
    _status = DSPeerStatus_Connected;
    
    dispatch_async(self.delegateQueue, ^{
        if (self->_status == DSPeerStatus_Connected) [self.peerDelegate peerConnected:self];
    });
}

- (void)receivedOrphanBlock {
    self.receivedOrphanCount++;
    if (self.receivedOrphanCount > 9) { //after 10 orphans mark this peer as bad by saying we got a bad block
        [self.transactionDelegate peer:self relayedTooManyOrphanBlocks:self.receivedOrphanCount];
    }
}

// MARK: - send

- (void)sendMessage:(NSData *)message type:(NSString *)type
{
    if (message.length > MAX_MSG_LENGTH) {
        DSDLog(@"%@:%u failed to send %@, length %u is too long", self.host, self.port, type, (int)message.length);
#if DEBUG
        abort();
#endif
        return;
    }
    
    if (! self.runLoop) return;
    
    CFRunLoopPerformBlock([self.runLoop getCFRunLoop], kCFRunLoopCommonModes, ^{
#if MESSAGE_LOGGING
        if (![type isEqualToString:MSG_GETDATA] && ![type isEqualToString:MSG_VERSION] && ![type isEqualToString:MSG_GETBLOCKS]) { //we log this somewhere else for better accuracy of what data is being got
            DSDLog(@"%@:%u %@sending %@", self.host, self.port, self.peerDelegate.downloadPeer == self?@"(download peer) ":@"",type);
#if MESSAGE_IN_DEPTH_TX_LOGGING
            if ([type isEqualToString:@"ix"] || [type isEqualToString:@"tx"]) {
                DSTransaction * transactionBeingSent = [DSTransaction transactionWithMessage:message onChain:self.chain];
                DSDLog(@"%@:%u transaction %@", self.host, self.port, transactionBeingSent.longDescription);
            }
#endif
#if MESSAGE_CONTENT_LOGGING
            DSDLog(@"%@:%u sending data (%lu bytes) %@", self.host, self.port, (unsigned long)message.length, message.hexString);
#endif
        }
#endif
        
        LOCK(self.outputBufferSemaphore);
        
        [self.outputBuffer appendMessage:message type:type forChain:self.chain];
        
        while (self.outputBuffer.length > 0 && self.outputStream.hasSpaceAvailable) {
            NSInteger l = [self.outputStream write:self.outputBuffer.bytes maxLength:self.outputBuffer.length];
            
            if (l > 0) [self.outputBuffer replaceBytesInRange:NSMakeRange(0, l) withBytes:NULL length:0];
            //if (self.outputBuffer.length == 0) DSDLog(@"%@:%u output buffer cleared", self.host, self.port);
        }
        
        UNLOCK(self.outputBufferSemaphore);
    });
    CFRunLoopWakeUp([self.runLoop getCFRunLoop]);
}

- (void)sendVersionMessage
{
    NSMutableData *msg = [NSMutableData data];
    uint16_t port = CFSwapInt16HostToBig(self.port);
    
    [msg appendUInt32:self.chain.protocolVersion]; // version
    [msg appendUInt64:ENABLED_SERVICES]; // services
    [msg appendUInt64:[NSDate timeIntervalSince1970]]; // timestamp
    [msg appendUInt64:self.services]; // services of remote peer
    [msg appendBytes:&_address length:sizeof(_address)]; // IPv6 address of remote peer
    [msg appendBytes:&port length:sizeof(port)]; // port of remote peer
    [msg appendNetAddress:LOCAL_HOST port:self.chain.standardPort services:ENABLED_SERVICES]; // net address of local peer
    self.localNonce = ((uint64_t)arc4random() << 32) | (uint64_t)arc4random(); // random nonce
    [msg appendUInt64:self.localNonce];
    if (self.chain.isMainnet) {
        [msg appendString:USER_AGENT]; // user agent
    } else if (self.chain.isTestnet) {
        [msg appendString:[USER_AGENT stringByAppendingString:@"(testnet)"]];
    } else {
        [msg appendString:[USER_AGENT stringByAppendingString:[NSString stringWithFormat:@"(devnet=%@)",self.chain.devnetIdentifier]]];
    }
    [msg appendUInt32:0]; // last block received
    [msg appendUInt8:0]; // relay transactions (no for SPV bloom filter mode)
    self.pingStartTime = [NSDate timeIntervalSince1970];
    
#if MESSAGE_LOGGING
        DSDLog(@"%@:%u %@sending version with protocol version %d", self.host, self.port, self.peerDelegate.downloadPeer == self?@"(download peer) ":@"",self.chain.protocolVersion);
#endif
    
    [self sendMessage:msg type:MSG_VERSION];
    
}

- (void)sendVerackMessage
{
    [self sendMessage:[NSData data] type:MSG_VERACK];
    self.sentVerack = YES;
    [self didConnect];
}

- (void)sendFilterloadMessage:(NSData *)filter
{
    self.sentFilter = YES;
    DSDLog(@"Sending filter with fingerprint %@ to node %@ %@",[NSData dataWithUInt256:filter.SHA256].shortHexString,self.host,self.peerDelegate.downloadPeer == self?@"(download peer) ":@"");
    [self sendMessage:filter type:MSG_FILTERLOAD];
}

- (void)mempoolTimeout
{
    DSDLog(@"[DSPeer] mempool time out %@",self.host);
    
    __block MempoolCompletionBlock completion = self.mempoolTransactionCompletion;
    [self sendPingMessageWithPongHandler:^(BOOL success) {
        if (completion) {
            completion(success,YES,NO);
        }
        
    }];
    self.mempoolTransactionCompletion = nil;
}

- (void)sendMempoolMessage:(NSArray *)publishedTxHashes completion:(MempoolCompletionBlock)completion
{
    DSDLog(@"%@:%u sendMempoolMessage %@",self.host,self.port,publishedTxHashes);
    [self.knownTxHashes addObjectsFromArray:publishedTxHashes];
    self.sentMempool = YES;
    
    if (completion) {
        if (self.mempoolTransactionCompletion) {
            dispatch_async(self.delegateQueue, ^{
                if (self->_status == DSPeerStatus_Connected) completion(NO,NO,NO);
            });
        }
        else {
            self.mempoolTransactionCompletion = completion;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(MEMPOOL_TIMEOUT * NSEC_PER_SEC)), self.delegateQueue, ^{
                if ([NSDate timeIntervalSince1970] - self.mempoolRequestTime >= MEMPOOL_TIMEOUT) {
                    [self mempoolTimeout];
                }
            });
        }
    }
    self.mempoolRequestTime = [NSDate timeIntervalSince1970];
    [self sendMessage:[NSData data] type:MSG_MEMPOOL];
}

- (void)sendAddrMessage
{
    NSMutableData *msg = [NSMutableData data];
    
    //TODO: send peer addresses we know about
    [msg appendVarInt:0];
    [self sendMessage:msg type:MSG_ADDR];
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

- (void)sendGetheadersMessageWithLocators:(NSArray *)locators andHashStop:(UInt256)hashStop
{
    NSMutableData *msg = [NSMutableData data];
    
    [msg appendUInt32:self.chain.protocolVersion];
    [msg appendVarInt:locators.count];
    
    for (NSData *hashData in locators) {
        [msg appendUInt256:hashData.UInt256];
    }
    
    [msg appendBytes:&hashStop length:sizeof(hashStop)];
    if (self.relayStartTime == 0) self.relayStartTime = [NSDate timeIntervalSince1970];
    [self sendMessage:msg type:MSG_GETHEADERS];
}

- (void)sendGetblocksMessageWithLocators:(NSArray *)locators andHashStop:(UInt256)hashStop
{
    NSMutableData *msg = [NSMutableData data];
    
    [msg appendUInt32:self.chain.protocolVersion];
    [msg appendVarInt:locators.count];
    
    for (NSData *hashData in locators) {
        [msg appendUInt256:hashData.UInt256];
    }
    
    [msg appendBytes:&hashStop length:sizeof(hashStop)];
    self.sentGetblocks = YES;
    
#if MESSAGE_LOGGING
    NSMutableArray *locatorHexes = [NSMutableArray arrayWithCapacity:[locators count]];
    [locators enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        uint32_t knownHeight = [self.chain heightForBlockHash:((NSData*)obj).UInt256];
        if (knownHeight == UINT32_MAX) {
            [locatorHexes addObject:[NSString stringWithFormat:@"%@ (block height unknown)",((NSData*)obj).reverse.hexString]];
        } else {
            [locatorHexes addObject:[NSString stringWithFormat:@"%@ (block %d)",((NSData*)obj).reverse.hexString,knownHeight]];
        }
    }];
    DSDLog(@"%@:%u %@sending getblocks with locators %@", self.host, self.port, self.peerDelegate.downloadPeer == self?@"(download peer) ":@"",locatorHexes);
#if MESSAGE_CONTENT_LOGGING
        DSDLog(@"%@:%u sending data %@", self.host, self.port, msg.hexString);
#endif
#endif
    
    [self sendMessage:msg type:MSG_GETBLOCKS];
}

- (void)sendInvMessageForHashes:(NSArray *)invHashes ofType:(DSInvType)invType
{
    DSDLog(@"%@:%u sending inv message of type %@ hashes count %lu", self.host, self.port, [self nameOfInvMessage:invType],(unsigned long)invHashes.count);
    NSMutableOrderedSet *hashes = [NSMutableOrderedSet orderedSetWithArray:invHashes];
    NSMutableData *msg = [NSMutableData data];
    UInt256 h;
    
    [hashes minusOrderedSet:self.knownTxHashes];
    if (hashes.count == 0) return;
    [msg appendVarInt:hashes.count];
    
    for (NSValue *hash in hashes) {
        [msg appendUInt32:invType];
        [hash getValue:&h];
        [msg appendBytes:&h length:sizeof(h)];
    }
    
    [self sendMessage:msg type:MSG_INV];
    switch (invType) {
        case DSInvType_Tx:
            [self.knownTxHashes unionOrderedSet:hashes];
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

- (void)sendTransactionInvMessagesforTransactionHashes:(NSArray *)txInvHashes txLockRequestHashes:(NSArray*)txLockRequestInvHashes {
    NSMutableOrderedSet *txHashes = txInvHashes?[NSMutableOrderedSet orderedSetWithArray:txInvHashes]:nil;
    NSMutableOrderedSet *txLockRequestHashes = txLockRequestInvHashes?[NSMutableOrderedSet orderedSetWithArray:txLockRequestInvHashes]:nil;
    NSMutableData *msg = [NSMutableData data];
    UInt256 h;
    
    [txHashes minusOrderedSet:self.knownTxHashes];
    [txLockRequestHashes minusOrderedSet:self.knownTxHashes];
    
    if (txHashes.count + txLockRequestHashes.count == 0) return;
    [msg appendVarInt:txHashes.count + txLockRequestHashes.count];
    
    for (NSValue *hash in txHashes) {
        [msg appendUInt32:DSInvType_Tx];
        [hash getValue:&h];
        [msg appendBytes:&h length:sizeof(h)];
    }
    
    for (NSValue *hash in txLockRequestHashes) {
        [msg appendUInt32:DSInvType_TxLockRequest];
        [hash getValue:&h];
        [msg appendBytes:&h length:sizeof(h)];
    }
    
    [self sendMessage:msg type:MSG_INV];
    txHashes?[self.knownTxHashes unionOrderedSet:txHashes]:nil;
    txLockRequestHashes?[self.knownTxHashes unionOrderedSet:txLockRequestHashes]:nil;
}

-(void)sendGetdataMessageForTxHash:(UInt256)txHash {
    if (!([[DSOptionsManager sharedInstance] syncType] & DSSyncType_GetsNewBlocks)) return;
    NSMutableData *msg = [NSMutableData data];
    [msg appendVarInt:1];
    [msg appendUInt32:DSInvType_Tx];
    [msg appendUInt256:txHash];
#if MESSAGE_LOGGING
    DSDLog(@"%@:%u sending getdata for transaction %@", self.host, self.port,uint256_hex(txHash));
#endif
    [self sendMessage:msg type:MSG_GETDATA];
}

- (void)sendGetdataMessageWithTxHashes:(NSArray *)txHashes instantSendLockHashes:(NSArray*)instantSendLockHashes blockHashes:(NSArray *)blockHashes chainLockHashes:(NSArray *)chainLockHashes
{
    if (!([[DSOptionsManager sharedInstance] syncType] & DSSyncType_GetsNewBlocks)) return;
    if (txHashes.count + instantSendLockHashes.count + blockHashes.count + chainLockHashes.count > MAX_GETDATA_HASHES) { // limit total hash count to MAX_GETDATA_HASHES
        DSDLog(@"%@:%u couldn't send getdata, %u is too many items, max is %u", self.host, self.port,
              (int)txHashes.count + (int)instantSendLockHashes.count + (int)blockHashes.count + (int)chainLockHashes.count, MAX_GETDATA_HASHES);
        return;
    }
    else if (txHashes.count + instantSendLockHashes.count + blockHashes.count + chainLockHashes.count == 0) return;
    
    NSMutableData *msg = [NSMutableData data];
    UInt256 h;
    
    [msg appendVarInt:txHashes.count + blockHashes.count + instantSendLockHashes.count + chainLockHashes.count];
    
    for (NSValue *hash in txHashes) {
        [msg appendUInt32:DSInvType_Tx];
        [hash getValue:&h];
        [msg appendBytes:&h length:sizeof(h)];
    }
    
    for (NSValue *hash in instantSendLockHashes) {
        [msg appendUInt32:DSInvType_InstantSendLock];
        [hash getValue:&h];
        [msg appendBytes:&h length:sizeof(h)];
    }
    
    for (NSValue *hash in blockHashes) {
        [msg appendUInt32:DSInvType_Merkleblock];
        [hash getValue:&h];
        [msg appendBytes:&h length:sizeof(h)];
    }
    
    for (NSValue *hash in chainLockHashes) {
        [msg appendUInt32:DSInvType_ChainLockSignature];
        [hash getValue:&h];
        [msg appendBytes:&h length:sizeof(h)];
    }
    
    self.sentGetdataTxBlocks = YES;
#if MESSAGE_LOGGING
    DSDLog(@"%@:%u sending getdata (transactions and blocks)", self.host, self.port);
#endif
    [self sendMessage:msg type:MSG_GETDATA];
}

-(void)sendGetMasternodeListFromPreviousBlockHash:(UInt256)previousBlockHash forBlockHash:(UInt256)blockHash {
    NSMutableData *msg = [NSMutableData data];
    [msg appendUInt256:previousBlockHash];
    [msg appendUInt256:blockHash];
    [self sendMessage:msg type:MSG_GETMNLISTDIFF];
}

- (void)sendGetdataMessageWithGovernanceObjectHashes:(NSArray<NSData*> *)governanceObjectHashes
{
    if (governanceObjectHashes.count > MAX_GETDATA_HASHES) { // limit total hash count to MAX_GETDATA_HASHES
        DSDLog(@"%@:%u couldn't send governance getdata, %u is too many items, max is %u", self.host, self.port,
              (int)governanceObjectHashes.count, MAX_GETDATA_HASHES);
        return;
    }
    else if (governanceObjectHashes.count == 0) return;
    
    NSMutableData *msg = [NSMutableData data];
    
    [msg appendVarInt:governanceObjectHashes.count];
    
    for (NSData *dataHash in governanceObjectHashes) {
        [msg appendUInt32:DSInvType_GovernanceObject];
        
        [msg appendBytes:dataHash.bytes length:sizeof(UInt256)];
    }
    
    self.sentGetdataGovernance = YES;
#if MESSAGE_LOGGING
    DSDLog(@"%@:%u sending getdata (governance objects)", self.host, self.port);
#endif
    [self sendMessage:msg type:MSG_GETDATA];
}

- (void)sendGetdataMessageWithGovernanceVoteHashes:(NSArray<NSData*> *)governanceVoteHashes {
    if (governanceVoteHashes.count > MAX_GETDATA_HASHES) { // limit total hash count to MAX_GETDATA_HASHES
        DSDLog(@"%@:%u couldn't send governance votes getdata, %u is too many items, max is %u", self.host, self.port,
              (int)governanceVoteHashes.count, MAX_GETDATA_HASHES);
        return;
    }
    else if (governanceVoteHashes.count == 0) return;
    
    NSMutableData *msg = [NSMutableData data];
    
    [msg appendVarInt:governanceVoteHashes.count];
    
    for (NSData *dataHash in governanceVoteHashes) {
        [msg appendUInt32:DSInvType_GovernanceObjectVote];
        
        [msg appendBytes:dataHash.bytes length:sizeof(UInt256)];
    }
    
    self.sentGetdataGovernanceVotes = YES;
#if MESSAGE_LOGGING
    DSDLog(@"%@:%u sending getdata (governance votes)", self.host, self.port);
#endif
    [self sendMessage:msg type:MSG_GETDATA];
}


- (void)sendGetaddrMessage
{
    self.sentGetaddr = YES;
    [self sendMessage:[NSData data] type:MSG_GETADDR];
}

- (void)sendPingMessageWithPongHandler:(void (^)(BOOL success))pongHandler;
{
    NSMutableData *msg = [NSMutableData data];
    
    dispatch_async(self.delegateQueue, ^{
        if (! self.pongHandlers) self.pongHandlers = [NSMutableArray array];
        [self.pongHandlers addObject:(pongHandler) ? [pongHandler copy] : [^(BOOL success) {} copy]];
        [msg appendUInt64:self.localNonce];
        self.pingStartTime = [NSDate timeIntervalSince1970];
        
#if MESSAGE_LOGGING
        DSDLog(@"%@:%u sending ping", self.host, self.port);
#endif
        
        [self sendMessage:msg type:MSG_PING];
    });
}

// re-request blocks starting from blockHash, useful for getting any additional transactions after a bloom filter update
- (void)rerequestBlocksFrom:(UInt256)blockHash
{
    NSUInteger i = [self.knownBlockHashes indexOfObject:uint256_obj(blockHash)];
    
    if (i != NSNotFound) {
        [self.knownBlockHashes removeObjectsInRange:NSMakeRange(0, i)];
        DSDLog(@"%@:%u re-requesting %u blocks", self.host, self.port, (int)self.knownBlockHashes.count);
        [self sendGetdataMessageWithTxHashes:nil instantSendLockHashes:nil blockHashes:self.knownBlockHashes.array chainLockHashes:nil];
    }
}

// MARK: - send Dash Sporks

-(void)sendGetSporks {
    [self sendMessage:[NSData data] type:MSG_GETSPORKS];
}

// MARK: - send Dash Masternode list

-(void)sendDSegMessage:(DSUTXO)utxo {
    NSMutableData *msg = [NSMutableData data];
    [msg appendUInt256:utxo.hash];
    if (uint256_is_zero(utxo.hash)) {
        DSDLog(@"%@:%u Requesting Masternode List",self.host, self.port);
        [msg appendUInt32:UINT32_MAX];
    } else {
        DSDLog(@"%@:%u Requesting Masternode Entry",self.host, self.port);
        [msg appendUInt32:(uint32_t)utxo.n];
    }
    
    [msg appendUInt8:0];
    [msg appendUInt32:UINT32_MAX];
    [self sendMessage:msg type:MSG_DSEG];
}

// MARK: - send Dash Governance

- (void)sendGovSync:(UInt256)parentHash { //for votes
    if (self.governanceRequestState != DSGovernanceRequestState_None) {  //Make sure we aren't in a governance sync process
        DSDLog(@"%@:%u Requesting Governance Vote Hashes out of resting state",self.host, self.port);
        return;
    }
    self.sentGovSync = TRUE;
    DSDLog(@"%@:%u Requesting Governance Object Vote Hashes",self.host, self.port);
    NSMutableData *msg = [NSMutableData data];
    //UInt256 reversed = *(UInt256*)[NSData dataWithUInt256:parentHash].reverse.bytes;
    [msg appendBytes:&parentHash length:sizeof(parentHash)];
    [msg appendData:[[[DSBloomFilter alloc] initWithFalsePositiveRate:0.01 forElementCount:20000 tweak:arc4random_uniform(10000) flags:1] toData]];
    self.governanceRequestState = DSGovernanceRequestState_GovernanceObjectVoteHashes;
    [self sendMessage:msg type:MSG_GOVOBJSYNC];
}

- (void)sendGovSync { //for governance objects
    if (self.governanceRequestState != DSGovernanceRequestState_None) {//Make sure we aren't in a governance sync process
        DSDLog(@"%@:%u Requesting Governance Object Hashes out of resting state",self.host, self.port);
        return;
    }
    DSDLog(@"%@:%u Requesting Governance Object Hashes",self.host, self.port);
    UInt256 h = UINT256_ZERO;
    NSMutableData *msg = [NSMutableData data];
    
    [msg appendBytes:&h length:sizeof(h)];
    [msg appendData:[DSBloomFilter emptyBloomFilterData]];
    self.governanceRequestState = DSGovernanceRequestState_GovernanceObjectHashes;
    [self sendMessage:msg type:MSG_GOVOBJSYNC];
    
    //we aren't afraid of coming back here within 5 seconds because a peer can only sendGovSync once every 3 hours
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.governanceRequestState == DSGovernanceRequestState_GovernanceObjectHashes) {
            DSDLog(@"%@:%u Peer ignored request for governance object hashes",self.host, self.port);
            [self.governanceDelegate peer:self ignoredGovernanceSync:DSGovernanceRequestState_GovernanceObjectHashes];
        }
    });
}

-(void)sendGovObjectVote:(DSGovernanceVote*)governanceVote {
    [self sendMessage:[governanceVote dataMessage] type:MSG_GOVOBJVOTE];
}

-(void)sendGovObject:(DSGovernanceObject*)governanceObject {
    [self sendMessage:[governanceObject dataMessage] type:MSG_GOVOBJ];
}


// MARK: - accept

- (void)acceptMessage:(NSData *)message type:(NSString *)type
{
#if MESSAGE_LOGGING
    if (![type isEqualToString:MSG_INV] && ![type isEqualToString:MSG_GOVOBJVOTE] && ![type isEqualToString:MSG_MERKLEBLOCK]) {
        DSDLog(@"%@:%u accept message %@", self.host, self.port, type);
    }
#endif
    if (self.currentBlock && (! ([MSG_TX isEqual:type] || [MSG_IX isEqual:type] ))) { // if we receive a non-tx message, merkleblock is done
        UInt256 hash = self.currentBlock.blockHash;
        
        self.currentBlock = nil;
        self.currentBlockTxHashes = nil;
        [self error:@"incomplete merkleblock %@, expected %u more tx, got %@",
         uint256_obj(hash), (int)self.currentBlockTxHashes.count, type];
    }
    else if ([MSG_VERSION isEqual:type]) [self acceptVersionMessage:message];
    else if ([MSG_VERACK isEqual:type]) [self acceptVerackMessage:message];
    else if ([MSG_ADDR isEqual:type]) [self acceptAddrMessage:message];
    else if ([MSG_INV isEqual:type]) [self acceptInvMessage:message];
    else if ([MSG_TX isEqual:type]) [self acceptTxMessage:message];
    else if ([MSG_IX isEqual:type]) [self acceptTxMessage:message];
    else if ([MSG_ISLOCK isEqual:type]) [self acceptIslockMessage:message];
    else if ([MSG_HEADERS isEqual:type]) [self acceptHeadersMessage:message];
    else if ([MSG_GETADDR isEqual:type]) [self acceptGetaddrMessage:message];
    else if ([MSG_GETDATA isEqual:type]) [self acceptGetdataMessage:message];
    else if ([MSG_NOTFOUND isEqual:type]) [self acceptNotfoundMessage:message];
    else if ([MSG_PING isEqual:type]) [self acceptPingMessage:message];
    else if ([MSG_PONG isEqual:type]) [self acceptPongMessage:message];
    else if ([MSG_MERKLEBLOCK isEqual:type]) [self acceptMerkleblockMessage:message];
    else if ([MSG_CHAINLOCK isEqual:type]) [self acceptChainLockMessage:message];
    else if ([MSG_REJECT isEqual:type]) [self acceptRejectMessage:message];
    else if ([MSG_FEEFILTER isEqual:type]) [self acceptFeeFilterMessage:message];
    //control
    else if ([MSG_SPORK isEqual:type]) [self acceptSporkMessage:message];
    //masternode
    else if ([MSG_SSC isEqual:type]) [self acceptSSCMessage:message];
    else if ([MSG_MNB isEqual:type]) [self acceptMNBMessage:message];
    else if ([MSG_MNLISTDIFF isEqual:type]) [self acceptMNLISTDIFFMessage:message];
    //governance
    else if ([MSG_GOVOBJVOTE isEqual:type]) [self acceptGovObjectVoteMessage:message];
    else if ([MSG_GOVOBJ isEqual:type]) [self acceptGovObjectMessage:message];
    //else if ([MSG_GOVOBJSYNC isEqual:type]) [self acceptGovObjectSyncMessage:message];
    
    //private send
    else if ([MSG_DARKSENDANNOUNCE isEqual:type]) [self acceptDarksendAnnounceMessage:message];
    else if ([MSG_DARKSENDCONTROL isEqual:type]) [self acceptDarksendControlMessage:message];
    else if ([MSG_DARKSENDFINISH isEqual:type]) [self acceptDarksendFinishMessage:message];
    else if ([MSG_DARKSENDINITIATE isEqual:type]) [self acceptDarksendInitiateMessage:message];
    else if ([MSG_DARKSENDQUORUM isEqual:type]) [self acceptDarksendQuorumMessage:message];
    else if ([MSG_DARKSENDSESSION isEqual:type]) [self acceptDarksendSessionMessage:message];
    else if ([MSG_DARKSENDSESSIONUPDATE isEqual:type]) [self acceptDarksendSessionUpdateMessage:message];
    else if ([MSG_DARKSENDTX isEqual:type]) [self acceptDarksendTransactionMessage:message];
    else {
#if DROP_MESSAGE_LOGGING
        DSDLog(@"%@:%u dropping %@, len:%u, not implemented", self.host, self.port, type, (int)message.length);
#endif
    }
}

- (void)acceptVersionMessage:(NSData *)message
{
    NSNumber * l = nil;
    
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

    if (self.version < self.chain.minProtocolVersion) {
#if MESSAGE_LOGGING
        DSDLog(@"%@:%u protocol version %u not supported, useragent:\"%@\"", self.host, self.port, self.version, self.useragent);
#endif
        [self error:@"protocol version %u not supported", self.version];
        return;
    } else {
#if MESSAGE_LOGGING
        DSDLog(@"%@:%u got version %u, useragent:\"%@\"", self.host, self.port, self.version, self.useragent);
#endif
    }
    
    [self sendVerackMessage];
}

- (void)acceptVerackMessage:(NSData *)message
{
    if (self.gotVerack) {
        DSDLog(@"%@:%u got unexpected verack", self.host, self.port);
        return;
    }
    
    _pingTime = [NSDate timeIntervalSince1970] - self.pingStartTime; // use verack time as initial ping time
    self.pingStartTime = 0;
#if MESSAGE_LOGGING
    DSDLog(@"%@:%u got verack in %fs", self.host, self.port, self.pingTime);
#endif
    self.gotVerack = YES;
    [self didConnect];
}

// TODO: relay addresses
- (void)acceptAddrMessage:(NSData *)message
{
    if (message.length > 0 && [message UInt8AtOffset:0] == 0) {
        DSDLog(@"%@:%u got addr with 0 addresses", self.host, self.port);
        return;
    }
    else if (message.length < 5) {
        [self error:@"malformed addr message, length %u is too short", (int)message.length];
        return;
    }
    else if (! self.sentGetaddr) return; // simple anti-tarpitting tactic, don't accept unsolicited addresses
    
    NSTimeInterval now = [NSDate timeIntervalSince1970];
    NSNumber * l = nil;
    NSUInteger count = (NSUInteger)[message varIntAtOffset:0 length:&l];
    NSMutableArray *peers = [NSMutableArray array];
    
    if (count > 1000) {
        DSDLog(@"%@:%u dropping addr message, %u is too many addresses (max 1000)", self.host, self.port, (int)count);
        return;
    }
    else if (message.length < l.unsignedIntegerValue + count*30) {
        [self error:@"malformed addr message, length is %u, should be %u for %u addresses", (int)message.length,
         (int)(l.unsignedIntegerValue + count*30), (int)count];
        return;
    }
    else DSDLog(@"%@:%u got addr with %u addresses", self.host, self.port, (int)count);
    
    for (NSUInteger off = l.unsignedIntegerValue; off < l.unsignedIntegerValue + 30*count; off += 30) {
        NSTimeInterval timestamp = [message UInt32AtOffset:off];
        uint64_t services = [message UInt64AtOffset:off + sizeof(uint32_t)];
        UInt128 address = *(UInt128 *)((const uint8_t *)message.bytes + off + sizeof(uint32_t) + sizeof(uint64_t));
        uint16_t port = CFSwapInt16BigToHost(*(const uint16_t *)((const uint8_t *)message.bytes + off +
                                                                 sizeof(uint32_t) + sizeof(uint64_t) +
                                                                 sizeof(UInt128)));
        
        if (! (services & SERVICES_NODE_NETWORK)) continue; // skip peers that don't carry full blocks
        if (address.u64[0] != 0 || address.u32[2] != CFSwapInt32HostToBig(0xffff)) continue; // ignore IPv6 for now
        
        // if address time is more than 10 min in the future or older than reference date, set to 5 days old
        if (timestamp > now + 10*60 || timestamp < 0) timestamp = now - 5*24*60*60;
        
        // subtract two hours and add it to the list
        [peers addObject:[[DSPeer alloc] initWithAddress:address port:port onChain:self.chain timestamp:timestamp - 2*60*60
                                                services:services]];
    }
    
    dispatch_async(self.delegateQueue, ^{
        if (self->_status == DSPeerStatus_Connected) [self.peerDelegate peer:self relayedPeers:peers];
    });
}

-(NSString*)nameOfInvMessage:(DSInvType)type {
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
        default:
            return @"";
    }
}

#define RANDOM_ERROR_INV 0

- (void)acceptInvMessage:(NSData *)message
{
    NSNumber * l = nil;
    NSUInteger count = (NSUInteger)[message varIntAtOffset:0 length:&l];
    NSMutableOrderedSet *txHashes = [NSMutableOrderedSet orderedSet];
    NSMutableOrderedSet *instantSendLockHashes = [NSMutableOrderedSet orderedSet];
    NSMutableOrderedSet *chainLockHashes = [NSMutableOrderedSet orderedSet];
    NSMutableOrderedSet *blockHashes = [NSMutableOrderedSet orderedSet];
    NSMutableSet *sporkHashes = [NSMutableSet set];
    NSMutableSet *governanceObjectHashes = [NSMutableSet set];
    NSMutableSet *governanceObjectVoteHashes = [NSMutableSet set];
    
    if (l.unsignedIntegerValue == 0 || message.length < l.unsignedIntegerValue + count*36) {
        [self error:@"malformed inv message, length is %u, should be %u for %u items", (int)message.length,
         (int)(((l.unsignedIntegerValue == 0) ? 1 : l.unsignedIntegerValue) + count*36), (int)count];
        return;
    }
    else if (count > MAX_GETDATA_HASHES) {
        DSDLog(@"%@:%u dropping inv message, %u is too many items, max is %u", self.host, self.port, (int)count,
              MAX_GETDATA_HASHES);
        return;
    }
    
    if (count == 0) {
        DSDLog(@"Got empty Inv message");
    }
    
    if (count > 0 && ([message UInt32AtOffset:l.unsignedIntegerValue] != DSInvType_MasternodePing) && ([message UInt32AtOffset:l.unsignedIntegerValue] != DSInvType_MasternodePaymentVote) && ([message UInt32AtOffset:l.unsignedIntegerValue] != DSInvType_MasternodeVerify) && ([message UInt32AtOffset:l.unsignedIntegerValue] != DSInvType_GovernanceObjectVote) && ([message UInt32AtOffset:l.unsignedIntegerValue] != DSInvType_DSTx)) {
        DSDLog(@"%@:%u got inv with %u item%@ (first item %@ with hash %@/%@)", self.host, self.port, (int)count,count==1?@"":@"s",[self nameOfInvMessage:[message UInt32AtOffset:l.unsignedIntegerValue]],[NSData dataWithUInt256:[message UInt256AtOffset:l.unsignedIntegerValue + sizeof(uint32_t)]].hexString,[NSData dataWithUInt256:[message UInt256AtOffset:l.unsignedIntegerValue + sizeof(uint32_t)]].reverse.hexString);
    }
    
    BOOL onlyPrivateSendTransactions = NO;
    
    for (NSUInteger off = l.unsignedIntegerValue; off < l.unsignedIntegerValue + 36*count; off += 36) {
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
            case DSInvType_InstantSendLock : [instantSendLockHashes addObject:uint256_obj(hash)]; break;
            case DSInvType_Block: [blockHashes addObject:uint256_obj(hash)]; break;
            case DSInvType_Merkleblock: [blockHashes addObject:uint256_obj(hash)]; break;
            case DSInvType_Spork: [sporkHashes addObject:[NSData dataWithUInt256:hash]]; break;
            case DSInvType_GovernanceObject: [governanceObjectHashes addObject:[NSData dataWithUInt256:hash]]; break;
            case DSInvType_GovernanceObjectVote: break;//[governanceObjectVoteHashes addObject:[NSData dataWithUInt256:hash]]; break;
            case DSInvType_MasternodePing: break;//[masternodePingHashes addObject:uint256_obj(hash)]; break;
            case DSInvType_MasternodePaymentVote: break;
            case DSInvType_MasternodeVerify: break;
            case DSInvType_MasternodeBroadcast: break;
            case DSInvType_QuorumFinalCommitment: break;
            case DSInvType_DummyCommitment: break;
            case DSInvType_QuorumContribution: break;
            case DSInvType_CompactBlock: break;
            case DSInvType_ChainLockSignature: [chainLockHashes addObject:uint256_obj(hash)]; break;
            default:
            {
                NSAssert(FALSE, @"inventory type not dealt with");
                break;
            }
        }
    }
    
    if ([self.chain syncsBlockchain] && !self.sentFilter && ! self.sentMempool && ! self.sentGetblocks && (txHashes.count > 0) && !onlyPrivateSendTransactions) {
        [self error:@"got tx inv message before loading a filter"];
        return;
    }
    else if (txHashes.count + instantSendLockHashes.count > 10000) { // this was happening on testnet, some sort of DOS/spam attack?
        DSDLog(@"%@:%u too many transactions, disconnecting", self.host, self.port);
        [self disconnect]; // disconnecting seems to be the easiest way to mitigate it
        return;
    }
    else if (self.currentBlockHeight > 0 && blockHashes.count > 2 && blockHashes.count < 500 &&
             self.currentBlockHeight + self.knownBlockHashes.count + blockHashes.count < self.lastBlockHeight) {
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
        dispatch_async(self.delegateQueue, ^{
            [self.knownBlockHashes unionOrderedSet:blockHashes];
            
            while (self.knownBlockHashes.count > MAX_GETDATA_HASHES) {
                [self.knownBlockHashes removeObjectsInRange:NSMakeRange(0, self.knownBlockHashes.count/3)];
            }
        });
    }
    
    if ([txHashes intersectsOrderedSet:self.knownTxHashes]) { // remove transactions we already have
        for (NSValue *hash in txHashes) {
            UInt256 h;
            
            if (! [self.knownTxHashes containsObject:hash]) continue;
            [hash getValue:&h];
            
            dispatch_async(self.delegateQueue, ^{
                if (self->_status == DSPeerStatus_Connected) [self.transactionDelegate peer:self hasTransactionWithHash:h];
            });
        }
        
        [txHashes minusOrderedSet:self.knownTxHashes];
    }
    
    [self.knownTxHashes unionOrderedSet:txHashes];
    
    if (instantSendLockHashes.count > 0) {
        for (NSValue *hash in instantSendLockHashes) {
            UInt256 h;
            
            if (! [self.knownInstantSendLockHashes containsObject:hash]) continue;
            [hash getValue:&h];
        }
        
        [instantSendLockHashes minusOrderedSet:self.knownInstantSendLockHashes];
        
        dispatch_async(self.delegateQueue, ^{
            if (self->_status == DSPeerStatus_Connected) [self.transactionDelegate peer:self hasInstantSendLockHashes:instantSendLockHashes];
        });
        
        [self.knownInstantSendLockHashes unionOrderedSet:instantSendLockHashes];
    }
    
    
    if (chainLockHashes.count > 0) {
        for (NSValue *hash in chainLockHashes) {
            UInt256 h;
            
            if (! [self.knownChainLockHashes containsObject:hash]) continue;
            [hash getValue:&h];
        }
        
        [chainLockHashes minusOrderedSet:self.knownChainLockHashes];
        
        dispatch_async(self.delegateQueue, ^{
            if (self->_status == DSPeerStatus_Connected) [self.transactionDelegate peer:self hasChainLockHashes:chainLockHashes];
        });
        
        [self.knownChainLockHashes unionOrderedSet:chainLockHashes];
    }
    
    if (txHashes.count + instantSendLockHashes.count > 0 || (! self.needsFilterUpdate && ((blockHashes.count + chainLockHashes.count) > 0))) {
        [self sendGetdataMessageWithTxHashes:txHashes.array instantSendLockHashes:instantSendLockHashes.array blockHashes:(self.needsFilterUpdate) ? nil : blockHashes.array chainLockHashes:chainLockHashes.array];
    }
    
    // to improve chain download performance, if we received 500 block hashes, we request the next 500 block hashes
    if (blockHashes.count >= 500 && ! self.needsFilterUpdate) {
        if ([self.chain.chainManager shouldRequestMerkleBlocksForZoneAfterHeight:self.chain.lastSyncBlockHeight + 1]) {
            [self sendGetblocksMessageWithLocators:@[uint256_data_from_obj(blockHashes.lastObject), uint256_data_from_obj(blockHashes.firstObject)]
            andHashStop:UINT256_ZERO];
        } else {
            [self sendGetheadersMessageWithLocators:@[uint256_data_from_obj(blockHashes.lastObject), uint256_data_from_obj(blockHashes.firstObject)]
                                       andHashStop:UINT256_ZERO];
        }

    }
    
    if (self.mempoolTransactionCompletion && (txHashes.count + governanceObjectHashes.count + sporkHashes.count > 0)) {
        self.mempoolRequestTime = [NSDate timeIntervalSince1970]; // this will cancel the mempool timeout
        DSDLog(@"[DSPeer] got mempool tx inv messages %@",self.host);
        __block MempoolCompletionBlock completion = self.mempoolTransactionCompletion;
        [self sendPingMessageWithPongHandler:^(BOOL success) {
            if (completion) {
                completion(success,YES,NO);
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

- (void)acceptTxMessage:(NSData *)message
{
    DSTransaction *tx = [DSTransactionFactory transactionWithMessage:message onChain:self.chain];
    
    if (! tx && ![DSTransactionFactory shouldIgnoreTransactionMessage:message]) {
        [self error:@"malformed tx message: %@", message];
        return;
    }
    else if (! self.sentFilter && ! self.sentGetdataTxBlocks) {
        [self error:@"got tx message before loading a filter"];
        return;
    }
    
    if (tx) {
        __block DSMerkleBlock * currentBlock = self.currentBlock;
        dispatch_async(self.delegateQueue, ^{
            [self.transactionDelegate peer:self relayedTransaction:tx inBlock:currentBlock];
        });
        #if LOG_FULL_TX_MESSAGE
            DSDLog(@"%@:%u got tx %@ %@", self.host, self.port, uint256_obj(tx.txHash),message.hexString);
        #else
            DSDLog(@"%@:%u got tx %@", self.host, self.port, uint256_obj(tx.txHash));
        #endif
    }

    
    if (self.currentBlock) { // we're collecting tx messages for a merkleblock
        UInt256 txHash = tx?tx.txHash:message.SHA256_2;
        if ([self.currentBlockTxHashes containsObject:uint256_obj(txHash)]) {
            [self.currentBlockTxHashes removeObject:uint256_obj(txHash)];
        } else {
            DSDLog(@"%@:%u current block does not contain transaction %@ (contains %@)", self.host, self.port,uint256_hex(txHash),self.currentBlockTxHashes);
        }
        
        if (self.currentBlockTxHashes.count == 0) { // we received the entire block including all matched tx
            DSMerkleBlock *block = self.currentBlock;
            
            DSDLog(@"%@:%u clearing current block", self.host, self.port);
            
            self.currentBlock = nil;
            self.currentBlockTxHashes = nil;
            
            dispatch_sync(self.delegateQueue, ^{ // syncronous dispatch so we don't get too many queued up tx
                [self.transactionDelegate peer:self relayedBlock:block];
            });
        }
    } else {
        DSDLog(@"%@:%u no current block", self.host, self.port);
    }
    
}



- (void)acceptIslockMessage:(NSData *)message
{
#if LOG_TX_LOCK_VOTES
    DSDLog(@"peer relayed islock message: %@", message.hexString);
#endif
    if (![self.chain.chainManager.sporkManager deterministicMasternodeListEnabled]) {
        DSDLog(@"returned instant send lock message when DML not enabled: %@", message);//no error here
        return;
    }
    if (![self.chain.chainManager.sporkManager llmqInstantSendEnabled]) {
        DSDLog(@"returned instant send lock message when llmq instant send is not enabled: %@", message);//no error here
        return;
    }
    DSInstantSendTransactionLock *instantSendTransactionLock = [DSInstantSendTransactionLock instantSendTransactionLockWithMessage:message onChain:self.chain];
    
    if (! instantSendTransactionLock) {
        [self error:@"malformed islock message: %@", message];
        return;
    }
    else if (! self.sentFilter && ! self.sentGetdataTxBlocks) {
        [self error:@"got islock message before loading a filter"];
        return;
    }
    
    dispatch_async(self.delegateQueue, ^{
        [self.transactionDelegate peer:self relayedInstantSendTransactionLock:instantSendTransactionLock];;
    });
    
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

- (void)acceptHeadersMessage:(NSData *)message
{
    NSNumber * lNumber = nil;
    NSUInteger count = (NSUInteger)[message varIntAtOffset:0 length:&lNumber];
    NSUInteger l = lNumber.unsignedIntegerValue;
    NSUInteger off = 0;
    
    if (message.length < l + 81*count) {
        [self error:@"malformed headers message, length is %u, should be %u for %u items", (int)message.length,
         (int)(((l == 0) ? 1 : l) + count*81), (int)count];
        return;
    }
    if (count == 0) {
        DSDLog(@"%@:%u got 0 headers (%@)", self.host, self.port, message.hexString);
    } else {
        DSDLog(@"%@:%u got %u headers", self.host, self.port, (int)count);
    }
    
#if LOG_ALL_HEADERS_IN_ACCEPT_HEADERS
    for (int i =0;i<count;i++) {
        NSData * headerData = [message subdataWithRange:NSMakeRange(l+ 81*i, 80)];
        DSDLog(@"BLOCK HEADER ----------");
        DSDLog(@"block version %u",[headerData UInt8AtOffset:0]);
        DSDLog(@"previous blockheader hash %@ (%@)",[NSData dataWithUInt256:[headerData UInt256AtOffset:4]].hexString,[NSData dataWithUInt256:[headerData UInt256AtOffset:4]].reverse.hexString);
        DSDLog(@"merkle root %@",[NSData dataWithUInt256:[headerData UInt256AtOffset:36]].hexString);
        uint32_t timestamp = [headerData UInt32AtOffset:68];
        DSDLog(@"timestamp %x (%u) time is %@",timestamp,timestamp,[NSDate dateWithTimeIntervalSince1970:timestamp]);
        DSDLog(@"target is %x",[headerData UInt32AtOffset:72]);
        DSDLog(@"nonce is %x",[headerData UInt32AtOffset:76]);
        DSDLog(@"transaction count is %u",[headerData UInt8AtOffset:80]);
        DSDLog(@"-----------------------");
    }
#endif
    
    if (_relayStartTime != 0) { // keep track of relay peformance
        NSTimeInterval speed = count/([NSDate timeIntervalSince1970] - self.relayStartTime);
        
        if (_relaySpeed == 0) _relaySpeed = speed;
        _relaySpeed = _relaySpeed*0.9 + speed*0.1;
        _relayStartTime = 0;
    }
    //    for (int i = 0; i < count; i++) {
    //        UInt256 locator = [message subdataWithRange:NSMakeRange(l + 81*i, 80)].x11;
    //        DSDLog(@"%@:%u header: %@", self.host, self.port, uint256_obj(locator));
    //    }
    // To improve chain download performance, if this message contains 2000 headers then request the next 2000 headers
    // immediately, and switch to requesting blocks when we receive a header newer than earliestKeyTime
    // Devnets can run slower than usual
    NSTimeInterval lastTimestamp = [message UInt32AtOffset:l + 81*(count - 1) + 68];
    NSTimeInterval firstTimestamp = [message UInt32AtOffset:l + 81 + 68];
    if (!self.chain.needsInitialTerminalHeadersSync && (firstTimestamp + DAY_TIME_INTERVAL*2 >= self.earliestKeyTime) && [self.chain.chainManager shouldRequestMerkleBlocksForZoneAfterHeight:self.chain.lastSyncBlockHeight + 1]) {
        //this is a rare scenario where we called getheaders but the first header returned was actually past the cuttoff, but the previous header was before the cuttoff
        DSDLog(@"%@:%u calling getblocks with locators: %@", self.host, self.port, [self.chain chainSyncBlockLocatorArray]);
        [self sendGetblocksMessageWithLocators:self.chain.chainSyncBlockLocatorArray andHashStop:UINT256_ZERO];
        return;
    }
    if (!count) return;
    if (count >= self.chain.headersMaxAmount || (((lastTimestamp + DAY_TIME_INTERVAL*2) >= self.earliestKeyTime) && (!self.chain.needsInitialTerminalHeadersSync))) {
        UInt256 firstBlockHash = [message subdataWithRange:NSMakeRange(l, 80)].x11;
        UInt256 lastBlockHash = [message subdataWithRange:NSMakeRange(l + 81*(count - 1), 80)].x11;
        NSData *firstHashData = uint256_data(firstBlockHash);
        NSData *lastHashData = uint256_data(lastBlockHash);
        
        
        if (((lastTimestamp + DAY_TIME_INTERVAL*2) >= self.earliestKeyTime) && (!self.chain.needsInitialTerminalHeadersSync) && [self.chain.chainManager shouldRequestMerkleBlocksForZoneAfterHeight:self.chain.lastSyncBlockHeight + 1]) { // request blocks for the remainder of the chain
            NSTimeInterval timestamp = [message UInt32AtOffset:l + 81 + 68];
            
            for (off = l; timestamp > 0 && ((timestamp + DAY_TIME_INTERVAL*2) < self.earliestKeyTime);) {
                off += 81;
                timestamp = [message UInt32AtOffset:off + 81 + 68];
            }
            lastBlockHash = [message subdataWithRange:NSMakeRange(off, 80)].x11;
            lastHashData = uint256_data(lastBlockHash);
            DSDLog(@"%@:%u calling getblocks with locators: %@", self.host, self.port, @[lastHashData.reverse.hexString, firstHashData.reverse.hexString]);
            [self sendGetblocksMessageWithLocators:@[lastHashData, firstHashData] andHashStop:UINT256_ZERO];
        }
        else {
            DSDLog(@"%@:%u calling getheaders with locators: %@", self.host, self.port,
                  @[lastHashData.reverse.hexString, firstHashData.reverse.hexString]);
            [self sendGetheadersMessageWithLocators:@[lastHashData, firstHashData] andHashStop:UINT256_ZERO];
        }
    }
    for (NSUInteger off = l; off < l + 81*count; off += 81) {
        DSMerkleBlock *block = [DSMerkleBlock merkleBlockWithMessage:[message subdataWithRange:NSMakeRange(off, 81)] onChain:self.chain];
        if (! block.valid) {
            [self error:@"invalid block header %@", uint256_obj(block.blockHash)];
            return;
        }
        
        dispatch_async(self.delegateQueue, ^{
            [self.transactionDelegate peer:self relayedHeader:block];
        });
    }
}

- (void)acceptGetaddrMessage:(NSData *)message
{
    DSDLog(@"%@:%u got getaddr", self.host, self.port);
    [self sendAddrMessage];
}

- (void)acceptGetdataMessage:(NSData *)message
{
    NSNumber * lNumber = nil;
    NSUInteger l, count = (NSUInteger)[message varIntAtOffset:0 length:&lNumber];
    l = lNumber.unsignedIntegerValue;
    
    if (l == 0 || message.length < l + count*36) {
        [self error:@"malformed getdata message, length is %u, should be %u for %u items", (int)message.length,
         (int)(((l == 0) ? 1 : l) + count*36), (int)count];
        return;
    }
    else if (count > MAX_GETDATA_HASHES) {
        DSDLog(@"%@:%u dropping getdata message, %u is too many items, max is %u", self.host, self.port, (int)count,
              MAX_GETDATA_HASHES);
        return;
    }
    
    DSDLog(@"%@:%u %@got getdata for %u item%@", self.host, self.port, self.peerDelegate.downloadPeer == self?@"(download peer)":@"", (int)count,count==1?@"":@"s");
    
    dispatch_async(self.delegateQueue, ^{
        NSMutableData *notfound = [NSMutableData data];
        
        for (NSUInteger off = l; off < l + count*36; off += 36) {
            DSInvType type = [message UInt32AtOffset:off];
            UInt256 hash = [message UInt256AtOffset:off + sizeof(uint32_t)];
            DSTransaction *transaction = nil;
            
            if (uint256_is_zero(hash)) continue;
            
            switch (type) {
                case DSInvType_Tx:
                case DSInvType_TxLockRequest:
                    transaction = [self.transactionDelegate peer:self requestedTransaction:hash];
                    
                    if (transaction) {
                        [self sendMessage:transaction.data type:MSG_TX];
                        break;
                    } else {
                        DSDLog(@"peer %@ requested transaction was not found with hash %@ reversed %@",self.host,[NSData dataWithUInt256:hash].hexString,[NSData dataWithUInt256:hash].reverse.hexString);
                        [notfound appendUInt32:type];
                        [notfound appendBytes:&hash length:sizeof(hash)];
                        break;
                    }
                case DSInvType_GovernanceObjectVote:
                {
                    DSGovernanceVote * vote = [self.governanceDelegate peer:self requestedVote:hash];
                    if (vote) {
                        [self sendMessage:vote.dataMessage type:MSG_GOVOBJVOTE];
                        break;
                    } else {
                        [notfound appendUInt32:type];
                        [notfound appendBytes:&hash length:sizeof(hash)];
                        break;
                    }
                    break;
                }
                case DSInvType_GovernanceObject:
                {
                    DSGovernanceObject * governanceObject = [self.governanceDelegate peer:self requestedGovernanceObject:hash];
                    if (governanceObject) {
                        [self sendMessage:governanceObject.dataMessage type:MSG_GOVOBJ];
                        break;
                    } else {
                        [notfound appendUInt32:type];
                        [notfound appendBytes:&hash length:sizeof(hash)];
                        break;
                    }
                    break;
                }
                    // fall through
                default:
                    [notfound appendUInt32:type];
                    [notfound appendBytes:&hash length:sizeof(hash)];
                    break;
            }
        }
        
        if (notfound.length > 0) {
            NSMutableData *msg = [NSMutableData data];
            
            [msg appendVarInt:notfound.length/36];
            [msg appendData:notfound];
            [self sendMessage:msg type:MSG_NOTFOUND];
        }
    });
}

- (void)acceptNotfoundMessage:(NSData *)message
{
    NSNumber * lNumber = nil;
    NSMutableArray *txHashes = [NSMutableArray array], *txLockRequestHashes = [NSMutableArray array], *blockHashes = [NSMutableArray array];
    NSUInteger l, count = (NSUInteger)[message varIntAtOffset:0 length:&lNumber];
    l = lNumber.unsignedIntegerValue;
    
    if (l == 0 || message.length < l + count*36) {
        [self error:@"malformed notfound message, length is %u, should be %u for %u items", (int)message.length,
         (int)(((l == 0) ? 1 : l) + count*36), (int)count];
        return;
    }
    
    DSDLog(@"%@:%u got notfound with %u item%@ (first item %@)", self.host, self.port, (int)count,count==1?@"":@"s",[self nameOfInvMessage:[message UInt32AtOffset:l]]);
    
    for (NSUInteger off = l; off < l + 36*count; off += 36) {
        if ([message UInt32AtOffset:off] == DSInvType_Tx) {
            [txHashes addObject:uint256_obj([message UInt256AtOffset:off + sizeof(uint32_t)])];
        }
        else if ([message UInt32AtOffset:off] == DSInvType_TxLockRequest) {
            [txLockRequestHashes addObject:uint256_obj([message UInt256AtOffset:off + sizeof(uint32_t)])];
        }
        else if ([message UInt32AtOffset:off] == DSInvType_Merkleblock) {
            [blockHashes addObject:uint256_obj([message UInt256AtOffset:off + sizeof(uint32_t)])];
        }
    }
    
    dispatch_async(self.delegateQueue, ^{
        [self.transactionDelegate peer:self relayedNotFoundMessagesWithTransactionHashes:txHashes andBlockHashes:blockHashes];
    });
}

- (void)acceptPingMessage:(NSData *)message
{
    if (message.length < sizeof(uint64_t)) {
        [self error:@"malformed ping message, length is %u, should be 4", (int)message.length];
        return;
    }
#if MESSAGE_LOGGING
    DSDLog(@"%@:%u got ping", self.host, self.port);
#endif
    [self sendMessage:message type:MSG_PONG];
}

- (void)acceptPongMessage:(NSData *)message
{
    if (message.length < sizeof(uint64_t)) {
        [self error:@"malformed pong message, length is %u, should be 4", (int)message.length];
        return;
    }
    else if ([message UInt64AtOffset:0] != self.localNonce) {
        [self error:@"pong message contained wrong nonce: %llu, expected: %llu", [message UInt64AtOffset:0],
         self.localNonce];
        return;
    }
    else if (! self.pongHandlers.count) {
        DSDLog(@"%@:%u got unexpected pong", self.host, self.port);
        return;
    }
    
    if (self.pingStartTime > 1) {
        NSTimeInterval pingTime = [NSDate timeIntervalSince1970] - self.pingStartTime;
        
        // 50% low pass filter on current ping time
        _pingTime = self.pingTime*0.5 + pingTime*0.5;
        self.pingStartTime = 0;
    }
    
#if MESSAGE_LOGGING
    DSDLog(@"%@:%u got pong in %fs", self.host, self.port, self.pingTime);
#endif
    
    dispatch_async(self.delegateQueue, ^{
        if (self->_status == DSPeerStatus_Connected && self.pongHandlers.count) {
            ((void (^)(BOOL))self.pongHandlers[0])(YES);
            [self.pongHandlers removeObjectAtIndex:0];
        }
    });
}

#define SAVE_INCOMING_BLOCKS 0

- (void)acceptMerkleblockMessage:(NSData *)message
{
    // Dash nodes don't support querying arbitrary transactions, only transactions not yet accepted in a block. After
    // a merkleblock message, the remote node is expected to send tx messages for the tx referenced in the block. When a
    // non-tx message is received we should have all the tx in the merkleblock.
    DSMerkleBlock *block = [DSMerkleBlock merkleBlockWithMessage:message onChain:self.chain];
    
    if (! block.valid) {
        [self error:@"invalid merkleblock: %@", uint256_obj(block.blockHash)];
        return;
    }
    else if (! self.sentFilter && ! self.sentGetdataTxBlocks) {
        [self error:@"got merkleblock message before loading a filter"];
        return;
    }
    //else DSDLog(@"%@:%u got merkleblock %@", self.host, self.port, block.blockHash);
    
    NSMutableOrderedSet *txHashes = [NSMutableOrderedSet orderedSetWithArray:block.transactionHashes];
    
    [txHashes minusOrderedSet:self.knownTxHashes];
    
    if (txHashes.count > 0) { // wait til we get all the tx messages before processing the block
        self.currentBlock = block;
        self.currentBlockTxHashes = txHashes;
    }
    else {
        dispatch_async(self.delegateQueue, ^{
            [self.transactionDelegate peer:self relayedBlock:block];
            
            #if SAVE_INCOMING_BLOCKS
                NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
                NSString *documentsDirectory = [paths objectAtIndex:0];
                NSString *dataPath = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%d-%@.block",self.chain.devnetIdentifier,block.height,uint256_hex(block.blockHash)]];

                 // Save it into file system
                [message writeToFile:dataPath atomically:YES];
                
            #endif
        });
    }
}

// DIP08: https://github.com/dashpay/dips/blob/master/dip-0008.md
- (void)acceptChainLockMessage:(NSData *)message
{
    
    if (![self.chain.chainManager.sporkManager chainLocksEnabled]) {
        DSDLog(@"returned chain lock message when chain locks are not enabled: %@", message);//no error here
        return;
    }
    DSChainLock *chainLock = [DSChainLock chainLockWithMessage:message onChain:self.chain];
    
    if (! chainLock) {
        [self error:@"malformed chain lock message: %@", message];
        return;
    }
    else if (! self.sentFilter && ! self.sentGetdataTxBlocks) {
        [self error:@"got chain lock message before loading a filter"];
        return;
    }
    
    dispatch_async(self.delegateQueue, ^{
        [self.transactionDelegate peer:self relayedChainLock:chainLock];
    });
}

// BIP61: https://github.com/bitcoin/bips/blob/master/bip-0061.mediawiki
- (void)acceptRejectMessage:(NSData *)message
{
    NSNumber * offNumber = nil, *lNumber = nil;
    NSUInteger off = 0, l = 0;
    NSString *type = [message stringAtOffset:0 length:&offNumber];
    off = offNumber.unsignedIntegerValue;
    uint8_t code = [message UInt8AtOffset:off++];
    NSString *reason = [message stringAtOffset:off length:&lNumber];
    l = lNumber.unsignedIntegerValue;
    UInt256 txHash = ([MSG_TX isEqual:type] || [MSG_IX isEqual:type]) ? [message UInt256AtOffset:off + l] : UINT256_ZERO;
    
    DSDLog(@"%@:%u rejected %@ code: 0x%x reason: \"%@\"%@%@", self.host, self.port, type, code, reason,
          (uint256_is_zero(txHash) ? @"" : @" txid: "), (uint256_is_zero(txHash) ? @"" : uint256_obj(txHash)));
    reason = nil; // fixes an unused variable warning for non-debug builds
    
    if (! uint256_is_zero(txHash)) {
        dispatch_async(self.delegateQueue, ^{
            [self.transactionDelegate peer:self rejectedTransaction:txHash withCode:code];
        });
    }
}

// BIP133: https://github.com/bitcoin/bips/blob/master/bip-0133.mediawiki
- (void)acceptFeeFilterMessage:(NSData *)message
{
    if (message.length < sizeof(uint64_t)) {
        [self error:@"malformed freerate message, length is %u, should be 4", (int)message.length];
        return;
    }
    
    _feePerByte = ceilf((float)[message UInt64AtOffset:0]/1000.0f);
    DSDLog(@"%@:%u got feefilter with rate %llu per Byte", self.host, self.port, self.feePerByte);
    
    dispatch_async(self.delegateQueue, ^{
        [self.transactionDelegate peer:self setFeePerByte:self.feePerByte];
    });
}

// MARK: - accept Control

- (void)acceptSporkMessage:(NSData *)message
{
    DSSpork * spork = [DSSpork sporkWithMessage:message onChain:self.chain];
    DSDLog(@"received spork %@ with message %@",spork.identifierString,message.hexString);
    [self.sporkDelegate peer:self relayedSpork:spork];
}

// MARK: - accept Masternode

- (void)acceptSSCMessage:(NSData *)message
{
    
    DSSyncCountInfo syncCountInfo = [message UInt32AtOffset:0];
    uint32_t count = [message UInt32AtOffset:4];
    DSDLog(@"received ssc message %d %d",syncCountInfo,count);
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

-(void)acceptMNBMessage:(NSData *)message
{
    //deprecated since version 70211
}

-(void)acceptMNLISTDIFFMessage:(NSData*)message
{
    [self.masternodeDelegate peer:self relayedMasternodeDiffMessage:message];
}


// MARK: - accept Governance

// https://dash-docs.github.io/en/developer-reference#govobj

- (void)acceptGovObjectMessage:(NSData *)message
{
    DSGovernanceObject * governanceObject = [DSGovernanceObject governanceObjectFromMessage:message onChain:self.chain];
    if (governanceObject) {
        [self.governanceDelegate peer:self relayedGovernanceObject:governanceObject];
    }
}

- (void)acceptGovObjectVoteMessage:(NSData *)message
{
    DSGovernanceVote * governanceVote = [DSGovernanceVote governanceVoteFromMessage:message onChain:self.chain];
    if (governanceVote) {
        [self.governanceDelegate peer:self relayedGovernanceVote:governanceVote];
    }
}

- (void)acceptGovObjectSyncMessage:(NSData *)message
{
    DSDLog(@"Gov Object Sync");
}

// MARK: - Accept Dark send

- (void)acceptDarksendAnnounceMessage:(NSData *)message
{
    
}

- (void)acceptDarksendControlMessage:(NSData *)message
{
    
}

- (void)acceptDarksendFinishMessage:(NSData *)message
{
    
}

- (void)acceptDarksendInitiateMessage:(NSData *)message
{
    
}

- (void)acceptDarksendQuorumMessage:(NSData *)message
{
    
}

- (void)acceptDarksendSessionMessage:(NSData *)message
{
    
}

- (void)acceptDarksendSessionUpdateMessage:(NSData *)message
{
    
}

- (void)acceptDarksendTransactionMessage:(NSData *)message
{
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
    //    DSDLog(@"%@:%u got tx %@", self.host, self.port, uint256_obj(tx.txHash));
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

#define FNV32_PRIME  0x01000193u
#define FNV32_OFFSET 0x811C9dc5u

// FNV32-1a hash of the ip address and port number: http://www.isthe.com/chongo/tech/comp/fnv/index.html#FNV-1a
- (NSUInteger)hash
{
    uint32_t hash = FNV32_OFFSET;
    
    for (int i = 0; i < sizeof(_address); i++) {
        hash = (hash ^ _address.u8[i])*FNV32_PRIME;
    }
    
    hash = (hash ^ ((_port >> 8) & 0xff))*FNV32_PRIME;
    hash = (hash ^ (_port & 0xff))*FNV32_PRIME;
    return hash;
}

// two peer objects are equal if they share an ip address and port number
- (BOOL)isEqual:(id)object
{
    return (self == object || ([object isKindOfClass:[DSPeer class]] && _port == ((DSPeer *)object).port &&
                               uint128_eq(_address, [(DSPeer *)object address]))) ? YES : NO;
}

// MARK: - Info

-(NSString*)chainTip {
    return [NSData dataWithUInt256:self.currentBlock.blockHash].shortHexString;
}

// MARK: - Saving to Disk

-(void)save {
    [self.managedObjectContext performBlock:^{
        NSArray * peerEntities = [DSPeerEntity objectsInContext:self.managedObjectContext matching:@"address == %@ && port == %@", @(CFSwapInt32BigToHost(self.address.u32[3])),@(self.port)];
        if ([peerEntities count]) {
            DSPeerEntity * e = [peerEntities firstObject];
            
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

-(NSError *)connectionTimeoutError {
    static NSError * error;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        error = [NSError errorWithDomain:@"DashSync" code:DASH_PEER_TIMEOUT_CODE
                                userInfo:@{NSLocalizedDescriptionKey:DSLocalizedString(@"Connect timeout", nil)}];
    });
    return error;
}

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
{
    switch (eventCode) {
        case NSStreamEventOpenCompleted:
            DSDLog(@"%@:%u %@ stream connected in %fs", self.host, self.port,
                  (aStream == self.inputStream) ? @"input" : (aStream == self.outputStream ? @"output" : @"unknown"),
                  [NSDate timeIntervalSince1970] - self.pingStartTime);
            
            if (aStream == self.outputStream) {
                self.pingStartTime = [NSDate timeIntervalSince1970]; // don't count connect time in ping time
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
                            DSDLog(@"%@:%u error reading message", self.host, self.port);
                            goto reset;
                        }
                        
                        self.msgHeader.length = headerLen + l;
                        
                        // consume one byte at a time, up to the magic number that starts a new message header
                        while (self.msgHeader.length >= sizeof(uint32_t) &&
                               [self.msgHeader UInt32AtOffset:0] != self.chain.magicNumber) {
#if DEBUG
                            printf("%c", *(const char *)self.msgHeader.bytes);
#endif
                            [self.msgHeader replaceBytesInRange:NSMakeRange(0, 1) withBytes:NULL length:0];
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
                        goto reset;
                    }
                    
                    if (payloadLen < length) { // read message payload
                        self.msgPayload.length = length;
                        l = [self.inputStream read:(uint8_t *)self.msgPayload.mutableBytes + payloadLen
                                         maxLength:self.msgPayload.length - payloadLen];
                        
                        if (l < 0) {
                            DSDLog(@"%@:%u error reading %@", self.host, self.port, type);
                            goto reset;
                        }
                        
                        self.msgPayload.length = payloadLen + l;
                        if (self.msgPayload.length < length) continue; // wait for more stream input
                    }
                    
                    if (CFSwapInt32LittleToHost(self.msgPayload.SHA256_2.u32[0]) != checksum) { // verify checksum
                        [self error:@"error reading %@, invalid checksum %x, expected %x, payload length:%u, expected "
                         "length:%u, SHA256_2:%@", type, self.msgPayload.SHA256_2.u32[0], checksum,
                         (int)self.msgPayload.length, length, uint256_obj(self.msgPayload.SHA256_2)];
                        goto reset;
                    }
                    
                    message = self.msgPayload;
                    self.msgPayload = [NSMutableData data];
                    [self acceptMessage:message type:type]; // process message
                    
                reset:              // reset for next message
                    self.msgHeader.length = self.msgPayload.length = 0;
                }
            }
            
            break;
            
        case NSStreamEventErrorOccurred:
            DSDLog(@"%@:%u error connecting, %@", self.host, self.port, aStream.streamError);
            [self disconnectWithError:aStream.streamError];
            break;
            
        case NSStreamEventEndEncountered:
            DSDLog(@"%@:%u connection closed", self.host, self.port);
            [self disconnectWithError:nil];
            break;
            
        default:
            DSDLog(@"%@:%u unknown network stream eventCode:%u", self.host, self.port, (int)eventCode);
    }
}

@end
