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

@class DSOperation, DSOperationConditionResult;

/**
 A protocol for defining conditions that must be satisfied in order for an
 operation to begin execution.
 */
@protocol DSOperationConditionProtocol <NSObject>

/**
 Some conditions may have the ability to satisfy the condition if another
 operation is executed first. Use this method to return an operation that
 (for example) asks for permission to perform the operation
 
 - parameter operation: The `Operation` to which the Condition has been added.
 - returns: An `NSOperation`, if a dependency should be automatically added. Otherwise, `nil`.
 - note: Only a single operation may be returned as a dependency. If you
 find that you need to return multiple operations, then you should be
 expressing that as multiple conditions. Alternatively, you could return
 a single `GroupOperation` that executes multiple operations internally.
 */
- (nullable NSOperation *)dependencyForOperation:(DSOperation *)operation;

/**
 Evaluate the condition, to see if it has been satisfied or not.
 */
- (void)evaluateForOperation:(DSOperation *)operation completion:(void (^)(DSOperationConditionResult *result))completion;

@end

NS_ASSUME_NONNULL_END
