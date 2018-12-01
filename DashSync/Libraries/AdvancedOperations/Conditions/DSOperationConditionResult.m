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

#import "DSOperationConditionResult.h"
#import "DSOperation.h"
#import "DSOperationConditionProtocol.h"
#import "NSError+DSOperationKit.h"

@interface DSOperationConditionResult ()

@property (nonatomic, assign, getter=isSuccees) BOOL success;
@property (nonatomic, strong) NSError *error;

@end

@implementation DSOperationConditionResult

- (NSError *)error {
    if (!self.success) {
        return _error;
    }
    else {
        return nil;
    }
}

+ (DSOperationConditionResult *)satisfiedResult {
    return [self resultWithSuccess:YES error:nil];
}

+ (DSOperationConditionResult *)failedResultWithError:(NSError *)error {
    return [self resultWithSuccess:NO error:error];
}

+ (DSOperationConditionResult *)resultWithSuccess:(BOOL)success error:(NSError *)error {
    DSOperationConditionResult *newResult = [[DSOperationConditionResult alloc] init];
    newResult.success = success;
    newResult.error = error;

    return newResult;
}

+ (void)evaluateConditions:(NSArray *)conditions operation:(DSOperation *)operation completion:(void (^)(NSArray<NSError *> *errors))completion {
    // Check conditions.
    dispatch_group_t conditionGroup = dispatch_group_create();

    //array of OperationConditionResult
    NSMutableArray *results = [NSMutableArray arrayWithCapacity:conditions.count];

    // Ask each condition to evaluate and store its result in the "results" array.
    [conditions enumerateObjectsUsingBlock:^(NSObject<DSOperationConditionProtocol> *condition, NSUInteger idx, BOOL *stop) {

        dispatch_group_enter(conditionGroup);
        [condition evaluateForOperation:operation completion:^(DSOperationConditionResult *result) {
            [results addObject:result];

            dispatch_group_leave(conditionGroup);
        }];
    }];

    // After all the conditions have evaluated, this block will execute.
    dispatch_group_notify(conditionGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // Aggregate the errors that occurred, in order.
        NSArray *failures = [[results filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"error != nil"]] valueForKeyPath:@"error"];

        /*
         If any of the conditions caused this operation to be cancelled,
         check for that.
         */
        if (operation.isCancelled) {
            failures = [failures arrayByAddingObject:[NSError ds_operationErrorWithCode:DSOperationErrorConditionFailed]];
        }
        if (completion) {
            completion(failures);
        }
    });
}

@end
