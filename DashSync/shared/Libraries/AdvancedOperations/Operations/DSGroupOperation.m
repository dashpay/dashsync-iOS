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

#import "DSGroupOperation.h"
#import "DSOperationQueue.h"

@interface DSGroupOperation () <DSOperationQueueDelegate>

@property (nonatomic, strong) DSOperationQueue *internalQueue;
@property (nonatomic, copy) NSBlockOperation *finishingOperation;
@property (nonatomic, strong) NSMutableArray<NSError *> *aggregatedErrors;

@end

@implementation DSGroupOperation

+ (instancetype)operationWithOperations:(NSArray<NSOperation *> *)operations {
    return [[[self class] alloc] initWithOperations:operations];
}

- (instancetype)initWithOperations:(NSArray<NSOperation *> *)operations {
    self = [super init];
    if (self) {
        _finishingOperation = [NSBlockOperation blockOperationWithBlock:^{
        }];
        _aggregatedErrors = [NSMutableArray array];
        _internalQueue = [[DSOperationQueue alloc] init];
        _internalQueue.suspended = YES;
        _internalQueue.delegate = self;

        for (NSOperation *op in operations) {
            [_internalQueue addOperation:op];
        }
    }
    return self;
}

- (void)cancel {
    [self.internalQueue cancelAllOperations];
    self.internalQueue.suspended = NO;
    [super cancel];
}
- (void)execute {
    self.internalQueue.suspended = NO;
    [self.internalQueue addOperation:self.finishingOperation];
}
- (void)addOperation:(NSOperation *)operation {
    [self.internalQueue addOperation:operation];
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
    // For use by subclassers.
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
    @synchronized(self.aggregatedErrors) {
        [self.aggregatedErrors addObjectsFromArray:errors];
    }

    if (operation == self.finishingOperation) {
        self.internalQueue.suspended = YES;
        [self finishWithErrors:[self.aggregatedErrors copy]];
    } else {
        [self operationDidFinish:operation withErrors:errors];
    }
}

@end
