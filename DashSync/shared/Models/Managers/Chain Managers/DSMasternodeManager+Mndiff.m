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
#import "DSMasternodeDiffMessageContext.h"
#import "DSMasternodeList+Mndiff.h"
#import "DSMasternodeManager+Mndiff.h"
#import "DSMerkleBlock.h"
#import "DSQuorumEntry+Mndiff.h"
#import "DSQuorumSnapshot+Mndiff.h"
#import "DSSimplifiedMasternodeEntry+Mndiff.h"
#import "NSData+Dash.h"

@interface DSMasternodeManager (Mndiff)
@property (nonatomic, assign) Processor4 *processor;
@end

@implementation DSMasternodeManager (Mndiff)

const MasternodeList *getMasternodeListByBlockHash(uint8_t (*block_hash)[32], const void *context) {
    DSMasternodeDiffMessageContext *mndiffContext = (__bridge DSMasternodeDiffMessageContext *)context;
    NSData *data = [NSData dataWithBytes:block_hash length:32];
    DSMasternodeList *list = mndiffContext.masternodeListLookup(data.UInt256);
    MasternodeList *c_list = list ? [list ffi_malloc] : NULL;
    mndiff_block_hash_destroy(block_hash);
    return c_list;
}

void destroyMasternodeList(const MasternodeList *masternode_list) {
    [DSMasternodeList ffi_free:((MasternodeList *)masternode_list)];
}

uint32_t getBlockHeightByHash(uint8_t (*block_hash)[32], const void *context) {
    DSMasternodeDiffMessageContext *mndiffContext = (__bridge DSMasternodeDiffMessageContext *)context;
    NSData *data = [NSData dataWithBytes:block_hash length:32];
    uint32_t block_height = mndiffContext.blockHeightLookup(data.UInt256);
    mndiff_block_hash_destroy(block_hash);
    return block_height;
}

const uint8_t *getBlockHashByHeight(uint32_t block_height, const void *context) {
    DSMasternodeDiffMessageContext *mndiffContext = (__bridge DSMasternodeDiffMessageContext *)context;
    DSChain *chain = mndiffContext.chain;
    DSBlock *block = [chain blockAtHeight: block_height];
    uint8_t (*block_hash)[32] = block ? uint256_malloc(block.blockHash) : NULL;
    return (const uint8_t *)block_hash;
}

const LLMQSnapshot *getLLMQSnapshotByBlockHeight(uint32_t block_height, const void *context) {
    DSMasternodeDiffMessageContext *mndiffContext = (__bridge DSMasternodeDiffMessageContext *)context;
    DSChain *chain = mndiffContext.chain;
    DSQuorumSnapshot *snapshot = [chain.chainManager.masternodeManager quorumSnapshotForBlockHeight:block_height];
    LLMQSnapshot *c_snapshot = snapshot ? [snapshot ffi_malloc] : NULL;
    return c_snapshot;
}

void addInsightForBlockHash(uint8_t (*block_hash)[32], const void *context) {
    DSMasternodeDiffMessageContext *mndiffContext = (__bridge DSMasternodeDiffMessageContext *)context;
    NSData *data = [NSData dataWithBytes:block_hash length:32];
    UInt256 entryQuorumHash = data.UInt256;
    DSChain *chain = mndiffContext.chain;
    [chain blockUntilGetInsightForBlockHash:entryQuorumHash];
    mndiff_block_hash_destroy(block_hash);
}

bool shouldProcessLLMQType(uint8_t quorum_type, const void *context) {
    DSMasternodeDiffMessageContext *mndiffContext = (__bridge DSMasternodeDiffMessageContext *)context;
    BOOL should = [mndiffContext.chain shouldProcessQuorumOfType:(DSLLMQType)quorum_type];
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

- (void)registerProcessor:(DSMasternodeDiffMessageContext *)context {
    Processor4 *processor = register_processor(getBlockHeightByHash, getBlockHashByHeight, getLLMQSnapshotByBlockHeight, getMasternodeListByBlockHash, destroyMasternodeList, addInsightForBlockHash, shouldProcessLLMQType, validateLLMQ, (__bridge void *)(context));
    self.processor = processor;
}

- (void)unregisterProcessor {
    if (self.processor) {
        unregister_processor(self.processor);
    }
}


+ (void)processMasternodeDiffMessage:(NSData *)message withContext:(DSMasternodeDiffMessageContext *)context completion:(void (^)(DSMnDiffProcessingResult *result))completion {
    DSChain *chain = context.chain;
    UInt256 merkleRoot = context.lastBlock.merkleRoot;
    struct MNListDiffResult *result = mndiff_process(message.bytes, message.length, context.baseMasternodeListHash.bytes, uint256_data(merkleRoot).bytes, context.useInsightAsBackup, getBlockHeightByHash, getBlockHashByHeight, getLLMQSnapshotByBlockHeight, getMasternodeListByBlockHash, destroyMasternodeList, addInsightForBlockHash, shouldProcessLLMQType, validateLLMQ, (__bridge void *)(context));
    DSMnDiffProcessingResult *processingResult = [DSMnDiffProcessingResult processingResultWith:result onChain:chain];
    mndiff_destroy(result);
    completion(processingResult);
}

+ (void)destroyQRInfoMessage:(struct LLMQRotationInfo *)info {
    llmq_rotation_info_destroy(info);
}

+ (struct LLMQRotationInfo *)readQRInfoMessage:(NSData *)message withContext:(DSMasternodeDiffMessageContext *)context {
    NSLog(@"readQRInfoMessage: \n %@", message.hexString);
    struct LLMQRotationInfo *result = llmq_rotation_info_read(message.bytes, message.length, getBlockHeightByHash, (__bridge void *)(context));
    return result;
}

+ (void)processQRInfo:(struct LLMQRotationInfo *)info withContext:(DSMasternodeDiffMessageContext *)context completion:(void (^)(DSQRInfoProcessingResult *result))completion {
    DSChain *chain = context.chain;
    UInt256 merkleRoot = context.lastBlock.merkleRoot;
    LLMQRotationInfoResult *result = llmq_rotation_info_process(info, context.baseMasternodeListHash.bytes, uint256_data(merkleRoot).bytes, context.useInsightAsBackup, getBlockHeightByHash, getBlockHashByHeight, getLLMQSnapshotByBlockHeight, getMasternodeListByBlockHash, destroyMasternodeList, addInsightForBlockHash, shouldProcessLLMQType, validateLLMQ, (__bridge void *)(context));
    DSQRInfoProcessingResult *processingResult = [DSQRInfoProcessingResult processingResultWith:result onChain:chain];
    llmq_rotation_info_result_destroy(result);
    completion(processingResult);
}

- (void)dealloc {
    [self unregisterProcessor];
    self.processor = nil;
}

@end
