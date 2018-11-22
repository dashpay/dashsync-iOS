//
//  DSChainPeerManager.m
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
#import "DSDAPIPeerManager.h"
#import "NSDate+Utils.h"
#import "DSTransactionManager+Protected.h"
#import "DSChainManager+Protected.h"
#import "DSBloomFilter.h"

#define PEER_LOGGING 1

#if ! PEER_LOGGING
#define NSLog(...)
#endif

#define TESTNET_DNS_SEEDS @[/*@"testnet-dnsseed.dash.org",@"test.dnsseed.masternode.io",@"testnet-seed.dashdot.io"*/]

#define MAINNET_DNS_SEEDS @[@"dnsseed.dash.org"]


#define FIXED_PEERS          @"FixedPeers"
#define TESTNET_FIXED_PEERS  @"TestnetFixedPeers"

#define SYNC_COUNT_INFO @"SYNC_COUNT_INFO"

@interface DSPeerManager ()

@property (nonatomic, strong) NSMutableOrderedSet *peers;
@property (nonatomic, strong) NSMutableSet *connectedPeers, *misbehavinPeers, *nonFpTx;
@property (nonatomic, strong) DSPeer *downloadPeer, *fixedPeer;
@property (nonatomic, assign) NSUInteger taskId, connectFailures, misbehavinCount, maxConnectCount;
@property (nonatomic, strong) dispatch_queue_t chainPeerManagerQueue;
@property (nonatomic, strong) id backgroundObserver, walletAddedObserver;
@property (nonatomic, strong) DSChain * chain;

@end

@implementation DSPeerManager

- (instancetype)initWithChain:(DSChain*)chain
{
    if (! (self = [super init])) return nil;
    
    self.chain = chain;
    self.connectedPeers = [NSMutableSet set];
    self.misbehavinPeers = [NSMutableSet set];
    self.nonFpTx = [NSMutableSet set];
    self.taskId = UIBackgroundTaskInvalid;
    self.chainPeerManagerQueue = dispatch_queue_create("org.dashcore.dashsync.peermanager", DISPATCH_QUEUE_SERIAL);
    self.maxConnectCount = PEER_MAX_CONNECTIONS;
    
    self.backgroundObserver =
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil
                                                       queue:nil usingBlock:^(NSNotification *note) {
                                                           [self savePeers];
                                                           [self.chain saveBlocks];
                                                           
                                                           if (self.taskId == UIBackgroundTaskInvalid) {
                                                               self.misbehavinCount = 0;
                                                               [self.connectedPeers makeObjectsPerformSelector:@selector(disconnect)];
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

// MARK: - Managers

-(DSMasternodeManager*)masternodeManager {
    return self.chain.chainManager.masternodeManager;
}

-(DSTransactionManager*)transactionManager {
    return self.chain.chainManager.transactionManager;
}

-(DSMempoolManager*)mempoolManager {
    return self.chain.chainManager.mempoolManager;
}

-(DSGovernanceSyncManager*)governanceSyncManager {
    return self.chain.chainManager.governanceSyncManager;
}

-(DSChainManager*)chainManager {
    return self.chain.chainManager;
}

// MARK: - Info

// number of connected peers
- (NSUInteger)connectedPeerCount
{
    NSUInteger count = 0;
    
    for (DSPeer *peer in [self.connectedPeers copy]) {
        if (peer.status == DSPeerStatus_Connected) count++;
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
                    else [self.misbehavinPeers addObject:[e peer]];
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
                    
                    NSLog(@"DNS lookup %@", [dnsSeeds objectAtIndex:i]);
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
                        NSLog(@"failed getaddrinfo for %@", dnsSeeds[i]);
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
                UInt128 addr = { .u32 = { 0, 0, CFSwapInt32HostToBig(0xffff), 0 } };
                
                NSString *bundlePath = [[NSBundle bundleForClass:self.class] pathForResource:@"DashSync" ofType:@"bundle"];
                NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
                NSString * path = [bundle pathForResource:[self.chain isMainnet]?FIXED_PEERS:TESTNET_FIXED_PEERS ofType:@"plist"];
                for (NSNumber *address in [NSArray arrayWithContentsOfFile:path]) {
                    // give hard coded peers a timestamp between 7 and 14 days ago
                    addr.u32[3] = CFSwapInt32HostToBig(address.unsignedIntValue);
                    [_peers addObject:[[DSPeer alloc] initWithAddress:addr port:self.chain.standardPort onChain:self.chain
                                                            timestamp:now - (7*24*60*60 + arc4random_uniform(7*24*60*60))
                                                             services:SERVICES_NODE_NETWORK | SERVICES_NODE_BLOOM]];
                }
            }
            
            [self sortPeers];
        }
        
        return _peers;
    }
}


- (void)changeCurrentPeers {
    for (DSPeer *p in self.connectedPeers) {
        p.priority--;
        NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier: NSCalendarIdentifierGregorian];
        p.lowPreferenceTill = [[calendar dateByAddingUnit:NSCalendarUnitDay value:5 toDate:[NSDate date] options:0] timeIntervalSince1970];
    }
}

- (void)peerMisbehavin:(DSPeer *)peer
{
    peer.misbehavin++;
    [self.peers removeObject:peer];
    [self.misbehavinPeers addObject:peer];
    
    if (++self.misbehavinCount >= 10) { // clear out stored peers so we get a fresh list from DNS for next connect
        self.misbehavinCount = 0;
        [self.misbehavinPeers removeAllObjects];
        [DSPeerEntity deleteAllObjects];
        _peers = nil;
    }
    
    [peer disconnect];
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
    //        NSLog(@"%@:%d lastRequestedMasternodeList(%f) lastRequestedGovernanceSync(%f)",peer.host,peer.port,peer.lastRequestedMasternodeList, peer.lastRequestedGovernanceSync);
    //    }
    NSLog(@"peers sorted");
}

- (void)savePeers
{
    NSLog(@"[DSChainPeerManager] save peers");
    NSMutableSet *peers = [[self.peers.set setByAddingObjectsFromSet:self.misbehavinPeers] mutableCopy];
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
                    e.misbehavin = p.misbehavin;
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
    } else if ([self.misbehavinPeers containsObject:peer]) {
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

-(void)setTrustedPeerHost:(NSString*)host {
    if (!host) [[NSUserDefaults standardUserDefaults] removeObjectForKey:[self settingsFixedPeerKey]];
    else [[NSUserDefaults standardUserDefaults] setObject:host
                                                   forKey:[self settingsFixedPeerKey]];
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
                [[NSNotificationCenter defaultCenter] postNotificationName:DSChainPeerManagerSyncStartedNotification
                                                                    object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain}];
            });
        }
        
        [self.connectedPeers minusSet:[self.connectedPeers objectsPassingTest:^BOOL(id obj, BOOL *stop) {
            return ([obj status] == DSPeerStatus_Disconnected) ? YES : NO;
        }]];
        
        self.fixedPeer = [self trustedPeerHost]?[DSPeer peerWithHost:[self trustedPeerHost] onChain:self.chain]:nil;
        self.maxConnectCount = (self.fixedPeer) ? 1 : PEER_MAX_CONNECTIONS;
        if (self.connectedPeers.count >= self.maxConnectCount) return; // already connected to maxConnectCount peers
        
        NSMutableOrderedSet *peers = [NSMutableOrderedSet orderedSetWithOrderedSet:self.peers];
        
        if (peers.count > 100) [peers removeObjectsInRange:NSMakeRange(100, peers.count - 100)];
        
        while (peers.count > 0 && self.connectedPeers.count < self.maxConnectCount) {
            // pick a random peer biased towards peers with more recent timestamps
            DSPeer *p = peers[(NSUInteger)(pow(arc4random_uniform((uint32_t)peers.count), 2)/peers.count)];
            
            if (p && ! [self.connectedPeers containsObject:p]) {
                [p setDelegate:self queue:self.chainPeerManagerQueue];
                p.earliestKeyTime = self.chain.earliestWalletCreationTime;
                [self.connectedPeers addObject:p];
                [p connect];
            }
            
            [peers removeObject:p];
        }
        
        if (self.connectedPeers.count == 0) {
            [self syncStopped];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                NSError *error = [NSError errorWithDomain:@"DashWallet" code:1
                                                 userInfo:@{NSLocalizedDescriptionKey:DSLocalizedString(@"no peers found", nil)}];
                
                [[NSNotificationCenter defaultCenter] postNotificationName:DSChainPeerManagerSyncFailedNotification
                                                                    object:nil userInfo:@{@"error":error,DSChainManagerNotificationChainKey:self.chain}];
            });
        }
    });
}

- (void)disconnect
{
    for (DSPeer *peer in self.connectedPeers) {
        self.connectFailures = MAX_CONNECT_FAILURES; // prevent futher automatic reconnect attempts
        [peer disconnect];
    }
}

- (void)disconnectDownloadPeerWithCompletion:(void (^ _Nullable)(BOOL success))completion {
    
    dispatch_async(self.chainPeerManagerQueue, ^{
        if (self.downloadPeer) { // disconnect the current download peer so a new random one will be selected
            [self.peers removeObject:self.downloadPeer];
            [self.downloadPeer disconnect];
        }
        completion(TRUE);
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
    [self disconnectDownloadPeer];
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

// MARK: - Count Info

-(void)setCount:(uint32_t)count forSyncCountInfo:(DSSyncCountInfo)syncCountInfo {
    //    if (syncCountInfo ==  DSSyncCountInfo_List || syncCountInfo == DSSyncCountInfo_GovernanceObject) {
    //        NSString * storageKey = [NSString stringWithFormat:@"%@_%@_%d",self.chain.uniqueID,SYNC_COUNT_INFO,syncCountInfo];
    //        [[NSUserDefaults standardUserDefaults] setInteger:count forKey:storageKey];
    //        [self.syncCountInfo setObject:@(count) forKey:@(syncCountInfo)];
    //    }
    switch (syncCountInfo) {
        case DSSyncCountInfo_List:
            self.chain.totalMasternodeCount = count;
            [self.chain save];
            break;
        case DSSyncCountInfo_GovernanceObject:
            self.chain.totalGovernanceObjectsCount = count;
            [self.chain save];
            break;
        case DSSyncCountInfo_GovernanceObjectVote:
            self.governanceSyncManager.currentGovernanceSyncObject.totalGovernanceVoteCount = count;
            [self.governanceSyncManager.currentGovernanceSyncObject save];
            break;
        default:
            break;
    }
}

// MARK: - DSPeerDelegate

- (void)peerConnected:(DSPeer *)peer
{
    NSTimeInterval now = [NSDate timeIntervalSince1970];
    
    if (peer.timestamp > now + 2*60*60 || peer.timestamp < now - 2*60*60) peer.timestamp = now; //timestamp sanity check
    self.connectFailures = 0;
    NSLog(@"%@:%d connected with lastblock %d", peer.host, peer.port, peer.lastblock);
    
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
                NSLog(@"self.chain.lastBlockHeight %u, self.chain.estimatedBlockHeight %u",self.chain.lastBlockHeight,self.chain.estimatedBlockHeight);
                return; // don't load bloom filter yet if we're syncing
            }
            if ([self.chain canConstructAFilter]) {
                [peer sendFilterloadMessage:[self.chainManager bloomFilterForPeer:peer].data];
                [peer sendInvMessageForHashes:self.transactionManager.publishedCallback.allKeys ofType:DSInvType_Tx]; // publish pending tx
            } else {
                [peer sendFilterloadMessage:[DSBloomFilter emptyBloomFilterData]];
            }
            [peer sendPingMessageWithPongHandler:^(BOOL success) {
                if (! success) return;
                [peer sendMempoolMessage:self.transactionManager.publishedTx.allKeys completion:^(BOOL success) {
                    if (! success) return;
                    peer.synced = YES;
                    [self.transactionManager removeUnrelayedTransactions];
                    [peer sendGetaddrMessage]; // request a list of other dash peers
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[NSNotificationCenter defaultCenter] postNotificationName:DSChainPeerManagerTxStatusNotification
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
        [peer sendFilterloadMessage:[self.chainManager bloomFilterForPeer:peer].data];
    }
    peer.currentBlockHeight = self.chain.lastBlockHeight;
    
    if ([self.chain syncsBlockchain] && (self.chain.lastBlockHeight < peer.lastblock)) { // start blockchain sync
        self.chainManager.lastChainRelayTime = 0;
        dispatch_async(dispatch_get_main_queue(), ^{ // setup a timer to detect if the sync stalls
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(syncTimeout) object:nil];
            [self performSelector:@selector(syncTimeout) withObject:nil afterDelay:PROTOCOL_TIMEOUT];
            
            [[NSNotificationCenter defaultCenter] postNotificationName:DSChainPeerManagerTxStatusNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain}];
            
            dispatch_async(self.chainPeerManagerQueue, ^{
                // request just block headers up to a week before earliestKeyTime, and then merkleblocks after that
                // BUG: XXX headers can timeout on slow connections (each message is over 160k)
                BOOL startingDevnetSync = [self.chain isDevnetAny] && self.chain.lastBlock.height < 5;
                if (startingDevnetSync || self.chain.lastBlock.timestamp + 7*24*60*60 >= self.chain.earliestWalletCreationTime) {
                    [peer sendGetblocksMessageWithLocators:[self.chain blockLocatorArray] andHashStop:UINT256_ZERO];
                }
                else [peer sendGetheadersMessageWithLocators:[self.chain blockLocatorArray] andHashStop:UINT256_ZERO];
            });
        });
    }
    else { // we're already synced
        [self.chainManager restartSyncStartHeight];
        [self loadMempools];
        [self getSporks];
        [self startGovernanceSync];
        [self getMasternodeList];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DSPeerManagerConnectedPeersDidChangeNotification
                                                            object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain}];
    });
}

- (void)peer:(DSPeer *)peer disconnectedWithError:(NSError *)error
{
    NSLog(@"%@:%d disconnected%@%@", peer.host, peer.port, (error ? @", " : @""), (error ? error : @""));
    
    if ([error.domain isEqual:@"DashWallet"] && error.code != BITCOIN_TIMEOUT_CODE) {
        [self peerMisbehavin:peer]; // if it's protocol error other than timeout, the peer isn't following the rules
    }
    else if (error) { // timeout or some non-protocol related network error
        [self.peers removeObject:peer];
        self.connectFailures++;
    }
    
    [self.transactionManager clearTransactionRelaysForPeer:peer];
    
    if ([self.downloadPeer isEqual:peer]) { // download peer disconnected
        _connected = NO;
        self.downloadPeer = nil;
        if (self.connectFailures > MAX_CONNECT_FAILURES) self.connectFailures = MAX_CONNECT_FAILURES;
    }
    
    if (! self.connected && self.connectFailures == MAX_CONNECT_FAILURES) {
        [self syncStopped];
        
        // clear out stored peers so we get a fresh list from DNS on next connect attempt
        [self.misbehavinPeers removeAllObjects];
        [DSPeerEntity deleteAllObjects];
        _peers = nil;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSChainPeerManagerSyncFailedNotification
                                                                object:nil userInfo:(error) ? @{@"error":error,DSChainManagerNotificationChainKey:self.chain} : @{DSChainManagerNotificationChainKey:self.chain}];
        });
    }
    else if (self.connectFailures < MAX_CONNECT_FAILURES) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.taskId != UIBackgroundTaskInvalid ||
                [UIApplication sharedApplication].applicationState != UIApplicationStateBackground) {
                [self connect]; // try connecting to another peer
            }
        });
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DSPeerManagerConnectedPeersDidChangeNotification
                                                            object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain}];
        [[NSNotificationCenter defaultCenter] postNotificationName:DSChainPeerManagerTxStatusNotification object:nil userInfo:@{DSChainManagerNotificationChainKey:self.chain}];
    });
}

- (void)peer:(DSPeer *)peer relayedPeers:(NSArray *)peers
{
    NSLog(@"%@:%d relayed %d peer(s)", peer.host, peer.port, (int)peers.count);
    [self.peers addObjectsFromArray:peers];
    [self.peers minusSet:self.misbehavinPeers];
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

- (void)peer:(DSPeer *)peer relayedBlock:(DSMerkleBlock *)block
{
    // ignore block headers that are newer than one week before earliestKeyTime (headers have 0 totalTransactions)
    if (block.totalTransactions == 0 &&
        block.timestamp + WEEK_TIME_INTERVAL/4 > self.chain.earliestWalletCreationTime + HOUR_TIME_INTERVAL/2) {
        return;
    }
    
    NSArray *txHashes = block.txHashes;
    
    // track the observed bloom filter false positive rate using a low pass filter to smooth out variance
    if (peer == self.downloadPeer && block.totalTransactions > 0) {
        NSMutableSet *fp = [NSMutableSet setWithArray:txHashes];
        
        // 1% low pass filter, also weights each block by total transactions, using 1400 tx per block as typical
        [fp minusSet:self.nonFpTx]; // wallet tx are not false-positives
        [self.nonFpTx removeAllObjects];
        self.fpRate = self.fpRate*(1.0 - 0.01*block.totalTransactions/1400) + 0.01*fp.count/1400;
        
        // false positive rate sanity check
        if (self.downloadPeer.status == DSPeerStatus_Connected && self.fpRate > BLOOM_DEFAULT_FALSEPOSITIVE_RATE*10.0) {
            NSLog(@"%@:%d bloom filter false positive rate %f too high after %d blocks, disconnecting...", peer.host,
                  peer.port, self.fpRate, self.chain.lastBlockHeight + 1 - self.filterUpdateHeight);
            [self.downloadPeer disconnect];
        }
        else if (self.chain.lastBlockHeight + 500 < peer.lastblock && self.fpRate > BLOOM_REDUCED_FALSEPOSITIVE_RATE*10.0) {
            [self updateFilter]; // rebuild bloom filter when it starts to degrade
        }
    }
    
    if (! _bloomFilter) { // ignore potentially incomplete blocks when a filter update is pending
        if (peer == self.downloadPeer) self.chainManager.lastChainRelayTime = [NSDate timeIntervalSince1970];
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

- (void)peer:(DSPeer *)peer setFeePerByte:(uint64_t)feePerKb
{
    uint64_t maxFeePerByte = 0, secondFeePerByte = 0;
    
    for (DSPeer *p in self.connectedPeers) { // find second highest fee rate
        if (p.status != DSPeerStatus_Connected) continue;
        if (p.feePerByte > maxFeePerByte) secondFeePerByte = maxFeePerByte, maxFeePerByte = p.feePerByte;
    }
    
    if (secondFeePerByte*2 > MIN_FEE_PER_B && secondFeePerByte*2 <= MAX_FEE_PER_B &&
        secondFeePerByte*2 > self.chain.feePerByte) {
        NSLog(@"increasing feePerKb to %llu based on feefilter messages from peers", secondFeePerByte*2);
        self.chain.feePerByte = secondFeePerByte*2;
    }
}

- (DSGovernanceVote *)peer:(DSPeer *)peer requestedVote:(UInt256)voteHash {
    return [self.governanceSyncManager peer:peer requestedVote:voteHash];
}
- (DSGovernanceObject *)peer:(DSPeer *)peer requestedGovernanceObject:(UInt256)governanceObjectHash {
    return [self.governanceSyncManager peer:peer requestedGovernanceObject:governanceObjectHash];
}


// MARK: Dash Specific

- (void)peer:(DSPeer *)peer relayedSpork:(DSSpork *)spork {
    if (spork.isValid) {
        [self.sporkManager peer:(DSPeer*)peer relayedSpork:spork];
    } else {
        [self peerMisbehavin:peer];
    }
}

- (void)peer:(DSPeer *)peer relayedSyncInfo:(DSSyncCountInfo)syncCountInfo count:(uint32_t)count {
    [self setCount:count forSyncCountInfo:syncCountInfo];
    switch (syncCountInfo) {
        case DSSyncCountInfo_List:
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:DSMasternodeListCountUpdateNotification object:nil userInfo:@{@(syncCountInfo):@(count),DSChainManagerNotificationChainKey:self.chain}];
            });
            break;
        }
        case DSSyncCountInfo_GovernanceObject:
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:DSGovernanceObjectCountUpdateNotification object:nil userInfo:@{@(syncCountInfo):@(count),DSChainManagerNotificationChainKey:self.chain}];
            });
            break;
        }
        case DSSyncCountInfo_GovernanceObjectVote:
        {
            if (peer.governanceRequestState == DSGovernanceRequestState_GovernanceObjectVoteHashesReceived) {
                if (count == 0) {
                    //there were no votes
                    NSLog(@"no votes on object, going to next object");
                    peer.governanceRequestState = DSGovernanceRequestState_GovernanceObjectVotes;
                    [self.governanceSyncManager finishedGovernanceVoteSyncWithPeer:peer];
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[NSNotificationCenter defaultCenter] postNotificationName:DSGovernanceVoteCountUpdateNotification object:nil userInfo:@{@(syncCountInfo):@(count),DSChainManagerNotificationChainKey:self.chain}];
                    });
                }
            }
            
            break;
        }
        default:
            break;
    }
}

- (void)peer:(DSPeer *)peer hasGovernanceVoteHashes:(NSSet*)governanceVoteHashes {
    [self.governanceSyncManager.currentGovernanceSyncObject peer:peer hasGovernanceVoteHashes:governanceVoteHashes];
}

@end
