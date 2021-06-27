//
//  DSChainEntity+CoreDataClass.m
//
//
//  Created by Sam Westrich on 5/20/18.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "DSChain+Protected.h"
#import "DSChainEntity+CoreDataProperties.h"
#import "DSChainLockEntity+CoreDataProperties.h"
#import "DSCheckpoint.h"
#import "DSCompatibilityArrayValueTransformer.h"
#import "DSPeerManager.h"
#import "NSData+Bitcoin.h"
#import "NSManagedObject+Sugar.h"
#import "NSString+Dash.h"

@interface DSChainEntity ()

@property (nonatomic, strong) DSChain *cachedChain;

@end

@implementation DSChainEntity

@synthesize cachedChain;

- (instancetype)setAttributesFromChain:(DSChain *)chain {
    self.type = chain.chainType;
    self.totalGovernanceObjectsCount = chain.totalGovernanceObjectsCount;
    return self;
}

- (DSChain *)chain {
    if (self.cachedChain) {
        return self.cachedChain;
    }
    __block DSChainType type;
    __block NSString *devnetIdentifier;
    __block NSData *data;
    __block uint32_t totalGovernanceObjectsCount;
    __block UInt256 baseBlockHash;
    __block UInt256 lastPersistedChainSyncBlockHash;
    __block UInt256 lastPersistedChainSyncBlockChainWork;
    __block uint32_t lastPersistedChainSyncBlockHeight;
    __block NSTimeInterval lastPersistedChainSyncBlockTimestamp;
    __block DSChainLock *lastChainLock;

    __block NSArray *lastPersistedChainSyncLocators;
    [self.managedObjectContext performBlockAndWait:^{
        type = self.type;
        devnetIdentifier = self.devnetIdentifier;
        data = self.checkpoints;
        totalGovernanceObjectsCount = self.totalGovernanceObjectsCount;
        baseBlockHash = self.baseBlockHash.UInt256;
        lastPersistedChainSyncBlockHash = self.syncBlockHash.UInt256;
        lastPersistedChainSyncBlockChainWork = self.syncBlockChainWork.UInt256;
        lastPersistedChainSyncBlockHeight = self.syncBlockHeight;
        lastPersistedChainSyncLocators = self.syncLocators;
        lastPersistedChainSyncBlockTimestamp = self.syncBlockTimestamp;
    }];
    DSChain *chain = nil;
    if (type == DSChainType_MainNet) {
        chain = [DSChain mainnet];
    } else if (type == DSChainType_TestNet) {
        chain = [DSChain testnet];
    } else if (type == DSChainType_DevNet) {
        if ([DSChain devnetWithIdentifier:devnetIdentifier]) {
            chain = [DSChain devnetWithIdentifier:devnetIdentifier];
        } else {
            NSError *checkpointRetrievalError = nil;
            NSArray *checkpointArray = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSArray class] fromData:data error:&checkpointRetrievalError];
            chain = [DSChain recoverKnownDevnetWithIdentifier:devnetIdentifier withCheckpoints:checkpointRetrievalError ? @[] : checkpointArray performSetup:YES];
        }
    } else {
        NSAssert(FALSE, @"Unknown DSChainType");
    }
    [self.managedObjectContext performBlockAndWait:^{
        lastChainLock = [self.lastChainLock chainLockForChain:chain];
    }];

    // This fixes an issue after migration (6 -> 7)
    // After we set syncLocators in DSMerkleBlockEntity6To7MigrationPolicy for some reason
    // CoreData returns them as a NSData
    if ([lastPersistedChainSyncLocators isKindOfClass:NSData.class]) {
        NSError *unarchiveError = nil;
        if (@available(iOS 11.0, *)) {
            id object = [NSKeyedUnarchiver unarchivedObjectOfClasses:[NSSet setWithArray:@[[NSArray class], [NSData class]]] fromData:(NSData *)lastPersistedChainSyncLocators error:&unarchiveError];
            NSAssert(unarchiveError == nil, @"Failed transforming data to object %@", unarchiveError);
            lastPersistedChainSyncLocators = object;
        } else {
            NSAssert(NO, @"not supported");
        }
    }

    chain.lastChainLock = lastChainLock;
    chain.lastPersistedChainSyncLocators = lastPersistedChainSyncLocators;
    chain.lastPersistedChainSyncBlockHeight = lastPersistedChainSyncBlockHeight;
    chain.lastPersistedChainSyncBlockHash = lastPersistedChainSyncBlockHash;
    chain.lastPersistedChainSyncBlockTimestamp = lastPersistedChainSyncBlockTimestamp;
    self.cachedChain = chain;
    return chain;
}

+ (DSChainEntity *)chainEntityForType:(DSChainType)type devnetIdentifier:(NSString *)devnetIdentifier checkpoints:(NSArray *)checkpoints inContext:(NSManagedObjectContext *)context {
    NSArray *objects = [DSChainEntity objectsForPredicate:[NSPredicate predicateWithFormat:@"type = %d && ((type != %d) || devnetIdentifier = %@)", type, DSChainType_DevNet, devnetIdentifier] inContext:context];
    if (objects.count) {
        NSAssert(objects.count == 1, @"There should only ever be 1 chain for either mainnet, testnet, or a devnet Identifier");
        if (objects.count > 1) {
            //This is very bad, just remove all above 1
            for (int i = 1; i < objects.count; i++) {
                DSChainEntity *chainEntityToRemove = objects[i];
                [context deleteObject:chainEntityToRemove];
                [context ds_save];
                DSLog(@"Removing extra chain entity of type %d", type);
            }
        }
        DSChainEntity *chainEntity = objects[0];
        if (devnetIdentifier) {
            NSError *error = nil;
            NSArray *knownCheckpoints = [NSKeyedUnarchiver unarchivedObjectOfClasses:[NSSet setWithArray:@[[NSArray class], [DSCheckpoint class]]] fromData:[chainEntity checkpoints] error:&error];
            if (error != nil || checkpoints.count > knownCheckpoints.count) {
                NSData *archivedCheckpoints = [NSKeyedArchiver archivedDataWithRootObject:checkpoints requiringSecureCoding:YES error:&error];
                NSAssert(error == nil, @"There should not be an error when decrypting checkpoints");
                if (!error) {
                    chainEntity.checkpoints = archivedCheckpoints;
                }
            }
        } else {
            chainEntity.checkpoints = nil;
        }
        return chainEntity;
    }

    DSChainEntity *chainEntity = [self managedObjectInBlockedContext:context];
    chainEntity.type = type;
    chainEntity.devnetIdentifier = devnetIdentifier;
    if (checkpoints && devnetIdentifier) {
        NSError *error = nil;
        NSData *archivedCheckpoints = [NSKeyedArchiver archivedDataWithRootObject:checkpoints requiringSecureCoding:NO error:&error];
        NSAssert(error == nil, @"There should not be an error when decrypting checkpoints");
        if (!error) {
            chainEntity.checkpoints = archivedCheckpoints;
        }
    }
    return chainEntity;
}

@end
