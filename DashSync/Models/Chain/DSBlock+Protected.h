//  
//  Created by Sam Westrich
//  Copyright © 2020 Dash Core Group. All rights reserved.
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

NS_ASSUME_NONNULL_BEGIN

@interface DSBlock ()


@property (nonatomic, assign) UInt256 blockHash;
@property (nonatomic, strong) NSValue * blockHashValue;
@property (nonatomic, assign) uint32_t version;
@property (nonatomic, assign) UInt256 prevBlock;
@property (nonatomic, strong) NSValue * prevBlockValue;
@property (nonatomic, assign) UInt256 merkleRoot;
@property (nonatomic, assign) uint32_t timestamp; // time interval since unix epoch
@property (nonatomic, assign) uint32_t target;
@property (nonatomic, assign) uint32_t nonce;
@property (nonatomic, assign) uint32_t totalTransactions;
@property (nonatomic, assign) BOOL chainLocked;
@property (nonatomic, assign) BOOL hasUnverifiedChainLock;
@property (nonatomic, strong, nullable) DSChainLock * chainLockAwaitingProcessing;
@property (nonatomic, strong) DSChain * chain;
@property (nonatomic, strong) NSArray *transactionHashes; // the matched tx hashes in the block
@property (nonatomic, assign, getter = isValid) BOOL valid;
@property (nonatomic, assign, getter = isMerkleTreeValid) BOOL merkleTreeValid;
@property (nonatomic, strong, getter = toData) NSData *data;
@property (nonatomic, assign) uint32_t height;
@property (nonatomic, assign) UInt256 aggregateWork;

- (instancetype)initWithVersion:(uint32_t)version timestamp:(uint32_t)timestamp height:(uint32_t)height onChain:(DSChain*)chain;

@end


NS_ASSUME_NONNULL_END
