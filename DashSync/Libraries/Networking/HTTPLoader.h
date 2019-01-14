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

@protocol HTTPCancellationToken;
@protocol HTTPLoaderDelegate;
@class HTTPRequest;

@interface HTTPLoader : NSObject

@property (nullable, weak, nonatomic) id<HTTPLoaderDelegate> delegate;
@property (strong, nonatomic) dispatch_queue_t delegateQueue;
@property (readonly, copy, nonatomic) NSArray<HTTPRequest *> *currentRequests;

- (nullable id<HTTPCancellationToken>)performRequest:(HTTPRequest *)request;

- (void)cancelAllLoads;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
