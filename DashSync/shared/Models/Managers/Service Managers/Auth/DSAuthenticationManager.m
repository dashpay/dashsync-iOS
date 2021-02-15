//
//  DSAuthenticationManager.m
//  DashSync
//
//  Created by Sam Westrich on 5/27/18.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.


#import "DSAuthenticationManager+Private.h"

#import "DSAccount.h"
#import "DSBIP39Mnemonic.h"
#import "DSBiometricsAuthenticator.h"
#import "DSChain+Protected.h"
#import "DSChainsManager.h"
#import "DSCheckpoint.h"
#import "DSDerivationPath.h"
#import "DSEventManager.h"
#import "DSMerkleBlock.h"
#import "DSPeer.h"
#import "DSPriceManager.h"
#import "DSVersionManager.h"
#import "DSWallet.h"
#import "DashSync.h"
#import "NSData+Bitcoin.h"
#import "NSDate+Utils.h"
#import "NSMutableData+Dash.h"

#if TARGET_OS_IOS
#import "DSRecoveryViewController.h"
#import "DSRequestPinViewController.h"
#import "DSSetPinViewController.h"
#import "UIWindow+DSUtils.h"
#endif

static NSString *sanitizeString(NSString *s) {
    NSMutableString *sane = [NSMutableString stringWithString:(s) ? s : @""];

    CFStringTransform((CFMutableStringRef)sane, NULL, kCFStringTransformToUnicodeName, NO);
    return sane;
}

#define SECURE_TIME_KEY @"SECURE_TIME"
#define USES_AUTHENTICATION_KEY @"USES_AUTHENTICATION"
#define PIN_KEY @"pin"
#define PIN_FAIL_COUNT_KEY @"pinfailcount"
#define PIN_FAIL_HEIGHT_KEY @"pinfailheight"
#define LOCK @"\xF0\x9F\x94\x92" // unicode lock symbol U+1F512 (utf-8)
#define REDX @"\xE2\x9D\x8C"     // unicode cross mark U+274C, red x emoji (utf-8)

#define BIOMETRIC_SPENDING_LIMIT_KEY @"SPEND_LIMIT_AMOUNT"
#define BIOMETRIC_ALLOWED_AMOUNT_LEFT_KEY @"BIOMETRIC_ALLOWED_AMOUNT_LEFT_KEY"

NSString *const DSApplicationTerminationRequestNotification = @"DSApplicationTerminationRequestNotification";

@implementation DSAuthenticationManager

+ (instancetype)sharedInstance {
    static DSAuthenticationManager *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] init];
    });
    return _sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.failedPins = [NSMutableSet set];

        NSError *error = nil;
        BOOL hasSetPin = [self hasPin:&error];
        if (error) {
            self.usesAuthentication = YES; //just to be safe
        } else {
            self.usesAuthentication = [self shouldUseAuthentication] && hasSetPin;
        }

#if TARGET_OS_IOS
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidEnterBackgroundNotification)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
#endif
    }
    return self;
}

- (void)dealloc {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

// MARK: - Helpers

// last known time from an ssl server connection
- (NSTimeInterval)secureTime {
    return [[NSUserDefaults standardUserDefaults] doubleForKey:SECURE_TIME_KEY];
}

- (void)updateSecureTime:(NSTimeInterval)secureTime {
    [[NSUserDefaults standardUserDefaults] setDouble:secureTime forKey:SECURE_TIME_KEY];
}

- (void)updateSecureTimeFromResponseIfNeeded:(NSDictionary<NSString *, NSString *> *)responseHeaders {
    NSString *date = responseHeaders[@"Date"];
    if (!date) {
        return;
    }
    NSDataDetector *dataDetector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeDate error:nil];
    NSTextCheckingResult *lastResult = [dataDetector matchesInString:date options:0 range:NSMakeRange(0, date.length)].lastObject;
    if (!lastResult) {
        return;
    }
    NSTimeInterval serverTime = [lastResult date].timeIntervalSince1970;
    if (serverTime > self.secureTime) {
        [self updateSecureTime:serverTime];
        self.secureTimeUpdated = YES;
    } else {
        //rare case
        NSTimeInterval lastCheckpointTime = [[DSChainsManager sharedInstance] mainnetManager].chain.checkpoints.lastObject.timestamp;
        NSTimeInterval lastBlockTime = [[DSChainsManager sharedInstance] mainnetManager].chain.lastSyncBlock.timestamp; //this will either be 0 or a real timestamp, both are fine for next check
        if (serverTime > lastCheckpointTime && serverTime > lastBlockTime) {
            //there was definitely an issue with serverTime at some point.
            [self updateSecureTime:serverTime];
            self.secureTimeUpdated = YES;
        }
    }
}

- (void)deauthenticate {
    if (self.usesAuthentication) {
        self.didAuthenticate = NO;
    }
}

- (void)setOneTimeShouldUseAuthentication:(BOOL)requestingShouldUseAuthentication {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSError *error = nil;
        if (!hasKeychainData(USES_AUTHENTICATION_KEY, &error)) {
            setKeychainInt(requestingShouldUseAuthentication, USES_AUTHENTICATION_KEY, NO);
        } else {
            BOOL shouldUseAuthentication = getKeychainInt(USES_AUTHENTICATION_KEY, &error);
            if (!shouldUseAuthentication && requestingShouldUseAuthentication) { //we are switching the app to use authentication in the future
                setKeychainInt(YES, USES_AUTHENTICATION_KEY, NO);
            }
        }
    });
}

- (BOOL)shouldUseAuthentication {
#if !TARGET_OS_IOS
    return NO; //disable authentication temporarily for macos
#endif
    NSError *error = nil;
    if (!hasKeychainData(USES_AUTHENTICATION_KEY, &error)) {
        return TRUE; //default true;
    } else {
        BOOL shouldUseAuthentication = getKeychainInt(USES_AUTHENTICATION_KEY, &error);
        if (!error) {
            return shouldUseAuthentication;
        } else {
            return TRUE; //default
        }
    }
}

// MARK: - Prompts

// generate a description of a transaction so the user can review and decide whether to confirm or cancel
- (NSString *)promptForAmount:(uint64_t)amount
                          fee:(uint64_t)fee
                      address:(NSString *)address
                         name:(NSString *)name
                         memo:(NSString *)memo
                     isSecure:(BOOL)isSecure
                 errorMessage:(NSString *)errorMessage
                localCurrency:(NSString *)localCurrency {
    NSParameterAssert(address);

    DSPriceManager *manager = [DSPriceManager sharedInstance];
    NSString *prompt = (isSecure && name.length > 0) ? LOCK @" " : @"";

    //BUG: XXX limit the length of name and memo to avoid having the amount clipped
    if (!isSecure && errorMessage.length > 0) prompt = [prompt stringByAppendingString:REDX @" "];
    if (name.length > 0) prompt = [prompt stringByAppendingString:sanitizeString(name)];
    if (!isSecure && prompt.length > 0) prompt = [prompt stringByAppendingString:@"\n"];
    if (!isSecure || prompt.length == 0) prompt = [prompt stringByAppendingString:address];
    if (memo.length > 0) prompt = [prompt stringByAppendingFormat:@"\n\n%@", sanitizeString(memo)];
    prompt = [prompt stringByAppendingFormat:DSLocalizedString(@"\n\n     amount %@ (%@)", nil),
                     [manager stringForDashAmount:amount - fee], [manager localCurrencyStringForDashAmount:amount - fee]];

    if (localCurrency && ![localCurrency isEqualToString:manager.localCurrencyCode]) {
        NSString *requestedAmount = [[DSPriceManager sharedInstance] fiatCurrencyString:localCurrency forDashAmount:amount];
        prompt = [prompt stringByAppendingFormat:DSLocalizedString(@"\n(local requested amount: %@)", nil), requestedAmount];
    }

    if (fee > 0) {
        prompt = [prompt stringByAppendingFormat:DSLocalizedString(@"\nnetwork fee +%@ (%@)", nil),
                         [manager stringForDashAmount:fee], [manager localCurrencyStringForDashAmount:fee]];
        prompt = [prompt stringByAppendingFormat:DSLocalizedString(@"\n         total %@ (%@)", nil),
                         [manager stringForDashAmount:amount], [manager localCurrencyStringForDashAmount:amount]];
    }

    return prompt;
}

// MARK: - Pin

- (NSTimeInterval)lockoutWaitTime {
    NSError *error = nil;
    uint64_t failHeight = [self getFailHeight:&error];
    if (error) {
        return NSIntegerMax;
    }
    uint64_t failCount = [self getFailCount:&error];
    if (error) {
        return NSIntegerMax;
    }
#if DEBUG && SPEED_UP_WAIT_TIME
    NSTimeInterval wait = failHeight + pow(6, failCount - 3) * 60.0 / 100000.0 - self.secureTime;
#else
    NSTimeInterval wait = failHeight + pow(6, failCount - 3) * 60.0 - self.secureTime;
#endif
    return wait;
}

- (void)resetAllWalletsWithWipeHandler:(void (^_Nullable)(void))wipeHandler completion:(void (^)(BOOL success))completion {
    if (![[DSChainsManager sharedInstance] hasAWallet]) {
        completion(NO);

        return;
    }
#if TARGET_OS_IOS
    DSRecoveryViewController *controller = [[DSRecoveryViewController alloc] initWithWipeHandler:wipeHandler
                                                                                      completion:completion];
    [self presentController:controller animated:YES completion:nil];
#endif
}

- (void)setPinIfNeededWithCompletion:(void (^)(BOOL needed, BOOL success))completion {
    NSError *error = nil;
    BOOL hasPin = [self hasPin:&error]; //don't put pin in memory before needed

    if (error || hasPin) {
        if (completion) {
            completion(!hasPin, NO);
        }

        return; // error reading existing pin from keychain
    }

    if (!hasPin) {
        [self setPinWithCompletion:^(BOOL success) {
            if (completion) {
                completion(YES, success);
            }
        }];
    }
}

// prompts the user to set or change their wallet pin and returns true if the pin was successfully set
- (void)setPinWithCompletion:(void (^_Nullable)(BOOL success))completion {
#if TARGET_OS_IOS
    DSSetPinViewController *alert = [[DSSetPinViewController alloc] initWithCompletion:completion];
    [self presentController:alert animated:YES completion:nil];
#else
    completion(FALSE);
#endif
}

- (void)removePin {
    //You can only remove pin if there are no wallets
    if ([[DSChainsManager sharedInstance] hasAWallet]) {
        DSLog(@"Tried to remove a pin, but wallets exist on device");
        return;
    }
    setKeychainInt(0, BIOMETRIC_ALLOWED_AMOUNT_LEFT_KEY, NO);
    setKeychainData(nil, PIN_KEY, NO);
    setKeychainData(nil, PIN_FAIL_COUNT_KEY, NO);
    setKeychainData(nil, PIN_FAIL_HEIGHT_KEY, NO);
    self.didAuthenticate = NO;
    self.usesAuthentication = NO;
}

// MARK: - Biometric Limits

// amount that can be spent using touch id without pin entry
- (uint64_t)biometricSpendingLimit {
    NSError *error = nil;
    BOOL hasASpendingLimit = hasKeychainData(BIOMETRIC_SPENDING_LIMIT_KEY, &error);
    if (error) return 0;
    if (!hasASpendingLimit) {
        if ([[NSUserDefaults standardUserDefaults] doubleForKey:BIOMETRIC_SPENDING_LIMIT_KEY]) {
            //lets migrate this when we are authenticated
            if ([self setBiometricSpendingLimitIfAuthenticated:[[NSUserDefaults standardUserDefaults] doubleForKey:BIOMETRIC_SPENDING_LIMIT_KEY]]) {
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:BIOMETRIC_SPENDING_LIMIT_KEY];

                uint64_t spendingLimit = getKeychainInt(BIOMETRIC_SPENDING_LIMIT_KEY, &error);
                if (error) return 0;

                return spendingLimit;
            }
        } else {
            return BIOMETRIC_SPENDING_LIMIT_NOT_SET;
        }
    }

    uint64_t spendingLimit = getKeychainInt(BIOMETRIC_SPENDING_LIMIT_KEY, &error);
    if (error) return 0;

    return spendingLimit;
}

- (BOOL)setBiometricSpendingLimitIfAuthenticated:(uint64_t)spendingLimit {
    if (![self didAuthenticate]) return FALSE;

    if (setKeychainInt(spendingLimit, BIOMETRIC_ALLOWED_AMOUNT_LEFT_KEY, NO)) { //we are authenticated anyways so reset this
        // use setDouble since setInteger won't hold a uint64_t
        setKeychainInt(spendingLimit, BIOMETRIC_SPENDING_LIMIT_KEY, YES);
        return TRUE;
    }
    return FALSE;
}

- (BOOL)resetSpendingLimitsIfAuthenticated {
    if (![self didAuthenticate]) return FALSE;
    uint64_t limit = self.biometricSpendingLimit;
    if (limit > 0) setKeychainInt(limit, BIOMETRIC_ALLOWED_AMOUNT_LEFT_KEY, NO);
    return TRUE;
}

- (BOOL)updateBiometricsAmountLeftAfterSpendingAmount:(uint64_t)amount {
    NSError *error = nil;
    BOOL hasAmountLeft = hasKeychainData(BIOMETRIC_ALLOWED_AMOUNT_LEFT_KEY, &error);
    if (error || !hasAmountLeft) return NO;

    uint64_t amountLeft = getKeychainInt(BIOMETRIC_ALLOWED_AMOUNT_LEFT_KEY, &error);
    if (error) return FALSE;
    if (amountLeft < amount) {
        setKeychainInt(0, BIOMETRIC_ALLOWED_AMOUNT_LEFT_KEY, NO); //require pin because this is weird
        return FALSE;
    }
    setKeychainInt(amountLeft - amount, BIOMETRIC_ALLOWED_AMOUNT_LEFT_KEY, NO);
    return TRUE;
}

- (BOOL)canUseBiometricAuthenticationForAmount:(uint64_t)amount {
    if (![self isBiometricSpendingAllowed]) return FALSE;
    NSError *error = nil;
    BOOL hasAmountLeft = hasKeychainData(BIOMETRIC_ALLOWED_AMOUNT_LEFT_KEY, &error);
    if (error || !hasAmountLeft) return NO;

    uint64_t amountLeft = getKeychainInt(BIOMETRIC_ALLOWED_AMOUNT_LEFT_KEY, &error);
    if (error) return FALSE;
    return (amount <= amountLeft);
}


// MARK: - Authentication

- (BOOL)isBiometricAuthenticationAllowed {
    if (DSBiometricsAuthenticator.isBiometricsAuthenticationEnabled == NO) {
        return NO;
    }

    NSTimeInterval pinUnlockTime = [[NSUserDefaults standardUserDefaults] doubleForKey:PIN_UNLOCK_TIME_KEY];

    return (pinUnlockTime + 7 * 24 * 60 * 60 > [NSDate timeIntervalSince1970] &&
            [self getFailCount:nil] == 0);
}

- (BOOL)isBiometricSpendingAllowed {
    return ([self isBiometricAuthenticationAllowed] && getKeychainInt(BIOMETRIC_SPENDING_LIMIT_KEY, nil) > 0);
}

- (void)authenticateUsingBiometricsOnlyWithPrompt:(NSString *_Nullable)prompt
                                       completion:(PinCompletionBlock)completion {
    [self authenticateUsingBiometricsOnlyWithPrompt:prompt
                                shouldFallbackToPin:NO
                                     alertIfLockout:NO
                                         completion:completion];
}

- (void)authenticateUsingBiometricsOnlyWithPrompt:(NSString *_Nullable)prompt
                              shouldFallbackToPin:(BOOL)shouldFallbackToPin
                                   alertIfLockout:(BOOL)alertIfLockout
                                       completion:(PinCompletionBlock)completion {
    NSAssert(self.usesAuthentication, @"Authentication is not configured");

    if (!self.usesAuthentication) { //if we don't have authentication
        completion(YES, NO, NO);
        return;
    }

    NSAssert([self isBiometricAuthenticationAllowed],
        @"Check if biometrics allowed using `isBiometricAuthenticationAllowed` method before calling this method");

    BOOL shouldPreprompt = NO;
    if (@available(iOS 11.0, *)) {
        if (DSBiometricsAuthenticator.biometryType == LABiometryTypeFaceID) {
            shouldPreprompt = YES;
        }
    }

    void (^localAuthBlock)(void) = ^{
        [self performLocalAuthenticationWithPrompt:prompt
                                        completion:^(BOOL authenticated, BOOL shouldTryAnotherMethod) {
                                            if (shouldFallbackToPin && shouldTryAnotherMethod) {
                                                [self authenticateWithPrompt:prompt
                                                    usingBiometricAuthentication:NO
                                                                  alertIfLockout:alertIfLockout
                                                                      completion:completion];
                                            } else {
                                                completion(authenticated, YES, NO);
                                            }
                                        }];
    };

    if (prompt && shouldPreprompt) {
#if TARGET_OS_IOS
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:DSLocalizedString(@"Confirm", nil)
                                                                       message:prompt
                                                                preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:DSLocalizedString(@"Cancel", nil)
                                                               style:UIAlertActionStyleCancel
                                                             handler:^(UIAlertAction *action) {
                                                                 completion(NO, NO, YES);
                                                             }];
        [alert addAction:cancelAction];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:DSLocalizedString(@"OK", nil)
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *action) {
                                                             localAuthBlock();
                                                         }];
        [alert addAction:okAction];
        [self presentController:alert animated:YES completion:nil];
#endif
    } else {
        localAuthBlock();
    }
}

- (void)seedWithPrompt:(NSString *_Nullable)authprompt forWallet:(DSWallet *)wallet forAmount:(uint64_t)amount forceAuthentication:(BOOL)forceAuthentication completion:(_Nullable SeedCompletionBlock)completion {
    NSParameterAssert(wallet);
    NSAssert([NSThread isMainThread], @"This should only be called on main thread");
    if (forceAuthentication) {
        [wallet seedWithPrompt:authprompt forAmount:amount completion:completion];
    } else {
        @autoreleasepool {
            NSString *seedPhrase = [wallet seedPhraseIfAuthenticated];
            if (seedPhrase) {
                completion([[DSBIP39Mnemonic sharedInstance] deriveKeyFromPhrase:seedPhrase withPassphrase:nil], NO);
            } else {
                [wallet seedWithPrompt:authprompt forAmount:amount completion:completion];
            }
        }
    }
}

// prompts user to authenticate with touch id or passcode
- (void)authenticateWithPrompt:(NSString *)authprompt usingBiometricAuthentication:(BOOL)usesBiometricAuthentication alertIfLockout:(BOOL)alertIfLockout completion:(PinCompletionBlock)completion {
    if (!self.usesAuthentication) { //if we don't have authentication
        completion(YES, NO, NO);
        return;
    }

    if (usesBiometricAuthentication) {
        if ([self isBiometricAuthenticationAllowed]) {
            [self authenticateUsingBiometricsOnlyWithPrompt:authprompt
                                        shouldFallbackToPin:YES
                                             alertIfLockout:alertIfLockout
                                                 completion:completion];
        } else {
            [self authenticateWithPrompt:authprompt
                usingBiometricAuthentication:NO
                              alertIfLockout:alertIfLockout
                                  completion:completion];
        }
    } else {
        // TODO explain reason when touch id is disabled after 30 days without pin unlock
        [self authenticatePinWithMessage:authprompt alertIfLockout:alertIfLockout completion:completion];
    }
}

- (void)performLocalAuthenticationWithPrompt:(NSString *)prompt
                                  completion:(void (^)(BOOL authenticated, BOOL shouldTryAnotherMethod))completion {
    [DSEventManager saveEvent:@"wallet_manager:touchid_auth"];

    [DSBiometricsAuthenticator
        performBiometricsAuthenticationWithReason:prompt.length > 0 ? prompt : @" "
                                    fallbackTitle:DSLocalizedString(@"Passcode", nil)
                                       completion:^(DSBiometricsAuthenticationResult result) {
                                           switch (result) {
                                               case DSBiometricsAuthenticationResultSucceeded: {
                                                   self.didAuthenticate = YES;
                                                   completion(YES, NO);

                                                   break;
                                               }
                                               case DSBiometricsAuthenticationResultFailed: {
                                                   setKeychainInt(0, BIOMETRIC_ALLOWED_AMOUNT_LEFT_KEY, NO); // require pin entry for next spend
                                                   completion(NO, YES);

                                                   break;
                                               }
                                               case DSBiometricsAuthenticationResultCancelled: {
                                                   completion(NO, NO);

                                                   break;
                                               }
                                           }
                                       }];
}

- (void)userLockedOut {
    NSError *error = nil;
    __unused uint64_t failHeight = [self getFailHeight:&error];
    if (error) {
        return;
    }
    uint64_t failCount = [self getFailCount:&error];
    if (error) {
        return;
    }
    NSString *message = nil;
    if (failCount < MAX_FAIL_COUNT) {
        NSTimeInterval wait = [self lockoutWaitTime];
        NSString *waitString = [NSString waitTimeFromNow:wait];
        message = [NSString stringWithFormat:DSLocalizedString(@"Try again in %@", nil), waitString];
    } else {
        message = DSLocalizedString(@"No attempts remaining", nil);
    }
#if TARGET_OS_IOS
    UIAlertController *alertController = [UIAlertController
        alertControllerWithTitle:DSLocalizedString(@"Wallet disabled", nil)
                         message:message
                  preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *resetButton = [UIAlertAction
        actionWithTitle:DSLocalizedString(@"Reset", nil)
                  style:UIAlertActionStyleDefault
                handler:^(UIAlertAction *action) {
                    [self resetAllWalletsWithWipeHandler:nil
                                              completion:^(BOOL success){
                                                  // NOP
                                              }];
                }];
    if (failCount < MAX_FAIL_COUNT) {
        UIAlertAction *okButton = [UIAlertAction
            actionWithTitle:DSLocalizedString(@"OK", nil)
                      style:UIAlertActionStyleCancel
                    handler:^(UIAlertAction *action){

                    }];
        [alertController addAction:resetButton];
        [alertController addAction:okButton]; //ok button should be on the right side as per Apple guidelines, as reset is the less desireable option

    } else {
        UIAlertAction *wipeButton = [UIAlertAction
            actionWithTitle:DSLocalizedString(@"Wipe", nil)
                      style:UIAlertActionStyleDestructive
                    handler:^(UIAlertAction *action) {
                        [self.failedPins removeAllObjects];
                        [[DSVersionManager sharedInstance] clearKeychainWalletOldData];
                        [[DashSync sharedSyncController] stopSyncAllChains];
                        for (DSChain *chain in [[DSChainsManager sharedInstance] chains]) {
                            NSManagedObjectContext *context = [NSManagedObjectContext chainContext];
                            [[DashSync sharedSyncController] wipeMasternodeDataForChain:chain inContext:context];
                            [[DashSync sharedSyncController] wipeBlockchainDataForChain:chain inContext:context];
                            [[DashSync sharedSyncController] wipeSporkDataForChain:chain inContext:context];
                            [chain unregisterAllWallets];
                        }
                        [self removePin];
                    }];
        [alertController addAction:wipeButton]; //ok button should be on the right side as per Apple guidelines, as reset is the less desireable option
        [alertController addAction:resetButton];
    }

    [self presentController:alertController animated:YES completion:nil];
#endif
}

- (void)authenticatePinWithMessage:(NSString *)message
                    alertIfLockout:(BOOL)alertIfLockout
                        completion:(PinCompletionBlock)completion {
    [self performAuthenticationPrecheck:^(BOOL shouldContinueAuthentication,
        BOOL authenticated,
        BOOL shouldLockout,
        NSString *_Nullable attemptsMessage) {
        if (shouldContinueAuthentication) {
            NSString *resultMessage;
            if (attemptsMessage != nil) {
                resultMessage = attemptsMessage;

                if (message) {
                    resultMessage = [resultMessage stringByAppendingFormat:@"\n%@", message];
                }
            } else {
                resultMessage = message;
            }
#if TARGET_OS_IOS
            DSRequestPinViewController *alert =
                [[DSRequestPinViewController alloc] initWithAuthPrompt:resultMessage
                                                        alertIfLockout:alertIfLockout
                                                            completion:completion];
            [self presentController:alert animated:YES completion:nil];
#endif
        } else {
            if (shouldLockout) {
                [self userLockedOut];
            }

            completion(authenticated, NO, NO);
        }
    }];
}

- (void)requestKeyPasswordForSweepCompletion:(void (^_Nonnull)(DSTransaction *tx, uint64_t fee, NSError *error))sweepCompletion userInfo:(NSDictionary *)userInfo completion:(void (^_Nonnull)(void (^sweepCompletion)(DSTransaction *tx, uint64_t fee, NSError *error), NSDictionary *userInfo, NSString *password))completion cancel:(void (^_Nonnull)(void))cancel {
    NSParameterAssert(sweepCompletion);
    NSParameterAssert(userInfo);
    NSParameterAssert(completion);
    NSParameterAssert(cancel);
#if TARGET_OS_IOS
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:DSLocalizedString(@"Password protected key", nil) message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *_Nonnull textField) {
        textField.secureTextEntry = true;
        textField.returnKeyType = UIReturnKeyDone;
        textField.placeholder = DSLocalizedString(@"Password", nil);
    }];
    UIAlertAction *cancelButton = [UIAlertAction
        actionWithTitle:DSLocalizedString(@"Cancel", nil)
                  style:UIAlertActionStyleCancel
                handler:^(UIAlertAction *action) {
                    cancel();
                }];
    UIAlertAction *okButton = [UIAlertAction
        actionWithTitle:DSLocalizedString(@"OK", nil)
                  style:UIAlertActionStyleDefault
                handler:^(UIAlertAction *action) {
                    NSString *password = alert.textFields[0].text;
                    completion(sweepCompletion, userInfo, password);
                }];
    [alert addAction:cancelButton];
    [alert addAction:okButton];
    [self presentController:alert animated:YES completion:nil];
#endif
}


- (void)badKeyPasswordForSweepCompletion:(void (^_Nonnull)(void))completion cancel:(void (^_Nonnull)(void))cancel {
    NSParameterAssert(completion);
    NSParameterAssert(cancel);
#if TARGET_OS_IOS
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:DSLocalizedString(@"Password protected key", nil)
                         message:DSLocalizedString(@"Bad password, try again", nil)
                  preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *cancelButton = [UIAlertAction
        actionWithTitle:DSLocalizedString(@"Cancel", nil)
                  style:UIAlertActionStyleCancel
                handler:^(UIAlertAction *action) {
                    if (cancel) completion();
                }];
    UIAlertAction *okButton = [UIAlertAction
        actionWithTitle:DSLocalizedString(@"OK", nil)
                  style:UIAlertActionStyleDefault
                handler:^(UIAlertAction *action) {
                    if (completion) completion();
                }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.secureTextEntry = true;
        textField.placeholder = @"Password";
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        textField.borderStyle = UITextBorderStyleRoundedRect;
        textField.returnKeyType = UIReturnKeyDone;
    }];
    [alert addAction:okButton];
    [alert addAction:cancelButton];
    [self presentController:alert animated:YES completion:nil];
#endif
}

#pragma mark - Low Level

- (BOOL)setupNewPin:(NSString *)pin {
    NSParameterAssert(pin);
    if (!pin) {
        return NO;
    }

    BOOL success = [self setPin:pin];
    if (!success) {
        return NO;
    }

    self.usesAuthentication = YES;
    self.didAuthenticate = YES;
    [[NSUserDefaults standardUserDefaults] setDouble:[NSDate timeIntervalSince1970]
                                              forKey:PIN_UNLOCK_TIME_KEY];

    return YES;
}

- (BOOL)hasPin:(NSError *_Nullable __autoreleasing *_Nullable)outError {
    NSError *error = nil;
    BOOL hasPin = hasKeychainData(PIN_KEY, &error);
    if (error) {
        if (outError) {
            *outError = error;
        }

        return YES;
    }

    return hasPin;
}

- (nullable NSString *)getPin:(NSError *_Nullable __autoreleasing *_Nullable)outError {
    NSError *error = nil;
    NSString *pin = getKeychainString(PIN_KEY, &error);
    if (error) {
        if (outError) {
            *outError = error;
        }

        return nil;
    }

    return pin;
}

- (BOOL)setPin:(NSString *)pin {
    NSParameterAssert(pin);
    if (!pin) {
        return NO;
    }

    return setKeychainString(pin, PIN_KEY, NO);
}

- (uint64_t)getFailCount:(NSError *_Nullable __autoreleasing *_Nullable)outError {
    NSError *error = nil;
    uint64_t failCount = getKeychainInt(PIN_FAIL_COUNT_KEY, &error);
    if (error) {
        if (outError) {
            *outError = error;
        }

        return UINT64_MAX;
    }

    return failCount;
}

- (BOOL)setFailCount:(uint64_t)failCount {
    return setKeychainInt(failCount, PIN_FAIL_COUNT_KEY, NO);
}

- (uint64_t)getFailHeight:(NSError *_Nullable __autoreleasing *_Nullable)outError {
    NSError *error = nil;
    // When was the last time we failed?
    uint64_t failHeight = getKeychainInt(PIN_FAIL_HEIGHT_KEY, &error);
    if (error) {
        if (outError) {
            *outError = error;
        }

        return UINT64_MAX;
    }

    return failHeight;
}

- (BOOL)setFailHeight:(uint64_t)failHeight {
    return setKeychainInt(failHeight, PIN_FAIL_HEIGHT_KEY, NO);
}

- (void)removePinForced {
    setKeychainInt(0, BIOMETRIC_ALLOWED_AMOUNT_LEFT_KEY, NO);
    setKeychainData(nil, PIN_KEY, NO);
    setKeychainData(nil, PIN_FAIL_COUNT_KEY, NO);
    setKeychainData(nil, PIN_FAIL_HEIGHT_KEY, NO);
}

- (void)performAuthenticationPrecheck:(void (^)(BOOL shouldContinueAuthentication,
                                          BOOL authenticated,
                                          BOOL shouldLockout,
                                          NSString *_Nullable attemptsMessage))completion {
    //authentication logic is as follows
    //you have 3 failed attempts initially
    //after that you get locked out once immediately with a message saying
    //then you have 4 attempts with exponentially increasing intervals to get your password right

    NSError *error = nil;
    NSString *pin = [self getPin:&error];
    if (error) { // error reading from keychain
        completion(NO, NO, NO, nil);

        return;
    }

    NSAssert(error == nil, @"Error is not handled");

    if (pin.length != PIN_LENGTH) {
        // backward compatibility
        [self setPinWithCompletion:^(BOOL success) {
            completion(NO, success, NO, nil);
        }];

        return;
    }

    uint64_t failCount = [self getFailCount:&error];
    if (error) { // error reading from keychain
        completion(NO, NO, NO, nil);

        return;
    }

    NSAssert(error == nil, @"Error is not handled");

    //// Logic explanation

    NSString *attemptsMessage = nil;

    //  If we have failed 3 or more times
    if (failCount >= MAX_FAIL_COUNT) {
        if (completion) {
            completion(NO, NO, YES, nil);
        }

        return;
    } else if (failCount >= ALLOWED_FAIL_COUNT) {
        // When was the last time we failed?
        __unused uint64_t failHeight = [self getFailHeight:&error];

        if (error) { // error reading from keychain
            completion(NO, NO, NO, nil);

            return;
        }

        NSAssert(error == nil, @"Error is not handled");

        const CGFloat lockoutTimeLeft = [self lockoutWaitTime];
        DSLog(@"locked out for %f more seconds", lockoutTimeLeft);

        if (lockoutTimeLeft > 0) { // locked out
            completion(NO, NO, YES, nil);

            return;
        } else {
            //no longer locked out, give the user a try
            attemptsMessage = [NSString localizedStringWithFormat:
                                            DSLocalizedString(@"%ld attempt(s) remaining", @"#bc-ignore!"),
                                        (long)(MAX_FAIL_COUNT - failCount)];
        }
    }

    completion(YES, NO, NO, attemptsMessage);
}


- (void)performPinVerificationAgainstCurrentPin:(NSString *)inputPin
                                     completion:(void (^)(BOOL allowedNextVerificationRound,
                                                    BOOL authenticated,
                                                    BOOL cancelled,
                                                    BOOL shouldLockout))completion {
    NSError *error = nil;
    const uint64_t failCount = [self getFailCount:&error];
    if (error) { // error reading from keychain
        completion(NO, NO, NO, NO);

        return;
    }

    NSAssert(error == nil, @"Error is not handled");
    NSString *pin = [self getPin:&error];
    if (error) { // error reading from keychain
        completion(NO, NO, NO, NO);

        return;
    }

    NSAssert(error == nil, @"Error is not handled");
    // count unique attempts before checking success
    if (![self.failedPins containsObject:inputPin]) {
        [self setFailCount:failCount + 1];
    }

    if ([inputPin isEqual:pin]) { // successful pin attempt
        [self.failedPins removeAllObjects];
        self.didAuthenticate = YES;

        [self setFailCount:0];
        [self setFailHeight:0];

        [self resetSpendingLimitsIfAuthenticated];
        [[NSUserDefaults standardUserDefaults] setDouble:[NSDate timeIntervalSince1970]
                                                  forKey:PIN_UNLOCK_TIME_KEY];

        completion(NO, YES, NO, NO);

        return;
    }

    if (![self.failedPins containsObject:inputPin]) {
        [self.failedPins addObject:inputPin];

        if (self.secureTime > [self getFailHeight:nil]) {
            [self setFailHeight:self.secureTime];
        }

        if (failCount >= ALLOWED_FAIL_COUNT) {
            completion(NO, NO, NO, YES);

            return;
        }
    }

    completion(YES, NO, NO, NO);
}

#pragma mark - Notifications

- (void)applicationDidEnterBackgroundNotification {
    // lockdown the app
    self.didAuthenticate = NO;
#if TARGET_OS_IOS
    [UIApplication sharedApplication].applicationIconBadgeNumber = 0; // reset app badge number
#endif
}

#pragma mark - Private

#if TARGET_OS_IOS
- (void)presentController:(UIViewController *)controller
                 animated:(BOOL)animated
               completion:(void (^_Nullable)(void))completion {
    UIWindow *window = [[UIApplication sharedApplication] keyWindow];
    UIViewController *presentingController = [window ds_presentingViewController];
    NSParameterAssert(presentingController);
    [presentingController presentViewController:controller animated:animated completion:completion];
}
#endif

@end
