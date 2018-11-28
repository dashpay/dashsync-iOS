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

#import "DSTimeoutObserver.h"
#import "DSOperation.h"
#import "NSError+DSOperationKit.h"

@interface DSTimeoutObserver ()

@property (nonatomic, assign) NSTimeInterval timeout;

@end

@implementation DSTimeoutObserver

- (instancetype)initWithTimeout:(NSTimeInterval)interval {
    self = [super init];
    if (self) {
        self.timeout = interval;
    }
    return self;
}

- (void)operationDidStart:(DSOperation *)operation {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.timeout * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (![operation isCancelled] && ![operation isFinished]) {
            NSError *error = [NSError ds_operationErrorWithCode:DSOperationErrorExecutionFailed
                                                       userInfo:@{ @"timeout" : @(self.timeout) }];
            [operation cancelWithError:error];
        }
    });
}

- (void)operationWillStart:(DSOperation *)operation inOperationQueue:(DSOperationQueue *)operationQueue {
}

- (void)operation:(DSOperation *)operation didProduceOperation:(NSOperation *)newOperation {
    // NOP
}

- (void)operationDidFinish:(DSOperation *)operation errors:(NSArray *)errors {
    // NOP
}

@end
