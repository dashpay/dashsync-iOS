//
//  Created by Andrew Podkovyrin
//  Copyright © 2018 Dash Core Group. All rights reserved.
//  Copyright © 2015 Michal Zaborowski. All rights reserved.
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

#import "DSOperation.h"

NS_ASSUME_NONNULL_BEGIN

@class DSBlockOperation;

typedef void (^DSBlockOperationCompletionBlock)(void);
typedef void (^DSBlockOperationBlock)(DSBlockOperation *operation, DSBlockOperationCompletionBlock completionBlock);

/// A sublcass of `DSOperation` to execute a block.
@interface DSBlockOperation : DSOperation

@property (nonatomic, copy) DSBlockOperationBlock block;

/**
 The designated initializer.
 
 - parameter block: The closure to run when the operation executes. This
 closure will be run on an arbitrary queue. The parameter passed to the
 block **MUST** be invoked by your code, or else the `BlockOperation`
 will never finish executing. If this parameter is `nil`, the operation
 will immediately finish.
 */
- (instancetype)initWithBlock:(DSBlockOperationBlock)block;

+ (instancetype)operationWithBlock:(DSBlockOperationBlock)block;

/**
 A convenience initializer to execute a block on the main queue.
 
 - parameter mainQueueBlock: The block to execute on the main queue. Note
 that this block does not have a "continuation" block to execute (unlike
 the designated initializer). The operation will be automatically ended
 after the `mainQueueBlock` is executed.
 */
- (instancetype)initWithMainQueueBlock:(dispatch_block_t)block;

+ (instancetype)operationWithMainQueueBlock:(dispatch_block_t)block;

@end

NS_ASSUME_NONNULL_END
