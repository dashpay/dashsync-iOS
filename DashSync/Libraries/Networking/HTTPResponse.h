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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// http://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html
typedef NS_ENUM(NSInteger, HTTPResponseStatusCode) {
    HTTPResponseStatusCode_Invalid = 0,
    // Informational
    HTTPResponseStatusCode_Continue = 100,
    HTTPResponseStatusCode_SwitchProtocols = 101,
    // Successful
    HTTPResponseStatusCode_OK = 200,
    HTTPResponseStatusCode_Created = 201,
    HTTPResponseStatusCode_Accepted = 202,
    HTTPResponseStatusCode_NonAuthoritiveInformation = 203,
    HTTPResponseStatusCode_NoContent = 204,
    HTTPResponseStatusCode_ResetContent = 205,
    HTTPResponseStatusCode_PartialContent = 206,
    // Redirection
    HTTPResponseStatusCode_MovedMultipleChoices = 300,
    HTTPResponseStatusCode_MovedPermanently = 301,
    HTTPResponseStatusCode_Found = 302,
    HTTPResponseStatusCode_SeeOther = 303,
    HTTPResponseStatusCode_NotModified = 304,
    HTTPResponseStatusCode_UseProxy = 305,
    HTTPResponseStatusCode_Unused = 306,
    HTTPResponseStatusCode_TemporaryRedirect = 307,
    // Client Error
    HTTPResponseStatusCode_BadRequest = 400,
    HTTPResponseStatusCode_Unauthorised = 401,
    HTTPResponseStatusCode_PaymentRequired = 402,
    HTTPResponseStatusCode_Forbidden = 403,
    HTTPResponseStatusCode_NotFound = 404,
    HTTPResponseStatusCode_MethodNotAllowed = 405,
    HTTPResponseStatusCode_NotAcceptable = 406,
    HTTPResponseStatusCode_ProxyAuthenticationRequired = 407,
    HTTPResponseStatusCode_RequestTimeout = 408,
    HTTPResponseStatusCode_Conflict = 409,
    HTTPResponseStatusCode_Gone = 410,
    HTTPResponseStatusCode_LengthRequired = 411,
    HTTPResponseStatusCode_PreconditionFailed = 412,
    HTTPResponseStatusCode_RequestEntityTooLarge = 413,
    HTTPResponseStatusCode_RequestURITooLong = 414,
    HTTPResponseStatusCode_UnsupportedMediaTypes = 415,
    HTTPResponseStatusCode_RequestRangeUnsatisifiable = 416,
    HTTPResponseStatusCode_ExpectationFail = 417,
    // Server Error
    HTTPResponseStatusCode_InternalServerError = 500,
    HTTPResponseStatusCode_NotImplemented = 501,
    HTTPResponseStatusCode_BadGateway = 502,
    HTTPResponseStatusCode_ServiceUnavailable = 503,
    HTTPResponseStatusCode_GatewayTimeout = 504,
    HTTPResponseStatusCode_HTTPVersionNotSupported = 505
};

@class HTTPRequest;

extern NSString *const HTTPResponseErrorDomain;

@interface HTTPResponse : NSObject

@property (readonly, strong, nonatomic) HTTPRequest *request;
@property (nullable, readonly, strong, nonatomic) NSError *error;
@property (readonly, copy, nonatomic) NSDictionary<NSString *, NSString *> *responseHeaders;
@property (nullable, readonly, strong, nonatomic) NSDate *retryAfter;
@property (nullable, readonly, strong, nonatomic) NSData *body;
@property (readonly, assign, nonatomic) NSTimeInterval requestTime;
@property (readonly, assign, nonatomic) HTTPResponseStatusCode statusCode;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
