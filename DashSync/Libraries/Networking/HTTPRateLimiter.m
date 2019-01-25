//
//  Created by Andrew Podkovyrin
//  Copyright © 2019-2019 Dash Core Group. All rights reserved.
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

#import "HTTPRateLimiter.h"

NS_ASSUME_NONNULL_BEGIN

@interface HTTPRateLimiter ()

@property (strong, nonatomic) NSMutableArray<NSNumber *> *executionTimes;

@end

@implementation HTTPRateLimiter

- (instancetype)initWithWindow:(NSTimeInterval)window
                    delayAfter:(NSUInteger)delayAfter
                         delay:(NSTimeInterval)delay
                       maximum:(NSUInteger)maximum {
    self = [super init];
    if (self) {
        _window = window;
        _delayAfter = delayAfter;
        _delay = delay;
        _maximum = maximum;
        _executionTimes = [NSMutableArray array];
    }

    return self;
}

- (NSTimeInterval)earliestTimeUntilRequestCanBeExecuted {
    [self cleanupExecutionTimes];

    NSArray<NSNumber *> *executionTimes = nil;
    @synchronized(self.executionTimes) {
        executionTimes = [self.executionTimes copy];
    }

    if (executionTimes.count < self.delayAfter) {
        return 0.0;
    }

    if (executionTimes.count >= self.maximum) {
        return self.window;
    }

    CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
    CFAbsoluteTime lastExecution = executionTimes.lastObject.doubleValue;
    CFAbsoluteTime deltaTime = currentTime - lastExecution;

    NSTimeInterval timeInterval = self.delay - deltaTime;
    if (timeInterval < 0.0) {
        timeInterval = 0.0;
    }

    return timeInterval;
}

- (void)executedRequest {
    @synchronized(self.executionTimes) {
        [self.executionTimes addObject:@(CFAbsoluteTimeGetCurrent())];
    }
}

#pragma mark Private

- (void)cleanupExecutionTimes {
    @synchronized(self.executionTimes) {
        CFTimeInterval currentTime = CFAbsoluteTimeGetCurrent();
        NSIndexSet *indexesToRemove = [self.executionTimes indexesOfObjectsPassingTest:^BOOL(NSNumber *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
            CFTimeInterval ti = obj.doubleValue;
            CFTimeInterval passed = ti + currentTime;
            return (passed > self.window);
        }];

        [self.executionTimes removeObjectsAtIndexes:indexesToRemove];
    }
}

@end

NS_ASSUME_NONNULL_END
