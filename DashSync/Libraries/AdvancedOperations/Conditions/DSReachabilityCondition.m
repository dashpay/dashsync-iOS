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

#import "DSReachabilityCondition.h"
#import "DSOperationConditionResult.h"
#import "DSReachabilityManager.h"
#import "NSError+DSOperationKit.h"

@interface DSReachabilityCondition ()

@property (nonatomic, strong) NSURL *host;

@end

@implementation DSReachabilityCondition

+ (instancetype)reachabilityCondition {
    return [[[self class] alloc] init];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        if (![DSReachabilityManager sharedManager].isMonitoring) {
            [[DSReachabilityManager sharedManager] startMonitoring];
        }
    }
    return self;
}

- (NSString *)name {
    return NSStringFromClass([DSReachabilityCondition class]);
}

- (NSOperation *)dependencyForOperation:(DSOperation *)operation {
    return nil;
}

- (void)evaluateForOperation:(DSOperation *)operation completion:(void (^)(DSOperationConditionResult *))completion {
    if (![DSReachabilityManager sharedManager].isMonitoring) {
        [[DSReachabilityManager sharedManager] startMonitoring];
    }

    DSReachabilityStatus status = [DSReachabilityManager sharedManager].networkReachabilityStatus;

    if (status == DSReachabilityStatusUnknown) {
        [[DSReachabilityManager sharedManager] addSingleCallReachabilityStatusChangeBlock:^(DSReachabilityStatus status) {
            if (status <= DSReachabilityStatusNotReachable) {
                NSError *error = [NSError ds_operationErrorWithCode:DSOperationErrorConditionFailed
                                                           userInfo:@{DSOperationErrorConditionKey : NSStringFromClass([self class])}];
                if (completion) {
                    completion([DSOperationConditionResult failedResultWithError:error]);
                }
            }
            else {
                if (completion) {
                    completion([DSOperationConditionResult satisfiedResult]);
                }
            }
        }];
    }
    else if (status <= DSReachabilityStatusNotReachable) {
        NSError *error = [NSError ds_operationErrorWithCode:DSOperationErrorConditionFailed
                                                   userInfo:@{DSOperationErrorConditionKey : NSStringFromClass([self class])}];
        if (completion) {
            completion([DSOperationConditionResult failedResultWithError:error]);
        }
    }
    else {
        if (completion) {
            completion([DSOperationConditionResult satisfiedResult]);
        }
    }
}

@end
