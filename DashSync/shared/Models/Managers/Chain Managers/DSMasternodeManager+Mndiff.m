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
const MasternodeList *getMasternodeListByBlockHash(uint8_t (*block_hash)[32], const void *context) {
    DSMasternodeDiffMessageContext *processorContext = (__bridge DSMasternodeDiffMessageContext *)context;
    NSData *data = [NSData dataWithBytes:block_hash length:32];
    DSMasternodeList *list = processorContext.masternodeListLookup(data.UInt256);
    MasternodeList *c_list = list ? [list ffi_malloc] : NULL;
    NoTimeLog(@"getMasternodeListByBlockHash: %@: %@: %@", data.hexString, c_list, context);
    mndiff_block_hash_destroy(block_hash);
    return c_list;
}

bool saveMasternodeList(uint8_t (*block_hash)[32], const MasternodeList *masternode_list, const void *context) {
    DSMasternodeDiffMessageContext *processorContext = (__bridge DSMasternodeDiffMessageContext *)context;
    DSChain *chain = processorContext.chain;
    NSData *data = [NSData dataWithBytes:block_hash length:32];
    DSMasternodeList *masternodeList = [DSMasternodeList masternodeListWith:(MasternodeList *)masternode_list onChain:chain];
    BOOL saved = [chain.chainManager.masternodeManager saveMasternodeList:masternodeList forBlockHash:data.UInt256];
    NoTimeLog(@"saveMasternodeList: %ul: %@: %d", processorContext.blockHeightLookup(data.UInt256), data.hexString, saved);
    return saved;
}

void destroyMasternodeList(const MasternodeList *masternode_list) {
    [DSMasternodeList ffi_free:((MasternodeList *)masternode_list)];
}

uint32_t getBlockHeightByHash(uint8_t (*block_hash)[32], const void *context) {
    DSMasternodeDiffMessageContext *processorContext = (__bridge DSMasternodeDiffMessageContext *)context;
    NSData *data = [NSData dataWithBytes:block_hash length:32];
    uint32_t block_height = processorContext.blockHeightLookup(data.UInt256);
    NoTimeLog(@"%@ => %u,", data.hexString, block_height);
    NoTimeLog(@"getBlockHeightByHash: %@: %u: %@", data.hexString, block_height, context);
    mndiff_block_hash_destroy(block_hash);
    return block_height;
}

const uint8_t *getBlockHashByHeight(uint32_t block_height, const void *context) {
    DSMasternodeDiffMessageContext *processorContext = (__bridge DSMasternodeDiffMessageContext *)context;
    DSChain *chain = processorContext.chain;
    DSBlock *block = [chain blockAtHeight: block_height];
    uint8_t (*block_hash)[32] = block ? uint256_malloc(block.blockHash) : NULL;
    return (const uint8_t *)block_hash;
}

const uint8_t *getMerkleRootByHash(uint8_t (*block_hash)[32], const void *context) {
    DSMasternodeDiffMessageContext *processorContext = (__bridge DSMasternodeDiffMessageContext *)context;
    NSData *data = [NSData dataWithBytes:block_hash length:32];
    UInt256 merkleRoot = processorContext.merkleRootLookup(data.UInt256);
    uint8_t (*merkle_root)[32] = uint256_malloc(merkleRoot);
    return (const uint8_t *)merkle_root;
}

const LLMQSnapshot *getLLMQSnapshotByBlockHeight(uint32_t block_height, const void *context) {
    DSMasternodeDiffMessageContext *processorContext = (__bridge DSMasternodeDiffMessageContext *)context;
    DSChain *chain = processorContext.chain;
    DSQuorumSnapshot *snapshot = [chain.chainManager.masternodeManager quorumSnapshotForBlockHeight:block_height];
    LLMQSnapshot *c_snapshot = snapshot ? [snapshot ffi_malloc] : NULL;
    return c_snapshot;
}


bool saveLLMQSnapshot(uint8_t (*block_hash)[32], const LLMQSnapshot *snapshot, const void *context) {
    DSMasternodeDiffMessageContext *processorContext = (__bridge DSMasternodeDiffMessageContext *)context;
    DSChain *chain = processorContext.chain;
    NSData *data = [NSData dataWithBytes:block_hash length:32];
    BOOL saved = [chain.chainManager.masternodeManager saveQuorumSnapshot:[DSQuorumSnapshot quorumSnapshotWith:(LLMQSnapshot *)snapshot] forBlockHash:data.UInt256];
    NoTimeLog(@"saveLLMQSnapshot: %ul: %@: %d", processorContext.blockHeightLookup(data.UInt256), data.hexString, saved);
    return saved;
}
                      

void addInsightForBlockHash(uint8_t (*block_hash)[32], const void *context) {
    DSMasternodeDiffMessageContext *processorContext = (__bridge DSMasternodeDiffMessageContext *)context;
    NSData *data = [NSData dataWithBytes:block_hash length:32];
    UInt256 entryQuorumHash = data.UInt256;
    DSChain *chain = processorContext.chain;
    [chain blockUntilGetInsightForBlockHash:entryQuorumHash];
    mndiff_block_hash_destroy(block_hash);
}

bool shouldProcessLLMQType(uint8_t quorum_type, const void *context) {
    DSMasternodeDiffMessageContext *processorContext = (__bridge DSMasternodeDiffMessageContext *)context;
    BOOL should = [processorContext.chain shouldProcessQuorumOfType:(DSLLMQType)quorum_type];
    return should;
};

bool validateLLMQ(struct LLMQValidationData *data, const void *context) {
    uintptr_t count = data->count;
    uint8_t(**items)[48] = data->items;
    NSMutableArray<DSBLSKey *> *publicKeyArray = [NSMutableArray array];
    for (NSUInteger i = 0; i < count; i++) {
        UInt384 publicKey = *((UInt384 *)items[i]);
        [publicKeyArray addObject:[DSBLSKey keyWithPublicKey:publicKey]];
    }
    UInt768 allCommitmentAggregatedSignature = *((UInt768 *)data->all_commitment_aggregated_signature);
    UInt256 commitmentHash = *((UInt256 *)data->commitment_hash);
    bool allCommitmentAggregatedSignatureValidated = [DSBLSKey verifySecureAggregated:commitmentHash signature:allCommitmentAggregatedSignature withPublicKeys:publicKeyArray];
    if (!allCommitmentAggregatedSignatureValidated) {
        DSLog(@"Issue with allCommitmentAggregatedSignatureValidated");
        mndiff_quorum_validation_data_destroy(data);
        return false;
    }
    //The sig must validate against the commitmentHash and all public keys determined by the signers bitvector. This is an aggregated BLS signature verification.
    UInt768 quorumThresholdSignature = *((UInt768 *)data->threshold_signature);
    UInt384 quorumPublicKey = *((UInt384 *)data->public_key);
    
    bool quorumSignatureValidated = [DSBLSKey verify:commitmentHash signature:quorumThresholdSignature withPublicKey:quorumPublicKey];
    mndiff_quorum_validation_data_destroy(data);
    if (!quorumSignatureValidated) {
        DSLog(@"Issue with quorumSignatureValidated");
        return false;
    }
    return true;
};


///
/// MARK: Registering/unregistering processor (which is responsible for callback processing)
///

+ (MasternodeProcessor *)registerProcessor:(DSMasternodeProcessorContext *)context {
    return register_processor(getMerkleRootByHash, getBlockHeightByHash, getBlockHashByHeight, getLLMQSnapshotByBlockHeight, saveLLMQSnapshot, getMasternodeListByBlockHash, saveMasternodeList, destroyMasternodeList, addInsightForBlockHash, shouldProcessLLMQType, validateLLMQ/*, (__bridge void *)(context)*/);
}

+ (void)unregisterProcessor:(MasternodeProcessor *)processor {
    unregister_processor(processor);
}

+ (MasternodeProcessorCache *)createProcessorCache {
    return processor_create_cache();
}

+ (void)destroyProcessorCache:(MasternodeProcessorCache *)processorCache {
    processor_destroy_cache(processorCache);
}


///
/// MARK: Call processing methods
///
- (void)processMasternodeDiffMessage:(NSData *)message
                         withContext:(DSMasternodeDiffMessageContext *)context
                          completion:(void (^)(DSMnDiffProcessingResult *result))completion {
    NSAssert(self.processor, @"processMasternodeDiffMessage: No processor created");
    [DSMasternodeManager processMasternodeDiffMessage:message withProcessor:self.processor usingCache:self.processorCache withContext:context completion:completion];
}

+ (void)processMasternodeDiffMessage:(NSData *)message
                       withProcessor:(MasternodeProcessor *)processor
                          usingCache:(MasternodeProcessorCache *)cache
                         withContext:(DSMasternodeDiffMessageContext *)context
                          completion:(void (^)(DSMnDiffProcessingResult *result))completion {
    MNListDiffResult *result = process_mnlistdiff_from_message(
                                                               message.bytes,
                                                               message.length,
                                                               context.baseMasternodeListHash.bytes,
                                                               context.useInsightAsBackup,
                                                               processor,
                                                               cache,
                                                               (__bridge void *)(context));
    NSLog(@"processMasternodeDiffMessage...");
    DSMnDiffProcessingResult *processingResult = [DSMnDiffProcessingResult processingResultWith:result onChain:context.chain];
    mndiff_destroy(result);
    completion(processingResult);
}

+ (void)destroyQRInfoMessage:(LLMQRotationInfo *)info {
    llmq_rotation_info_destroy(info);
}

+ (LLMQRotationInfo *)readQRInfoMessage:(NSData *)message
                            withContext:(DSMasternodeDiffMessageContext *)context
                          withProcessor:(MasternodeProcessor *)processor {
    NoTimeLog(@"readQRInfoMessage...");
    LLMQRotationInfo *result = read_qrinfo(message.bytes, message.length, processor, (__bridge void *)(context));
    return result;
}

- (void)processQRInfo:(LLMQRotationInfo *)info
          withContext:(DSMasternodeDiffMessageContext *)context
           completion:(void (^)(DSQRInfoProcessingResult *result))completion {
    NSAssert(self.processor, @"processQRInfo: No processor created");
    NSAssert(self.processorCache, @"processQRInfo: No processorCache created");
    [DSMasternodeManager processQRInfo:info withProcessor:self.processor usingCache:self.processorCache withContext:context completion:completion];
}

+ (void)processQRInfo:(LLMQRotationInfo *)info
        withProcessor:(MasternodeProcessor *)processor
           usingCache:(MasternodeProcessorCache *)processorCache
          withContext:(DSMasternodeDiffMessageContext *)context
           completion:(void (^)(DSQRInfoProcessingResult *result))completion {
    NoTimeLog(@"processQRInfo...");
    LLMQRotationInfoResult *result = process_qrinfo(info, context.baseMasternodeListHash.bytes, context.useInsightAsBackup, processor, processorCache, (__bridge void *)(context));
    DSQRInfoProcessingResult *processingResult = [DSQRInfoProcessingResult processingResultWith:result onChain:context.chain];
    llmq_rotation_info_result_destroy(result);
    completion(processingResult);
}

@end
