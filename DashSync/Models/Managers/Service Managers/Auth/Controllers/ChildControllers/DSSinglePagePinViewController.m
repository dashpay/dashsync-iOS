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

#import "DSSinglePagePinViewController.h"

#import "DSPinField.h"
#import "DSPinInputStepView.h"
#import "UIView+DSAnimations.h"

NS_ASSUME_NONNULL_BEGIN

@interface DSSinglePagePinViewController () <DSPinFieldDelegate>

@property (null_resettable, nonatomic, strong) DSPinInputStepView *pinView;
@property (null_resettable, nonatomic, strong) UINotificationFeedbackGenerator *feedbackGenerator;

@end

@implementation DSSinglePagePinViewController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    // `becomeFirstResponder` will be called after `viewDidLayoutSubviews` but before `viewDidAppear:`
    // Assigning first responder in `viewWillAppear:` is too early and in `viewDidAppear:` is too late
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.pinView.pinField becomeFirstResponder];
    });
}

- (nullable NSString *)titleText {
    return self.pinView.titleText;
}

- (void)setTitleText:(nullable NSString *)titleText {
    self.pinView.titleText = titleText;
}

- (nullable NSString *)messageText {
    return self.pinView.messageText;
}

- (void)setMessageText:(nullable NSString *)messageText {
    self.pinView.messageText = messageText;
}

- (void)clearAndShakePin {
    [self.pinView.pinField clear];
    [self.pinView.pinField ds_shakeView];

    [self.feedbackGenerator notificationOccurred:UINotificationFeedbackTypeError];
    [self.feedbackGenerator prepare];
}

#pragma mark - Private

- (DSPinInputStepView *)pinView {
    if (_pinView == nil) {
        DSPinInputStepView *pinView = [[DSPinInputStepView alloc] initWithFrame:CGRectZero];
        pinView.translatesAutoresizingMaskIntoConstraints = NO;
        pinView.pinField.delegate = self;
        [self.view addSubview:pinView];
        _pinView = pinView;

        [NSLayoutConstraint activateConstraints:@[
            [pinView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
            [pinView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
            [pinView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
            [pinView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        ]];
    }

    return _pinView;
}

- (UINotificationFeedbackGenerator *)feedbackGenerator {
    if (_feedbackGenerator == nil) {
        _feedbackGenerator = [[UINotificationFeedbackGenerator alloc] init];
        [_feedbackGenerator prepare];
    }

    return _feedbackGenerator;
}

#pragma mark - DSPinFieldDelegate

- (void)pinFieldDidFinishInput:(DSPinField *)pinField {
    [self.delegate singlePagePinViewController:self didFinishInputWithPin:pinField.text];
}

@end

NS_ASSUME_NONNULL_END
