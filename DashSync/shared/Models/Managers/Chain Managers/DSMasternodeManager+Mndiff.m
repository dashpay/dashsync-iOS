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
    DSMasternodeProcessorContext *processorContext = (__bridge DSMasternodeProcessorContext *)context;
    UInt256 blockHash = *((UInt256 *)block_hash);
    DSMasternodeList *list = processorContext.masternodeListLookup(blockHash);
    MasternodeList *c_list = list ? [list ffi_malloc] : NULL;
    NSLog(@"••• getMasternodeListByBlockHash: %@: %p: %@", uint256_hex(blockHash), c_list, context);
    processor_destroy_block_hash(block_hash);
    return c_list;
}

bool saveMasternodeList(uint8_t (*block_hash)[32], MasternodeList *masternode_list, const void *context) {
    DSMasternodeProcessorContext *processorContext = (__bridge DSMasternodeProcessorContext *)context;
    DSChain *chain = processorContext.chain;
    UInt256 blockHash = *((UInt256 *)block_hash);
    DSMasternodeList *masternodeList = [DSMasternodeList masternodeListWith:masternode_list onChain:chain];
    BOOL saved = [chain.chainManager.masternodeManager saveMasternodeList:masternodeList forBlockHash:blockHash];
    NSLog(@"••• saveMasternodeList: %ul: %@: %d", processorContext.blockHeightLookup(blockHash), uint256_hex(blockHash), saved);
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
    DSMasternodeProcessorContext *processorContext = (__bridge DSMasternodeProcessorContext *)context;
    UInt256 blockHash = *((UInt256 *)block_hash);
    uint32_t block_height = processorContext.blockHeightLookup(blockHash);
    NSLog(@"\"%@\" => %u, // getBlockHeightByHash", uint256_hex(blockHash), block_height);
    processor_destroy_block_hash(block_hash);
    return block_height;
}

uint8_t *getBlockHashByHeight(uint32_t block_height, const void *context) {
    DSMasternodeProcessorContext *processorContext = (__bridge DSMasternodeProcessorContext *)context;
    DSChain *chain = processorContext.chain;
    DSBlock *block = [chain blockAtHeight:block_height];
    NSLog(@"%u => UInt256::from_hex(\"%@\"), // getBlockHashByHeight", block_height, uint256_hex(block.blockHash));
    uint8_t (*block_hash)[32] = block ? uint256_malloc(block.blockHash) : NULL;
    return (uint8_t *)block_hash;
}


uint8_t *getMerkleRootByHash(uint8_t (*block_hash)[32], const void *context) {
    DSMasternodeProcessorContext *processorContext = (__bridge DSMasternodeProcessorContext *)context;
    UInt256 blockHash = *((UInt256 *)block_hash);
    UInt256 merkleRoot = processorContext.merkleRootLookup(blockHash);
    uint8_t (*merkle_root)[32] = uint256_malloc(merkleRoot);
    NSLog(@"••• getMerkleRootByHash: %@ -> %@: %p",uint256_hex(blockHash), uint256_hex(merkleRoot), merkle_root);
    processor_destroy_block_hash(block_hash);
    return (uint8_t *)merkle_root;
}

LLMQSnapshot *getLLMQSnapshotByBlockHash(uint8_t (*block_hash)[32], const void *context) {
    DSMasternodeProcessorContext *processorContext = (__bridge DSMasternodeProcessorContext *)context;
    DSChain *chain = processorContext.chain;
    UInt256 blockHash = *((UInt256 *)block_hash);
    DSQuorumSnapshot *snapshot = [chain.chainManager.masternodeManager quorumSnapshotForBlockHash:blockHash];
    LLMQSnapshot *c_snapshot = snapshot ? [snapshot ffi_malloc] : NULL;
    NSLog(@"••• getLLMQSnapshotByBlockHash: %@: %p: %@", uint256_hex(blockHash), c_snapshot, context);
    processor_destroy_block_hash(block_hash);
    return c_snapshot;
}


bool saveLLMQSnapshot(uint8_t (*block_hash)[32], LLMQSnapshot *snapshot, const void *context) {
    DSMasternodeProcessorContext *processorContext = (__bridge DSMasternodeProcessorContext *)context;
    DSChain *chain = processorContext.chain;
    UInt256 blockHash = *((UInt256 *)block_hash);
    DSQuorumSnapshot *quorumSnapshot = [DSQuorumSnapshot quorumSnapshotWith:snapshot forBlockHash:blockHash];
    BOOL saved = [chain.chainManager.masternodeManager saveQuorumSnapshot:quorumSnapshot];
//    NSLog(@"••• saveLLMQSnapshot: %u: %@: %d", processorContext.blockHeightLookup(blockHash), uint256_hex(blockHash), saved);
    processor_destroy_block_hash(block_hash);
    processor_destroy_llmq_snapshot(snapshot);
    return saved;
}
void destroyLLMQSnapshot(LLMQSnapshot *snapshot) {
//    NSLog(@"••• destroyLLMQSnapshot: %p", snapshot);
    [DSQuorumSnapshot ffi_free:snapshot];
}

void addInsightForBlockHash(uint8_t (*block_hash)[32], const void *context) {
    DSMasternodeProcessorContext *processorContext = (__bridge DSMasternodeProcessorContext *)context;
    UInt256 blockHash = *((UInt256 *)block_hash);
    DSChain *chain = processorContext.chain;
    [chain blockUntilGetInsightForBlockHash:blockHash];
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
    DSMasternodeProcessorContext *processorContext = (__bridge DSMasternodeProcessorContext *)context;
    UInt256 baseBlockHash = *((UInt256 *)base_block_hash);
    UInt256 blockHash = *((UInt256 *)block_hash);
    DSChain *chain = processorContext.chain;
    DSMasternodeManager *manager = chain.chainManager.masternodeManager;
    uint32_t baseBlockHeight = [manager heightForBlockHash:baseBlockHash];
    uint32_t blockHeight = [manager heightForBlockHash:blockHash];
//    NSLog(@"•••• shouldProcessDiffWithRange.... %u..%u %@ .. %@", baseBlockHeight, blockHeight, uint256_hex(baseBlockHash), uint256_hex(blockHash));
    DSMasternodeListService *service = processorContext.isDIP0024 ? manager.quorumRotationService : manager.masternodeListDiffService;
    
    BOOL hasRemovedFromRetrieval = [service removeRequestInRetrievalForBaseBlockHash:baseBlockHash blockHash:blockHash];
    BOOL hasLocallyStored = [manager.store hasMasternodeListAt:uint256_data(blockHash)];
    DSMasternodeList *list = [manager.store masternodeListForBlockHash:blockHash withBlockHeightLookup:processorContext.blockHeightLookup];
    BOOL hasUnverifiedRotatedQuorums = [list hasUnverifiedRotatedQuorums];
    processor_destroy_block_hash(base_block_hash);
    processor_destroy_block_hash(block_hash);
    if (!hasRemovedFromRetrieval) {
        NSLog(@"•••• shouldProcessDiffWithRange: persist in retrieval: %u..%u %@ .. %@", baseBlockHeight, blockHeight, uint256_hex(baseBlockHash), uint256_hex(blockHash));
        return 1; // ProcessingError::PersistInRetrieval
    }
    if (hasLocallyStored && !hasUnverifiedRotatedQuorums) {
        NSLog(@"•••• shouldProcessDiffWithRange: already persist: %u: %@ hasUnverifiedRotated: %d", blockHeight, uint256_hex(blockHash), hasUnverifiedRotatedQuorums);
        return 2; // ProcessingError::LocallyStored
    }
    DSMasternodeList *baseMasternodeList = processorContext.masternodeListLookup(baseBlockHash);
    if (!baseMasternodeList && !uint256_eq(chain.genesisHash, baseBlockHash) && uint256_is_not_zero(baseBlockHash)) {
        // this could have been deleted in the meantime, if so rerequest
        [service issueWithMasternodeListFromPeer:processorContext.peer];
        NSLog(@"•••• No base masternode list at: %d: %@", baseBlockHeight, uint256_hex(baseBlockHash));
        return 4; // ProcessingError::HasNoBaseBlockHash
    }
//    NSLog(@"•••• shouldProcessDiffWithRange: OK! %u..%u %@ .. %@", baseBlockHeight, blockHeight, uint256_hex(baseBlockHash), uint256_hex(blockHash));
    return 0; // ProcessingError::None
}

bool shouldProcessLLMQType(uint8_t quorum_type, const void *context) {
    DSMasternodeProcessorContext *processorContext = (__bridge DSMasternodeProcessorContext *)context;
    DSChain *chain = processorContext.chain;
    DSLLMQType llmqType = (DSLLMQType)quorum_type;
    BOOL should = [chain shouldProcessQuorumOfType:llmqType];
    BOOL isQRContext = processorContext.isDIP0024;
    if (chain.quorumTypeForISDLocks == llmqType) {
        should = isQRContext && chain.isRotatedQuorumsPresented;
    } else if (isQRContext) /*skip old quorums here for now*/ {
        should = false;
    } else {
        should = [chain shouldProcessQuorumOfType:llmqType];
    }
        
    NSLog(@"••• shouldProcessLLMQType: %d: %d", quorum_type, should);
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

- (DSQRInfoProcessingResult *)processQRInfoMessage:(NSData *)message withContext:(DSMasternodeProcessorContext *)context {
    NSAssert(self.processor, @"processQRInfoMessage: No processor created");
    NSAssert(self.processorCache, @"processQRInfoMessage: No processorCache created");
    QRInfoResult *result = NULL;
    @synchronized (context) {
        result = process_qrinfo_from_message(
                                                           message.bytes,
                                                           message.length,
                                                           context.useInsightAsBackup,
                                                           context.isFromSnapshot,
                                                           (const uint8_t *) context.chain.genesisHash.u8,
                                                           self.processor,
                                                           self.processorCache,
                                                           (__bridge void *)(context));
    }
    DSQRInfoProcessingResult *processingResult = [DSQRInfoProcessingResult processingResultWith:result onChain:context.chain];
    processor_destroy_qr_info_result(result);
    return processingResult;
}

@end
