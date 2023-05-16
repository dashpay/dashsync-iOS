//
//  Created by Vladimir Pirogov
//  Copyright © 2021 Dash Core Group. All rights reserved.
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

#import "dash_shared_core.h"
#import "DSChain.h"
#import "DSMasternodeProcessorContext.h"
#import "DSMasternodeList.h"
#import "DSMasternodeManager.h"
#import "DSMnDiffProcessingResult.h"
#import "DSQRInfoProcessingResult.h"
#import "DSQuorumEntry.h"
#import "DSSimplifiedMasternodeEntry.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DSMasternodeManager (Mndiff)

/// Rust FFI callbacks
MasternodeList *getMasternodeListByBlockHash(uint8_t (*block_hash)[32], const void *context);
bool saveMasternodeList(uint8_t (*block_hash)[32], MasternodeList *masternode_list, const void *context);
void destroyMasternodeList(MasternodeList *masternode_list);
void destroyHash(uint8_t *block_hash);
uint32_t getBlockHeightByHash(uint8_t (*block_hash)[32], const void *context);
uint8_t *getBlockHashByHeight(uint32_t block_height, const void *context);
uint8_t *getMerkleRootByHash(uint8_t (*block_hash)[32], const void *context);
LLMQSnapshot *getLLMQSnapshotByBlockHash(uint8_t (*block_hash)[32], const void *context);
bool saveLLMQSnapshot(uint8_t (*block_hash)[32], LLMQSnapshot *snapshot, const void *context);
void destroyLLMQSnapshot(LLMQSnapshot *snapshot);
void addInsightForBlockHash(uint8_t (*block_hash)[32], const void *context);
ProcessingError shouldProcessDiffWithRange(uint8_t (*base_block_hash)[32], uint8_t (*block_hash)[32], const void *context);

+ (MasternodeProcessor *)registerProcessor;
+ (void)unregisterProcessor:(MasternodeProcessor *)processor;

+ (MasternodeProcessorCache *)createProcessorCache;
+ (void)destroyProcessorCache:(MasternodeProcessorCache *)processorCache;

- (DSMnDiffProcessingResult *)processMasternodeDiffMessage:(NSData *)message withContext:(DSMasternodeProcessorContext *)context;

- (void)processMasternodeDiffWith:(NSData *)message context:(DSMasternodeProcessorContext *)context completion:(void (^)(DSMnDiffProcessingResult *result))completion;
- (void)processQRInfoWith:(NSData *)message context:(DSMasternodeProcessorContext *)context completion:(void (^)(DSQRInfoProcessingResult *result))completion;

- (void)clearProcessorCache;
- (void)removeMasternodeListFromCacheAtBlockHash:(UInt256)blockHash;
- (void)removeSnapshotFromCacheAtBlockHash:(UInt256)blockHash;

@end


NS_ASSUME_NONNULL_END
