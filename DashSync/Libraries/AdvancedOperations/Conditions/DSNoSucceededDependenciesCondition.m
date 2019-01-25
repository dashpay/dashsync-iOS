//
//  Created by Andrew Podkovyrin
//  Copyright © 2019 Dash Core Group. All rights reserved.
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

#import "DSNoSucceededDependenciesCondition.h"

#import "DSOperation.h"
#import "DSOperationConditionResult.h"
#import "NSError+DSOperationKit.h"

NS_ASSUME_NONNULL_BEGIN

@implementation DSNoSucceededDependenciesCondition

- (nullable NSOperation *)dependencyForOperation:(DSOperation *)operation {
    return nil;
}

- (void)evaluateForOperation:(DSOperation *)operation completion:(void (^)(DSOperationConditionResult *result))completion {
    __block BOOL anyDependencySucceeded = NO;
    [operation.dependencies enumerateObjectsUsingBlock:^(NSOperation *obj, NSUInteger idx, BOOL *stop) {
        if ([obj isKindOfClass:DSOperation.class]) {
            DSOperation *dsOperation = (DSOperation *)obj;
            if (dsOperation.internalErrors.firstObject == nil) {
                anyDependencySucceeded = YES;
                *stop = YES;
            }
        }
    }];

    if (anyDependencySucceeded) {
        NSError *error = [NSError ds_operationErrorWithCode:DSOperationErrorConditionFailed userInfo:nil];
        completion([DSOperationConditionResult failedResultWithError:error]);
    }
    else {
        completion([DSOperationConditionResult satisfiedResult]);
    }
}

@end

NS_ASSUME_NONNULL_END
