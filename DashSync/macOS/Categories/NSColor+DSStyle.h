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

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, DSAppearanceMode)
{
    /// Follows Dark Mode setting on iOS 13, uses the light appearance mode on iOS 12 or lower
    DSAppearanceMode_Automatic,
    /// The light appearance mode
    DSAppearanceMode_Light,
    /// The dark appearance mode
    DSAppearanceMode_Dark,
};

@interface NSColor (DSStyle)

+ (NSColor *)ds_dashBlueColor;

+ (NSColor *)ds_labelColorForMode:(DSAppearanceMode)appearanceMode;

+ (NSColor *)ds_pinBackgroundColor;
+ (NSColor *)ds_pinLockScreenBackgroundColor;
+ (NSColor *)ds_pinInputDotColor;

+ (NSColor *)ds_passphraseBackgroundColorForMode:(DSAppearanceMode)appearanceMode;

@end

NS_ASSUME_NONNULL_END
