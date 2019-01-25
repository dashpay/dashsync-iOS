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

#import "HTTPCancellationTokenImpl.h"

NS_ASSUME_NONNULL_BEGIN

@interface HTTPCancellationTokenImpl ()

@property (assign, nonatomic, getter=isCancelled) BOOL cancelled;

@end

@implementation HTTPCancellationTokenImpl

- (instancetype)initWithDelegate:(id<HTTPCancellationTokenDelegate>)delegate cancelObject:(nullable id)cancelObject {
    self = [super init];
    if (self) {
        _delegate = delegate;
        _objectToCancel = cancelObject;
    }

    return self;
}

#pragma mark HTTPCancellationToken

@synthesize cancelled = _cancelled;
@synthesize delegate = _delegate;
@synthesize objectToCancel = _objectToCancel;

- (void)cancel {
    if (self.cancelled) {
        return;
    }

    [self.delegate cancellationTokenDidCancel:self];

    self.cancelled = YES;
}

- (void)cancelByProducingResumeData:(void (^)(NSData *_Nullable resumeData))completionHandler {
    [self.delegate cancellationTokenDidCancel:self producingResumeDataCompletion:^(NSData *_Nullable resumeData) {
        if (completionHandler) {
            dispatch_block_t block = ^{
                completionHandler(resumeData);
            };

            if ([NSThread isMainThread]) {
                block();
            }
            else {
                dispatch_async(dispatch_get_main_queue(), block);
            }
        }
    }];
}

@end

NS_ASSUME_NONNULL_END
