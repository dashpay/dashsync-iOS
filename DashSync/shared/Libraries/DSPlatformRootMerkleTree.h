//  
//  Created by Samuel Westrich
//  Copyright © 2564 Dash Core Group. All rights reserved.
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
#import "DSMerkleTree.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSPlatformRootMerkleTree : NSObject <NSCopying>

@property (nonatomic, readonly) uint32_t treeElementCount;
@property (nonatomic, readonly) NSData *hashes;
@property (nonatomic, readonly) NSData *flags;
@property (nonatomic, readonly) UInt256 merkleRoot;
@property (nonatomic, readonly) DSMerkleTreeHashFunction hashFunction;

+ (instancetype)merkleTreeWithElementToProve:(UInt256)element proofData:(NSData *)data hashFunction:(DSMerkleTreeHashFunction)hashFunction;

- (BOOL)merkleTreeHasRoot:(UInt256)desiredMerkleRoot;

@end

NS_ASSUME_NONNULL_END
