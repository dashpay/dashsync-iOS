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

#import "DSHTTPGETOperation.h"

#import "DSAuthenticationManager+Private.h"
#import "DSNetworkActivityObserver.h"
#import "DSReachabilityCondition.h"

NS_ASSUME_NONNULL_BEGIN

NSString *const DSHTTPGETOperationErrorDomain = @"DSHTTPGETOperationError";

@interface DSHTTPGETOperation ()

@property (copy, nonatomic) NSURLRequest *request;
@property (strong, nonatomic, nullable) id responseJSONObject;

@end

@implementation DSHTTPGETOperation

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
    NSURLSessionDataTask *task = [session dataTaskWithRequest:self.request completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response, NSError *_Nullable error) {
        NSError *statusCodeError = nil;
        NSUInteger statusCode = [response isKindOfClass:NSHTTPURLResponse.class] ? [(NSHTTPURLResponse *)response statusCode] : 500;
        if (statusCode < 200 || statusCode > 300) {
            NSDictionary *userInfo = @{NSLocalizedDescriptionKey : [NSHTTPURLResponse localizedStringForStatusCode:statusCode]};
            statusCodeError = [NSError errorWithDomain:DSHTTPGETOperationErrorDomain
                                                  code:statusCode
                                              userInfo:userInfo];
        }

        if (statusCodeError || error) {
            [self cancelWithError:(statusCodeError ?: error)];
        }
        else {
            if ([response isKindOfClass:NSHTTPURLResponse.class]) { // store server timestamp
                [[DSAuthenticationManager sharedInstance] updateSecureTimeFromResponseIfNeeded:(NSHTTPURLResponse *)response];
            }

            NSError *jsonError = nil;
            self.responseJSONObject = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
            if (jsonError) {
                [self cancelWithError:jsonError];
            }
            else {
                [self finish];
            }
        }
    }];

    [task resume];
}

#pragma mark DSChainableOperationProtocol

- (nullable id)additionalDataToPassForChainedOperation {
    return self.responseJSONObject;
}

@end

NS_ASSUME_NONNULL_END
