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

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class DSPinField;

typedef NS_ENUM(NSUInteger, DSPinFieldStyle)
{
    DSPinFieldStyle_Default,      // 50pt field size
    DSPinFieldStyle_DefaultWhite, // 50pt field size, white bg
    DSPinFieldStyle_Small,        // 44pt
};

@protocol DSPinFieldDelegate <NSObject>

- (void)pinFieldDidFinishInput:(DSPinField *)pinField;

@end

@interface DSPinField : UIView <UITextInput>

@property (nonatomic, assign) BOOL inputEnabled;
@property (nullable, nonatomic, weak) id<DSPinFieldDelegate> delegate;
@property (readonly, nonatomic, copy) NSString *text;

- (void)clear;

- (instancetype)initWithStyle:(DSPinFieldStyle)style;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithFrame:(CGRect)frame NS_UNAVAILABLE;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
