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

#import "HTTPLoaderOperation.h"

#import "HTTPCancellationToken.h"
#import "HTTPLoader.h"
#import "HTTPLoaderDelegate.h"
#import "HTTPLoaderFactory.h"
#import "HTTPRequest.h"
#import "DSNetworkActivityIndicatorManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface HTTPLoaderOperation () <HTTPLoaderDelegate>

@property (strong, nonatomic) HTTPLoader *httpLoader;
@property (strong, nonatomic) HTTPRequest *httpRequest;

@property (weak, nonatomic) id<HTTPCancellationToken> cancellationToken;
@property (nullable, copy, nonatomic) HTTPLoaderRawCompletionBlock completion;

@end

@implementation HTTPLoaderOperation

- (instancetype)initWithHTTPRequest:(HTTPRequest *)httpRequest httpLoaderFactory:(HTTPLoaderFactory *)httpLoaderFactory {
    NSParameterAssert(httpRequest);
    NSParameterAssert(httpLoaderFactory);

    self = [super init];
    if (self) {
        _httpRequest = httpRequest;
        _httpLoader = [httpLoaderFactory createHTTPLoader];
        _httpLoader.delegate = self;
    }

    return self;
}

- (void)performWithCompletion:(HTTPLoaderRawCompletionBlock)completion {
    NSParameterAssert(completion);

    //
    // hold cycle reference to the `self` to keep an operation alive until it completed or cancelled
    //
    __block id referenceToSelf = self;
    self.completion = ^(BOOL success, BOOL cancelled, HTTPResponse *_Nullable response) {
        if (completion) {
            completion(success, cancelled, response);
        }

        referenceToSelf = nil;
    };

    self.cancellationToken = [self.httpLoader performRequest:self.httpRequest];
    NSAssert(self.cancellationToken, @"Performing request failed");
    
    [DSNetworkActivityIndicatorManager increaseActivityCounter];
}

#pragma mark HTTPLoaderOperationProtocol

- (void)cancel {
    [self.cancellationToken cancel];

    //
    // nilled out completion block to break the retain cycle
    // @see: performWithCompletion
    //
    self.completion = nil;
}

- (void)cancelByProducingResumeData:(void (^)(NSData *_Nullable resumeData))completionHandler {
    [self.cancellationToken cancelByProducingResumeData:^(NSData *_Nullable resumeData) {
        if (completionHandler) {
            completionHandler(resumeData);
        }

        //
        // nilled out completion block to break the retain cycle
        // @see: performWithCompletion
        //
        self.completion = nil;
    }];
}

#pragma mark HTTPLoaderDelegate

- (void)httpLoader:(HTTPLoader *)httpLoader didReceiveSuccessfulResponse:(HTTPResponse *)response {
    [DSNetworkActivityIndicatorManager decreaseActivityCounter];

    if (self.completion) {
        self.completion(YES, NO, response);
    }
}

- (void)httpLoader:(HTTPLoader *)httpLoader didReceiveErrorResponse:(HTTPResponse *)response {
    [DSNetworkActivityIndicatorManager decreaseActivityCounter];

    if (self.completion) {
        self.completion(NO, NO, response);
    }
}

- (void)httpLoader:(HTTPLoader *)httpLoader didCancelRequest:(HTTPRequest *)request {
    [DSNetworkActivityIndicatorManager decreaseActivityCounter];

    if (self.completion) {
        self.completion(NO, YES, nil);
    }
}

@end

NS_ASSUME_NONNULL_END
