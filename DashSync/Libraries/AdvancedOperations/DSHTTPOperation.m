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

#import "DSHTTPOperation.h"

#import "DSNetworking.h"

NS_ASSUME_NONNULL_BEGIN

NSString *const DSHTTPOperationErrorDomain = @"DSHTTPOperation.error";

@interface DSHTTPOperation ()

@property (strong, nonatomic) HTTPRequest *request;
@property (nullable, weak, nonatomic) id<HTTPLoaderOperationProtocol> loaderOperation;

@end

@implementation DSHTTPOperation

- (instancetype)initWithRequest:(HTTPRequest *)request {
    NSParameterAssert(request);
    
    self = [super init];
    if (self) {
        _request = request;
    }
    return self;
}

- (void)execute {
    __weak typeof(self) weakSelf = self;
    HTTPLoaderManager *loaderManager = [DSNetworkingCoordinator sharedInstance].loaderManager;
    self.loaderOperation = [loaderManager sendRequest:self.request completion:^(id _Nullable parsedData, NSDictionary *_Nullable responseHeaders, NSInteger statusCode, NSError *_Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }

        if (error) {
            [strongSelf cancelWithError:error];
        }
        else {
            [strongSelf processSuccessResponse:parsedData responseHeaders:responseHeaders statusCode:statusCode];
        }
    }];
}

- (void)cancel {
    id<HTTPLoaderOperationProtocol> loaderOperation = self.loaderOperation;
    if (loaderOperation) {
        [loaderOperation cancel];
    }

    [super cancel];
}

- (void)processSuccessResponse:(id)parsedData responseHeaders:(NSDictionary *)responseHeaders statusCode:(NSInteger)statusCode {
    // To be implemented in subclass
}

- (void)cancelWithInvalidResponse:(id)responseData {
    NSParameterAssert(responseData);
    NSError *error = [NSError errorWithDomain:DSHTTPOperationErrorDomain
                                         code:DSHTTPOperationErrorCodeInvalidResponse
                                     userInfo:@{NSDebugDescriptionErrorKey : responseData}];
    [self cancelWithError:error];
}

@end

NS_ASSUME_NONNULL_END
