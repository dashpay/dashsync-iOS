//
//  DSSporkManager.m
//  DashSync
//
//  Created by Sam Westrich on 10/18/17.
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

#import "DSSporkManager.h"
#import "DSChain+Protected.h"
#import "DSChainEntity+CoreDataProperties.h"
#import "DSChainManager+Protected.h"
#import "DSMerkleBlock.h"
#import "DSOptionsManager.h"
#import "DSPeerManager+Protected.h"
#import "DSSpork.h"
#import "DSSporkEntity+CoreDataProperties.h"
#import "DSSporkHashEntity+CoreDataProperties.h"
#import "NSData+Dash.h"
#import "NSDate+Utils.h"
#import "NSManagedObject+Sugar.h"

#define SPORK_15_MIN_PROTOCOL_VERSION 70213

@interface DSSporkManager ()

@property (nonatomic, strong) NSMutableDictionary<NSNumber *, DSSpork *> *mSporkDictionary;
@property (nonatomic, strong) NSMutableArray *sporkHashesMarkedForRetrieval;
@property (nonatomic, strong) DSChain *chain;
@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, assign) NSTimeInterval lastRequestedSporks;
@property (nonatomic, assign) NSTimeInterval lastSyncedSporks;
@property (nonatomic, strong) NSTimer *sporkTimer;

@end

@implementation DSSporkManager

- (instancetype)initWithChain:(DSChain *)chain {
    NSParameterAssert(chain);

    if (!(self = [super init])) return nil;
    _chain = chain;
    __block NSMutableArray *sporkHashesMarkedForRetrieval = [NSMutableArray array];
    __block NSMutableDictionary *sporkDictionary = [NSMutableDictionary dictionary];
    self.lastRequestedSporks = 0;
    self.lastSyncedSporks = 0;
    self.managedObjectContext = [NSManagedObjectContext chainContext];
    [self.managedObjectContext performBlockAndWait:^{
        DSChainEntity *chainEntity = [self.chain chainEntityInContext:self.managedObjectContext];
        NSArray *sporkEntities = [DSSporkEntity sporksonChainEntity:chainEntity];
        for (DSSporkEntity *sporkEntity in sporkEntities) {
            DSSpork *spork = [[DSSpork alloc] initWithIdentifier:sporkEntity.identifier value:sporkEntity.value timeSigned:sporkEntity.timeSigned signature:sporkEntity.signature onChain:chain];
            sporkDictionary[@(spork.identifier)] = spork;
        }
        NSArray *sporkHashEntities = [DSSporkHashEntity standaloneSporkHashEntitiesOnChainEntity:chainEntity];
        for (DSSporkHashEntity *sporkHashEntity in sporkHashEntities) {
            [sporkHashesMarkedForRetrieval addObject:sporkHashEntity.sporkHash];
        }
    }];
    self.mSporkDictionary = [sporkDictionary mutableCopy];
    _sporkHashesMarkedForRetrieval = sporkHashesMarkedForRetrieval;
    [self checkTriggers];
    return self;
}

- (DSPeerManager *)peerManager {
    return self.chain.chainManager.peerManager;
}

- (BOOL)instantSendActive {
    DSSpork *instantSendSpork = self.sporkDictionary[@(DSSporkIdentifier_Spork2InstantSendEnabled)];
    if (!instantSendSpork) return TRUE; //assume true
    return instantSendSpork.value <= self.chain.lastTerminalBlockHeight;
}

- (BOOL)sporksUpdatedSignatures {
    DSSpork *updateSignatureSpork = self.sporkDictionary[@(DSSporkIdentifier_Spork6NewSigs)];
    if (!updateSignatureSpork) return FALSE; //assume false
    return updateSignatureSpork.value <= self.chain.lastTerminalBlockHeight;
}

- (BOOL)deterministicMasternodeListEnabled {
    DSSpork *dmlSpork = self.sporkDictionary[@(DSSporkIdentifier_Spork15DeterministicMasternodesEnabled)];
    if (!dmlSpork) return TRUE; //assume true
    return dmlSpork.value <= self.chain.lastTerminalBlockHeight;
}

- (BOOL)llmqInstantSendEnabled {
    DSSpork *llmqSpork = self.sporkDictionary[@(DSSporkIdentifier_Spork20InstantSendLLMQBased)];
    if (!llmqSpork) return TRUE; //assume true
    return llmqSpork.value <= self.chain.lastTerminalBlockHeight;
}

- (BOOL)quorumDKGEnabled {
    DSSpork *dkgSpork = self.sporkDictionary[@(DSSporkIdentifier_Spork17QuorumDKGEnabled)];
    if (!dkgSpork) return TRUE; //assume true
    return dkgSpork.value <= self.chain.lastTerminalBlockHeight;
}

- (BOOL)chainLocksEnabled {
    DSSpork *chainLockSpork = self.sporkDictionary[@(DSSporkIdentifier_Spork19ChainLocksEnabled)];
    if (!chainLockSpork) return TRUE; //assume true
    return chainLockSpork.value <= self.chain.lastTerminalBlockHeight;
}

- (NSDictionary *)sporkDictionary {
    return [_mSporkDictionary copy];
}

// MARK: - Spork Sync

- (void)performSporkRequest {
    for (DSPeer *p in self.peerManager.connectedPeers) { // after syncing, get sporks from other peers
        if (p.status != DSPeerStatus_Connected) continue;

        [p sendPingMessageWithPongHandler:^(BOOL success) {
            if (success) {
                self.lastRequestedSporks = [NSDate timeIntervalSince1970];
                [p sendGetSporks];
            }
        }];
    }
}

- (void)getSporks {
    if (!([[DSOptionsManager sharedInstance] syncType] & DSSyncType_Sporks)) return; // make sure we care about sporks

    if (!self.sporkTimer) {
        [self performSporkRequest];
        self.sporkTimer = [NSTimer scheduledTimerWithTimeInterval:600
                                                          repeats:TRUE
                                                            block:^(NSTimer *_Nonnull timer) {
                                                                if (self.lastSyncedSporks < [NSDate timeIntervalSince1970] - 60 * 10) { //wait 10 minutes between requests
                                                                    [self performSporkRequest];
                                                                }
                                                            }];
    }
}

- (void)stopGettingSporks {
    [self.sporkTimer invalidate];
    self.sporkTimer = nil;
}

- (void)peer:(DSPeer *_Nonnull)peer hasSporkHashes:(NSSet *_Nonnull)sporkHashes {
    BOOL hasNew = FALSE;
    for (NSData *sporkHash in sporkHashes) {
        if (![_sporkHashesMarkedForRetrieval containsObject:sporkHash]) {
            [_sporkHashesMarkedForRetrieval addObject:sporkHash];
            hasNew = TRUE;
        }
    }
    if (hasNew) [self getSporks];
}

- (void)peer:(DSPeer *)peer relayedSpork:(DSSpork *)spork {
    if (!spork.isValid) {
        [self.peerManager peerMisbehaving:peer errorMessage:@"Spork is not valid"];
        return;
    }
    self.lastSyncedSporks = [NSDate timeIntervalSince1970];
    DSSpork *currentSpork = self.sporkDictionary[@(spork.identifier)];
    BOOL updatedSpork = FALSE;
    __block NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];
    if (currentSpork) {
        //there was already a spork
        if (![currentSpork isEqualToSpork:spork]) {
            [self setSporkValue:spork forKeyIdentifier:spork.identifier]; //set it to new one
            updatedSpork = TRUE;
            [dictionary setObject:currentSpork forKey:@"old"];
        } else {
            //lets check triggers anyways in case of an update of trigger code
            [self checkTriggersForSpork:spork forKeyIdentifier:spork.identifier];
            return;
        }
    } else {
        [self setSporkValue:spork forKeyIdentifier:spork.identifier];
    }
    [dictionary setObject:spork
                   forKey:@"new"];
    [dictionary setObject:self.chain forKey:DSChainManagerNotificationChainKey];
    if (!currentSpork || updatedSpork) {
        [self.managedObjectContext performBlockAndWait:^{
            @autoreleasepool {
                DSSporkHashEntity *hashEntity = [DSSporkHashEntity sporkHashEntityWithHash:[NSData dataWithUInt256:spork.sporkHash] onChainEntity:[spork.chain chainEntityInContext:self.managedObjectContext]];
                if (hashEntity) {
                    DSSporkEntity *sporkEntity = hashEntity.spork;
                    if (!sporkEntity) {
                        sporkEntity = [DSSporkEntity managedObjectInBlockedContext:self.managedObjectContext];
                    }
                    [sporkEntity setAttributesFromSpork:spork
                                          withSporkHash:hashEntity]; // add new peers
                    [self.managedObjectContext ds_save];
                } else {
                    DSLog(@"Spork was received that wasn't requested");
                }
            }
        }];
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSSporkListDidUpdateNotification object:nil userInfo:dictionary];
        });
    }
}

- (void)checkTriggers {
    for (NSNumber *key in _mSporkDictionary) {
        DSSpork *spork = _mSporkDictionary[key];
        [self checkTriggersForSpork:spork forKeyIdentifier:spork.identifier];
    }
}

- (void)checkTriggersForSpork:(DSSpork *)spork forKeyIdentifier:(DSSporkIdentifier)sporkIdentifier {
    BOOL changed = FALSE; //some triggers will require a change, others have different requirements
    if (![_mSporkDictionary objectForKey:@(sporkIdentifier)] || ([_mSporkDictionary objectForKey:@(sporkIdentifier)] && (_mSporkDictionary[@(sporkIdentifier)].value != spork.value))) {
        changed = TRUE;
    }
    switch (sporkIdentifier) {
        case DSSporkIdentifier_Spork15DeterministicMasternodesEnabled: {
            if (!self.chain.isDevnetAny && self.chain.estimatedBlockHeight >= spork.value && self.chain.minProtocolVersion < SPORK_15_MIN_PROTOCOL_VERSION) { //use estimated block height here instead
                [self.chain setMinProtocolVersion:SPORK_15_MIN_PROTOCOL_VERSION];
            }
        } break;

        default:
            break;
    }
}

- (void)setSporkValue:(DSSpork *)spork forKeyIdentifier:(DSSporkIdentifier)sporkIdentifier {
    @synchronized(self) {
        [self checkTriggersForSpork:spork forKeyIdentifier:sporkIdentifier];
        _mSporkDictionary[@(sporkIdentifier)] = spork;
    }
}


- (void)wipeSporkInfo {
    @synchronized(self) {
        _mSporkDictionary = [NSMutableDictionary dictionary];
        [self stopGettingSporks];
    }
}

@end
