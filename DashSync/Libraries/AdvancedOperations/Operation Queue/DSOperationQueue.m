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

#import "DSOperationQueue.h"
#import "DSBlockOperationObserver.h"
#import "DSOperation.h"
#import "NSOperation+DSOperationKit.h"

@implementation DSOperationQueue

- (void)addOperation:(NSOperation *)operationToAdd {
    if ([self.operations containsObject:operationToAdd]) {
        return;
    }

    if ([operationToAdd isKindOfClass:[DSOperation class]]) {
        DSOperation *operation = (DSOperation *)operationToAdd;
        __weak typeof(self) weakSelf = self;
        // Set up a `DSBlockOperationObserver` to invoke the `DSOperationQueueDelegate` method.
        DSBlockOperationObserver *delegate = [[DSBlockOperationObserver alloc]
            initWithWillStartHandler:nil
            didStartHandler:nil
            produceHandler:^(DSOperation *operation, NSOperation *producedOperation) {
                [weakSelf addOperation:producedOperation];
            }
            finishHandler:^(DSOperation *operation, NSArray *errors) {
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf) {
                    return;
                }

                if ([strongSelf.delegate respondsToSelector:@selector(operationQueue:operationDidFinish:withErrors:)]) {
                    [strongSelf.delegate operationQueue:strongSelf operationDidFinish:operation withErrors:errors];
                }
            }];

        [operation addObserver:delegate];

        // Extract any dependencies needed by this operation.
        NSMutableArray *dependencies = [NSMutableArray arrayWithCapacity:operation.conditions.count];
        [operation.conditions enumerateObjectsUsingBlock:^(NSObject<DSOperationConditionProtocol> *condition, NSUInteger idx, BOOL *stop) {
            NSOperation *dependency = [condition dependencyForOperation:operation];
            if (dependency) {
                [dependencies addObject:dependency];
            }
        }];

        [dependencies enumerateObjectsUsingBlock:^(NSOperation *dependency, NSUInteger idx, BOOL *stop) {
            [operation addDependency:dependency];

            [self addOperation:dependency];
        }];

        [operation willEnqueueInOperationQueue:self];
    }
    else {
        /*
         For regular `NSOperation`s, we'll manually call out to the queue's
         delegate we don't want to just capture "operation" because that
         would lead to the operation strongly referencing itself and that's
         the pure definition of a memory leak.
         */
        __weak typeof(self) weakSelf = self;
        __weak NSOperation *weakOperation = operationToAdd;
        [operationToAdd ds_addCompletionBlock:^(DSOperation *op) {
            DSOperationQueue *operationQueue = weakSelf;
            NSOperation *operation = weakOperation;
            if (operationQueue && operation) {
                if ([operationQueue.delegate respondsToSelector:@selector(operationQueue:operationDidFinish:withErrors:)]) {
                    [operationQueue.delegate operationQueue:operationQueue operationDidFinish:operation withErrors:nil];
                }
            }
            else {
                return;
            }
        }];
    }
    if ([self.delegate respondsToSelector:@selector(operationQueue:willAddOperation:)]) {
        [self.delegate operationQueue:self willAddOperation:operationToAdd];
    }
    [super addOperation:operationToAdd];
}

- (void)addOperations:(NSArray<NSOperation *> *)operations waitUntilFinished:(BOOL)wait {
    /*
     The base implementation of this method does not call `addOperation:`,
     so we'll call it ourselves.
     */
    for (NSOperation *operation in operations) {
        if ([operation isKindOfClass:[NSOperation class]]) {
            [self addOperation:operation];
        }
    }
    if (wait) {
        for (NSOperation *operation in operations) {
            if ([operation isKindOfClass:[NSOperation class]]) {
                [operation waitUntilFinished];
            }
        }
    }
}

@end
