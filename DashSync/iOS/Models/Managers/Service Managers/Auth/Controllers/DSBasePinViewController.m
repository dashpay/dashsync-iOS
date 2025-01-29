//
//  Created by Andrew Podkovyrin
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

#import "DSBasePinViewController.h"

#import "DSAuthenticationManager+Private.h"
#import "DSPriceManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSBasePinViewController ()

@end

@implementation DSBasePinViewController

+ (NSString *)defaultTitle {
    return DSLocalizedFormat(@"PIN for %@", nil, DISPLAY_NAME);
//    return [NSString stringWithFormat:DSLocalizedString(@"PIN for %@", nil), DISPLAY_NAME];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self
                           selector:@selector(applicationWillResignActiveNotification)
                               name:UIApplicationWillResignActiveNotification
                             object:nil];
}

- (void)performPinVerificationAgainstCurrentPin:(NSString *)inputPin {
    DSAuthenticationManager *authManager = [DSAuthenticationManager sharedInstance];
    [authManager
        performPinVerificationAgainstCurrentPin:inputPin
                                     completion:^(BOOL allowedNextVerificationRound,
                                         BOOL authenticated,
                                         BOOL cancelled,
                                         BOOL shouldLockout) {
                                         if (allowedNextVerificationRound) {
                                             [self pinVerificationDidFail];
                                         } else {
                                             [self pinVerificationDidFinishWithAuthenticated:authenticated
                                                                                   cancelled:cancelled
                                                                               shouldLockOut:shouldLockout];
                                         }
                                     }];
}

- (void)pinVerificationDidFail {
    // clear & shake pin field
}

- (void)pinVerificationDidFinishWithAuthenticated:(BOOL)authenticated
                                        cancelled:(BOOL)cancelled
                                    shouldLockOut:(BOOL)shouldLockOut {
    // Sanity checks
#ifdef DEBUG
    if (authenticated) {
        NSAssert(shouldLockOut == NO, @"Invalid state");
        NSAssert(cancelled == NO, @"Invalid state");
    }

    if (cancelled) {
        NSAssert(authenticated == NO, @"Invalid state");
        NSAssert(shouldLockOut == NO, @"Invalid state");
    }

    if (shouldLockOut) {
        NSAssert(authenticated == NO, @"Invalid state");
        NSAssert(cancelled == NO, @"Invalid state");
    }
#endif
}

#pragma mark - Notifications

- (void)applicationWillResignActiveNotification {
    [self pinVerificationDidFinishWithAuthenticated:NO cancelled:YES shouldLockOut:NO];
}

@end

NS_ASSUME_NONNULL_END
