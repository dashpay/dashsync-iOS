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
//
//#import "DSMasternodeProcessorContext.h"
//#import "NSData+Dash.h"
//#import "DSChain+Protected.h"
//#import "DSChainManager.h"
//#import "DSMasternodeManager.h"
//
//@implementation DSMasternodeProcessorContext
//
//- (uint32_t)blockHeightForBlockHash:(UInt256)blockHash {
//    return self.blockHeightLookup(blockHash);
//}
//
//- (DSMerkleBlock *_Nullable)blockForBlockHeight:(uint32_t)blockHeight {
//    return [self.chain blockAtHeight:blockHeight];
//
//}
//- (UInt256)merkleRootForBlockHash:(UInt256)blockHash {
//    return self.merkleRootLookup(blockHash);
//}
//
//- (NSData *_Nullable)CLSignatureForBlockHash:(UInt256)blockHash {
//    return [self.chain.chainManager.masternodeManager CLSignatureForBlockHash:blockHash];
//}
//
//- (DSQuorumSnapshot *_Nullable)quorumSnapshotForBlockHash:(UInt256)blockHash {
//    return [self.chain.chainManager.masternodeManager quorumSnapshotForBlockHash:blockHash];
//}
//
//- (DSMasternodeList *_Nullable)masternodeListForBlockHash:(UInt256)blockHash {
//    return self.masternodeListLookup(blockHash);
//}
//
//- (BOOL)saveCLSignature:(UInt256)blockHash signature:(UInt768)signature {
//    return [self.chain.chainManager.masternodeManager saveCLSignature:uint256_data(blockHash) signatureData:uint768_data(signature)];
//}
//
//- (BOOL)saveQuorumSnapshot:(DSQuorumSnapshot *)snapshot {
//    return [self.chain.chainManager.masternodeManager saveQuorumSnapshot:snapshot];
//}
//
//- (BOOL)saveMasternodeList:(DSMasternodeList *)masternodeList forBlockHash:(UInt256)blockHash {
//    return [self.chain.chainManager.masternodeManager saveMasternodeList:masternodeList forBlockHash:blockHash];
//}
//
//- (void)blockUntilGetInsightForBlockHash:(UInt256)blockHash {
//    [self.chain blockUntilGetInsightForBlockHash:blockHash];
//}
//
//- (NSString *)description {
//    return [[super description] stringByAppendingString:[NSString stringWithFormat:@" {%@}: [%@: %@ (%u)] genesis: %@ protocol: %u, insight: %i, from_snapshot: %i, dip-24: %i}", self.chain.name, self.peer.location, self.peer.useragent, self.peer.version, uint256_hex(self.chain.genesisHash), self.chain.protocolVersion, self.useInsightAsBackup, self.isFromSnapshot, self.isDIP0024]];
//}
//
//- (ProcessingError)shouldProcessDiffWithRange:(UInt256)baseBlockHash blockHash:(UInt256)blockHash {
//    uint32_t baseBlockHeight = [self blockHeightForBlockHash:baseBlockHash];
//    uint32_t blockHeight = [self blockHeightForBlockHash:blockHash];
//    if (blockHeight == UINT32_MAX) {
//        DSLog(@"•••• shouldProcessDiffWithRange: unknown blockHash: %u..%u %@ .. %@", baseBlockHeight, blockHeight, uint256_reverse_hex(baseBlockHash), uint256_reverse_hex(blockHash));
//        return ProcessingError_UnknownBlockHash;
//    }
//    DSChain *chain = self.chain;
//    DSMasternodeManager *manager = chain.chainManager.masternodeManager;
//    DSMasternodeListService *service = self.isDIP0024 ? manager.quorumRotationService : manager.masternodeListDiffService;
//    BOOL hasRemovedFromRetrieval = [service removeRequestInRetrievalForBaseBlockHash:baseBlockHash blockHash:blockHash];
//    if (!hasRemovedFromRetrieval) {
//        DSLog(@"•••• shouldProcessDiffWithRange: persist in retrieval: %u..%u %@ .. %@", baseBlockHeight, blockHeight, uint256_reverse_hex(baseBlockHash), uint256_reverse_hex(blockHash));
//        return ProcessingError_PersistInRetrieval;
//    }
//    NSData *blockHashData = uint256_data(blockHash);
//    DSMasternodeList *list = self.masternodeListLookup(blockHash);
//    BOOL needToVerifyRotatedQuorums = self.isDIP0024 && (!manager.quorumRotationService.masternodeListAtH || [manager.quorumRotationService.masternodeListAtH hasUnverifiedRotatedQuorums]);
//    BOOL needToVerifyNonRotatedQuorums = !self.isDIP0024 && [list hasUnverifiedNonRotatedQuorums];
//    BOOL noNeedToVerifyQuorums = !(needToVerifyRotatedQuorums || needToVerifyNonRotatedQuorums);
//    BOOL hasLocallyStored = [manager.store hasMasternodeListAt:blockHashData];
//    if (hasLocallyStored && noNeedToVerifyQuorums) {
//        DSLog(@"•••• shouldProcessDiffWithRange: already persist: %u: %@ needToVerifyRotatedQuorums: %d needToVerifyNonRotatedQuorums: %d", blockHeight, uint256_reverse_hex(blockHash), needToVerifyRotatedQuorums, needToVerifyNonRotatedQuorums);
//        [service removeFromRetrievalQueue:blockHashData];
//        return ProcessingError_LocallyStored;
//    }
//    DSMasternodeList *baseMasternodeList = self.masternodeListLookup(baseBlockHash);
//    if (!baseMasternodeList && !uint256_eq(chain.genesisHash, baseBlockHash) && uint256_is_not_zero(baseBlockHash)) {
//        // this could have been deleted in the meantime, if so rerequest
//        [service issueWithMasternodeListFromPeer:self.peer];
//        DSLog(@"•••• No base masternode list at: %d: %@", baseBlockHeight, uint256_reverse_hex(baseBlockHash));
//        return ProcessingError_HasNoBaseBlockHash;
//    }
//    return ProcessingError_None;
//}
//
//@end
