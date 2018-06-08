//
//  DSMasternodeManager.m
//  DashSync
//
//  Created by Sam Westrich on 6/7/18.
//

#import "DSMasternodeManager.h"
#import "DSMasternodeBroadcast.h"
#import "DSMasternodePing.h"
#import "DSMasternodeBroadcastEntity+CoreDataProperties.h"
#import "DSMasternodeBroadcastHashEntity+CoreDataProperties.h"
#import "NSManagedObject+Sugar.h"
#import "DSChain.h"
#import "DSPeer.h"
#import "NSData+Dash.h"

#define REQUEST_MASTERNODE_BROADCAST_COUNT 500

@interface DSMasternodeManager()

@property (nonatomic,strong) DSChain * chain;
@property (nonatomic,strong) NSOrderedSet * knownHashes, * needsRequestsHashes;
@property (nonatomic,strong) NSMutableArray * requestHashes;
@property (nonatomic,strong) NSMutableArray<DSMasternodeBroadcast *> * masternodeBroadcasts;
@property (nonatomic, strong) NSMutableDictionary * masternodeSyncCountInfo;

@end

@implementation DSMasternodeManager

- (instancetype)initWithChain:(id)chain
{
    if (! (self = [super init])) return nil;
    _chain = chain;
    _masternodeBroadcasts = [NSMutableArray array];
    self.masternodeSyncCountInfo = [NSMutableDictionary dictionary];

    return self;
}

//-(NSArray*)masternodeHashes {
//
//}

-(void)loadMasternodes:(NSUInteger)count {
    NSFetchRequest * fetchRequest = [[DSMasternodeBroadcastEntity fetchRequest] copy];
    [fetchRequest setFetchLimit:count];
        NSArray * masternodeBroadcastEntities = [DSMasternodeBroadcastEntity fetchObjects:fetchRequest];
    for (DSMasternodeBroadcastEntity * masternodeBroadcastEntity in masternodeBroadcastEntities) {
        DSUTXO utxo;
        utxo.hash = *(UInt256 *)masternodeBroadcastEntity.utxoHash.bytes;
        utxo.n = masternodeBroadcastEntity.utxoIndex;
        UInt128 ipv6address = UINT128_ZERO;
        ipv6address.u32[3] = masternodeBroadcastEntity.address;
        DSMasternodeBroadcast * masternodeBroadcast = [[DSMasternodeBroadcast alloc] initWithUTXO:utxo ipAddress:ipv6address port:masternodeBroadcastEntity.port protocolVersion:masternodeBroadcastEntity.protocolVersion publicKey:masternodeBroadcastEntity.publicKey signature:masternodeBroadcastEntity.signature signatureTimestamp:masternodeBroadcastEntity.signatureTimestamp onChain:self.chain];
        [_masternodeBroadcasts addObject:masternodeBroadcast];
    }
}

-(NSOrderedSet*)knownHashes {
    if (_knownHashes) return _knownHashes;
    
    [[DSMasternodeBroadcastHashEntity context] performBlockAndWait:^{
        NSFetchRequest *request = DSMasternodeBroadcastHashEntity.fetchReq;
        [request setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"masternodeBroadcastHash" ascending:TRUE]]];
        NSArray<DSMasternodeBroadcastHashEntity *> * knownMasternodeBroadcastHashEntities = [DSMasternodeBroadcastHashEntity fetchObjects:request];
        NSMutableOrderedSet <NSData*> * rHashes = [NSMutableOrderedSet orderedSetWithCapacity:knownMasternodeBroadcastHashEntities.count];
        for (DSMasternodeBroadcastHashEntity * knownMasternodeBroadcastHashEntity in knownMasternodeBroadcastHashEntities) {
            NSData * hash = knownMasternodeBroadcastHashEntity.masternodeBroadcastHash;
            [rHashes addObject:hash];
        }
        self.knownHashes = [rHashes copy];
    }];
    return _knownHashes;
}

-(NSOrderedSet*)needsRequestsHashes {
    if (_needsRequestsHashes) return _needsRequestsHashes;
    
    [[DSMasternodeBroadcastHashEntity context] performBlockAndWait:^{
        NSFetchRequest *request = DSMasternodeBroadcastHashEntity.fetchReq;
        [request setPredicate:[NSPredicate predicateWithFormat:@"masternodeBroadcast == nil"]];
        [request setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"masternodeBroadcastHash" ascending:TRUE]]];
        NSArray<DSMasternodeBroadcastHashEntity *> * needsRequestsHashEntities = [DSMasternodeBroadcastHashEntity fetchObjects:request];
        NSMutableOrderedSet <NSData*> * rHashes = [NSMutableOrderedSet orderedSetWithCapacity:needsRequestsHashEntities.count];
        for (DSMasternodeBroadcastHashEntity * knownMasternodeBroadcastHashEntity in needsRequestsHashEntities) {
            NSData * hash = knownMasternodeBroadcastHashEntity.masternodeBroadcastHash;
            [rHashes addObject:hash];
        }
        self.needsRequestsHashes = [rHashes copy];
    }];
    return _needsRequestsHashes;
}

-(void)requestMasternodeBroadcastsFromPeer:(DSPeer*)peer {
    if (![self.needsRequestsHashes count]) {
        //we are done syncing
        return;
    }
    self.requestHashes = [[[self.needsRequestsHashes array] subarrayWithRange:NSMakeRange(0, MIN(self.needsRequestsHashes.count,REQUEST_MASTERNODE_BROADCAST_COUNT))] mutableCopy];
    [peer sendGetdataMessageWithMasternodeBroadcastHashes:_requestHashes];
}

- (void)peer:(DSPeer *)peer hasMasternodeBroadcastHashes:(NSSet*)masternodeBroadcastHashes {
    NSMutableOrderedSet * hashesToInsert = [[NSOrderedSet orderedSetWithSet:masternodeBroadcastHashes] mutableCopy];
    NSMutableOrderedSet <NSData*> * rHashes = [_knownHashes mutableCopy];
    [hashesToInsert minusOrderedSet:self.knownHashes];
    if ([hashesToInsert count]) {
    [[DSMasternodeBroadcastHashEntity context] performBlockAndWait:^{
        [DSMasternodeBroadcastHashEntity masternodeBroadcastHashEntitiesWithHashes:hashesToInsert];
        [DSMasternodeBroadcastHashEntity saveContext];
    }];
        [rHashes addObjectsFromArray:[hashesToInsert array]];
        [rHashes sortUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
            UInt256 a = *(UInt256 *)((NSData*)obj1).bytes;
            UInt256 b = *(UInt256 *)((NSData*)obj2).bytes;
            return uint256_sup(a,b)?NSOrderedAscending:NSOrderedDescending;
        }];
    }
    

    
    NSMutableOrderedSet <NSData*> * rNeedsRequestsHashes = [self.needsRequestsHashes mutableCopy];
    [rNeedsRequestsHashes addObjectsFromArray:[hashesToInsert array]];
    [rNeedsRequestsHashes sortUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        UInt256 a = *(UInt256 *)((NSData*)obj1).bytes;
        UInt256 b = *(UInt256 *)((NSData*)obj2).bytes;
        return uint256_sup(a,b)?NSOrderedAscending:NSOrderedDescending;
    }];
    self.knownHashes = rHashes;
    self.needsRequestsHashes = rNeedsRequestsHashes;
    if ([self.knownHashes count] == [self countForMasternodeSyncCountInfo:DSMasternodeSyncCountInfo_List]) {
        NSLog(@"%@",@"All masternode broadcast hashes received");
        //we have all hashes, let's request objects.
        [self requestMasternodeBroadcastsFromPeer:peer];
    }
}

- (void)peer:(DSPeer * )peer relayedMasternodeBroadcast:(DSMasternodeBroadcast * )masternodeBroadcast {
    NSData *masternodeBroadcastHash = [NSData dataWithUInt256:masternodeBroadcast.masternodeBroadcastHash];
    if ([self.requestHashes containsObject:masternodeBroadcastHash]) {
        [self.requestHashes removeObject:masternodeBroadcastHash];
        NSLog(@"%d",_requestHashes.count);
    }
    [self.masternodeBroadcasts addObject:masternodeBroadcast];
    if (![self.requestHashes count]) {
        [self saveBroadcasts];
        [self requestMasternodeBroadcastsFromPeer:peer];
    }
}

- (void)peer:(DSPeer * _Nullable)peer relayedMasternodePing:(DSMasternodePing*  _Nonnull)masternodePing {
    
}

-(void)saveBroadcasts {
        NSLog(@"[DSMasternodeManager] save broadcasts");
        [[DSMasternodeBroadcastEntity context] performBlock:^{

//                NSArray<DSMasternodeBroadcastEntity *> * recentOrphans = [DSMasternodeBroadcastEntity objectsMatching:@"(chain == %@) && (height > %u) && !(blockHash in %@) ",self.delegateQueueChainEntity,startHeight,blocks.allKeys];
//                if ([recentOrphans count])  NSLog(@"%lu recent orphans will be removed from disk",(unsigned long)[recentOrphans count]);
//                [DSMasternodeBroadcastEntity deleteObjects:recentOrphans];
//
            DSChainEntity * chainEntity = self.chain.chainEntity;
            for (DSMasternodeBroadcast *masternodeBroadcast in self.masternodeBroadcasts) {
                @autoreleasepool {
                    [[DSMasternodeBroadcastEntity managedObject] setAttributesFromMasternodeBroadcast:masternodeBroadcast forChain:chainEntity];
                }
            }
            
            [DSMasternodeBroadcastEntity saveContext];
        }];
    }

// MARK: - Masternodes

- (uint32_t)countForMasternodeSyncCountInfo:(DSMasternodeSyncCountInfo)masternodeSyncCountInfo {
    if (![self.masternodeSyncCountInfo objectForKey:@(masternodeSyncCountInfo)]) return 0;
    return (uint32_t)[[self.masternodeSyncCountInfo objectForKey:@(masternodeSyncCountInfo)] unsignedLongValue];
}

-(void)setCount:(uint32_t)count forMasternodeSyncCountInfo:(DSMasternodeSyncCountInfo)masternodeSyncCountInfo {
    [self.masternodeSyncCountInfo setObject:@(count) forKey:@(masternodeSyncCountInfo)];
}

@end
