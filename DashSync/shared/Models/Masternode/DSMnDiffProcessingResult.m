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

#import "NSData+Dash.h"
#import "DSMnDiffProcessingResult.h"
#import "DSMasternodeList+Mndiff.h"
#import "DSQuorumEntry+Mndiff.h"
#import "DSSimplifiedMasternodeEntry+Mndiff.h"

@implementation DSMnDiffProcessingResult

+ (instancetype)processingResultWith:(MNListDiffResult *)result onChain:(DSChain *)chain {
    DSMnDiffProcessingResult *processingResult = [[DSMnDiffProcessingResult alloc] init];
    uint8_t errorStatus = result->error_status;
    processingResult.errorStatus = errorStatus;
    if (errorStatus > 0) {
        return processingResult;
    }
    if (result->masternode_list == NULL) {
        NSLog(@"DSQRInfoProcessingResult.error.unknown");
        processingResult.errorStatus = ProcessingError_ParseError;
        return processingResult;
    }

    [processingResult setErrorStatus:errorStatus];
    [processingResult setBaseBlockHash:*(UInt256 *)result->base_block_hash];
    [processingResult setBlockHash:*(UInt256 *)result->block_hash];
    [processingResult setFoundCoinbase:result->has_found_coinbase];
    [processingResult setValidCoinbase:result->has_valid_coinbase];
    [processingResult setRootMNListValid:result->has_valid_mn_list_root];
    [processingResult setRootQuorumListValid:result->has_valid_llmq_list_root];
    [processingResult setValidQuorums:result->has_valid_quorums];
    MasternodeList *result_masternode_list = result->masternode_list;
    [processingResult setMasternodeList:[DSMasternodeList masternodeListWith:result_masternode_list onChain:chain]];
    NSDictionary *addedMasternodes = [DSSimplifiedMasternodeEntry simplifiedEntriesWith:result->added_masternodes count:result->added_masternodes_count onChain:chain];
    [processingResult setAddedMasternodes:addedMasternodes];
    NSDictionary *modifiedMasternodes = [DSSimplifiedMasternodeEntry simplifiedEntriesWith:result->modified_masternodes count:result->modified_masternodes_count onChain:chain];
    [processingResult setModifiedMasternodes:modifiedMasternodes];
    NSArray<DSQuorumEntry *> *addedQuorums = [DSQuorumEntry entriesWith:result->added_quorums count:result->added_quorums_count onChain:chain];
    [processingResult setAddedQuorums:addedQuorums];
    uint8_t(**needed_masternode_lists)[32] = result->needed_masternode_lists;
    uintptr_t needed_masternode_lists_count = result->needed_masternode_lists_count;
    NSMutableOrderedSet *neededMissingMasternodeLists = [NSMutableOrderedSet orderedSetWithCapacity:needed_masternode_lists_count];
    for (NSUInteger i = 0; i < needed_masternode_lists_count; i++) {
        NSData *hash = [NSData dataWithBytes:needed_masternode_lists[i] length:32];
        [neededMissingMasternodeLists addObject:hash];
    }
    [processingResult setNeededMissingMasternodeLists:[neededMissingMasternodeLists copy]];
    uint8_t (**quorums_cl_signatures_hashes)[32] = result->quorums_cl_signatures_hashes;
    uint8_t (**quorums_cl_signatures)[96] = result->quorums_cl_signatures;
    uintptr_t quorums_cl_sigs_count = result->quorums_cl_sigs_count;
    NSMutableDictionary<NSData *, NSData *> *clSignatures = [NSMutableDictionary dictionaryWithCapacity:quorums_cl_sigs_count];
    for (NSUInteger i = 0; i < quorums_cl_sigs_count; i++) {
        [clSignatures setObject:uint768_data(*(UInt768 *)quorums_cl_signatures[i])
                         forKey:uint256_data(*(UInt256 *)quorums_cl_signatures_hashes[i])];
    }
    [processingResult setClSignatures:clSignatures];
    return processingResult;
}

- (BOOL)isValid {
//    return self.foundCoinbase && self.validQuorums && self.rootMNListValid && self.rootQuorumListValid;
    return self.foundCoinbase && self.rootQuorumListValid;
}
- (BOOL)isTotallyValid {
    return [self isValid] && self.validCoinbase;
}

- (BOOL)hasRotatedQuorumsForChain:(DSChain*)chain {
    return [[self.addedQuorums indexesOfObjectsPassingTest:^BOOL(DSQuorumEntry * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        // TODO: make it more reliable as quorum type values may change
        return obj.llmqType == quorum_type_for_isd_locks(chain.chainType) && (*stop = TRUE);
    }] count] > 0;
}

- (NSString *)debugDescription {
    return [NSString stringWithFormat:@"•-• %@: {\nvalidity: %d%d%d%d%d, \nmasternodeList: %@, \nmasternodes: [added:%lu, modified:%lu], \nquorums: [added: %lu],\nneeded: [%@]}",
            [super debugDescription], self.foundCoinbase, self.validCoinbase, self.rootMNListValid, self.rootQuorumListValid, self.validQuorums,
            self.masternodeList, self.addedMasternodes.count, self.modifiedMasternodes.count, self.addedQuorums.count, self.neededMissingMasternodeLists
            
    ];
}

@end
