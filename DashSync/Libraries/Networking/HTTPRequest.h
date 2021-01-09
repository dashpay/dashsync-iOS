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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, HTTPRequestMethod)
{
    HTTPRequestMethod_GET,
    HTTPRequestMethod_POST,
    HTTPRequestMethod_PUT,
    HTTPRequestMethod_DELETE,
    HTTPRequestMethod_UPDATE,
    HTTPRequestMethod_HEAD,
};

typedef NS_ENUM(NSUInteger, HTTPContentType)
{
    HTTPContentType_JSON,
    HTTPContentType_UrlEncoded,
};

typedef NS_ENUM(NSUInteger, HTTPRequestDownloadTaskPolicy)
{
    HTTPRequestDownloadTaskPolicyNone,
    HTTPRequestDownloadTaskPolicyOnDemand,
    HTTPRequestDownloadTaskPolicyAlways,
};

typedef NS_ENUM(NSInteger, HTTPRequestErrorCode)
{
    HTTPRequestErrorCode_Timeout,
    HTTPRequestErrorCode_ChunkedRequestWithoutChunkedDelegate
};

extern NSString *const HTTPRequestErrorDomain;

@interface HTTPRequest : NSObject <NSCopying>

@property (readonly, strong, nonatomic) NSURL *URL;
@property (readonly, assign, nonatomic) HTTPRequestMethod method;
@property (nullable, readonly, strong, nonatomic) NSData *body;
@property (nullable, readonly, strong, nonatomic) NSInputStream *bodyStream;
@property (readonly, copy, nonatomic) NSDictionary<NSString *, NSString *> *headers;
@property (nullable, readonly, copy, nonatomic) NSString *sourceIdentifier;
@property (readonly, assign, nonatomic) int64_t uniqueIdentifier;

@property (assign, nonatomic) HTTPRequestDownloadTaskPolicy downloadTaskPolicy;
@property (nullable, copy, nonatomic) NSString *downloadLocationPath;
@property (nullable, copy, nonatomic) NSData *resumeData;
@property (assign, nonatomic) BOOL chunks;
@property (assign, nonatomic) NSURLRequestCachePolicy cachePolicy;
@property (assign, nonatomic) NSJSONReadingOptions jsonReadingOptions;
@property (assign, nonatomic) BOOL skipNSURLCache;
@property (assign, nonatomic) NSTimeInterval timeout;
@property (assign, nonatomic) NSUInteger maximumRetryCount;
@property (copy, nonatomic) NSDictionary *userInfo;

+ (instancetype)requestWithURL:(NSURL *)URL
                        method:(HTTPRequestMethod)method
                    parameters:(nullable NSDictionary *)parameters;
+ (instancetype)requestWithURL:(NSURL *)URL
                        method:(HTTPRequestMethod)method
                   contentType:(HTTPContentType)contentType
                    parameters:(nullable NSDictionary *)parameters;
- (instancetype)initWithURL:(NSURL *)URL
                     method:(HTTPRequestMethod)method
                contentType:(HTTPContentType)contentType
                 parameters:(nullable NSDictionary *)parameters
                       body:(nullable NSData *)body
           sourceIdentifier:(nullable NSString *)sourceIdentifier;
- (instancetype)initWithURL:(NSURL *)URL
                     method:(HTTPRequestMethod)method
                 parameters:(nullable NSDictionary *)parameters
                 bodyStream:(nullable NSInputStream *)bodyStream
           sourceIdentifier:(nullable NSString *)sourceIdentifier;
- (instancetype)init NS_UNAVAILABLE;

- (void)addValue:(NSString *)value forHeader:(NSString *)header;
- (void)removeHeader:(NSString *)header;
- (void)setBasicAuthWithUsername:(NSString *)username password:(NSString *)password;

@end

NS_ASSUME_NONNULL_END
