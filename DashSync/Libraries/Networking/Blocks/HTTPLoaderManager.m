//
//  Created by Andrew Podkovyrin
//  Copyright © 2018-2019 Dash Core Group. All rights reserved.
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

#import "HTTPLoaderManager.h"

#import "DSAuthenticationManager+Private.h"
#import "HTTPLoaderFactory.h"
#import "HTTPLoaderOperation.h"
#import "HTTPRequest.h"
#import "HTTPResponse.h"

NS_ASSUME_NONNULL_BEGIN

@interface HTTPLoaderManager ()

@property (strong, nonatomic) HTTPLoaderFactory *factory;

@end

@implementation HTTPLoaderManager

- (instancetype)initWithFactory:(HTTPLoaderFactory *)factory {
    self = [super init];
    if (self) {
        _factory = factory;
    }

    return self;
}

- (id<HTTPLoaderOperationProtocol>)sendRequest:(HTTPRequest *)httpRequest completion:(HTTPLoaderCompletionBlock)completion {
    return [self sendRequest:httpRequest factory:self.factory completion:completion];
}

- (id<HTTPLoaderOperationProtocol>)sendRequest:(HTTPRequest *)httpRequest rawCompletion:(HTTPLoaderRawCompletionBlock)rawCompletion {
    return [self sendRequest:httpRequest factory:self.factory rawCompletion:rawCompletion];
}

- (id<HTTPLoaderOperationProtocol>)sendRequest:(HTTPRequest *)httpRequest
                                       factory:(HTTPLoaderFactory *)factory
                                    completion:(HTTPLoaderCompletionBlock)completion {
    return [self sendRequest:httpRequest factory:factory rawCompletion:^(BOOL success, BOOL cancelled, HTTPResponse *_Nullable response) {
        NSAssert([NSThread isMainThread], nil);

        if (success) {
            NSError *_Nullable error = nil;
            id _Nullable parsedData = [self parseResponse:response.body statusCode:response.statusCode request:httpRequest error:&error];
            NSAssert((!error && parsedData) || (error && !parsedData), nil); // sanity check
            
            if ([DSLogger sharedInstance].shouldLogHTTPResponses) {
                DSLogInfo(@">> Response OK: %@, error: %@", parsedData, error);
            }

            // store server timestamp
            [[DSAuthenticationManager sharedInstance] updateSecureTimeFromResponseIfNeeded:response.responseHeaders];

            if (completion) {
                completion(parsedData, response.responseHeaders, response.statusCode, error ?: response.error);
            }
        }
        else {
            NSError *error = nil;
            if (cancelled) {
                error = [NSError errorWithDomain:NSURLErrorDomain
                                            code:NSURLErrorCancelled
                                        userInfo:nil];
            }
            else {
                error = response.error;
            }
            
            if ([DSLogger sharedInstance].shouldLogHTTPResponses) {
                id parsedData = response.body ?
                    [NSJSONSerialization JSONObjectWithData:response.body
                                                    options:httpRequest.jsonReadingOptions
                                                      error:nil]
                    : nil;
                
                DSLogInfo(@">> Response Failed: %@, error: %@", parsedData, error);
            }
            
            if (completion) {
                if (cancelled) {
                    completion(nil, nil, HTTPResponseStatusCode_Invalid, error);
                }
                else {
                    completion(nil, response.responseHeaders, response.statusCode, error);
                }
            }
        }

    }];
}

- (id<HTTPLoaderOperationProtocol>)sendRequest:(HTTPRequest *)httpRequest
                                       factory:(HTTPLoaderFactory *)factory
                                 rawCompletion:(HTTPLoaderRawCompletionBlock)rawCompletion {
    HTTPLoaderOperation *operation = [[HTTPLoaderOperation alloc] initWithHTTPRequest:httpRequest httpLoaderFactory:factory];
    [operation performWithCompletion:rawCompletion];
    return operation;
}

#pragma mark Private

- (nullable id)parseResponse:(nullable NSData *)data statusCode:(NSInteger)statusCode request:(HTTPRequest *)request error:(NSError *__autoreleasing *)error {
    NSError *statusCodeError = nil;
    if (statusCode < 200 || statusCode > 300) {
        NSDictionary *userInfo = @{NSLocalizedDescriptionKey : [NSHTTPURLResponse localizedStringForStatusCode:statusCode]};
        statusCodeError = [NSError errorWithDomain:HTTPResponseErrorDomain
                                              code:statusCode
                                          userInfo:userInfo];
    }

    if (!data) {
        if (error) {
            *error = statusCodeError;
        }

        return nil;
    }

    NSError *parseError = nil;
    id parsed = [NSJSONSerialization JSONObjectWithData:data
                                                options:request.jsonReadingOptions
                                                  error:&parseError];
    if (parseError) {
        if (error) {
            *error = parseError;
        }

        return nil;
    }

    return parsed;
}

@end

NS_ASSUME_NONNULL_END
