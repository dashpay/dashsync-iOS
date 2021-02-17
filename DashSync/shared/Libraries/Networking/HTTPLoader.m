//
//  Created by Andrew Podkovyrin
//
//  Copyright (c) 2015-2018 Spotify AB.
//
//  Licensed to the Apache Software Foundation (ASF) under one
//  or more contributor license agreements.  See the NOTICE file
//  distributed with this work for additional information
//  regarding copyright ownership.  The ASF licenses this file
//  to you under the Apache License, Version 2.0 (the
//  "License"); you may not use this file except in compliance
//  with the License.  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing,
//  software distributed under the License is distributed on an
//  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
//  KIND, either express or implied.  See the License for the
//  specific language governing permissions and limitations
//  under the License.
//
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

#import "HTTPLoader+Private.h"

#import "HTTPCancellationTokenImpl.h"
#import "HTTPLoaderDelegate.h"
#import "HTTPRequest+Private.h"
#import "HTTPRequest.h"
#import "HTTPRequestOperationHandler.h"
#import "HTTPResponse+Private.h"
#import "HTTPResponse.h"

NS_ASSUME_NONNULL_BEGIN

@interface HTTPLoader () <HTTPCancellationTokenDelegate>

@property (readonly, strong, nonatomic) NSMutableArray<id<HTTPCancellationToken>> *cancellationTokens;
@property (readonly, strong, nonatomic) NSMutableArray<HTTPRequest *> *requests;

@end

@implementation HTTPLoader

- (instancetype)initWithRequestOperationHandlerDelegate:(id<HTTPRequestOperationHandlerDelegate>)requestOperationHandlerDelegate {
    self = [super init];
    if (self) {
        _requestOperationHandlerDelegate = requestOperationHandlerDelegate;

        _cancellationTokens = [[NSMutableArray alloc] init];
        _delegateQueue = dispatch_get_main_queue();
        _requests = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc {
    [self cancelAllLoads];
}

#pragma mark HTTPLoader

- (nullable id<HTTPCancellationToken>)performRequest:(HTTPRequest *)request {
    HTTPRequest *copiedRequest = [request copy];
    id<HTTPLoaderDelegate> delegate = self.delegate;

    // Cancel the request immediately if it requires chunks and the delegate does not support that
    BOOL chunksSupported = [delegate respondsToSelector:@selector(httpLoaderShouldSupportChunks:)];
    if (chunksSupported) {
        chunksSupported = [delegate httpLoaderShouldSupportChunks:self];
    }
    if (!chunksSupported && copiedRequest.chunks) {
        NSError *error = [NSError errorWithDomain:HTTPRequestErrorDomain
                                             code:HTTPRequestErrorCode_ChunkedRequestWithoutChunkedDelegate
                                         userInfo:nil];
        HTTPResponse *response = [[HTTPResponse alloc] initWithRequest:request response:nil];
        response.error = error;
        [delegate httpLoader:self didReceiveErrorResponse:response];
        return nil;
    }

    id<HTTPCancellationToken> cancellationToken = [[HTTPCancellationTokenImpl alloc] initWithDelegate:self cancelObject:copiedRequest];
    copiedRequest.cancellationToken = cancellationToken;
    @synchronized(self.cancellationTokens) {
        [self.cancellationTokens addObject:cancellationToken];
    }

    @synchronized(self.requests) {
        [self.requests addObject:copiedRequest];
    }

    [self.requestOperationHandlerDelegate requestOperationHandler:self performRequest:copiedRequest];

    return cancellationToken;
}

- (void)cancelAllLoads {
    NSArray *cancellationTokens = nil;
    @synchronized(self.cancellationTokens) {
        cancellationTokens = [self.cancellationTokens copy];
        [self.cancellationTokens removeAllObjects];
    }
    [cancellationTokens makeObjectsPerformSelector:@selector(cancel)];
}

- (BOOL)isRequestExpected:(HTTPRequest *)request {
    @synchronized(self.requests) {
        for (HTTPRequest *expectedRequest in self.requests) {
            if (request.uniqueIdentifier == expectedRequest.uniqueIdentifier) {
                return YES;
            }
        }
    }
    return NO;
}

- (NSArray<HTTPRequest *> *)currentRequests {
    return [self.requests copy];
}

#pragma mark HTTPRequestOperationHandler

@synthesize requestOperationHandlerDelegate = _requestOperationHandlerDelegate;

- (void)successfulResponse:(HTTPResponse *)response {
    if (![self isRequestExpected:response.request]) {
        return;
    }

    [self executeDelegateBlock:^{
        [self.delegate httpLoader:self didReceiveSuccessfulResponse:response];
    }];
    @synchronized(self.requests) {
        [self.requests removeObject:response.request];
    }
}

- (void)failedResponse:(HTTPResponse *)response {
    if (![self isRequestExpected:response.request]) {
        return;
    }

    [self executeDelegateBlock:^{
        [self.delegate httpLoader:self didReceiveErrorResponse:response];
    }];
    @synchronized(self.requests) {
        [self.requests removeObject:response.request];
    }
}

- (void)cancelledRequest:(HTTPRequest *)request {
    if (![self isRequestExpected:request]) {
        return;
    }

    if ([self.delegate respondsToSelector:@selector(httpLoader:didCancelRequest:)]) {
        [self executeDelegateBlock:^{
            [self.delegate httpLoader:self didCancelRequest:request];
        }];
    }
    @synchronized(self.requests) {
        [self.requests removeObject:request];
    }
}

- (void)receivedDataChunk:(NSData *)data forResponse:(HTTPResponse *)response {
    if (![self isRequestExpected:response.request]) {
        return;
    }

    // Do not send a callback if the request doesn't support it
    NSAssert(response.request.chunks, @"The loader is receiving a data chunk for a response that doesn't support data chunks");

    BOOL didReceiveDataChunkSelectorExists = [self.delegate respondsToSelector:@selector(httpLoader:didReceiveDataChunk:forResponse:)];
    if (didReceiveDataChunkSelectorExists) {
        [self executeDelegateBlock:^{
            [self.delegate httpLoader:self didReceiveDataChunk:data forResponse:response];
        }];
    }
}

- (void)receivedInitialResponse:(HTTPResponse *)response {
    if (![self isRequestExpected:response.request]) {
        return;
    }

    // Do not send a callback if the request doesn't support it
    if (!response.request.chunks) {
        return;
    }

    if ([self.delegate respondsToSelector:@selector(httpLoader:didReceiveInitialResponse:)]) {
        [self executeDelegateBlock:^{
            [self.delegate httpLoader:self didReceiveInitialResponse:response];
        }];
    }
}

- (void)needsNewBodyStream:(void (^)(NSInputStream *))completionHandler forRequest:(HTTPRequest *)request {
    if ([self.delegate respondsToSelector:@selector(httpLoader:needsNewBodyStream:forRequest:)]) {
        [self executeDelegateBlock:^{
            [self.delegate httpLoader:self
                   needsNewBodyStream:completionHandler
                           forRequest:request];
        }];
    } else {
        completionHandler(request.bodyStream);
    }
}

#pragma mark HTTPCancellationTokenDelegate

- (void)cancellationTokenDidCancel:(id<HTTPCancellationToken>)cancellationToken {
    HTTPRequest *request = (HTTPRequest *)cancellationToken.objectToCancel;
    [self.requestOperationHandlerDelegate requestOperationHandler:self cancelRequest:request];
    [self cancelledRequest:request];
}

- (void)cancellationTokenDidCancel:(id<HTTPCancellationToken>)cancellationToken producingResumeDataCompletion:(void (^)(NSData *_Nullable))completionHandler {
    HTTPRequest *request = (HTTPRequest *)cancellationToken.objectToCancel;
    [self.requestOperationHandlerDelegate requestOperationHandler:self cancelRequest:request producingResumeDataCompletion:completionHandler];
    [self cancelledRequest:request];
}

#pragma mark Private

- (void)executeDelegateBlock:(dispatch_block_t)block {
    if (self.delegateQueue == dispatch_get_main_queue() && [NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(self.delegateQueue, block);
    }
}

@end

NS_ASSUME_NONNULL_END
