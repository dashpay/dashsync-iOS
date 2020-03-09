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

#import <UIKit/UIKit.h>

#import "DSNetworkActivityIndicatorManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSNetworkActivityIndicatorManager ()

@property (assign, nonatomic) NSUInteger counter;

@end

@implementation DSNetworkActivityIndicatorManager

+ (void)increaseActivityCounter {
    dispatch_block_t block = ^{
        [[[self class] sharedInstance] increaseActivityCounter];
    };

    if ([NSThread isMainThread]) {
        block();
    }
    else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

+ (void)decreaseActivityCounter {
    dispatch_block_t block = ^{
        [[[self class] sharedInstance] decreaseActivityCounter];
    };

    if ([NSThread isMainThread]) {
        block();
    }
    else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

#pragma mark Private

+ (instancetype)sharedInstance {
    static id _sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] init];
    });
    return _sharedInstance;
}

- (void)increaseActivityCounter {
    self.counter++;

    if (self.counter > 0) {
#if TARGET_OS_IOS
        [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
#endif
    }
}

- (void)decreaseActivityCounter {
    if (self.counter == 0) {
        DSDLog(@"activity counter < 0, something went wrong in class %@", [self class]);

        return;
    }

    self.counter--;

    if (self.counter == 0) {
#if TARGET_OS_IOS
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
#endif
    }
}

@end

NS_ASSUME_NONNULL_END
