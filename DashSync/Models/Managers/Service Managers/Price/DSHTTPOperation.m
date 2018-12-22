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

#import "DSHTTPOperation.h"

#import "DSAuthenticationManager+Private.h"
#import "DSHTTPOperationResult.h"
#import "DSNetworkActivityObserver.h"
#import "DSReachabilityCondition.h"

NS_ASSUME_NONNULL_BEGIN

NSString *const DSHTTPOperationErrorDomain = @"DSHTTPOperationError";

@interface DSHTTPOperation ()

@property (copy, nonatomic) NSURLRequest *request;
@property (nullable, strong, nonatomic) DSHTTPOperationResult *result;
@property (strong, nonatomic) NSURLSessionDataTask *task;

@end

@implementation DSHTTPOperation

- (instancetype)initWithRequest:(NSURLRequest *)request {
    self = [super init];
    if (self) {
        _request = request;

        [self addCondition:[DSReachabilityCondition reachabilityCondition]];
        [self addObserver:[DSNetworkActivityObserver new]];
    }
    return self;
}

- (void)execute {
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [session dataTaskWithRequest:self.request completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response, NSError *_Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }

        if (error) {
            strongSelf.result = [DSHTTPOperationResult resultWithStatusCode:0
                                                            responseHeaders:@{}
                                                                      error:error];

            [strongSelf cancelWithError:error];

            return;
        }

        NSHTTPURLResponse *httpURLResponse = (NSHTTPURLResponse *)response;
        BOOL isHTTPURLResponse = [httpURLResponse isKindOfClass:NSHTTPURLResponse.class];
        NSAssert(isHTTPURLResponse, @"Invalid server response");

        NSUInteger statusCode = isHTTPURLResponse ? httpURLResponse.statusCode : 500;
        if (statusCode < 200 || statusCode > 300) {
            NSDictionary *userInfo = @{NSLocalizedDescriptionKey : [NSHTTPURLResponse localizedStringForStatusCode:statusCode]};
            NSError *statusCodeError = [NSError errorWithDomain:DSHTTPOperationErrorDomain
                                                           code:statusCode
                                                       userInfo:userInfo];

            NSDictionary *responseHeaders = isHTTPURLResponse ? httpURLResponse.allHeaderFields : @{};
            strongSelf.result = [DSHTTPOperationResult resultWithStatusCode:statusCode
                                                            responseHeaders:responseHeaders
                                                                      error:statusCodeError];

            [strongSelf cancelWithError:statusCodeError];

            return;
        }

        // store server timestamp
        [[DSAuthenticationManager sharedInstance] updateSecureTimeFromResponseIfNeeded:httpURLResponse];

        NSError *jsonError = nil;
        id parsedResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if (jsonError) {
            strongSelf.result = [DSHTTPOperationResult resultWithStatusCode:statusCode
                                                            responseHeaders:httpURLResponse.allHeaderFields
                                                                      error:jsonError];
            [strongSelf cancelWithError:jsonError];
        }
        else {
            strongSelf.result = [DSHTTPOperationResult resultWithStatusCode:statusCode
                                                            responseHeaders:httpURLResponse.allHeaderFields
                                                             parsedResponse:parsedResponse];
            [strongSelf finish];
        }
    }];

    [task resume];
    
    self.task = task;
}

- (void)cancel {
    [self.task cancel];
    [super cancel];
}

#pragma mark DSChainableOperationProtocol

- (nullable id)additionalDataToPassForChainedOperation {
    return self.result;
}

@end

NS_ASSUME_NONNULL_END
