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

#import "BigIntTypes.h"
#import "DSChain+Params.h"
#import "DSCheckpointsCache.h"
#import "DSKeyManager.h"
#import "NSData+Dash.h"
#import "NSMutableData+Dash.h"
#import "NSString+Bitcoin.h"

@interface DSCheckpointsCache ()
@property (nonatomic, strong) NSMutableDictionary<NSData *, DSCheckpoint *> *checkpointsByHashDictionary;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, DSCheckpoint *> *checkpointsByHeightDictionary;
@property (nonatomic, strong) NSArray<DSCheckpoint *> *checkpoints;
@property (nonatomic, strong) DSCheckpoint *terminalHeadersOverrideUseCheckpoint;
@property (nonatomic, strong) DSCheckpoint *syncHeadersOverrideUseCheckpoint;
@property (nonatomic, strong) DSCheckpoint *lastCheckpoint;
@property (nonatomic, assign) UInt256 genesisHash;

@end

@implementation DSCheckpointsCache

- (instancetype)initAsDevnetWithIdentifier:(DevnetType)devnetType
                         onProtocolVersion:(uint32_t)protocolVersion
                               checkpoints:(NSArray<DSCheckpoint *> *)checkpoints forChain:(DSChain *)chain {
    //for devnet the genesis checkpoint is really the second block
    if (!(self = [self init])) return nil;

    if (!checkpoints || ![checkpoints count]) {
        DSCheckpoint *genesisCheckpoint = [DSCheckpoint genesisDevnetCheckpoint];
        DSCheckpoint *secondCheckpoint = [self createDevNetGenesisBlockCheckpointForParentCheckpoint:genesisCheckpoint
                                                                                      withIdentifier:devnetType
                                                                                   onProtocolVersion:protocolVersion
                                                                                            forChain: chain];
        self.checkpoints = @[genesisCheckpoint, secondCheckpoint];
        self.genesisHash = secondCheckpoint.blockHash;
    } else {
        self.checkpoints = checkpoints;
        self.genesisHash = checkpoints[1].blockHash;
    }
    return self;
}

- (UInt256)blockHashForDevNetGenesisBlockWithVersion:(uint32_t)version 
                                            prevHash:(UInt256)prevHash
                                          merkleRoot:(UInt256)merkleRoot
                                           timestamp:(uint32_t)timestamp
                                              target:(uint32_t)target
                                               nonce:(uint32_t)nonce {
    NSMutableData *d = [NSMutableData data];
    [d appendUInt32:version];
    [d appendBytes:&prevHash length:sizeof(prevHash)];
    [d appendBytes:&merkleRoot length:sizeof(merkleRoot)];
    [d appendUInt32:timestamp];
    [d appendUInt32:target];
    [d appendUInt32:nonce];
    return [DSKeyManager x11:d];
}

- (DSCheckpoint *)createDevNetGenesisBlockCheckpointForParentCheckpoint:(DSCheckpoint *)checkpoint
                                                         withIdentifier:(DevnetType)identifier
                                                      onProtocolVersion:(uint32_t)protocolVersion
                                                               forChain: (DSChain *)chain {
    uint32_t nTime = checkpoint.timestamp + 1;
    uint32_t nBits = checkpoint.target;
    UInt256 fullTarget = setCompactLE(nBits);
    uint32_t nVersion = 4;
    UInt256 prevHash = checkpoint.blockHash;
    UInt256 merkleRoot = [DSTransaction devnetGenesisCoinbaseTxHash:identifier onProtocolVersion:protocolVersion forChain:chain];
    UInt256 chainWork = @"0400000000000000000000000000000000000000000000000000000000000000".hexToData.UInt256;
    uint32_t nonce = UINT32_MAX; //+1 => 0;
    UInt256 blockhash;
    do {
        nonce++; //should start at 0;
        blockhash = [self blockHashForDevNetGenesisBlockWithVersion:nVersion prevHash:prevHash merkleRoot:merkleRoot timestamp:nTime target:nBits nonce:nonce];
    } while (nonce < UINT32_MAX && uint256_sup(blockhash, fullTarget));
    DSCheckpoint *block2Checkpoint = [DSCheckpoint checkpointForHeight:1 blockHash:blockhash timestamp:nTime target:nBits merkleRoot:merkleRoot chainWork:chainWork masternodeListName:nil];
    return block2Checkpoint;
}


// MARK: - Checkpoints

- (DSCheckpoint *)lastCheckpoint {
    if (!_lastCheckpoint) {
        _lastCheckpoint = [[self checkpoints] lastObject];
    }
    return _lastCheckpoint;
}

- (DSCheckpoint *_Nullable)lastCheckpointForTerminalHeaders {
    return self.terminalHeadersOverrideUseCheckpoint ? self.terminalHeadersOverrideUseCheckpoint : [self lastCheckpoint];
}

- (DSCheckpoint *)lastCheckpointOnOrBeforeHeight:(uint32_t)height forChain:(DSChain *)chain {
    BOOL isNotSyncing = ![chain syncsBlockchain];
    NSUInteger genesisHeight = [chain isDevnetAny] ? 1 : 0;
    // if we don't have any blocks yet, use the latest checkpoint that's at least a week older than earliestKeyTime
    for (long i = self.checkpoints.count - 1; i >= genesisHeight; i--) {
        if (i == genesisHeight || isNotSyncing || (self.checkpoints[i].height <= height)) {
            return self.checkpoints[i];
        }
    }
    return nil;
}

- (DSCheckpoint *_Nullable)lastCheckpointBeforeHeight:(uint32_t)height {
    DSCheckpoint *lastCheckpoint = nil;
    for (DSCheckpoint *checkpoint in self.checkpoints) {
        if (checkpoint.height < height) {
            lastCheckpoint = checkpoint;
        } else {
            break;
        }
    }
    return lastCheckpoint;
}

- (DSCheckpoint *)lastCheckpointOnOrBeforeTimestamp:(NSTimeInterval)timestamp forChain:(DSChain *)chain {
    BOOL isNotSyncing = ![chain syncsBlockchain];
    NSUInteger genesisHeight = [chain isDevnetAny] ? 1 : 0;
    // if we don't have any blocks yet, use the latest checkpoint that's at least a week older than earliestKeyTime
    for (long i = self.checkpoints.count - 1; i >= genesisHeight; i--) {
        if (i == genesisHeight || isNotSyncing || (self.checkpoints[i].timestamp <= timestamp)) {
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
    return _checkpointsByHeightDictionary[numbers.lastObject];
}

- (DSCheckpoint *)checkpointForBlockHash:(UInt256)blockHash {
    return [_checkpointsByHashDictionary objectForKey:uint256_data(blockHash)];
}

- (DSCheckpoint *)checkpointForBlockHeight:(uint32_t)blockHeight {
    return [_checkpointsByHeightDictionary objectForKey:@(blockHeight)];
}

- (void)addCheckpoint:(DSCheckpoint *)checkpoint {
    _checkpointsByHeightDictionary[@(checkpoint.height)] = checkpoint;
    _checkpointsByHashDictionary[uint256_data(checkpoint.blockHash)] = checkpoint;
}
- (DSCheckpoint *_Nullable)checkpointForHeight:(uint32_t)height {
    DSCheckpoint *checkpoint = [_checkpointsByHeightDictionary objectForKey:@(height)];
    return checkpoint;
}
- (uint32_t)checkpointHeightForBlockHash:(UInt256)blockhash {
    DSCheckpoint *checkpoint = [_checkpointsByHashDictionary objectForKey:uint256_data(blockhash)];
    if (checkpoint) {
        return checkpoint.height;
    }
    return 0;
}

- (NSTimeInterval)lastCheckpointTimestamp {
    return self.checkpoints.lastObject.timestamp;
}

- (BOOL)isGenesisExist {
    return uint256_is_not_zero([self genesisHash]);
}
- (NSUInteger)hash {
    return self.genesisHash.u64[0];
}
- (BOOL)isEqual:(id)obj {
    return self == obj || ([obj isKindOfClass:[DSCheckpointsCache class]] && uint256_eq([obj genesisHash], _genesisHash));
}

- (instancetype)initWithFirstCheckpoint:(NSArray *)checkpoints {
    if (!(self = [self init])) return nil;
    self.checkpoints = checkpoints;
    self.genesisHash = self.checkpoints[0].blockHash;
    _checkpointsByHashDictionary = [NSMutableDictionary dictionary];
    _checkpointsByHeightDictionary = [NSMutableDictionary dictionary];
    return self;
}
- (instancetype)initWithDevnet:(DevnetType)devnetType 
                   checkpoints:(NSArray<DSCheckpoint *> *)checkpoints
             onProtocolVersion:(uint32_t)protocolVersion
                      forChain:(DSChain *)chain {
    if (!(self = [self init])) return nil;
    if (!checkpoints || ![checkpoints count]) {
        DSCheckpoint *genesisCheckpoint = [DSCheckpoint genesisDevnetCheckpoint];
        DSCheckpoint *secondCheckpoint = [self createDevNetGenesisBlockCheckpointForParentCheckpoint:genesisCheckpoint withIdentifier:devnetType onProtocolVersion:protocolVersion forChain:chain];
        self.checkpoints = @[genesisCheckpoint, secondCheckpoint];
        self.genesisHash = secondCheckpoint.blockHash;
    } else {
        self.checkpoints = checkpoints;
        self.genesisHash = checkpoints[1].blockHash;
    }
    return self;
}

- (void)useOverrideForSyncHeaders:(DSCheckpoint *)checkpoint {
    self.syncHeadersOverrideUseCheckpoint = checkpoint;
}
- (void)useOverrideForTerminalHeaders:(DSCheckpoint *)checkpoint {
    self.terminalHeadersOverrideUseCheckpoint = checkpoint;
}


@end
