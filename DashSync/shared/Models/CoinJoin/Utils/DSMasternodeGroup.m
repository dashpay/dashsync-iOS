//  
//  Created by Andrei Ashikhmin
//  Copyright © 2024 Dash Core Group. All rights reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://opensource.org/licenses/MIT
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "DSMasternodeGroup.h"
#import "DSChainManager.h"
#import "DSChain+Protected.h"
#import "DSCoinJoinManager.h"
#import "DSSimplifiedMasternodeEntry.h"
#import "DSMasternodeManager.h"
#import "DSPeerManager.h"
#import "DSSendCoinJoinQueue.h"
#import "DSBackoff.h"
#import "DSBlock.h"
#import <arpa/inet.h>

float_t const MIN_PEER_DISCOVERY_INTERVAL = 1; // One second
float_t const DEFAULT_INITIAL_BACKOFF = 1; // One second
float_t const DEFAULT_MAX_BACKOFF = 5; // Five seconds
float_t const GROUP_BACKOFF_MULTIPLIER = 1.5;
float_t const BACKOFF_MULTIPLIER = 1.001;

@interface DSMasternodeGroup ()

@property (nonatomic, strong) DSChain *chain;
@property (nonatomic, weak, nullable) DSCoinJoinManager *coinJoinManager; // TODO: sync all access points
@property (nonatomic, strong) NSMutableSet<NSValue *> *pendingSessions;
@property (nonatomic, strong) NSMutableDictionary *masternodeMap;
@property (nonatomic, strong) NSMutableDictionary *addressMap;
@property (atomic, readonly) NSUInteger maxConnections;
@property (nonatomic, strong) NSMutableArray<DSPeer *> *pendingClosingMasternodes;
@property (nonatomic, strong) NSMutableSet *mutableConnectedPeers;
@property (nonatomic, strong) NSMutableSet *mutablePendingPeers;
@property (nonatomic, readonly) BOOL shouldSendDsq;
@property (nullable, nonatomic, readwrite) DSPeer *downloadPeer;
@property (nonatomic, readonly) NSUInteger backoff;
@property (nonatomic, strong) DSBackoff *groupBackoff;
@property (nonatomic, strong) NSMutableDictionary<NSString*, DSBackoff*> *backoffMap;
@property (nonatomic, strong) NSMutableArray<DSPeer *> *inactives;
@property (nonatomic, strong) NSLock *lock;
@property (nonatomic, strong) id blocksObserver;
@property (nonatomic) uint32_t lastSeenBlock;

@end

@implementation DSMasternodeGroup

- (instancetype)initWithManager:(DSCoinJoinManager *)manager {
    self = [super init];
    if (self) {
        _coinJoinManager = manager;
        _chain = manager.chain;
        _pendingSessions = [NSMutableSet set];
        _pendingClosingMasternodes = [NSMutableArray array];
        _masternodeMap = [NSMutableDictionary dictionary];
        _addressMap = [NSMutableDictionary dictionary];
        _mutableConnectedPeers = [NSMutableSet set];
        _mutablePendingPeers = [NSMutableSet set];
        _downloadPeer = nil;
        _maxConnections = 0;
        _shouldSendDsq = true;
        _groupBackoff = [[DSBackoff alloc] initInitialBackoff:DEFAULT_INITIAL_BACKOFF maxBackoff:DEFAULT_MAX_BACKOFF multiplier:GROUP_BACKOFF_MULTIPLIER];
        _backoffMap = [NSMutableDictionary dictionary];
        _inactives = [NSMutableArray array];
        _lastSeenBlock = 0;
    }
    return self;
}

- (void)startAsync {
    _isRunning = true;
    self.blocksObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:DSChainManagerSyncStateDidChangeNotification
                                                          object:nil
                                                           queue:nil
                                                      usingBlock:^(NSNotification *note) {
                                                          if ([note.userInfo[DSChainManagerNotificationChainKey] isEqual:[self chain]] && self.chain.lastSyncBlock.height > self.lastSeenBlock) {
                                                              
                                                              DSLog(@"[OBJ-C] CoinJoin: new block found, restarting masternode connections job");
                                                              [self triggerConnections];
                                                          }
                                                      }];
}

- (dispatch_queue_t)networkingQueue {
    return self.chain.networkingQueue;
}

- (void)stopAsync {
    _isRunning = false;
    [[NSNotificationCenter defaultCenter] removeObserver:self.blocksObserver];
}

- (BOOL)isMasternodeOrDisconnectRequested:(UInt128)ip port:(uint16_t)port {
    BOOL found = [self forPeer:ip port:port warn:NO withPredicate:^BOOL(DSPeer *peer) {
        return YES;
    }];
    
    if (!found) {
        for (DSPeer *mn in self.pendingClosingMasternodes) {
            if (uint128_eq(mn.address, ip) && mn.port == port) {
                found = true;
            }
        }
    }
    
    return found;
}

- (BOOL)disconnectMasternode:(UInt128)ip port:(uint16_t)port {
    return [self forPeer:ip port:port warn:YES withPredicate:^BOOL(DSPeer *peer) {
        DSLog(@"[OBJ-C] CoinJoin: masternode[closing] %@", [self hostFor:ip]);
        
        @synchronized (self.pendingClosingMasternodes) {
            [self.pendingClosingMasternodes addObject:peer];
            // TODO (dashj): what if this disconnects the wrong one
            [self updateMaxConnections];
        }
        
        [peer disconnect];
        
        return true;
    }];
}

- (BOOL)forPeer:(UInt128)ip port:(uint16_t)port warn:(BOOL)warn withPredicate:(BOOL (^)(DSPeer *peer))predicate {
    NSMutableString *listOfPeers = [NSMutableString string];
    
    for (DSPeer *peer in self.connectedPeers) {
        [listOfPeers appendFormat:@"%@, ", peer.location];
            
        if (uint128_eq(peer.address, ip) && peer.port == port) {
            return predicate(peer);
        }
    }
    
    if (warn) {
        if (![self isNodePending:ip port:port]) {
            DSLog(@"[OBJ-C] CoinJoin: Cannot find %@ in the list of connected peers: %@", [self hostFor:ip], listOfPeers);
            NSAssert(NO, @"Cannot find %@", [self hostFor:ip]);
        } else {
            DSLog(@"[OBJ-C] CoinJoin: %@ in the list of pending peers: %@", [self hostFor:ip], listOfPeers);
        }
    }
    
    return NO;
}

- (BOOL)isNodePending:(UInt128)ip port:(uint16_t)port {
    for (DSPeer *peer in self.pendingPeers) {
        if (uint128_eq(peer.address, ip) && peer.port == port) {
            return true;
        }
    }
    
    return false;
}

- (NSSet *)connectedPeers {
    @synchronized(self.mutableConnectedPeers) {
        return [self.mutableConnectedPeers copy];
    }
}

- (NSSet *)pendingPeers {
    @synchronized(self.mutablePendingPeers) {
        return [self.mutablePendingPeers copy];
    }
}

- (void)triggerConnections {
    [self triggerConnectionsJobWithDelay:0];
}

- (void)triggerConnectionsJobWithDelay:(NSTimeInterval)delay {
    dispatch_time_t delayTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC));
    dispatch_after(delayTime, self.networkingQueue, ^{
        if (!self.isRunning) {
            return;
        }
        
        if (!self.coinJoinManager.isChainSynced || self.coinJoinManager.isWaitingForNewBlock || !self.coinJoinManager.isMixing) {
            return;
        }
        
        BOOL doDiscovery = NO;
        NSDate *now = [NSDate date];
        
        @synchronized (self.inactives) {
            BOOL havPeersToTry = self.inactives.count > 0 && [self.backoffMap objectForKey:self.inactives[0].location].retryTime <= now;
            doDiscovery = !havPeersToTry;
            NSUInteger numPeers = self.mutablePendingPeers.count + self.connectedPeers.count;
            DSPeer *peerToTry = nil;
            NSDate *retryTime = nil;
            
            if (doDiscovery) {
                NSArray<DSPeer *> *peers = [self getPeers];
                
                for (DSPeer *peer in [self getPeers]) {
                    [self addInactive:peer];
                }
                
                BOOL discoverySuccess = peers.count > 0;
                // Require that we have enough connections, to consider this
                // a success, or we just constantly test for new peers
                if (discoverySuccess && numPeers >= self.maxConnections) {
                    [self.groupBackoff trackSuccess];
                } else {
                    [self.groupBackoff trackFailure];
                }
            }
            
            // Inactives is sorted by backoffMap time.
            if (self.inactives.count == 0) {
                if (numPeers < self.maxConnections) {
                    NSTimeInterval interval = MAX([self.groupBackoff.retryTime timeIntervalSinceDate:now], MIN_PEER_DISCOVERY_INTERVAL);
                    
                    DSLog(@"[OBJ-C] CoinJoin: Masternode discovery didn't provide us any more masternodes, will try again in %fl ms.", interval);
                    
                    [self triggerConnectionsJobWithDelay:interval];
                } else {
                    // We have enough peers and discovery provided no more, so just settle down. Most likely we
                    // were given a fixed set of addresses in some test scenario.
                }
                return;
            } else {
                peerToTry = self.inactives.firstObject;
                [self.inactives removeObjectAtIndex:0];
                retryTime = [self.backoffMap objectForKey:peerToTry.location].retryTime;
            }
            
            retryTime = [retryTime laterDate:self.groupBackoff.retryTime];
            NSTimeInterval delay = [retryTime timeIntervalSinceDate:now];
            
            if (delay > 0) {
                DSLog(@"[OBJ-C] CoinJoin: Waiting %fl s before next connect attempt to masternode to %@", delay, peerToTry == NULL ? @"" : peerToTry.location);
                [self.inactives addObject:peerToTry];
                [self triggerConnectionsJobWithDelay:delay];
                return;
            }
            
            [self connectTo:peerToTry incrementMaxConnections:false];
        }
        
        NSUInteger count = self.mutablePendingPeers.count + self.connectedPeers.count;
        
        if (count < self.maxConnections) {
            [self triggerConnectionsJobWithDelay:0]; // Try next peer immediately.
        }
    });
}

- (NSArray<DSPeer *> *)getPeers {
    NSMutableArray<DSPeer *> *addresses = [NSMutableArray array];
    
   @synchronized(self.addressMap) {
        for (NSValue *sessionValue in self.pendingSessions) {
            UInt256 sessionId;
            [sessionValue getValue:&sessionId];
            DSSimplifiedMasternodeEntry *mixingMasternodeInfo = [self mixingMasternodeAddressFor:sessionId];
               
            if (mixingMasternodeInfo) {
                UInt128 ipAddress = mixingMasternodeInfo.address;
                uint16_t port = mixingMasternodeInfo.port;
                DSPeer *peer = [self.chain.chainManager.peerManager peerForLocation:ipAddress port:port];
                
                if (![self.pendingClosingMasternodes containsObject:peer]) {
                    [addresses addObject:peer];
                    [self.addressMap setObject:sessionValue forKey:peer.location];
                    DSLog(@"[OBJ-C] CoinJoin: discovery: %@ -> %@", peer.location, uint256_hex(sessionId));
                }
            } else {
                DSLog(@"[OBJ-C] CoinJoin: mixingMasternodeInfo is nil");
            }
       }
    }
                 
    return [addresses copy];
}

- (DSSimplifiedMasternodeEntry *)mixingMasternodeAddressFor:(UInt256)sessionId {
    for (NSValue* key in self.masternodeMap) {
        NSValue *object = [self.masternodeMap objectForKey:key];
        UInt256 currentId = UINT256_ZERO;
        [object getValue:&currentId];
        
        if (uint256_eq(sessionId, currentId)) {
            UInt256 proTxHash = UINT256_ZERO;
            [key getValue:&proTxHash];
            
            return [self.coinJoinManager masternodeEntryByHash:proTxHash];
        }
    }
    
    return nil;
}

- (BOOL)addPendingMasternode:(UInt256)proTxHash clientSessionId:(UInt256)sessionId {
    @synchronized (_pendingSessions) {
        DSLog(@"[OBJ-C] CoinJoin: adding masternode for mixing. maxConnections = %lu, protx: %@", (unsigned long)_maxConnections, uint256_hex(proTxHash));
        NSValue *sessionIdValue = [NSValue valueWithBytes:&sessionId objCType:@encode(UInt256)];
        [_pendingSessions addObject:sessionIdValue];
        
        NSValue *proTxHashKey = [NSValue value:&proTxHash withObjCType:@encode(UInt256)];
        [_masternodeMap setObject:sessionIdValue forKey:proTxHashKey];
        
        [self updateMaxConnections];
        [self checkMasternodesWithoutSessions];
    }
    
    return true;
}

- (void)updateMaxConnections {
    _maxConnections = _pendingSessions.count;
    NSUInteger connections = MIN(_maxConnections, DEFAULT_COINJOIN_SESSIONS);
    DSLog(@"[OBJ-C] CoinJoin: updating max connections to min(%lu, %lu)", (unsigned long)_maxConnections,  (unsigned long)connections);
    
    [self updateMaxConnections:connections];
}

- (void)updateMaxConnections:(NSUInteger)connections {
    _maxConnections = connections;
    
    if (!self.isRunning) {
        return;
    }
    
    // We may now have too many or too few open connections. Add more or drop some to get to the right amount.
    NSUInteger adjustment = 0;
    NSSet *connectedPeers = self.connectedPeers;
    
    @synchronized (self.mutablePendingPeers) {
        NSUInteger numPeers = _mutablePendingPeers.count + connectedPeers.count;
        adjustment = _maxConnections - numPeers;
    }
    
    if (adjustment > 0) {
        [self triggerConnections];
    }

    if (adjustment < 0) {
        for (DSPeer *peer in connectedPeers) {
            [peer disconnect];
            adjustment++;
            
            if (adjustment >= 0) {
                break;
            }
        }
    }
}

- (void)checkMasternodesWithoutSessions {
    NSMutableArray *masternodesToDrop = [NSMutableArray array];
    
    for (DSPeer *peer in self.connectedPeers) {
        BOOL found = false;
            
        for (NSValue *value in _pendingSessions) {
            UInt256 sessionId;
            [value getValue:&sessionId];
            DSSimplifiedMasternodeEntry *mixingMasternodeAddress = [self mixingMasternodeAddressFor:sessionId];
                
            if (mixingMasternodeAddress) {
                UInt128 ipAddress = mixingMasternodeAddress.address;
                uint16_t port = mixingMasternodeAddress.port;
                    
                if (uint128_eq(ipAddress, peer.address) && port == peer.port) {
                    found = YES;
                }
            } else {
                // TODO(DashJ): we may not need this anymore
                DSLog(@"[OBJ-C] CoinJoin: session is not connected to a masternode: %@", uint256_hex(sessionId));
            }
        }
            
        if (!found) {
            DSLog(@"[OBJ-C] CoinJoin: masternode is not connected to a session: %@", peer.location);
            [masternodesToDrop addObject:peer];
        }
    }
    
    DSLog(@"[OBJ-C] CoinJoin: need to drop %lu masternodes", (unsigned long)masternodesToDrop.count);
    
    for (DSPeer *peer in masternodesToDrop) {
        DSSimplifiedMasternodeEntry *mn = [_chain.chainManager.masternodeManager masternodeAtLocation:peer.address port:peer.port];
        //pendingSessions.remove(mn.getProTxHash()); TODO: recheck (commented in DashJ)
        DSLog(@"[OBJ-C] CoinJoin: masternode will be disconnected: %@: %@", peer.location, uint256_hex(mn.providerRegistrationTransactionHash));
        [peer disconnect];
    }
}

- (NSString *)hostFor:(UInt128)address {
    char s[INET6_ADDRSTRLEN];

    if (address.u64[0] == 0 && address.u32[2] == CFSwapInt32HostToBig(0xffff)) {
        return @(inet_ntop(AF_INET, &address.u32[3], s, sizeof(s)));
    } else
        return @(inet_ntop(AF_INET6, &address, s, sizeof(s)));
}

- (BOOL)connectTo:(DSPeer *)peer incrementMaxConnections:(BOOL)increment {
    DSLog(@"[OBJ-C] CoinJoin: connectTo: %@", peer.location);
    
    if (![self isMasternodeSessionByPeer:peer]) {
        DSLog(@"[OBJ-C] CoinJoin: %@ not a masternode session, exit", peer.location);
        return NO;
    }
    
    if ([self isNodeConnected:peer] || [self isNodePending:peer]) {
        DSLog(@"[OBJ-C] CoinJoin: attempting to connect to the same masternode again: %@", peer.location);
        return NO; // do not connect to the same peer again
    }
    
    DSSimplifiedMasternodeEntry *mn = [_chain.chainManager.masternodeManager masternodeAtLocation:peer.address port:peer.port];
    UInt256 sessionId = UINT256_ZERO;
    
    @synchronized (_masternodeMap) {
        UInt256 proTxHash = mn.providerRegistrationTransactionHash;
        NSValue *proTxHashKey = [NSValue value:&proTxHash withObjCType:@encode(UInt256)];
        NSValue *keyObject = [_masternodeMap objectForKey:proTxHashKey];
        
        if (keyObject) {
            [keyObject getValue:&sessionId];
        }
    }
    
    if (uint256_is_zero(sessionId)) {
        DSLog(@"[OBJ-C] CoinJoin: session is not connected to a masternode, proTxHashKey not found in masternodeMap");
        return NO;
    }
    
    DSSimplifiedMasternodeEntry *mixingMasternodeAddress = [self mixingMasternodeAddressFor:sessionId];
    
    if (!mixingMasternodeAddress) {
        DSLog(@"[OBJ-C] CoinJoin: session is not connected to a masternode, sessionId: %@", uint256_hex(sessionId));
        return NO;
    }
    
    DSLog(@"[OBJ-C] CoinJoin: masternode[connecting] %@: %@; %@", peer.location, uint256_hex(mn.providerRegistrationTransactionHash), uint256_hex(sessionId));
    
    [peer setChainDelegate:self.chain.chainManager peerDelegate:self transactionDelegate:self.chain.chainManager.transactionManager governanceDelegate:self.chain.chainManager.governanceSyncManager sporkDelegate:self.chain.chainManager.sporkManager masternodeDelegate:self.chain.chainManager.masternodeManager queue:self.networkingQueue];
    peer.earliestKeyTime = self.chain.earliestWalletCreationTime;;

    @synchronized (self.mutablePendingPeers) {
        [self.mutablePendingPeers addObject:peer];
    }
    
    DSLog(@"[OBJ-C] CoinJoin: calling peer.connect to %@", peer.location);
    [peer connect];
    
    return YES;
}

- (BOOL)isMasternodeSessionByPeer:(DSPeer *)peer {
    @synchronized (_addressMap) {
        return [_addressMap objectForKey:peer.location] != nil;
    }
}

- (BOOL)isNodeConnected:(DSPeer *)node {
    return [self forPeer:node.address port:node.port warn:false withPredicate:^BOOL(DSPeer * _Nonnull peer) {
        return YES;
    }];
}

- (BOOL)isNodePending:(DSPeer *)node {
    @synchronized (self) {
        for (DSPeer *peer in self.mutablePendingPeers) {
            if (uint128_eq(node.address, peer.address) && node.port == peer.port) {
                return YES;
            }
        }
    }
    
    return NO;
}

- (void)peerConnected:(nonnull DSPeer *)peer {
    @synchronized (self) {
        [_groupBackoff trackSuccess];
        [[_backoffMap objectForKey:peer.location] trackSuccess];
        
        DSLog(@"[OBJ-C] CoinJoin: New peer %@ ({%lu connected, %lu pending, %lu max)", peer.location, _mutableConnectedPeers.count, _mutablePendingPeers.count, _maxConnections);
        
        [_mutablePendingPeers removeObject:peer];
        [_mutableConnectedPeers addObject:peer];
    }
    
    if (_shouldSendDsq) {
        [peer sendRequest:[DSSendCoinJoinQueue requestWithShouldSend:true]];
    }
}

- (void)peer:(nonnull DSPeer *)peer disconnectedWithError:(nonnull NSError *)error {
    @synchronized (self) {
        [_mutablePendingPeers removeObject:peer];
        [_mutableConnectedPeers removeObject:peer];
        
        DSLog(@"[OBJ-C] CoinJoin: Peer died: %@ (%lu connected, %lu pending, %lu max)", peer.location, (unsigned long)_mutableConnectedPeers.count, (unsigned long)_mutablePendingPeers.count, (unsigned long)_maxConnections);
        
        [_groupBackoff trackFailure];
        [[_backoffMap objectForKey:peer.location] trackFailure];
        // Put back on inactive list
        [self addInactive:peer];
        NSUInteger numPeers = _mutablePendingPeers.count + _mutableConnectedPeers.count;
        
        if (numPeers < _maxConnections) {
            [self triggerConnections];
        }
    }
     
    @synchronized (_pendingSessions) {
        DSPeer *masternode = NULL;
        
        for (DSPeer *mn in _pendingClosingMasternodes) {
            if ([peer.location isEqualToString:mn.location]) {
                masternode = mn;
            }
        }
        
        DSLog(@"[OBJ-C] CoinJoin: handling this mn peer death: %@ -> %@", peer.location, masternode != NULL ? masternode.location : @"not found in closing list");
        
        if (masternode) {
            NSString *address = peer.location;
            
            if ([_pendingClosingMasternodes containsObject:masternode]) {
                // if this is part of pendingClosingMasternodes, where we want to close the connection,
                // we don't want to increase the backoff time
                [[_backoffMap objectForKey:address] trackSuccess];
            }
            
            [_pendingClosingMasternodes removeObject:masternode];
            UInt256 sessionId = [_chain.chainManager.masternodeManager masternodeAtLocation:masternode.address port:masternode.port].providerRegistrationTransactionHash;
            NSValue *sessionIdValue = [NSValue valueWithBytes:&sessionId objCType:@encode(UInt256)];
            [_pendingSessions removeObject:sessionIdValue];
            [_masternodeMap removeObjectForKey:sessionIdValue];
            [_addressMap removeObjectForKey:masternode.location];
        }
        
        [self checkMasternodesWithoutSessions];
    }
}

- (void)peer:(nonnull DSPeer *)peer relayedPeers:(nonnull NSArray *)peers {
    // TODO ?
}

- (void)addInactive:(DSPeer *)peer {
    @synchronized (_inactives) {
        // Deduplicate, handle differently than PeerGroup
        if ([self.inactives containsObject:peer]) {
            return;
        }
                
        // do not connect to another the same peer twice
        if ([self isNodeConnected:peer]) {
            DSLog(@"[OBJ-C] CoinJoin: attempting to connect to the same masternode again: %@", peer.location);
            return;
        }
        
        DSBackoff *backoff = [[DSBackoff alloc] initInitialBackoff:DEFAULT_INITIAL_BACKOFF maxBackoff:DEFAULT_MAX_BACKOFF multiplier:GROUP_BACKOFF_MULTIPLIER];
        [self.backoffMap setObject:backoff forKey:peer.location];
        [self.inactives addObject:peer];
        [self sortInactives];
    }
}

- (void)sortInactives {
    [_inactives sortUsingComparator:^NSComparisonResult(DSPeer *obj1, DSPeer *obj2) {
        DSBackoff *backoff1 = [_backoffMap objectForKey:obj1.location];
        DSBackoff *backoff2 = [_backoffMap objectForKey:obj2.location];
        return [backoff1.retryTime compare:backoff2.retryTime];
    }];
}

@end
