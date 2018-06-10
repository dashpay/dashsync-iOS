//
//  DSMasternodeBroadcastEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 6/4/18.
//
//

#import "DSMasternodeBroadcastEntity+CoreDataClass.h"
#import "DSMasternodeBroadcastHashEntity+CoreDataClass.h"
#import "NSManagedObject+Sugar.h"
#import "DSChainEntity+CoreDataClass.h"
#import "NSData+Dash.h"

@implementation DSMasternodeBroadcastEntity

- (void)setAttributesFromMasternodeBroadcast:(DSMasternodeBroadcast *)masternodeBroadcast forChain:(DSChainEntity*)chainEntity {
    [self.managedObjectContext performBlockAndWait:^{
        NSData * data = [NSData dataWithUInt256:masternodeBroadcast.masternodeBroadcastHash];
        DSMasternodeBroadcastHashEntity * hashEntity = [[DSMasternodeBroadcastHashEntity objectsMatching:@"chain == %@ && masternodeBroadcastHash = %@",chainEntity,data] firstObject];
        NSAssert(hashEntity,@"hashEntity needs to exist");
        self.utxoHash = [NSData dataWithBytes:masternodeBroadcast.utxo.hash.u8 length:sizeof(UInt256)];
        self.utxoIndex = (uint32_t)masternodeBroadcast.utxo.n;
        self.address = masternodeBroadcast.ipAddress.u8[2];
        self.masternodeBroadcastHash = hashEntity;
        self.port = masternodeBroadcast.port;
        self.protocolVersion = masternodeBroadcast.protocolVersion;
        self.signature = masternodeBroadcast.signature;
        self.signatureTimestamp = masternodeBroadcast.signatureTimestamp;
        self.publicKey = masternodeBroadcast.publicKey;
    }];
}

+ (NSUInteger)countForChain:(DSChainEntity*)chain {
    __block NSUInteger count = 0;
    [chain.managedObjectContext performBlockAndWait:^{
        NSFetchRequest * fetchRequest = [DSMasternodeBroadcastEntity fetchReq];
        [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"chain = %@",chain]];
        count = [DSMasternodeBroadcastEntity countObjects:fetchRequest];
    }];
    return count;
}


@end
