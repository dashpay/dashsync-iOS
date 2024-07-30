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

#import <Foundation/Foundation.h>
#import "DSChainManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSChainManager (Mining)

// MARK: - Mining

- (void)mineEmptyBlocks:(uint32_t)blockCount 
       toPaymentAddress:(NSString *)paymentAddress
            withTimeout:(NSTimeInterval)timeout
             completion:(MultipleBlockMiningCompletionBlock)completion;

- (void)mineEmptyBlocks:(uint32_t)blockCount 
       toPaymentAddress:(NSString *)paymentAddress
             afterBlock:(DSBlock *)block
         previousBlocks:(NSDictionary<NSValue *, DSBlock *> *)previousBlocks
            withTimeout:(NSTimeInterval)timeout
             completion:(MultipleBlockMiningCompletionBlock)completion;

- (void)mineBlockToPaymentAddress:(NSString *)paymentAddress 
                 withTransactions:(NSArray<DSTransaction *> *_Nullable)transactions
                      withTimeout:(NSTimeInterval)timeout
                       completion:(BlockMiningCompletionBlock)completion;

- (void)mineBlockAfterBlock:(DSBlock *)block 
           toPaymentAddress:(NSString *)paymentAddress
           withTransactions:(NSArray<DSTransaction *> *_Nullable)transactions
             previousBlocks:(NSDictionary<NSValue *, DSBlock *> *)previousBlocks
                nonceOffset:(uint32_t)nonceOffset
                withTimeout:(NSTimeInterval)timeout
                 completion:(BlockMiningCompletionBlock)completion;

@end

NS_ASSUME_NONNULL_END
