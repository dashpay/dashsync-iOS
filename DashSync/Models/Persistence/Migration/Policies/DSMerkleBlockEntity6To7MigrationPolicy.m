//  
//  Created by Andrew Podkovyrin
//  Copyright © 2020 Dash Core Group. All rights reserved.
//
//  Licensed under the MIT License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://opensource.org/licenses/MIT
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "DSMerkleBlockEntity6To7MigrationPolicy.h"

#import "DSChainCheckpoints.h"
#import "DSChain.h"
#import "DSCheckpoint.h"
#import "NSData+Bitcoin.h"
#import "DSMerkleBlock.h"
#import "DSMerkleBlockEntity+CoreDataClass.h"
#import "DSChainEntity+CoreDataClass.h"

@interface DSChain (DSMigrationHelper)

+ (NSMutableArray *)createCheckpointsArrayFromCheckpoints:(checkpoint*)checkpoints count:(NSUInteger)checkpointCount;

@end

@interface DSMerkleBlockEntity6To7MigrationPolicyStorage : NSObject

@property (nonatomic, copy) NSDictionary <NSNumber *, DSCheckpoint *> *checkpoints;
@property (nonatomic, copy) NSArray <DSCheckpoint *> *checkpointsArray;
@property (nonatomic, strong) DSMerkleBlockEntity *lastBlockAdded;

@end

@implementation DSMerkleBlockEntity6To7MigrationPolicyStorage

+ (instancetype)sharedInstance {
    static DSMerkleBlockEntity6To7MigrationPolicyStorage *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] init];
    });
    return _sharedInstance;
}

@end

@interface DSMerkleBlockEntity6To7MigrationPolicy ()

@property (nonatomic, copy) NSDictionary <NSNumber *, DSCheckpoint *> *checkpoints;
@property (nonatomic, copy) NSArray <DSCheckpoint *> *checkpointsArray;
@property (nonatomic, strong) DSMerkleBlockEntity *lastBlockAdded;

@end

@implementation DSMerkleBlockEntity6To7MigrationPolicy

- (NSDictionary<NSNumber *,DSCheckpoint *> *)checkpoints {
    return [DSMerkleBlockEntity6To7MigrationPolicyStorage sharedInstance].checkpoints;
}

- (void)setCheckpoints:(NSDictionary<NSNumber *,DSCheckpoint *> *)checkpoints {
    [DSMerkleBlockEntity6To7MigrationPolicyStorage sharedInstance].checkpoints = checkpoints;
}

- (NSArray<DSCheckpoint *> *)checkpointsArray {
    return [DSMerkleBlockEntity6To7MigrationPolicyStorage sharedInstance].checkpointsArray;
}

- (void)setCheckpointsArray:(NSArray<DSCheckpoint *> *)checkpointsArray {
    [DSMerkleBlockEntity6To7MigrationPolicyStorage sharedInstance].checkpointsArray = checkpointsArray;
}

- (DSMerkleBlockEntity *)lastBlockAdded {
    return [DSMerkleBlockEntity6To7MigrationPolicyStorage sharedInstance].lastBlockAdded;
}

- (void)setLastBlockAdded:(DSMerkleBlockEntity *)lastBlockAdded {
    [DSMerkleBlockEntity6To7MigrationPolicyStorage sharedInstance].lastBlockAdded = lastBlockAdded;
}

- (BOOL)beginEntityMapping:(NSEntityMapping *)mapping manager:(NSMigrationManager *)manager error:(NSError **)error {
    BOOL result = [super beginEntityMapping:mapping manager:manager error:error];
    NSUInteger count = (sizeof(mainnet_checkpoint_array)/sizeof(*mainnet_checkpoint_array));
    NSArray <DSCheckpoint *> *checkpointsArray = [DSChain createCheckpointsArrayFromCheckpoints:mainnet_checkpoint_array
                                                                count:count];
    NSMutableDictionary <NSNumber *, DSCheckpoint *> *checkpoints = [NSMutableDictionary dictionary];
    for (DSCheckpoint *checkpoint in checkpointsArray) {
        checkpoints[@(checkpoint.height)] = checkpoint;
    }
    self.checkpoints = checkpoints;
    self.checkpointsArray = checkpointsArray;
    return result;
}

- (BOOL)createDestinationInstancesForSourceInstance:(NSManagedObject *)sInstance
                                      entityMapping:(NSEntityMapping *)mapping
                                            manager:(NSMigrationManager *)manager
                                              error:(NSError *__autoreleasing  _Nullable *)error {
    NSNumber *height = [sInstance valueForKey:@"height"];
    NSManagedObject *chainEntity = [sInstance valueForKey:@"chain"];
    NSParameterAssert(chainEntity);
    if (height != nil && [[chainEntity valueForKey:@"type"] intValue] == DSChainType_MainNet) {
        DSCheckpoint *checkpoint = self.checkpoints[height];
        if (checkpoint != nil) {
            BOOL result = [super createDestinationInstancesForSourceInstance:sInstance
                                                               entityMapping:mapping
                                                                     manager:manager
                                                                       error:error];
            if (result) {
                NSManagedObject *destination = [manager destinationInstancesForEntityMappingNamed:mapping.name sourceInstances:@[sInstance]].firstObject;
                NSParameterAssert(destination);
                [destination setValue:uint256_data(checkpoint.chainWork) forKey:@"chainWork"];
                
                if (self.lastBlockAdded == nil) {
                    self.lastBlockAdded = (DSMerkleBlockEntity *)destination;
                }
                else if ([[destination valueForKey:@"height"] intValue] > [[self.lastBlockAdded valueForKey:@"height"] intValue]) {
                    self.lastBlockAdded = (DSMerkleBlockEntity *)destination;
                }
            }
        }
    }
    
    return YES;
}

- (BOOL)endEntityMapping:(NSEntityMapping *)mapping manager:(NSMigrationManager *)manager error:(NSError **)error {
    DSChainEntity *chainEntity = [self chainEntityForType:DSChainType_MainNet inContext:manager.destinationContext];
    id chain = nil;
    DSMerkleBlock *block = nil;
    if (self.lastBlockAdded == nil) {
        DSCheckpoint *lastCheckpoint = self.checkpointsArray.lastObject;
        
        block = [[DSMerkleBlock alloc] initWithCheckpoint:lastCheckpoint onChain:chain];
        DSMerkleBlockEntity *entity = [[DSMerkleBlockEntity alloc] initWithContext:manager.destinationContext];
        [entity setAttributesFromBlock:block forChainEntity:chainEntity];
        self.lastBlockAdded = entity;
    }
    else {
        block = [[DSMerkleBlock alloc] initWithVersion:self.lastBlockAdded.version blockHash:self.lastBlockAdded.blockHash.UInt256 prevBlock:self.lastBlockAdded.prevBlock.UInt256 merkleRoot:self.lastBlockAdded.merkleRoot.UInt256
                                             timestamp:self.lastBlockAdded.timestamp target:self.lastBlockAdded.target chainWork:self.lastBlockAdded.chainWork.UInt256 nonce:self.lastBlockAdded.nonce
                                     totalTransactions:self.lastBlockAdded.totalTransactions hashes:self.lastBlockAdded.hashes flags:self.lastBlockAdded.flags height:self.lastBlockAdded.height chainLock:nil onChain:chain];
    }
    
    [chainEntity setValue:[self.lastBlockAdded.blockHash copy] forKey:@"syncBlockHash"];
    [chainEntity setValue:[self.lastBlockAdded valueForKey:@"height"] forKey:@"syncBlockHeight"];
    NSDate *date = [self.lastBlockAdded valueForKey:@"timestamp"];
    NSAssert([date isKindOfClass:NSDate.class], @"invalid type");
    [chainEntity setValue:@([date timeIntervalSince1970]) forKey:@"syncBlockTimestamp"];
    [chainEntity setValue:[self blockLocatorArrayForBlock:block] forKey:@"syncLocators"];
    
    return [super endEntityMapping:mapping manager:manager error:error];
}

- (NSArray <NSData*> *)blockLocatorArrayForBlock:(DSBlock*)block {
    NSMutableArray *locators = [NSMutableArray arrayWithObject:uint256_data(block.blockHash)];
    
    uint32_t lastHeight = block.height;
    DSCheckpoint * lastCheckpoint = nil;
    //then add the last checkpoint we know about previous to this block
    for (DSCheckpoint * checkpoint in self.checkpointsArray) {
        if (checkpoint.height < lastHeight && checkpoint.timestamp < block.timestamp) {
            lastCheckpoint = checkpoint;
        } else {
            break;
        }
    }
    if (lastCheckpoint) {
        [locators addObject:uint256_data(lastCheckpoint.blockHash)];
    }
    return locators;
}


- (DSChainEntity*)chainEntityForType:(DSChainType)type inContext:(NSManagedObjectContext*)context {
    NSFetchRequest *fetchRequest = [DSChainEntity fetchRequest];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"type = %d",type];
    NSError *error = nil;
    NSArray *objects = [context executeFetchRequest:fetchRequest error:&error];
    if (objects.count) {
        return objects.firstObject;
    }
    
    DSChainEntity * chainEntity = [[DSChainEntity alloc] initWithContext:context];
    chainEntity.type = type;
    return chainEntity;
}


@end
