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
#import "DSSpork.h"
#import "DSSporkHashEntity+CoreDataProperties.h"
#import "DSSporkEntity+CoreDataProperties.h"
#import "NSManagedObject+Sugar.h"
#import "DSChain.h"
#import "DSChainEntity+CoreDataProperties.h"
#import "DSPeerManager+Protected.h"
#import "DSOptionsManager.h"
#import "DSChainManager+Protected.h"
#import "DSMerkleBlock.h"

#define SPORK_15_MIN_PROTOCOL_VERSION 70213

@interface DSSporkManager()
    
@property (nonatomic,strong) NSMutableDictionary <NSNumber*,DSSpork*> * sporkDictionary;
@property (nonatomic,strong) NSMutableArray * sporkHashesMarkedForRetrieval;
@property (nonatomic,strong) DSChain * chain;
@property (nonatomic,strong) NSManagedObjectContext * managedObjectContext;
    
@end

@implementation DSSporkManager

- (instancetype)initWithChain:(id)chain
{
    if (! (self = [super init])) return nil;
    _chain = chain;
    __block NSMutableArray * sporkHashesMarkedForRetrieval = [NSMutableArray array];
    __block NSMutableDictionary * sporkDictionary = [NSMutableDictionary dictionary];
    self.managedObjectContext = [NSManagedObject context];
    [self.managedObjectContext performBlockAndWait:^{
        [DSChainEntity setContext:self.managedObjectContext];
        DSChainEntity * chainEntity = self.chain.chainEntity;
        NSArray * sporkEntities = [DSSporkEntity sporksOnChain:chainEntity];
        for (DSSporkEntity * sporkEntity in sporkEntities) {
            DSSpork * spork = [[DSSpork alloc] initWithIdentifier:sporkEntity.identifier value:sporkEntity.value timeSigned:sporkEntity.timeSigned signature:sporkEntity.signature onChain:chain];
            sporkDictionary[@(spork.identifier)] = spork;
        }
        NSArray * sporkHashEntities = [DSSporkHashEntity standaloneSporkHashEntitiesOnChain:chainEntity];
        for (DSSporkHashEntity * sporkHashEntity in sporkHashEntities) {
            [sporkHashesMarkedForRetrieval addObject:sporkHashEntity.sporkHash];
        }
    }];
    _sporkDictionary = sporkDictionary;
    _sporkHashesMarkedForRetrieval = sporkHashesMarkedForRetrieval;
    [self checkTriggers];
    return self;
}

-(DSPeerManager*)peerManager {
    return self.chain.chainManager.peerManager;
}
    
-(BOOL)instantSendActive {
    DSSpork * instantSendSpork = self.sporkDictionary[@(DSSporkIdentifier_Spork2InstantSendEnabled)];
    if (!instantSendSpork) return TRUE;//assume true
    return instantSendSpork.value <= self.chain.lastBlockHeight;
}

-(BOOL)instantSendAutoLocks {
    DSSpork * instantSendSpork = self.sporkDictionary[@(DSSporkIdentifier_Spork16InstantSendAutoLocks)];
    if (!instantSendSpork) return FALSE;//assume false
    return instantSendSpork.value <= self.chain.lastBlockHeight;
}

-(BOOL)sporksUpdatedSignatures {
    DSSpork * updateSignatureSpork = self.sporkDictionary[@(DSSporkIdentifier_Spork6NewSigs)];
    if (!updateSignatureSpork) return FALSE;//assume false
    return updateSignatureSpork.value <= self.chain.lastBlockHeight;
}

-(BOOL)deterministicMasternodeListEnabled {
    DSSpork * dmlSpork = self.sporkDictionary[@(DSSporkIdentifier_Spork15DeterministicMasternodesEnabled)];
    if (!dmlSpork) return FALSE;//assume false
    return dmlSpork.value <= self.chain.lastBlockHeight;
}



-(NSDictionary*)sporkDictionary {
    return [_sporkDictionary copy];
}

// MARK: - Spork Sync

-(void)getSporks {
    if (!([[DSOptionsManager sharedInstance] syncType] & DSSyncType_Sporks)) return; // make sure we care about sporks
    for (DSPeer *p in self.peerManager.connectedPeers) { // after syncing, get sporks from other peers
        if (p.status != DSPeerStatus_Connected) continue;
        
        [p sendPingMessageWithPongHandler:^(BOOL success) {
            if (success) {
                [p sendGetSporks];
            }
        }];
    }
}


- (void)peer:(DSPeer * _Nonnull)peer hasSporkHashes:(NSSet* _Nonnull)sporkHashes {
    BOOL hasNew = FALSE;
    for (NSData * sporkHash in sporkHashes) {
        if (![_sporkHashesMarkedForRetrieval containsObject:sporkHash]) {
            [_sporkHashesMarkedForRetrieval addObject:sporkHash];
            hasNew = TRUE;
        }
    }
    if (hasNew) [self getSporks];
}
    
- (void)peer:(DSPeer *)peer relayedSpork:(DSSpork *)spork {
    if (!spork.isValid) {
        [self.peerManager peerMisbehaving:peer];
        return;
    }
    DSSpork * currentSpork = self.sporkDictionary[@(spork.identifier)];
    BOOL updatedSpork = FALSE;
    __block NSMutableDictionary * dictionary = [[NSMutableDictionary alloc] init];
    if (currentSpork) {
        //there was already a spork
        if (![currentSpork isEqualToSpork:spork]) {
            [self setSporkValue:spork forKeyIdentifier:spork.identifier]; //set it to new one
            updatedSpork = TRUE;
            [dictionary setObject:currentSpork forKey:@"old"];
        } else {
            return; //nothing more to do
        }
    } else {
        [self setSporkValue:spork forKeyIdentifier:spork.identifier];
    }
    [dictionary setObject:spork forKey:@"new"];
    [dictionary setObject:self.chain forKey:DSChainManagerNotificationChainKey];
    if (!currentSpork || updatedSpork) {
        dispatch_async(dispatch_get_main_queue(), ^{
            @autoreleasepool {
                [[DSSporkEntity managedObject] setAttributesFromSpork:spork]; // add new peers
                [DSSporkEntity saveContext];
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:DSSporkListDidUpdateNotification object:nil userInfo:dictionary];
        });
    }
}

-(void)checkTriggers {
    for (NSNumber * key in _sporkDictionary) {
        DSSpork * spork = _sporkDictionary[key];
        [self checkTriggersForSpork:spork forKeyIdentifier:spork.identifier];
    }
}

-(void)checkTriggersForSpork:(DSSpork*)spork forKeyIdentifier:(DSSporkIdentifier)sporkIdentifier {
    if (![_sporkDictionary objectForKey:@(sporkIdentifier)] || ([_sporkDictionary objectForKey:@(sporkIdentifier)] && (_sporkDictionary[@(sporkIdentifier)].value != spork.value))) {
        switch (sporkIdentifier) {
            case DSSporkIdentifier_Spork15DeterministicMasternodesEnabled:
            {
                if (self.chain.lastBlock.height >= spork.value && self.chain.minProtocolVersion < SPORK_15_MIN_PROTOCOL_VERSION) {
                    [self.chain setMinProtocolVersion:SPORK_15_MIN_PROTOCOL_VERSION];
                }
            }
            break;
            
            default:
            break;
        }
    }
}

-(void)setSporkValue:(DSSpork*)spork forKeyIdentifier:(DSSporkIdentifier)sporkIdentifier {
    [self checkTriggersForSpork:spork forKeyIdentifier:sporkIdentifier];
    _sporkDictionary[@(sporkIdentifier)] = spork;
}


-(void)wipeSporkInfo {
    _sporkDictionary = [NSMutableDictionary dictionary];
}
    
@end
