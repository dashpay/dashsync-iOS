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

#import "DSTwoPagePinViewController.h"

#import "DSPinField.h"
#import "DSPinInputStepView.h"
#import "UIView+DSAnimations.h"
#import "UIView+DSFindConstraint.h"

NS_ASSUME_NONNULL_BEGIN

static NSTimeInterval const ANIMATION_DURATION = 0.35;
static CGFloat const ANIMATION_SPRING_DAMPING = 1.0;
static CGFloat const ANIMATION_INITIAL_VELOCITY = 0.0;
static UIViewAnimationOptions const ANIMATION_OPTIONS = UIViewAnimationOptionCurveEaseOut;

@interface DSTwoPagePinViewController () <DSPinFieldDelegate>

@property (null_resettable, nonatomic, strong) DSPinInputStepView *firstPinView;
@property (null_resettable, nonatomic, strong) DSPinInputStepView *secondPinView;

@property (null_resettable, nonatomic, strong) UINotificationFeedbackGenerator *feedbackGenerator;

@end

@implementation DSTwoPagePinViewController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    // `becomeFirstResponder` will be called after `viewDidLayoutSubviews` but before `viewDidAppear:`
    // Assigning first responder in `viewWillAppear:` is too early and in `viewDidAppear:` is too late
    dispatch_async(dispatch_get_main_queue(), ^{
        [self activatePinView];
    });
}

- (nullable NSString *)firstTitleText {
    return self.firstPinView.titleText;
}

- (void)setFirstTitleText:(nullable NSString *)firstTitleText {
    self.firstPinView.titleText = firstTitleText;
    [self.view setNeedsLayout];
}

- (nullable NSString *)firstMessageText {
    return self.firstPinView.messageText;
}

- (void)setFirstMessageText:(nullable NSString *)firstMessageText {
    self.firstPinView.messageText = firstMessageText;
    [self.view setNeedsLayout];
}

- (nullable NSString *)secondTitleText {
    return self.secondPinView.titleText;
}

- (void)setSecondTitleText:(nullable NSString *)secondTitleText {
    self.secondPinView.titleText = secondTitleText;
    [self.view setNeedsLayout];
}

- (nullable NSString *)secondMessageText {
    return self.secondPinView.messageText;
}

- (void)setSecondMessageText:(nullable NSString *)secondMessageText {
    self.secondPinView.messageText = secondMessageText;
    [self.view setNeedsLayout];
}

- (NSString *)firstPin {
    return self.firstPinView.pinField.text;
}

- (NSString *)secondPin {
    return self.secondPinView.pinField.text;
}

- (void)firstClearAndShakePin:(void (^)(void))completion {
    [self clearAndShakePinView:self.firstPinView completion:completion];
}

- (void)secondClearAndShakePin:(void (^)(void))completion {
    [self clearAndShakePinView:self.secondPinView completion:completion];
}

- (void)switchFromFirstToSecondAnimation:(DSTwoPagePinAnimationDirection)animationDirection
                              completion:(void (^_Nullable)(void))completion {
    [self switchFromPinView:self.firstPinView
                  toPinView:self.secondPinView
         animationDirection:animationDirection
                 completion:completion];
}

- (void)switchFromSecondToFirstAnimation:(DSTwoPagePinAnimationDirection)animationDirection
                              completion:(void (^_Nullable)(void))completion {
    [self switchFromPinView:self.secondPinView
                  toPinView:self.firstPinView
         animationDirection:animationDirection
                 completion:completion];
}

- (void)firstClear {
    [self.firstPinView.pinField clear];
}

- (void)secondClear {
    [self.secondPinView.pinField clear];
}

- (void)setSecondPageVisible {
    self.firstPinView.hidden = YES;
    self.secondPinView.hidden = NO;
}

#pragma mark - Private

- (DSPinInputStepView *)firstPinView {
    if (_firstPinView == nil) {
        _firstPinView = [self createAndAddNewPinView];
    }

    return _firstPinView;
}

- (DSPinInputStepView *)secondPinView {
    if (_secondPinView == nil) {
        _secondPinView = [self createAndAddNewPinView];
        _secondPinView.hidden = YES;
    }

    return _secondPinView;
}

- (UINotificationFeedbackGenerator *)feedbackGenerator {
    if (_feedbackGenerator == nil) {
        _feedbackGenerator = [[UINotificationFeedbackGenerator alloc] init];
        [_feedbackGenerator prepare];
    }

    return _feedbackGenerator;
}

- (void)clearAndShakePinView:(DSPinInputStepView *)pinView completion:(void (^)(void))completion {
    [pinView.pinField clear];
    [pinView.pinField ds_shakeViewWithCompletion:completion];

    [self.feedbackGenerator notificationOccurred:UINotificationFeedbackTypeError];
    [self.feedbackGenerator prepare];
}

- (void)activatePinView {
    NSAssert(self.firstPinView.hidden || self.secondPinView.hidden, @"Inconsistent state");

    if (self.secondPinView.hidden) {
        [self.firstPinView.pinField becomeFirstResponder];
    }
    else {
        [self.secondPinView.pinField becomeFirstResponder];
    }
}

- (DSPinInputStepView *)createAndAddNewPinView {
    DSPinInputStepView *pinView = [[DSPinInputStepView alloc] initWithFrame:CGRectZero];
    pinView.translatesAutoresizingMaskIntoConstraints = NO;
    pinView.pinField.delegate = self;
    [self.view addSubview:pinView];

    [NSLayoutConstraint activateConstraints:@[
        [pinView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [pinView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [pinView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [pinView.widthAnchor constraintEqualToAnchor:self.view.widthAnchor],
    ]];

    return pinView;
}

- (void)switchFromPinView:(DSPinInputStepView *)fromPinView
                toPinView:(DSPinInputStepView *)toPinView
       animationDirection:(DSTwoPagePinAnimationDirection)animationDirection
               completion:(void (^_Nullable)(void))completion {
    NSAssert(toPinView.hidden, @"Inconsistent state");

    fromPinView.pinField.inputEnabled = NO;
    toPinView.pinField.inputEnabled = NO;

    NSLayoutConstraint *fromLeadingConstraint =
        [fromPinView ds_findContraintForAttribute:NSLayoutAttributeLeading];
    NSLayoutConstraint *toLeadingConstraint =
        [toPinView ds_findContraintForAttribute:NSLayoutAttributeLeading];

    const CGFloat width = self.view.bounds.size.width;
    toLeadingConstraint.constant =
        animationDirection == DSTwoPagePinAnimationDirection_Forward ? width : -width;
    [self.view layoutIfNeeded];
    toPinView.hidden = NO;

    [fromPinView.pinField resignFirstResponder];
    [toPinView.pinField becomeFirstResponder];

    fromLeadingConstraint.constant =
        animationDirection == DSTwoPagePinAnimationDirection_Forward ? -width : width;
    toLeadingConstraint.constant = 0;

    [UIView animateWithDuration:ANIMATION_DURATION
        delay:0.0
        usingSpringWithDamping:ANIMATION_SPRING_DAMPING
        initialSpringVelocity:ANIMATION_INITIAL_VELOCITY
        options:ANIMATION_OPTIONS
        animations:^{
            [self.view layoutIfNeeded];
        }
        completion:^(BOOL finished) {
            fromPinView.pinField.inputEnabled = YES;
            toPinView.pinField.inputEnabled = YES;

            fromPinView.hidden = YES;

            [self.feedbackGenerator prepare];

            if (completion) {
                completion();
            }
        }];
}

#pragma mark - DSPinFieldDelegate

- (void)pinFieldDidFinishInput:(DSPinField *)pinField {
    if (self.firstPinView.pinField == pinField) {
        [self.delegate twoPagePinViewController:self didFinishInputFirstPageWithPin:pinField.text];
    }
    else {
        [self.delegate twoPagePinViewController:self didFinishInputSecondPageWithPin:pinField.text];
    }
}

@end

NS_ASSUME_NONNULL_END
