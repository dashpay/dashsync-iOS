//
// Created by wiistriker@gmail.com
// Copyright (c) 2013 JustCommunication
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class HTTPLoaderFactory;

/**
 DSHTTPJSONRPCClient objects communicate with web services using the JSON-RPC 2.0 protocol.
 
 @see http://www.jsonrpc.org/specification
 */
@interface DSHTTPJSONRPCClient : NSObject

/**
 The endpoint URL for the webservice.
 */
@property (readonly, strong, nonatomic) NSURL *endpointURL;

/**
 Creates and initializes a JSON-RPC client with the specified endpoint.
 
 @param URL The endpoint URL.
 @param httpLoaderFactory The factory to create HTTP manager
 
 @return An initialized JSON-RPC client.
 */
+ (instancetype)clientWithEndpointURL:(NSURL *)URL
                    httpLoaderFactory:(HTTPLoaderFactory *)httpLoaderFactory;

/**
 Initializes a JSON-RPC client with the specified endpoint.
 
 @param URL The endpoint URL.
 @param httpLoaderFactory The factory to create HTTP manager
 
 @return An initialized JSON-RPC client.
 */
- (instancetype)initWithEndpointURL:(NSURL *)URL
                  httpLoaderFactory:(HTTPLoaderFactory *)httpLoaderFactory NS_DESIGNATED_INITIALIZER;

/**
 Creates a request with the specified method, and enqueues a request operation for it.
 
 @param method The HTTP method. Must not be `nil`.
 @param success A block object to be executed when the request operation finishes successfully. This block has no return value and takes one argument: the response object created by the client response serializer.
 @param failure A block object to be executed when the request operation finishes unsuccessfully, or that finishes successfully, but encountered an error while parsing the response data. This block has no return value and takes one argument: the error describing the network or parsing error that occurred.
 */
- (void)invokeMethod:(NSString *)method
             success:(void (^)(id responseObject))success
             failure:(void (^)(NSError *error))failure;

/**
 Creates a request with the specified method and parameters, and enqueues a request operation for it.

 @param method The HTTP method. Must not be `nil`.
 @param parameters The parameters to encode into the request. Must be either an `NSDictionary` or `NSArray`.
 @param success A block object to be executed when the request operation finishes successfully. This block has no return value and takes one argument: the response object created by the client response serializer.
 @param failure A block object to be executed when the request operation finishes unsuccessfully, or that finishes successfully, but encountered an error while parsing the response data. This block has no return value and takes one argument: the error describing the network or parsing error that occurred.
 */
- (void)invokeMethod:(NSString *)method
      withParameters:(id)parameters
             success:(void (^)(id responseObject))success
             failure:(void (^)(NSError *error))failure;

/**
 Creates a request with the specified method and parameters, and enqueues a request operation for it.

 @param method The HTTP method. Must not be `nil`.
 @param parameters The parameters to encode into the request. Must be either an `NSDictionary` or `NSArray`.
 @param requestId The ID of the request.
 @param success A block object to be executed when the request operation finishes successfully. This block has no return value and takes one arguments: the response object created by the client response serializer.
 @param failure A block object to be executed when the request operation finishes unsuccessfully, or that finishes successfully, but encountered an error while parsing the response data. This block has no return value and takes one argument: the error describing the network or parsing error that occurred.
 */
- (void)invokeMethod:(NSString *)method
      withParameters:(id)parameters
           requestId:(id)requestId
             success:(void (^)(id responseObject))success
             failure:(void (^)(NSError *error))failure;

///----------------------
/// @name Method Proxying
///----------------------

/**
 Returns a JSON-RPC client proxy object with methods conforming to the specified protocol.

 @param protocol The protocol.

 @discussion This approach allows Objective-C messages to be transparently forwarded as JSON-RPC calls.
 */
- (id)proxyWithProtocol:(Protocol *)protocol;


/**
 Default initializer is unavailable.
 
 @see -initWithEndpointURL:httpLoaderFactory:
 */
- (instancetype)init NS_UNAVAILABLE;

@end

///----------------
/// @name Constants
///----------------

/**
 DSJSONRPCClientErrorDomain errors.
 */
extern NSString *const DSJSONRPCClientErrorDomain;

NS_ASSUME_NONNULL_END
