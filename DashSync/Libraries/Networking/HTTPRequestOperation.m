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

#import "HTTPRequestOperation.h"

#import "HTTPRateLimiter.h"
#import "HTTPRequest.h"
#import "HTTPResponse.h"

#import "HTTPRequestOperationHandler.h"
#import "HTTPResponse+Private.h"

#import "SPTDataLoaderExponentialTimer.h"

NS_ASSUME_NONNULL_BEGIN

static NSUInteger const HTTPRequestOperationMaxRedirects = 10;

@interface HTTPRequestOperation ()

@property (assign, nonatomic, getter=isCancelled) BOOL cancelled;

@property (weak, nonatomic) id<HTTPRequestOperationHandler> requestOperationHandler;
@property (nullable, strong, nonatomic) HTTPRateLimiter *rateLimiter;

@property (strong, nonatomic) HTTPResponse *response;
@property (nullable, strong, nonatomic) NSMutableData *receivedData;
@property (assign, nonatomic) CFAbsoluteTime absoluteStartTime;
@property (assign, nonatomic) NSUInteger retryCount;
@property (assign, nonatomic) NSUInteger waitCount;
@property (assign, nonatomic) NSUInteger redirectCount;
@property (copy, nonatomic) dispatch_block_t executionBlock;
@property (strong, nonatomic) SPTDataLoaderExponentialTimer *exponentialTimer;

@property (assign, nonatomic) BOOL calledSuccessfulResponse;
@property (assign, nonatomic) BOOL calledFailedResponse;
@property (assign, nonatomic) BOOL calledCancelledRequest;
@property (assign, nonatomic) BOOL started;
@property (strong, nonatomic) dispatch_queue_t retryQueue;

@end

@implementation HTTPRequestOperation

- (instancetype)initWithTask:(NSURLSessionTask *)task
                     request:(HTTPRequest *)request
     requestOperationHandler:(id<HTTPRequestOperationHandler>)requestOperationHandler
                 rateLimiter:(nullable HTTPRateLimiter *)rateLimiter {
    const NSTimeInterval HTTPRequestOperationMaximumTime = 60.0;
    const NSTimeInterval HTTPRequestOperationInitialTime = 1.0;

    self = [super init];
    if (self) {
        _task = task;
        _request = request;
        _requestOperationHandler = requestOperationHandler;
        _rateLimiter = rateLimiter;

        __weak __typeof(self) weakSelf = self;
        _executionBlock = ^{
            [weakSelf checkRateLimiterAndExecute];
        };
        _exponentialTimer = [SPTDataLoaderExponentialTimer exponentialTimerWithInitialTime:HTTPRequestOperationInitialTime
                                                                                   maxTime:HTTPRequestOperationMaximumTime];
        _retryQueue = dispatch_get_main_queue();
    }

    return self;
}

- (void)dealloc {
    [self completeIfInFlight];
}

- (void)receiveData:(NSData *)data {
    [data enumerateByteRangesUsingBlock:^(const void *bytes, NSRange byteRange, BOOL *stop) {
        NSData *dataRange = [NSData dataWithBytes:bytes length:byteRange.length];

        if (self.request.chunks) {
            [self.requestOperationHandler receivedDataChunk:dataRange forResponse:self.response];
        } else {
            if (!self.receivedData) {
                self.receivedData = [dataRange mutableCopy];
            } else {
                [self.receivedData appendData:dataRange];
            }
        }
    }];
}

- (nullable HTTPResponse *)completeWithError:(nullable NSError *)error response:(nullable NSURLResponse *)response {
    id<HTTPRequestOperationHandler> requestOperationHandler = self.requestOperationHandler;
    if (!self.response) {
        self.response = [[HTTPResponse alloc] initWithRequest:self.request response:response];
    } else {
        [self.response updateResponseIfNeeded:response];
    }

    if ([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled) {
        [requestOperationHandler cancelledRequest:self.request];
        self.calledCancelledRequest = YES;
        self.cancelled = YES;
        return nil;
    }

    [self.rateLimiter executedRequest];

    if (error) {
        self.response.error = error;
    }

    self.response.body = self.receivedData;
    self.response.requestTime = CFAbsoluteTimeGetCurrent() - self.absoluteStartTime;

    if (self.response.error) {
        if ([self.response shouldRetry]) {
            if (self.retryCount++ != self.request.maximumRetryCount) {
                [self start];
                return nil;
            }
        }
        [requestOperationHandler failedResponse:self.response];
        self.calledFailedResponse = YES;
        return self.response;
    }

    [requestOperationHandler successfulResponse:self.response];
    self.calledSuccessfulResponse = YES;
    return self.response;
}

- (NSURLSessionResponseDisposition)receiveResponse:(NSURLResponse *)response {
    self.response = [[HTTPResponse alloc] initWithRequest:self.request response:response];
    [self.requestOperationHandler receivedInitialResponse:self.response];

    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (httpResponse.expectedContentLength > 0) {
            self.receivedData = [NSMutableData dataWithCapacity:(NSUInteger)httpResponse.expectedContentLength];
        }
    }

    if (!self.receivedData) {
        self.receivedData = [NSMutableData data];
    }

    if (self.request.downloadTaskPolicy == HTTPRequestDownloadTaskPolicyOnDemand) {
        return NSURLSessionResponseBecomeDownload;
    } else {
        return NSURLSessionResponseAllow;
    }
}

- (BOOL)mayRedirect {
    // Limit the amount of possible redirects
    if (++self.redirectCount > HTTPRequestOperationMaxRedirects) {
        return NO;
    }

    return YES;
}

- (void)start {
    self.started = YES;
    self.executionBlock();
}

- (void)provideNewBodyStreamWithCompletion:(void (^)(NSInputStream *_Nonnull))completionHandler {
    [self.requestOperationHandler needsNewBodyStream:completionHandler forRequest:self.request];
}

- (void)checkRateLimiterAndExecute {
    NSTimeInterval waitTime = [self.rateLimiter earliestTimeUntilRequestCanBeExecuted];
    if (waitTime == 0.0) {
        [self checkRetryLimiterAndExecute];
    } else {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                           (int64_t)(waitTime * NSEC_PER_SEC)),
            self.retryQueue,
            self.executionBlock);
    }
}

- (void)checkRetryLimiterAndExecute {
    if (self.waitCount < self.retryCount) {
        self.waitCount++;
        if (self.waitCount == 1) {
            self.executionBlock();
        } else {
            NSTimeInterval waitTime = self.exponentialTimer.timeIntervalAndCalculateNext;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                               (int64_t)(waitTime * NSEC_PER_SEC)),
                self.retryQueue,
                self.executionBlock);
        }
        return;
    }

    self.absoluteStartTime = CFAbsoluteTimeGetCurrent();
    [self.task resume];
}

- (void)completeIfInFlight {
    // Always call the last error the request completed with if retrying
    if (self.started && !self.calledCancelledRequest && !self.calledFailedResponse && !self.calledSuccessfulResponse) {
        [self completeWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil] response:nil];
    }
}

@end

NS_ASSUME_NONNULL_END
