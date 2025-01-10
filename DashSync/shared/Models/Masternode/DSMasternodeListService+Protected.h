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

#import "DSKeyManager.h"
#import "DSMasternodeListService.h"
//#import "DSMasternodeListStore.h"
//#import "DSMnDiffProcessingResult.h"
#import "DSPeer.h"

NS_ASSUME_NONNULL_BEGIN
@class DSMasternodeListStore;
@interface DSMasternodeListService (Protected)

@property (nonatomic, readonly) DSMasternodeListStore *store;

- (void)updateAfterProcessingMasternodeListWithBlockHash:(NSData *)blockHashData fromPeer:(DSPeer *)peer;
- (BOOL)shouldProcessDiffResult:(u256 *)block_hash
                        isValid:(BOOL)isValid
        skipPresenceInRetrieval:(BOOL)skipPresenceInRetrieval;
//- (BOOL)shouldProcessDiffResult:(DSMnDiffProcessingResult *)diffResult skipPresenceInRetrieval:(BOOL)skipPresenceInRetrieval;
//- (DSMasternodeListRequest*__nullable)requestInRetrievalFor:(UInt256)baseBlockHash blockHash:(UInt256)blockHash;

@end

NS_ASSUME_NONNULL_END
