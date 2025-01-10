//  
//  Created by Vladimir Pirogov
//  Copyright © 2024 Dash Core Group. All rights reserved.
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

#import "DSNetworkActivityView.h"

@interface DSNetworkActivityView ()

@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;
@property (nonatomic, assign) NSInteger activityCount;

@end

@implementation DSNetworkActivityView

+ (instancetype)shared {
    static DSNetworkActivityView *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    return sharedManager;
}
- (UIWindow *)getKeyWindow {
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
            for (UIWindow *window in ((UIWindowScene *)scene).windows) {
                if (window.isKeyWindow) return window;
            }
        }
    }
    return nil;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        UIWindow *keyWindow = [self getKeyWindow];
        if (keyWindow) {
            self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
            self.activityIndicator.center = keyWindow.center;
            [keyWindow addSubview:self.activityIndicator];
        }
        self.activityCount = 0;
    }
    return self;
}

- (void)start {
    @synchronized (self) {
        self.activityCount += 1;
        if (!self.activityIndicator.isAnimating) {
            [self.activityIndicator startAnimating];
        }
    }
}

- (void)stop {
    @synchronized (self) {
        if (self.activityCount > 0) {
            self.activityCount -= 1;
        }
        if (self.activityCount == 0) {
            [self.activityIndicator stopAnimating];
        }
    }
}

@end
