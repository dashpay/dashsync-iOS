//
//  Created by Andrew Podkovyrin
//  Copyright © 2018 Dash Core Group. All rights reserved.
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

#import "DSParseResponseOperation.h"

#import "DSHTTPGETOperation.h"

NS_ASSUME_NONNULL_BEGIN

NSString *const DSParseResponseOperationErrorDomain = @"DSParseResponseOperationError";

@interface DSParseResponseOperation ()

@property (strong, nonatomic, nullable) id responseToParse;

@end

@implementation DSParseResponseOperation

+ (NSError *)invalidResponseErrorWithUserInfo:(nullable NSDictionary<NSErrorUserInfoKey, id> *)userInfo {
    NSError *error = [NSError errorWithDomain:DSParseResponseOperationErrorDomain
                                         code:DSParseResponseOperationErrorCodeInvalidResponse
                                     userInfo:userInfo];
    return error;
}

#pragma mark DSChainableOperationProtocol

- (void)chainedOperation:(NSOperation *)operation didFinishWithErrors:(nullable NSArray<NSError *> *)errors passingAdditionalData:(nullable id)data {
    if ([operation isKindOfClass:DSHTTPGETOperation.class]) {
        self.responseToParse = data;
    }
}

@end

NS_ASSUME_NONNULL_END
