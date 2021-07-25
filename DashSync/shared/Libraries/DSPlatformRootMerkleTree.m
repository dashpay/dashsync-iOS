//
//  Created by Samuel Westrich
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

#import "DSPlatformRootMerkleTree.h"
#import "NSData+DSHash.h"
#import "NSData+Dash.h"
#import "NSMutableData+Dash.h"

#define ROOT_MERKLE_TREE_DEPTH 3

@interface DSPlatformRootMerkleTree ()

@property (nonatomic, assign) UInt256 elementToProve;
@property (nonatomic, strong) NSArray *proofHashes;
@property (nonatomic, strong) NSData *flags;
@property (nonatomic, assign) DSMerkleTreeHashFunction hashFunction;

@end

@implementation DSPlatformRootMerkleTree

+ (instancetype)merkleTreeWithElementToProve:(UInt256)element proofData:(NSData *)proofData hashFunction:(DSMerkleTreeHashFunction)hashFunction {
    NSUInteger off = 0, len = 0;
    uint32_t leafCount = [proofData UInt32AtOffset:off];
    NSAssert(leafCount == 1, @"leaf count must be 1");
    off += sizeof(uint32_t);
    NSNumber *l = nil;
    len = (NSUInteger)[proofData varIntAtOffset:off length:&l];
    off += l.unsignedIntegerValue;
    NSMutableArray *proofHashes = [NSMutableArray array];
    for (int i = 0; i < len; i++) {
        [proofHashes addObject:[proofData subdataWithRange:NSMakeRange(off, sizeof(UInt256))]];
        off += sizeof(UInt256);
    }
    NSData *flags = [proofData dataAtOffset:off length:&l];
    if (proofHashes.count == 0) return nil;
    return [[DSPlatformRootMerkleTree alloc] initWithElementToProve:element proofHashes:proofHashes flags:flags hashFunction:hashFunction];
}

- (instancetype)initWithElementToProve:(UInt256)element proofHashes:(NSArray *)proofHashes flags:(NSData *)flags hashFunction:(DSMerkleTreeHashFunction)hashFunction {
    if (!(self = [self init])) return nil;
    self.elementToProve = element;
    self.proofHashes = proofHashes;
    self.flags = flags;
    self.hashFunction = hashFunction;
    return self;
}

- (UInt256)hashData:(NSData *)data {
    switch (self.hashFunction) {
        case DSMerkleTreeHashFunction_SHA256_2:
            return data.SHA256_2;
            break;
        case DSMerkleTreeHashFunction_BLAKE3_2:
            return data.blake3_2;
            break;

        default:
            return data.SHA256_2;
            break;
    }
}

- (UInt256)merkleRoot {
    int i = 0;
    UInt256 merkleRoot = self.elementToProve;
    for (NSData *data in self.proofHashes) {
        BOOL proofIsRight = (((const uint8_t *)_flags.bytes)[i / 8] & (1 << (i % 8)));
        UInt256 left, right;
        if (proofIsRight) {
            right = data.UInt256;
            left = merkleRoot;
        } else {
            right = merkleRoot;
            left = data.UInt256;
        }
        UInt512 concat = uint512_concat(uint256_reverse(left), uint256_reverse(right));
        merkleRoot = uint256_reverse([self hashData:uint512_data(concat)]);
        i++;
    }
    return merkleRoot;
}

- (BOOL)merkleTreeHasRoot:(UInt256)desiredMerkleRoot {
    //DSLog(@"%@ - %@",uint256_hex(merkleRoot),uint256_hex(_merkleRoot));
    if (!uint256_eq(self.merkleRoot, desiredMerkleRoot)) return NO; // merkle root check failed
    return YES;
}

- (id)copyWithZone:(NSZone *)zone {
    DSPlatformRootMerkleTree *copy = [[[self class] alloc] init];
    copy.proofHashes = [self.proofHashes copyWithZone:zone];
    copy.flags = [self.flags copyWithZone:zone];
    copy.hashFunction = self.hashFunction;
    return copy;
}

@end
