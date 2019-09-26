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

#import "DSAuthenticationManager.h"

NS_ASSUME_NONNULL_BEGIN

// Only 4 digits pin is supported
#define PIN_LENGTH 4

#define ALLOWED_FAIL_COUNT 3

#if DEBUG && 0

#define SPEED_UP_WAIT_TIME 1
#define MAX_FAIL_COUNT 4

#else

#define SPEED_UP_WAIT_TIME 0
#define MAX_FAIL_COUNT 8

#endif /* DEBUG && _ */

@interface DSAuthenticationManager () <UITextFieldDelegate>

@property (nonatomic, strong) NSMutableSet *failedPins;
@property (nullable, nonatomic, strong) UIAlertController *resetAlertController;
@property (nonatomic, assign) BOOL usesAuthentication;
@property (nonatomic, assign) BOOL didAuthenticate; // true if the user authenticated after this was last set to false
@property (nonatomic, assign) BOOL secureTimeUpdated;

- (void)userLockedOut;

// Low level
- (nullable NSString *)getPin:(NSError *_Nullable __autoreleasing *_Nullable)outError;
- (uint64_t)getFailCount:(NSError *_Nullable __autoreleasing *_Nullable)outError;
- (BOOL)setFailCount:(uint64_t)failCount;
- (uint64_t)getFailHeight:(NSError *_Nullable __autoreleasing *_Nullable)outError;
- (BOOL)setFailHeight:(uint64_t)failHeight;

- (void)performAuthenticationPrecheck:(void (^)(BOOL shouldContinueAuthentication,
                                                BOOL authenticated,
                                                BOOL shouldLockout,
                                                NSString *_Nullable attemptsMessage))completion;

- (void)performPinVerificationAgainstCurrentPin:(NSString *)inputPin
                                     completion:(void (^)(BOOL allowedNextVerificationRound,
                                                          BOOL authenticated,
                                                          BOOL cancelled,
                                                          BOOL shouldLockout))completion;

@end

NS_ASSUME_NONNULL_END
