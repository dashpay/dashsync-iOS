//
// Created by wiistriker@gmail.com
// Copyright (c) 2013 JustCommunication
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
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

#import "DSHTTPJSONRPCClient.h"

#import <objc/runtime.h>

#import "HTTPLoaderManager.h"
#import "HTTPRequest.h"

NS_ASSUME_NONNULL_BEGIN

NSString *const DSJSONRPCClientErrorDomain = @"dash.networking.json-rpc";

static NSString *DSJSONRPCLocalizedErrorMessageForCode(NSInteger code) {
    switch (code) {
        case -32700:
            return DSLocalizedString(@"Parse Error", nil);
        case -32600:
            return DSLocalizedString(@"Invalid Request", nil);
        case -32601:
            return DSLocalizedString(@"Method Not Found", nil);
        case -32602:
            return DSLocalizedString(@"Invalid Params", nil);
        case -32603:
            return DSLocalizedString(@"Internal Error", nil);
        default:
            return DSLocalizedString(@"Server Error", nil);
    }
}

#pragma mark - Proxy Declaration

@interface DSJSONRPCProxy : NSProxy

- (instancetype)initWithClient:(DSHTTPJSONRPCClient *)client protocol:(Protocol *)protocol;

@end

#pragma mark - Client

@interface DSHTTPJSONRPCClient ()

@property (strong, nonatomic) NSURL *endpointURL;
@property (strong, nonatomic) HTTPLoaderManager *httpManager;

@end

@implementation DSHTTPJSONRPCClient

+ (instancetype)clientWithEndpointURL:(NSURL *)URL
                    httpLoaderFactory:(HTTPLoaderFactory *)httpLoaderFactory {
    return [[self alloc] initWithEndpointURL:URL httpLoaderFactory:httpLoaderFactory];
}

- (instancetype)initWithEndpointURL:(NSURL *)URL
                  httpLoaderFactory:(HTTPLoaderFactory *)httpLoaderFactory {
    NSParameterAssert(URL);
    NSParameterAssert(httpLoaderFactory);

    self = [super init];
    if (self) {
        _endpointURL = URL;
        _httpManager = [[HTTPLoaderManager alloc] initWithFactory:httpLoaderFactory];
    }
    return self;
}

- (void)invokeMethod:(NSString *)method
             success:(void (^)(id responseObject))success
             failure:(void (^)(NSError *error))failure {
    [self invokeMethod:method withParameters:@[] success:success failure:failure];
}

- (void)invokeMethod:(NSString *)method
      withParameters:(id)parameters
             success:(void (^)(id responseObject))success
             failure:(void (^)(NSError *error))failure {
    [self invokeMethod:method withParameters:parameters requestId:@(1) success:success failure:failure];
}

- (void)invokeMethod:(NSString *)method
      withParameters:(id)parameters
           requestId:(id)requestId
             success:(void (^)(id responseObject))success
             failure:(void (^)(NSError *error))failure {
    NSParameterAssert(method);

    if (!parameters) {
        parameters = @[];
    }

    NSAssert([parameters isKindOfClass:NSDictionary.class] || [parameters isKindOfClass:NSArray.class],
             @"Expect NSArray or NSDictionary in JSONRPC parameters");

    if (!requestId) {
        requestId = @(1);
    }

    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[@"jsonrpc"] = @"2.0";
    payload[@"method"] = method;
    payload[@"params"] = parameters;
    payload[@"id"] = [requestId description];

    HTTPRequest *request = [[HTTPRequest alloc] initWithURL:self.endpointURL
                                                     method:HTTPRequestMethod_POST
                                                contentType:HTTPContentType_JSON
                                                 parameters:payload
                                                       body:nil
                                           sourceIdentifier:nil];
    [request addValue:@"application/json" forHeader:@"Accept"];
    [self.httpManager sendRequest:request completion:^(id _Nullable responseObject, NSDictionary *_Nullable responseHeaders, NSInteger statusCode, NSError *_Nullable httpError) {

        if (httpError) {
            if (failure) {
                failure(httpError);
            }

            return;
        }

        NSInteger code = 0;
        NSString *message = nil;
        id data = nil;

        if ([responseObject isKindOfClass:NSDictionary.class]) {
            id result = responseObject[@"result"];
            id error = responseObject[@"error"];

            if (result && result != NSNull.null) {
                if (success) {
                    success(result);

                    return;
                }
            }
            else if (error && error != NSNull.null) {
                if ([error isKindOfClass:NSDictionary.class]) {
                    if (error[@"code"]) {
                        code = [error[@"code"] integerValue];
                    }

                    if (error[@"message"]) {
                        message = error[@"message"];
                    }
                    else if (code) {
                        message = DSJSONRPCLocalizedErrorMessageForCode(code);
                    }

                    data = error[@"data"];
                }
                else {
                    message = DSLocalizedString(@"Unknown Error", nil);
                }
            }
            else {
                message = DSLocalizedString(@"Unknown JSON-RPC Response", nil);
            }
        }
        else {
            message = DSLocalizedString(@"Unknown JSON-RPC Response", nil);
        }

        if (failure) {
            NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
            if (message) {
                userInfo[NSLocalizedDescriptionKey] = message;
            }

            if (data) {
                userInfo[@"data"] = data;
            }

            NSError *error = [NSError errorWithDomain:DSJSONRPCClientErrorDomain code:code userInfo:userInfo];

            failure(error);
        }
    }];
}

- (id)proxyWithProtocol:(Protocol *)protocol {
    return [[DSJSONRPCProxy alloc] initWithClient:self protocol:protocol];
}

@end

#pragma mark - Proxy Implementation

typedef void (^DSJSONRPCProxySuccessBlock)(id responseObject);
typedef void (^DSJSONRPCProxyFailureBlock)(NSError *error);

@interface DSJSONRPCProxy ()

@property (readwrite, nonatomic, strong) DSHTTPJSONRPCClient *client;
@property (readwrite, nonatomic, strong) Protocol *protocol;

@end

@implementation DSJSONRPCProxy

- (instancetype)initWithClient:(DSHTTPJSONRPCClient *)client protocol:(Protocol *)protocol {
    self.client = client;
    self.protocol = protocol;

    return self;
}

- (BOOL)respondsToSelector:(SEL)selector {
    struct objc_method_description description = protocol_getMethodDescription(self.protocol, selector, YES, YES);

    return description.name != NULL;
}

- (nullable NSMethodSignature *)methodSignatureForSelector:(__unused SEL)selector {
    // 0: v->RET || 1: @->self || 2: :->SEL || 3: @->arg#0 (NSArray) || 4,5: ^v->arg#1,2 (block)
    NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:"v@:@^v^v"];

    return signature;
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    NSParameterAssert(invocation.methodSignature.numberOfArguments == 5);

    NSString *RPCMethod = [NSStringFromSelector([invocation selector]) componentsSeparatedByString:@":"][0];

    __unsafe_unretained id arguments;
    __unsafe_unretained DSJSONRPCProxySuccessBlock unsafeSuccess;
    __unsafe_unretained DSJSONRPCProxyFailureBlock unsafeFailure;

    [invocation getArgument:&arguments atIndex:2];
    [invocation getArgument:&unsafeSuccess atIndex:3];
    [invocation getArgument:&unsafeFailure atIndex:4];

    invocation.target = nil;

    __strong DSJSONRPCProxySuccessBlock strongSuccess = [unsafeSuccess copy];
    __strong DSJSONRPCProxyFailureBlock strongFailure = [unsafeFailure copy];

    [self.client invokeMethod:RPCMethod withParameters:arguments success:strongSuccess failure:strongFailure];
}

@end

NS_ASSUME_NONNULL_END
