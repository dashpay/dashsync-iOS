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
#import <arpa/inet.h>

uint64_t const MIN_PEER_DISCOVERY_INTERVAL = 1000;

@implementation DSMasternodeGroup

- (instancetype)initWithManager:(DSCoinJoinManager *)manager {
    self = [super init];
    if (self) {
        _coinJoinManager = manager;
        _pendingSessions = [NSMutableSet set];
        _masternodeMap = [NSMutableDictionary dictionary];
        _addressMap = [NSMutableDictionary dictionary];
        _mutableConnectedPeers = [NSMutableSet set];
        _mutablePendingPeers = [NSMutableSet set];
    }
    return self;
}

- (void)startAsync {
    _isRunning = true;
}

- (dispatch_queue_t)networkingQueue {
    return self.chain.networkingQueue;
}

- (void)stopAsync {
    _isRunning = false;
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
        
        [self.lock lock];
        [self.pendingClosingMasternodes addObject:peer];
        // TODO (dashj): what if this disconnects the wrong one
        [self updateMaxConnections];
        [self.lock unlock];
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
    dispatch_async(self.networkingQueue, ^{
        if (!self.isRunning) {
            return;
        }
        
        if (self.coinJoinManager.isWaitingForNewBlock || self.coinJoinManager.isMixing) {
            return;
        }
        
        // TODO
    });
}

- (NSArray<DSPeer *> *)getPeers {
    NSMutableArray<DSPeer *> *addresses = [NSMutableArray array];
    
   @synchronized(_addressMap) {
        for (NSValue *sessionValue in _pendingSessions) {
            UInt256 sessionId;
            [sessionValue getValue:&sessionId];
            SocketAddress *mixingMasternodeInfo = [_coinJoinManager mixingMasternodeAddressFor:sessionId];
               
            if (mixingMasternodeInfo) {
                UInt128 ipAddress = *((UInt128 *)mixingMasternodeInfo->ip_address);
                uint16_t port = mixingMasternodeInfo->port;
                DSPeer *peer = [_chain.chainManager.peerManager peerForLocation:ipAddress port:port];
                
                if (![_pendingClosingMasternodes containsObject:peer]) {
                    [addresses addObject:peer];
                    [_addressMap setObject:sessionValue forKey:peer.location];
                    DSLog(@"[OBJ-C] CoinJoin: discovery: %@ -> %@", peer.location, uint256_hex(sessionId));
                }
                
                destroy_socket_address(mixingMasternodeInfo);
            }
       }
    }
                 
    return [addresses copy];
}

- (BOOL)addPendingMasternode:(UInt256)proTxHash clientSessionId:(UInt256)sessionId {
    @synchronized (self) {
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
    
    // TODO:
    // We may now have too many or too few open connections. Add more or drop some to get to the right amount.
//  adjustment = maxConnections - channels.getConnectedClientCount();
//  if (adjustment > 0)
//      triggerConnections();
//
//  if (adjustment < 0)
//      channels.closeConnections(-adjustment);
}

- (void)checkMasternodesWithoutSessions {
    NSMutableArray *masternodesToDrop = [NSMutableArray array];
    
    @synchronized (_pendingSessions) {
        for (DSPeer *peer in self.connectedPeers) {
            BOOL found = false;
            
            for (NSValue *value in _pendingSessions) {
                UInt256 sessionId;
                [value getValue:&sessionId];
                SocketAddress *mixingMasternodeAddress = [_coinJoinManager mixingMasternodeAddressFor:sessionId];
                
                if (mixingMasternodeAddress) {
                    UInt128 ipAddress = *((UInt128 *)mixingMasternodeAddress->ip_address);
                    uint16_t port = mixingMasternodeAddress->port;
                    
                    if (uint128_eq(ipAddress, peer.address) && port == peer.port) {
                        found = YES;
                    }
                    
                    destroy_socket_address(mixingMasternodeAddress);
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
    if (![self isMasternodeSessionByPeer:peer]) {
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
    
    SocketAddress *mixingMasternodeAddress = [_coinJoinManager mixingMasternodeAddressFor:sessionId];
    
    if (!mixingMasternodeAddress) {
        DSLog(@"[OBJ-C] CoinJoin: session is not connected to a masternode, sessionId: %@", uint256_hex(sessionId));
        return NO;
    }
    
    DSLog(@"[OBJ-C] CoinJoin: masternode[connecting] %@: %@; %@", peer.location, uint256_hex(mn.providerRegistrationTransactionHash), uint256_hex(sessionId));
    
    [peer setChainDelegate:self.chain.chainManager peerDelegate:self transactionDelegate:self.chain.chainManager.transactionManager governanceDelegate:self.chain.chainManager.governanceSyncManager sporkDelegate:self.chain.chainManager.sporkManager masternodeDelegate:self.chain.chainManager.masternodeManager queue:self.networkingQueue];
    peer.earliestKeyTime = self.chain.earliestWalletCreationTime;;

    [self.mutablePendingPeers addObject:peer];
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
    for (DSPeer *peer in self.mutablePendingPeers) {
        
        if (uint128_eq(node.address, peer.address) && node.port == peer.port) {
            return YES;
        }
    }
    
    return NO;
}

@synthesize downloadPeer;

- (void)peer:(nonnull DSPeer *)peer disconnectedWithError:(nonnull NSError *)error { 
    // TODO
}

- (void)peer:(nonnull DSPeer *)peer relayedPeers:(nonnull NSArray *)peers { 
    // TODO ?
}

- (void)peerConnected:(nonnull DSPeer *)peer { 
    // TODO
}

@end
