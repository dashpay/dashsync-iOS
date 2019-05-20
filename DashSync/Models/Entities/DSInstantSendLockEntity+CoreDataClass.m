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
        [DSTransactionEntity setContext:self.managedObjectContext];
        [DSQuorumEntryEntity setContext:self.managedObjectContext];
        self.validSignature = instantSendTransactionLock.signatureVerified;
        self.signature = [NSData dataWithUInt768:instantSendTransactionLock.signature];
        DSTransactionEntity * transactionEntity = [DSTransactionEntity anyObjectMatching:@"transactionHash.txHash == %@", uint256_data(instantSendTransactionLock.transactionHash)];
        self.transaction = transactionEntity;
        self.quorum = instantSendTransactionLock.intendedQuorum.matchingQuorumEntryEntity;
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
