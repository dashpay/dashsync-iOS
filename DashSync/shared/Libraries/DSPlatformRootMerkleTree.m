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

@interface DSPlatformRootMerkleTree ()

@property (nonatomic, assign) UInt256 elementToProve;
@property (nonatomic, strong) NSData *proofHashes;
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
    len = (NSUInteger)[proofData varIntAtOffset:off length:&l] * sizeof(UInt256);
    off += l.unsignedIntegerValue;
    NSData *proofHashes = (off + len > proofData.length) ? nil : [proofData subdataWithRange:NSMakeRange(off, len)];
    off += len;
    NSData *flags = [proofData dataAtOffset:off length:&l];
    if (proofHashes.length == 0) return nil;
    return [[DSPlatformRootMerkleTree alloc] initWithElementToProve:element proofHashes:proofHashes flags:flags hashFunction:hashFunction];
}

- (instancetype)initWithElementToProve:(UInt256)element proofHashes:(NSData *)proofHashes flags:(NSData *)flags hashFunction:(DSMerkleTreeHashFunction)hashFunction {
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
    int hashIdx = 0, flagIdx = 0;
    UInt256 merkleRoot = [self walkHashIdx:&hashIdx
        flagIdx:&flagIdx
        depth:0
        leaf:^UInt256(UInt256 hash, BOOL flag) {
            return hash;
        }
        branch:^UInt256(UInt256 left, UInt256 right) {
            UInt512 concat = uint512_concat(left, right);
            return [self hashData:uint512_data(concat)];
        }];
    return merkleRoot;
}

- (BOOL)merkleTreeHasRoot:(UInt256)desiredMerkleRoot {
    //DSLog(@"%@ - %@",uint256_hex(merkleRoot),uint256_hex(_merkleRoot));
    if (self.treeElementCount > 0 && !uint256_eq(self.merkleRoot, desiredMerkleRoot)) return NO; // merkle root check failed
    return YES;
}

// recursively walks the merkle tree in depth first order, calling leaf(hash, flag) for each stored hash, and
// branch(left, right) with the result from each branch
- (UInt256)walkHashIdx:(int *)hashIdx flagIdx:(int *)flagIdx
            depth:(int)depth
             leaf:(UInt256 (^)(UInt256, BOOL))leaf
           branch:(UInt256 (^)(UInt256, UInt256))branch {
    if ((*flagIdx) / 8 >= _flags.length || (*hashIdx + 1) * sizeof(UInt256) > _hashes.length) return leaf(UINT256_ZERO, NO);

    BOOL flag = (((const uint8_t *)_flags.bytes)[*flagIdx / 8] & (1 << (*flagIdx % 8)));

    (*flagIdx)++;

    if (!flag || depth == ceil_log2(self.treeElementCount)) {
        UInt256 hash = [_hashes UInt256AtOffset:(*hashIdx) * sizeof(UInt256)];

        (*hashIdx)++;
        return leaf(hash, flag);
    }

    UInt256 left = [self walkHashIdx:hashIdx flagIdx:flagIdx depth:depth + 1 leaf:leaf branch:branch];
    UInt256 right = [self walkHashIdx:hashIdx flagIdx:flagIdx depth:depth + 1 leaf:leaf branch:branch];

    return branch(left, right);
}

- (id)copyWithZone:(NSZone *)zone {
    DSPlatformRootMerkleTree *copy = [[[self class] alloc] init];
    copy.hashes = [self.hashes copyWithZone:zone];
    copy.flags = [self.flags copyWithZone:zone];
    copy.hashFunction = self.hashFunction;
    return copy;
}

@end
