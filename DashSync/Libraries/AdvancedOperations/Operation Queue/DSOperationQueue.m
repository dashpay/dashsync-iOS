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

@interface DSOperationQueue ()

@property (nonatomic, strong) NSMutableSet *chainOperationsCache;

@end

@implementation DSOperationQueue

- (NSMutableSet *)chainOperationsCache {
    if (!_chainOperationsCache) {
        _chainOperationsCache = [NSMutableSet set];
    }
    return _chainOperationsCache;
}

- (void)addOperation:(NSOperation *)operationToAdd {
    if ([self.operations containsObject:operationToAdd]) {
        return;
    }

    if ([operationToAdd isKindOfClass:[DSOperation class]]) {
        DSOperation *operation = (DSOperation *)operationToAdd;

        // Chain operation cache is imporatant to be able to add any operation from chain
        // and whole chain will be added to queue
        if (operation.chainedOperations.count > 0 && ![self.chainOperationsCache containsObject:operation] && ![self.operations containsObject:operation]) {
            [self.chainOperationsCache addObject:operation];
            [[operation.chainedOperations allObjects] enumerateObjectsUsingBlock:^(DSOperation<DSChainableOperationProtocol> *_Nonnull chainOperation, NSUInteger idx, BOOL *_Nonnull stop) {
                [self addOperation:chainOperation];
            }];

            return;
        }

        __weak typeof(self) weakSelf = self;
        // Set up a `DSBlockOperationObserver` to invoke the `DSOperationQueueDelegate` method.
        DSBlockOperationObserver *delegate = [[DSBlockOperationObserver alloc]
            initWithWillStartHandler:nil
            didStartHandler:nil
            produceHandler:^(DSOperation *operation, NSOperation *producedOperation) {
                [weakSelf addOperation:producedOperation];
            }
            finishHandler:^(DSOperation *operation, NSArray *errors) {
                [weakSelf.chainOperationsCache removeObject:operation];

                if ([weakSelf.delegate respondsToSelector:@selector(operationQueue:operationDidFinish:withErrors:)]) {
                    [weakSelf.delegate operationQueue:weakSelf operationDidFinish:operation withErrors:errors];
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

            // Chain operation cache is imporatant to be able to add any operation from chain
            // and whole chain will be added to queue
            if ([dependency isKindOfClass:[DSOperation class]]) {
                DSOperation *dependencyOperation = (DSOperation *)dependency;
                if (dependencyOperation.chainedOperations.count > 0) {
                    [self.chainOperationsCache addObject:dependencyOperation];
                }
            }

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
