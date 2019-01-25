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

NS_ASSUME_NONNULL_BEGIN

@class DSOperation, DSOperationQueue;

/**
 The delegate of an `DSOperationQueue` can respond to `DSOperation` lifecycle
 events by implementing these methods.
 
 In general, implementing `DSOperationQueueDelegate` is not necessary; you would
 want to use an `DSOperationObserver` instead. However, there are a couple of
 situations where using `DSOperationQueueDelegate` can lead to simpler code.
 For example, `DSGroupOperation` is the delegate of its own internal
 `DSOperationQueue` and uses it to manage dependencies.
 */
@protocol DSOperationQueueDelegate <NSObject>

@optional
- (void)operationQueue:(DSOperationQueue *)operationQueue willAddOperation:(NSOperation *)operation;
- (void)operationQueue:(DSOperationQueue *)operationQueue operationDidFinish:(NSOperation *)operation withErrors:(nullable NSArray *)errors;

@end

/**
 `DSOperationQueue` is an `NSOperationQueue` subclass that implements a large
 number of "extra features" related to the `DSOperation` class:
 
 - Notifying a delegate of all operation completion
 - Extracting generated dependencies from operation conditions
 - Setting up dependencies to enforce mutual exclusivity
 */
@interface DSOperationQueue : NSOperationQueue

@property (nonatomic, weak, nullable) id<DSOperationQueueDelegate> delegate;

@end

NS_ASSUME_NONNULL_END
