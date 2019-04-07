//
//  DSInstantSendLockEntity+CoreDataClass.m
//  DashSync
//
//  Created by Sam Westrich on 4/7/19.
//
//

#import "DSInstantSendLockEntity+CoreDataClass.h"
#import "DSInstantSendTransactionLock.h"
#import "BigIntTypes.h"
#import "NSMutableData+Dash.h"
#import "NSData+Bitcoin.h"
#import "DSSimplifiedMasternodeEntry.h"
#import "DSTransactionEntity+CoreDataClass.h"
#import "NSManagedObject+Sugar.h"
#import "DSChainEntity+CoreDataClass.h"

@implementation DSInstantSendLockEntity

- (instancetype)setAttributesFromInstantSendTransactionLock:(DSInstantSendTransactionLock *)instantSendTransactionLock
{
    [self.managedObjectContext performBlockAndWait:^{
        self.transactionHash = uint256_data(instantSendTransactionLock.transactionHash);
        self.instantSendLockHash = uint256_data(instantSendTransactionLock.instantSendTransactionLockHash);
        self.fromValidQuorum = instantSendTransactionLock.quorumVerified;
        self.signature = [NSData dataWithUInt768:instantSendTransactionLock.signature];
        self.chain = instantSendTransactionLock.chain.chainEntity;
        DSTransactionEntity * transactionEntity = [DSTransactionEntity anyObjectMatching:@"transactionHash.txHash == %@", uint256_data(instantSendTransactionLock.transactionHash)];
        self.transaction = transactionEntity;
        self.inputsOutpoints = instantSendTransactionLock.inputOutpoints;
    }];
    
    return self;
}

- (DSInstantSendTransactionLock *)instantSendTransactionLockForChain:(DSChain*)chain
{
    if (!chain) chain = [self.chain chain];
    
    DSInstantSendTransactionLock * instantSendTransactionLock = [[DSInstantSendTransactionLock alloc] initWithTransactionHash:self.transactionHash.UInt256 withInputOutpoints:self.inputsOutpoints signatureVerified:TRUE quorumVerified:TRUE onChain:chain];
    
    return instantSendTransactionLock;
}

@end
