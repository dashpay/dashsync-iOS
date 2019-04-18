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

#import "DSPeerManager+Protected.h"
#import "DSPeer.h"
#import "DSPeerEntity+CoreDataClass.h"
#import "DSTransaction.h"
#import "DSTransactionEntity+CoreDataClass.h"
#import "DSMerkleBlock.h"
#import "DSMerkleBlockEntity+CoreDataClass.h"
#import "NSString+Bitcoin.h"
#import "NSData+Bitcoin.h"
#import "NSManagedObject+Sugar.h"
#import "DSEventManager.h"
#import "DSChain.h"
#import "DSSpork.h"
#import "DSSporkManager.h"
#import "DSChainEntity+CoreDataClass.h"
#import <netdb.h>
#import "DSDerivationPath.h"
#import "DSAccount.h"
#import "DSOptionsManager.h"
#import "DSMasternodeManager.h"
#import "DSGovernanceSyncManager.h"
#import "DSGovernanceObject.h"
#import "DSGovernanceVote.h"
#import "DSWallet.h"
#import "NSDate+Utils.h"
#import "DSTransactionManager+Protected.h"
#import "DSChainManager+Protected.h"
#import "DSBloomFilter.h"
#import <arpa/inet.h>

#define PEER_LOGGING 1

#if ! PEER_LOGGING
#define DSDLog(...)
#endif

#define TESTNET_DNS_SEEDS @[@"testnet-seed.dashdot.io"]

#define MAINNET_DNS_SEEDS @[@"dnsseed.dash.org",@"dnsseed.dashdot.io"]

#define TESTNET_MAIN_PEER @""//@"52.36.64.148:19999"


#define FIXED_PEERS          @"FixedPeers"
#define TESTNET_FIXED_PEERS  @"TestnetFixedPeers"

#define SYNC_COUNT_INFO @"SYNC_COUNT_INFO"

@interface DSPeerManager ()

@property (nonatomic, strong) NSMutableOrderedSet *peers;

@property (nonatomic, strong) NSMutableSet *mutableConnectedPeers, *mutableMisbehavingPeers;
@property (nonatomic, strong) DSPeer *downloadPeer, *fixedPeer;
@property (nonatomic, assign) NSUInteger taskId, connectFailures, misbehavingCount, maxConnectCount;
@property (nonatomic, strong) dispatch_queue_t chainPeerManagerQueue;
@property (nonatomic, strong) id backgroundObserver, walletAddedObserver;
@property (nonatomic, strong) DSChain * chain;
@property (nonatomic, assign) DSPeerManagerDesiredState desiredState;

@end

@implementation DSPeerManager

- (instancetype)initWithChain:(DSChain*)chain
{
    NSParameterAssert(chain);
    
    if (! (self = [super init])) return nil;
    
    self.chain = chain;
    self.mutableConnectedPeers = [NSMutableSet set];
    self.mutableMisbehavingPeers = [NSMutableSet set];
    self.taskId = UIBackgroundTaskInvalid;
    
    //there should be one queue per chain
    self.chainPeerManagerQueue = dispatch_queue_create([[NSString stringWithFormat:@"org.dashcore.dashsync.peermanager.%@",self.chain.uniqueID] UTF8String], DISPATCH_QUEUE_SERIAL);
    self.maxConnectCount = PEER_MAX_CONNECTIONS;
    
    self.backgroundObserver =
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil
                                                       queue:nil usingBlock:^(NSNotification *note) {
                                                           [self savePeers];
                                                           [self.chain saveBlocks];
                                                           
                                                           if (self.taskId == UIBackgroundTaskInvalid) {
                                                               self.misbehavingCount = 0;
                                                               dispatch_async(self.chainPeerManagerQueue, ^{
                                                                   [self.connectedPeers makeObjectsPerformSelector:@selector(disconnect)];
                                                               });
                                                           }
                                                       }];
    
    self.walletAddedObserver =
    [[NSNotificationCenter defaultCenter] addObserverForName:DSChainWalletsDidChangeNotification object:nil
                                                       queue:nil usingBlock:^(NSNotification *note) {
                                                           //[[self.connectedPeers copy] makeObjectsPerformSelector:@selector(disconnect)];
                                                       }];
    
    return self;
}

- (void)dealloc
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    if (self.backgroundObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.backgroundObserver];
    if (self.walletAddedObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.walletAddedObserver];
}

- (NSSet *)connectedPeers {
    return [self.mutableConnectedPeers copy];
}

- (NSSet *)misbehavingPeers {
    return [self.mutableMisbehavingPeers copy];
}

// MARK: - Managers

-(DSMasternodeManager*)masternodeManager {
    return self.chain.chainManager.masternodeManager;
}

-(DSTransactionManager*)transactionManager {
    return self.chain.chainManager.transactionManager;
}

-(DSGovernanceSyncManager*)governanceSyncManager {
    return self.chain.chainManager.governanceSyncManager;
}

-(DSSporkManager*)sporkManager {
    return self.chain.chainManager.sporkManager;
}

-(DSChainManager*)chainManager {
    return self.chain.chainManager;
}

// MARK: - Info

// number of connected peers
- (NSUInteger)connectedPeerCount
{
    NSUInteger count = 0;
    @synchronized (self.connectedPeers) {
        for (DSPeer *peer in self.connectedPeers) {
            if (peer.status == DSPeerStatus_Connected) count++;
        }
    }
    return count;
}

- (NSUInteger)peerCount
{
    return self.peers.count;
}


- (NSString *)downloadPeerName
{
    return [self.downloadPeer.host stringByAppendingFormat:@":%d", self.downloadPeer.port];
}

-(NSArray*)dnsSeeds {
    switch (self.chain.chainType) {
        case DSChainType_MainNet:
            return MAINNET_DNS_SEEDS;
            break;
        case DSChainType_TestNet:
            return TESTNET_DNS_SEEDS;
            break;
        case DSChainType_DevNet:
            return nil; //no dns seeds for devnets
            break;
        default:
            break;
    }
    return nil;
}

// MARK: - Peers

-(void)removeTrustedPeerHost {
    [self disconnect];
    [self setTrustedPeerHost:nil];
}

-(void)clearPeers {
    [self disconnect];
    _peers = nil;
}

- (NSMutableOrderedSet *)peers
{
    if (_fixedPeer) return [NSMutableOrderedSet orderedSetWithObject:_fixedPeer];
    if (_peers.count >= _maxConnectCount) return _peers;
    
    @synchronized(self) {
        if (_peers.count >= _maxConnectCount) return _peers;
        _peers = [NSMutableOrderedSet orderedSet];
        
        [[DSPeerEntity context] performBlockAndWait:^{
            for (DSPeerEntity *e in [DSPeerEntity objectsMatching:@"chain == %@",self.chain.chainEntity]) {
                @autoreleasepool {
                    if (e.misbehavin == 0) [self->_peers addObject:[e peer]];
                    else [self.mutableMisbehavingPeers addObject:[e peer]];
                }
            }
        }];
        
        [self sortPeers];
        
        if ([self.chain isDevnetAny]) {
            
            [_peers addObjectsFromArray:[self registeredDevnetPeers]];
            
            [self sortPeers];
            return _peers;
        }
        
        // DNS peer discovery
        NSTimeInterval now = [NSDate timeIntervalSince1970];
        NSMutableArray *peers = [NSMutableArray arrayWithObject:[NSMutableArray array]];
        NSArray * dnsSeeds = [self dnsSeeds];
        if (_peers.count < PEER_MAX_CONNECTIONS || ((DSPeer *)_peers[PEER_MAX_CONNECTIONS - 1]).timestamp + 3*24*60*60 < now) {
            while (peers.count < dnsSeeds.count) [peers addObject:[NSMutableArray array]];
        }
        
        if (peers.count > 0) {
            if ([dnsSeeds count]) {
                dispatch_apply(peers.count, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t i) {
                    NSString *servname = @(self.chain.standardPort).stringValue;
                    struct addrinfo hints = { 0, AF_UNSPEC, SOCK_STREAM, 0, 0, 0, NULL, NULL }, *servinfo, *p;
                    UInt128 addr = { .u32 = { 0, 0, CFSwapInt32HostToBig(0xffff), 0 } };
                    
                    DSDLog(@"DNS lookup %@", [dnsSeeds objectAtIndex:i]);
                    NSString * dnsSeed = [dnsSeeds objectAtIndex:i];
                    
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
                            else continue;
                            
                            uint16_t port = CFSwapInt16BigToHost(((struct sockaddr_in *)p->ai_addr)->sin_port);
                            NSTimeInterval age = 3*24*60*60 + arc4random_uniform(4*24*60*60); // add between 3 and 7 days
                            
                            [peers[i] addObject:[[DSPeer alloc] initWithAddress:addr port:port onChain:self.chain
                                                                      timestamp:(i > 0 ? now - age : now)
                                                                       services:SERVICES_NODE_NETWORK | SERVICES_NODE_BLOOM]];
                        }
                        
                        freeaddrinfo(servinfo);
                    } else {
                        DSDLog(@"failed getaddrinfo for %@", dnsSeeds[i]);
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
                NSArray * serviceArray = [TESTNET_MAIN_PEER componentsSeparatedByString:@":"];
                NSString * address = serviceArray[0];
                NSString * port = ([serviceArray count] > 1)? serviceArray[1]:nil;
                UInt128 ipAddress = { .u32 = { 0, 0, CFSwapInt32HostToBig(0xffff), 0 } };
                struct in_addr addrV4;
                if (inet_aton([address UTF8String], &addrV4) != 0) {
                    uint32_t ip = ntohl(addrV4.s_addr);
                    ipAddress.u32[3] = CFSwapInt32HostToBig(ip);
                } else {
                    DSDLog(@"invalid address");
                }
                [_peers addObject:[[DSPeer alloc] initWithAddress:ipAddress port:port?[port intValue]:self.chain.standardPort onChain:self.chain
                                                        timestamp:now - (WEEK_TIME_INTERVAL + arc4random_uniform(WEEK_TIME_INTERVAL))
                                                         services:SERVICES_NODE_NETWORK | SERVICES_NODE_BLOOM]];
            } else {
                UInt128 addr = { .u32 = { 0, 0, CFSwapInt32HostToBig(0xffff), 0 } };
                
                NSString *bundlePath = [[NSBundle bundleForClass:self.class] pathForResource:@"DashSync" ofType:@"bundle"];
                NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
                NSString * path = [bundle pathForResource:[self.chain isMainnet]?FIXED_PEERS:TESTNET_FIXED_PEERS ofType:@"plist"];
                for (NSNumber *address in [NSArray arrayWithContentsOfFile:path]) {
                    // give hard coded peers a timestamp between 7 and 14 days ago
                    addr.u32[3] = CFSwapInt32HostToBig(address.unsignedIntValue);
                    [_peers addObject:[[DSPeer alloc] initWithAddress:addr port:self.chain.standardPort onChain:self.chain
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
    dispatch_async(self.chainPeerManagerQueue, ^{
        for (DSPeer *p in self.connectedPeers) {
            p.priority--;
            NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier: NSCalendarIdentifierGregorian];
            p.lowPreferenceTill = [[calendar dateByAddingUnit:NSCalendarUnitDay value:5 toDate:[NSDate date] options:0] timeIntervalSince1970];
        }
    });
}

- (void)peerMisbehaving:(DSPeer *)peer errorMessage:(NSString*)errorMessage
{
    peer.misbehaving++;
    [self.peers removeObject:peer];
    [self.mutableMisbehavingPeers addObject:peer];
    
    if (++self.misbehavingCount >= self.chain.peerMisbehavingThreshold) { // clear out stored peers so we get a fresh list from DNS for next connect
        self.misbehavingCount = 0;
        [self.mutableMisbehavingPeers removeAllObjects];
        [DSPeerEntity deleteAllObjects];
        _peers = nil;
    }
    
    [peer disconnectWithError:[NSError errorWithDomain:@"DashSync" code:500
                                              userInfo:@{NSLocalizedDescriptionKey:errorMessage}]];
    [self connect];
}

- (void)sortPeers
{
    NSTimeInterval threeHoursAgo = [[NSDate date] timeIntervalSince1970] - 10800;
    BOOL syncsMasternodeList = !!([[DSOptionsManager sharedInstance] syncType] & DSSyncType_MasternodeList);
    BOOL syncsGovernanceObjects = !!([[DSOptionsManager sharedInstance] syncType] & DSSyncType_Governance);
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
    //    for (DSPeer * peer in _peers) {
    //        DSDLog(@"%@:%d lastRequestedMasternodeList(%f) lastRequestedGovernanceSync(%f)",peer.host,peer.port,peer.lastRequestedMasternodeList, peer.lastRequestedGovernanceSync);
    //    }
    DSDLog(@"peers sorted");
}

- (void)savePeers
{
    DSDLog(@"[DSPeerManager] save peers");
    NSMutableSet *peers = [[self.peers.set setByAddingObjectsFromSet:self.misbehavingPeers] mutableCopy];
    NSMutableSet *addrs = [NSMutableSet set];
    
    for (DSPeer *p in peers) {
        if (p.address.u64[0] != 0 || p.address.u32[2] != CFSwapInt32HostToBig(0xffff)) continue; // skip IPv6 for now
        [addrs addObject:@(CFSwapInt32BigToHost(p.address.u32[3]))];
    }
    
    [[DSPeerEntity context] performBlock:^{
        [DSChainEntity setContext:[DSPeerEntity context]];
        [DSPeerEntity deleteObjects:[DSPeerEntity objectsMatching:@"(chain == %@) && !(address in %@)", self.chain.chainEntity, addrs]]; // remove deleted peers
        
        for (DSPeerEntity *e in [DSPeerEntity objectsMatching:@"(chain == %@) && (address in %@)", self.chain.chainEntity, addrs]) { // update existing peers
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
                }
                else [e deleteObject];
            }
        }
        
        for (DSPeer *p in peers) {
            @autoreleasepool {
                [[DSPeerEntity managedObject] setAttributesFromPeer:p]; // add new peers
            }
        }
    }];
}

-(DSPeer*)peerForLocation:(UInt128)IPAddress port:(uint16_t)port {
    for (DSPeer * peer in self.peers) {
        if (uint128_eq(peer.address, IPAddress) && peer.port == port) {
            return peer;
        }
    }
    return nil;
}

-(DSPeerStatus)statusForLocation:(UInt128)IPAddress port:(uint32_t)port {
    DSPeer * peer = [self peerForLocation:IPAddress port:port];
    if (!peer) {
        return DSPeerStatus_Unknown;
    } else if ([self.misbehavingPeers containsObject:peer]) {
        return DSPeerStatus_Banned;
    } else {
        return peer.status;
    }
}

-(DSPeerType)typeForLocation:(UInt128)IPAddress port:(uint32_t)port {
    DSPeer * peer = [self peerForLocation:IPAddress port:port];
    if (!peer) {
        return DSPeerType_Unknown;
    }
    if ([self.masternodeManager hasMasternodeAtLocation:IPAddress port:port]) {
        return DSPeerType_MasterNode;
    } else {
        return DSPeerType_FullNode;
    }
}

-(NSString*)settingsFixedPeerKey {
    return [NSString stringWithFormat:@"%@_%@",SETTINGS_FIXED_PEER_KEY,self.chain.uniqueID];
}

-(NSString*)trustedPeerHost {
    if ([[NSUserDefaults standardUserDefaults] objectForKey:[self settingsFixedPeerKey]]) {
        return [[NSUserDefaults standardUserDefaults] stringForKey:[self settingsFixedPeerKey]];
    } else {
        return nil;
    }
}

-(void)setTrustedPeerHost:(NSString * _Nullable)host {
    if (!host) [[NSUserDefaults standardUserDefaults] removeObjectForKey:[self settingsFixedPeerKey]];
    else [[NSUserDefaults standardUserDefaults] setObject:host
                                                   forKey:[self settingsFixedPeerKey]];
}

// MARK: - Peer Registration

- (void)updateFilterOnPeers
{
    if (self.downloadPeer.needsFilterUpdate) return;
    self.downloadPeer.needsFilterUpdate = YES;
    DSDLog(@"filter update needed, waiting for pong");
    
    [self.downloadPeer sendPingMessageWithPongHandler:^(BOOL success) { // wait for pong so we include already sent tx
        if (! success) return;
        //we are on chainPeerManagerQueue
        DSDLog(@"updating filter with newly created wallet addresses");
        [self.transactionManager clearTransactionsBloomFilter];
        
        if (self.chain.lastBlockHeight < self.chain.estimatedBlockHeight) { // if we're syncing, only update download peer
            [self.downloadPeer sendFilterloadMessage:[self.transactionManager transactionsBloomFilterForPeer:self.downloadPeer].data];
            [self.downloadPeer sendPingMessageWithPongHandler:^(BOOL success) { // wait for pong so filter is loaded
                if (! success) return;
                self.downloadPeer.needsFilterUpdate = NO;
                [self.downloadPeer rerequestBlocksFrom:self.chain.lastBlock.blockHash];
                [self.downloadPeer sendPingMessageWithPongHandler:^(BOOL success) {
                    if (! success || self.downloadPeer.needsFilterUpdate) return;
                    [self.downloadPeer sendGetblocksMessageWithLocators:[self.chain blockLocatorArray]
                                                            andHashStop:UINT256_ZERO];
                }];
            }];
        }
        else {
            for (DSPeer *p in self.connectedPeers) {
                if (p.status != DSPeerStatus_Connected) continue;
                [p sendFilterloadMessage:[self.transactionManager transactionsBloomFilterForPeer:p].data];
                [p sendPingMessageWithPongHandler:^(BOOL success) { // wait for pong so we know filter is loaded
                    if (! success) return;
                    p.needsFilterUpdate = NO;
                    [p sendMempoolMessage:self.transactionManager.publishedTx.allKeys completion:nil];
                }];
            }
        }
    }];
}

// MARK: - Peer Registration

-(void)clearRegisteredPeers {
    [self clearPeers];
    setKeychainArray(@[], self.chain.registeredPeersKey, NO);
}

-(void)registerPeerAtLocation:(UInt128)IPAddress port:(uint32_t)port dapiPort:(uint32_t)dapiPort {
    NSError * error = nil;
    NSMutableArray * registeredPeersArray = [getKeychainArray(self.chain.registeredPeersKey, &error) mutableCopy];
    if (!registeredPeersArray) registeredPeersArray = [NSMutableArray array];
    NSDictionary * insertDictionary = @{@"address":[NSData dataWithUInt128:IPAddress],@"port":@(port),@"dapiPort":@(dapiPort)};
    BOOL found = FALSE;
    for (NSDictionary * dictionary in registeredPeersArray) {
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


-(NSArray*)registeredDevnetPeers {
    NSError * error = nil;
    NSMutableArray * registeredPeersArray = [getKeychainArray(self.chain.registeredPeersKey, &error) mutableCopy];
    if (error) return @[];
    NSMutableArray * registeredPeers = [NSMutableArray array];
    for (NSDictionary * peerDictionary in registeredPeersArray) {
        UInt128 ipAddress = *(UInt128*)((NSData*)peerDictionary[@"address"]).bytes;
        uint16_t port = [peerDictionary[@"port"] unsignedShortValue];
        NSTimeInterval now = [NSDate timeIntervalSince1970];
        [registeredPeers addObject:[[DSPeer alloc] initWithAddress:ipAddress port:port onChain:self.chain timestamp:now - (7*24*60*60 + arc4random_uniform(7*24*60*60)) services:SERVICES_NODE_NETWORK | SERVICES_NODE_BLOOM]];
    }
    return [registeredPeers copy];
}

-(NSArray*)registeredDevnetPeerServices {
    NSArray * registeredDevnetPeers = [self registeredDevnetPeers];
    NSMutableArray * registeredDevnetPeerServicesArray = [NSMutableArray array];
    for (DSPeer * peer in registeredDevnetPeers) {
        if (!uint128_is_zero(peer.address)) {
            [registeredDevnetPeerServicesArray addObject:[NSString stringWithFormat:@"%@:%hu",peer.host,peer.port]];
        }
    }
    return [registeredDevnetPeerServicesArray copy];
}

// MARK: - Connectivity

- (void)connect
{
    self.desiredState = DSPeerManagerDesiredState_Connected;
    dispatch_async(self.chainPeerManagerQueue, ^{
        
        if ([self.chain syncsBlockchain] && ![self.chain canConstructAFilter]) return; // check to make sure the wallet has been created if only are a basic wallet with no dash features
        if (self.connectFailures >= MAX_CONNECT_FAILURES) self.connectFailures = 0; // this attempt is a manual retry
        
        if (self.chainManager.syncProgress < 1.0) {
            [self.chainManager resetSyncStartHeight];
            
            if (self.taskId == UIBackgroundTaskInvalid) { // start a background task for the chain sync
                self.taskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
                    dispatch_async(self.chainPeerManagerQueue, ^{
                        [self.chain saveBlocks];
                    });
                    
                    [self syncStopped];
                }];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:DSTransactionManagerSyncStartedNotification
                                                                    object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain}];
            });
        }
        
        @synchronized (self.connectedPeers) {
            [self.mutableConnectedPeers minusSet:[self.connectedPeers objectsPassingTest:^BOOL(id obj, BOOL *stop) {
                return ([obj status] == DSPeerStatus_Disconnected) ? YES : NO;
            }]];
        }
        
        self.fixedPeer = [self trustedPeerHost]?[DSPeer peerWithHost:[self trustedPeerHost] onChain:self.chain]:nil;
        self.maxConnectCount = (self.fixedPeer) ? 1 : PEER_MAX_CONNECTIONS;
        if (self.connectedPeers.count >= self.maxConnectCount) return; // already connected to maxConnectCount peers
        
        NSMutableOrderedSet *peers = [NSMutableOrderedSet orderedSetWithOrderedSet:self.peers];
        
        if (peers.count > 100) [peers removeObjectsInRange:NSMakeRange(100, peers.count - 100)];
        
        if (peers.count > 0 && self.connectedPeers.count < self.maxConnectCount) {
            @synchronized (self.connectedPeers) {
                NSTimeInterval earliestWalletCreationTime = self.chain.earliestWalletCreationTime;;
                while (peers.count > 0 && self.connectedPeers.count < self.maxConnectCount) {
                    // pick a random peer biased towards peers with more recent timestamps
                    DSPeer *peer = peers[(NSUInteger)(pow(arc4random_uniform((uint32_t)peers.count), 2)/peers.count)];
                    
                    if (peer && ! [self.connectedPeers containsObject:peer]) {
                        [peer setChainDelegate:self.chain.chainManager peerDelegate:self transactionDelegate:self.transactionManager governanceDelegate:self.governanceSyncManager sporkDelegate:self.sporkManager masternodeDelegate:self.masternodeManager queue:self.chainPeerManagerQueue];
                        peer.earliestKeyTime = earliestWalletCreationTime;
                        
                        [self.mutableConnectedPeers addObject:peer];
                        
                        [peer connect];
                    }
                    
                    [peers removeObject:peer];
                }
            }
        }
        
        if (self.connectedPeers.count == 0) {
            [self syncStopped];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                NSError *error = [NSError errorWithDomain:@"DashSync" code:1
                                                 userInfo:@{NSLocalizedDescriptionKey:DSLocalizedString(@"no peers found", nil)}];
                
                [[NSNotificationCenter defaultCenter] postNotificationName:DSTransactionManagerSyncFailedNotification
                                                                    object:nil userInfo:@{@"error":error,DSChainManagerNotificationChainKey:self.chain}];
            });
        }
    });
}

- (void)disconnect
{
    self.desiredState = DSPeerManagerDesiredState_Disconnected;
    dispatch_async(self.chainPeerManagerQueue, ^{
        for (DSPeer *peer in self.connectedPeers) {
            self.connectFailures = MAX_CONNECT_FAILURES; // prevent futher automatic reconnect attempts
            [peer disconnect];
        }
    });
}

- (void)disconnectDownloadPeerWithCompletion:(void (^ _Nullable)(BOOL success))completion {
    [self.downloadPeer disconnect];
    dispatch_async(self.chainPeerManagerQueue, ^{
        if (self.downloadPeer) { // disconnect the current download peer so a new random one will be selected
            [self.peers removeObject:self.downloadPeer];
        }
        if (completion) completion(TRUE);
    });
}

- (void)syncTimeout
{
    NSTimeInterval now = [NSDate timeIntervalSince1970];
    
    if (now - self.chainManager.lastChainRelayTime < PROTOCOL_TIMEOUT) { // the download peer relayed something in time, so restart timer
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(syncTimeout) object:nil];
        [self performSelector:@selector(syncTimeout) withObject:nil
                   afterDelay:PROTOCOL_TIMEOUT - (now - self.chainManager.lastChainRelayTime)];
        return;
    }
    [self disconnectDownloadPeerWithCompletion:nil];
}

- (void)syncStopped
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(syncTimeout) object:nil];
        
        if (self.taskId != UIBackgroundTaskInvalid) {
            [[UIApplication sharedApplication] endBackgroundTask:self.taskId];
            self.taskId = UIBackgroundTaskInvalid;
        }
    });
}

// MARK: - DSPeerDelegate

- (void)peerConnected:(DSPeer *)peer
{
    NSTimeInterval now = [NSDate timeIntervalSince1970];
    
    if (peer.timestamp > now + 2*60*60 || peer.timestamp < now - 2*60*60) peer.timestamp = now; //timestamp sanity check
    self.connectFailures = 0;
    DSDLog(@"%@:%d connected with lastblock %d", peer.host, peer.port, peer.lastblock);
    
    // drop peers that don't carry full blocks, or aren't synced yet
    // TODO: XXXX does this work with 0.11 pruned nodes?
    if (! (peer.services & SERVICES_NODE_NETWORK) || peer.lastblock + 10 < self.chain.lastBlockHeight) {
        [peer disconnect];
        return;
    }
    
    // drop peers that don't support SPV filtering
    if (peer.version >= 70206 && !(peer.services & SERVICES_NODE_BLOOM)) {
        [peer disconnect];
        return;
    }
    
    if (self.connected) {
        if (![self.chain syncsBlockchain]) return;
        if (self.chain.estimatedBlockHeight >= peer.lastblock || self.chain.lastBlockHeight >= peer.lastblock) {
            if (self.chain.lastBlockHeight < self.chain.estimatedBlockHeight) {
                DSDLog(@"self.chain.lastBlockHeight %u, self.chain.estimatedBlockHeight %u",self.chain.lastBlockHeight,self.chain.estimatedBlockHeight);
                return; // don't load bloom filter yet if we're syncing
            }
            if ([self.chain canConstructAFilter]) {
                [peer sendFilterloadMessage:[self.transactionManager transactionsBloomFilterForPeer:peer].data];
                [peer sendInvMessageForHashes:self.transactionManager.publishedCallback.allKeys ofType:DSInvType_Tx]; // publish pending tx
            } else {
                [peer sendFilterloadMessage:[DSBloomFilter emptyBloomFilterData]];
            }
            [peer sendPingMessageWithPongHandler:^(BOOL success) {
                if (! success) {
                    DSDLog(@"[DSTransactionManager] fetching mempool ping on connection failure peer %@",peer.host);
                    return;
                }
                DSDLog(@"[DSTransactionManager] fetching mempool ping on connection success peer %@",peer.host);
                [peer sendMempoolMessage:self.transactionManager.publishedTx.allKeys completion:^(BOOL success,BOOL needed,BOOL interruptedByDisconnect) {
                    if (! success) {
                        if (!needed) {
                            DSDLog(@"[DSTransactionManager] fetching mempool message on connection not needed (already happening) peer %@",peer.host);
                        } else if (interruptedByDisconnect) {
                            DSDLog(@"[DSTransactionManager] fetching mempool message on connection failure peer %@",peer.host);
                        } else {
                            DSDLog(@"[DSTransactionManager] fetching mempool message on connection failure disconnect peer %@",peer.host);
                        }
                        return;
                    }
                    DSDLog(@"[DSTransactionManager] fetching mempool message on connection success peer %@",peer.host);
                    peer.synced = YES;
                    [self.transactionManager removeUnrelayedTransactionsFromPeer:peer];
                    [peer sendGetaddrMessage]; // request a list of other dash peers
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[NSNotificationCenter defaultCenter] postNotificationName:DSTransactionManagerTransactionStatusDidChangeNotification
                                                                            object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain}];
                    });
                }];
            }];
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:DSPeerManagerConnectedPeersDidChangeNotification
                                                                    object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain}];
            });
            return; // we're already connected to a download peer
        }
    }
    
    // select the peer with the lowest ping time to download the chain from if we're behind
    // BUG: XXX a malicious peer can report a higher lastblock to make us select them as the download peer, if two
    // peers agree on lastblock, use one of them instead
    for (DSPeer *p in self.connectedPeers) {
        if (p.status != DSPeerStatus_Connected) continue;
        if ((p.pingTime < peer.pingTime && p.lastblock >= peer.lastblock) || p.lastblock > peer.lastblock) peer = p;
    }
    
    [self.downloadPeer disconnect];
    self.downloadPeer = peer;
    _connected = YES;
    [self.chain setEstimatedBlockHeight:peer.lastblock fromPeer:peer];
    if ([self.chain syncsBlockchain] && [self.chain canConstructAFilter]) {
        [peer sendFilterloadMessage:[self.transactionManager transactionsBloomFilterForPeer:peer].data];
    }
    peer.currentBlockHeight = self.chain.lastBlockHeight;
    
    
    if ([self.chain syncsBlockchain] && (self.chain.lastBlockHeight < peer.lastblock)) { // start blockchain sync
        [self.chainManager resetLastRelayedItemTime];
        dispatch_async(dispatch_get_main_queue(), ^{ // setup a timer to detect if the sync stalls
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(syncTimeout) object:nil];
            [self performSelector:@selector(syncTimeout) withObject:nil afterDelay:PROTOCOL_TIMEOUT];
            
            [[NSNotificationCenter defaultCenter] postNotificationName:DSTransactionManagerTransactionStatusDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain}];
            
            [self.chainManager chainWillStartSyncingBlockchain:self.chain];
            
            dispatch_async(self.chainPeerManagerQueue, ^{
                // request just block headers up to a week before earliestKeyTime, and then merkleblocks after that
                // BUG: XXX headers can timeout on slow connections (each message is over 160k)
                BOOL startingDevnetSync = [self.chain isDevnetAny] && self.chain.lastBlock.height < 5;
                if (startingDevnetSync || self.chain.lastBlock.timestamp + (2*HOUR_TIME_INTERVAL + WEEK_TIME_INTERVAL)/4 >= self.chain.earliestWalletCreationTime) {
                    [peer sendGetblocksMessageWithLocators:[self.chain blockLocatorArray] andHashStop:UINT256_ZERO];
                }
                else {
                    [peer sendGetheadersMessageWithLocators:[self.chain blockLocatorArray] andHashStop:UINT256_ZERO];
                }
            });
        });
    }
    else { // we're already synced
        [self.chainManager chainFinishedSyncingTransactionsAndBlocks:self.chain fromPeer:nil onMainChain:TRUE];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DSPeerManagerConnectedPeersDidChangeNotification
                                                            object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain}];
        [[NSNotificationCenter defaultCenter] postNotificationName:DSPeerManagerDownloadPeerDidChangeNotification
                                                            object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain}];
    });
}

- (void)peer:(DSPeer *)peer disconnectedWithError:(NSError *)error
{
    DSDLog(@"%@:%d disconnected%@%@", peer.host, peer.port, (error ? @", " : @""), (error ? error : @""));
    
    if ([error.domain isEqual:@"DashSync"] && error.code != DASH_PEER_TIMEOUT_CODE) {
        [self peerMisbehaving:peer errorMessage:error.localizedDescription]; // if it's protocol error other than timeout, the peer isn't following the rules
    }
    else if (error) { // timeout or some non-protocol related network error
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
    
    if (! self.connected && self.connectFailures == MAX_CONNECT_FAILURES) {
        [self syncStopped];
        
        // clear out stored peers so we get a fresh list from DNS on next connect attempt
        [self.mutableMisbehavingPeers removeAllObjects];
        [DSPeerEntity deleteAllObjects];
        _peers = nil;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSTransactionManagerSyncFailedNotification
                                                                object:nil userInfo:(error) ? @{@"error":error,DSChainManagerNotificationChainKey:self.chain} : @{DSChainManagerNotificationChainKey:self.chain}];
        });
    }
    else if (self.connectFailures < MAX_CONNECT_FAILURES) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if ((self.desiredState == DSPeerManagerDesiredState_Connected) && (self.taskId != UIBackgroundTaskInvalid ||
                [UIApplication sharedApplication].applicationState != UIApplicationStateBackground)) {
                [self connect]; // try connecting to another peer
            }
        });
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DSPeerManagerConnectedPeersDidChangeNotification
                                                            object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain}];
        [[NSNotificationCenter defaultCenter] postNotificationName:DSPeerManagerDownloadPeerDidChangeNotification
                                                            object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain}];
    });
}

- (void)peer:(DSPeer *)peer relayedPeers:(NSArray *)peers
{
    DSDLog(@"%@:%d relayed %d peer(s)", peer.host, peer.port, (int)peers.count);
    [self.peers addObjectsFromArray:peers];
    [self.peers minusSet:self.misbehavingPeers];
    [self sortPeers];
    
    // limit total to 2500 peers
    if (self.peers.count > 2500) [self.peers removeObjectsInRange:NSMakeRange(2500, self.peers.count - 2500)];
    
    NSTimeInterval now = [NSDate timeIntervalSince1970];
    
    // remove peers more than 3 hours old, or until there are only 1000 left
    while (self.peers.count > 1000 && ((DSPeer *)self.peers.lastObject).timestamp + 3*60*60 < now) {
        [self.peers removeObject:self.peers.lastObject];
    }
    
    if (peers.count > 1 && peers.count < 1000) [self savePeers]; // peer relaying is complete when we receive <1000
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DSPeerManagerPeersDidChangeNotification
                                                            object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain}];
    });
    
}

@end
