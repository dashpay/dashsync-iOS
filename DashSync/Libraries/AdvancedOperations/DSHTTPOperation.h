//
//  Created by Andrew Podkovyrin
//  Copyright © 2019-2019 Dash Core Group. All rights reserved.
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

#import "HTTPRequest.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const DSHTTPOperationErrorDomain;

typedef NS_ENUM(NSUInteger, DSHTTPOperationErrorCode) {
    DSHTTPOperationErrorCodeInvalidResponse = 1,
};

@interface DSHTTPOperation : DSOperation

- (instancetype)initWithRequest:(HTTPRequest *)request;
- (instancetype)init NS_UNAVAILABLE;

- (void)processSuccessResponse:(id)parsedData responseHeaders:(NSDictionary *)responseHeaders statusCode:(NSInteger)statusCode;
- (void)cancelWithInvalidResponse:(id)responseData;

@end

NS_ASSUME_NONNULL_END
