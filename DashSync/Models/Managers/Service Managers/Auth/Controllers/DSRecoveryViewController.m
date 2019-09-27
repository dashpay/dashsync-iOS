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

#import "DSRecoveryViewController.h"

#import "DashSync.h"

#import "DSPassphraseChildViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSRecoveryViewController () <DSPassphraseChildViewControllerDelegate>

@property (readonly, nonatomic, strong) DSPassphraseChildViewController *passphraseController;
@property (nullable, nonatomic, copy) void (^completion)(BOOL success);
@property (nullable, nonatomic, copy) void (^wipeHandler)(void);

@end

@implementation DSRecoveryViewController

+ (BOOL)canRecoverWallet {
    // TODO: find a way to handle when there are more that one wallet
    DSChain *chain = [[DSChainsManager sharedInstance] mainnetManager].chain;
    return (chain.wallets.count == 1);
}

- (instancetype)initWithWipeHandler:(void (^_Nullable)(void))wipeHandler completion:(void (^)(BOOL success))completion {
    NSAssert([self.class canRecoverWallet], @"Check pre-condition before use");

    DSPassphraseChildViewController *passphraseController = [[DSPassphraseChildViewController alloc] init];

    self = [super initWithContentController:passphraseController];
    if (self) {
        _passphraseController = passphraseController;
        _passphraseController.delegate = self;
        _wipeHandler = [wipeHandler copy];
        _completion = [completion copy];

        __weak typeof(self) weakSelf = self;
        DWAlertAction *cancelAction = [DWAlertAction
            actionWithTitle:DSLocalizedString(@"Cancel", nil)
                      style:DWAlertActionStyleCancel
                    handler:^(DWAlertAction *_Nonnull action) {
                        __strong typeof(weakSelf) strongSelf = weakSelf;
                        if (!strongSelf) {
                            return;
                        }

                        [strongSelf doneSuccess:NO];
                    }];
        [self addAction:cancelAction];

        if (wipeHandler) {
            DWAlertAction *wipeAction = [DWAlertAction
                actionWithTitle:DSLocalizedString(@"OK", nil)
                          style:DWAlertActionStyleDefault
                        handler:^(DWAlertAction *_Nonnull action) {
                            __strong typeof(weakSelf) strongSelf = weakSelf;
                            if (!strongSelf) {
                                return;
                            }

                            [strongSelf wipeAction];
                        }];
            [self addAction:wipeAction];
        }

        DWAlertAction *okAction = [DWAlertAction
            actionWithTitle:DSLocalizedString(@"OK", nil)
                      style:DWAlertActionStyleDefault
                    handler:^(DWAlertAction *_Nonnull action) {
                        __strong typeof(weakSelf) strongSelf = weakSelf;
                        if (!strongSelf) {
                            return;
                        }

                        [strongSelf.passphraseController verifySeedPharse];
                    }];
        [self addAction:okAction];

        self.preferredAction = okAction;
    }
    return self;
}

#pragma mark - DSPassphraseChildViewControllerDelegate

- (void)passphraseChildViewControllerDidVerifySeedPhrase:(DSPassphraseChildViewController *)controller {
    [self doneSuccess:YES];
}

#pragma mark - Private

- (void)doneSuccess:(BOOL)success {
    void (^completion)(BOOL success) = [self.completion copy];
    self.completion = nil;
    self.wipeHandler = nil;
    NSParameterAssert(completion);

    [self dismissViewControllerAnimated:YES
                             completion:^{
                                 if (success) {
                                     [[DSAuthenticationManager sharedInstance] setPinWithCompletion:^(BOOL setPinSuccess) {
                                         if (completion) {
                                             completion(success && setPinSuccess);
                                         }
                                     }];
                                 }
                             }];
}

- (void)wipeAction {
    void (^wipeHandler)(void) = [self.wipeHandler copy];
    self.completion = nil;
    self.wipeHandler = nil;
    NSParameterAssert(wipeHandler);

    [self dismissViewControllerAnimated:YES
                             completion:^{
                                 if (wipeHandler) {
                                     wipeHandler();
                                 }
                             }];
}

@end

NS_ASSUME_NONNULL_END
