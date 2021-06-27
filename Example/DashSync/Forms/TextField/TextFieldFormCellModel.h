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

#import <UIKit/UIKit.h>

#import "BaseFormCellModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface TextFieldFormCellModel : BaseFormCellModel

@property (nullable, copy, nonatomic) NSString *placeholder;
@property (nullable, copy, nonatomic) NSString *text;

@property (nullable, copy, nonatomic) void (^didChangeValueBlock)(TextFieldFormCellModel *cellModel);
@property (nullable, copy, nonatomic) void (^didReturnValueBlock)(TextFieldFormCellModel *cellModel);

// Some of UITextInputTraits protocol params
@property (assign, nonatomic) UITextAutocapitalizationType autocapitalizationType;
@property (assign, nonatomic) UITextAutocorrectionType autocorrectionType;
@property (assign, nonatomic) UIKeyboardType keyboardType;
@property (assign, nonatomic) UIReturnKeyType returnKeyType;
@property (assign, nonatomic) BOOL enablesReturnKeyAutomatically;
@property (assign, nonatomic, getter=isSecureTextEntry) BOOL secureTextEntry;

- (instancetype)initWithTitle:(nullable NSString *)title placeholder:(nullable NSString *)placeholder NS_DESIGNATED_INITIALIZER;

- (BOOL)validateReplacementString:(NSString *)string text:(nullable NSString *)text;

@end

NS_ASSUME_NONNULL_END
