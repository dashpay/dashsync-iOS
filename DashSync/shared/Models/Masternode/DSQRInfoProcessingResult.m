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
    NSMutableOrderedSet<DSQuorumEntry *> *lastQuorumPerIndex = [NSMutableOrderedSet orderedSet];
    for (NSUInteger i = 0; i < result->last_quorum_per_index_count; i++) {
        DSQuorumEntry *entry = [[DSQuorumEntry alloc] initWithEntry:result->last_quorum_per_index[i] onChain:chain];
        [lastQuorumPerIndex addObject:entry];
    }
    processingResult.lastQuorumPerIndex = lastQuorumPerIndex;
    NSMutableOrderedSet<DSQuorumSnapshot *> *snapshotList = [NSMutableOrderedSet orderedSet];
    for (NSUInteger i = 0; i < result->quorum_snapshot_list_count; i++) {
        DSQuorumSnapshot *snapshot = [DSQuorumSnapshot quorumSnapshotWith:result->quorum_snapshot_list[i]];
        [snapshotList addObject:snapshot];
    }
    processingResult.snapshotList = snapshotList;
    NSMutableOrderedSet<DSMnDiffProcessingResult *> *mnListDiffList = [NSMutableOrderedSet orderedSet];
    for (NSUInteger i = 0; i < result->mn_list_diff_list_count; i++) {
        DSMnDiffProcessingResult *mnListDiff = [DSMnDiffProcessingResult processingResultWith:result->mn_list_diff_list[i] onChain:chain];
        [mnListDiffList addObject:mnListDiff];
    }
    processingResult.mnListDiffList = mnListDiffList;
    return processingResult;
}


- (NSString *)debugDescription {
    return [NSString stringWithFormat:@"%@: {\n diffs: [\ntip: %@,\nh: %@,\nh-c: %@,\nh-2c: %@,\nh-3c: %@,\nh-4c: %@\n],\n snapshots: [\nh-c: %@,\nh-2c: %@,\nh-3c: %@,\nh-4c: %@], \n lastQuorums: %@, \n diffs: %@, \n, snapshots: %@ \n]}",
            [super debugDescription],
            self.mnListDiffResultAtTip,
            self.mnListDiffResultAtH,
            self.mnListDiffResultAtHC,
            self.mnListDiffResultAtH2C,
            self.mnListDiffResultAtH3C,
            self.mnListDiffResultAtH4C,
            self.snapshotAtHC,
            self.snapshotAtH2C,
            self.snapshotAtH3C,
            self.snapshotAtH4C,
            self.lastQuorumPerIndex,
            self.snapshotList,
            self.mnListDiffList
    ];
}

@end
