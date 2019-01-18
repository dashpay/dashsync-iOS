//
//  Created by Andrew Podkovyrin
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

#import "DSNetworkingCoordinator.h"

NS_ASSUME_NONNULL_BEGIN

@implementation DSNetworkingCoordinator

+ (instancetype)sharedInstance {
    static DSNetworkingCoordinator *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] init];
    });
    return _sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        HTTPService *httpService = [[HTTPService alloc] initWithConfiguration:configuration];

        _httpService = httpService;
        _loaderFactory = [httpService createHTTPLoaderFactoryWithAuthorisers:nil];
    }
    return self;
}

@end

NS_ASSUME_NONNULL_END
