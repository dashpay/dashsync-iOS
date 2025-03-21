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
//#import "DSQuorumEntryEntity+CoreDataClass.h"
#import "NSData+Dash.h"
#import "NSManagedObject+Sugar.h"

@implementation DSChainLockEntity

+ (instancetype)chainLockEntityForChainLock:(DSChainLock *)chainLock
                                  inContext:(NSManagedObjectContext *)context {
    DSMerkleBlockEntity *merkleBlockEntity = [DSMerkleBlockEntity merkleBlockEntityForBlockHash:chainLock.blockHashData inContext:context];
    if (!merkleBlockEntity) {
        return nil;
    }
    DSChainLockEntity *chainLockEntity = [DSChainLockEntity managedObjectInBlockedContext:context];
    chainLockEntity.validSignature = chainLock.signatureVerified;
    chainLockEntity.signature = chainLock.signatureData;
    chainLockEntity.merkleBlock = merkleBlockEntity;
//    chainLockEntity.quorum = [DSQuorumEntryEntity anyObjectInContext:context matching:@"quorumPublicKeyData == %@", chainLock.intendedQuorumPublicKey];
//    chainLockEntity.quorum = [chainLock.intendedQuorum matchingQuorumEntryEntityInContext:context]; //the quorum might not yet
    if (chainLock.signatureVerified) {
        
//        DSChainEntity *chainEntity = [chainLock.intendedQuorum.chain chainEntityInContext:context];
        DSChainEntity *chainEntity = [chainLock.chain chainEntityInContext:context];
        if (!chainEntity.lastChainLock || chainEntity.lastChainLock.merkleBlock.height < DChainLockBlockHeight(chainLock.lock)) {
            chainEntity.lastChainLock = chainLockEntity;
        }
    }

    return chainLockEntity;
}

- (DSChainLock *)chainLockForChain:(DSChain *)chain {
    return [[DSChainLock alloc] initWithBlockHash:self.merkleBlock.blockHash
                                           height:self.merkleBlock.height
                                        signature:self.signature
                                signatureVerified:TRUE
                                   quorumVerified:TRUE
                                          onChain:chain];
}

@end
