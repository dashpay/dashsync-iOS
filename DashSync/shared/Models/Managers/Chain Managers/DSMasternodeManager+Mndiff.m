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

#import "DSBlock.h"
#import "DSBlockOperation.h"
#import "DSChain+Params.h"
#import "DSChain+Protected.h"
#import "DSChainManager.h"
#import "DSInsightManager.h"
#import "DSMasternodeList+Mndiff.h"
#import "DSMasternodeManager+Mndiff.h"
#import "DSMasternodeManager+Protected.h"
#import "DSMerkleBlock.h"
#import "DSQuorumEntry+Mndiff.h"
#import "DSQuorumSnapshot+Mndiff.h"
#import "DSSimplifiedMasternodeEntry+Mndiff.h"
#import "NSData+Dash.h"

#define AS_OBJC(context) ((__bridge DSMasternodeProcessorContext *)(context))
#define AS_RUST(context) ((__bridge void *)(context))

@implementation DSMasternodeManager (Mndiff)


///
/// MARK: Rust FFI callbacks
///
MasternodeList *getMasternodeListByBlockHash(uint8_t (*block_hash)[32], const void *context) {
    UInt256 blockHash = *((UInt256 *)block_hash);
    MasternodeList *c_list = NULL;
    @synchronized (context) {
        DSMasternodeList *list = [AS_OBJC(context) masternodeListForBlockHash:blockHash];
        if (list) {
            c_list = [list ffi_malloc];
        }
    }
    processor_destroy_block_hash(block_hash);
    return c_list;
}

bool saveMasternodeList(uint8_t (*block_hash)[32], MasternodeList *masternode_list, const void *context) {
    UInt256 blockHash = *((UInt256 *)block_hash);
    BOOL saved = NO;
    @synchronized (context) {
        DSMasternodeProcessorContext *processorContext = AS_OBJC(context);
        DSMasternodeList *masternodeList = [DSMasternodeList masternodeListWith:masternode_list onChain:processorContext.chain];
        saved = [processorContext saveMasternodeList:masternodeList forBlockHash:blockHash];
    }
    processor_destroy_block_hash(block_hash);
    processor_destroy_masternode_list(masternode_list);
    return saved;
}

void destroyMasternodeList(MasternodeList *masternode_list) {
    [DSMasternodeList ffi_free:masternode_list];
}

void destroyU8(uint8_t *block_hash) { // big uint
    if (block_hash) {
        free(block_hash);
    }
}

uint32_t getBlockHeightByHash(uint8_t (*block_hash)[32], const void *context) {
    UInt256 blockHash = *((UInt256 *)block_hash);
    uint32_t block_height = UINT32_MAX;
    @synchronized (context) {
        block_height = [AS_OBJC(context) blockHeightForBlockHash:blockHash];
    }
    processor_destroy_block_hash(block_hash);
    return block_height;
}

uint8_t *getBlockHashByHeight(uint32_t block_height, const void *context) {
    uint8_t (*block_hash)[32] = NULL;
    @synchronized (context) {
        DSBlock *block = [AS_OBJC(context) blockForBlockHeight:block_height];
        if (block) {
            block_hash = uint256_malloc(block.blockHash);
        }
    }
    return (uint8_t *)block_hash;
}


uint8_t *getMerkleRootByHash(uint8_t (*block_hash)[32], const void *context) {
    UInt256 blockHash = *((UInt256 *)block_hash);
    uint8_t (*merkle_root)[32] = NULL;
    @synchronized (context) {
        UInt256 merkleRoot = [AS_OBJC(context) merkleRootForBlockHash:blockHash];
        merkle_root = uint256_malloc(merkleRoot);
    }
    processor_destroy_block_hash(block_hash);
    return (uint8_t *)merkle_root;
}

LLMQSnapshot *getLLMQSnapshotByBlockHash(uint8_t (*block_hash)[32], const void *context) {
    UInt256 blockHash = *((UInt256 *)block_hash);
    LLMQSnapshot *c_snapshot = NULL;
    @synchronized (context) {
        DSQuorumSnapshot *snapshot = [AS_OBJC(context) quorumSnapshotForBlockHash:blockHash];
        if (snapshot) {
            c_snapshot = [snapshot ffi_malloc];
        }
    }
    processor_destroy_block_hash(block_hash);
    return c_snapshot;
}


bool saveLLMQSnapshot(uint8_t (*block_hash)[32], LLMQSnapshot *snapshot, const void *context) {
    UInt256 blockHash = *((UInt256 *)block_hash);
    BOOL saved = NO;
    @synchronized (context) {
        saved = [AS_OBJC(context) saveQuorumSnapshot:[DSQuorumSnapshot quorumSnapshotWith:snapshot forBlockHash:blockHash]];
    }
    processor_destroy_block_hash(block_hash);
    processor_destroy_llmq_snapshot(snapshot);
    return saved;
}
void destroyLLMQSnapshot(LLMQSnapshot *snapshot) {
    [DSQuorumSnapshot ffi_free:snapshot];
}

uint8_t *getCLSignatureByBlockHash(uint8_t (*block_hash)[32], const void *context) {
    UInt256 blockHash = *((UInt256 *)block_hash);
    uint8_t (*cl_signature)[96] = NULL;
    @synchronized (context) {
        NSData *signature = [AS_OBJC(context) CLSignatureForBlockHash:blockHash];
        if (signature) {
            cl_signature = uint768_malloc(signature.UInt768);
        }
    }
    processor_destroy_block_hash(block_hash);
    return (uint8_t *)cl_signature;
}
bool saveCLSignature(uint8_t (*block_hash)[32], uint8_t (*cl_signature)[96], const void *context) {
    UInt256 blockHash = *((UInt256 *)block_hash);
    UInt768 clSignature = *((UInt768 *)cl_signature);
    BOOL saved = NO;
    @synchronized (context) {
        saved = [AS_OBJC(context) saveCLSignature:blockHash signature:clSignature];
    }
    processor_destroy_block_hash(block_hash);
    processor_destroy_cl_signature(cl_signature);
    return saved;
}

void addInsightForBlockHash(uint8_t (*block_hash)[32], const void *context) {
    UInt256 blockHash = *((UInt256 *)block_hash);
    @synchronized (context) {
        [AS_OBJC(context) blockUntilGetInsightForBlockHash:blockHash];
    }
    processor_destroy_block_hash(block_hash);
}

ProcessingError shouldProcessDiffWithRange(uint8_t (*base_block_hash)[32], uint8_t (*block_hash)[32], const void *context) {
    UInt256 baseBlockHash = *((UInt256 *)base_block_hash);
    UInt256 blockHash = *((UInt256 *)block_hash);
    processor_destroy_block_hash(base_block_hash);
    processor_destroy_block_hash(block_hash);
    ProcessingError error = ProcessingError_None;
    @synchronized (context) {
        error = [AS_OBJC(context) shouldProcessDiffWithRange:baseBlockHash blockHash:blockHash];
    }
    return error;
}
    
///
/// MARK: Registering/unregistering processor (which is responsible for callback processing)
///

+ (MasternodeProcessor *)registerProcessor {
    return register_processor(
                              getMerkleRootByHash,
                              getBlockHeightByHash,
                              getBlockHashByHeight,
                              getLLMQSnapshotByBlockHash,
                              saveLLMQSnapshot,
                              getCLSignatureByBlockHash,
                              saveCLSignature,
                              getMasternodeListByBlockHash,
                              saveMasternodeList,
                              destroyMasternodeList,
                              addInsightForBlockHash,
                              destroyU8,
                              destroyLLMQSnapshot,
                              shouldProcessDiffWithRange);
}

+ (void)unregisterProcessor:(MasternodeProcessor *)processor {
    unregister_processor(processor);
}

///
/// MARK: Creating/destroying opaque cache (which is important for storing some of the results between processing sessions)
///

+ (MasternodeProcessorCache *)createProcessorCache {
    return processor_create_cache();
}

+ (void)destroyProcessorCache:(MasternodeProcessorCache *)processorCache {
    processor_destroy_cache(processorCache);
}


///
/// MARK: Call processing methods
///
- (void)processMasternodeDiffWith:(NSData *)message context:(DSMasternodeProcessorContext *)context completion:(void (^)(DSMnDiffProcessingResult *result))completion {
    NSAssert(self.processor, @"processMasternodeDiffMessage: No processor created");
    DSLog(@"[%@] processMasternodeDiffWith: %@", context.chain.name, context);
    MNListDiffResult *result = process_mnlistdiff_from_message(message.bytes,
                                                               message.length,
                                                               context.chain.chainType,
                                                               context.useInsightAsBackup,
                                                               context.isFromSnapshot,
                                                               context.peer ? context.peer.version : context.chain.protocolVersion,
                                                               self.processor,
                                                               self.processorCache,
                                                               AS_RUST(context));
    DSMnDiffProcessingResult *processingResult = [DSMnDiffProcessingResult processingResultWith:result onChain:context.chain];
    processor_destroy_mnlistdiff_result(result);
    completion(processingResult);
}

- (void)processQRInfoWith:(NSData *)message context:(DSMasternodeProcessorContext *)context completion:(void (^)(DSQRInfoProcessingResult *result))completion {
    NSAssert(self.processor, @"processQRInfoMessage: No processor created");
    NSAssert(self.processorCache, @"processQRInfoMessage: No processorCache created");
    DSLog(@"[%@] processQRInfoWith: %@", context.chain.name, context);
    QRInfoResult *result = process_qrinfo_from_message(message.bytes,
                                                       message.length,
                                                       context.chain.chainType,
                                                       context.useInsightAsBackup,
                                                       context.isFromSnapshot,
                                                       context.chain.isRotatedQuorumsPresented,
                                                       context.peer ? context.peer.version : context.chain.protocolVersion,
                                                       self.processor,
                                                       self.processorCache,
                                                       AS_RUST(context));
    DSQRInfoProcessingResult *processingResult = [DSQRInfoProcessingResult processingResultWith:result onChain:context.chain];
    processor_destroy_qr_info_result(result);
    completion(processingResult);
}

- (DSMnDiffProcessingResult *)processMasternodeDiffFromFile:(NSData *)message protocolVersion:(uint32_t)protocolVersion withContext:(DSMasternodeProcessorContext *)context {
    NSAssert(self.processor, @"processMasternodeDiffMessage: No processor created");
    DSLog(@"[%@] processMasternodeDiffMessage: %@", context.chain.name, context);
    MNListDiffResult *result = NULL;
    @synchronized (context) {
        result = process_mnlistdiff_from_message(
                                                 message.bytes,
                                                 message.length,
                                                 context.chain.chainType,
                                                 context.useInsightAsBackup,
                                                 context.isFromSnapshot,
                                                 protocolVersion,
                                                 self.processor,
                                                 self.processorCache,
                                                 AS_RUST(context));
    }
    DSMnDiffProcessingResult *processingResult = [DSMnDiffProcessingResult processingResultWith:result onChain:context.chain];
    processor_destroy_mnlistdiff_result(result);
    return processingResult;
}

- (void)clearProcessorCache {
    NSAssert(self.processorCache, @"clearProcessorCache: No processorCache created");
    processor_clear_cache(self.processorCache);
}

- (void)removeMasternodeListFromCacheAtBlockHash:(UInt256)blockHash {
    NSAssert(self.processorCache, @"removeMasternodeListFromCacheAtBlockHash: No processorCache created");
    processor_remove_masternode_list_from_cache_for_block_hash((const uint8_t *) blockHash.u8, self.processorCache);
}

- (void)removeSnapshotFromCacheAtBlockHash:(UInt256)blockHash {
    NSAssert(self.processorCache, @"removeSnapshotFromCacheAtBlockHash: No processorCache created");
    processor_remove_llmq_snapshot_from_cache_for_block_hash((const uint8_t *) blockHash.u8, self.processorCache);
}


@end
