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

#import "TextViewFormTableViewCell.h"

#import "PlaceholderTextView.h"

NS_ASSUME_NONNULL_BEGIN

@interface TextViewFormTableViewCell () <UITextViewDelegate>

@property (strong, nonatomic) IBOutlet UILabel *titleLabel;
@property (strong, nonatomic) IBOutlet PlaceholderTextView *textView;

@end

@implementation TextViewFormTableViewCell

- (void)awakeFromNib {
    [super awakeFromNib];

    self.textView.textContainerInset = UIEdgeInsetsZero;
    self.textView.textContainer.lineFragmentPadding = 0.0;

    [self mvvm_observe:@"cellModel.title"
                  with:^(typeof(self) self, NSString *value) {
                      self.titleLabel.text = value;
                  }];

    [self mvvm_observe:@"cellModel.placeholder"
                  with:^(typeof(self) self, NSString *value) {
                      self.textView.placeholderText = value;
                  }];

    [self mvvm_observe:@"cellModel.text"
                  with:^(typeof(self) self, NSString *value) {
                      self.textView.text = value;
                  }];
}

- (void)setCellModel:(nullable TextViewFormCellModel *)cellModel {
    _cellModel = cellModel;

    self.textView.autocapitalizationType = cellModel.autocapitalizationType;
    self.textView.autocorrectionType = cellModel.autocorrectionType;
    self.textView.keyboardType = cellModel.keyboardType;
    self.textView.returnKeyType = cellModel.returnKeyType;
    self.textView.enablesReturnKeyAutomatically = cellModel.enablesReturnKeyAutomatically;
    self.textView.secureTextEntry = cellModel.secureTextEntry;
}

#pragma mark - TextInputFormTableViewCell

- (void)textInputBecomeFirstResponder {
    [self.textView becomeFirstResponder];
}

#pragma mark - UITextViewDelegate

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    BOOL allowed = [self.cellModel validateReplacementString:text text:textView.text];
    if (!allowed) {
        return NO;
    }

    self.cellModel.text = [textView.text stringByReplacingCharactersInRange:range withString:text];
    if (self.cellModel.didChangeValueBlock) {
        self.cellModel.didChangeValueBlock(self.cellModel);
    }

    return NO;
}

@end

NS_ASSUME_NONNULL_END
