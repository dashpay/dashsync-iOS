//  
//  Created by Vladimir Pirogov
//  Copyright © 2024 Dash Core Group. All rights reserved.
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

#import "DSChain+Checkpoint.h"
#import "DSChain+Params.h"
#import "NSData+Dash.h"
#import "NSString+Bitcoin.h"
#import <objc/runtime.h>

NSString const *checkpointsKey = @"checkpointsKey";
NSString const *lastCheckpointKey = @"lastCheckpointKey";
NSString const *checkpointsByHashDictionaryKey = @"checkpointsByHashDictionaryKey";
NSString const *checkpointsByHeightDictionaryKey = @"checkpointsByHeightDictionaryKey";
NSString const *terminalHeadersOverrideUseCheckpointKey = @"terminalHeadersOverrideUseCheckpointKey";
NSString const *syncHeadersOverrideUseCheckpointKey = @"syncHeadersOverrideUseCheckpointKey";

@implementation DSChain (Checkpoint)

// MARK: - Checkpoints
- (NSArray<DSCheckpoint *> *)checkpoints {
    return objc_getAssociatedObject(self, &checkpointsKey);
}
- (void)setCheckpoints:(NSArray<DSCheckpoint *> *)checkpoints {
    objc_setAssociatedObject(self, &checkpointsKey, checkpoints, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSMutableDictionary<NSData *,DSCheckpoint *> *)checkpointsByHashDictionary {
    return objc_getAssociatedObject(self, &checkpointsByHashDictionaryKey);
}
- (void)setCheckpointsByHashDictionary:(NSMutableDictionary<NSData *,DSCheckpoint *> *)checkpointsByHashDictionary {
    objc_setAssociatedObject(self, &checkpointsByHashDictionaryKey, checkpointsByHashDictionary, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSMutableDictionary<NSNumber *, DSCheckpoint *> *)checkpointsByHeightDictionary {
    return objc_getAssociatedObject(self, &checkpointsByHeightDictionaryKey);
}
- (void)setCheckpointsByHeightDictionary:(NSMutableDictionary<NSNumber *, DSCheckpoint *> *)checkpointsByHeightDictionary {
    objc_setAssociatedObject(self, &checkpointsByHeightDictionaryKey, checkpointsByHeightDictionary, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)blockHeightHasCheckpoint:(uint32_t)blockHeight {
    DSCheckpoint *checkpoint = [self lastCheckpointOnOrBeforeHeight:blockHeight];
    return (checkpoint.height == blockHeight);
}

- (DSCheckpoint *)lastCheckpoint {
    DSCheckpoint *maybeLastCheckpoint = objc_getAssociatedObject(self, &lastCheckpointKey);
    if (!maybeLastCheckpoint) {
        maybeLastCheckpoint = [[self checkpoints] lastObject];
        objc_setAssociatedObject(self, &lastCheckpointKey, maybeLastCheckpoint, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return maybeLastCheckpoint;
}

- (DSCheckpoint *)lastTerminalCheckpoint {
    return self.terminalHeadersOverrideUseCheckpoint ? self.terminalHeadersOverrideUseCheckpoint : [self lastCheckpoint];
    
}

- (DSCheckpoint *)lastCheckpointOnOrBeforeHeight:(uint32_t)height {
    NSUInteger genesisHeight = [self isDevnetAny] ? 1 : 0;
    // if we don't have any blocks yet, use the latest checkpoint that's at least a week older than earliestKeyTime
    for (long i = self.checkpoints.count - 1; i >= genesisHeight; i--) {
        if (i == genesisHeight || ![self syncsBlockchain] || (self.checkpoints[i].height <= height)) {
            return self.checkpoints[i];
        }
    }
    return nil;
}

- (DSCheckpoint *)lastCheckpointOnOrBeforeTimestamp:(NSTimeInterval)timestamp {
    NSUInteger genesisHeight = [self isDevnetAny] ? 1 : 0;
    // if we don't have any blocks yet, use the latest checkpoint that's at least a week older than earliestKeyTime
    for (long i = self.checkpoints.count - 1; i >= genesisHeight; i--) {
        if (i == genesisHeight || ![self syncsBlockchain] || (self.checkpoints[i].timestamp <= timestamp)) {
            return self.checkpoints[i];
        }
    }
    return nil;
}

- (DSCheckpoint *_Nullable)lastCheckpointHavingMasternodeList {
    NSSet *set = [self.checkpointsByHeightDictionary keysOfEntriesPassingTest:^BOOL(id _Nonnull key, id _Nonnull obj, BOOL *_Nonnull stop) {
        DSCheckpoint *checkpoint = (DSCheckpoint *)obj;
        return (checkpoint.masternodeListName && ![checkpoint.masternodeListName isEqualToString:@""]);
    }];
    NSArray *numbers = [[set allObjects] sortedArrayUsingSelector:@selector(compare:)];
    if (!numbers.count) return nil;
    return self.checkpointsByHeightDictionary[numbers.lastObject];
}

- (DSCheckpoint *)checkpointForBlockHash:(UInt256)blockHash {
    return [self.checkpointsByHashDictionary objectForKey:uint256_data(blockHash)];
}

- (DSCheckpoint *)checkpointForBlockHeight:(uint32_t)blockHeight {
    return [self.checkpointsByHeightDictionary objectForKey:@(blockHeight)];
}

- (DSCheckpoint *)terminalHeadersOverrideUseCheckpoint {
    return objc_getAssociatedObject(self, &terminalHeadersOverrideUseCheckpointKey);
}

- (void)useCheckpointBeforeOrOnHeightForTerminalBlocksSync:(uint32_t)blockHeight {
    objc_setAssociatedObject(self, &terminalHeadersOverrideUseCheckpointKey, [self lastCheckpointOnOrBeforeHeight:blockHeight], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (DSCheckpoint *)syncHeadersOverrideUseCheckpoint {
    return objc_getAssociatedObject(self, &syncHeadersOverrideUseCheckpointKey);
}

- (void)useCheckpointBeforeOrOnHeightForSyncingChainBlocks:(uint32_t)blockHeight {
    objc_setAssociatedObject(self, &syncHeadersOverrideUseCheckpointKey, [self lastCheckpointOnOrBeforeHeight:blockHeight], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}


+ (NSMutableArray *)createCheckpointsArrayFromCheckpoints:(checkpoint *)checkpoints count:(NSUInteger)checkpointCount {
    NSMutableArray *checkpointMutableArray = [NSMutableArray array];
    for (int i = 0; i < checkpointCount; i++) {
        checkpoint cpt = checkpoints[i];
        NSString *merkleRootString = NSStringFromPtr(cpt.merkleRoot);
        NSString *chainWorkString = NSStringFromPtr(cpt.chainWork);
        uint32_t blockHeight = cpt.height;
        NSString *blockHashHex = NSStringFromPtr(cpt.checkpointHash);
        UInt256 blockHash = blockHashHex.hexToData.reverse.UInt256;
        UInt256 chainWork = chainWorkString.hexToData.reverse.UInt256;
        UInt256 merkleRoot = [merkleRootString isEqualToString:@""] ? UINT256_ZERO : merkleRootString.hexToData.reverse.UInt256;
        DSCheckpoint *checkpoint = [DSCheckpoint checkpointForHeight:blockHeight
                                                           blockHash:blockHash
                                                           timestamp:cpt.timestamp
                                                              target:cpt.target
                                                          merkleRoot:merkleRoot
                                                           chainWork:chainWork
                                                  masternodeListName:NSStringFromPtr(cpt.masternodeListPath)];
        [checkpointMutableArray addObject:checkpoint];
    }
    return [checkpointMutableArray copy];
}

- (dash_spv_masternode_processor_processing_processor_DiffConfig *_Nullable)createDiffConfig {
    dash_spv_masternode_processor_processing_processor_DiffConfig *diff_config = NULL;
    if ([self isMainnet]) {
        NSString *bundlePath = [[NSBundle bundleForClass:self.class] pathForResource:@"DashSync" ofType:@"bundle"];
        NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
        NSString *filePath = [bundle pathForResource:@"mn_list_diff_0_2227096" ofType:@"dat"];
        NSData *data = [NSData dataWithContentsOfFile:filePath];

        diff_config = dash_spv_masternode_processor_processing_processor_DiffConfig_ctor(bytes_ctor(data), 2227096);
    } else if ([self isTestnet]) {
        NSString *bundlePath = [[NSBundle bundleForClass:self.class] pathForResource:@"DashSync" ofType:@"bundle"];
        NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
        NSString *filePath = [bundle pathForResource:@"MNL_TESTNET_0_1220040" ofType:@"dat"];
        NSData *data = [NSData dataWithContentsOfFile:filePath];
        diff_config = dash_spv_masternode_processor_processing_processor_DiffConfig_ctor(bytes_ctor(data), 1220040);
    }
    return diff_config;
}

@end
