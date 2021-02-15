//
//  Created by Andrew Podkovyrin
//  Copyright © 2018 Dash Core Group. All rights reserved.
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

#import "TextFieldFormTableViewCell.h"

NS_ASSUME_NONNULL_BEGIN

@interface TextFieldFormTableViewCell () <UITextFieldDelegate>

@property (strong, nonatomic) IBOutlet UILabel *titleLabel;
@property (strong, nonatomic) IBOutlet UITextField *textField;

@end

@implementation TextFieldFormTableViewCell

- (void)awakeFromNib {
    [super awakeFromNib];

    [self mvvm_observe:@"cellModel.title"
                  with:^(typeof(self) self, NSString *value) {
                      self.titleLabel.text = value;
                  }];

    [self mvvm_observe:@"cellModel.placeholder"
                  with:^(typeof(self) self, NSString *value) {
                      self.textField.placeholder = value;
                  }];

    [self mvvm_observe:@"cellModel.text"
                  with:^(typeof(self) self, NSString *value) {
                      self.textField.text = value;
                  }];
}

- (void)setCellModel:(nullable TextFieldFormCellModel *)cellModel {
    _cellModel = cellModel;

    self.textField.autocapitalizationType = cellModel.autocapitalizationType;
    self.textField.autocorrectionType = cellModel.autocorrectionType;
    self.textField.keyboardType = cellModel.keyboardType;
    self.textField.returnKeyType = cellModel.returnKeyType;
    self.textField.enablesReturnKeyAutomatically = cellModel.enablesReturnKeyAutomatically;
    self.textField.secureTextEntry = cellModel.secureTextEntry;
}

#pragma mark - TextInputFormTableViewCell

- (void)textInputBecomeFirstResponder {
    [self.textField becomeFirstResponder];
}

#pragma mark UITextFieldDelegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    BOOL allowed = [self.cellModel validateReplacementString:string text:textField.text];
    if (!allowed) {
        return NO;
    }

    self.cellModel.text = [textField.text stringByReplacingCharactersInRange:range withString:string];
    if (self.cellModel.didChangeValueBlock) {
        self.cellModel.didChangeValueBlock(self.cellModel);
    }

    return NO;
}

- (BOOL)textFieldShouldClear:(UITextField *)textField {
    self.cellModel.text = @"";
    if (self.cellModel.didChangeValueBlock) {
        self.cellModel.didChangeValueBlock(self.cellModel);
    }

    return NO;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField.returnKeyType == UIReturnKeyNext) {
        [self.delegate textFieldFormTableViewCellActivateNextFirstResponder:self];
    } else if (textField.returnKeyType == UIReturnKeyDone) {
        [self endEditing:YES];
    }

    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField reason:(UITextFieldDidEndEditingReason)reason {
    if (reason == UITextFieldDidEndEditingReasonCommitted && self.cellModel.didReturnValueBlock) {
        self.cellModel.didReturnValueBlock(self.cellModel);
    }
}

@end

NS_ASSUME_NONNULL_END
