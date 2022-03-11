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

#import "DSChain.h"
#import "DSChainCheckpoints.h"
#import "DSChainEntity+CoreDataClass.h"
#import "DSCheckpoint.h"
#import "DSMerkleBlock.h"
#import "DSMerkleBlockEntity+CoreDataClass.h"
#import "NSData+Dash.h"
#import "NSManagedObject+Sugar.h"

@interface DSChain (DSMigrationHelper)

+ (NSMutableArray *)createCheckpointsArrayFromCheckpoints:(checkpoint *)checkpoints count:(NSUInteger)checkpointCount;

@end

@interface DSMerkleBlockEntity6To7MigrationPolicyStorage : NSObject

@property (nonatomic, copy) NSDictionary<NSNumber *, DSCheckpoint *> *checkpoints;
@property (nonatomic, copy) NSArray<DSCheckpoint *> *checkpointsArray;
@property (nonatomic, strong) DSMerkleBlock *lastKnownSourceBlockWithCheckpoint;
@property (nonatomic, assign) uint32_t lastKnownSourceBlockHeight;

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

@property (nonatomic, copy) NSDictionary<NSNumber *, DSCheckpoint *> *checkpoints;
@property (nonatomic, copy) NSArray<DSCheckpoint *> *checkpointsArray;
@property (nonatomic, strong) DSMerkleBlock *lastKnownSourceBlockWithCheckpoint;
@property (nonatomic, assign) uint32_t lastKnownSourceBlockHeight;

@end

@implementation DSMerkleBlockEntity6To7MigrationPolicy

- (NSDictionary<NSNumber *, DSCheckpoint *> *)checkpoints {
    return [DSMerkleBlockEntity6To7MigrationPolicyStorage sharedInstance].checkpoints;
}

- (void)setCheckpoints:(NSDictionary<NSNumber *, DSCheckpoint *> *)checkpoints {
    [DSMerkleBlockEntity6To7MigrationPolicyStorage sharedInstance].checkpoints = checkpoints;
}

- (NSArray<DSCheckpoint *> *)checkpointsArray {
    return [DSMerkleBlockEntity6To7MigrationPolicyStorage sharedInstance].checkpointsArray;
}

- (void)setCheckpointsArray:(NSArray<DSCheckpoint *> *)checkpointsArray {
    [DSMerkleBlockEntity6To7MigrationPolicyStorage sharedInstance].checkpointsArray = checkpointsArray;
}

- (DSMerkleBlock *)lastKnownSourceBlockWithCheckpoint {
    return [DSMerkleBlockEntity6To7MigrationPolicyStorage sharedInstance].lastKnownSourceBlockWithCheckpoint;
}

- (void)setLastKnownSourceBlockWithCheckpoint:(DSMerkleBlock *)lastKnownSourceBlockWithCheckpoint {
    [DSMerkleBlockEntity6To7MigrationPolicyStorage sharedInstance].lastKnownSourceBlockWithCheckpoint = lastKnownSourceBlockWithCheckpoint;
}

- (uint32_t)lastKnownSourceBlockHeight {
    return [DSMerkleBlockEntity6To7MigrationPolicyStorage sharedInstance].lastKnownSourceBlockHeight;
}

- (void)setLastKnownSourceBlockHeight:(uint32_t)lastKnownSourceBlockHeight {
    [DSMerkleBlockEntity6To7MigrationPolicyStorage sharedInstance].lastKnownSourceBlockHeight = lastKnownSourceBlockHeight;
}


- (DSCheckpoint *)lastMainnetCheckpointOnOrBeforeHeight:(uint32_t)height {
    NSUInteger genesisHeight = 0;
    // if we don't have any blocks yet, use the latest checkpoint that's at least a week older than earliestKeyTime
    for (long i = self.checkpointsArray.count - 1; i >= genesisHeight; i--) {
        if (i == genesisHeight || (self.checkpointsArray[i].height <= height)) {
            return self.checkpointsArray[i];
        }
    }
    return nil;
}

- (BOOL)beginEntityMapping:(NSEntityMapping *)mapping manager:(NSMigrationManager *)manager error:(NSError **)error {
    BOOL result = [super beginEntityMapping:mapping manager:manager error:error];
    NSUInteger count = (sizeof(mainnet_checkpoint_array) / sizeof(*mainnet_checkpoint_array));
    NSArray<DSCheckpoint *> *checkpointsArray = [DSChain createCheckpointsArrayFromCheckpoints:mainnet_checkpoint_array
                                                                                         count:count];
    NSMutableDictionary<NSNumber *, DSCheckpoint *> *checkpoints = [NSMutableDictionary dictionary];
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
                                              error:(NSError *__autoreleasing _Nullable *)error {
    NSNumber *height = [sInstance valueForKey:@"height"];
    NSManagedObject *chainEntity = [sInstance valueForKey:@"chain"];
    NSParameterAssert(chainEntity);
    if (height != nil && [height intValue] != BLOCK_UNKNOWN_HEIGHT && [[chainEntity valueForKey:@"type"] intValue] == DSChainType_MainNet && [height intValue] > self.lastKnownSourceBlockHeight) {
        self.lastKnownSourceBlockHeight = [height unsignedIntValue];
    }

    return YES;
}

- (BOOL)endEntityMapping:(NSEntityMapping *)mapping manager:(NSMigrationManager *)manager error:(NSError **)error {
    if (self.lastKnownSourceBlockHeight && !self.lastKnownSourceBlockWithCheckpoint) {
        DSCheckpoint *lastCheckpoint = [self lastMainnetCheckpointOnOrBeforeHeight:self.lastKnownSourceBlockHeight];
        id chain = nil;
        self.lastKnownSourceBlockWithCheckpoint = [[DSMerkleBlock alloc] initWithCheckpoint:lastCheckpoint onChain:chain];
    }
    if (self.lastKnownSourceBlockWithCheckpoint) {
        DSChainEntity *chainEntity = [self chainEntityForType:DSChainType_MainNet inContext:manager.destinationContext];
        if (chainEntity) {
            [chainEntity setValue:uint256_data(self.lastKnownSourceBlockWithCheckpoint.blockHash) forKey:@"syncBlockHash"];
            [chainEntity setValue:@(self.lastKnownSourceBlockWithCheckpoint.height) forKey:@"syncBlockHeight"];
            [chainEntity setValue:@(self.lastKnownSourceBlockWithCheckpoint.timestamp) forKey:@"syncBlockTimestamp"];
            [chainEntity setValue:[self blockLocatorArrayForBlock:self.lastKnownSourceBlockWithCheckpoint] forKey:@"syncLocators"];
            [chainEntity setValue:uint256_data(self.lastKnownSourceBlockWithCheckpoint.chainWork) forKey:@"syncBlockChainWork"];
        }
    }
    return [super endEntityMapping:mapping manager:manager error:error];
}

- (NSArray<NSData *> *)blockLocatorArrayForBlock:(DSBlock *)block {
    NSMutableArray *locators = [NSMutableArray arrayWithObject:uint256_data(block.blockHash)];

    uint32_t lastHeight = block.height;
    DSCheckpoint *lastCheckpoint = nil;
    //then add the last checkpoint we know about previous to this block
    for (DSCheckpoint *checkpoint in self.checkpointsArray) {
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


- (DSChainEntity *)chainEntityForType:(DSChainType)type inContext:(NSManagedObjectContext *)context {
    NSFetchRequest *fetchRequest = [DSChainEntity fetchRequest];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"type = %d", type];
    NSError *error = nil;
    NSArray *objects = [context executeFetchRequest:fetchRequest error:&error];
    if (objects.count) {
        return objects.firstObject;
    }

    return nil;
}


@end
