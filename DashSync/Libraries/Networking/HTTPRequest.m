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

#import "HTTPRequest.h"

#import "HTTPRequest+Private.h"
#import "HTTPURLRequestBuilder.h"

NS_ASSUME_NONNULL_BEGIN

NSString *const HTTPRequestErrorDomain = @"dash.httploader.request";

static NSString *NSStringFromHTTPRequestMethod(HTTPRequestMethod requestMethod) {
    switch (requestMethod) {
        case HTTPRequestMethod_DELETE:
            return @"DELETE";
        case HTTPRequestMethod_GET:
            return @"GET";
        case HTTPRequestMethod_POST:
            return @"POST";
        case HTTPRequestMethod_PUT:
            return @"PUT";
        case HTTPRequestMethod_HEAD:
            return @"HEAD";
        case HTTPRequestMethod_UPDATE:
            return @"UPDATE";
    }
}

@interface HTTPRequest ()

@property (assign, nonatomic) int64_t uniqueIdentifier;

@property (strong, nonatomic) NSMutableDictionary<NSString *, NSString *> *mutableHeaders;
@property (assign, nonatomic) BOOL retriedAuthorisation;
@property (weak, nonatomic) id<HTTPCancellationToken> cancellationToken;

@end

@implementation HTTPRequest

+ (instancetype)requestWithURL:(NSURL *)URL
                        method:(HTTPRequestMethod)method
                    parameters:(nullable NSDictionary *)parameters {
    return [[[self class] alloc] initWithURL:URL
                                      method:method
                                 contentType:HTTPContentType_UrlEncoded
                                  parameters:parameters
                                        body:nil
                            sourceIdentifier:nil];
}

+ (instancetype)requestWithURL:(NSURL *)URL
                        method:(HTTPRequestMethod)method
                   contentType:(HTTPContentType)contentType
                    parameters:(nullable NSDictionary *)parameters {
    return [[[self class] alloc] initWithURL:URL
                                      method:method
                                 contentType:contentType
                                  parameters:parameters
                                        body:nil
                            sourceIdentifier:nil];
}

- (instancetype)initWithURL:(NSURL *)URL
                     method:(HTTPRequestMethod)method
                contentType:(HTTPContentType)contentType
                 parameters:(nullable NSDictionary *)parameters
                       body:(nullable NSData *)body
           sourceIdentifier:(nullable NSString *)sourceIdentifier {
    NSAssert(URL != nil, @"URL must not be nil");

    NSURL *requestURL = URL;
    NSData *resultBody = nil;
    NSMutableDictionary<NSString *, NSString *> *mutableHeaders = [NSMutableDictionary dictionary];

    if (method == HTTPRequestMethod_GET || method == HTTPRequestMethod_HEAD || body) {
        NSString *query = [HTTPURLRequestBuilder queryStringFromParameters:parameters];
        NSString *absoluteString = URL.absoluteString;
        if (query && query.length > 0 && absoluteString.length > 0) {
            requestURL = [NSURL URLWithString:[absoluteString stringByAppendingFormat:URL.query ? @"&%@" : @"?%@", query]];
        }
    }
    else if (parameters && contentType == HTTPContentType_JSON) {
        resultBody = [HTTPURLRequestBuilder jsonDataFromParameters:parameters];
        mutableHeaders[@"Content-Type"] = @"application/json";
        mutableHeaders[@"Content-Length"] = @(resultBody.length).stringValue;
    }
    else if (parameters && contentType == HTTPContentType_UrlEncoded) {
        NSString *query = [HTTPURLRequestBuilder queryStringFromParameters:parameters] ?: @""; // an empty string is a valid x-www-form-urlencoded payload
        resultBody = [query dataUsingEncoding:NSUTF8StringEncoding];
        mutableHeaders[@"Content-Type"] = @"application/x-www-form-urlencoded; charset=utf-8";
        mutableHeaders[@"Content-Length"] = @(resultBody.length).stringValue;
    }

    if (body) {
        resultBody = body;
        mutableHeaders[@"Content-Length"] = @(resultBody.length).stringValue;
    }

    return [self initWithURL:requestURL
                      method:method
                        body:resultBody
                  bodyStream:nil
                     headers:mutableHeaders
            sourceIdentifier:sourceIdentifier];
}

- (instancetype)initWithURL:(NSURL *)URL
                     method:(HTTPRequestMethod)method
                 parameters:(nullable NSDictionary *)parameters
                 bodyStream:(nullable NSInputStream *)bodyStream
           sourceIdentifier:(nullable NSString *)sourceIdentifier {
    NSAssert(URL != nil, @"URL must not be nil");

    NSURL *requestURL = URL;
    NSString *query = [HTTPURLRequestBuilder queryStringFromParameters:parameters];
    NSString *absoluteString = URL.absoluteString;
    if (query && query.length > 0 && absoluteString.length > 0) {
        requestURL = [NSURL URLWithString:[absoluteString stringByAppendingFormat:URL.query ? @"&%@" : @"?%@", query]];
    }

    return [self initWithURL:requestURL
                      method:method
                        body:nil
                  bodyStream:bodyStream
                     headers:nil
            sourceIdentifier:sourceIdentifier];
}

- (instancetype)initWithURL:(NSURL *)URL
                     method:(HTTPRequestMethod)method
                       body:(nullable NSData *)body
                 bodyStream:(nullable NSInputStream *)bodyStream
                    headers:(nullable NSDictionary<NSString *, NSString *> *)headers
           sourceIdentifier:(nullable NSString *)sourceIdentifier {
    static int64_t uniqueIdentifier = 0;
    @synchronized(self.class) {
        return [self initWithURL:URL
                          method:method
                            body:body
                      bodyStream:bodyStream
                         headers:headers
                sourceIdentifier:sourceIdentifier
                uniqueIdentifier:uniqueIdentifier];
    }
}

- (instancetype)initWithURL:(NSURL *)URL
                     method:(HTTPRequestMethod)method
                       body:(nullable NSData *)body
                 bodyStream:(nullable NSInputStream *)bodyStream
                    headers:(nullable NSDictionary<NSString *, NSString *> *)headers
           sourceIdentifier:(nullable NSString *)sourceIdentifier
           uniqueIdentifier:(int64_t)uniqueIdentifier {
    self = [super init];
    if (self) {
        _URL = URL;
        _method = method;
        _body = body;
        _bodyStream = bodyStream;
        _mutableHeaders = [headers mutableCopy] ?: [NSMutableDictionary dictionary];
        _sourceIdentifier = sourceIdentifier;
        _uniqueIdentifier = uniqueIdentifier;
    }

    return self;
}

- (NSDictionary *)headers {
    @synchronized(self.mutableHeaders) {
        return [self.mutableHeaders copy];
    }
}

- (void)addValue:(NSString *)value forHeader:(NSString *)header {
    if (!header) {
        return;
    }

    @synchronized(self.mutableHeaders) {
        if (!value && header) {
            [self.mutableHeaders removeObjectForKey:header];
            return;
        }

        self.mutableHeaders[header] = value;
    }
}

- (void)removeHeader:(NSString *)header {
    @synchronized(self.mutableHeaders) {
        [self.mutableHeaders removeObjectForKey:header];
    }
}

- (void)setBasicAuthWithUsername:(NSString *)username password:(NSString *)password {
    NSString *userPassword = [NSString stringWithFormat:@"%@:%@", username, password];
    NSData *userPasswordData = [userPassword dataUsingEncoding:NSUTF8StringEncoding];
    NSString *base64EncodedCredential = [userPasswordData base64EncodedStringWithOptions:0];
    NSString *authString = [NSString stringWithFormat:@"Basic %@", base64EncodedCredential];
    [self addValue:authString forHeader:@"Authorization"];
}

#pragma mark Private

- (NSURLRequest *)urlRequest {
    NSString *const HTTPRequestContentLengthHeader = @"Content-Length";

    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:self.URL];

    if (self.bodyStream != nil) {
        urlRequest.HTTPBodyStream = self.bodyStream;
    }
    else if (self.body) {
        [urlRequest addValue:@(self.body.length).stringValue forHTTPHeaderField:HTTPRequestContentLengthHeader];
        urlRequest.HTTPBody = self.body;
    }

    NSDictionary *headers = self.headers;
    for (NSString *key in headers) {
        NSString *value = headers[key];
        [urlRequest addValue:value forHTTPHeaderField:key];
    }

    urlRequest.cachePolicy = self.cachePolicy;
    urlRequest.HTTPMethod = NSStringFromHTTPRequestMethod(self.method);

    return urlRequest;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p URL = \"%@\">", self.class, (void *)self, self.URL];
}

#pragma mark NSCopying

- (id)copyWithZone:(nullable NSZone *)zone {
    __typeof(self) copy = [[self.class alloc] initWithURL:self.URL
                                                   method:self.method
                                                     body:[self.body copy]
                                               bodyStream:self.bodyStream
                                                  headers:self.headers
                                         sourceIdentifier:self.sourceIdentifier
                                         uniqueIdentifier:self.uniqueIdentifier];
    copy.downloadTaskPolicy = self.downloadTaskPolicy;
    copy.downloadLocationPath = self.downloadLocationPath;
    copy.chunks = self.chunks;
    copy.cachePolicy = self.cachePolicy;
    copy.jsonReadingOptions = self.jsonReadingOptions;
    copy.skipNSURLCache = self.skipNSURLCache;
    copy.timeout = self.timeout;
    copy.maximumRetryCount = self.maximumRetryCount;
    copy.userInfo = self.userInfo;
    copy.cancellationToken = self.cancellationToken;
    return copy;
}

@end

NS_ASSUME_NONNULL_END
