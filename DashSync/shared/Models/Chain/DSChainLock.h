//
//  DSChainLock.h
//  DashSync
//
//  Created by Sam Westrich on 11/25/19.
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

@class DSChain, DSQuorumEntry, DSMasternodeList;

@interface DSChainLock : NSObject

@property (nonatomic, readonly) uint32_t height;
@property (nonatomic, readonly) UInt256 blockHash;
@property (nonatomic, readonly) UInt256 requestID;
@property (nonatomic, readonly) UInt768 signature;
@property (nonatomic, readonly) BOOL signatureVerified;
@property (nonatomic, readonly) BOOL saved;
@property (nonatomic, readonly) DSQuorumEntry *intendedQuorum;

// message can be either a merkleblock or header message
+ (instancetype)chainLockWithMessage:(NSData *)message onChain:(DSChain *)chain;

- (instancetype)initWithMessage:(NSData *)message onChain:(DSChain *)chain;

- (instancetype)initWithBlockHash:(UInt256)blockHash signature:(UInt768)signature signatureVerified:(BOOL)signatureVerified quorumVerified:(BOOL)quorumVerified onChain:(DSChain *)chain;

- (instancetype)init NS_UNAVAILABLE;

- (DSQuorumEntry *)findSigningQuorumReturnMasternodeList:(DSMasternodeList *_Nullable *_Nullable)returnMasternodeList;

- (BOOL)verifySignature;

- (void)saveInitial;

- (void)saveSignatureValid;

@end

NS_ASSUME_NONNULL_END
