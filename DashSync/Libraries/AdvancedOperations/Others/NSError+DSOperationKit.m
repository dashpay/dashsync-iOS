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

#import "NSError+DSOperationKit.h"
#import "DSReachabilityCondition.h"

NSString *const DSOperationErrorDomain = @"DSOperationErrorDomain";

NSString *const DSOperationErrorConditionKey = @"DSOperationErrorConditionKey";

@implementation NSError (DSOperationKit)

+ (instancetype)ds_operationErrorWithCode:(NSUInteger)code {
    return [self ds_operationErrorWithCode:code userInfo:nil];
}

+ (instancetype)ds_operationErrorWithCode:(NSUInteger)code userInfo:(NSDictionary *)info {
    return [NSError errorWithDomain:DSOperationErrorDomain code:code userInfo:info];
}

- (BOOL)ds_isReachabilityConditionError {
    if ([self.domain isEqualToString:DSOperationErrorDomain] &&
        [self.userInfo[DSOperationErrorConditionKey] isEqualToString:NSStringFromClass([DSReachabilityCondition class])]) {
        return YES;
    }
    return NO;
}

@end
