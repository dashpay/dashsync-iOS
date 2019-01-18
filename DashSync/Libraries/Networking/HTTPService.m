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

#import "HTTPService.h"

#import "HTTPCancellationToken.h"
#import "HTTPLoaderFactory+Private.h"
#import "HTTPRateLimiterMap.h"
#import "HTTPRequest+Private.h"
#import "HTTPRequestOperation.h"
#import "HTTPRequestOperationHandler.h"
#import "HTTPResponse+Private.h"
#import "NSURLRequest+DCcURL.h"

NS_ASSUME_NONNULL_BEGIN

@interface HTTPService () <HTTPRequestOperationHandlerDelegate, NSURLSessionDataDelegate, NSURLSessionTaskDelegate, NSURLSessionDownloadDelegate>

@property (strong, nonatomic) NSURLSession *session;
@property (strong, nonatomic) NSOperationQueue *sessionQueue;
@property (strong, nonatomic) NSMutableArray<HTTPRequestOperation *> *operations;

@end

@implementation HTTPService

- (instancetype)initWithConfiguration:(NSURLSessionConfiguration *)configuration {
    const NSUInteger HTTPServiceMaxConcurrentOperations = 32;

    self = [super init];
    if (self) {
        _rateLimiterMap = [[HTTPRateLimiterMap alloc] init];
        _sessionQueue = [[NSOperationQueue alloc] init];
        _sessionQueue.maxConcurrentOperationCount = HTTPServiceMaxConcurrentOperations;
        _sessionQueue.name = NSStringFromClass(self.class);
        _session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:_sessionQueue];
        _operations = [[NSMutableArray alloc] init];
    }

    return self;
}

- (void)dealloc {
    [self cancelAllLoads];
}

- (HTTPLoaderFactory *)createHTTPLoaderFactoryWithAuthorisers:(nullable NSArray<id<HTTPLoaderAuthoriser>> *)authorisers {
    return [[HTTPLoaderFactory alloc] initWithRequestOperationHandlerDelegate:self authorisers:authorisers];
}

#pragma mark HTTPRequestOperationHandlerDelegate

- (void)requestOperationHandler:(id<HTTPRequestOperationHandler>)requestOperationHandler performRequest:(HTTPRequest *)request {
    if ([requestOperationHandler respondsToSelector:@selector(shouldAuthoriseRequest:)]) {
        if ([requestOperationHandler shouldAuthoriseRequest:request]) {
            if ([requestOperationHandler respondsToSelector:@selector(authoriseRequest:)]) {
                [requestOperationHandler authoriseRequest:request];
                return;
            }
        }
    }

    [self performRequest:request requestOperationHandler:requestOperationHandler];
}

- (void)requestOperationHandler:(id<HTTPRequestOperationHandler>)requestOperationHandler cancelRequest:(HTTPRequest *)request {
    NSArray *operations = nil;
    @synchronized(self.operations) {
        operations = [self.operations copy];
    }
    for (HTTPRequestOperation *operation in operations) {
        if ([operation.request isEqual:request]) {
            [operation.task cancel];
            break;
        }
    }
}

- (void)requestOperationHandler:(id<HTTPRequestOperationHandler>)requestOperationHandler
                  cancelRequest:(HTTPRequest *)request
  producingResumeDataCompletion:(void (^)(NSData *_Nullable resumeData))completionHandler {
    NSArray *operations = nil;
    @synchronized(self.operations) {
        operations = [self.operations copy];
    }
    for (HTTPRequestOperation *operation in operations) {
        if ([operation.request isEqual:request]) {
            NSURLSessionDownloadTask *downloadTask = (NSURLSessionDownloadTask *)operation.task;
            NSParameterAssert([downloadTask isKindOfClass:NSURLSessionDownloadTask.class]);
            if ([downloadTask isKindOfClass:NSURLSessionDownloadTask.class]) {
                [downloadTask cancelByProducingResumeData:completionHandler];
            }
            return;
        }
    }

    if (completionHandler) {
        if ([NSThread isMainThread]) {
            completionHandler(nil);
        }
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(nil);
            });
        }
    }
}

- (void)requestOperationHandler:(id<HTTPRequestOperationHandler>)requestOperationHandler authorisedRequest:(HTTPRequest *)request {
    [self performRequest:request requestOperationHandler:requestOperationHandler];
}

- (void)requestOperationHandler:(id<HTTPRequestOperationHandler>)requestOperationHandler failedToAuthoriseRequest:(HTTPRequest *)request error:(NSError *)error {
    HTTPResponse *response = [[HTTPResponse alloc] initWithRequest:request response:nil];
    response.error = error;
    [requestOperationHandler failedResponse:response];
}

#pragma mark NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveResponse:(NSURLResponse *)response
     completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    HTTPRequestOperation *operation = [self handlerForTask:dataTask];
    if (completionHandler) {
        completionHandler([operation receiveResponse:response]);
    }
}

- (void)URLSession:(NSURLSession *)session
                 dataTask:(NSURLSessionDataTask *)dataTask
    didBecomeDownloadTask:(NSURLSessionDownloadTask *)downloadTask {
    HTTPRequestOperation *operation = [self handlerForTask:dataTask];
    operation.task = downloadTask;
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data {
    HTTPRequestOperation *operation = [self handlerForTask:dataTask];
    [operation receiveData:data];
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
 willCacheResponse:(NSCachedURLResponse *)proposedResponse
 completionHandler:(void (^)(NSCachedURLResponse *cachedResponse))completionHandler {
    if (!completionHandler) {
        return;
    }
    HTTPRequestOperation *operation = [self handlerForTask:dataTask];
    completionHandler(operation.request.skipNSURLCache ? nil : proposedResponse);
}

- (void)URLSession:(NSURLSession *)session
                   task:(NSURLSessionTask *)task
    didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
      completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *__nullable credential))completionHandler {
    if (!completionHandler) {
        return;
    }

    NSURLSessionAuthChallengeDisposition disposition = NSURLSessionAuthChallengePerformDefaultHandling;
    NSURLCredential *credential = nil;

    if (self.areAllCertificatesAllowed) {
        SecTrustRef trust = challenge.protectionSpace.serverTrust;
        disposition = NSURLSessionAuthChallengeUseCredential;
        credential = [NSURLCredential credentialForTrust:trust];
    }
    else {
        // No-op
        // Use default handing
    }

    completionHandler(disposition, credential);
}

#pragma mark NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session
                    task:(NSURLSessionTask *)task
    didCompleteWithError:(nullable NSError *)error {
    HTTPRequestOperation *operation = [self handlerForTask:task];
    if (operation == nil) {
        return;
    }
    NSData *resumeData = error.userInfo[NSURLSessionDownloadTaskResumeData];
    if (resumeData) {
        operation.task = [self.session downloadTaskWithResumeData:resumeData];
    }
    else if (operation.request.downloadTaskPolicy == HTTPRequestDownloadTaskPolicyAlways) {
        operation.task = [self.session downloadTaskWithRequest:operation.request.urlRequest];
    }
    else {
        operation.task = [self.session dataTaskWithRequest:operation.request.urlRequest];
    }
    HTTPResponse *response = [operation completeWithError:error response:task.response];
    if (response == nil && !operation.cancelled) {
        return;
    }

    @synchronized(self.operations) {
        [self.operations removeObject:operation];
    }
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
 needNewBodyStream:(void (^)(NSInputStream *_Nullable))completionHandler {
    HTTPRequestOperation *operation = [self handlerForTask:task];
    [operation provideNewBodyStreamWithCompletion:completionHandler];
}

#pragma mark NSURLSessionDownloadDelegate

- (void)URLSession:(NSURLSession *)session
                 downloadTask:(NSURLSessionDownloadTask *)downloadTask
    didFinishDownloadingToURL:(NSURL *)location {
    if (!location.path || !location.lastPathComponent) {
        [self URLSession:session task:downloadTask didCompleteWithError:nil];
        return;
    }
    NSFileManager *fileManager = [NSFileManager defaultManager];
    HTTPRequestOperation *operation = [self handlerForTask:downloadTask];

    NSString *filePath = operation.request.downloadLocationPath;
    if (!filePath) {
        NSString *cachePath = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
        cachePath = [cachePath stringByAppendingPathComponent:@"httpservice.temporary"];
        [fileManager createDirectoryAtPath:cachePath
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:nil];
        filePath = [cachePath stringByAppendingPathComponent:(NSString * _Nonnull)location.lastPathComponent];
        operation.request.downloadLocationPath = filePath;
    }

    NSError *fileError;
    if ([fileManager moveItemAtPath:(NSString * _Nonnull)location.path toPath:filePath error:&fileError]) {
        if (operation.request.downloadTaskPolicy == HTTPRequestDownloadTaskPolicyAlways) {
            [self URLSession:session task:downloadTask didCompleteWithError:nil];
        }
        else {
            [self.sessionQueue addOperationWithBlock:^{
                NSError *readError;
                NSData *data = [NSData dataWithContentsOfFile:filePath options:NSDataReadingUncached error:&readError];

                [fileManager removeItemAtPath:filePath error:nil];

                if (!readError) {
                    [operation receiveData:data];
                }

                [self URLSession:session task:downloadTask didCompleteWithError:readError];
            }];
        }
    }
    else {
        [self URLSession:session task:downloadTask didCompleteWithError:fileError];
    }
}

#pragma mark Private

- (nullable HTTPRequestOperation *)handlerForTask:(NSURLSessionTask *)task {
    NSArray *operations = nil;
    @synchronized(self.operations) {
        operations = [self.operations copy];
    }
    for (HTTPRequestOperation *operation in operations) {
        if ([operation.task isEqual:task]) {
            return operation;
        }
    }
    return nil;
}

- (void)performRequest:(HTTPRequest *)request requestOperationHandler:(id<HTTPRequestOperationHandler>)requestOperationHandler {
    if (request.cancellationToken.cancelled) {
        return;
    }

    if (request.URL.host == nil) {
        return;
    }

    NSURLRequest *urlRequest = request.urlRequest;
#ifdef DEBUG
    __unused NSString *cURLSting = [urlRequest dc_cURL];
#endif
    HTTPRateLimiter *rateLimiter = [self.rateLimiterMap rateLimiterForURL:request.URL];
    NSURLSessionTask *task;
    if (request.downloadTaskPolicy == HTTPRequestDownloadTaskPolicyAlways) {
        if (request.resumeData) {
            task = [self.session downloadTaskWithResumeData:request.resumeData];
        }
        else {
            task = [self.session downloadTaskWithRequest:urlRequest];
        }
    }
    else {
        NSAssert(!request.resumeData, @"Inconsistent HTTPRequest configuration");
        task = [self.session dataTaskWithRequest:urlRequest];
    }
    HTTPRequestOperation *operation = [[HTTPRequestOperation alloc] initWithTask:task
                                                                         request:request
                                                         requestOperationHandler:requestOperationHandler
                                                                     rateLimiter:rateLimiter];
    @synchronized(self.operations) {
        [self.operations addObject:operation];
    }
    [operation start];
}

- (void)cancelAllLoads {
    NSArray *operations = nil;
    @synchronized(self.operations) {
        operations = [self.operations copy];
    }
    for (HTTPRequestOperation *operation in operations) {
        [operation.task cancel];
    }
}

@end

NS_ASSUME_NONNULL_END
