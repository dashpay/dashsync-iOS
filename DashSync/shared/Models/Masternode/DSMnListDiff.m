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

#import "DSMnListDiff.h"
#import "DSCoinbaseTransaction+Mndiff.h"
#import "DSQuorumEntry+Mndiff.h"
#import "DSSimplifiedMasternodeEntry+Mndiff.h"

@implementation DSMnListDiff

+ (instancetype)mnListDiffWith:(MNListDiff *)mnListDiff onChain:(DSChain *)chain {
    DSMnListDiff *diff = [[DSMnListDiff alloc] init];
    diff.chain = chain;
    diff.baseBlockHash = *((UInt256 *)mnListDiff->base_block_hash);
    diff.blockHash = *((UInt256 *)mnListDiff->block_hash);
    diff.totalTransactions = mnListDiff->total_transactions;
    NSMutableOrderedSet<NSNumber *> *merkleHashes = [NSMutableOrderedSet orderedSet];
    for (NSUInteger i = 0; i < mnListDiff->merkle_hashes_count; i++) {
        [merkleHashes addObject:[NSNumber numberWithInteger:mnListDiff->merkle_hashes[i]]];
    }
    diff.merkleHashes = merkleHashes;
    NSMutableOrderedSet<NSNumber *> *merkleFlags = [NSMutableOrderedSet orderedSet];
    for (NSUInteger i = 0; i < mnListDiff->merkle_flags_count; i++) {
        [merkleFlags addObject:[NSNumber numberWithInteger:mnListDiff->merkle_flags[i]]];
    }
    diff.merkleFlags = merkleFlags;
    diff.coinbaseTransaction = [DSCoinbaseTransaction coinbaseTransactionWith:mnListDiff->coinbase_transaction onChain:chain];
    NSMutableOrderedSet<NSData *> *deletedMasternodeHashes = [NSMutableOrderedSet orderedSet];
    for (NSUInteger i = 0; i < mnListDiff->deleted_masternode_hashes_count; i++) {
        NSData *hash = [NSData dataWithBytes:mnListDiff->deleted_masternode_hashes[i] length:32];
        [deletedMasternodeHashes addObject:hash];
    }
    diff.deletedMasternodeHashes = deletedMasternodeHashes;
    NSMutableOrderedSet<DSSimplifiedMasternodeEntry *> *addedOrModifiedMasternodes = [NSMutableOrderedSet orderedSet];
    for (NSUInteger i = 0; i < mnListDiff->added_or_modified_masternodes_count; i++) {
        DSSimplifiedMasternodeEntry *entry = [DSSimplifiedMasternodeEntry simplifiedEntryWith:mnListDiff->added_or_modified_masternodes[i] onChain:chain];
        [addedOrModifiedMasternodes addObject:entry];
    }
    diff.addedOrModifiedMasternodes = addedOrModifiedMasternodes;
    NSMutableOrderedSet<NSData *> *deletedQuorums = [NSMutableOrderedSet orderedSet];
    for (NSUInteger i = 0; i < mnListDiff->deleted_quorums_count; i++) {
        NSData *quorumHash = [NSData dataWithBytes:mnListDiff->deleted_quorums[i] length:32];
        [deletedQuorums addObject:quorumHash];
    }
    diff.deletedQuorums = deletedQuorums;
    NSUInteger addedQuorumsCount = mnListDiff->added_quorums_count;
    NSMutableOrderedSet<DSQuorumEntry *> *addedQuorums = [NSMutableOrderedSet orderedSetWithCapacity:addedQuorumsCount];
    for (NSUInteger i = 0; i < addedQuorumsCount; i++) {
        DSQuorumEntry *entry = [[DSQuorumEntry alloc] initWithEntry:mnListDiff->added_quorums[i] onChain:chain];
        [addedQuorums addObject:entry];
    }
    diff.addedQuorums = addedQuorums;
    return diff;
}

@end
