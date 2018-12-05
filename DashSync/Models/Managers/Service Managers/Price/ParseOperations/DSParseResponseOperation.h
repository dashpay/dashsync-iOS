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

#import "DSOperation.h"
#import "DSChainableOperationProtocol.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const DSParseResponseOperationErrorDomain;

typedef NS_ENUM(NSUInteger, DSParseResponseOperationErrorCode) {
    DSParseResponseOperationErrorCodeInvalidResponse = 1,
};

/**
 Abstract chainable operation, follows `DSHTTPGETOperation`
 */
@interface DSParseResponseOperation : DSOperation <DSChainableOperationProtocol>

@property (readonly, strong, nonatomic, nullable) id responseToParse;

+ (NSError *)invalidResponseErrorWithUserInfo:(nullable NSDictionary<NSErrorUserInfoKey, id> *)userInfo;

@end

NS_ASSUME_NONNULL_END
