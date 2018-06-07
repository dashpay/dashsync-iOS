//
//  DSMasternodeBroadcastEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 6/4/18.
//
//

#import "DSMasternodeBroadcastEntity+CoreDataClass.h"

@implementation DSMasternodeBroadcastEntity

- (void)setAttributesFromMasternodeBroadcast:(DSMasternodeBroadcast *)masternodeBroadcast forChain:(DSChainEntity*)chainEntity {
    [self.managedObjectContext performBlockAndWait:^{
        self.utxoHash = [NSData dataWithBytes:masternodeBroadcast.utxo.hash.u8 length:sizeof(UInt256)];
        self.utxoIndex = (uint32_t)masternodeBroadcast.utxo.n;
        self.address = masternodeBroadcast.ipAddress.u8[2];
        self.mnbHash = [NSData dataWithBytes:masternodeBroadcast.masternodeBroadcastHash.u8 length:sizeof(UInt256)];
        self.port = masternodeBroadcast.port;
        self.protocolVersion = masternodeBroadcast.protocolVersion;
        self.signature = masternodeBroadcast.signature;
        self.signatureTimestamp = masternodeBroadcast.signatureTimestamp;
        self.publicKey = masternodeBroadcast.publicKey;
        self.chain = chainEntity;
    }];
}

@end
