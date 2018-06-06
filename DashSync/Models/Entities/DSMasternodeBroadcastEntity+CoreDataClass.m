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
    self.utxoIndex = masternodeBroadcast.utxo.n;
        self.address = masternodeBroadcast.ipAddress;
        self.mnbHash = masternodeBroadcast.mnb
    }
}

     @property (nonatomic, assign) uint32_t address;
     @property (nullable, nonatomic, retain) NSData *mnbHash;
     @property (nonatomic, assign) uint16_t port;
     @property (nonatomic, assign) uint32_t protocolVersion;
     @property (nonatomic, assign) uint64_t signatureTimestamp;
     @property (nonatomic, assign) uint32_t utxoIndex;
     @property (nullable, nonatomic, retain) NSData *utxoHash;
     @property (nullable, nonatomic, retain) NSData *publicKey;
     @property (nullable, nonatomic, retain) NSData *signature;
     @property (nonatomic, retain) DSChainEntity * chain;

- (instancetype)setAttributesFromBlock:(DSMerkleBlock *)block
    [self.managedObjectContext performBlockAndWait:^{
        self.blockHash = [NSData dataWithBytes:block.blockHash.u8 length:sizeof(UInt256)];
        self.version = block.version;
        self.prevBlock = [NSData dataWithBytes:block.prevBlock.u8 length:sizeof(UInt256)];
        self.merkleRoot = [NSData dataWithBytes:block.merkleRoot.u8 length:sizeof(UInt256)];
        self.timestamp = block.timestamp - NSTimeIntervalSince1970;
        self.target = block.target;
        self.nonce = block.nonce;
        self.totalTransactions = block.totalTransactions;
        self.hashes = [NSData dataWithData:block.hashes];
        self.flags = [NSData dataWithData:block.flags];
        self.height = block.height;
        self.chain = chainEntity;
    }];
    
    return self;
}


@end
