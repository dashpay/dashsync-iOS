//  
//  Created by Andrew Podkovyrin
//  Copyright © 2020 Dash Core Group. All rights reserved.
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

#import <Foundation/Foundation.h>
#import <LocalAuthentication/LocalAuthentication.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, DSBiometricsAuthenticationResult) {
    DSBiometricsAuthenticationResultSucceeded,
    DSBiometricsAuthenticationResultFailed,
    DSBiometricsAuthenticationResultCancelled,
};

@interface DSBiometricsAuthenticator : NSObject

@property (readonly, class, nonatomic, getter=isBiometricsAuthenticationEnabled) BOOL biometricsAuthenticationEnabled;
@property (readonly, class, nonatomic, getter=isPasscodeEnabled) BOOL passcodeEnabled;
@property (readonly, class, nonatomic, getter=isTouchIDEnabled) BOOL touchIDEnabled;
@property (readonly, class, nonatomic, getter=isFaceIDEnabled) BOOL faceIDEnabled;
@property (readonly, class, nonatomic) LABiometryType biometryType API_AVAILABLE(macos(10.13.2), ios(11.0)) API_UNAVAILABLE(watchos, tvos);

+ (void)performBiometricsAuthenticationWithReason:(NSString *)reason
                                    fallbackTitle:(nullable NSString *)fallbackTitle
                                       completion:(void(^)(DSBiometricsAuthenticationResult result))completion;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
