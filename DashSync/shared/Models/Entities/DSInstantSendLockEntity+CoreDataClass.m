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
#import "DSTransactionEntity+CoreDataClass.h"
#import "DSTransactionHashEntity+CoreDataClass.h"
#import "DSTxInputEntity+CoreDataClass.h"
#import "NSData+Dash.h"
#import "NSManagedObject+Sugar.h"

@implementation DSInstantSendLockEntity

+ (DSInstantSendLockEntity *)instantSendLockEntityFromInstantSendLock:(DSInstantSendTransactionLock *)instantSendTransactionLock inContext:(NSManagedObjectContext *)context {
    DSTransactionEntity *transactionEntity = [DSTransactionEntity anyObjectInContext:context matching:@"transactionHash.txHash == %@", instantSendTransactionLock.transactionHashData];
    if (transactionEntity) {
        DSInstantSendLockEntity *entity = [DSInstantSendLockEntity managedObjectInContext:context];
        entity.validSignature = instantSendTransactionLock.signatureVerified;
        entity.signature = instantSendTransactionLock.signatureData;
        entity.cycleHash = instantSendTransactionLock.cycleHashData;
        NSAssert(transactionEntity, @"transaction must exist");
        entity.transaction = transactionEntity;
    }
    return nil;
}

- (instancetype)setAttributesFromInstantSendTransactionLock:(DSInstantSendTransactionLock *)instantSendTransactionLock {
    [self.managedObjectContext performBlockAndWait:^{
        self.validSignature = instantSendTransactionLock.signatureVerified;
        self.signature = instantSendTransactionLock.signatureData;
        self.cycleHash = instantSendTransactionLock.cycleHashData;
        DSTransactionEntity *transactionEntity = [DSTransactionEntity anyObjectInContext:self.managedObjectContext matching:@"transactionHash.txHash == %@", instantSendTransactionLock.transactionHashData];
        NSAssert(transactionEntity, @"transaction must exist");
        self.transaction = transactionEntity;
    }];

    return self;
}

- (DSInstantSendTransactionLock *)instantSendTransactionLockForChain:(DSChain *)chain {
    NSMutableArray *inputOutpoints = [NSMutableArray array];
    for (DSTxInputEntity *input in self.transaction.inputs) {
        [inputOutpoints addObject:dsutxo_data(input.outpoint)];
    }
    return [[DSInstantSendTransactionLock alloc] initWithTransactionHash:self.transaction.transactionHash.txHash
                                                      withInputOutpoints:inputOutpoints
                                                                 version:self.version
                                                               signature:self.signature
                                                               cycleHash:self.cycleHash
                                                       signatureVerified:TRUE
                                                          quorumVerified:TRUE
                                                                 onChain:chain];
}

@end
