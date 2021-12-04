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

#import "BigIntTypes.h"
#import "DSMasternodeList+Mndiff.h"
#import "DSQuorumEntry+Mndiff.h"
#import "DSSimplifiedMasternodeEntry+Mndiff.h"
#import "NSData+Dash.h"

@implementation DSMasternodeList (Mndiff)

+ (instancetype)masternodeListWith:(MasternodeList *)list onChain:(DSChain *)chain {
    uintptr_t masternodes_count = list->masternodes_count;
    NSMutableDictionary<NSData *, DSSimplifiedMasternodeEntry *> *masternodes = [DSSimplifiedMasternodeEntry simplifiedEntriesWith:list->masternodes count:masternodes_count onChain:chain];
    NSMutableDictionary<NSNumber *, NSMutableDictionary<NSData *, DSQuorumEntry *> *> *quorums = [DSQuorumEntry entriesWith:list->quorum_type_maps count:list->quorum_type_maps_count onChain:chain];
    UInt256 masternodeMerkleRoot = list->masternode_merkle_root ? *((UInt256 *) list->masternode_merkle_root) :  UINT256_ZERO;
    UInt256 quorumMerkleRoot = list->quorum_merkle_root ? *((UInt256 *) list->quorum_merkle_root) : UINT256_ZERO;
    UInt256 blockHash = *((UInt256 *) list->block_hash);
    return [self masternodeListWithSimplifiedMasternodeEntriesDictionary:masternodes
                                                 quorumEntriesDictionary:quorums
                                                             atBlockHash:blockHash
                                                           atBlockHeight:list->known_height
                                            withMasternodeMerkleRootHash:masternodeMerkleRoot
                                                withQuorumMerkleRootHash:quorumMerkleRoot
                                                                 onChain:chain];
}

@end
