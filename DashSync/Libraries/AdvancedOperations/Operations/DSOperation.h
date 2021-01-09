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

#import <Foundation/Foundation.h>

#import "DSOperationConditionProtocol.h"
#import "DSOperationObserverProtocol.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, DSOperationState)
{
    /// The initial state of an `DSOperation`.
    DSOperationStateInitialized,

    /// The `DSOperation` is ready to begin evaluating conditions.
    DSOperationStatePending,

    /// The `DSOperation` is evaluating conditions.
    DSOperationStateEvaluatingConditions,

    /// The `DSOperation`'s conditions have all been satisfied, and it is ready to execute.
    DSOperationStateReady,

    /// The `DSOperation` is executing.
    DSOperationStateExecuting,

    /// Execution of the `DSOperation` has finished, but it has not yet notified the queue of this.
    DSOperationStateFinishing,

    /// The `DSOperation` has finished executing.
    DSOperationStateFinished
};

@class DSOperationQueue;

@interface DSOperation : NSOperation

@property (readonly, getter=isCancelled) BOOL cancelled;
@property (nonatomic, assign) BOOL userInitiated;
@property (atomic, readonly) DSOperationState state;

@property (nonatomic, weak, readonly, nullable) DSOperationQueue *enqueuedOperationQueue;

@property (nonatomic, copy, readonly) NSArray<NSObject<DSOperationConditionProtocol> *> *conditions;
@property (nonatomic, copy, readonly) NSArray<NSObject<DSOperationObserverProtocol> *> *observers;
@property (nonatomic, copy, readonly) NSArray<NSError *> *internalErrors;

- (void)addObserver:(NSObject<DSOperationObserverProtocol> *)observer;
- (void)addCondition:(NSObject<DSOperationConditionProtocol> *)condition;

- (void)willEnqueueInOperationQueue:(DSOperationQueue *)operationQueue NS_REQUIRES_SUPER;

- (void)finish;
- (void)finishWithErrors:(nullable NSArray<NSError *> *)errors NS_REQUIRES_SUPER;
- (void)finishWithError:(nullable NSError *)error;

- (void)finishedWithErrors:(NSArray<NSError *> *)errors;

- (void)cancel NS_REQUIRES_SUPER;
- (void)cancelWithError:(nullable NSError *)error;
- (void)cancelWithErrors:(nullable NSArray<NSError *> *)errors;

- (void)execute;
- (void)produceOperation:(NSOperation *)operation NS_REQUIRES_SUPER;

@end

NS_ASSUME_NONNULL_END
