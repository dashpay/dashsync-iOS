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

#import "DSHTTPOperationResult.h"

NS_ASSUME_NONNULL_BEGIN

@implementation DSHTTPOperationResult

+ (instancetype)resultWithStatusCode:(NSInteger)statusCode
                     responseHeaders:(NSDictionary *)responseHeaders
                      parsedResponse:(id)parsedResponse {
    return [[self alloc] initWithStatusCode:statusCode
                            responseHeaders:responseHeaders
                             parsedResponse:parsedResponse
                                      error:nil];
}

+ (instancetype)resultWithStatusCode:(NSInteger)statusCode
                     responseHeaders:(NSDictionary *)responseHeaders
                               error:(NSError *)error {
    return [[self alloc] initWithStatusCode:statusCode
                            responseHeaders:responseHeaders
                             parsedResponse:nil
                                      error:error];
}

- (instancetype)initWithStatusCode:(NSInteger)statusCode
                   responseHeaders:(NSDictionary *)responseHeaders
                    parsedResponse:(nullable id)parsedResponse
                             error:(nullable NSError *)error {
    self = [super init];
    if (self) {
        _statusCode = statusCode;
        _responseHeaders = [responseHeaders copy];
        _parsedResponse = parsedResponse;
        _error = error;
    }
    return self;
}

@end

NS_ASSUME_NONNULL_END
