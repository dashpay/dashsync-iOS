//
//  DSInstantSendLockEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 5/19/19.
//
//

#import "DSInstantSendLockEntity+CoreDataClass.h"
#import "DSSimplifiedMasternodeEntry.h"
#import "DSTransactionEntity+CoreDataClass.h"
#import "DSTxInputEntity+CoreDataClass.h"
#import "DSQuorumEntryEntity+CoreDataClass.h"
#import "DSTransactionHashEntity+CoreDataClass.m"
#import "NSManagedObject+Sugar.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSInstantSendTransactionLock.h"
#import "BigIntTypes.h"
#import "NSData+Bitcoin.h"
#import "DSQuorumEntry.h"

@implementation DSInstantSendLockEntity

- (instancetype)setAttributesFromInstantSendTransactionLock:(DSInstantSendTransactionLock *)instantSendTransactionLock
{
    [self.managedObjectContext performBlockAndWait:^{
        self.validSignature = instantSendTransactionLock.signatureVerified;
        self.signature = [NSData dataWithUInt768:instantSendTransactionLock.signature];
        DSTransactionEntity * transactionEntity = [DSTransactionEntity anyObjectInContext:self.managedObjectContext matching:@"transactionHash.txHash == %@", uint256_data(instantSendTransactionLock.transactionHash)];
        NSAssert(transactionEntity, @"transaction must exist");
        self.transaction = transactionEntity;
        self.quorum = [instantSendTransactionLock.intendedQuorum matchingQuorumEntryEntityInContext:self.managedObjectContext];//the quorum might not yet
    }];
    
    return self;
}

- (DSInstantSendTransactionLock *)instantSendTransactionLockForChain:(DSChain*)chain
{
    NSMutableArray * inputOutpoints = [NSMutableArray array];
    for (DSTxInputEntity * input in self.transaction.inputs) {
        [inputOutpoints addObject:dsutxo_data(input.outpoint)];
    }
    DSInstantSendTransactionLock * instantSendTransactionLock = [[DSInstantSendTransactionLock alloc] initWithTransactionHash:self.transaction.transactionHash.txHash.UInt256 withInputOutpoints:inputOutpoints signatureVerified:TRUE quorumVerified:TRUE onChain:chain];
    
    return instantSendTransactionLock;
}

@end
