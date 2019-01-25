//
//  Created by Andrew Podkovyrin
//  Copyright © 2019 Dash Core Group. All rights reserved.
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

@class DSOperationQueue;

/**
 A subclass of `DSOperation` that executes zero or more operations as part of its
 own execution. This class of operation is very useful for abstracting several
 smaller operations into a larger operation.
 
 Additionally, `DSGroupOperation`s are useful if you establish a chain of dependencies,
 but part of the chain may "loop". For example, if you have an operation that
 requires the user to be authenticated, you may consider putting the "login"
 operation inside a group operation. That way, the "login" operation may produce
 subsequent operations (still within the outer `DSGroupOperation`) that will all
 be executed before the rest of the operations in the initial chain of operations.
 */
@interface DSGroupOperation : DSOperation

@property (nonatomic, strong, readonly) DSOperationQueue *internalQueue;

+ (instancetype)operationWithOperations:(nullable NSArray<NSOperation *> *)operations;
- (instancetype)initWithOperations:(nullable NSArray<NSOperation *> *)operations;

- (void)addOperation:(NSOperation *)operation;
- (void)aggregateError:(NSError *)error;
- (void)operationDidFinish:(NSOperation *)operation withErrors:(nullable NSArray<NSError *> *)errors;

@end

NS_ASSUME_NONNULL_END
