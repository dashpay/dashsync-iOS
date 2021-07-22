//
//  Created by Sam Westrich
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
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, DSMerkleTreeHashFunction)
{
    DSMerkleTreeHashFunction_SHA256_2 = 0,
    DSMerkleTreeHashFunction_BLAKE3,
};

@interface DSMerkleTree : NSObject <NSCopying>

@property (nonatomic, readonly) uint32_t treeElementCount;
@property (nonatomic, readonly) NSData *hashes;
@property (nonatomic, readonly) NSData *flags;
@property (nonatomic, readonly) UInt256 merkleRoot;
@property (nonatomic, readonly) DSMerkleTreeHashFunction hashFunction;

+ (instancetype)merkleTreeWithData:(NSData *)data treeElementCount:(uint32_t)elementCount hashFunction:(DSMerkleTreeHashFunction)hashFunction;

- (instancetype)initWithHashes:(NSData *)hashes flags:(NSData *)flags treeElementCount:(uint32_t)elementCount hashFunction:(DSMerkleTreeHashFunction)hashFunction;

- (NSArray *)elementHashes;

- (BOOL)containsHash:(UInt256)hash;

- (BOOL)merkleTreeHasRoot:(UInt256)desiredMerkleRoot;

@end

NS_ASSUME_NONNULL_END
