//
//  DSInstantSendLockEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 5/19/19.
//
//

#import "BigIntTypes.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSInstantSendLockEntity+CoreDataClass.h"
#import "DSInstantSendTransactionLock.h"
#import "DSQuorumEntryEntity+CoreDataClass.h"
#import "DSTransactionEntity+CoreDataClass.h"
#import "DSTransactionHashEntity+CoreDataClass.m"
#import "DSTxInputEntity+CoreDataClass.h"
#import "NSData+Dash.h"
#import "NSManagedObject+Sugar.h"

@implementation DSInstantSendLockEntity

+ (DSInstantSendLockEntity *)instantSendLockEntityFromInstantSendLock:(DSInstantSendTransactionLock *)instantSendTransactionLock inContext:(NSManagedObjectContext *)context {
    DSTransactionEntity *transactionEntity = [DSTransactionEntity anyObjectInContext:context matching:@"transactionHash.txHash == %@", uint256_data(instantSendTransactionLock.transactionHash)];
    if (transactionEntity) {
        DSInstantSendLockEntity *entity = [DSInstantSendLockEntity managedObjectInContext:context];
        entity.validSignature = instantSendTransactionLock.signatureVerified;
        entity.signature = [NSData dataWithUInt768:instantSendTransactionLock.signature];

        NSAssert(transactionEntity, @"transaction must exist");
        entity.transaction = transactionEntity;
        
        entity.quorum = [DSQuorumEntryEntity anyObjectInContext:context matching:@"quorumPublicKeyData == %@", instantSendTransactionLock.intendedQuorumPublicKey];
//        entity.quorum = [instantSendTransactionLock.intendedQuorum matchingQuorumEntryEntityInContext:context]; //the quorum might not yet
    }

    return nil;
}

- (instancetype)setAttributesFromInstantSendTransactionLock:(DSInstantSendTransactionLock *)instantSendTransactionLock {
    [self.managedObjectContext performBlockAndWait:^{
        self.validSignature = instantSendTransactionLock.signatureVerified;
        self.signature = [NSData dataWithUInt768:instantSendTransactionLock.signature];
        DSTransactionEntity *transactionEntity = [DSTransactionEntity anyObjectInContext:self.managedObjectContext matching:@"transactionHash.txHash == %@", uint256_data(instantSendTransactionLock.transactionHash)];
        NSAssert(transactionEntity, @"transaction must exist");
        self.transaction = transactionEntity;
        self.quorum = [DSQuorumEntryEntity anyObjectInContext:self.managedObjectContext matching:@"quorumPublicKeyData == %@", instantSendTransactionLock.intendedQuorumPublicKey];
//        self.quorum = [instantSendTransactionLock.intendedQuorum matchingQuorumEntryEntityInContext:self.managedObjectContext]; //the quorum might not yet
    }];

    return self;
}

- (DSInstantSendTransactionLock *)instantSendTransactionLockForChain:(DSChain *)chain {
    NSMutableArray *inputOutpoints = [NSMutableArray array];
    for (DSTxInputEntity *input in self.transaction.inputs) {
        [inputOutpoints addObject:dsutxo_data(input.outpoint)];
    }
    DSInstantSendTransactionLock *instantSendTransactionLock = [[DSInstantSendTransactionLock alloc] initWithTransactionHash:self.transaction.transactionHash.txHash.UInt256 withInputOutpoints:inputOutpoints signature:self.signature.UInt768 signatureVerified:TRUE quorumVerified:TRUE onChain:chain];

    return instantSendTransactionLock;
}

@end
