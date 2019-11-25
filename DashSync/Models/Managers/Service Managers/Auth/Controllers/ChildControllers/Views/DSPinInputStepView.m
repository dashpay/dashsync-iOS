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

#import "DSPinInputStepView.h"

#import "DSPinField.h"
#import "UIColor+DSStyle.h"

NS_ASSUME_NONNULL_BEGIN

static CGFloat const LABELS_PIN_PADDING = 26.0;
static CGFloat const TITLE_MESSAGE_SPACING = 16.0;

@interface DSPinInputStepView ()

@property (readonly, nonatomic, strong) UILabel *titleLabel;
@property (readonly, nonatomic, strong) UILabel *messageLabel;

@end

@implementation DSPinInputStepView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.backgroundColor = [UIColor clearColor];

        UILabel *titleLabel = [[UILabel alloc] init];
        titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        titleLabel.adjustsFontForContentSizeCategory = YES;
        titleLabel.numberOfLines = 0;
        titleLabel.backgroundColor = self.backgroundColor;
        titleLabel.textColor = [UIColor ds_labelColorForMode:DSAppearanceMode_Automatic];
        titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
        titleLabel.textAlignment = NSTextAlignmentCenter;
        titleLabel.adjustsFontSizeToFitWidth = YES;
        titleLabel.minimumScaleFactor = 0.5;
        titleLabel.hidden = YES;
        _titleLabel = titleLabel;

        UILabel *messageLabel = [[UILabel alloc] init];
        messageLabel.translatesAutoresizingMaskIntoConstraints = NO;
        messageLabel.adjustsFontForContentSizeCategory = YES;
        messageLabel.numberOfLines = 0;
        messageLabel.backgroundColor = self.backgroundColor;
        messageLabel.textColor = [UIColor ds_labelColorForMode:DSAppearanceMode_Automatic];
        messageLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
        messageLabel.textAlignment = NSTextAlignmentCenter;
        messageLabel.adjustsFontSizeToFitWidth = YES;
        messageLabel.minimumScaleFactor = 0.5;
        messageLabel.hidden = YES;
        _messageLabel = messageLabel;

        UIStackView *stackView = [[UIStackView alloc] initWithArrangedSubviews:@[ titleLabel, messageLabel ]];
        stackView.translatesAutoresizingMaskIntoConstraints = NO;
        stackView.axis = UILayoutConstraintAxisVertical;
        stackView.alignment = UIStackViewAlignmentCenter;
        stackView.spacing = TITLE_MESSAGE_SPACING;
        [self addSubview:stackView];

        DSPinField *pinField = [[DSPinField alloc] initWithStyle:DSPinFieldStyle_Small];
        pinField.backgroundColor = self.backgroundColor;
        pinField.translatesAutoresizingMaskIntoConstraints = NO;
        pinField.keyboardType = UIKeyboardTypeNumberPad;
        [self addSubview:pinField];
        _pinField = pinField;

        [NSLayoutConstraint activateConstraints:@[
            [stackView.topAnchor constraintEqualToAnchor:self.topAnchor],
            [stackView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [stackView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],

            [pinField.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [pinField.topAnchor constraintEqualToAnchor:stackView.bottomAnchor
                                               constant:LABELS_PIN_PADDING],
            [pinField.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        ]];
    }
    return self;
}

- (nullable NSString *)titleText {
    return self.titleLabel.text;
}

- (void)setTitleText:(nullable NSString *)titleText {
    self.titleLabel.text = titleText;
    self.titleLabel.hidden = titleText.length == 0;
    
    [self setNeedsLayout];
}

- (nullable NSString *)messageText {
    return self.messageLabel.text;
}

- (void)setMessageText:(nullable NSString *)messageText {
    self.messageLabel.text = messageText;
    self.messageLabel.hidden = messageText.length == 0;
    
    [self setNeedsLayout];
}

@end

NS_ASSUME_NONNULL_END
