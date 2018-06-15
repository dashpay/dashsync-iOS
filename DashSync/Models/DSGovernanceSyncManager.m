//
//  DSGovernanceSyncManager.m
//  DashSync
//
//  Created by Sam Westrich on 6/12/18.
//

#import "DSGovernanceSyncManager.h"
#import "DSGovernanceObject.h"
#import "DSGovernanceVote.h"
#import "DSMasternodePing.h"
#import "DSGovernanceObjectEntity+CoreDataProperties.h"
#import "DSGovernanceObjectHashEntity+CoreDataProperties.h"
#import "DSGovernanceVoteEntity+CoreDataProperties.h"
#import "DSGovernanceVoteHashEntity+CoreDataProperties.h"
#import "NSManagedObject+Sugar.h"
#import "DSChain.h"
#import "DSPeer.h"
#import "DSChainEntity+CoreDataProperties.h"
#import "NSData+Dash.h"

#define REQUEST_GOVERNANCE_OBJECT_COUNT 500

@interface DSGovernanceSyncManager()

@property (nonatomic,strong) DSChain * chain;

@property (nonatomic,strong) NSOrderedSet * knownGovernanceObjectHashes;
@property (nonatomic,readonly) NSOrderedSet * fulfilledRequestsGovernanceObjectHashEntities;
@property (nonatomic,strong) NSMutableArray *needsRequestsGovernanceObjectHashEntities;
@property (nonatomic,strong) NSMutableArray * requestGovernanceObjectHashEntities;
@property (nonatomic,strong) NSMutableArray<DSGovernanceObject *> * governanceObjects;
@property (nonatomic,assign) NSUInteger governanceObjectsCount;

@property (nonatomic,strong) NSOrderedSet * knownGovernanceVoteHashes;
@property (nonatomic,readonly) NSOrderedSet * fulfilledRequestsGovernanceVoteHashEntities;
@property (nonatomic,strong) NSMutableArray *needsRequestsGovernanceVoteHashEntities;
@property (nonatomic,strong) NSMutableArray * requestGovernanceVoteHashEntities;
@property (nonatomic,strong) NSMutableArray<DSGovernanceVote *> * governanceVotes;
@property (nonatomic,assign) NSUInteger governanceVotesCount;

@property (nonatomic,strong) NSManagedObjectContext * managedObjectContext;

@end

@implementation DSGovernanceSyncManager

- (instancetype)initWithChain:(id)chain
{
    if (! (self = [super init])) return nil;
    _chain = chain;
    _governanceObjects = [NSMutableArray array];
    self.managedObjectContext = [NSManagedObject context];
    return self;
}

// MARK:- Governance Object

-(NSUInteger)recentGovernanceObjectHashesCount {
    __block NSUInteger count = 0;
    [self.managedObjectContext performBlockAndWait:^{
        count = [DSGovernanceObjectHashEntity countAroundNowOnChain:self.chain.chainEntity];
    }];
    return count;
}

-(NSUInteger)last3HoursStandaloneGovernanceObjectHashesCount {
    __block NSUInteger count = 0;
    [self.managedObjectContext performBlockAndWait:^{
        [DSGovernanceObjectHashEntity setContext:self.managedObjectContext];
        count = [DSGovernanceObjectHashEntity standaloneCountInLast3hoursOnChain:self.chain.chainEntity];
    }];
    return count;
}

-(NSUInteger)governanceObjectsCount {
    
    __block NSUInteger count = 0;
    [self.managedObjectContext performBlockAndWait:^{
        [DSGovernanceObjectEntity setContext:self.managedObjectContext];
        count = [DSGovernanceObjectEntity countForChain:self.chain.chainEntity];
    }];
    return count;
}


//-(void)loadGovernanceObjects:(NSUInteger)count {
//    NSFetchRequest * fetchRequest = [[DSGovernanceObjectEntity fetchRequest] copy];
//    [fetchRequest setFetchLimit:count];
//    NSArray * governanceObjectEntities = [DSGovernanceObjectEntity fetchObjects:fetchRequest];
//    for (DSGovernanceObjectEntity * governanceObjectEntity in governanceObjectEntities) {
//        DSUTXO utxo;
//        utxo.hash = *(UInt256 *)governanceObjectEntity.utxoHash.bytes;
//        utxo.n = governanceObjectEntity.utxoIndex;
//        UInt128 ipv6address = UINT128_ZERO;
//        ipv6address.u32[3] = governanceObjectEntity.address;
//        UInt256 governanceObjectHash = *(UInt256 *)governanceObjectEntity.governanceObjectHash.governanceObjectHash.bytes;
//        DSGovernanceObject * governanceObject = [[DSGovernanceObject alloc] initWithUTXO:utxo ipAddress:ipv6address port:governanceObjectEntity.port protocolVersion:governanceObjectEntity.protocolVersion publicKey:governanceObjectEntity.publicKey signature:governanceObjectEntity.signature signatureTimestamp:governanceObjectEntity.signatureTimestamp governanceObjectHash:governanceObjectHash onChain:self.chain];
//        [_governanceObjects addObject:governanceObject];
//    }
//}

-(NSOrderedSet*)knownGovernanceObjectHashes {
    if (_knownGovernanceObjectHashes) return _knownGovernanceObjectHashes;
    
    [self.managedObjectContext performBlockAndWait:^{
        [DSGovernanceObjectHashEntity setContext:self.managedObjectContext];
        NSFetchRequest *request = DSGovernanceObjectHashEntity.fetchReq;
        [request setPredicate:[NSPredicate predicateWithFormat:@"chain = %@",self.chain.chainEntity]];
        [request setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"governanceObjectHash" ascending:TRUE]]];
        NSArray<DSGovernanceObjectHashEntity *> * knownGovernanceObjectHashEntities = [DSGovernanceObjectHashEntity fetchObjects:request];
        NSMutableOrderedSet <NSData*> * rHashes = [NSMutableOrderedSet orderedSetWithCapacity:knownGovernanceObjectHashEntities.count];
        for (DSGovernanceObjectHashEntity * knownGovernanceObjectHashEntity in knownGovernanceObjectHashEntities) {
            NSData * hash = knownGovernanceObjectHashEntity.governanceObjectHash;
            [rHashes addObject:hash];
        }
        self.knownGovernanceObjectHashes = [rHashes copy];
    }];
    return _knownGovernanceObjectHashes;
}

-(NSMutableArray*)needsRequestsGovernanceObjectHashEntities {
    if (_needsRequestsGovernanceObjectHashEntities) return _needsRequestsGovernanceObjectHashEntities;
    
    [self.managedObjectContext performBlockAndWait:^{
        [DSGovernanceObjectHashEntity setContext:self.managedObjectContext];
        NSFetchRequest *request = DSGovernanceObjectHashEntity.fetchReq;
        [request setPredicate:[NSPredicate predicateWithFormat:@"chain = %@ && governanceObject == nil",self.chain.chainEntity]];
        [request setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"governanceObjectHash" ascending:TRUE]]];
        self.needsRequestsGovernanceObjectHashEntities = [[DSGovernanceObjectHashEntity fetchObjects:request] mutableCopy];
        
    }];
    return _needsRequestsGovernanceObjectHashEntities;
}

-(NSArray*)needsGovernanceObjectRequestsHashes {
    __block NSMutableArray * mArray = [NSMutableArray array];
    [self.managedObjectContext performBlockAndWait:^{
        [DSGovernanceObjectHashEntity setContext:self.managedObjectContext];
        for (DSGovernanceObjectHashEntity * governanceObjectHashEntity in self.needsRequestsGovernanceObjectHashEntities) {
            [mArray addObject:governanceObjectHashEntity.governanceObjectHash];
        }
    }];
    return [mArray copy];
}

-(NSOrderedSet*)fulfilledRequestsGovernanceObjectHashEntities {
    __block NSOrderedSet * orderedSet;
    [self.managedObjectContext performBlockAndWait:^{
        [DSGovernanceObjectHashEntity setContext:self.managedObjectContext];
        NSFetchRequest *request = DSGovernanceObjectHashEntity.fetchReq;
        [request setPredicate:[NSPredicate predicateWithFormat:@"chain = %@ && governanceObject != nil",self.chain.chainEntity]];
        [request setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"governanceObjectHash" ascending:TRUE]]];
        orderedSet = [NSOrderedSet orderedSetWithArray:[DSGovernanceObjectHashEntity fetchObjects:request]];
        
    }];
    return orderedSet;
}

-(NSOrderedSet*)fulfilledGovernanceObjectRequestsHashes {
    NSMutableOrderedSet * mOrderedSet = [NSMutableOrderedSet orderedSet];
    for (DSGovernanceObjectHashEntity * governanceObjectHashEntity in self.fulfilledRequestsGovernanceObjectHashEntities) {
        [mOrderedSet addObject:governanceObjectHashEntity.governanceObjectHash];
    }
    return [mOrderedSet copy];
}

-(void)requestGovernanceObjectsFromPeer:(DSPeer*)peer {
    if (![self.needsRequestsGovernanceObjectHashEntities count]) {
        //we are done syncing
        return;
    }
    self.requestGovernanceObjectHashEntities = [[self.needsRequestsGovernanceObjectHashEntities subarrayWithRange:NSMakeRange(0, MIN(self.needsGovernanceObjectRequestsHashes.count,REQUEST_GOVERNANCE_OBJECT_COUNT))] mutableCopy];
    NSMutableArray * requestHashes = [NSMutableArray array];
    for (DSGovernanceObjectHashEntity * governanceObjectHashEntity in self.requestGovernanceObjectHashEntities) {
        [requestHashes addObject:governanceObjectHashEntity.governanceObjectHash];
    }
    [peer sendGetdataMessageWithGovernanceObjectHashes:requestHashes];
}

- (void)peer:(DSPeer *)peer hasGovernanceObjectHashes:(NSSet*)governanceObjectHashes {
    NSLog(@"peer relayed governance objects");
    NSMutableOrderedSet * hashesToInsert = [[NSOrderedSet orderedSetWithSet:governanceObjectHashes] mutableCopy];
    NSMutableOrderedSet * hashesToUpdate = [[NSOrderedSet orderedSetWithSet:governanceObjectHashes] mutableCopy];
    NSMutableOrderedSet * hashesToQuery = [[NSOrderedSet orderedSetWithSet:governanceObjectHashes] mutableCopy];
    NSMutableOrderedSet <NSData*> * rHashes = [_knownGovernanceObjectHashes mutableCopy];
    [hashesToInsert minusOrderedSet:self.knownGovernanceObjectHashes];
    [hashesToUpdate minusOrderedSet:hashesToInsert];
    [hashesToQuery minusOrderedSet:self.fulfilledGovernanceObjectRequestsHashes];
    NSMutableOrderedSet * hashesToQueryFromInsert = [hashesToQuery mutableCopy];
    [hashesToQueryFromInsert intersectOrderedSet:hashesToInsert];
    NSMutableArray * hashEntitiesToQuery = [NSMutableArray array];
    NSMutableArray <NSData*> * rNeedsRequestsHashEntities = [self.needsRequestsGovernanceObjectHashEntities mutableCopy];
    if ([governanceObjectHashes count]) {
        [self.managedObjectContext performBlockAndWait:^{
            [DSChainEntity setContext:self.managedObjectContext];
            [DSGovernanceObjectHashEntity setContext:self.managedObjectContext];
            if ([hashesToInsert count]) {
                NSArray * novelGovernanceObjectHashEntities = [DSGovernanceObjectHashEntity governanceObjectHashEntitiesWithHashes:hashesToInsert onChain:self.chain.chainEntity];
                for (DSGovernanceObjectHashEntity * governanceObjectHashEntity in novelGovernanceObjectHashEntities) {
                    if ([hashesToQueryFromInsert containsObject:governanceObjectHashEntity.governanceObjectHash]) {
                        [hashEntitiesToQuery addObject:governanceObjectHashEntity];
                    }
                }
            }
            if ([hashesToUpdate count]) {
                [DSGovernanceObjectHashEntity updateTimestampForGovernanceObjectHashEntitiesWithGovernanceObjectHashes:hashesToUpdate onChain:self.chain.chainEntity];
            }
            [DSGovernanceObjectHashEntity saveContext];
        }];
        if ([hashesToInsert count]) {
            [rHashes addObjectsFromArray:[hashesToInsert array]];
            [rHashes sortUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
                UInt256 a = *(UInt256 *)((NSData*)obj1).bytes;
                UInt256 b = *(UInt256 *)((NSData*)obj2).bytes;
                return uint256_sup(a,b)?NSOrderedAscending:NSOrderedDescending;
            }];
        }
    }
    
    [rNeedsRequestsHashEntities addObjectsFromArray:hashEntitiesToQuery];
    [rNeedsRequestsHashEntities sortUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        UInt256 a = *(UInt256 *)((NSData*)((DSGovernanceObjectHashEntity*)obj1).governanceObjectHash).bytes;
        UInt256 b = *(UInt256 *)((NSData*)((DSGovernanceObjectHashEntity*)obj2).governanceObjectHash).bytes;
        return uint256_sup(a,b)?NSOrderedAscending:NSOrderedDescending;
    }];
    self.knownGovernanceObjectHashes = rHashes;
    self.needsRequestsGovernanceObjectHashEntities = rNeedsRequestsHashEntities;
    NSLog(@"-> %lu - %lu",(unsigned long)[self.knownGovernanceObjectHashes count],(unsigned long)self.totalGovernanceObjectCount);
    NSUInteger countAroundNow = [self recentGovernanceObjectHashesCount];
    if ([self.knownGovernanceObjectHashes count] > self.totalGovernanceObjectCount) {
        [self.managedObjectContext performBlockAndWait:^{
            [DSGovernanceObjectHashEntity setContext:self.managedObjectContext];
            NSLog(@"countAroundNow -> %lu - %lu",(unsigned long)countAroundNow,(unsigned long)self.totalGovernanceObjectCount);
            if (countAroundNow == self.totalGovernanceObjectCount) {
                [DSGovernanceObjectHashEntity removeOldest:self.totalGovernanceObjectCount - [self.knownGovernanceObjectHashes count] onChain:self.chain.chainEntity];
                [self requestGovernanceObjectsFromPeer:peer];
            }
        }];
    } else if (countAroundNow == self.totalGovernanceObjectCount) {
        NSLog(@"%@",@"All governance object hashes received");
        //we have all hashes, let's request objects.
        [self requestGovernanceObjectsFromPeer:peer];
    }
}

- (void)peer:(DSPeer * )peer relayedGovernanceObject:(DSGovernanceObject * )governanceObject {
    NSData *governanceObjectHash = [NSData dataWithUInt256:governanceObject.governanceObjectHash];
    DSGovernanceObjectHashEntity * relatedHashEntity = nil;
    for (DSGovernanceObjectHashEntity * governanceObjectHashEntity in [self.requestGovernanceObjectHashEntities copy]) {
        if ([governanceObjectHashEntity.governanceObjectHash isEqual:governanceObjectHash]) {
            relatedHashEntity = governanceObjectHashEntity;
            [self.requestGovernanceObjectHashEntities removeObject:governanceObjectHashEntity];
            break;
        }
    }
    //NSAssert(relatedHashEntity, @"There needs to be a relatedHashEntity");
    if (!relatedHashEntity) return;
    [[DSGovernanceObjectEntity managedObject] setAttributesFromGovernanceObject:governanceObject forHashEntity:relatedHashEntity];
    [self.needsRequestsGovernanceObjectHashEntities removeObject:relatedHashEntity];
    [self.governanceObjects addObject:governanceObject];
    if (![self.requestGovernanceObjectHashEntities count]) {
        [self requestGovernanceObjectsFromPeer:peer];
        [DSGovernanceObjectEntity saveContext];
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSGovernanceObjectListDidChangeNotification object:self userInfo:nil];
        });
    }
}



// MARK:- Governance Vote

-(NSUInteger)recentGovernanceVoteHashesCount {
    __block NSUInteger count = 0;
    [self.managedObjectContext performBlockAndWait:^{
        count = [DSGovernanceVoteHashEntity countAroundNowOnChain:self.chain.chainEntity];
    }];
    return count;
}

-(NSUInteger)last3HoursStandaloneGovernanceVoteHashesCount {
    __block NSUInteger count = 0;
    [self.managedObjectContext performBlockAndWait:^{
        [DSGovernanceVoteHashEntity setContext:self.managedObjectContext];
        count = [DSGovernanceVoteHashEntity standaloneCountInLast3hoursOnChain:self.chain.chainEntity];
    }];
    return count;
}

-(NSUInteger)governanceVotesCount {
    
    __block NSUInteger count = 0;
    [self.managedObjectContext performBlockAndWait:^{
        [DSGovernanceVoteEntity setContext:self.managedObjectContext];
        count = [DSGovernanceVoteEntity countForChain:self.chain.chainEntity];
    }];
    return count;
}


//-(void)loadGovernanceVotes:(NSUInteger)count {
//    NSFetchRequest * fetchRequest = [[DSGovernanceVoteEntity fetchRequest] copy];
//    [fetchRequest setFetchLimit:count];
//    NSArray * governanceVoteEntities = [DSGovernanceVoteEntity fetchObjects:fetchRequest];
//    for (DSGovernanceVoteEntity * governanceVoteEntity in governanceVoteEntities) {
//        DSUTXO utxo;
//        utxo.hash = *(UInt256 *)governanceVoteEntity.utxoHash.bytes;
//        utxo.n = governanceVoteEntity.utxoIndex;
//        UInt128 ipv6address = UINT128_ZERO;
//        ipv6address.u32[3] = governanceVoteEntity.address;
//        UInt256 governanceVoteHash = *(UInt256 *)governanceVoteEntity.governanceVoteHash.governanceVoteHash.bytes;
//        DSGovernanceVote * governanceVote = [[DSGovernanceVote alloc] initWithUTXO:utxo ipAddress:ipv6address port:governanceVoteEntity.port protocolVersion:governanceVoteEntity.protocolVersion publicKey:governanceVoteEntity.publicKey signature:governanceVoteEntity.signature signatureTimestamp:governanceVoteEntity.signatureTimestamp governanceVoteHash:governanceVoteHash onChain:self.chain];
//        [_governanceVotes addObject:governanceVote];
//    }
//}

-(NSOrderedSet*)knownGovernanceVoteHashes {
    if (_knownGovernanceVoteHashes) return _knownGovernanceVoteHashes;
    
    [self.managedObjectContext performBlockAndWait:^{
        [DSGovernanceVoteHashEntity setContext:self.managedObjectContext];
        NSFetchRequest *request = DSGovernanceVoteHashEntity.fetchReq;
        [request setPredicate:[NSPredicate predicateWithFormat:@"chain = %@",self.chain.chainEntity]];
        [request setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"governanceVoteHash" ascending:TRUE]]];
        NSArray<DSGovernanceVoteHashEntity *> * knownGovernanceVoteHashEntities = [DSGovernanceVoteHashEntity fetchObjects:request];
        NSMutableOrderedSet <NSData*> * rHashes = [NSMutableOrderedSet orderedSetWithCapacity:knownGovernanceVoteHashEntities.count];
        for (DSGovernanceVoteHashEntity * knownGovernanceVoteHashEntity in knownGovernanceVoteHashEntities) {
            NSData * hash = knownGovernanceVoteHashEntity.governanceVoteHash;
            [rHashes addObject:hash];
        }
        self.knownGovernanceVoteHashes = [rHashes copy];
    }];
    return _knownGovernanceVoteHashes;
}

-(NSMutableArray*)needsRequestsGovernanceVoteHashEntities {
    if (_needsRequestsGovernanceVoteHashEntities) return _needsRequestsGovernanceVoteHashEntities;
    
    [self.managedObjectContext performBlockAndWait:^{
        [DSGovernanceVoteHashEntity setContext:self.managedObjectContext];
        NSFetchRequest *request = DSGovernanceVoteHashEntity.fetchReq;
        [request setPredicate:[NSPredicate predicateWithFormat:@"chain = %@ && governanceVote == nil",self.chain.chainEntity]];
        [request setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"governanceVoteHash" ascending:TRUE]]];
        self.needsRequestsGovernanceVoteHashEntities = [[DSGovernanceVoteHashEntity fetchObjects:request] mutableCopy];
        
    }];
    return _needsRequestsGovernanceVoteHashEntities;
}

-(NSArray*)needsGovernanceVoteRequestsHashes {
    __block NSMutableArray * mArray = [NSMutableArray array];
    [self.managedObjectContext performBlockAndWait:^{
        [DSGovernanceVoteHashEntity setContext:self.managedObjectContext];
        for (DSGovernanceVoteHashEntity * governanceVoteHashEntity in self.needsRequestsGovernanceVoteHashEntities) {
            [mArray addObject:governanceVoteHashEntity.governanceVoteHash];
        }
    }];
    return [mArray copy];
}

-(NSOrderedSet*)fulfilledRequestsGovernanceVoteHashEntities {
    __block NSOrderedSet * orderedSet;
    [self.managedObjectContext performBlockAndWait:^{
        [DSGovernanceVoteHashEntity setContext:self.managedObjectContext];
        NSFetchRequest *request = DSGovernanceVoteHashEntity.fetchReq;
        [request setPredicate:[NSPredicate predicateWithFormat:@"chain = %@ && governanceVote != nil",self.chain.chainEntity]];
        [request setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"governanceVoteHash" ascending:TRUE]]];
        orderedSet = [NSOrderedSet orderedSetWithArray:[DSGovernanceVoteHashEntity fetchObjects:request]];
        
    }];
    return orderedSet;
}

-(NSOrderedSet*)fulfilledGovernanceVoteRequestsHashes {
    NSMutableOrderedSet * mOrderedSet = [NSMutableOrderedSet orderedSet];
    for (DSGovernanceVoteHashEntity * governanceVoteHashEntity in self.fulfilledRequestsGovernanceVoteHashEntities) {
        [mOrderedSet addObject:governanceVoteHashEntity.governanceVoteHash];
    }
    return [mOrderedSet copy];
}

-(void)requestGovernanceVotesFromPeer:(DSPeer*)peer {
    if (![self.needsRequestsGovernanceVoteHashEntities count]) {
        //we are done syncing
        return;
    }
    self.requestGovernanceVoteHashEntities = [[self.needsRequestsGovernanceVoteHashEntities subarrayWithRange:NSMakeRange(0, MIN(self.needsGovernanceVoteRequestsHashes.count,REQUEST_GOVERNANCE_OBJECT_COUNT))] mutableCopy];
    NSMutableArray * requestHashes = [NSMutableArray array];
    for (DSGovernanceVoteHashEntity * governanceVoteHashEntity in self.requestGovernanceVoteHashEntities) {
        [requestHashes addObject:governanceVoteHashEntity.governanceVoteHash];
    }
    [peer sendGetdataMessageWithGovernanceVoteHashes:requestHashes];
}

-(void)peer:(DSPeer *)peer hasGovernanceVoteHashes:(NSSet*)governanceVoteHashes {
    NSLog(@"peer relayed masternode broadcasts");
    NSMutableOrderedSet * hashesToInsert = [[NSOrderedSet orderedSetWithSet:governanceVoteHashes] mutableCopy];
    NSMutableOrderedSet * hashesToUpdate = [[NSOrderedSet orderedSetWithSet:governanceVoteHashes] mutableCopy];
    NSMutableOrderedSet * hashesToQuery = [[NSOrderedSet orderedSetWithSet:governanceVoteHashes] mutableCopy];
    NSMutableOrderedSet <NSData*> * rHashes = [_knownGovernanceVoteHashes mutableCopy];
    [hashesToInsert minusOrderedSet:self.knownGovernanceVoteHashes];
    [hashesToUpdate minusOrderedSet:hashesToInsert];
    [hashesToQuery minusOrderedSet:self.fulfilledGovernanceVoteRequestsHashes];
    NSMutableOrderedSet * hashesToQueryFromInsert = [hashesToQuery mutableCopy];
    [hashesToQueryFromInsert intersectOrderedSet:hashesToInsert];
    NSMutableArray * hashEntitiesToQuery = [NSMutableArray array];
    NSMutableArray <NSData*> * rNeedsRequestsHashEntities = [self.needsRequestsGovernanceVoteHashEntities mutableCopy];
    if ([governanceVoteHashes count]) {
        [self.managedObjectContext performBlockAndWait:^{
            [DSChainEntity setContext:self.managedObjectContext];
            [DSGovernanceVoteHashEntity setContext:self.managedObjectContext];
            if ([hashesToInsert count]) {
                NSArray * novelGovernanceVoteHashEntities = [DSGovernanceVoteHashEntity governanceVoteHashEntitiesWithHashes:hashesToInsert onChain:self.chain.chainEntity];
                for (DSGovernanceVoteHashEntity * governanceVoteHashEntity in novelGovernanceVoteHashEntities) {
                    if ([hashesToQueryFromInsert containsObject:governanceVoteHashEntity.governanceVoteHash]) {
                        [hashEntitiesToQuery addObject:governanceVoteHashEntity];
                    }
                }
            }
            if ([hashesToUpdate count]) {
                [DSGovernanceVoteHashEntity updateTimestampForGovernanceVoteHashEntitiesWithGovernanceVoteHashes:hashesToUpdate onChain:self.chain.chainEntity];
            }
            [DSGovernanceVoteHashEntity saveContext];
        }];
        if ([hashesToInsert count]) {
            [rHashes addObjectsFromArray:[hashesToInsert array]];
            [rHashes sortUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
                UInt256 a = *(UInt256 *)((NSData*)obj1).bytes;
                UInt256 b = *(UInt256 *)((NSData*)obj2).bytes;
                return uint256_sup(a,b)?NSOrderedAscending:NSOrderedDescending;
            }];
        }
    }
    
    [rNeedsRequestsHashEntities addObjectsFromArray:hashEntitiesToQuery];
    [rNeedsRequestsHashEntities sortUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        UInt256 a = *(UInt256 *)((NSData*)((DSGovernanceVoteHashEntity*)obj1).governanceVoteHash).bytes;
        UInt256 b = *(UInt256 *)((NSData*)((DSGovernanceVoteHashEntity*)obj2).governanceVoteHash).bytes;
        return uint256_sup(a,b)?NSOrderedAscending:NSOrderedDescending;
    }];
    self.knownGovernanceVoteHashes = rHashes;
    self.needsRequestsGovernanceVoteHashEntities = rNeedsRequestsHashEntities;
    NSLog(@"-> %lu - %lu",(unsigned long)[self.knownGovernanceVoteHashes count],(unsigned long)self.totalGovernanceVoteCount);
    NSUInteger countAroundNow = [self recentGovernanceVoteHashesCount];
    if ([self.knownGovernanceVoteHashes count] > self.totalGovernanceVoteCount) {
        [self.managedObjectContext performBlockAndWait:^{
            [DSGovernanceVoteHashEntity setContext:self.managedObjectContext];
            NSLog(@"countAroundNow -> %lu - %lu",(unsigned long)countAroundNow,(unsigned long)self.totalGovernanceVoteCount);
            if (countAroundNow == self.totalGovernanceVoteCount) {
                [DSGovernanceVoteHashEntity removeOldest:self.totalGovernanceVoteCount - [self.knownGovernanceVoteHashes count] onChain:self.chain.chainEntity];
                [self requestGovernanceVotesFromPeer:peer];
            }
        }];
    } else if (countAroundNow == self.totalGovernanceVoteCount) {
        NSLog(@"%@",@"All governance object hashes received");
        //we have all hashes, let's request objects.
        [self requestGovernanceVotesFromPeer:peer];
    }
}

- (void)peer:(DSPeer * )peer relayedGovernanceVote:(DSGovernanceVote * )governanceVote {
    NSData *governanceVoteHash = [NSData dataWithUInt256:governanceVote.governanceVoteHash];
    DSGovernanceVoteHashEntity * relatedHashEntity = nil;
    for (DSGovernanceVoteHashEntity * governanceVoteHashEntity in [self.requestGovernanceVoteHashEntities copy]) {
        if ([governanceVoteHashEntity.governanceVoteHash isEqual:governanceVoteHash]) {
            relatedHashEntity = governanceVoteHashEntity;
            [self.requestGovernanceVoteHashEntities removeObject:governanceVoteHashEntity];
            break;
        }
    }
    //NSAssert(relatedHashEntity, @"There needs to be a relatedHashEntity");
    if (!relatedHashEntity) return;
    [[DSGovernanceVoteEntity managedObject] setAttributesFromGovernanceVote:governanceVote forHashEntity:relatedHashEntity];
    [self.needsRequestsGovernanceVoteHashEntities removeObject:relatedHashEntity];
    [self.governanceVotes addObject:governanceVote];
    if (![self.requestGovernanceVoteHashEntities count]) {
        [self requestGovernanceVotesFromPeer:peer];
        [DSGovernanceVoteEntity saveContext];
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSGovernanceVotesDidChangeNotification object:self userInfo:nil];
        });
    }
}

@end
