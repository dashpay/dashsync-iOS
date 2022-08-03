//
//  Created by Vladimir Pirogov
//  Copyright © 2022 Dash Core Group. All rights reserved.
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

#import "DSQRInfoProcessingResult.h"

@implementation DSQRInfoProcessingResult

+ (instancetype)processingResultWith:(QRInfoResult *)result onChain:(DSChain *)chain {
    DSQRInfoProcessingResult *processingResult = [[DSQRInfoProcessingResult alloc] init];
    processingResult.snapshotAtHC = [DSQuorumSnapshot quorumSnapshotWith:result->snapshot_at_h_c];
    processingResult.snapshotAtH2C = [DSQuorumSnapshot quorumSnapshotWith:result->snapshot_at_h_2c];
    processingResult.snapshotAtH3C = [DSQuorumSnapshot quorumSnapshotWith:result->snapshot_at_h_3c];
    BOOL extraShare = result->extra_share;
    processingResult.extraShare = extraShare;
    
    processingResult.mnListDiffResultAtTip = [DSMnDiffProcessingResult processingResultWith:result->result_at_tip onChain:chain];
    processingResult.mnListDiffResultAtH = [DSMnDiffProcessingResult processingResultWith:result->result_at_h onChain:chain];
    processingResult.mnListDiffResultAtHC = [DSMnDiffProcessingResult processingResultWith:result->result_at_h_c onChain:chain];
    processingResult.mnListDiffResultAtH2C = [DSMnDiffProcessingResult processingResultWith:result->result_at_h_2c onChain:chain];
    processingResult.mnListDiffResultAtH3C = [DSMnDiffProcessingResult processingResultWith:result->result_at_h_3c onChain:chain];
    if (extraShare) {
        processingResult.snapshotAtH4C = [DSQuorumSnapshot quorumSnapshotWith:result->snapshot_at_h_4c];
        processingResult.mnListDiffResultAtH4C = [DSMnDiffProcessingResult processingResultWith:result->result_at_h_4c onChain:chain];
    }
    /*NSMutableOrderedSet<NSData *> *blockHashList = [NSMutableOrderedSet orderedSet];
    for (NSUInteger i = 0; i < llmqRotationInfo->block_hash_list_num; i++) {
        NSData *hash = [NSData dataWithBytes:quorumRotationInfo->block_hash_list[i] length:32];
        [blockHashList addObject:hash];
    }
    processingResult.blockHashList = blockHashList;
    NSMutableOrderedSet<DSQuorumSnapshot *> *snapshotList = [NSMutableOrderedSet orderedSet];
    for (NSUInteger i = 0; i < quorumRotationInfo->snapshot_list_num; i++) {
        DSQuorumSnapshot *snapshot = [DSQuorumSnapshot quorumSnapshotWith:quorumRotationInfo->snapshot_list[i]];
        [snapshotList addObject:snapshot];
    }
    processingResult.snapshotList = snapshotList;
    NSMutableOrderedSet<DSMnListDiff *> *mnListDiffList = [NSMutableOrderedSet orderedSet];
    for (NSUInteger i = 0; i < quorumRotationInfo->mn_list_diff_list_num; i++) {
        DSMnListDiff *mnListDiff = [DSMnListDiff mnListDiffWith:quorumRotationInfo->mn_list_diff_list[i] onChain:chain];
        [mnListDiffList addObject:mnListDiff];
    }
    processingResult.mnListDiffList = mnListDiffList;*/
    return processingResult;
}

@end
