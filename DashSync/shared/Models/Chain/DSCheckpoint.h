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

#import "BigIntTypes.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class DSChain, DSBlock;

typedef NS_ENUM(uint8_t, DSCheckpointParameter)
{
    DSCheckpointParameter_None,
    DSCheckpointParameter_MerkleRoot = 1,
    DSCheckpointParameter_MasternodeList = 1 << 2,

    DSCheckpointParameter_ChainWorkSize = 1 << 4, //chainWorkSize is a multiple of 32 bytes
};

typedef NS_ENUM(uint8_t, DSCheckpointOptions)
{
    DSCheckpointOptions_None,
    DSCheckpointOptions_SaveMerkleRoot = 1,
};

@interface DSCheckpoint : NSObject <NSCoding, NSSecureCoding>

@property (nonatomic, readonly) uint32_t height;
@property (nonatomic, readonly) UInt256 blockHash;
@property (nonatomic, readonly) uint32_t timestamp;
@property (nonatomic, readonly) uint32_t target;
@property (nonatomic, readonly) NSString *masternodeListName;
@property (nonatomic, readonly) uint32_t protocolVersion;
@property (nonatomic, readonly) UInt256 merkleRoot;
@property (nonatomic, readonly) UInt256 chainWork;

+ (instancetype)checkpointForHeight:(uint32_t)height blockHash:(UInt256)blockHash timestamp:(uint32_t)timestamp target:(uint32_t)target merkleRoot:(UInt256)merkleRoot chainWork:(UInt256)chainWork masternodeListName:(NSString *_Nullable)masternodeListName;

+ (instancetype)checkpointFromBlock:(DSBlock *)block options:(uint8_t)options;

- (DSBlock *)blockForChain:(DSChain *)chain;

- (instancetype)initWithData:(NSData *)data;

- (instancetype)initWithData:(NSData *)data atOffset:(uint32_t)offset finalOffset:(uint32_t *_Nullable)finalOffset;

+ (DSCheckpoint *)genesisDevnetCheckpoint;

- (NSData *)serialize;

@end

NS_ASSUME_NONNULL_END
