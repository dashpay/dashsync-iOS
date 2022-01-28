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
#import "DSInsightManager.h"
#import "DSMasternodeDiffMessageContext.h"
#import "DSMasternodeList+Mndiff.h"
#import "DSMasternodeManager+Mndiff.h"
#import "DSMerkleBlock.h"
#import "DSQuorumEntry+Mndiff.h"
#import "DSSimplifiedMasternodeEntry+Mndiff.h"
#import "NSData+Dash.h"

@implementation DSMasternodeManager (Mndiff)

const MasternodeList *masternodeListLookupCallback(uint8_t (*block_hash)[32], const void *context) {
    DSMasternodeDiffMessageContext *mndiffContext = (__bridge DSMasternodeDiffMessageContext *)context;
    NSData *data = [NSData dataWithBytes:block_hash length:32];
    DSMasternodeList *list = mndiffContext.masternodeListLookup(data.UInt256);
    MasternodeList *c_list = list ? [list ffi_malloc] : NULL;
    mndiff_block_hash_destroy(block_hash);
    return c_list;
}

void masternodeListDestroyCallback(const MasternodeList *masternode_list) {
    [DSMasternodeList ffi_free:(MasternodeList *)masternode_list];
}

uint32_t blockHeightListLookupCallback(uint8_t (*block_hash)[32], const void *context) {
    DSMasternodeDiffMessageContext *mndiffContext = (__bridge DSMasternodeDiffMessageContext *)context;
    NSData *data = [NSData dataWithBytes:block_hash length:32];
    uint32_t block_height = mndiffContext.blockHeightLookup(data.UInt256);
    mndiff_block_hash_destroy(block_hash);
    return block_height;
}

void addInsightLookup(uint8_t (*block_hash)[32], const void *context) {
    DSMasternodeDiffMessageContext *mndiffContext = (__bridge DSMasternodeDiffMessageContext *)context;
    NSData *data = [NSData dataWithBytes:block_hash length:32];
    UInt256 entryQuorumHash = data.UInt256;
    DSChain *chain = mndiffContext.chain;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    [[DSInsightManager sharedInstance] blockForBlockHash:uint256_reverse(entryQuorumHash)
                                                 onChain:chain
                                              completion:^(DSBlock *_Nullable block, NSError *_Nullable error) {
        if (!error && block) {
            [chain addInsightVerifiedBlock:block forBlockHash:entryQuorumHash];
        }
        dispatch_semaphore_signal(sem);
    }];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    mndiff_block_hash_destroy(block_hash);
}

bool shouldProcessQuorumType(uint8_t quorum_type, const void *context) {
    DSMasternodeDiffMessageContext *mndiffContext = (__bridge DSMasternodeDiffMessageContext *)context;
    BOOL should = [mndiffContext.chain shouldProcessQuorumOfType:(DSLLMQType)quorum_type];
    return should;
};

bool validateQuorumCallback(QuorumValidationData *data, const void *context) {
    uintptr_t count = data->count;
    uint8_t(**items)[48] = data->items;
    NSMutableArray<DSBLSKey *> *publicKeyArray = [NSMutableArray array];
    for (NSUInteger i = 0; i < count; i++) {
        NSData *pkData = [NSData dataWithBytes:items[i] length:48];
        [publicKeyArray addObject:[DSBLSKey keyWithPublicKey:pkData.UInt384]];
    }
    uint8_t(*all_commitment_aggregated_signature)[96] = data->all_commitment_aggregated_signature;
    uint8_t(*commitment_hash)[32] = data->commitment_hash;
    UInt256 commitmentHash = [NSData dataWithBytes:commitment_hash length:32].UInt256;
    UInt768 allCommitmentAggregatedSignature = [NSData dataWithBytes:all_commitment_aggregated_signature length:96].UInt768;
    bool allCommitmentAggregatedSignatureValidated = [DSBLSKey verifySecureAggregated:commitmentHash signature:allCommitmentAggregatedSignature withPublicKeys:publicKeyArray];
    if (!allCommitmentAggregatedSignatureValidated) {
        return false;
    }
    //The sig must validate against the commitmentHash and all public keys determined by the signers bitvector. This is an aggregated BLS signature verification.
    uint8_t(*quorum_threshold_signature)[96] = data->quorum_threshold_signature;
    uint8_t(*quorum_public_key)[48] = data->quorum_public_key;
    UInt768 quorumThresholdSignature = [NSData dataWithBytes:quorum_threshold_signature length:96].UInt768;
    UInt384 quorumPublicKey = [NSData dataWithBytes:quorum_public_key length:48].UInt384;
    bool quorumSignatureValidated = [DSBLSKey verify:commitmentHash signature:quorumThresholdSignature withPublicKey:quorumPublicKey];
    mndiff_quorum_validation_data_destroy(data);
    if (!quorumSignatureValidated) {
        DSLog(@"Issue with quorumSignatureValidated");
        return false;
    }
    return true;
};

+ (void)processMasternodeDiffMessage:(NSData *)message withContext:(DSMasternodeDiffMessageContext *)context completion:(void (^)(DSMnDiffProcessingResult *result))completion {
    DSChain *chain = context.chain;
    DSMasternodeList *baseMasternodeList = context.baseMasternodeList;
    UInt256 merkleRoot = context.lastBlock.merkleRoot;
    MasternodeList *base_masternode_list = baseMasternodeList ? [baseMasternodeList ffi_malloc] : NULL;

    MndiffResult *result = mndiff_process(message.bytes, message.length, base_masternode_list, masternodeListLookupCallback, masternodeListDestroyCallback, uint256_data(merkleRoot).bytes, context.useInsightAsBackup, addInsightLookup, shouldProcessQuorumType, validateQuorumCallback, blockHeightListLookupCallback, (__bridge void *)(context));

    [DSMasternodeList ffi_free:base_masternode_list];
    DSMnDiffProcessingResult *processingResult = [DSMnDiffProcessingResult processingResultWith:result onChain:chain];
    mndiff_destroy(result);
    completion(processingResult);
}

+ (void)destroyQRInfoMessage:(QuorumRotationInfo *)info {
    qrinfo_destroy(info);
}

+ (QuorumRotationInfo *)readQRInfoMessage:(NSData *)message {
    QuorumRotationInfo *result = qrinfo_read(message.bytes, message.length);
    return result;
}

+ (void)processQRInfo:(QuorumRotationInfo *)info withContext:(DSMasternodeDiffMessageContext *)context completion:(void (^)(DSQRInfoProcessingResult *result))completion {
    DSChain *chain = context.chain;
    DSMasternodeList *baseMasternodeList = context.baseMasternodeList;
    UInt256 merkleRoot = context.lastBlock.merkleRoot;
    MasternodeList *base_masternode_list = baseMasternodeList ? [baseMasternodeList ffi_malloc] : NULL;
    QuorumRotationInfo *qrInfo = qrinfo_process(info, uint256_data(merkleRoot).bytes, base_masternode_list, masternodeListLookupCallback, masternodeListDestroyCallback, context.useInsightAsBackup, addInsightLookup, shouldProcessQuorumType, validateQuorumCallback, blockHeightListLookupCallback, (__bridge void *)(context));
    [DSMasternodeList ffi_free:base_masternode_list];
    DSQRInfoProcessingResult *processingResult = [DSQRInfoProcessingResult processingResultWith:qrInfo onChain:chain];
    [DSMasternodeManager destroyQRInfoMessage:qrInfo];
    completion(processingResult);
}

@end
