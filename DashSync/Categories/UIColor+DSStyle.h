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

// for iOS 12 or lower Dark Mode is not supported for now (since it requires it's manual support)

typedef NS_ENUM(NSInteger, DSAppearanceMode) {
    /// Follows Dark Mode setting on iOS 13, uses the light appearance mode on iOS 12 or lower
    DSAppearanceMode_Automatic,
    /// The light appearance mode
    DSAppearanceMode_Light,
    /// The dark appearance mode
    DSAppearanceMode_Dark,
};

@interface UIColor (DSStyle)

+ (UIColor *)ds_dashBlueColor;

+ (UIColor *)ds_labelColorForMode:(DSAppearanceMode)appearanceMode;

+ (UIColor *)ds_pinBackgroundColor;
+ (UIColor *)ds_pinLockScreenBackgroundColor;
+ (UIColor *)ds_pinInputDotColor;

+ (UIColor *)ds_passphraseBackgroundColorForMode:(DSAppearanceMode)appearanceMode;

@end

NS_ASSUME_NONNULL_END
