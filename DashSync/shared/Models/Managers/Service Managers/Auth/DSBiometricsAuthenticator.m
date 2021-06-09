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

#import "DSPermissionNotification.h"

#import "DSBiometricsAuthenticator.h"

static LAPolicy const POLICY = LAPolicyDeviceOwnerAuthenticationWithBiometrics;

@implementation DSBiometricsAuthenticator

+ (BOOL)isBiometricsAuthenticationEnabled {
    LAContext *context = [[LAContext alloc] init];
    const BOOL canEvaluatePolicy = [context canEvaluatePolicy:POLICY error:nil];
    return canEvaluatePolicy;
}

+ (BOOL)isPasscodeEnabled {
    LAContext *context = [[LAContext alloc] init];
    NSError *error = nil;
    const BOOL canEvaluatePolicy = [context canEvaluatePolicy:POLICY error:&error];
    if (canEvaluatePolicy) {
        return YES;
    } else {
        return (error && error.code == LAErrorPasscodeNotSet) ? NO : YES;
    }
}

+ (BOOL)isTouchIDEnabled {
    LAContext *context = [[LAContext alloc] init];
    const BOOL canEvaluatePolicy = [context canEvaluatePolicy:POLICY error:nil];

    if (@available(iOS 11.0, *)) {
        return canEvaluatePolicy && context.biometryType == LABiometryTypeTouchID;
    } else {
        return canEvaluatePolicy;
    }
}

+ (BOOL)isFaceIDEnabled {
    LAContext *context = [[LAContext alloc] init];
    const BOOL canEvaluatePolicy = [context canEvaluatePolicy:POLICY error:nil];

    if (@available(iOS 11.0, *)) {
        return canEvaluatePolicy && context.biometryType == LABiometryTypeFaceID;
    } else {
        return canEvaluatePolicy;
    }
}

+ (LABiometryType)biometryType {
    LAContext *context = [[LAContext alloc] init];
    [context canEvaluatePolicy:POLICY error:nil];
    return context.biometryType;
}

+ (void)performBiometricsAuthenticationWithReason:(NSString *)reason
                                    fallbackTitle:(nullable NSString *)fallbackTitle
                                       completion:(void (^)(DSBiometricsAuthenticationResult result))completion {
    [[NSNotificationCenter defaultCenter] postNotificationName:DSWillRequestOSPermissionNotification object:nil];
    
    LAContext *context = [[LAContext alloc] init];
    context.localizedFallbackTitle = fallbackTitle;
    [context evaluatePolicy:POLICY
            localizedReason:reason
                      reply:^(BOOL success, NSError *_Nullable error) {
                          dispatch_async(dispatch_get_main_queue(), ^{
                              [[NSNotificationCenter defaultCenter] postNotificationName:DSDidRequestOSPermissionNotification object:nil];

                              DSBiometricsAuthenticationResult result;
                              if (success) {
                                  result = DSBiometricsAuthenticationResultSucceeded;
                              } else {
                                  const NSInteger code = error.code;
                                  if (code == LAErrorUserCancel || code == LAErrorSystemCancel) {
                                      result = DSBiometricsAuthenticationResultCancelled;
                                  } else {
                                      result = DSBiometricsAuthenticationResultFailed;
                                  }
                              }

                              if (completion) {
                                  completion(result);
                              }
                          });
                      }];
}

@end
