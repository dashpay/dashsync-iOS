//
//  DSGovernanceSyncManager.m
//  DashSync
//
//  Created by Sam Westrich on 6/12/18.
//

#import "DSGovernanceSyncManager.h"
#import "DSGovernanceObject.h"
#import "DSMasternodePing.h"
#import "DSGovernanceObjectEntity+CoreDataProperties.h"
#import "DSGovernanceObjectHashEntity+CoreDataProperties.h"
#import "NSManagedObject+Sugar.h"
#import "DSChain.h"
#import "DSPeer.h"
#import "DSChainEntity+CoreDataProperties.h"
#import "NSData+Dash.h"

#define REQUEST_GOVERNANCE_OBJECT_COUNT 500

@interface DSGovernanceSyncManager()

@property (nonatomic,strong) DSChain * chain;
@property (nonatomic,strong) NSOrderedSet * knownHashes;
@property (nonatomic,readonly) NSOrderedSet * fulfilledRequestsHashEntities;
@property (nonatomic,strong) NSMutableArray *needsRequestsHashEntities;
@property (nonatomic,strong) NSMutableArray * requestHashEntities;
@property (nonatomic,strong) NSMutableArray<DSGovernanceObject *> * governanceObjects;
@property (nonatomic,assign) NSUInteger governanceObjectsCount;
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

//-(NSArray*)masternodeHashes {
//
//}

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

-(NSOrderedSet*)knownHashes {
    if (_knownHashes) return _knownHashes;
    
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
        self.knownHashes = [rHashes copy];
    }];
    return _knownHashes;
}

-(NSMutableArray*)needsRequestsHashEntities {
    if (_needsRequestsHashEntities) return _needsRequestsHashEntities;
    
    [self.managedObjectContext performBlockAndWait:^{
        [DSGovernanceObjectHashEntity setContext:self.managedObjectContext];
        NSFetchRequest *request = DSGovernanceObjectHashEntity.fetchReq;
        [request setPredicate:[NSPredicate predicateWithFormat:@"chain = %@ && governanceObject == nil",self.chain.chainEntity]];
        [request setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"governanceObjectHash" ascending:TRUE]]];
        self.needsRequestsHashEntities = [[DSGovernanceObjectHashEntity fetchObjects:request] mutableCopy];
        
    }];
    return _needsRequestsHashEntities;
}

-(NSArray*)needsRequestsHashes {
    __block NSMutableArray * mArray = [NSMutableArray array];
    [self.managedObjectContext performBlockAndWait:^{
        [DSGovernanceObjectHashEntity setContext:self.managedObjectContext];
        for (DSGovernanceObjectHashEntity * governanceObjectHashEntity in self.needsRequestsHashEntities) {
            [mArray addObject:governanceObjectHashEntity.governanceObjectHash];
        }
    }];
    return [mArray copy];
}

-(NSOrderedSet*)fulfilledRequestsHashEntities {
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

-(NSOrderedSet*)fulfilledRequestsHashes {
    NSMutableOrderedSet * mOrderedSet = [NSMutableOrderedSet orderedSet];
    for (DSGovernanceObjectHashEntity * governanceObjectHashEntity in self.fulfilledRequestsHashEntities) {
        [mOrderedSet addObject:governanceObjectHashEntity.governanceObjectHash];
    }
    return [mOrderedSet copy];
}

-(void)requestGovernanceObjectsFromPeer:(DSPeer*)peer {
    if (![self.needsRequestsHashEntities count]) {
        //we are done syncing
        return;
    }
    self.requestHashEntities = [[self.needsRequestsHashEntities subarrayWithRange:NSMakeRange(0, MIN(self.needsRequestsHashes.count,REQUEST_GOVERNANCE_OBJECT_COUNT))] mutableCopy];
    NSMutableArray * requestHashes = [NSMutableArray array];
    for (DSGovernanceObjectHashEntity * governanceObjectHashEntity in self.requestHashEntities) {
        [requestHashes addObject:governanceObjectHashEntity.governanceObjectHash];
    }
    [peer sendGetdataMessageWithGovernanceObjectHashes:requestHashes];
}

- (void)peer:(DSPeer *)peer hasGovernanceObjectHashes:(NSSet*)governanceObjectHashes {
    NSLog(@"peer relayed masternode broadcasts");
    NSMutableOrderedSet * hashesToInsert = [[NSOrderedSet orderedSetWithSet:governanceObjectHashes] mutableCopy];
    NSMutableOrderedSet * hashesToUpdate = [[NSOrderedSet orderedSetWithSet:governanceObjectHashes] mutableCopy];
    NSMutableOrderedSet * hashesToQuery = [[NSOrderedSet orderedSetWithSet:governanceObjectHashes] mutableCopy];
    NSMutableOrderedSet <NSData*> * rHashes = [_knownHashes mutableCopy];
    [hashesToInsert minusOrderedSet:self.knownHashes];
    [hashesToUpdate minusOrderedSet:hashesToInsert];
    [hashesToQuery minusOrderedSet:self.fulfilledRequestsHashes];
    NSMutableOrderedSet * hashesToQueryFromInsert = [hashesToQuery mutableCopy];
    [hashesToQueryFromInsert intersectOrderedSet:hashesToInsert];
    NSMutableArray * hashEntitiesToQuery = [NSMutableArray array];
    NSMutableArray <NSData*> * rNeedsRequestsHashEntities = [self.needsRequestsHashEntities mutableCopy];
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
    self.knownHashes = rHashes;
    self.needsRequestsHashEntities = rNeedsRequestsHashEntities;
    NSLog(@"-> %lu - %lu",(unsigned long)[self.knownHashes count],(unsigned long)self.totalGovernanceObjectCount);
    NSUInteger countAroundNow = [self recentGovernanceObjectHashesCount];
    if ([self.knownHashes count] > self.totalGovernanceObjectCount) {
        [self.managedObjectContext performBlockAndWait:^{
            [DSGovernanceObjectHashEntity setContext:self.managedObjectContext];
            NSLog(@"countAroundNow -> %lu - %lu",(unsigned long)countAroundNow,(unsigned long)self.totalGovernanceObjectCount);
            if (countAroundNow == self.totalGovernanceObjectCount) {
                [DSGovernanceObjectHashEntity removeOldest:self.totalGovernanceObjectCount - [self.knownHashes count] onChain:self.chain.chainEntity];
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
    for (DSGovernanceObjectHashEntity * governanceObjectHashEntity in [self.requestHashEntities copy]) {
        if ([governanceObjectHashEntity.governanceObjectHash isEqual:governanceObjectHash]) {
            relatedHashEntity = governanceObjectHashEntity;
            [self.requestHashEntities removeObject:governanceObjectHashEntity];
            break;
        }
    }
    //NSAssert(relatedHashEntity, @"There needs to be a relatedHashEntity");
    if (!relatedHashEntity) return;
    [[DSGovernanceObjectEntity managedObject] setAttributesFromGovernanceObject:governanceObject forHashEntity:relatedHashEntity];
    [self.needsRequestsHashEntities removeObject:relatedHashEntity];
    [self.governanceObjects addObject:governanceObject];
    if (![self.requestHashEntities count]) {
        [self requestGovernanceObjectsFromPeer:peer];
        [DSGovernanceObjectEntity saveContext];
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DSGovernanceObjectListDidChangeNotification object:self userInfo:nil];
        });
    }
}

- (void)peer:(DSPeer * _Nullable)peer relayedMasternodePing:(DSMasternodePing*  _Nonnull)masternodePing {
    
}

//-(void)saveBroadcast:(DSGovernanceObject*)governanceObject forHashEntity:(DSGovernanceObjectHashEntity*)governanceObjectHashEntity {
//    NSLog(@"[DSMasternodeManager] save broadcasts");
//    if ([self.governanceObjects count]) {
//
//        NSAssert(self.managedObjectContext == governanceObjectHashEntity.managedObjectContext, @"must be same contexts");
//
//
//
//
//
//    }
//}


@end
