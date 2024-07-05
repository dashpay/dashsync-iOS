//  
//  Created by Vladimir Pirogov
//  Copyright © 2024 Dash Core Group. All rights reserved.
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

#import <Foundation/Foundation.h>
#import "DSBlock.h"
#import "DSChain.h"
#import "DSCheckpoint.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSBlocksCache : NSObject

@property (nonatomic, strong, readonly) NSDictionary<NSValue *, DSBlock *> *orphans;

///*! @brief Returns the hash of the last persisted sync block. The sync block itself most likely is not persisted.  */
//@property (nonatomic, assign) UInt256 lastPersistedChainSyncBlockHash;
/*! @brief Returns the hash of the last persisted sync block. The sync block itself most likely is not persisted.  */
@property (nonatomic, readonly) UInt256 lastPersistedChainSyncBlockHash;

/*! @brief Returns the height of the last persisted sync block. The sync block itself most likely is not persisted.  */
@property (nonatomic, readonly) uint32_t lastPersistedChainSyncBlockHeight;

/*! @brief Returns the timestamp of the last persisted sync block. The sync block itself most likely is not persisted.  */
@property (nonatomic, readonly) NSTimeInterval lastPersistedChainSyncBlockTimestamp;

/*! @brief The last known terminal block on the chain.  */
@property (nonatomic, readonly, nullable) DSBlock *lastTerminalBlock;


/*! @brief Returns the hash of the last persisted sync block. The sync block itself most likely is not persisted.  */
@property (nonatomic, assign) UInt256 lastPersistedChainSyncBlockHash;

/*! @brief Returns the chain work of the last persisted sync block. The sync block itself most likely is not persisted.  */
@property (nonatomic, readonly) UInt256 lastPersistedChainSyncBlockChainWork;


- (void)resetLastSyncBlock;
- (void)setLastSyncBlockFromCheckpoints:(DSCheckpoint *)checkpoint forChain:(DSChain *)chain;
- (void)setSyncBlockFromCheckpoint:(DSCheckpoint *)checkpoint forChain:(DSChain *)chain;
- (DSBlock *)lastSyncBlockWithUseCheckpoints:(BOOL)useCheckpoints forChain:(DSChain *)chain;

- (void)setLastPersistedSyncBlockHeight:(uint32_t)height
                              blockHash:(UInt256)blockHash
                              timestamp:(NSTimeInterval)timestamp
                              chainWork:(UInt256)chainWork;
@end

NS_ASSUME_NONNULL_END
