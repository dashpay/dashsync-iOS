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
#import <arpa/inet.h>

uint64_t const MIN_PEER_DISCOVERY_INTERVAL = 1000;

@implementation DSMasternodeGroup

- (instancetype)initWithManager:(DSCoinJoinManager *)manager {
    self = [super init];
    if (self) {
        _coinJoinManager = manager;
        _pendingSessions = [NSMutableSet set];
        _masternodeMap = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)startAsync {
    _isRunning = true;
    self.blocksObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:DSChainNewChainTipBlockNotification
                                                          object:nil
                                                           queue:nil
                                                      usingBlock:^(NSNotification *note) {
                                                          if ([note.userInfo[DSChainManagerNotificationChainKey] isEqual:[self chain]]) {
                                                              
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
    NSArray<DSPeer *> *peerList = [self getConnectedPeers];
    NSMutableString *listOfPeers = [NSMutableString string];
    
    for (DSPeer *peer in peerList) {
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
    NSArray<DSPeer *> *pendingPeers = [self getConnectedPeers];
    
    for (DSPeer *peer in pendingPeers) {
        if (uint128_eq(peer.address, ip) && peer.port == port) {
            return true;
        }
    }
    
    return false;
}

- (NSArray<DSPeer *> *)getConnectedPeers {
    // TODO:
    return @[];
}

- (NSArray<DSPeer *> *)getPendingPeers {
    // TODO:
    return @[];
}

- (void)triggerConnections {
    dispatch_async(self.networkingQueue, ^{
        if (!self.isRunning) {
            return;
        }
        
        if (self.coinJoinManager.isWaitingForNewBlock) {
            // TODO
        }
    });
}

- (BOOL)addPendingMasternode:(UInt256)proTxHash clientSessionId:(UInt256)sessionId {
    @synchronized (self) {
        DSLog(@"[OBJ-C] CoinJoin: adding masternode for mixing. maxConnections = %lu, protx: %@", (unsigned long)self.maxConnections, uint256_hex(proTxHash));
        NSValue *sessionIdValue = [NSValue valueWithBytes:&proTxHash objCType:@encode(UInt256)];
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
    NSUInteger connections = MIN(self.maxConnections, DEFAULT_COINJOIN_SESSIONS);
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
    // TODO:
}

- (NSString *)hostFor:(UInt128)address {
    char s[INET6_ADDRSTRLEN];

    if (address.u64[0] == 0 && address.u32[2] == CFSwapInt32HostToBig(0xffff)) {
        return @(inet_ntop(AF_INET, &address.u32[3], s, sizeof(s)));
    } else
        return @(inet_ntop(AF_INET6, &address, s, sizeof(s)));
}

@end
