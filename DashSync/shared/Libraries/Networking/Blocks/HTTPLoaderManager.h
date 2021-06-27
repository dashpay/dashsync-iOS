//
//  Created by Andrew Podkovyrin
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

#import <Foundation/Foundation.h>

#import "HTTPLoaderBlocks.h"
#import "HTTPLoaderOperationProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@class HTTPRequest;
@class HTTPLoaderFactory;

@interface HTTPLoaderManager : NSObject

- (instancetype)initWithFactory:(HTTPLoaderFactory *)factory NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (id<HTTPLoaderOperationProtocol>)sendRequest:(HTTPRequest *)httpRequest completion:(HTTPLoaderCompletionBlock)completion;
- (id<HTTPLoaderOperationProtocol>)sendRequest:(HTTPRequest *)httpRequest rawCompletion:(HTTPLoaderRawCompletionBlock)rawCompletion;

@end

NS_ASSUME_NONNULL_END
