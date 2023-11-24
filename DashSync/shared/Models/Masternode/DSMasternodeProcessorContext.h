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
#import "DSChain.h"
#import "DSMasternodeList.h"
#import "DSQuorumSnapshot.h"
#import "DSPeer.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef DSMasternodeList *_Nullable(^_Nullable MasternodeListFinder)(UInt256 blockHash);
typedef UInt256(^_Nullable MerkleRootFinder)(UInt256 blockHash);
typedef DSMerkleBlock *_Nullable(^_Nullable MerkleBlockFinder)(UInt256 blockHash);

@interface DSMasternodeProcessorContext : NSObject

@property (nonatomic) DSChain *chain;
@property (nonatomic, nullable) DSPeer *peer;
@property (nonatomic) BOOL useInsightAsBackup;
@property (nonatomic) BOOL isFromSnapshot;
@property (nonatomic) BOOL isDIP0024;
@property (nonatomic, copy) MasternodeListFinder masternodeListLookup;
@property (nonatomic, copy) BlockHeightFinder blockHeightLookup;
@property (nonatomic, copy) MerkleRootFinder merkleRootLookup;


- (uint32_t)blockHeightForBlockHash:(UInt256)blockHash;
- (UInt256)merkleRootForBlockHash:(UInt256)blockHash;
- (DSBlock *_Nullable)blockForBlockHeight:(uint32_t)blockHeight;
- (NSData *_Nullable)CLSignatureForBlockHash:(UInt256)blockHash;
- (DSQuorumSnapshot *_Nullable)quorumSnapshotForBlockHash:(UInt256)blockHash;
- (DSMasternodeList *_Nullable)masternodeListForBlockHash:(UInt256)blockHash;

- (BOOL)saveCLSignature:(UInt256)blockHash signature:(UInt768)signature;
- (BOOL)saveQuorumSnapshot:(DSQuorumSnapshot *)snapshot;
- (BOOL)saveMasternodeList:(DSMasternodeList *)masternodeList forBlockHash:(UInt256)blockHash;



- (void)blockUntilGetInsightForBlockHash:(UInt256)blockHash;
- (ProcessingError)shouldProcessDiffWithRange:(UInt256)baseBlockHash blockHash:(UInt256)blockHash;

@end

NS_ASSUME_NONNULL_END
