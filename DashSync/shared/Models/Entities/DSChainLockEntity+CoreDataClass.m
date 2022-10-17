//
//  DSChainLockEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 11/25/19.
//
//

#import "BigIntTypes.h"
#import "DSChain.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSChainLock.h"
#import "DSChainLockEntity+CoreDataClass.h"
#import "DSMerkleBlock.h"
#import "DSMerkleBlockEntity+CoreDataClass.h"
#import "DSQuorumEntry.h"
#import "DSQuorumEntryEntity+CoreDataClass.h"
#import "DSSimplifiedMasternodeEntry.h"
#import "NSData+Dash.h"
#import "NSManagedObject+Sugar.h"

@implementation DSChainLockEntity

+ (instancetype)chainLockEntityForChainLock:(DSChainLock *)chainLock inContext:(NSManagedObjectContext *)context {
    DSMerkleBlockEntity *merkleBlockEntity = [DSMerkleBlockEntity merkleBlockEntityForBlockHash:chainLock.blockHash inContext:context];
    if (!merkleBlockEntity) {
        return nil;
    }
    DSChainLockEntity *chainLockEntity = [DSChainLockEntity managedObjectInBlockedContext:context];
    chainLockEntity.validSignature = chainLock.signatureVerified;
    chainLockEntity.signature = [NSData dataWithUInt768:chainLock.signature];
    chainLockEntity.merkleBlock = merkleBlockEntity;
    chainLockEntity.quorum = [chainLock.intendedQuorum matchingQuorumEntryEntityInContext:context]; //the quorum might not yet
    if (chainLock.signatureVerified) {
        DSChainEntity *chainEntity = [chainLock.intendedQuorum.chain chainEntityInContext:context];
        if (!chainEntity.lastChainLock || chainEntity.lastChainLock.merkleBlock.height < chainLock.height) {
            chainEntity.lastChainLock = chainLockEntity;
        }
    }

    return chainLockEntity;
}

- (DSChainLock *)chainLockForChain:(DSChain *)chain {
    DSChainLock *chainLock = [[DSChainLock alloc] initWithBlockHash:self.merkleBlock.blockHash.UInt256 signature:self.signature.UInt768 signatureVerified:TRUE quorumVerified:TRUE onChain:chain];

    return chainLock;
}

@end
