//
//  DSSparseMerkleTree.h
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


#import "BigIntTypes.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(uint16_t, DSSparseMerkleTreeProofType) {
    DSSparseMerkleTreeProofType_Inclusion,
    DSSparseMerkleTreeProofType_NonInclusion,
};

typedef void (^ProofVerificationCompletionBlock)(BOOL verified, NSError *_Nullable error);


@interface DSSparseMerkleTree : NSObject

+ (void)verifyInclusionWithRoot:(UInt256)root forKey:(UInt256)key withValueData:(NSData *)valueData againstProofHashes:(NSArray *)hashes completion:(ProofVerificationCompletionBlock)completion;

+ (void)verifyNonInclusionWithRoot:(UInt256)root forKey:(UInt256)key withProofKeyData:(NSData *_Nullable)proofKey withProofValueData:(NSData *_Nullable)valueData againstProofHashes:(NSArray *)hashes completion:(ProofVerificationCompletionBlock)completion;

+ (void)verifyCompressedInclusionWithRoot:(UInt256)root forKey:(UInt256)key withValueData:(NSData *)valueData againstProofHashes:(NSArray *)hashes compressionData:(NSData *)compressionData length:(uint32_t)length completion:(ProofVerificationCompletionBlock)completion;

+ (void)verifyCompressedNonInclusionWithRoot:(UInt256)root forKey:(UInt256)key withProofKeyData:(NSData *_Nullable)proofKeyData withProofValueData:(NSData *)proofValueData againstProofHashes:(NSArray *)hashes compressionData:(NSData *)compressionData length:(uint32_t)length completion:(ProofVerificationCompletionBlock)completion;

@end

NS_ASSUME_NONNULL_END
