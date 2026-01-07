//
//  DSGovernanceSyncManager.m
//  DashSync
//
//  Created by Sam Westrich on 6/12/18.
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

#import "DSGovernanceSyncManager.h"
#import "DSAccount.h"
#import "DSChain+Protected.h"
#import "DSChainEntity+CoreDataProperties.h"
#import "DSChainsManager.h"
#import "DSGetGovernanceObjectsRequest.h"
#import "DSGovernanceObject.h"
#import "DSGovernanceObjectEntity+CoreDataProperties.h"
#import "DSGovernanceObjectHashEntity+CoreDataProperties.h"
#import "DSGovernanceObjectsSyncRequest.h"
#import "DSGovernanceVote.h"
#import "DSGovernanceVoteEntity+CoreDataProperties.h"
#import "DSGovernanceVoteHashEntity+CoreDataProperties.h"
#import "DSGovernanceVotesSyncRequest.h"
#import "DSOptionsManager.h"
#import "DSPeer.h"
#import "DSPeerManager+Protected.h"
#import "DSSimplifiedMasternodeEntry.h"
#import "NSData+DSHash.h"
#import "NSManagedObject+Sugar.h"

#define REQUEST_GOVERNANCE_OBJECT_COUNT 500

@interface DSGovernanceSyncManager ()

@property (nonatomic, strong) DSChain *chain;

@property (nonatomic, strong) NSOrderedSet *knownGovernanceObjectHashes; //this doesn't care if the hash has an associated governance object already known
@property (nonatomic, strong) NSMutableOrderedSet<NSData *> *knownGovernanceObjectHashesForExistingGovernanceObjects;
@property (nonatomic, readonly) NSOrderedSet *fulfilledRequestsGovernanceObjectHashEntities;
@property (nonatomic, strong) NSMutableArray *requestGovernanceObjectHashEntities;
@property (nonatomic, strong) NSMutableArray<DSGovernanceObject *> *governanceObjects;
@property (nonatomic, strong) NSMutableArray<DSGovernanceObject *> *needVoteSyncGovernanceObjects;
@property (nonatomic, assign) NSUInteger governanceObjectsCount;

@property (nonatomic, strong) NSMutableDictionary<NSData *, DSGovernanceObject *> *publishGovernanceObjects;
@property (nonatomic, strong) NSMutableDictionary<NSData *, DSGovernanceVote *> *publishVotes;

@property (nonatomic, strong) DSGovernanceObject *currentGovernanceSyncObject;

@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;

@end

@implementation DSGovernanceSyncManager

- (instancetype)initWithChain:(id)chain {
    NSParameterAssert(chain);

    if (!(self = [super init])) return nil;
    _chain = chain;
    _governanceObjects = [NSMutableArray array];
    self.managedObjectContext = [NSManagedObjectContext chainContext];
    [self loadGovernanceObjects:0];
    self.publishVotes = [[NSMutableDictionary alloc] init];
    self.publishGovernanceObjects = [[NSMutableDictionary alloc] init];
    return self;
}

- (DSPeerManager *)peerManager {
    return self.chain.chainManager.peerManager;
}

// MARK: - Governance Sync

- (void)continueGovernanceSync {
    NSUInteger last3HoursStandaloneBroadcastHashesCount = [self last3HoursStandaloneGovernanceObjectHashesCount];
    if (last3HoursStandaloneBroadcastHashesCount) {
        DSPeer *downloadPeer = nil;

        //find download peer (ie the peer that we will ask for governance objects from
        for (DSPeer *peer in self.peerManager.connectedPeers) {
            if (peer.status != DSPeerStatus_Connected) continue;
            downloadPeer = peer;
            break;
        }

        if (downloadPeer) {
            downloadPeer.governanceRequestState = DSGovernanceRequestState_GovernanceObjects; //force this by bypassing normal route

            [self requestGovernanceObjectsFromPeer:downloadPeer];
        }
    } else {
        if (!([[DSOptionsManager sharedInstance] syncType] & DSSyncType_GovernanceVotes)) return; // make sure we care about Governance objects
        DSPeer *downloadPeer = nil;
        //find download peer (ie the peer that we will ask for governance objects from
        for (DSPeer *peer in self.peerManager.connectedPeers) {
            if (peer.status != DSPeerStatus_Connected) continue;
            downloadPeer = peer;
            break;
        }

        if (downloadPeer) {
            downloadPeer.governanceRequestState = DSGovernanceRequestState_GovernanceObjects; //force this by bypassing normal route

            //we will request governance objects
            //however since governance objects are all accounted for
            //and we want votes, then votes will be requested instead for each governance object
            [self requestGovernanceObjectsFromPeer:downloadPeer];
        }
    }
}


- (void)startGovernanceSync {
    //Do we want to sync?
    if (!([[DSOptionsManager sharedInstance] syncType] & DSSyncType_Governance)) return; // make sure we care about Governance objects

    //Do we need to sync?
    if ([[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"%@_%@", self.chain.uniqueID, LAST_SYNCED_GOVERANCE_OBJECTS]]) { //no need to do a governance sync if we already completed one recently
        NSTimeInterval lastSyncedGovernance = [[NSUserDefaults standardUserDefaults] integerForKey:[NSString stringWithFormat:@"%@_%@", self.chain.uniqueID, LAST_SYNCED_GOVERANCE_OBJECTS]];
        NSTimeInterval interval = [[DSOptionsManager sharedInstance] syncGovernanceObjectsInterval];
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        if (lastSyncedGovernance + interval > now) {
            [self continueGovernanceSync];
            return;
        };
    }

    //We need to sync
    NSArray *sortedPeers = [self.peerManager.connectedPeers sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"lastRequestedGovernanceSync" ascending:YES]]];
    BOOL startedGovernanceSync = FALSE;
    for (DSPeer *peer in sortedPeers) {
        if (peer.status != DSPeerStatus_Connected) continue;
        if ([[NSDate date] timeIntervalSince1970] - peer.lastRequestedGovernanceSync < 10800) {
            continue; //don't request less than every 3 hours from a peer
        }
        peer.lastRequestedGovernanceSync = [[NSDate date] timeIntervalSince1970]; //we are requesting the list from this peer
        [peer sendGovernanceSyncRequest:[DSGovernanceObjectsSyncRequest request]];
        [peer save];
        startedGovernanceSync = TRUE;
        break;
    }
    if (!startedGovernanceSync) { //we have requested masternode list from connected peers too recently, let's connect to different peers
        [self continueGovernanceSync];
    }
}

- (void)publishProposal:(DSGovernanceObject *)goveranceProposal {
    NSParameterAssert(goveranceProposal);

    if (![goveranceProposal isValid]) return;
    [self.peerManager.downloadPeer sendGovObject:goveranceProposal];
}

- (void)publishVotes:(NSArray<DSGovernanceVote *> *)votes {
    NSMutableArray *voteHashes = [NSMutableArray array];
    for (DSGovernanceVote *vote in votes) {
        if (![vote isValid]) continue;
        [voteHashes addObject:uint256_obj(vote.governanceVoteHash)];
    }
    [self.peerManager.downloadPeer sendInvMessageForHashes:voteHashes
                                                    ofType:DSInvType_GovernanceObjectVote];
}

// MARK:- Control

- (void)startNextGoveranceVoteSyncWithPeer:(DSPeer *)peer {
    self.currentGovernanceSyncObject = [self.needVoteSyncGovernanceObjects firstObject];
    self.currentGovernanceSyncObject.delegate = self;
    [peer sendGovernanceSyncRequest:[DSGovernanceVotesSyncRequest requestWithParentHash:self.currentGovernanceSyncObject.governanceObjectHash]];
}

- (void)finishedGovernanceObjectSyncWithPeer:(DSPeer *)peer {
    if (peer.governanceRequestState != DSGovernanceRequestState_GovernanceObjects) return;
    peer.governanceRequestState = DSGovernanceRequestState_None;
    [[NSUserDefaults standardUserDefaults] setInteger:[[NSDate date] timeIntervalSince1970] forKey:[NSString stringWithFormat:@"%@_%@", self.chain.uniqueID, LAST_SYNCED_GOVERANCE_OBJECTS]];

    //Do we want to request votes now?
    if (!([[DSOptionsManager sharedInstance] syncType] & DSSyncType_GovernanceVotes)) return;
    self.needVoteSyncGovernanceObjects = [self.governanceObjects mutableCopy];
    [self startNextGoveranceVoteSyncWithPeer:peer];
}

- (void)finishedGovernanceVoteSyncWithPeer:(DSPeer *)peer {
    if (peer.governanceRequestState != DSGovernanceRequestState_GovernanceObjectVotes) return;
    if (!([[DSOptionsManager sharedInstance] syncType] & DSSyncType_GovernanceVotes)) return;
    peer.governanceRequestState = DSGovernanceRequestState_None;
    [self.needVoteSyncGovernanceObjects removeObject:self.currentGovernanceSyncObject];
    if ([self.needVoteSyncGovernanceObjects count]) {
        [self startNextGoveranceVoteSyncWithPeer:peer];
    }
}

// MARK:- Governance Object

- (NSUInteger)recentGovernanceObjectHashesCount {
    __block NSUInteger count = 0;
    [self.managedObjectContext performBlockAndWait:^{
        count = [DSGovernanceObjectHashEntity countAroundNowOnChainEntity:[self.chain chainEntityInContext:self.managedObjectContext]];
    }];
    return count;
}

- (NSUInteger)last3HoursStandaloneGovernanceObjectHashesCount {
    __block NSUInteger count = 0;
    [self.managedObjectContext performBlockAndWait:^{
        count = [DSGovernanceObjectHashEntity standaloneCountInLast3hoursOnChainEntity:[self.chain chainEntityInContext:self.managedObjectContext]];
    }];
    return count;
}

- (NSUInteger)proposalObjectsCount {
    __block NSUInteger count = 0;
    [self.managedObjectContext performBlockAndWait:^{
        count = [DSGovernanceObjectEntity countObjectsInContext:self.managedObjectContext matching:@"governanceObjectHash.chain == %@ && type == %@", [self.chain chainEntityInContext:self.managedObjectContext], @(DSGovernanceObjectType_Proposal)];
    }];
    return count;
}

- (NSUInteger)governanceObjectsCount {
    __block NSUInteger count = 0;
    [self.managedObjectContext performBlockAndWait:^{
        count = [DSGovernanceObjectEntity countForChainEntity:[self.chain chainEntityInContext:self.managedObjectContext]];
    }];
    return count;
}


- (void)loadGovernanceObjects:(NSUInteger)count {
    NSFetchRequest *fetchRequest = [[DSGovernanceObjectEntity fetchRequest] copy];
    if (count) {
        [fetchRequest setFetchLimit:count];
    }
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"governanceObjectHash.chain == %@", [self.chain chainEntityInContext:self.managedObjectContext]]];
    if (!_knownGovernanceObjectHashesForExistingGovernanceObjects) _knownGovernanceObjectHashesForExistingGovernanceObjects = [NSMutableOrderedSet orderedSet];
    NSArray *governanceObjectEntities = [DSGovernanceObjectEntity fetchObjects:fetchRequest inContext:self.managedObjectContext];
    for (DSGovernanceObjectEntity *governanceObjectEntity in governanceObjectEntities) {
        DSGovernanceObject *governanceObject = [governanceObjectEntity governanceObject];
        [_knownGovernanceObjectHashesForExistingGovernanceObjects addObject:[NSData dataWithUInt256:governanceObject.governanceObjectHash]];
        [_governanceObjects addObject:governanceObject];
    }
}

- (NSOrderedSet *)knownGovernanceObjectHashes {
    if (_knownGovernanceObjectHashes) return _knownGovernanceObjectHashes;

    [self.managedObjectContext performBlockAndWait:^{
        NSFetchRequest *request = DSGovernanceObjectHashEntity.fetchReq;
        [request setPredicate:[NSPredicate predicateWithFormat:@"chain = %@", [self.chain chainEntityInContext:self.managedObjectContext]]];
        [request setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"governanceObjectHash" ascending:TRUE]]];
        NSArray<DSGovernanceObjectHashEntity *> *knownGovernanceObjectHashEntities = [DSGovernanceObjectHashEntity fetchObjects:request inContext:self.managedObjectContext];
        NSMutableOrderedSet<NSData *> *rHashes = [NSMutableOrderedSet orderedSetWithCapacity:knownGovernanceObjectHashEntities.count];
        for (DSGovernanceObjectHashEntity *knownGovernanceObjectHashEntity in knownGovernanceObjectHashEntities) {
            NSData *hash = knownGovernanceObjectHashEntity.governanceObjectHash;
            [rHashes addObject:hash];
        }
        self.knownGovernanceObjectHashes = [rHashes copy];
    }];
    return _knownGovernanceObjectHashes;
}

- (NSMutableArray *)needsRequestsGovernanceObjectHashEntities {
    NSFetchRequest *request = DSGovernanceObjectHashEntity.fetchReq;
    DSChainEntity *chainEntity = [self.chain chainEntityInContext:self.managedObjectContext];
    [request setPredicate:[NSPredicate predicateWithFormat:@"chain == %@ && governanceObject == nil", chainEntity]];
    [request setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"governanceObjectHash" ascending:TRUE]]];
    return [[DSGovernanceObjectHashEntity fetchObjects:request inContext:self.managedObjectContext] mutableCopy];
}

- (NSUInteger)needsRequestsGovernanceObjectHashEntitiesCount {
    NSFetchRequest *request = DSGovernanceObjectHashEntity.fetchReq;
    DSChainEntity *chainEntity = [self.chain chainEntityInContext:self.managedObjectContext];
    [request setPredicate:[NSPredicate predicateWithFormat:@"chain == %@ && governanceObject == nil", chainEntity]];
    [request setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"governanceObjectHash" ascending:TRUE]]];
    return [DSGovernanceObjectHashEntity countObjects:request inContext:self.managedObjectContext];
}

- (NSArray *)needsGovernanceObjectRequestsHashes {
    __block NSMutableArray *mArray = [NSMutableArray array];
    [self.managedObjectContext performBlockAndWait:^{
        for (DSGovernanceObjectHashEntity *governanceObjectHashEntity in self.needsRequestsGovernanceObjectHashEntities) {
            [mArray addObject:governanceObjectHashEntity.governanceObjectHash];
        }
    }];
    return [mArray copy];
}

- (NSOrderedSet *)fulfilledRequestsGovernanceObjectHashEntities {
    @synchronized(self) {
        __block NSOrderedSet *orderedSet;
        [self.managedObjectContext performBlockAndWait:^{
            NSFetchRequest *request = DSGovernanceObjectHashEntity.fetchReq;
            [request setPredicate:[NSPredicate predicateWithFormat:@"chain = %@ && governanceObject != nil", [self.chain chainEntityInContext:self.managedObjectContext]]];
            [request setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"governanceObjectHash" ascending:TRUE]]];
            orderedSet = [NSOrderedSet orderedSetWithArray:[DSGovernanceObjectHashEntity fetchObjects:request inContext:self.managedObjectContext]];
        }];
        return orderedSet;
    }
}

- (NSOrderedSet *)fulfilledGovernanceObjectRequestsHashes {
    NSMutableOrderedSet *mOrderedSet = [NSMutableOrderedSet orderedSet];
    for (DSGovernanceObjectHashEntity *governanceObjectHashEntity in self.fulfilledRequestsGovernanceObjectHashEntities) {
        [mOrderedSet addObject:governanceObjectHashEntity.governanceObjectHash];
    }
    return [mOrderedSet copy];
}

- (void)requestGovernanceObjectsFromPeer:(DSPeer *)peer {
    __block BOOL finishedSync = FALSE;
    [self.managedObjectContext performBlockAndWait:^{
        if (![self needsRequestsGovernanceObjectHashEntitiesCount]) {
            [self finishedGovernanceObjectSyncWithPeer:(DSPeer *)peer];
            //we are done syncing
            finishedSync = TRUE;
        } else {
            self.requestGovernanceObjectHashEntities = [[self.needsRequestsGovernanceObjectHashEntities subarrayWithRange:NSMakeRange(0, MIN(self.needsGovernanceObjectRequestsHashes.count, REQUEST_GOVERNANCE_OBJECT_COUNT))] mutableCopy];
        }
    }];
    if (finishedSync) return;
    NSMutableArray *requestHashes = [NSMutableArray array];
    for (DSGovernanceObjectHashEntity *governanceObjectHashEntity in self.requestGovernanceObjectHashEntities) {
        [requestHashes addObject:governanceObjectHashEntity.governanceObjectHash];
    }
    DSGetGovernanceObjectsRequest *request = [DSGetGovernanceObjectsRequest requestWithGovernanceObjectHashes:requestHashes];
    [peer sendGovernanceRequest:request];
}

- (void)peer:(DSPeer *)peer hasGovernanceObjectHashes:(NSSet *)governanceObjectHashes {
    if (!([[DSOptionsManager sharedInstance] syncType] & DSSyncType_Governance)) return; // make sure we care about Governance objects
    @synchronized(self) {
        if (peer.governanceRequestState != DSGovernanceRequestState_GovernanceObjectHashesReceived) {
            if ((governanceObjectHashes.count == 1) && ([_knownGovernanceObjectHashesForExistingGovernanceObjects containsObject:[governanceObjectHashes anyObject]])) {
                return;
            }
        }
        NSMutableOrderedSet *hashesToInsert = [[NSOrderedSet orderedSetWithSet:governanceObjectHashes] mutableCopy];
        NSMutableOrderedSet *hashesToUpdate = [[NSOrderedSet orderedSetWithSet:governanceObjectHashes] mutableCopy];
        NSMutableOrderedSet *hashesToQuery = [[NSOrderedSet orderedSetWithSet:governanceObjectHashes] mutableCopy];
        NSMutableOrderedSet<NSData *> *rHashes = [self.knownGovernanceObjectHashes mutableCopy];
        [hashesToInsert minusOrderedSet:self.knownGovernanceObjectHashes];
        [hashesToUpdate minusOrderedSet:hashesToInsert];
        [hashesToQuery minusOrderedSet:self.fulfilledGovernanceObjectRequestsHashes];
        NSMutableOrderedSet *hashesToQueryFromInsert = [hashesToQuery mutableCopy];
        [hashesToQueryFromInsert intersectOrderedSet:hashesToInsert];
        NSMutableArray *hashEntitiesToQuery = [NSMutableArray array];
        if ([governanceObjectHashes count]) {
            [self.managedObjectContext performBlockAndWait:^{
                DSChainEntity *chainEntity = [self.chain chainEntityInContext:self.managedObjectContext];
                if ([hashesToInsert count]) {
                    NSArray *novelGovernanceObjectHashEntities = [DSGovernanceObjectHashEntity governanceObjectHashEntitiesWithHashes:hashesToInsert onChainEntity:chainEntity];
                    for (DSGovernanceObjectHashEntity *governanceObjectHashEntity in novelGovernanceObjectHashEntities) {
                        if ([hashesToQueryFromInsert containsObject:governanceObjectHashEntity.governanceObjectHash]) {
                            [hashEntitiesToQuery addObject:governanceObjectHashEntity];
                        }
                    }
                }
                if ([hashesToUpdate count]) {
                    [DSGovernanceObjectHashEntity updateTimestampForGovernanceObjectHashEntitiesWithGovernanceObjectHashes:hashesToUpdate onChainEntity:chainEntity];
                }
                NSError *error = nil;
                [self.managedObjectContext save:&error];
            }];
            if ([hashesToInsert count]) {
                [rHashes addObjectsFromArray:[hashesToInsert array]];
                [rHashes sortUsingComparator:^NSComparisonResult(id _Nonnull obj1, id _Nonnull obj2) {
                    UInt256 a = *(UInt256 *)((NSData *)obj1).bytes;
                    UInt256 b = *(UInt256 *)((NSData *)obj2).bytes;
                    return uint256_sup(a, b) ? NSOrderedAscending : NSOrderedDescending;
                }];
            }
        }

        self.knownGovernanceObjectHashes = rHashes;
        NSUInteger countAroundNow = [self recentGovernanceObjectHashesCount];
        if ([self.knownGovernanceObjectHashes count] > self.chain.totalGovernanceObjectsCount) {
            [self.managedObjectContext performBlockAndWait:^{
                if (countAroundNow > self.chain.totalGovernanceObjectsCount) {
                    [DSGovernanceObjectHashEntity removeOldest:countAroundNow - self.chain.totalGovernanceObjectsCount onChainEntity:[self.chain chainEntityInContext:self.managedObjectContext]];
                    [self.managedObjectContext ds_save];
                }
                if (peer.governanceRequestState == DSGovernanceRequestState_GovernanceObjectHashesCountReceived) {
                    peer.governanceRequestState = DSGovernanceRequestState_GovernanceObjects;
                    [self requestGovernanceObjectsFromPeer:peer];
                } else {
                    peer.governanceRequestState = DSGovernanceRequestState_GovernanceObjectHashesReceived;
                }
            }];
        } else if (countAroundNow == self.chain.totalGovernanceObjectsCount) {
            //we have all hashes, let's request objects.
            if (peer.governanceRequestState == DSGovernanceRequestState_GovernanceObjectHashesCountReceived) {
                peer.governanceRequestState = DSGovernanceRequestState_GovernanceObjects;
                [self requestGovernanceObjectsFromPeer:peer];
            } else {
                peer.governanceRequestState = DSGovernanceRequestState_GovernanceObjectHashesReceived;
            }
        }
    }
}

- (void)peer:(DSPeer *)peer relayedGovernanceObject:(DSGovernanceObject *)governanceObject {
    if (!([[DSOptionsManager sharedInstance] syncType] & DSSyncType_Governance)) return; // make sure we care about Governance objects
    @synchronized(self) {
        NSData *governanceObjectHash = [NSData dataWithUInt256:governanceObject.governanceObjectHash];
        DSGovernanceObjectHashEntity *relatedHashEntity = nil;
        for (DSGovernanceObjectHashEntity *governanceObjectHashEntity in [self.requestGovernanceObjectHashEntities copy]) {
            if ([governanceObjectHashEntity.governanceObjectHash isEqual:governanceObjectHash]) {
                relatedHashEntity = governanceObjectHashEntity;
                [self.requestGovernanceObjectHashEntities removeObject:governanceObjectHashEntity];
                break;
            }
        }
        //NSAssert(relatedHashEntity, @"There needs to be a relatedHashEntity");
        if (!relatedHashEntity) return;
        [[DSGovernanceObjectEntity managedObjectInBlockedContext:self.managedObjectContext] setAttributesFromGovernanceObject:governanceObject forHashEntity:relatedHashEntity];
        [self.governanceObjects addObject:governanceObject];
        if (![self.requestGovernanceObjectHashEntities count]) {
            [self requestGovernanceObjectsFromPeer:peer];
            [self.managedObjectContext ds_save];
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:DSGovernanceObjectListDidChangeNotification object:nil userInfo:@{DSChainManagerNotificationChainKey: self.chain}];
            });
        }
        __block BOOL finished = FALSE;
        [self.managedObjectContext performBlockAndWait:^{
            finished = ![self needsRequestsGovernanceObjectHashEntitiesCount];
        }];

        if (finished) {
            [self finishedGovernanceObjectSyncWithPeer:(DSPeer *)peer];
        }
    }
}

- (DSGovernanceObject *)peer:(DSPeer *_Nullable)peer requestedGovernanceObject:(UInt256)governanceObjectHash {
    if (!([[DSOptionsManager sharedInstance] syncType] & DSSyncType_Governance)) return nil; // make sure we care about Governance objects
    DSGovernanceObject *proposal = [self.publishGovernanceObjects objectForKey:[NSData dataWithUInt256:governanceObjectHash]];
    return proposal;
}

// MARK:- Governance Votes

- (NSUInteger)governanceVotesCount {
    __block NSUInteger count = 0;
    [self.managedObjectContext performBlockAndWait:^{
        count = [DSGovernanceVoteEntity countForChainEntity:[self.chain chainEntityInContext:self.managedObjectContext]];
    }];
    return count;
}

- (NSUInteger)totalGovernanceVotesCount {
    NSUInteger totalVotes = 0;
    for (DSGovernanceObject *governanceObject in self.governanceObjects) {
        totalVotes += governanceObject.totalGovernanceVoteCount;
    }
    return totalVotes;
}

- (void)peer:(DSPeer *_Nullable)peer relayedGovernanceVote:(DSGovernanceVote *)governanceVote {
    if (!([[DSOptionsManager sharedInstance] syncType] & DSSyncType_GovernanceVotes)) return; // make sure we care about Governance objects
    DSGovernanceObject *parentGovernanceObject = nil;
    for (DSGovernanceObject *governanceObject in self.governanceObjects) {
        if (uint256_eq(governanceVote.parentHash, governanceObject.governanceObjectHash)) {
            parentGovernanceObject = governanceObject;
            governanceVote.governanceObject = parentGovernanceObject;
            break;
        }
    }
    if (parentGovernanceObject) {
        [governanceVote.governanceObject peer:peer relayedGovernanceVote:governanceVote];
        if (governanceVote.governanceObject.finishedSync) {
            [self finishedGovernanceVoteSyncWithPeer:peer];
        }
    }
}

- (DSGovernanceVote *)peer:(DSPeer *_Nullable)peer requestedVote:(UInt256)voteHash {
    if (!([[DSOptionsManager sharedInstance] syncType] & DSSyncType_GovernanceVotes)) return nil; // make sure we care about Governance objects
    __block DSGovernanceVote *vote = [self.publishVotes objectForKey:[NSData dataWithUInt256:voteHash]];
    if (!vote) {
        [self.managedObjectContext performBlockAndWait:^{
            NSArray *votes = [DSGovernanceVoteEntity objectsInContext:self.managedObjectContext matching:@"governanceVoteHash.governanceVoteHash = %@", uint256_data(voteHash)];
            if (votes.count) {
                DSGovernanceVoteEntity *voteEntity = [votes firstObject];
                vote = [voteEntity governanceVote];
            }
        }];
    }
    return vote;
}

- (void)peer:(DSPeer *)peer ignoredGovernanceSync:(DSGovernanceRequestState)governanceRequestState {
    [self.peerManager peerMisbehaving:peer errorMessage:@"Ignored Governance Sync"];
    [self.peerManager connect];
}

// MARK:- Governance ObjectDelegate

- (void)governanceObject:(DSGovernanceObject *)governanceObject didReceiveUnknownHashes:(NSSet *)hash fromPeer:(DSPeer *)peer {
}

- (void)peer:(DSPeer *)peer hasGovernanceVoteHashes:(NSSet *)governanceVoteHashes {
    [self.currentGovernanceSyncObject peer:peer hasGovernanceVoteHashes:governanceVoteHashes];
}

// MARK:- Proposal Creation

- (DSGovernanceObject *)createProposalWithIdentifier:(NSString *)identifier toPaymentAddress:(NSString *)paymentAddress forAmount:(uint64_t)amount fromAccount:(DSAccount *)account startDate:(NSDate *)startDate cycles:(NSUInteger)cycles url:(NSString *)url {
    NSParameterAssert(identifier);
    NSParameterAssert(paymentAddress);
    NSParameterAssert(account);
    NSParameterAssert(startDate);
    NSParameterAssert(url);

    uint64_t endEpoch = [startDate timeIntervalSince1970] + (SUPERBLOCK_AVERAGE_TIME * cycles);
    DSGovernanceObject *governanceObject = [[DSGovernanceObject alloc] initWithType:DSGovernanceObjectType_Proposal parentHash:UINT256_ZERO revision:1 timestamp:[[NSDate date] timeIntervalSince1970] signature:nil collateralHash:UINT256_ZERO governanceObjectHash:UINT256_ZERO identifier:identifier amount:amount startEpoch:[startDate timeIntervalSince1970] endEpoch:endEpoch paymentAddress:paymentAddress url:url onChain:self.chain];
    return governanceObject;
}


// MARK:- Voting

- (void)vote:(DSGovernanceVoteOutcome)governanceVoteOutcome onGovernanceProposal:(DSGovernanceObject *)governanceObject {
    NSParameterAssert(governanceObject);

    //TODO fix voting
    //    NSArray * registeredMasternodes = [self.chain registeredMasternodes];
    //    DSPeerManager * peerManager = [[DSChainsManager sharedInstance] chainManagerForChain:self.chain];
    //    NSMutableArray * votesToRelay = [NSMutableArray array];
    //    for (DSSimplifiedMasternodeEntry * masternodeEntry in registeredMasternodes) {
    //        NSData * votingKey = [self.chain votingKeyForMasternode:masternodeEntry];
    //        DSECDSAKey * key = [DSECDSAKey keyWithPrivateKey:votingKey.base58String onChain:self.chain];
    //        UInt256 proposalHash = governanceObject.governanceObjectHash;
    //        DSUTXO masternodeUTXO = masternodeEntry.utxo;
    //        NSTimeInterval now = floor([[NSDate date] timeIntervalSince1970]);
    //        DSGovernanceVote * governanceVote = [[DSGovernanceVote alloc] initWithParentHash:proposalHash forMasternodeUTXO:masternodeUTXO voteOutcome:governanceVoteOutcome voteSignal:DSGovernanceVoteSignal_None createdAt:now signature:nil onChain:self.chain];
    //        [governanceVote signWithKey:key];
    //        [votesToRelay addObject:governanceVote];
    //        [self.publishVotes setObject:governanceVote forKey:uint256_data(governanceVote.governanceVoteHash)];
    //    }
    //    [peerManager publishVotes:votesToRelay];
}

- (void)wipeGovernanceInfo {
    [_governanceObjects removeAllObjects];
    [_needVoteSyncGovernanceObjects removeAllObjects];
    _currentGovernanceSyncObject = nil;
    _knownGovernanceObjectHashes = nil;
    self.governanceObjectsCount = 0;
}

@end
