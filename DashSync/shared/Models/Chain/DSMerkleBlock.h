//
//  DSMerkleBlock.h
//  DashSync
//
//  Created by Aaron Voisine for BreadWallet on 10/22/13.
//  Copyright (c) 2013 Aaron Voisine <voisine@gmail.com>
//  Copyright (c) 2018 Dash Core Group <contact@dash.org>
//  Updated by Quantum Explorer on 05/11/18.
//  Copyright (c) 2018 Quantum Explorer <quantum@dash.org>
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

#import "DSBlock.h"
#import <Foundation/Foundation.h>

#if (DEBUG && 0)
#define KEEP_RECENT_TERMINAL_BLOCKS 20000
#define LLMQ_KEEP_RECENT_DIVIDER_BLOCKS 20000
#else
#define KEEP_RECENT_TERMINAL_BLOCKS (5 * 576 * 8 + 100)
#define KEEP_RECENT_SYNC_BLOCKS 100
#endif

NS_ASSUME_NONNULL_BEGIN

typedef union _UInt256 UInt256;

@class DSChain, DSChainLock, DSCheckpoint, DSMerkleTree;

@interface DSMerkleBlock : DSBlock

@property (nonatomic, readonly) DSMerkleTree *merkleTree;

// message can be either a merkleblock or header message
+ (instancetype)merkleBlockWithMessage:(NSData *)message onChain:(DSChain *)chain;

// this init is used to check that the coinbase transaction is properly in the merkle tree of a block
- (instancetype)initWithBlockHash:(UInt256)blockHash merkleRoot:(UInt256)merkleRoot totalTransactions:(uint32_t)totalTransactions hashes:(NSData *)hashes flags:(NSData *)flags;

- (instancetype)initWithVersion:(uint32_t)version blockHash:(UInt256)blockHash prevBlock:(UInt256)prevBlock
                     merkleRoot:(UInt256)merkleRoot
                      timestamp:(uint32_t)timestamp
                         target:(uint32_t)target
                      chainWork:(UInt256)chainWork
                          nonce:(uint32_t)nonce
              totalTransactions:(uint32_t)totalTransactions
                         hashes:(NSData *_Nullable)hashes
                          flags:(NSData *_Nullable)flags
                         height:(uint32_t)height
                      chainLock:(DSChainLock *_Nullable)chainLock
                        onChain:(DSChain *)chain;

@end

NS_ASSUME_NONNULL_END
