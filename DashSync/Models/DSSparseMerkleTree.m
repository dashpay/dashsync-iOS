//
//  DSSparseMerkleTree.m
//  DashSync
//
//  Created by Sam Westrich on 11/19/19.
//  Copyright (c) 2019 Dash Core Group <quantum@dash.org>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.


#import "DSSparseMerkleTree.h"
#import "NSData+Bitcoin.h"
#import "NSArray+Dash.h"
#import "BigIntTypes.h"

@implementation DSSparseMerkleTree

+(NSData*)verifyInclusionForKey:(NSData*)key forKeyIndex:(uint32_t)keyIndex withLeafHash:(NSData*)leafHash againstHashes:(NSArray*)hashes  {
    if (keyIndex == hashes.count) {
        return leafHash;
    }
    NSData * nodeValue = [hashes objectAtIndex:hashes.count - keyIndex - 1];
    if ([key bitIsTrueAtLeftToRightIndex:keyIndex]) {
        UInt256 returnHash = [@[nodeValue, [self verifyInclusionForKey:key forKeyIndex:keyIndex+1 withLeafHash:leafHash againstHashes:hashes]] hashDataComponents];
        return uint256_data(returnHash);
    } else {
        UInt256 returnHash = [@[[self verifyInclusionForKey:key forKeyIndex:keyIndex+1 withLeafHash:leafHash againstHashes:hashes], nodeValue] hashDataComponents];
        return uint256_data(returnHash);
    }
}

+(void)verifyInclusionWithRoot:(UInt256)root forKey:(UInt256)key withValueData:(NSData*)valueData againstProofHashes:(NSArray*)hashes completion:(ProofVerificationCompletionBlock)completion {
    uint8_t height = 256 - hashes.count;
    NSData * heightData = [NSData dataWithBytes:&height length:sizeof(height)];
    UInt256 leafHash = [@[uint256_data(key), valueData, heightData] hashDataComponents];
    BOOL verified = uint256_eq(root, [self verifyInclusionForKey:uint256_data(key) forKeyIndex:0 withLeafHash:uint256_data(leafHash) againstHashes:hashes].UInt256);
    completion(verified,nil);
}

+(void)verifyNonInclusionWithRoot:(UInt256)root forKey:(UInt256)key withProofKeyData:(NSData* _Nullable)proofKeyData withProofValueData:(NSData* _Nullable)proofValueData againstProofHashes:(NSArray*)hashes completion:(ProofVerificationCompletionBlock)completion; {
    // Check if an empty subtree is on the key path
    if (!proofValueData || [proofValueData length] == 0) {
        // return true if a DefaultLeaf in the key path is included in the trie
        uint8_t zero = 0;
        NSData * defaultLeafData = [NSData dataWithBytes:&zero length:sizeof(zero)];
        BOOL verified = uint256_eq(root, [self verifyInclusionForKey:uint256_data(key) forKeyIndex:0 withLeafHash:defaultLeafData againstHashes:hashes].UInt256);
        if (completion) {
            completion(verified,nil);
        }
        return;
    }
    // Check if another kv leaf is on the key path in 2 steps
    // 1- Check the proof leaf exists
    [self verifyInclusionWithRoot:root forKey:proofKeyData.UInt256 withValueData:proofValueData againstProofHashes:hashes completion:^(BOOL verified, NSError * _Nullable error) {
        if (!verified) {
            if (completion) {
                completion(FALSE,nil);
            }
            return;
        }
        NSData * keyData = uint256_data(key);
        // 2- Check the proof leaf is on the key path
        for (uint32_t b = 0; b < hashes.count; b++) {
            if ([keyData bitIsTrueAtLeftToRightIndex:b] != [proofKeyData bitIsTrueAtLeftToRightIndex:b]) {
                if (completion) {
                    // the proofKey leaf node is not on the path of the key
                    completion(FALSE,nil);
                }
                return;
            }
        }
        // return true because we verified another leaf is on the key path
        if (completion) {
            completion(TRUE,nil);
        }
    }];
}

+(NSData*)verifyCompressedInclusionForKey:(NSData*)key forKeyIndex:(uint32_t)keyIndex forHashIndex:(uint32_t)hashIndex withLeafHash:(NSData*)leafHash againstHashes:(NSArray*)hashes compressionData:(NSData*)compressionData length:(uint32_t)length  {
    if (keyIndex == length) {
        return leafHash;
    }
    if ([key bitIsTrueAtLeftToRightIndex:keyIndex]) {
        if ([compressionData bitIsTrueAtLeftToRightIndex:length - keyIndex - 1]) {
            UInt256 returnHash = [@[[hashes objectAtIndex:hashes.count - hashIndex - 1], [self verifyCompressedInclusionForKey:key forKeyIndex:keyIndex + 1 forHashIndex:hashIndex + 1 withLeafHash:leafHash againstHashes:hashes compressionData:compressionData length:length]] hashDataComponents];
            return uint256_data(returnHash);
        } else {
            uint8_t zero = 0;
            NSData * defaultNodeData = [NSData dataWithBytes:&zero length:sizeof(zero)];
            UInt256 returnHash = [@[defaultNodeData, [self verifyCompressedInclusionForKey:key forKeyIndex:keyIndex + 1 forHashIndex:hashIndex withLeafHash:leafHash againstHashes:hashes compressionData:compressionData length:length]] hashDataComponents];
            return uint256_data(returnHash);
        }
    } else {
        if ([compressionData bitIsTrueAtLeftToRightIndex:length - keyIndex - 1]) {
            UInt256 returnHash = [@[[self verifyCompressedInclusionForKey:key forKeyIndex:keyIndex + 1 forHashIndex:hashIndex + 1 withLeafHash:leafHash againstHashes:hashes compressionData:compressionData length:length],[hashes objectAtIndex:hashes.count - hashIndex - 1]] hashDataComponents];
            return uint256_data(returnHash);
        } else {
            uint8_t zero = 0;
            NSData * defaultNodeData = [NSData dataWithBytes:&zero length:sizeof(zero)];
            UInt256 returnHash = [@[[self verifyCompressedInclusionForKey:key forKeyIndex:keyIndex + 1 forHashIndex:hashIndex withLeafHash:leafHash againstHashes:hashes compressionData:compressionData length:length],defaultNodeData] hashDataComponents];
            return uint256_data(returnHash);
        }
    }
}

+(void)verifyCompressedInclusionWithRoot:(UInt256)root forKey:(UInt256)key withValueData:(NSData*)valueData againstProofHashes:(NSArray*)hashes compressionData:(NSData*)compressionData length:(uint32_t)length completion:(ProofVerificationCompletionBlock)completion {
    uint8_t height = 256 - length;
    NSData * heightData = [NSData dataWithBytes:&height length:sizeof(height)];
    UInt256 leafHash = [@[uint256_data(key), valueData, heightData] hashDataComponents];
    BOOL verified = uint256_eq(root, [self verifyCompressedInclusionForKey:uint256_data(key) forKeyIndex:0 forHashIndex:0 withLeafHash:uint256_data(leafHash) againstHashes:hashes compressionData:compressionData length:length].UInt256);
    completion(verified,nil);
}

+(void)verifyCompressedNonInclusionWithRoot:(UInt256)root forKey:(UInt256)key withProofKeyData:(NSData* _Nullable)proofKeyData withProofValueData:(NSData*)proofValueData againstProofHashes:(NSArray*)hashes compressionData:(NSData*)compressionData length:(uint32_t)length completion:(ProofVerificationCompletionBlock)completion {
    // Check if an empty subtree is on the key path
    if (!proofValueData || [proofValueData length] == 0) {
        // return true if a DefaultLeaf in the key path is included in the trie
        uint8_t zero = 0;
        NSData * defaultLeafData = [NSData dataWithBytes:&zero length:sizeof(zero)];
        BOOL verified = uint256_eq(root, [self verifyCompressedInclusionForKey:uint256_data(key) forKeyIndex:0 forHashIndex:0 withLeafHash:defaultLeafData againstHashes:hashes compressionData:compressionData length:length].UInt256);
        if (completion) {
            completion(verified,nil);
        }
        return;
    }
    // Check if another kv leaf is on the key path in 2 steps
    // 1- Check the proof leaf exists
    [self verifyCompressedInclusionWithRoot:root forKey:proofKeyData.UInt256 withValueData:proofValueData againstProofHashes:hashes compressionData:compressionData length:length completion:^(BOOL verified, NSError * _Nullable error) {
        if (!verified) {
            if (completion) {
                completion(FALSE,nil);
            }
            return;
        }
        NSData * keyData = uint256_data(key);
        // 2- Check the proof leaf is on the key path
        for (uint32_t b = 0; b < hashes.count; b++) {
            if ([keyData bitIsTrueAtLeftToRightIndex:b] != [proofKeyData bitIsTrueAtLeftToRightIndex:b]) {
                if (completion) {
                    // the proofKey leaf node is not on the path of the key
                    completion(FALSE,nil);
                }
                return;
            }
        }
        // return true because we verified another leaf is on the key path
        if (completion) {
            completion(TRUE,nil);
        }
    }];
}

@end
