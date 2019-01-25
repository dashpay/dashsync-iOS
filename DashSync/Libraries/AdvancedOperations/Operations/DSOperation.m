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
#import "DSBlockOperationObserver.h"
#import "DSChainableCondition.h"
#import "DSOperationConditionResult.h"
#import "DSOperationQueue.h"

@interface DSOperation ()

@property (atomic, assign) BOOL hasFinishedAlready;
@property (atomic, assign) DSOperationState state;
@property (getter=isCancelled) BOOL cancelled;

@property (nonatomic, weak) DSOperationQueue *enqueuedOperationQueue;

@property (nonatomic, copy) NSArray<NSObject<DSOperationConditionProtocol> *> *conditions;
@property (nonatomic, copy) NSArray<NSObject<DSOperationObserverProtocol> *> *observers;
@property (nonatomic, copy) NSArray<NSError *> *internalErrors;

@end

@implementation DSOperation

@synthesize cancelled = _cancelled;
@synthesize userInitiated = _userInitiated;
@synthesize state = _state;

// use the KVO mechanism to indicate that changes to "state" affect other properties as well
+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
    if ([@[ @"isReady" ] containsObject:key]) {
        return [NSSet setWithArray:@[ @"state", @"cancelledState" ]];
    }
    if ([@[ @"isExecuting", @"isFinished" ] containsObject:key]) {
        return [NSSet setWithArray:@[ @"state" ]];
    }
    if ([@[ @"isCancelled" ] containsObject:key]) {
        return [NSSet setWithArray:@[ @"cancelledState" ]];
    }

    return [super keyPathsForValuesAffectingValueForKey:key];
}

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key {
    if ([@[ @"state", @"cancelledState" ] containsObject:key]) {
        return NO;
    }

    return YES;
}

- (DSOperationState)state {
    @synchronized(self) {
        return _state;
    }
}

- (void)setState:(DSOperationState)newState {
    // Manually fire the KVO notifications for state change, since this is "private".
    @synchronized(self) {
        if (_state != DSOperationStateFinished) {
            [self willChangeValueForKey:@"state"];
            NSAssert(_state != newState, @"Performing invalid cyclic state transition.");
            _state = newState;
            [self didChangeValueForKey:@"state"];
        }
    }
}

- (BOOL)isCancelled {
    @synchronized(self) {
        return _cancelled;
    }
}

- (void)setCancelled:(BOOL)cancelled {
    @synchronized(self) {
        [self willChangeValueForKey:@"cancelledState"];
        _cancelled = cancelled;
        [self didChangeValueForKey:@"cancelledState"];
    }
}

- (BOOL)isReady {
    BOOL ready = NO;

    @synchronized(self) {
        switch (self.state) {
            case DSOperationStateInitialized:
                ready = [self isCancelled];
                break;

            case DSOperationStatePending:
                if ([self isCancelled]) {
                    [self setState:DSOperationStateReady];
                    ready = YES;
                    break;
                }
                if ([super isReady]) {
                    [self evaluateConditions];
                }
                ready = (self.state == DSOperationStateReady && ([super isReady] || self.isCancelled));
                break;
            case DSOperationStateReady:
                ready = [super isReady] || [self isCancelled];
                break;
            default:
                ready = NO;
                break;
        }
    }

    return ready;
}

- (BOOL)userInitiated {
    if ([self respondsToSelector:@selector(qualityOfService)]) {
        return self.qualityOfService == NSQualityOfServiceUserInitiated;
    }

    return _userInitiated;
}
- (void)setUserInitiated:(BOOL)newValue {
    NSAssert(self.state < DSOperationStateExecuting, @"Cannot modify userInitiated after execution has begun.");
    if ([self respondsToSelector:@selector(setQualityOfService:)]) {
        self.qualityOfService = newValue ? NSQualityOfServiceUserInitiated : NSQualityOfServiceDefault;
    }
    _userInitiated = newValue;
}
- (BOOL)isExecuting {
    return self.state == DSOperationStateExecuting;
}
- (BOOL)isFinished {
    return self.state == DSOperationStateFinished;
}

- (void)evaluateConditions {
    NSAssert(self.state == DSOperationStatePending, @"evaluateConditions() was called out-of-order");

    self.state = DSOperationStateEvaluatingConditions;

    if (!self.conditions.count) {
        self.state = DSOperationStateReady;
        return;
    }

    // If evaluating will take too long and opearation was cancelled and deleted from queue
    // make sure that DSOperationConditionResult will not retain and call on self
    __weak typeof(self) weakSelf = self;
    [DSOperationConditionResult evaluateConditions:self.conditions operation:self completion:^(NSArray *failures) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }

        if (strongSelf.isCancelled) {
            return;
        }

        if (failures.count != 0) {
            [strongSelf cancelWithErrors:failures];
        }
        else if (strongSelf.state < DSOperationStateReady) {
            //We must preceed to have the operation exit the queue
            strongSelf.state = DSOperationStateReady;
        }
    }];
}

- (void)willEnqueueInOperationQueue:(DSOperationQueue *)operationQueue {
    self.enqueuedOperationQueue = operationQueue;

    for (NSObject<DSOperationObserverProtocol> *observer in self.observers) {
        if ([observer respondsToSelector:@selector(operationWillStart:inOperationQueue:)]) {
            [observer operationWillStart:self inOperationQueue:operationQueue];
        }
    }

    self.state = DSOperationStatePending;
}

#pragma mark - Observers

- (NSArray *)observers {
    if (!_observers) {
        _observers = @[];
    }
    return _observers;
}

- (void)addObserver:(NSObject<DSOperationObserverProtocol> *)observer {
    NSAssert(self.state < DSOperationStateExecuting, @"Cannot modify observers after execution has begun.");
    self.observers = [self.observers arrayByAddingObject:observer];
}
#pragma mark - Conditions

- (NSArray *)conditions {
    if (!_conditions) {
        _conditions = @[];
    }
    return _conditions;
}

- (void)addCondition:(NSObject<DSOperationConditionProtocol> *)condition {
    NSAssert(self.state < DSOperationStateEvaluatingConditions, @"Cannot modify conditions after execution has begun.");
    self.conditions = [self.conditions arrayByAddingObject:condition];
}

- (void)addDependency:(NSOperation *)op {
    NSAssert(self.state <= DSOperationStateExecuting, @"Dependencies cannot be modified after execution has begun.");
    [super addDependency:op];
}

#pragma mark - Execution and Cancellation

- (void)start {
    NSAssert(self.state == DSOperationStateReady, @"This operation must be performed on an operation queue.");

    if (self.isCancelled) {
        [self finish];
        return;
    }
    self.state = DSOperationStateExecuting;

    for (NSObject<DSOperationObserverProtocol> *observer in self.observers) {
        if ([observer respondsToSelector:@selector(operationDidStart:)]) {
            [observer operationDidStart:self];
        }
    }

    [self execute];
}

/**
 `execute` is the entry point of execution for all `DSOperation` subclasses.
 If you subclass `DSOperation` and wish to customize its execution, you would
 do so by overriding the `execute` method.
 
 At some point, your `DSOperation` subclass must call one of the "finish"
 methods defined below; this is how you indicate that your operation has
 finished its execution, and that operations dependent on yours can re-evaluate
 their readiness state.
 */
- (void)execute {
    DSDLog(@"%@ must override `execute`.", NSStringFromClass(self.class));
    [self finish];
}

- (void)cancel {
    if (self.isFinished) {
        return;
    }

    self.cancelled = YES;
    if (self.state > DSOperationStateReady) {
        [self finish];
    }
    else if (self.state < DSOperationStateReady) {
        self.state = DSOperationStateReady;
    }
}

- (void)cancelWithErrors:(NSArray<NSError *> *)errors {
    self.internalErrors = [self.internalErrors arrayByAddingObjectsFromArray:errors];
    [self cancel];
}

- (void)cancelWithError:(NSError *)error {
    if (error) {
        self.internalErrors = [self.internalErrors arrayByAddingObject:error];
    }
    [self cancel];
}

- (void)produceOperation:(NSOperation *)operation {
    for (NSObject<DSOperationObserverProtocol> *observer in self.observers) {
        if ([observer respondsToSelector:@selector(operation:didProduceOperation:)]) {
            [observer operation:self didProduceOperation:operation];
        }
    }
}

#pragma mark - Finishing

- (NSArray *)internalErrors {
    if (!_internalErrors) {
        _internalErrors = @[];
    }
    return _internalErrors;
}

/**
 Most operations may finish with a single error, if they have one at all.
 This is a convenience method to simplify calling the actual `finish`
 method. This is also useful if you wish to finish with an error provided
 by the system frameworks.
 */
- (void)finish {
    [self finishWithErrors:nil];
}

- (void)finishWithErrors:(NSArray<NSError *> *)errors {
    if (!self.hasFinishedAlready) {
        self.hasFinishedAlready = YES;
        self.state = DSOperationStateFinishing;

        _internalErrors = [self.internalErrors arrayByAddingObjectsFromArray:errors];
        [self finishedWithErrors:self.internalErrors];

        for (NSObject<DSOperationObserverProtocol> *observer in self.observers) {
            if ([observer respondsToSelector:@selector(operationDidFinish:errors:)]) {
                [observer operationDidFinish:self errors:self.internalErrors];
            }
        }

        self.state = DSOperationStateFinished;
    }
}

- (void)finishWithError:(NSError *)error {
    if (error) {
        [self finishWithErrors:@[ error ]];
    }
    else {
        [self finish];
    }
}
/**
 Subclasses may override `finishedWithErrors:` if they wish to react to the operation
 finishing with errors.
 */
- (void)finishedWithErrors:(NSArray<NSError *> *)errors {
    // NOP
}

- (void)waitUntilFinished {
    /*
     Waiting on operations is almost NEVER the right thing to do. It is
     usually superior to use proper locking constructs, such as `dispatch_semaphore_t`
     or `dispatch_group_notify`, or even `NSLock` objects. Many developers
     use waiting when they should instead be chaining discrete operations
     together using dependencies.
     
     To reinforce this idea, invoking `waitUntilFinished` will crash your
     app, as incentive for you to find a more appropriate way to express
     the behavior you're wishing to create.
     */
    NSAssert(NO, @"Waiting on operations is an anti-pattern. Remove this ONLY if you're absolutely sure there is No Other Way™.");
}

@end
