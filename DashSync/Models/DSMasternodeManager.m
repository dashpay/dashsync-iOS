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
#import "NSManagedObject+Sugar.h"
#import "DSChain.h"

@interface DSMasternodeManager()

@property (nonatomic,strong) DSChain * chain;
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

-(NSArray*)masternodeHashes {
    
}

-(void)loadMasternodes:(NSUInteger)count {
    NSFetchRequest * fetchRequest = [[DSMasternodeBroadcastEntity fetchRequest] copy];
    [fetchRequest setFetchLimit:count];
        NSArray * masternodeBroadcastEntities = [DSMasternodeBroadcastEntity fetchObjects:fetchRequest];
    for (DSMasternodeBroadcastEntity * masternodeBroadcastEntity in masternodeBroadcastEntities) {
        DSUTXO utxo = dsutxo_obj(masternodeBroadcastEntity.utxo);
        DSMasternodeBroadcast * masternodeBroadcast = [[DSMasternodeBroadcast alloc] initWithUTXO:utxo ipAddress:masternodeBroadcastEntity.address port:masternodeBroadcastEntity.port protocolVersion:masternodeBroadcastEntity.protocolVersion publicKey:masternodeBroadcastEntity. signature:<#(NSData * _Nonnull)#> signatureTimestamp:masternodeBroadcastEntity.signature];
        [_masternodeBroadcasts addObject:masternodeBroadcast];
    }
}

- (void)peer:(DSPeer * )peer relayedMasternodeBroadcast:(DSMasternodeBroadcast * )masternodeBroadcast {
    
}

@end
