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

#import "DSChainedOperation.h"
#import "DSOperationQueue.h"

@interface DSChainedOperation () <DSOperationQueueDelegate>

@property (nonatomic, strong) DSOperationQueue *internalQueue;
@property (nonatomic, copy) NSBlockOperation *finishingOperation;
@property (nonatomic, strong) NSMutableArray<NSError *> *aggregatedErrors;
@property (nonatomic, copy) NSArray<NSOperation *> *operations;

@end

@implementation DSChainedOperation

+ (instancetype)operationWithOperations:(NSArray<NSOperation<DSChainableOperationProtocol> *> *)operations {
    return [[[self class] alloc] initWithOperations:operations];
}

- (instancetype)initWithOperations:(NSArray<NSOperation<DSChainableOperationProtocol> *> *)operations {
    self = [super init];
    if (self) {
        _finishIfProducedAnyError = YES;
        _finishingOperation = [NSBlockOperation blockOperationWithBlock:^{
        }];
        _aggregatedErrors = [NSMutableArray array];
        _internalQueue = [[DSOperationQueue alloc] init];
        _internalQueue.maxConcurrentOperationCount = 1;
        _internalQueue.suspended = YES;
        _internalQueue.delegate = self;
        _operations = operations ?: @[];
    }
    return self;
}

- (void)cancel {
    [self.internalQueue cancelAllOperations];
    self.internalQueue.suspended = NO;
    [super cancel];
}

- (void)execute {
    if (self.operations.count <= 0) {
        [self finish];
        return;
    }

    NSOperation *dependencyOperation = nil;
    for (NSOperation *op in self.operations) {
        if (dependencyOperation) {
            [op addDependency:dependencyOperation];
        }
        [_internalQueue addOperation:op];
        dependencyOperation = op;
    }

    [self.internalQueue addOperation:self.finishingOperation];
    self.internalQueue.suspended = NO;
}

- (void)addOperation:(NSOperation *)operation {
    if ([self isCancelled] || [self isFinished]) {
        return;
    }
    NSParameterAssert(self.state < DSOperationStateExecuting);

    self.operations = [self.operations arrayByAddingObject:operation];
}

/**
 Note that some part of execution has produced an error.
 Errors aggregated through this method will be included in the final array
 of errors reported to observers and to the `finished:` method.
 */
- (void)aggregateError:(NSError *)error {
    [self.aggregatedErrors addObject:error];
}

- (void)operationDidFinish:(NSOperation *)operation withErrors:(NSArray<NSError *> *)errors {
    NSInteger nextOperationIndex = [self.internalQueue.operations indexOfObject:operation] + 1;
    if (self.internalQueue.operationCount > nextOperationIndex) {
        NSOperation<DSChainableOperationProtocol> *nextOperation = self.internalQueue.operations[nextOperationIndex];
        if ([nextOperation conformsToProtocol:@protocol(DSChainableOperationProtocol)]) {

            id additionalObject = nil;
            if ([operation conformsToProtocol:@protocol(DSChainableOperationProtocol)] && [operation respondsToSelector:@selector(additionalDataToPassForChainedOperation)]) {
                additionalObject = [(id<DSChainableOperationProtocol>)operation additionalDataToPassForChainedOperation];
            }

            if ([nextOperation respondsToSelector:@selector(chainedOperation:didFinishWithErrors:passingAdditionalData:)]) {
                [nextOperation chainedOperation:operation didFinishWithErrors:errors passingAdditionalData:additionalObject];
            }
        }
    };
}

#pragma mark - DSOperationQueueDelegate
- (void)operationQueue:(DSOperationQueue *)operationQueue willAddOperation:(NSOperation *)operation {
    NSAssert(!self.finishingOperation.finished && !self.finishingOperation.executing, @"cannot add new operations to a group after the group has completed");

    /*
     Some operation in this group has produced a new operation to execute.
     We want to allow that operation to execute before the group completes,
     so we'll make the finishing operation dependent on this newly-produced operation.
     */
    if (operation != self.finishingOperation) {
        [self.finishingOperation addDependency:operation];
    }
}
- (void)operationQueue:(DSOperationQueue *)operationQueue operationDidFinish:(NSOperation *)operation withErrors:(NSArray<NSError *> *)errors {
    [self.aggregatedErrors addObjectsFromArray:errors];

    if (operation == self.finishingOperation) {
        [self finishWithErrors:[self.aggregatedErrors copy]];
        if (self.internalQueue.operations.count > 0) {
            [self.internalQueue cancelAllOperations];
        }
    }
    else if (self.finishIfProducedAnyError && self.aggregatedErrors.count) {
        self.internalQueue.suspended = YES;
        [self.internalQueue cancelAllOperations];
        self.internalQueue.suspended = NO;
        [self finishWithErrors:[self.aggregatedErrors copy]];
    }
    else {
        [self operationDidFinish:operation withErrors:errors];
    }
}

@end
