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

#import "NSColor+DSStyle.h"

NS_ASSUME_NONNULL_BEGIN

static inline NSColor *ColorFromHEXAlpha(NSUInteger hexValue, CGFloat alpha) {
    return [NSColor colorWithRed:((hexValue & 0xFF0000) >> 16) / 255.0
                           green:((hexValue & 0xFF00) >> 8) / 255.0
                            blue:(hexValue & 0xFF) / 255.0
                           alpha:(CGFloat)(alpha)];
}

static inline NSColor *ColorFromHEX(NSUInteger hexValue) {
    return ColorFromHEXAlpha(hexValue, 1.0);
}

@implementation NSColor (DSStyle)

+ (NSColor *)ds_dashBlueColor {
    return ColorFromHEX(0x008DE4);
}

+ (NSColor *)ds_labelColorForMode:(DSAppearanceMode)appearanceMode {
    if (@available(iOS 13.0, *)) {
        return [NSColor labelColor];
    } else {
        if (appearanceMode == DSAppearanceMode_Dark) {
            return [NSColor whiteColor];
        } else {
            return [NSColor blackColor];
        }
    }
}

+ (NSColor *)ds_pinBackgroundColor {
    return ColorFromHEX(0xD8D8D8);
}

+ (NSColor *)ds_pinLockScreenBackgroundColor {
    return [NSColor whiteColor];
}

+ (NSColor *)ds_pinInputDotColor {
    return [NSColor whiteColor];
}

+ (NSColor *)ds_passphraseBackgroundColorForMode:(DSAppearanceMode)appearanceMode {
    if (appearanceMode == DSAppearanceMode_Dark) {
        return [NSColor blackColor];
    } else {
        return [NSColor whiteColor];
    }
}

@end

NS_ASSUME_NONNULL_END
