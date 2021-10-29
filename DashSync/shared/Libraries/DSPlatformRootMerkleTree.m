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

@property (nonatomic, strong) NSDictionary<NSNumber *, NSData *> *elementsToProve;
@property (nonatomic, strong) NSMutableArray<NSData *> *proofHashes;
@property (nonatomic, assign) DSMerkleTreeHashFunction hashFunction;
@property (nonatomic, assign) uint32_t fixedElementCount;

@end

@implementation DSPlatformRootMerkleTree

+ (instancetype)merkleTreeWithElementsToProve:(NSDictionary *)elements proofData:(NSData *)proofData hashFunction:(DSMerkleTreeHashFunction)hashFunction fixedElementCount:(uint32_t)fixedElementCount {
    NSMutableArray *proofHashes = [NSMutableArray array];
    for (int off = 0; off < proofData.length; off += sizeof(UInt256)) {
        [proofHashes addObject:[proofData subdataWithRange:NSMakeRange(off, sizeof(UInt256))]];
    }
    return [[DSPlatformRootMerkleTree alloc] initWithElementsToProve:elements proofHashes:proofHashes hashFunction:hashFunction fixedElementCount:fixedElementCount];
}

- (instancetype)initWithElementsToProve:(NSDictionary *)elements proofHashes:(NSArray *)proofHashes hashFunction:(DSMerkleTreeHashFunction)hashFunction fixedElementCount:(uint32_t)fixedElementCount {
    if (!(self = [self init])) return nil;
    self.fixedElementCount = fixedElementCount;
    self.elementsToProve = elements;
    self.proofHashes = [proofHashes mutableCopy];
    self.hashFunction = hashFunction;
    return self;
}

- (UInt256)hashData:(NSData *)data {
    switch (self.hashFunction) {
        case DSMerkleTreeHashFunction_SHA256_2:
            return data.SHA256_2;
            break;
        case DSMerkleTreeHashFunction_BLAKE3:
            return data.blake3;
            break;

        default:
            return data.SHA256_2;
            break;
    }
}

- (UInt256)merkleRoot {
    NSDictionary<NSNumber *, NSData *> *rowElements = self.elementsToProve;
    uint32_t rowSize = self.fixedElementCount;
    while (self.proofHashes.count > 0 || rowElements.count > 1) {
        NSMutableDictionary *nextRowElements = [NSMutableDictionary dictionary];
        NSMutableArray *positions = [rowElements.allKeys mutableCopy];
        [positions sortUsingSelector:@selector(compare:)];
        for (int i = 0; i < positions.count; i++) {
            NSNumber *number = positions[i];
            NSData *storeTreeRootHash = rowElements[number];
            UInt256 left, right;
            int pos = [number intValue];
            if (pos == rowSize - 1 && rowSize % 2) {
                [nextRowElements setObject:storeTreeRootHash forKey:@(pos / 2)];
                continue;
            }
            if ([number intValue] % 2) {
                //Right side
                right = storeTreeRootHash.UInt256;
                left = self.proofHashes.firstObject.UInt256;
                [self.proofHashes removeObjectAtIndex:0];
            } else {
                //Left Side
                left = storeTreeRootHash.UInt256;
                if (rowElements[@(pos + 1)]) {
                    // Both elements are known, no proof needed
                    right = rowElements[@(pos + 1)].UInt256;
                    i++;
                } else {
                    right = self.proofHashes.firstObject.UInt256;
                    [self.proofHashes removeObjectAtIndex:0];
                }
            }
            UInt512 concat = uint512_concat(left, right);
            UInt256 merkleRoot = [self hashData:uint512_data(concat)];
            [nextRowElements setObject:uint256_data(merkleRoot) forKey:@(pos / 2)];
            //            NSLog(@"hash %@ gives %@", uint512_hex(concat), uint256_hex(merkleRoot));
        }
        rowElements = nextRowElements;
        rowSize = ceilf(((float)rowSize) / 2);
    }
    return rowElements[@(0)].UInt256;
}

- (BOOL)merkleTreeHasRoot:(UInt256)desiredMerkleRoot {
    //DSLog(@"%@ - %@",uint256_hex(merkleRoot),uint256_hex(_merkleRoot));
    if (!uint256_eq(self.merkleRoot, desiredMerkleRoot)) return NO; // merkle root check failed
    return YES;
}

- (id)copyWithZone:(NSZone *)zone {
    DSPlatformRootMerkleTree *copy = [[[self class] alloc] init];
    copy.fixedElementCount = self.fixedElementCount;
    copy.elementsToProve = [self.elementsToProve copyWithZone:zone];
    copy.proofHashes = [self.proofHashes copyWithZone:zone];
    copy.hashFunction = self.hashFunction;
    return copy;
}

@end
