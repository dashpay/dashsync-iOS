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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class DSOperation;
@class DSOperationQueue;

/**
 The protocol that types may implement if they wish to be notified of significant
 operation lifecycle events.
 */
@protocol DSOperationObserverProtocol <NSObject>

@optional

/**
 Invoked before operation is enqueued in queue
 */
- (void)operationWillStart:(DSOperation *)operation inOperationQueue:(DSOperationQueue *)operationQueue;

/**
 Invoked immediately prior to the `DSOperation`'s `execute()` method.
 */
- (void)operationDidStart:(DSOperation *)operation;

/**
 Invoked when `[DSOperation produceOperation:]` is executed.
 */
- (void)operation:(DSOperation *)operation didProduceOperation:(NSOperation *)newOperation;

/**
 Invoked as an `DSOperation` finishes, along with any errors produced during
 execution (or readiness evaluation).
 */
- (void)operationDidFinish:(DSOperation *)operation errors:(nullable NSArray<NSError *> *)errors;

@end

NS_ASSUME_NONNULL_END
