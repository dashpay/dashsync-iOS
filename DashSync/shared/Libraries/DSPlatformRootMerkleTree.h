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

#import "DSMerkleTree.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DSPlatformRootMerkleTree : NSObject <NSCopying>

@property (nonatomic, readonly) UInt256 merkleRoot;
@property (nonatomic, readonly) DSMerkleTreeHashFunction hashFunction;

+ (instancetype)merkleTreeWithElementsToProve:(NSDictionary *)elements proofData:(NSData *)proofData hashFunction:(DSMerkleTreeHashFunction)hashFunction fixedElementCount:(uint32_t)fixedElementCount;

- (BOOL)merkleTreeHasRoot:(UInt256)desiredMerkleRoot;

@end

NS_ASSUME_NONNULL_END
