//
//  DSPeerManager.m
//  DashSync
//
//  Created by Aaron Voisine for BreadWallet on 10/6/13.
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

#import "DSAccount.h"
#import "DSBloomFilter.h"
#import "DSChain+Protected.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSChainManager+Protected.h"
#import "DSDerivationPath.h"
#import "DSEventManager.h"
#import "DSGovernanceObject.h"
#import "DSGovernanceSyncManager.h"
#import "DSGovernanceVote.h"
#import "DSMasternodeList.h"
#import "DSMasternodeManager.h"
#import "DSMerkleBlock.h"
#import "DSMerkleBlockEntity+CoreDataClass.h"
#import "DSOptionsManager.h"
#import "DSPeer.h"
#import "DSPeerEntity+CoreDataClass.h"
#import "DSPeerManager+Protected.h"
#import "DSSpork.h"
#import "DSSporkManager.h"
#import "DSTransaction.h"
#import "DSTransactionEntity+CoreDataClass.h"
#import "DSTransactionManager+Protected.h"
#import "DSWallet.h"
#import "NSData+Dash.h"
#import "NSDate+Utils.h"
#import "NSError+Dash.h"
#import "NSManagedObject+Sugar.h"
#import "NSString+Bitcoin.h"
#import "DSSendCoinJoinQueue.h"
#import <arpa/inet.h>
#import <netdb.h>

#define PEER_LOGGING 1

#if !PEER_LOGGING
#define DSLog(...)
#endif

#define TESTNET_DNS_SEEDS @[@"testnet-seed.dashdot.io"]
//#define TESTNET_DNS_SEEDS @[@"35.92.167.154", @"52.12.116.10"]
#define MAINNET_DNS_SEEDS @[@"dnsseed.dash.org"]

#define TESTNET_MAIN_PEER @"" //@"52.36.64.148:19999"

#define FIXED_PEERS @"FixedPeers"
#define TESTNET_FIXED_PEERS @"TestnetFixedPeers"

#define SYNC_COUNT_INFO @"SYNC_COUNT_INFO"

@interface DSPeerManager ()

@property (nonatomic, strong) NSMutableOrderedSet *peers;

@property (nonatomic, strong) NSMutableSet *mutableConnectedPeers, *mutableMisbehavingPeers;
@property (nonatomic, strong) DSPeer *downloadPeer, *fixedPeer;

@property (nonatomic, assign) NSUInteger connectFailures, misbehavingCount, maxConnectCount;
@property (nonatomic, strong) id backgroundObserver, walletAddedObserver;
@property (nonatomic, strong) DSChain *chain;
@property (nonatomic, assign) DSPeerManagerDesiredState desiredState;
@property (nonatomic, assign) uint64_t masternodeListConnectivityNonce;
@property (nonatomic, strong) DSMasternodeList *masternodeList;
@property (nonatomic, readonly) dispatch_queue_t networkingQueue;

#if TARGET_OS_IOS
@property (nonatomic, assign) NSUInteger terminalHeadersSaveTaskId, blockLocatorsSaveTaskId;
#endif

@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;

@end

@implementation DSPeerManager

- (instancetype)initWithChain:(DSChain *)chain {
    NSParameterAssert(chain);

    if (!(self = [super init])) return nil;

    self.chain = chain;
    self.mutableConnectedPeers = [NSMutableSet set];
    self.mutableMisbehavingPeers = [NSMutableSet set];

    self.maxConnectCount = PEER_MAX_CONNECTIONS;

#if TARGET_OS_IOS
    self.terminalHeadersSaveTaskId = UIBackgroundTaskInvalid;

    self.backgroundObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                          object:nil
                                                           queue:nil
                                                      usingBlock:^(NSNotification *note) {
                                                          dispatch_async(self.networkingQueue, ^{
                                                              [self savePeers];
                                                              [self.chain saveTerminalBlocks];
                                                          });
                                                          if (self.terminalHeadersSaveTaskId == UIBackgroundTaskInvalid) {
                                                              self.misbehavingCount = 0;
                                                              dispatch_async(self.networkingQueue, ^{
                                                                  [self.connectedPeers makeObjectsPerformSelector:@selector(disconnect)];
                                                              });
                                                          }
                                                      }];
#endif

    self.walletAddedObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:DSChainWalletsDidChangeNotification
                                                          object:nil
                                                           queue:nil
                                                      usingBlock:^(NSNotification *note){
                                                          //[[self.connectedPeers copy] makeObjectsPerformSelector:@selector(disconnect)];
                                                      }];

    dispatch_sync(self.networkingQueue, ^{
        self.managedObjectContext = [NSManagedObjectContext peerContext];
    });

    return self;
}

- (void)dealloc {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    if (self.backgroundObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.backgroundObserver];
    if (self.walletAddedObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.walletAddedObserver];
}

- (dispatch_queue_t)networkingQueue {
    return self.chain.networkingQueue;
}

- (NSSet *)connectedPeers {
    @synchronized(self.mutableConnectedPeers) {
        return [self.mutableConnectedPeers copy];
    }
}

- (NSSet *)misbehavingPeers {
    @synchronized(self.mutableMisbehavingPeers) {
        return [self.mutableMisbehavingPeers copy];
    }
}

// MARK: - Managers

- (DSMasternodeManager *)masternodeManager {
    return self.chain.chainManager.masternodeManager;
}

- (DSTransactionManager *)transactionManager {
    return self.chain.chainManager.transactionManager;
}

- (DSGovernanceSyncManager *)governanceSyncManager {
    return self.chain.chainManager.governanceSyncManager;
}

- (DSSporkManager *)sporkManager {
    return self.chain.chainManager.sporkManager;
}

- (DSChainManager *)chainManager {
    return self.chain.chainManager;
}

// MARK: - Info

// number of connected peers
- (NSUInteger)connectedPeerCount {
    NSUInteger count = 0;
    @synchronized(self.connectedPeers) {
        for (DSPeer *peer in self.connectedPeers) {
            if (peer.status == DSPeerStatus_Connected) count++;
        }
    }
    return count;
}

- (NSUInteger)peerCount {
    return self.peers.count;
}


- (NSString *)downloadPeerName {
    return [self.downloadPeer.host stringByAppendingFormat:@":%d", self.downloadPeer.port];
}

- (NSArray *)dnsSeeds {
    switch (self.chain.chainType.tag) {
        case ChainType_MainNet:
            return MAINNET_DNS_SEEDS;
        case ChainType_TestNet:
            return TESTNET_DNS_SEEDS;
        case ChainType_DevNet:
            return nil; //no dns seeds for devnets
        default:
            break;
    }
    return nil;
}

// MARK: - Peers
+ (DSPeer *)peerFromString:(NSString *)string forChain:(DSChain *)chain {
    return [[DSPeer alloc] initWithAddress:[[self class] ipAddressFromString:string]
                                      port:chain.standardPort
                                   onChain:chain
                                 timestamp:[NSDate timeIntervalSince1970] - (WEEK_TIME_INTERVAL + arc4random_uniform(WEEK_TIME_INTERVAL))
                                  services:SERVICES_NODE_NETWORK | SERVICES_NODE_BLOOM];
}

+ (UInt128)ipAddressFromString:(NSString *)address {
    UInt128 ipAddress = {.u32 = {0, 0, CFSwapInt32HostToBig(0xffff), 0}};
    struct in_addr addrV4;
    struct in6_addr addrV6;
    if (inet_aton([address UTF8String], &addrV4) != 0) {
        uint32_t ip = ntohl(addrV4.s_addr);
        ipAddress.u32[3] = CFSwapInt32HostToBig(ip);
        DSLog(@"ipAddressFromString: %@: %08x", address, ip);
    } else if (inet_pton(AF_INET6, [address UTF8String], &addrV6)) {
        //todo support IPV6
        DSLog(@"we do not yet support IPV6");
    } else {
        DSLog(@"invalid address");
    }
    return ipAddress;
}

- (void)removeTrustedPeerHost {
    [self disconnect:DSDisconnectReason_TrustedPeerSet];
    [self setTrustedPeerHost:nil];
}

- (void)clearPeers:(DSDisconnectReason)reason {
    [self disconnect:reason];
    @synchronized(self) {
        _peers = nil;
    }
}

- (NSMutableOrderedSet *)peers {
    if (_fixedPeer) return [NSMutableOrderedSet orderedSetWithObject:_fixedPeer];
    if (_peers.count >= _maxConnectCount) return _peers;

    @synchronized(self) {
        if (_peers.count >= _maxConnectCount) return _peers;
        _peers = [NSMutableOrderedSet orderedSet];

        [self.managedObjectContext performBlockAndWait:^{
            for (DSPeerEntity *e in [DSPeerEntity objectsInContext:self.managedObjectContext matching:@"chain == %@", [self.chain chainEntityInContext:self.managedObjectContext]]) {
                @autoreleasepool {
                    if (e.misbehavin == 0)
                        [self->_peers addObject:[e peer]];
                    else
                        [self.mutableMisbehavingPeers addObject:[e peer]];
                }
            }
        }];

        [self sortPeers];

        if ([self.chain isDevnetAny]) {
            [_peers addObjectsFromArray:[self registeredDevnetPeers]];

            if (self.masternodeList) {
                NSArray *masternodePeers = [self.masternodeList peers:8 withConnectivityNonce:self.masternodeListConnectivityNonce];
                [_peers addObjectsFromArray:masternodePeers];
            }

            [self sortPeers];
            return _peers;
        }

        if (self.masternodeList) {
            NSArray *masternodePeers = [self.masternodeList peers:500 withConnectivityNonce:self.masternodeListConnectivityNonce];
            [_peers addObjectsFromArray:masternodePeers];
            [self sortPeers];
            return _peers;
        }

        // DNS peer discovery
        NSTimeInterval now = [NSDate timeIntervalSince1970];
        NSMutableArray *peers = [NSMutableArray arrayWithObject:[NSMutableArray array]];
        NSArray *dnsSeeds = [self dnsSeeds];
        if (_peers.count < PEER_MAX_CONNECTIONS || ((DSPeer *)_peers[PEER_MAX_CONNECTIONS - 1]).timestamp + 3 * DAY_TIME_INTERVAL < now) {
            while (peers.count < dnsSeeds.count) [peers addObject:[NSMutableArray array]];
        }

        if (peers.count > 0) {
            if ([dnsSeeds count]) {
                dispatch_apply(peers.count, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t i) {
                    NSString *servname = @(self.chain.standardPort).stringValue;
                    struct addrinfo hints = {0, AF_UNSPEC, SOCK_STREAM, 0, 0, 0, NULL, NULL}, *servinfo, *p;
                    UInt128 addr = {.u32 = {0, 0, CFSwapInt32HostToBig(0xffff), 0}};

                    DSLog(@"[%@] [DSPeerManager] DNS lookup %@", self.chain.name, [dnsSeeds objectAtIndex:i]);
                    NSString *dnsSeed = [dnsSeeds objectAtIndex:i];
                    if (getaddrinfo([dnsSeed UTF8String], servname.UTF8String, &hints, &servinfo) == 0) {
                        for (p = servinfo; p != NULL; p = p->ai_next) {
                            if (p->ai_family == AF_INET) {
                                addr.u64[0] = 0;
                                addr.u32[2] = CFSwapInt32HostToBig(0xffff);
                                addr.u32[3] = ((struct sockaddr_in *)p->ai_addr)->sin_addr.s_addr;
                            }
                            //                        else if (p->ai_family == AF_INET6) {
                            //                            addr = *(UInt128 *)&((struct sockaddr_in6 *)p->ai_addr)->sin6_addr;
                            //                        }
                            else
                                continue;

                            uint16_t port = CFSwapInt16BigToHost(((struct sockaddr_in *)p->ai_addr)->sin_port);
                            NSTimeInterval age = 3 * DAY_TIME_INTERVAL + arc4random_uniform(4 * DAY_TIME_INTERVAL); // add between 3 and 7 days
                            [peers[i] addObject:[[DSPeer alloc] initWithAddress:addr
                                                                           port:port
                                                                        onChain:self.chain
                                                                      timestamp:(i > 0 ? now - age : now)
                                                                       services:SERVICES_NODE_NETWORK | SERVICES_NODE_BLOOM]];
                        }

                        freeaddrinfo(servinfo);
                    } else {
                        DSLog(@"[%@] [DSPeerManager] failed getaddrinfo for %@", self.chain.name, dnsSeeds[i]);
                    }
                });
            }

            for (NSArray *a in peers) [_peers addObjectsFromArray:a];

            if (![self.chain isMainnet] && ![self.chain isTestnet]) {
                [self sortPeers];
                return _peers;
            }
            // if DNS peer discovery fails, fall back on a hard coded list of peers (list taken from satoshi client)
            if (_peers.count < PEER_MAX_CONNECTIONS) {
                if (![self.chain isMainnet] && ![TESTNET_MAIN_PEER isEqualToString:@""]) {
                    NSArray *serviceArray = [TESTNET_MAIN_PEER componentsSeparatedByString:@":"];
                    NSString *address = serviceArray[0];
                    NSString *port = ([serviceArray count] > 1) ? serviceArray[1] : nil;
                    UInt128 ipAddress = {.u32 = {0, 0, CFSwapInt32HostToBig(0xffff), 0}};
                    struct in_addr addrV4;
                    if (inet_aton([address UTF8String], &addrV4) != 0) {
                        uint32_t ip = ntohl(addrV4.s_addr);
                        ipAddress.u32[3] = CFSwapInt32HostToBig(ip);
                    } else {
                        DSLog(@"[%@] [DSPeerManager] invalid address", self.chain.name);
                    }
                    [_peers addObject:[[DSPeer alloc] initWithAddress:ipAddress
                                                                 port:port ? [port intValue] : self.chain.standardPort
                                                              onChain:self.chain
                                                            timestamp:now - (WEEK_TIME_INTERVAL + arc4random_uniform(WEEK_TIME_INTERVAL))
                                                             services:SERVICES_NODE_NETWORK | SERVICES_NODE_BLOOM]];
                } else {
                    UInt128 addr = {.u32 = {0, 0, CFSwapInt32HostToBig(0xffff), 0}};

                    NSString *bundlePath = [[NSBundle bundleForClass:self.class] pathForResource:@"DashSync" ofType:@"bundle"];
                    NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
                    NSString *path = [bundle pathForResource:[self.chain isMainnet] ? FIXED_PEERS : TESTNET_FIXED_PEERS ofType:@"plist"];
                    for (NSNumber *address in [NSArray arrayWithContentsOfFile:path]) {
                        // give hard coded peers a timestamp between 7 and 14 days ago
                        addr.u32[3] = CFSwapInt32HostToBig(address.unsignedIntValue);
                        [_peers addObject:[[DSPeer alloc] initWithAddress:addr
                                                                     port:self.chain.standardPort
                                                                  onChain:self.chain
                                                                timestamp:now - (WEEK_TIME_INTERVAL + arc4random_uniform(WEEK_TIME_INTERVAL))
                                                                 services:SERVICES_NODE_NETWORK | SERVICES_NODE_BLOOM]];
                    }
                }
            }

            [self sortPeers];
        }

        return _peers;
    }
}


- (void)changeCurrentPeers {
    dispatch_async(self.networkingQueue, ^{
        for (DSPeer *p in self.connectedPeers) {
            p.priority--;
            NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
            p.lowPreferenceTill = [[calendar dateByAddingUnit:NSCalendarUnitDay value:5 toDate:[NSDate date] options:0] timeIntervalSince1970];
        }
    });
}

- (void)peerMisbehaving:(DSPeer *)peer errorMessage:(NSString *)errorMessage {
    @synchronized(self) {
        @synchronized(self.mutableMisbehavingPeers) {
            peer.misbehaving++;
            [self.peers removeObject:peer];
            [self.mutableMisbehavingPeers addObject:peer];
            if (++self.misbehavingCount >= self.chain.peerMisbehavingThreshold) { // clear out stored peers so we get a fresh list from DNS for next connect
                self.misbehavingCount = 0;
                [self.mutableMisbehavingPeers removeAllObjects];
                [self.managedObjectContext performBlockAndWait:^{
                    NSArray *objects = [DSPeerEntity allObjectsInContext:self.managedObjectContext];
                    for (NSManagedObject *obj in objects) {
                        [self.managedObjectContext deleteObject:obj];
                    }
                }];
                _peers = nil;
            }

            [peer disconnectWithError:[NSError errorWithCode:500 localizedDescriptionKey:errorMessage]];
            DSLog(@"[%@] [DSPeerManager] peerMisbehaving -> peerManager::connect", self.chain.name);
            [self connect];
        }
    }
}

- (void)sortPeers {
    NSTimeInterval threeHoursAgo = [[NSDate date] timeIntervalSince1970] - 10800;
    BOOL syncsMasternodeList = !!([[DSOptionsManager sharedInstance] syncType] & DSSyncType_MasternodeList);
    BOOL syncsGovernanceObjects = !!([[DSOptionsManager sharedInstance] syncType] & DSSyncType_Governance);
    @synchronized(self) {
        [_peers sortUsingComparator:^NSComparisonResult(DSPeer *p1, DSPeer *p2) {
            //the following is to make sure we get
            if (syncsMasternodeList) {
                if ((!p1.lastRequestedMasternodeList || p1.lastRequestedMasternodeList < threeHoursAgo) && p2.lastRequestedMasternodeList > threeHoursAgo) return NSOrderedDescending;
                if (p1.lastRequestedMasternodeList > threeHoursAgo && (!p2.lastRequestedMasternodeList || p2.lastRequestedMasternodeList < threeHoursAgo)) return NSOrderedAscending;
            }
            if (syncsGovernanceObjects) {
                if ((!p1.lastRequestedGovernanceSync || p1.lastRequestedGovernanceSync < threeHoursAgo) && p2.lastRequestedGovernanceSync > threeHoursAgo) return NSOrderedDescending;
                if (p1.lastRequestedGovernanceSync > threeHoursAgo && (!p2.lastRequestedGovernanceSync || p2.lastRequestedGovernanceSync < threeHoursAgo)) return NSOrderedAscending;
            }
            if (p1.priority > p2.priority) return NSOrderedAscending;
            if (p1.priority < p2.priority) return NSOrderedDescending;
            if (p1.timestamp > p2.timestamp) return NSOrderedAscending;
            if (p1.timestamp < p2.timestamp) return NSOrderedDescending;
            return NSOrderedSame;
        }];
    }
    //    for (DSPeer * peer in _peers) {
    //        DSLog(@"%@:%d lastRequestedMasternodeList(%f) lastRequestedGovernanceSync(%f)",peer.host,peer.port,peer.lastRequestedMasternodeList, peer.lastRequestedGovernanceSync);
    //    }
    DSLog(@"[%@] [DSPeerManager] peers sorted", self.chain.name);
}

- (void)savePeers {
    DSLog(@"[%@] [DSPeerManager] save peers", self.chain.name);
    NSMutableSet *peers = [[self.peers.set setByAddingObjectsFromSet:self.misbehavingPeers] mutableCopy];
    NSMutableSet *addrs = [NSMutableSet set];

    for (DSPeer *p in peers) {
        if (p.address.u64[0] != 0 || p.address.u32[2] != CFSwapInt32HostToBig(0xffff)) continue; // skip IPv6 for now
        [addrs addObject:@(CFSwapInt32BigToHost(p.address.u32[3]))];
    }

    [self.managedObjectContext performBlock:^{
        [DSPeerEntity deleteObjects:[DSPeerEntity objectsInContext:self.managedObjectContext matching:@"(chain == %@) && !(address in %@)", [self.chain chainEntityInContext:self.managedObjectContext], addrs] inContext:self.managedObjectContext]; // remove deleted peers

        for (DSPeerEntity *e in [DSPeerEntity objectsInContext:self.managedObjectContext matching:@"(chain == %@) && (address in %@)", [self.chain chainEntityInContext:self.managedObjectContext], addrs]) { // update existing peers
            @autoreleasepool {
                DSPeer *p = [peers member:[e peer]];

                if (p) {
                    e.timestamp = p.timestamp;
                    e.services = p.services;
                    e.misbehavin = p.misbehaving;
                    e.priority = p.priority;
                    e.lowPreferenceTill = p.lowPreferenceTill;
                    e.lastRequestedMasternodeList = p.lastRequestedMasternodeList;
                    e.lastRequestedGovernanceSync = p.lastRequestedGovernanceSync;
                    [peers removeObject:p];
                } else
                    [e deleteObjectAndWait];
            }
        }

        for (DSPeer *p in peers) {
            @autoreleasepool {
                [[DSPeerEntity managedObjectInBlockedContext:self.managedObjectContext] setAttributesFromPeer:p]; // add new peers
            }
        }
    }];
}

- (DSPeer *)peerForLocation:(UInt128)IPAddress port:(uint16_t)port {
    for (DSPeer *peer in self.peers) {
        if (uint128_eq(peer.address, IPAddress) && peer.port == port) {
            return peer;
        }
    }
    return nil;
}

- (DSPeerStatus)statusForLocation:(UInt128)IPAddress port:(uint32_t)port {
    DSPeer *peer = [self peerForLocation:IPAddress port:port];
    if (!peer) {
        return DSPeerStatus_Unknown;
    } else if ([self.misbehavingPeers containsObject:peer]) {
        return DSPeerStatus_Banned;
    } else {
        return peer.status;
    }
}

- (DSPeerType)typeForLocation:(UInt128)IPAddress port:(uint32_t)port {
    DSPeer *peer = [self peerForLocation:IPAddress port:port];
    if (!peer) {
        return DSPeerType_Unknown;
    }
    if ([self.masternodeManager hasMasternodeAtLocation:IPAddress port:port]) {
        return DSPeerType_MasterNode;
    } else {
        return DSPeerType_FullNode;
    }
}

- (NSString *)settingsFixedPeerKey {
    return [NSString stringWithFormat:@"%@_%@", SETTINGS_FIXED_PEER_KEY, self.chain.uniqueID];
}

- (NSString *)trustedPeerHost {
    if ([[NSUserDefaults standardUserDefaults] objectForKey:[self settingsFixedPeerKey]]) {
        return [[NSUserDefaults standardUserDefaults] stringForKey:[self settingsFixedPeerKey]];
    } else {
        return nil;
    }
}

- (void)setTrustedPeerHost:(NSString *_Nullable)host {
    if (!host)
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:[self settingsFixedPeerKey]];
    else
        [[NSUserDefaults standardUserDefaults] setObject:host forKey:[self settingsFixedPeerKey]];
}

// MARK: - Peer Registration

- (void)pauseBlockchainSynchronizationOnPeers {
    self.downloadPeer.needsFilterUpdate = YES;
}

- (void)resumeBlockchainSynchronizationOnPeers {
    self.downloadPeer.needsFilterUpdate = NO;
    if (self.downloadPeer) {
        [self updateFilterOnPeers];
    } else {
        DSLog(@"[%@] [DSPeerManager] resumeBlockchainSynchronizationOnPeers", self.chain.name);
        [self connect];
    }
}

- (void)updateFilterOnPeers {
    if (self.downloadPeer.needsFilterUpdate) return;
    self.downloadPeer.needsFilterUpdate = YES;
    DSLog(@"[%@] [DSPeerManager] filter update needed, waiting for pong", self.chain.name);

    [self.downloadPeer sendPingMessageWithPongHandler:^(BOOL success) { // wait for pong so we include already sent tx
        if (!success) return;
        //we are on chainPeerManagerQueue
        DSLog(@"[%@] [DSPeerManager] updating filter with newly created wallet addresses", self.chain.name);
        [self.transactionManager clearTransactionsBloomFilter];

        if (self.chain.lastSyncBlockHeight < self.chain.estimatedBlockHeight) { // if we're syncing, only update download peer
            [self.downloadPeer sendFilterloadMessage:[self.transactionManager transactionsBloomFilterForPeer:self.downloadPeer].data];
            [self.downloadPeer sendPingMessageWithPongHandler:^(BOOL success) { // wait for pong so filter is loaded
                if (!success) return;
                self.downloadPeer.needsFilterUpdate = NO;
                [self.downloadPeer rerequestBlocksFrom:self.chain.lastSyncBlock.blockHash];
                [self.downloadPeer sendPingMessageWithPongHandler:^(BOOL success) {
                    if (!success || self.downloadPeer.needsFilterUpdate) return;
                    [self.downloadPeer sendGetblocksMessageWithLocators:[self.chain chainSyncBlockLocatorArray]
                                                            andHashStop:UINT256_ZERO];
                }];
            }];
        } else {
            for (DSPeer *p in self.connectedPeers) {
                if (p.status != DSPeerStatus_Connected) continue;
                [p sendFilterloadMessage:[self.transactionManager transactionsBloomFilterForPeer:p].data];
                [p sendPingMessageWithPongHandler:^(BOOL success) { // wait for pong so we know filter is loaded
                    if (!success) return;
                    p.needsFilterUpdate = NO;
                    [p sendMempoolMessage:self.transactionManager.publishedTx.allKeys completion:nil];
                }];
            }
        }
    }];
}

// MARK: - Peer Registration

- (void)clearRegisteredPeers {
    [self clearPeers:DSDisconnectReason_ChainWipe];
    setKeychainArray(@[], self.chain.registeredPeersKey, NO);
}

- (void)registerPeerAtLocation:(UInt128)IPAddress port:(uint32_t)port dapiJRPCPort:(uint32_t)dapiJRPCPort dapiGRPCPort:(uint32_t)dapiGRPCPort {
    NSError *error = nil;
    NSMutableArray *registeredPeersArray = [getKeychainArray(self.chain.registeredPeersKey, @[[NSString class], [NSNumber class], [NSDictionary class], [NSData class]], &error) mutableCopy];
    if (!registeredPeersArray) registeredPeersArray = [NSMutableArray array];
    NSDictionary *insertDictionary = @{@"address": [NSData dataWithUInt128:IPAddress], @"port": @(port), @"dapiJRPCPort": @(dapiJRPCPort), @"dapiGRPCPort": @(dapiGRPCPort)};
    BOOL found = FALSE;
    for (NSDictionary *dictionary in registeredPeersArray) {
        if ([dictionary isEqualToDictionary:insertDictionary]) {
            found = TRUE;
            break;
        }
    }
    if (!found) {
        [registeredPeersArray addObject:insertDictionary];
    }
    setKeychainArray(registeredPeersArray, self.chain.registeredPeersKey, NO);
}


- (NSArray *)registeredDevnetPeers {
    NSError *error = nil;
    NSMutableArray *registeredPeersArray = [getKeychainArray(self.chain.registeredPeersKey, @[[NSString class], [NSNumber class], [NSDictionary class], [NSData class]], &error) mutableCopy];
    if (error) return @[];
    NSMutableArray *registeredPeers = [NSMutableArray array];
    for (NSDictionary *peerDictionary in registeredPeersArray) {
        UInt128 ipAddress = *(UInt128 *)((NSData *)peerDictionary[@"address"]).bytes;
        uint16_t port = [peerDictionary[@"port"] unsignedShortValue];
        NSTimeInterval now = [NSDate timeIntervalSince1970];
        [registeredPeers addObject:[[DSPeer alloc] initWithAddress:ipAddress port:port onChain:self.chain timestamp:now - (7 * 24 * 60 * 60 + arc4random_uniform(7 * 24 * 60 * 60)) services:SERVICES_NODE_NETWORK | SERVICES_NODE_BLOOM]];
    }
    return [registeredPeers copy];
}

- (NSArray *)registeredDevnetPeerServices {
    NSArray *registeredDevnetPeers = [self registeredDevnetPeers];
    NSMutableArray *registeredDevnetPeerServicesArray = [NSMutableArray array];
    for (DSPeer *peer in registeredDevnetPeers) {
        if (!uint128_is_zero(peer.address)) {
            [registeredDevnetPeerServicesArray addObject:[NSString stringWithFormat:@"%@:%hu", peer.host, peer.port]];
        }
    }
    return [registeredDevnetPeerServicesArray copy];
}

// MARK: - Using Masternode List for connectivitity

- (void)useMasternodeList:(DSMasternodeList *)masternodeList withConnectivityNonce:(uint64_t)connectivityNonce {
    self.masternodeList = masternodeList;
    self.masternodeListConnectivityNonce = connectivityNonce;

    BOOL connected = self.connected;


    NSArray *peers = [masternodeList peers:500 withConnectivityNonce:connectivityNonce];

    @synchronized(self) {
        if (!_peers) {
            _peers = [NSMutableOrderedSet orderedSetWithArray:peers];
        } else {
            [self clearPeers:DSDisconnectReason_StartNewPhase];
            _peers = [NSMutableOrderedSet orderedSetWithArray:peers];
            [self.peers minusSet:self.misbehavingPeers];
        }
        [self sortPeers];
    }

    if (peers.count > 1 && peers.count < 1000) [self savePeers]; // peer relaying is complete when we receive <1000

    if (connected) {
        DSLog(@"[%@] [DSPeerManager] useMasternodeList -> connect", self.chain.name);
        [self connect];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DSPeerManagerPeersDidChangeNotification
                                                            object:nil
                                                          userInfo:@{DSChainManagerNotificationChainKey: self.chain}];
    });
}

// MARK: - Connectivity

- (void)connect {
    DSLog(@"[%@] [DSPeerManager] connect", self.chain.name);
    self.desiredState = DSPeerManagerDesiredState_Connected;
    dispatch_async(self.networkingQueue, ^{
        if ([self.chain syncsBlockchain] && ![self.chain canConstructAFilter]) {
            DSLog(@"[%@] [DSPeerManager] failed to connect: check that wallet is created", self.chain.name);
            return; // check to make sure the wallet has been created if only are a basic wallet with no dash features
        }
        if (self.connectFailures >= MAX_CONNECT_FAILURES) self.connectFailures = 0;    // this attempt is a manual retry
        @synchronized (self.chainManager) {
            if (self.chainManager.terminalHeaderSyncProgress < 1.0) {
                [self.chainManager resetTerminalSyncStartHeight];
    #if TARGET_OS_IOS
                if (self.blockLocatorsSaveTaskId == UIBackgroundTaskInvalid) { // start a background task for the chain sync
                    self.blockLocatorsSaveTaskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
                        dispatch_async(self.networkingQueue, ^{
                            [self.chain saveBlockLocators];
                        });

                        [self chainSyncStopped];
                    }];
                }
    #endif
            }

            if (self.chainManager.chainSyncProgress < 1.0) {
                [self.chainManager resetChainSyncStartHeight];
    #if TARGET_OS_IOS
                if (self.terminalHeadersSaveTaskId == UIBackgroundTaskInvalid) { // start a background task for the chain sync
                    self.terminalHeadersSaveTaskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
                        dispatch_async(self.networkingQueue, ^{
                            [self.chain saveTerminalBlocks];
                        });

                        [self chainSyncStopped];
                    }];
                }
    #endif
            }
        }
//        @synchronized(self.mutableConnectedPeers) {
//            [self.mutableConnectedPeers minusSet:[self.connectedPeers objectsPassingTest:^BOOL(id obj, BOOL *stop) {
//                return ([obj status] == DSPeerStatus_Disconnected) ? YES : NO;
//            }]];
//        }
        @synchronized(self.mutableConnectedPeers) {
            NSMutableSet *disconnectedPeers = [NSMutableSet set];
            for (DSPeer *peer in self.mutableConnectedPeers) {
//                @synchronized(peer) {
                    if (peer.status == DSPeerStatus_Disconnected) {
                        [disconnectedPeers addObject:peer];
                    }
//                }
            }
            [self.mutableConnectedPeers minusSet:disconnectedPeers];
        }


        self.fixedPeer = [self trustedPeerHost] ? [DSPeer peerWithHost:[self trustedPeerHost] onChain:self.chain] : nil;
        self.maxConnectCount = (self.fixedPeer) ? 1 : PEER_MAX_CONNECTIONS;
        if (self.connectedPeers.count >= self.maxConnectCount) return; // already connected to maxConnectCount peers

        NSMutableOrderedSet *peers = [NSMutableOrderedSet orderedSetWithOrderedSet:self.peers];

        if (peers.count > 100) [peers removeObjectsInRange:NSMakeRange(100, peers.count - 100)];

        if (peers.count > 0 && self.connectedPeers.count < self.maxConnectCount) {
            @synchronized(self.mutableConnectedPeers) {
                NSTimeInterval earliestWalletCreationTime = self.chain.earliestWalletCreationTime;

                while (peers.count > 0 && self.connectedPeers.count < self.maxConnectCount) {
                    // pick a random peer biased towards peers with more recent timestamps
                    DSPeer *peer = peers[(NSUInteger)(pow(arc4random_uniform((uint32_t)peers.count), 2) / peers.count)];

                    if (peer && ![self.connectedPeers containsObject:peer]) {
                        [peer setChainDelegate:self.chain.chainManager peerDelegate:self transactionDelegate:self.transactionManager governanceDelegate:self.governanceSyncManager sporkDelegate:self.sporkManager masternodeDelegate:self.masternodeManager queue:self.networkingQueue];
                        peer.earliestKeyTime = earliestWalletCreationTime;

                        [self.mutableConnectedPeers addObject:peer];

                        DSLog(@"[%@: %@:%d] [DSPeerManager] Will attempt to connect to peer", self.chain.name, peer.host, peer.port);

                        [peer connect];
                    }

                    [peers removeObject:peer];
                }
            }
        }

        if (peers.count == 0) {
            [self chainSyncStopped];
            dispatch_async(dispatch_get_main_queue(), ^{
                NSError *error = [NSError errorWithCode:1 localizedDescriptionKey:@"No peers found"];
                [[NSNotificationCenter defaultCenter] postNotificationName:DSChainManagerSyncFailedNotification
                                                                    object:nil
                                                                  userInfo:@{@"error": error, DSChainManagerNotificationChainKey: self.chain}];
            });
        }
    });
}

- (void)disconnect:(DSDisconnectReason)reason {
    self.desiredState = DSPeerManagerDesiredState_Disconnected;
    dispatch_async(self.networkingQueue, ^{
        if (reason != DSDisconnectReason_StartNewPhase)
            self.connectFailures = MAX_CONNECT_FAILURES; // prevent futher automatic reconnect attempts
        for (DSPeer *peer in self.connectedPeers) {
            [peer disconnect];
        }
    });
}

- (void)disconnectDownloadPeerForError:(NSError *)error withCompletion:(void (^_Nullable)(BOOL success))completion {
    [self.downloadPeer disconnectWithError:error];
    dispatch_async(self.networkingQueue, ^{
        if (self.downloadPeer) { // disconnect the current download peer so a new random one will be selected
            [self.peers removeObject:self.downloadPeer];
        }
        if (completion) completion(TRUE);
    });
}

- (void)syncTimeout {
    @synchronized (self.chainManager) {
        NSTimeInterval now = [NSDate timeIntervalSince1970];
        NSTimeInterval delta = now - self.chainManager.lastChainRelayTime;
        if (delta < PROTOCOL_TIMEOUT) { // the download peer relayed something in time, so restart timer
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(syncTimeout) object:nil];
            [self performSelector:@selector(syncTimeout)
                       withObject:nil
                       afterDelay:PROTOCOL_TIMEOUT - delta];
            return;
        }
    }

    [self disconnectDownloadPeerForError:[NSError errorWithCode:500 descriptionKey:DSLocalizedString(@"Synchronization Timeout", @"An error message for notifying that chain sync has timed out")] withCompletion:nil];
}

- (void)chainSyncStopped {
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(syncTimeout) object:nil];
#if TARGET_OS_IOS
        if (self.terminalHeadersSaveTaskId != UIBackgroundTaskInvalid) {
            [[UIApplication sharedApplication] endBackgroundTask:self.terminalHeadersSaveTaskId];
            self.terminalHeadersSaveTaskId = UIBackgroundTaskInvalid;
        }

        if (self.blockLocatorsSaveTaskId != UIBackgroundTaskInvalid) {
            [[UIApplication sharedApplication] endBackgroundTask:self.blockLocatorsSaveTaskId];
            self.blockLocatorsSaveTaskId = UIBackgroundTaskInvalid;
        }
#endif
    });
}

// MARK: - DSPeerDelegate

- (void)peerConnected:(DSPeer *)peer {
    NSTimeInterval now = [NSDate timeIntervalSince1970];

    if (peer.timestamp > now + 2 * 60 * 60 || peer.timestamp < now - 2 * 60 * 60) peer.timestamp = now; //timestamp sanity check
    self.connectFailures = 0;
    DSLog(@"[%@: %@:%d] [DSPeerManager] connected with lastblock %d (our last header %d - last block %d)", self.chain.name, peer.host, peer.port, peer.lastBlockHeight, self.chain.lastTerminalBlockHeight, self.chain.lastSyncBlockHeight);

    // drop peers that don't carry full blocks, or aren't synced yet
    // TODO: XXXX does this work with 0.11 pruned nodes?
    if (!(peer.services & SERVICES_NODE_NETWORK) || peer.lastBlockHeight + 10 < self.chain.lastSyncBlockHeight) {
        [peer disconnectWithError:[NSError errorWithCode:500 descriptionKey:[NSString stringWithFormat:DSLocalizedString(@"Node at host %@ does not service network", nil), peer.host]]];
        return;
    }

    // drop peers that don't support SPV filtering
    if (peer.version >= 70206 && !(peer.services & SERVICES_NODE_BLOOM)) {
        [peer disconnectWithError:[NSError errorWithCode:500 descriptionKey:[NSString stringWithFormat:DSLocalizedString(@"Node at host %@ does not support bloom filtering", nil), peer.host]]];
        return;
    }

    if (self.connected) {
        if (![self.chain syncsBlockchain]) return;
        if ([self.chain canConstructAFilter]) {
            [peer sendFilterloadMessage:[self.transactionManager transactionsBloomFilterForPeer:peer].data];
            [peer sendInvMessageForHashes:self.transactionManager.publishedCallback.allKeys ofType:DSInvType_Tx]; // publish pending tx
        } else {
            [peer sendFilterloadMessage:[DSBloomFilter emptyBloomFilterData]];
        }
        if (self.chain.estimatedBlockHeight >= peer.lastBlockHeight || self.chain.lastSyncBlockHeight >= peer.lastBlockHeight) {
            if (self.chain.lastSyncBlockHeight < self.chain.estimatedBlockHeight) {
                DSLog(@"[%@: %@:%d] [DSPeerManager] lastSyncBlockHeight %u, estimatedBlockHeight %u", self.chain.name, peer.host, peer.port, self.chain.lastSyncBlockHeight, self.chain.estimatedBlockHeight);
                return; // don't get mempool yet if we're syncing
            }

            [peer sendPingMessageWithPongHandler:^(BOOL success) {
                if (!success) {
                    DSLog(@"[%@: %@:%d] [DSPeerManager] fetching mempool ping on connection failure peer", self.chain.name, peer.host, peer.port);
                    return;
                }
                DSLog(@"[%@: %@:%d] [DSPeerManager] fetching mempool ping on connection success peer", self.chain.name, peer.host, peer.port);
                [peer sendMempoolMessage:self.transactionManager.publishedTx.allKeys
                              completion:^(BOOL success, BOOL needed, BOOL interruptedByDisconnect) {
                    if (!success) {
                        if (!needed) {
                            DSLog(@"[%@: %@:%d] [DSPeerManager] fetching mempool message on connection not needed (already happening) peer", self.chain.name, peer.host, peer.port);
                        } else if (interruptedByDisconnect) {
                            DSLog(@"[%@: %@:%d] [DSPeerManager] fetching mempool message on connection failure peer", self.chain.name, peer.host, peer.port);
                        } else {
                            DSLog(@"[%@: %@:%d] [DSPeerManager] fetching mempool message on connection failure disconnect peer", self.chain.name, peer.host, peer.port);
                        }
                        return;
                    }
                    DSLog(@"[%@: %@:%d] [DSPeerManager] fetching mempool message on connection success peer", self.chain.name, peer.host, peer.port);
                    peer.synced = YES;
                    [self.transactionManager removeUnrelayedTransactionsFromPeer:peer];
                    if (!self.masternodeList) {
                        [peer sendGetaddrMessage]; // request a list of other dash peers
                    }
                    
                    if (self.shouldSendDsq) {
                        [peer sendRequest:[DSSendCoinJoinQueue requestWithShouldSend:true]];
                    }
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[NSNotificationCenter defaultCenter] postNotificationName:DSTransactionManagerTransactionStatusDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey: self.chain}];
                    });
                }];
            }];
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:DSPeerManagerConnectedPeersDidChangeNotification
                                                                    object:nil
                                                                  userInfo:@{DSChainManagerNotificationChainKey: self.chain}];
            });
            return; // we're already connected to a download peer
        }
    }

    // select the peer with the lowest ping time to download the chain from if we're behind
    // BUG: XXX a malicious peer can report a higher lastblock to make us select them as the download peer, if two
    // peers agree on lastblock, use one of them instead
    NSMutableArray *reallyConnectedPeers = [NSMutableArray array];
    for (DSPeer *p in self.connectedPeers) {
        if (p.status != DSPeerStatus_Connected) continue;
        [reallyConnectedPeers addObject:p];
    }

    if (!self.chain.isDevnetAny && reallyConnectedPeers.count < self.maxConnectCount) {
        //we didn't connect to all connected peers yet
        return;
    }

    DSPeer *bestPeer = peer;

    for (DSPeer *p in reallyConnectedPeers) {
        if ((p.pingTime < bestPeer.pingTime && p.lastBlockHeight >= bestPeer.lastBlockHeight) || p.lastBlockHeight > bestPeer.lastBlockHeight) bestPeer = p;
        [self.chain setEstimatedBlockHeight:p.lastBlockHeight fromPeer:p thresholdPeerCount:(uint32_t)reallyConnectedPeers.count * 2 / 3];
    }

    [self.downloadPeer disconnect];
    self.downloadPeer = bestPeer;
    @synchronized (self) {
        _connected = YES;
    }
    if ([self.chain syncsBlockchain] && [self.chain canConstructAFilter]) {
        [bestPeer sendFilterloadMessage:[self.transactionManager transactionsBloomFilterForPeer:bestPeer].data];
    }
    bestPeer.currentBlockHeight = self.chain.lastSyncBlockHeight;

    dispatch_async(dispatch_get_main_queue(), ^{ // setup a timer to detect if the sync stalls
        [self.chainManager assignSyncWeights];
        if ([self.chain syncsBlockchain] &&
            ((self.chain.lastSyncBlockHeight != self.chain.lastTerminalBlockHeight) ||
             (self.chain.lastSyncBlockHeight < bestPeer.lastBlockHeight))) { // start blockchain sync
            [self.chainManager resetLastRelayedItemTime];
                [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(syncTimeout) object:nil];
                [self performSelector:@selector(syncTimeout) withObject:nil afterDelay:PROTOCOL_TIMEOUT];

                [[NSNotificationCenter defaultCenter] postNotificationName:DSTransactionManagerTransactionStatusDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey: self.chain}];

                [self.chainManager chainWillStartSyncingBlockchain:self.chain];
                [self.chainManager chainShouldStartSyncingBlockchain:self.chain onPeer:bestPeer];
        } else { // we're already synced
            [self.chainManager chainFinishedSyncingTransactionsAndBlocks:self.chain fromPeer:nil onMainChain:TRUE];
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:DSPeerManagerConnectedPeersDidChangeNotification
                                                            object:nil
                                                          userInfo:@{DSChainManagerNotificationChainKey: self.chain}];
        [[NSNotificationCenter defaultCenter] postNotificationName:DSPeerManagerDownloadPeerDidChangeNotification
                                                            object:nil
                                                          userInfo:@{DSChainManagerNotificationChainKey: self.chain}];
    });
}

- (void)peer:(DSPeer *)peer disconnectedWithError:(NSError *)error {
    DSLog(@"[%@: %@:%d] [DSPeerManager] disconnected %@%@", self.chain.name, peer.host, peer.port, (error ? @", " : @""), (error ? error : @""));
    BOOL banned = NO;
    if ([error.domain isEqual:@"DashSync"]) {                                //} && error.code != DASH_PEER_TIMEOUT_CODE) {
        [self peerMisbehaving:peer errorMessage:error.localizedDescription]; // if it's protocol error other than timeout, the peer isn't following the rules
        banned = YES;
    } else if (error) {                                                      // timeout or some non-protocol related network error
        [self.peers removeObject:peer];
        self.connectFailures++;
    }

    [self.transactionManager clearTransactionRelaysForPeer:peer];

    if ([self.downloadPeer isEqual:peer]) { // download peer disconnected
        _connected = NO;
        [self.chain removeEstimatedBlockHeightOfPeer:peer];
        self.downloadPeer = nil;
        if (self.connectFailures > MAX_CONNECT_FAILURES) self.connectFailures = MAX_CONNECT_FAILURES;
    }

    if (!self.connected && self.connectFailures >= MAX_CONNECT_FAILURES) {
        [self chainSyncStopped];

        // clear out stored peers so we get a fresh list from DNS on next connect attempt
        @synchronized(self.mutableMisbehavingPeers) {
            [self.mutableMisbehavingPeers removeAllObjects];
        }
        [self.managedObjectContext performBlockAndWait:^{
            NSArray *objects = [DSPeerEntity allObjectsInContext:self.managedObjectContext];
            for (NSManagedObject *obj in objects) {
                [self.managedObjectContext deleteObject:obj];
            }
        }];
        @synchronized(self) {
            _peers = nil;
        }
        if (_desiredState != DSPeerManagerDesiredState_Disconnected)
            DSLog(@"[%@: %@:%d] [DSPeerManager] disconnectedWithError: max connect failures exceeded", self.chain.name, peer.host, peer.port);
            dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:DSChainManagerSyncFailedNotification
                                                                        object:nil
                                                                      userInfo:(error) ? @{@"error": error, DSChainManagerNotificationChainKey: self.chain} : @{DSChainManagerNotificationChainKey: self.chain}];
                });
    } else if (self.connectFailures < MAX_CONNECT_FAILURES) {
        dispatch_async(dispatch_get_main_queue(), ^{
#if TARGET_OS_IOS
            if ((self.desiredState == DSPeerManagerDesiredState_Connected) && (self.terminalHeadersSaveTaskId != UIBackgroundTaskInvalid ||
                                                                                  [UIApplication sharedApplication].applicationState != UIApplicationStateBackground)) {
                DSLog(@"[%@: %@:%d] [DSPeerManager] peer disconnectedWithError -> peerManager::connect", self.chain.name, peer.host, peer.port);
                if (!banned) [self connect]; // try connecting to another peer
            }
#else
                if (self.desiredState == DSPeerManagerDesiredState_Connected) {
                    [self connect]; // try connecting to another peer
                }
#endif
        });
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DSPeerManagerConnectedPeersDidChangeNotification
                                                            object:nil
                                                          userInfo:@{DSChainManagerNotificationChainKey: self.chain}];
        [[NSNotificationCenter defaultCenter] postNotificationName:DSPeerManagerDownloadPeerDidChangeNotification
                                                            object:nil
                                                          userInfo:@{DSChainManagerNotificationChainKey: self.chain}];
    });
}

- (void)peer:(DSPeer *)peer relayedPeers:(NSArray *)peers {
    if (self.masternodeList) return;
    DSLog(@"[%@: %@:%d] [DSPeerManager] relayed %d peer(s)", self.chain.name, peer.host, peer.port, (int)peers.count);
    [self.peers addObjectsFromArray:peers];
    [self.peers minusSet:self.misbehavingPeers];
    [self sortPeers];

    // limit total to 2500 peers
    if (self.peers.count > 2500) [self.peers removeObjectsInRange:NSMakeRange(2500, self.peers.count - 2500)];

    NSTimeInterval now = [NSDate timeIntervalSince1970];

    // remove peers more than 3 hours old, or until there are only 1000 left
    while (self.peers.count > 1000 && ((DSPeer *)self.peers.lastObject).timestamp + 3 * 60 * 60 < now) {
        [self.peers removeObject:self.peers.lastObject];
    }

    if (peers.count > 1 && peers.count < 1000) [self savePeers]; // peer relaying is complete when we receive <1000
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DSPeerManagerPeersDidChangeNotification
                                                            object:nil
                                                          userInfo:@{DSChainManagerNotificationChainKey: self.chain}];
    });
}

- (void)sendRequest:(DSMessageRequest *)request {
    [self.downloadPeer sendRequest:request];
}

// MARK: CoinJoin

- (DSPeer *)connectedPeer { // TODO(coinjoin): temp
    return self.connectedPeers.objectEnumerator.nextObject;
}

- (void)shouldSendDsq:(BOOL)shouldSendDsq {
    for (DSPeer *peer in self.connectedPeers) {
        DSSendCoinJoinQueue *request = [DSSendCoinJoinQueue requestWithShouldSend:shouldSendDsq];
        [peer sendRequest:request];
    }
    _shouldSendDsq = shouldSendDsq;
}

@end
