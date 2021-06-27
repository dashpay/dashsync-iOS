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

#import "HTTPLoaderFactory.h"

#import "HTTPCancellationTokenImpl.h"
#import "HTTPLoader+Private.h"
#import "HTTPLoaderAuthoriser.h"
#import "HTTPLoaderFactory+Private.h"
#import "HTTPRequest+Private.h"
#import "HTTPRequest.h"
#import "HTTPResponse+Private.h"

NS_ASSUME_NONNULL_BEGIN

@interface HTTPLoaderFactory () <HTTPRequestOperationHandlerDelegate, HTTPLoaderAuthoriserDelegate>

@property (strong, nonatomic) NSMapTable<HTTPRequest *, id<HTTPRequestOperationHandler>> *requestToRequestOperationHandler;
@property (strong, nonatomic) dispatch_queue_t requestTimeoutQueue;

@end

@implementation HTTPLoaderFactory

- (instancetype)initWithRequestOperationHandlerDelegate:(nullable id<HTTPRequestOperationHandlerDelegate>)requestOperationHandlerDelegate
                                            authorisers:(nullable NSArray<id<HTTPLoaderAuthoriser>> *)authorisers {
    self = [super init];
    if (self) {
        _requestOperationHandlerDelegate = requestOperationHandlerDelegate;
        _authorisers = [authorisers copy];

        _requestToRequestOperationHandler = [NSMapTable weakToWeakObjectsMapTable];
        _requestTimeoutQueue = dispatch_get_main_queue();

        for (id<HTTPLoaderAuthoriser> authoriser in _authorisers) {
            authoriser.delegate = self;
        }
    }

    return self;
}

#pragma mark HTTPLoaderFactory

- (HTTPLoader *)createHTTPLoader {
    return [[HTTPLoader alloc] initWithRequestOperationHandlerDelegate:self];
}

#pragma mark HTTPRequestOperationHandler

@synthesize requestOperationHandlerDelegate = _requestOperationHandlerDelegate;

- (void)successfulResponse:(HTTPResponse *)response {
    id<HTTPRequestOperationHandler> requestOperationHandler = nil;
    @synchronized(self.requestToRequestOperationHandler) {
        requestOperationHandler = [self.requestToRequestOperationHandler objectForKey:response.request];
        [self.requestToRequestOperationHandler removeObjectForKey:response.request];
    }
    [requestOperationHandler successfulResponse:response];
}

- (void)failedResponse:(HTTPResponse *)response {
    // If we failed on authorisation and we have not retried the authorisation, retry it
    if (response.error.code == HTTPResponseStatusCode_Unauthorised && !response.request.retriedAuthorisation) {
        for (id<HTTPLoaderAuthoriser> authoriser in self.authorisers) {
            if ([authoriser requestRequiresAuthorisation:response.request]) {
                [authoriser requestFailedAuthorisation:response.request];
            }
        }
        response.request.retriedAuthorisation = YES;
        if ([self shouldAuthoriseRequest:response.request]) {
            [self authoriseRequest:response.request];
            return;
        }
    }

    id<HTTPRequestOperationHandler> requestOperationHandler = nil;
    @synchronized(self.requestToRequestOperationHandler) {
        requestOperationHandler = [self.requestToRequestOperationHandler objectForKey:response.request];
        [self.requestToRequestOperationHandler removeObjectForKey:response.request];
    }
    [requestOperationHandler failedResponse:response];
}

- (void)cancelledRequest:(HTTPRequest *)request {
    id<HTTPRequestOperationHandler> requestOperationHandler = nil;
    @synchronized(self.requestToRequestOperationHandler) {
        requestOperationHandler = [self.requestToRequestOperationHandler objectForKey:request];
        [self.requestToRequestOperationHandler removeObjectForKey:request];
    }
    [requestOperationHandler cancelledRequest:request];
}

- (void)receivedDataChunk:(NSData *)data forResponse:(HTTPResponse *)response {
    id<HTTPRequestOperationHandler> requestOperationHandler = nil;
    @synchronized(self.requestToRequestOperationHandler) {
        requestOperationHandler = [self.requestToRequestOperationHandler objectForKey:response.request];
    }
    [requestOperationHandler receivedDataChunk:data forResponse:response];
}

- (void)receivedInitialResponse:(HTTPResponse *)response {
    id<HTTPRequestOperationHandler> requestOperationHandler = nil;
    @synchronized(self.requestToRequestOperationHandler) {
        requestOperationHandler = [self.requestToRequestOperationHandler objectForKey:response.request];
    }
    [requestOperationHandler receivedInitialResponse:response];
}

- (BOOL)shouldAuthoriseRequest:(HTTPRequest *)request {
    for (id<HTTPLoaderAuthoriser> authoriser in self.authorisers) {
        if ([authoriser requestRequiresAuthorisation:request]) {
            return YES;
        }
    }

    return NO;
}

- (void)authoriseRequest:(HTTPRequest *)request {
    for (id<HTTPLoaderAuthoriser> authoriser in self.authorisers) {
        if ([authoriser requestRequiresAuthorisation:request]) {
            [authoriser authoriseRequest:request];
            return;
        }
    }
}

- (void)needsNewBodyStream:(void (^)(NSInputStream *_Nonnull))completionHandler forRequest:(HTTPRequest *)request {
    id<HTTPRequestOperationHandler> requestOperationHandler = nil;
    @synchronized(self.requestToRequestOperationHandler) {
        requestOperationHandler = [self.requestToRequestOperationHandler objectForKey:request];
    }
    [requestOperationHandler needsNewBodyStream:completionHandler forRequest:request];
}

#pragma mark HTTPRequestOperationHandlerDelegate

- (void)requestOperationHandler:(id<HTTPRequestOperationHandler>)requestOperationHandler performRequest:(HTTPRequest *)request {
    if (self.offline) {
        request.cachePolicy = NSURLRequestReturnCacheDataDontLoad;
    }

    @synchronized(self.requestToRequestOperationHandler) {
        [self.requestToRequestOperationHandler setObject:requestOperationHandler forKey:request];
    }

    // Add an absolute timeout for responses
    if (request.timeout > 0.0) {
        __weak __typeof(self) weakSelf = self;
        __weak __typeof(request) weakRequest = request;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(request.timeout * NSEC_PER_SEC)), self.requestTimeoutQueue, ^{
            __strong __typeof(self) strongSelf = weakSelf;
            __strong __typeof(request) strongRequest = weakRequest;
            HTTPResponse *response = [[HTTPResponse alloc] initWithRequest:strongRequest response:nil];
            NSError *error = [NSError errorWithDomain:HTTPRequestErrorDomain
                                                 code:HTTPRequestErrorCode_Timeout
                                             userInfo:nil];
            response.error = error;
            [strongSelf failedResponse:response];
        });
    }

    [self.requestOperationHandlerDelegate requestOperationHandler:self performRequest:request];
}

- (void)requestOperationHandler:(id<HTTPRequestOperationHandler>)requestOperationHandler cancelRequest:(HTTPRequest *)request {
    [self.requestOperationHandlerDelegate requestOperationHandler:requestOperationHandler cancelRequest:request];
}

- (void)requestOperationHandler:(id<HTTPRequestOperationHandler>)requestOperationHandler
                    cancelRequest:(HTTPRequest *)request
    producingResumeDataCompletion:(nonnull void (^)(NSData *_Nullable))completionHandler {
    [self.requestOperationHandlerDelegate requestOperationHandler:requestOperationHandler
                                                    cancelRequest:request
                                    producingResumeDataCompletion:completionHandler];
}

#pragma mark HTTPLoaderAuthoriserDelegate

- (void)httpLoaderAuthoriser:(id<HTTPLoaderAuthoriser>)httpLoaderAuthoriser authorisedRequest:(HTTPRequest *)request {
    id<HTTPRequestOperationHandlerDelegate> requestOperationHandlerDelegate = self.requestOperationHandlerDelegate;
    if ([requestOperationHandlerDelegate respondsToSelector:@selector(requestOperationHandler:authorisedRequest:)]) {
        [requestOperationHandlerDelegate requestOperationHandler:self authorisedRequest:request];
    }
}

- (void)httpLoaderAuthoriser:(id<HTTPLoaderAuthoriser>)httpLoaderAuthoriser didFailToAuthoriseRequest:(HTTPRequest *)request withError:(NSError *)error {
    id<HTTPRequestOperationHandlerDelegate> requestOperationHandlerDelegate = self.requestOperationHandlerDelegate;
    if ([requestOperationHandlerDelegate respondsToSelector:@selector(requestOperationHandler:failedToAuthoriseRequest:error:)]) {
        [requestOperationHandlerDelegate requestOperationHandler:self failedToAuthoriseRequest:request error:error];
    }
}

@end

NS_ASSUME_NONNULL_END
