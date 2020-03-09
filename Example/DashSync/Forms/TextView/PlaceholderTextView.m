//
//  Created by Andrew Podkovyrin
//  Copyright © 2018 dashfoundation. All rights reserved.
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

#import "PlaceholderTextView.h"

NS_ASSUME_NONNULL_BEGIN

@implementation PlaceholderTextView

- (instancetype)initWithFrame:(CGRect)frame textContainer:(nullable NSTextContainer *)textContainer {
    self = [super initWithFrame:frame textContainer:textContainer];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(setNeedsDisplay)
                                                     name:UITextViewTextDidChangeNotification
                                                   object:self];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (nullable NSString *)placeholderText {
    return self.attributedPlaceholderText.string;
}

- (void)setPlaceholderText:(nullable NSString *)placeholderText {
    if (!placeholderText) {
        self.attributedPlaceholderText = nil;

        return;
    }

    if ([self.attributedPlaceholderText.string isEqualToString:placeholderText]) {
        return;
    }

    NSMutableDictionary<NSString *, id> *attributes = nil;
    if (self.isFirstResponder) {
        attributes = [self.typingAttributes mutableCopy];
    }
    else {
        attributes = [@{
            NSFontAttributeName : self.font ?: [UIFont systemFontOfSize:14.0],
        } mutableCopy];
    }

    UIColor *color = attributes[NSForegroundColorAttributeName] ?: [UIColor colorWithRed:0.0 green:0.0 blue:0.1 alpha:0.22];
    attributes[NSForegroundColorAttributeName] = [color colorWithAlphaComponent:0.22];

    self.attributedPlaceholderText = [[NSAttributedString alloc] initWithString:placeholderText attributes:attributes];
}

- (void)setAttributedPlaceholderText:(nullable NSAttributedString *)attributedPlaceholderText {
    _attributedPlaceholderText = attributedPlaceholderText;

    [self setNeedsDisplay];
}

#pragma mark UITextView

- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];

    if (self.attributedPlaceholderText && [self shouldDrawPlaceholder]) {
        CGRect placeholderRect = [self placeholderRect];
        [self.attributedPlaceholderText drawInRect:placeholderRect];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];

    if ([self shouldDrawPlaceholder]) {
        [self setNeedsDisplay];
    }
}

- (void)setText:(nullable NSString *)text {
    [super setText:text];

    [self setNeedsDisplay];
}

- (void)setAttributedText:(nullable NSAttributedString *)attributedText {
    [super setAttributedText:attributedText];

    [self setNeedsDisplay];
}

- (void)insertText:(NSString *)text {
    [super insertText:text];

    [self setNeedsDisplay];
}

- (void)setContentInset:(UIEdgeInsets)contentInset {
    [super setContentInset:contentInset];

    [self setNeedsDisplay];
}

#pragma mark Private

- (CGRect)placeholderRect {
    CGRect contentRect = UIEdgeInsetsInsetRect(self.bounds, self.contentInset);
    CGRect rect = UIEdgeInsetsInsetRect(contentRect, self.textContainerInset);
    CGFloat padding = self.textContainer.lineFragmentPadding;
    rect.origin.x += padding;
    rect.size.width -= padding * 2.0;
    return rect;
}

- (BOOL)shouldDrawPlaceholder {
    return !self.text || self.text.length == 0;
}

@end

NS_ASSUME_NONNULL_END
