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

#import "UIColor+DSStyle.h"

NS_ASSUME_NONNULL_BEGIN

static inline UIColor *ColorFromHEXAlpha(NSUInteger hexValue, CGFloat alpha) {
    return [UIColor colorWithRed:((hexValue & 0xFF0000) >> 16) / 255.0
                           green:((hexValue & 0xFF00) >> 8) / 255.0
                            blue:(hexValue & 0xFF) / 255.0
                           alpha:(CGFloat)(alpha)];
}

static inline UIColor *ColorFromHEX(NSUInteger hexValue) {
    return ColorFromHEXAlpha(hexValue, 1.0);
}

@implementation UIColor (DSStyle)

+ (UIColor *)ds_dashBlueColor {
    return ColorFromHEX(0x008DE4);
}

+ (UIColor *)ds_labelColorForMode:(DSAppearanceMode)appearanceMode {
    return [UIColor labelColor];
}

+ (UIColor *)ds_pinBackgroundColor {
    return ColorFromHEX(0xD8D8D8);
}

+ (UIColor *)ds_pinLockScreenBackgroundColor {
    return [UIColor whiteColor];
}

+ (UIColor *)ds_pinInputDotColor {
    return [UIColor whiteColor];
}

+ (UIColor *)ds_passphraseBackgroundColorForMode:(DSAppearanceMode)appearanceMode {
    return [UIColor systemBackgroundColor];
}

@end

NS_ASSUME_NONNULL_END
