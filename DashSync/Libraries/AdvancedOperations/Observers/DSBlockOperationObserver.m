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

#import "DSBlockOperationObserver.h"

@interface DSBlockOperationObserver ()

@property (nonatomic, copy) DSBlockOperationObserverWillStartHandler willStartHandler;
@property (nonatomic, copy) DSBlockOperationObserverStartHandler startHandler;
@property (nonatomic, copy) DSBlockOperationObserverProduceHandler produceHandler;
@property (nonatomic, copy) DSBlockOperationObserverFinishHandler finishHandler;

@end

@implementation DSBlockOperationObserver

- (instancetype)initWithWillStartHandler:(DSBlockOperationObserverWillStartHandler)willStartHandler
                         didStartHandler:(DSBlockOperationObserverStartHandler)startHandler
                          produceHandler:(DSBlockOperationObserverProduceHandler)produceHandler
                           finishHandler:(DSBlockOperationObserverFinishHandler)finishHandler {
    self = [super init];
    if (self) {
        self.willStartHandler = willStartHandler;
        self.startHandler = startHandler;
        self.produceHandler = produceHandler;
        self.finishHandler = finishHandler;
    }
    return self;
}

#pragma mark - DSOperationObserver

- (void)operationWillStart:(DSOperation *)operation inOperationQueue:(DSOperationQueue *)operationQueue {
    if (self.willStartHandler) {
        self.willStartHandler(operation, operationQueue);
    }
}

- (void)operationDidStart:(DSOperation *)operation {
    if (self.startHandler) {
        self.startHandler(operation);
    }
}

- (void)operation:(DSOperation *)operation didProduceOperation:(NSOperation *)newOperation {
    if (self.produceHandler) {
        self.produceHandler(operation, newOperation);
    }
}

- (void)operationDidFinish:(DSOperation *)operation errors:(NSArray<NSError *> *)errors {
    if (self.finishHandler) {
        self.finishHandler(operation, errors);
    }
}

@end
