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

#import "DSRequestPinViewController.h"

#import "DSAuthenticationManager+Private.h"
#import "DSSinglePagePinViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSRequestPinViewController () <DSSinglePagePinViewControllerDelegate>

@property (readonly, nonatomic, strong) DSSinglePagePinViewController *pinController;
@property (nullable, nonatomic, copy) PinCompletionBlock completion;

@end

@implementation DSRequestPinViewController

- (instancetype)initWihtAuthPrompt:(nullable NSString *)authPrompt
                    alertIfLockout:(BOOL)alertIfLockout
                        completion:(PinCompletionBlock)completion {
    DSSinglePagePinViewController *pinController = [[DSSinglePagePinViewController alloc] init];
    pinController.titleText = [self.class defaultTitle];
    pinController.messageText = authPrompt;

    self = [super initWithContentController:pinController];
    if (self) {
        _pinController = pinController;
        _pinController.delegate = self;

        _completion = [completion copy];

        self.alertIfLockout = alertIfLockout;

        __weak typeof(self) weakSelf = self;
        DWAlertAction *cancelAction = [DWAlertAction
            actionWithTitle:DSLocalizedString(@"Cancel", nil)
                      style:DWAlertActionStyleCancel
                    handler:^(DWAlertAction *_Nonnull action) {
                        __strong typeof(weakSelf) strongSelf = weakSelf;
                        if (!strongSelf) {
                            return;
                        }

                        [strongSelf pinVerificationDidFinishWithAuthenticated:NO
                                                                    cancelled:YES
                                                                shouldLockOut:NO];
                    }];
        [self addAction:cancelAction];
    }
    return self;
}

#pragma mark - DSSinglePagePinViewControllerDelegate

- (void)singlePagePinViewController:(DSSinglePagePinViewController *)controller
              didFinishInputWithPin:(NSString *)inputPin {
    [self performPinVerificationAgainstCurrentPin:inputPin];
}

#pragma mark - DSBasePinViewController

- (void)pinVerificationDidFail {
    [self.pinController clearAndShakePin];
}

- (void)pinVerificationDidFinishWithAuthenticated:(BOOL)authenticated
                                        cancelled:(BOOL)cancelled
                                    shouldLockOut:(BOOL)shouldLockOut {
    [super pinVerificationDidFinishWithAuthenticated:authenticated
                                           cancelled:cancelled
                                       shouldLockOut:shouldLockOut];

    PinCompletionBlock completion = [self.completion copy];
    self.completion = nil;
    NSParameterAssert(completion);

    [self dismissViewControllerAnimated:YES
                             completion:^{
                                 if (shouldLockOut) {
                                     DSAuthenticationManager *authManager = [DSAuthenticationManager sharedInstance];
                                     [authManager userLockedOut];
                                 }

                                 if (completion) {
                                     completion(authenticated, cancelled);
                                 }
                             }];
}

@end

NS_ASSUME_NONNULL_END
