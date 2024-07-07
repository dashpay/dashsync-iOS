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

#import <Foundation/Foundation.h>
#import "DSBlocksCache.h"
#import "DSChain+Checkpoints.h"
#import "DSChain+Protected.h"

@interface DSChain ()
@end

@implementation DSChain (Checkpoints)

// MARK: - Checkpoints

- (BOOL)blockHeightHasCheckpoint:(uint32_t)blockHeight {
    DSCheckpoint *checkpoint = [self lastCheckpointOnOrBeforeHeight:blockHeight];
    return (checkpoint.height == blockHeight);
}

- (DSCheckpoint *)lastCheckpoint {
    return [self.blocksCache.checkpointsCache lastCheckpoint];
}
- (uint32_t)lastCheckpointHeight {
    return [self.blocksCache.checkpointsCache lastCheckpoint].height;
}

- (DSCheckpoint *)lastCheckpointOnOrBeforeHeight:(uint32_t)height {
    return [self.blocksCache.checkpointsCache lastCheckpointOnOrBeforeHeight:height forChain:self];
}

- (DSCheckpoint *)lastCheckpointOnOrBeforeTimestamp:(NSTimeInterval)timestamp {
    return [self.blocksCache.checkpointsCache lastCheckpointOnOrBeforeTimestamp:timestamp forChain:self];
}

- (DSCheckpoint *_Nullable)lastCheckpointHavingMasternodeList {
    return [self.blocksCache.checkpointsCache lastCheckpointHavingMasternodeList];
}

- (DSCheckpoint *)checkpointForBlockHash:(UInt256)blockHash {
    return [self.blocksCache.checkpointsCache checkpointForBlockHash:blockHash];
}

- (DSCheckpoint *)checkpointForBlockHeight:(uint32_t)blockHeight {
    return [self.blocksCache.checkpointsCache checkpointForBlockHeight:blockHeight];
}

- (void)useCheckpointBeforeOrOnHeightForTerminalBlocksSync:(uint32_t)blockHeight {
    [self.blocksCache.checkpointsCache useOverrideForTerminalHeaders:[self lastCheckpointOnOrBeforeHeight:blockHeight]];
}

- (void)useCheckpointBeforeOrOnHeightForSyncingChainBlocks:(uint32_t)blockHeight {
    [self.blocksCache.checkpointsCache useOverrideForSyncHeaders:[self lastCheckpointOnOrBeforeHeight:blockHeight]];
}



@end
