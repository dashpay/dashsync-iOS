//  
//  Created by Vladimir Pirogov
//  Copyright © 2024 Dash Core Group. All rights reserved.
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

#import "DSChain+Protected.h"
#import "DSChainManager+Protected.h"
#import "DSChainManager+Mining.h"
#import "DSFullBlock.h"
#import "NSError+Dash.h"

@implementation DSChainManager (Mining)

- (void)mineEmptyBlocks:(uint32_t)blockCount
       toPaymentAddress:(NSString *)paymentAddress
            withTimeout:(NSTimeInterval)timeout
             completion:(MultipleBlockMiningCompletionBlock)completion {
    [self mineEmptyBlocks:blockCount toPaymentAddress:paymentAddress afterBlock:self.chain.lastTerminalBlock previousBlocks:self.chain.terminalBlocks withTimeout:timeout completion:completion];
}

- (void)mineEmptyBlocks:(uint32_t)blockCount 
       toPaymentAddress:(NSString *)paymentAddress
             afterBlock:(DSBlock *)previousBlock
         previousBlocks:(NSDictionary<NSValue *, DSBlock *> *)previousBlocks
            withTimeout:(NSTimeInterval)timeout
             completion:(MultipleBlockMiningCompletionBlock)completion {
    dispatch_async(self.miningQueue, ^{
        NSTimeInterval start = [[NSDate date] timeIntervalSince1970];
        NSTimeInterval end = [[[NSDate alloc] initWithTimeIntervalSinceNow:timeout] timeIntervalSince1970];
        NSMutableArray *blocksArray = [NSMutableArray array];
        NSMutableArray *attemptsArray = [NSMutableArray array];
        __block uint32_t blocksRemaining = blockCount;
        __block NSMutableDictionary<NSValue *, DSBlock *> *mPreviousBlocks = [previousBlocks mutableCopy];
        __block DSBlock *currentBlock = previousBlock;
        while ([[NSDate date] timeIntervalSince1970] < end && blocksRemaining > 0) {
            dispatch_semaphore_t sem = dispatch_semaphore_create(0);
            [self mineBlockAfterBlock:currentBlock
                     toPaymentAddress:paymentAddress
                     withTransactions:[NSArray array]
                       previousBlocks:mPreviousBlocks
                          nonceOffset:0
                          withTimeout:timeout
                           completion:^(DSFullBlock *_Nullable block, NSUInteger attempts, NSTimeInterval timeUsed, NSError *_Nullable error) {
                               NSAssert(uint256_is_not_zero(block.blockHash), @"Block hash must not be empty");
                               dispatch_semaphore_signal(sem);
                               [blocksArray addObject:block];
                               [mPreviousBlocks setObject:block forKey:uint256_obj(block.blockHash)];
                               currentBlock = block;
                               blocksRemaining--;
                               [attemptsArray addObject:@(attempts)];
                           }];
            dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
        }
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(blocksArray, attemptsArray, [[NSDate date] timeIntervalSince1970] - start, nil);
            });
        }
    });
}

- (void)mineBlockToPaymentAddress:(NSString *)paymentAddress 
                 withTransactions:(NSArray<DSTransaction *> *)transactions
                      withTimeout:(NSTimeInterval)timeout
                       completion:(BlockMiningCompletionBlock)completion {
    [self mineBlockAfterBlock:self.chain.lastTerminalBlock toPaymentAddress:paymentAddress withTransactions:transactions previousBlocks:self.chain.terminalBlocks nonceOffset:0 withTimeout:timeout completion:completion];
}

- (void)mineBlockAfterBlock:(DSBlock *)block 
           toPaymentAddress:(NSString *)paymentAddress
           withTransactions:(NSArray<DSTransaction *> *)transactions
             previousBlocks:(NSDictionary<NSValue *, DSBlock *> *)previousBlocks
                nonceOffset:(uint32_t)nonceOffset 
                withTimeout:(NSTimeInterval)timeout
                 completion:(nonnull BlockMiningCompletionBlock)completion {
    DSCoinbaseTransaction *coinbaseTransaction = [[DSCoinbaseTransaction alloc] initWithCoinbaseMessage:@"From iOS" paymentAddresses:@[paymentAddress] atHeight:block.height + 1 onChain:block.chain];
    DSFullBlock *fullblock = [[DSFullBlock alloc] initWithCoinbaseTransaction:coinbaseTransaction transactions:[NSSet set] previousBlockHash:block.blockHash previousBlocks:previousBlocks timestamp:[[NSDate date] timeIntervalSince1970] height:block.height + 1 onChain:self.chain];
    uint64_t attempts = 0;
    NSDate *startTime = [NSDate date];
    if ([fullblock mineBlockAfterBlock:block withNonceOffset:nonceOffset withTimeout:timeout rAttempts:&attempts]) {
        if (completion) {
            completion(fullblock, attempts, -[startTime timeIntervalSinceNow], nil);
        }
    } else {
        if (completion) {
            NSError *error = [NSError errorWithCode:500 localizedDescriptionKey:@"A block could not be mined in the selected time interval."];
            completion(nil, attempts, -[startTime timeIntervalSinceNow], error);
        }
    }
}

@end
