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

#import "DSBLSKey.h"
#import "DSBlock.h"
#import "DSBlockOperation.h"
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

@implementation DSMasternodeManager (Mndiff)

///
/// MARK: Rust FFI callbacks
///
MasternodeList *getMasternodeListByBlockHash(uint8_t (*block_hash)[32], const void *context) {
    UInt256 blockHash = *((UInt256 *)block_hash);
    DSMasternodeProcessorContext *processorContext = NULL;
    MasternodeList *c_list = NULL;
    @synchronized (context) {
        processorContext = (__bridge DSMasternodeProcessorContext *)context;
        DSMasternodeList *list = processorContext.masternodeListLookup(blockHash);
        //NSLog(@"••• getMasternodeListByBlockHash: %@: %@", uint256_hex(blockHash), list.debugDescription);
    //    if (list) {
    //        [list saveToJsonFile];
    //    }
        if (list) {
            c_list = [list ffi_malloc];
        }
    }
    processor_destroy_block_hash(block_hash);
    return c_list;
}

bool saveMasternodeList(uint8_t (*block_hash)[32], MasternodeList *masternode_list, const void *context) {
    UInt256 blockHash = *((UInt256 *)block_hash);
    DSMasternodeProcessorContext *processorContext = NULL;
    BOOL saved = NO;
    @synchronized (context) {
        processorContext = (__bridge DSMasternodeProcessorContext *)context;
        DSChain *chain = processorContext.chain;
        DSMasternodeList *masternodeList = [DSMasternodeList masternodeListWith:masternode_list onChain:chain];
        saved = [chain.chainManager.masternodeManager saveMasternodeList:masternodeList forBlockHash:blockHash];
        //NSLog(@"••• saveMasternodeList: %ul: %@: %d", processorContext.blockHeightLookup(blockHash), uint256_hex(blockHash), saved);
    }
    processor_destroy_block_hash(block_hash);
    processor_destroy_masternode_list(masternode_list);
    return saved;
}

void destroyMasternodeList(MasternodeList *masternode_list) {
//    NSLog(@"••• destroyMasternodeList: %p", masternode_list);
    [DSMasternodeList ffi_free:masternode_list];
}

void destroyHash(uint8_t *block_hash) { // UInt256
//    NSLog(@"••• destroyHash: %p", block_hash);
    if (block_hash) {
        free(block_hash);
    }
}

uint32_t getBlockHeightByHash(uint8_t (*block_hash)[32], const void *context) {
    DSMasternodeProcessorContext *processorContext = NULL;
    UInt256 blockHash = *((UInt256 *)block_hash);
    uint32_t block_height = UINT32_MAX;
    @synchronized (context) {
        processorContext = (__bridge DSMasternodeProcessorContext *)context;
        block_height = processorContext.blockHeightLookup(blockHash);
        //DSLog(@"getBlockHeightByHash: %u: %@", block_height, uint256_hex(blockHash));
    }
    processor_destroy_block_hash(block_hash);
    return block_height;
}

uint8_t *getBlockHashByHeight(uint32_t block_height, const void *context) {
    DSMasternodeProcessorContext *processorContext = NULL;
    uint8_t (*block_hash)[32] = NULL;
    @synchronized (context) {
        processorContext = (__bridge DSMasternodeProcessorContext *)context;
        DSChain *chain = processorContext.chain;
        DSBlock *block = [chain blockAtHeight:block_height];
        //NSLog(@"%u => UInt256::from_hex(\"%@\"), // getBlockHashByHeight", block_height, uint256_hex(block.blockHash));
        if (block) {
            block_hash = uint256_malloc(block.blockHash);
        }
    }
    return (uint8_t *)block_hash;
}


uint8_t *getMerkleRootByHash(uint8_t (*block_hash)[32], const void *context) {
    DSMasternodeProcessorContext *processorContext = NULL;
    UInt256 blockHash = *((UInt256 *)block_hash);
    uint8_t (*merkle_root)[32] = NULL;
    @synchronized (context) {
        processorContext = (__bridge DSMasternodeProcessorContext *)context;
        UInt256 merkleRoot = processorContext.merkleRootLookup(blockHash);
        merkle_root = uint256_malloc(merkleRoot);
    }
    processor_destroy_block_hash(block_hash);
    return (uint8_t *)merkle_root;
}

LLMQSnapshot *getLLMQSnapshotByBlockHash(uint8_t (*block_hash)[32], const void *context) {
    DSMasternodeProcessorContext *processorContext = NULL;
    UInt256 blockHash = *((UInt256 *)block_hash);
    LLMQSnapshot *c_snapshot = NULL;
    @synchronized (context) {
        processorContext = (__bridge DSMasternodeProcessorContext *)context;
        DSChain *chain = processorContext.chain;
        DSQuorumSnapshot *snapshot = [chain.chainManager.masternodeManager quorumSnapshotForBlockHash:blockHash];
        if (snapshot) {
            c_snapshot = [snapshot ffi_malloc];
        }
    }
    processor_destroy_block_hash(block_hash);
    return c_snapshot;
}


bool saveLLMQSnapshot(uint8_t (*block_hash)[32], LLMQSnapshot *snapshot, const void *context) {
    DSMasternodeProcessorContext *processorContext = NULL;
    UInt256 blockHash = *((UInt256 *)block_hash);
    BOOL saved = NO;
    @synchronized (context) {
        processorContext = (__bridge DSMasternodeProcessorContext *)context;
        DSChain *chain = processorContext.chain;
        DSQuorumSnapshot *quorumSnapshot = [DSQuorumSnapshot quorumSnapshotWith:snapshot forBlockHash:blockHash];
        saved = [chain.chainManager.masternodeManager saveQuorumSnapshot:quorumSnapshot];
        //NSLog(@"••• saveLLMQSnapshot: %u: %@: %d", processorContext.blockHeightLookup(blockHash), uint256_hex(blockHash), saved);
    }
    processor_destroy_block_hash(block_hash);
    processor_destroy_llmq_snapshot(snapshot);
    return saved;
}
void destroyLLMQSnapshot(LLMQSnapshot *snapshot) {
//    NSLog(@"••• destroyLLMQSnapshot: %p", snapshot);
    [DSQuorumSnapshot ffi_free:snapshot];
}

void addInsightForBlockHash(uint8_t (*block_hash)[32], const void *context) {
    DSMasternodeProcessorContext *processorContext = NULL;
    UInt256 blockHash = *((UInt256 *)block_hash);
    @synchronized (context) {
        processorContext = (__bridge DSMasternodeProcessorContext *)context;
        DSChain *chain = processorContext.chain;
        [chain blockUntilGetInsightForBlockHash:blockHash];
    }
    processor_destroy_block_hash(block_hash);
}

void logRustMessage(const char *message, const void *context) {
    //DSLog(@"••• %@", [NSString stringWithUTF8String:message]);
}
//None = 0,
//Skipped = 1,
//ParseError = 2,
//HasNoBaseBlockHash = 3,
uint8_t shouldProcessDiffWithRange(uint8_t (*base_block_hash)[32], uint8_t (*block_hash)[32], const void *context) {
    DSMasternodeProcessorContext *processorContext = NULL;
    UInt256 baseBlockHash = *((UInt256 *)base_block_hash);
    UInt256 blockHash = *((UInt256 *)block_hash);
    processor_destroy_block_hash(base_block_hash);
    processor_destroy_block_hash(block_hash);
    @synchronized (context) {
        processorContext = (__bridge DSMasternodeProcessorContext *)context;
        DSChain *chain = processorContext.chain;
        DSMasternodeManager *manager = chain.chainManager.masternodeManager;
        uint32_t baseBlockHeight = processorContext.blockHeightLookup(baseBlockHash);
        uint32_t blockHeight = processorContext.blockHeightLookup(blockHash);
        if (blockHeight == UINT32_MAX) {
            NSLog(@"•••• shouldProcessDiffWithRange: unknown blockHash: %u..%u %@ .. %@", baseBlockHeight, blockHeight, uint256_hex(baseBlockHash), uint256_hex(blockHash));
            return 5; // ProcessingError::UnknownBlockHash
        }
        DSMasternodeListService *service = processorContext.isDIP0024 ? manager.quorumRotationService : manager.masternodeListDiffService;
        BOOL hasRemovedFromRetrieval = [service removeRequestInRetrievalForBaseBlockHash:baseBlockHash blockHash:blockHash];
        BOOL hasLocallyStored = [manager.store hasMasternodeListAt:uint256_data(blockHash)];
        DSMasternodeList *list = processorContext.masternodeListLookup(blockHash);
        BOOL hasUnverifiedRotatedQuorums = processorContext.isDIP0024 && [list hasUnverifiedRotatedQuorums];
        if (!hasRemovedFromRetrieval) {
            NSLog(@"•••• shouldProcessDiffWithRange: persist in retrieval: %u..%u %@ .. %@", baseBlockHeight, blockHeight, uint256_hex(baseBlockHash), uint256_hex(blockHash));
            return 1; // ProcessingError::PersistInRetrieval
        }
        if (hasLocallyStored && !hasUnverifiedRotatedQuorums) {
            NSLog(@"•••• shouldProcessDiffWithRange: already persist: %u: %@ hasUnverifiedRotated: %d", blockHeight, uint256_hex(blockHash), [list hasUnverifiedRotatedQuorums]);
            return 2; // ProcessingError::LocallyStored
        }
        DSMasternodeList *baseMasternodeList = processorContext.masternodeListLookup(baseBlockHash);
        if (!baseMasternodeList && !uint256_eq(chain.genesisHash, baseBlockHash) && uint256_is_not_zero(baseBlockHash)) {
            // this could have been deleted in the meantime, if so rerequest
            [service issueWithMasternodeListFromPeer:processorContext.peer];
            NSLog(@"•••• No base masternode list at: %d: %@", baseBlockHeight, uint256_hex(baseBlockHash));
            return 4; // ProcessingError::HasNoBaseBlockHash
        }
    }
    return 0; // ProcessingError::None
}

bool shouldProcessLLMQType(uint8_t quorum_type, const void *context) {
    DSLLMQType llmqType = (DSLLMQType)quorum_type;
    DSMasternodeProcessorContext *processorContext = NULL;
    BOOL should = NO;
    @synchronized (context) {
        processorContext = (__bridge DSMasternodeProcessorContext *)context;
        DSChain *chain = processorContext.chain;
        should = [chain shouldProcessQuorumOfType:llmqType];
        BOOL isQRContext = processorContext.isDIP0024;
        if (chain.quorumTypeForISDLocks == llmqType) {
            should = isQRContext && chain.isRotatedQuorumsPresented;
        } else if (isQRContext) /*skip old quorums here for now*/ {
            should = false;
        } else {
            should = [chain shouldProcessQuorumOfType:llmqType];
        }
    }
    return should;
}

bool validateLLMQ(struct LLMQValidationData *data, const void *context) {
    uintptr_t count = data->count;
    uint8_t(**items)[48] = data->items;
    UInt768 allCommitmentAggregatedSignature = *((UInt768 *)data->all_commitment_aggregated_signature);
    UInt256 commitmentHash = *((UInt256 *)data->commitment_hash);
    UInt768 quorumThresholdSignature = *((UInt768 *)data->threshold_signature);
    UInt384 quorumPublicKey = *((UInt384 *)data->public_key);
    NSLog(@"••• validateLLMQ: items: %lu: %@", count, uint384_hex(quorumPublicKey));
    NSMutableArray<DSBLSKey *> *publicKeyArray = [NSMutableArray array];
    for (NSUInteger i = 0; i < count; i++) {
        UInt384 publicKey = *((UInt384 *)items[i]);
        [publicKeyArray addObject:[DSBLSKey keyWithPublicKey:publicKey]];
    }
    processor_destroy_llmq_validation_data(data);
    bool allCommitmentAggregatedSignatureValidated = [DSBLSKey verifySecureAggregated:commitmentHash signature:allCommitmentAggregatedSignature withPublicKeys:publicKeyArray];
    if (!allCommitmentAggregatedSignatureValidated) {
        NSLog(@"••• Issue with allCommitmentAggregatedSignatureValidated: %@", uint768_hex(allCommitmentAggregatedSignature));
        return false;
    }
    //The sig must validate against the commitmentHash and all public keys determined by the signers bitvector. This is an aggregated BLS signature verification.
    bool quorumSignatureValidated = [DSBLSKey verify:commitmentHash signature:quorumThresholdSignature withPublicKey:quorumPublicKey];
    if (!quorumSignatureValidated) {
        NSLog(@"••• Issue with quorumSignatureValidated");
        return false;
    }
    return true;
};

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
                              getMasternodeListByBlockHash,
                              saveMasternodeList,
                              destroyMasternodeList,
                              addInsightForBlockHash,
                              shouldProcessLLMQType,
                              validateLLMQ,
                              destroyHash,
                              destroyLLMQSnapshot,
                              shouldProcessDiffWithRange,
                              logRustMessage);
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
    MNListDiffResult *result = process_mnlistdiff_from_message(message.bytes,
                                                               message.length,
                                                               context.useInsightAsBackup,
                                                               context.isFromSnapshot,
                                                               (const uint8_t *) context.chain.genesisHash.u8,
                                                               self.processor,
                                                               self.processorCache,
                                                               (__bridge void *)(context));
    DSMnDiffProcessingResult *processingResult = [DSMnDiffProcessingResult processingResultWith:result onChain:context.chain];
    processor_destroy_mnlistdiff_result(result);
    completion(processingResult);
}

- (void)processQRInfoWith:(NSData *)message context:(DSMasternodeProcessorContext *)context completion:(void (^)(DSQRInfoProcessingResult *result))completion {
    NSAssert(self.processor, @"processQRInfoMessage: No processor created");
    NSAssert(self.processorCache, @"processQRInfoMessage: No processorCache created");
    QRInfoResult *result = process_qrinfo_from_message(message.bytes,
                                                       message.length,
                                                       context.useInsightAsBackup,
                                                       context.isFromSnapshot,
                                                       (const uint8_t *) context.chain.genesisHash.u8,
                                                       self.processor,
                                                       self.processorCache,
                                                       (__bridge void *)(context));
    DSQRInfoProcessingResult *processingResult = [DSQRInfoProcessingResult processingResultWith:result onChain:context.chain];
    processor_destroy_qr_info_result(result);
    completion(processingResult);
}

- (DSMnDiffProcessingResult *)processMasternodeDiffMessage:(NSData *)message withContext:(DSMasternodeProcessorContext *)context {
    NSAssert(self.processor, @"processMasternodeDiffMessage: No processor created");
    MNListDiffResult *result = NULL;
    @synchronized (context) {
        result = process_mnlistdiff_from_message(
                                                                   message.bytes,
                                                                   message.length,
                                                                   context.useInsightAsBackup,
                                                                   context.isFromSnapshot,
                                                                   (const uint8_t *) context.chain.genesisHash.u8,
                                                                   self.processor,
                                                                   self.processorCache,
                                                                   (__bridge void *)(context));
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
