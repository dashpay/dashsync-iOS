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

#import "DSSetPinViewController.h"

#import "DSAuthenticationManager+Private.h"
#import "DSTwoPagePinViewController.h"
#import "NSDate+Utils.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSSetPinViewController () <DSTwoPagePinViewControllerDelegate>

@property (readonly, nonatomic, strong) DSTwoPagePinViewController *pinController;
@property (nonatomic, assign) BOOL shouldVerifyOldPin;
@property (nullable, nonatomic, copy) void (^completion)(BOOL success);

// Internal view of DWAlertController
@property (readonly, nonatomic) UIView *alertView;

@end

@implementation DSSetPinViewController

/*
 How it works:
 
 There are two pages with pin inputs to operate with.
 
 If we have to verify pin first page will be used for verification and once verification is succeeded OR
 we don't have to verify pin:
 
 Second page is used for "Set PIN" and first page is used(reused) for "Confirm PIN".
 
 [1: Enter old PIN] [2: Set PIN] -> [1: Confirm PIN] [2: Set PIN]
 
 */

- (instancetype)initWithCompletion:(void (^)(BOOL success))completion {
    DSTwoPagePinViewController *controller = [[DSTwoPagePinViewController alloc] init];

    NSString *currentPin = [[DSAuthenticationManager sharedInstance] getPin:nil];
    const BOOL shouldVerifyOldPin = currentPin.length == PIN_LENGTH;
    if (shouldVerifyOldPin) {
        controller.firstTitleText = [self.class defaultTitle];
        controller.firstMessageText = DSLocalizedString(@"Enter old PIN", nil);
    }
    else {
        [controller setSecondPageVisible];
        controller.firstTitleText = NSLocalizedString(@"Confirm PIN", nil);
    }

    controller.secondTitleText = NSLocalizedString(@"Set PIN", nil);

    self = [super initWithContentController:controller];
    if (self) {
        _pinController = controller;
        _pinController.delegate = self;

        _shouldVerifyOldPin = shouldVerifyOldPin;
        _completion = [completion copy];

        self.alertIfLockout = YES;

        __weak typeof(self) weakSelf = self;
        DWAlertAction *cancelAction = [DWAlertAction
            actionWithTitle:DSLocalizedString(@"Cancel", nil)
                      style:DWAlertActionStyleCancel
                    handler:^(DWAlertAction *_Nonnull action) {
                        __strong typeof(weakSelf) strongSelf = weakSelf;
                        if (!strongSelf) {
                            return;
                        }

                        [strongSelf cancel];
                    }];
        [self addAction:cancelAction];
    }
    return self;
}

#pragma mark - Private

// Internal view of DWAlertController
@dynamic alertView;

- (void)cancel {
    [self doneSuccess:NO];
}

- (void)doneSuccess:(BOOL)success {
    void (^completion)(BOOL) = [self.completion copy];
    self.completion = nil;
    NSParameterAssert(completion);

    [self dismissViewControllerAnimated:YES
                             completion:^{
                                 if (completion) {
                                     completion(success);
                                 }
                             }];
}

#pragma mark - DSTwoPagePinViewControllerDelegate

- (void)twoPagePinViewController:(DSTwoPagePinViewController *)controller
    didFinishInputFirstPageWithPin:(NSString *)inputPin {
    if (self.shouldVerifyOldPin) {
        [self performPinVerificationAgainstCurrentPin:inputPin];
    }
    else {
        NSString *firstPin = controller.secondPin;
        NSString *secondPin = inputPin;
        if ([firstPin isEqualToString:secondPin]) {
            DSAuthenticationManager *authManager = [DSAuthenticationManager sharedInstance];
            [authManager setPin:secondPin];

            authManager.usesAuthentication = YES;
            authManager.didAuthenticate = YES;
            [[NSUserDefaults standardUserDefaults] setDouble:[NSDate timeIntervalSince1970]
                                                      forKey:PIN_UNLOCK_TIME_KEY];

            [self doneSuccess:YES];
        }
        else {
            [controller secondClear];

            [controller firstClearAndShakePin:^{
                [controller switchFromFirstToSecondAnimation:DSTwoPagePinAnimationDirection_Backward
                                                  completion:nil];
            }];
        }
    }
}

- (void)twoPagePinViewController:(DSTwoPagePinViewController *)controller
    didFinishInputSecondPageWithPin:(NSString *)inputPin {
    [controller switchFromSecondToFirstAnimation:DSTwoPagePinAnimationDirection_Forward completion:nil];
}

#pragma mark - DSBasePinViewController

- (void)pinVerificationDidFail {
    [self.pinController firstClearAndShakePin:^{
    }];
}

- (void)pinVerificationDidFinishWithAuthenticated:(BOOL)authenticated
                                        cancelled:(BOOL)cancelled
                                    shouldLockOut:(BOOL)shouldLockOut {
    [super pinVerificationDidFinishWithAuthenticated:authenticated
                                           cancelled:cancelled
                                       shouldLockOut:shouldLockOut];

    if (authenticated) {
        self.shouldVerifyOldPin = NO;

        DSAuthenticationManager *authManager = [DSAuthenticationManager sharedInstance];
        authManager.didAuthenticate = NO;

        DSTwoPagePinViewController *controller = self.pinController;

        [controller switchFromFirstToSecondAnimation:DSTwoPagePinAnimationDirection_Forward
                                          completion:^{
                                              controller.firstTitleText = NSLocalizedString(@"Confirm PIN", nil);
                                              controller.firstMessageText = nil;
                                              [controller firstClear];

                                              // Light hack on DWAlertController to force update its layout
                                              // since height of DSTwoPagePinViewController has been changed
                                              [UIView animateWithDuration:0.1
                                                               animations:^{
                                                                   [self.alertView setNeedsLayout];
                                                                   [self.alertView layoutIfNeeded];
                                                                   [self.view layoutIfNeeded];
                                                               }];
                                          }];
    }
    else {
        void (^completion)(BOOL success) = [self.completion copy];
        self.completion = nil;
        NSParameterAssert(completion);

        [self dismissViewControllerAnimated:YES
                                 completion:^{
                                     if (shouldLockOut) {
                                         DSAuthenticationManager *authManager = [DSAuthenticationManager sharedInstance];
                                         [authManager userLockedOut];
                                     }

                                     if (completion) {
                                         completion(NO);
                                     }
                                 }];
    }
}

@end

NS_ASSUME_NONNULL_END
