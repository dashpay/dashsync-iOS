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

#import "HTTPRateLimiter.h"

#import "HTTPRateLimiterMap.h"

NS_ASSUME_NONNULL_BEGIN

@interface HTTPRateLimiterMap ()

@property (strong, nonatomic) NSMutableDictionary<NSString *, HTTPRateLimiter *> *rateLimitersByKey;

@end

@implementation HTTPRateLimiterMap

- (instancetype)init {
    self = [super init];
    if (self) {
        _rateLimitersByKey = [NSMutableDictionary dictionary];
    }

    return self;
}

- (void)setRateLimiter:(HTTPRateLimiter *)rateLimiter forURL:(NSURL *)URL {
    NSParameterAssert(rateLimiter);
    NSParameterAssert(URL);

    if (!rateLimiter || !URL) {
        return;
    }

    NSString *key = [self keyFromURL:URL];
    @synchronized(self.rateLimitersByKey) {
        self.rateLimitersByKey[key] = rateLimiter;
    }
}

- (nullable HTTPRateLimiter *)rateLimiterForURL:(NSURL *)URL {
    NSParameterAssert(URL);

    if (!URL) {
        return nil;
    }

    NSString *key = [self keyFromURL:URL];
    HTTPRateLimiter *rateLimiter = nil;
    @synchronized(self.rateLimitersByKey) {
        rateLimiter = self.rateLimitersByKey[key];
    }

    return rateLimiter;
}

- (void)removeRateLimiterForURL:(NSURL *)URL {
    NSParameterAssert(URL);

    if (!URL) {
        return;
    }

    NSString *key = [self keyFromURL:URL];
    @synchronized(self.rateLimitersByKey) {
        [self.rateLimitersByKey removeObjectForKey:key];
    }
}

#pragma mark Private

- (NSString *)keyFromURL:(NSURL *)URL {
    if (!URL) {
        return @"";
    }

    NSURLComponents *components = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:NO];
    NSURLComponents *keyComponents = [[NSURLComponents alloc] init];
    keyComponents.scheme = components.scheme;
    keyComponents.host = components.host;
    keyComponents.path = components.path.pathComponents.firstObject;
    NSString *key = keyComponents.URL.absoluteString;

    return key;
}

@end

NS_ASSUME_NONNULL_END
