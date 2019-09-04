//
//  DSAuthenticationManager.h
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


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#define PIN_UNLOCK_TIME_KEY     @"PIN_UNLOCK_TIME"

typedef void (^PinCompletionBlock)(BOOL authenticatedOrSuccess, BOOL cancelled);
typedef void (^SeedPhraseCompletionBlock)(NSString * _Nullable seedPhrase);
typedef void (^SeedCompletionBlock)(NSData * _Nullable seed, BOOL cancelled);

typedef void (^ResetCancelHandlerBlock)(void);
typedef void (^ResetWipeHandlerBlock)(void);

extern NSString *const DSApplicationTerminationRequestNotification;

@class DSWallet,DSChain,DSTransaction;

@interface DSAuthenticationManager : NSObject

@property (nonatomic, readonly, getter=isTouchIdEnabled) BOOL touchIdEnabled; // true if touch id is enabled
@property (nonatomic, readonly, getter=isFaceIdEnabled) BOOL faceIdEnabled;
@property (nonatomic, readonly, getter=isPasscodeEnabled) BOOL passcodeEnabled; // true if device passcode is enabled
@property (nonatomic, readonly) BOOL shouldUseAuthentication; //true if the app should use authentication once it is set up
@property (nonatomic, readonly) BOOL usesAuthentication; //true if the app uses authentication and it is set up
@property (nonatomic, readonly) BOOL didAuthenticate; // true if the user authenticated after this was last set to false
@property (nonatomic ,readonly) BOOL lockedOut;
@property (nullable, nonatomic, copy) NSDictionary * userAccount; // client api user id and auth token
@property (nonatomic, readonly) NSTimeInterval secureTime; // last known time from an ssl server connection
/**
 Secure time was updated by HTTP response since app starts
 */
@property (nonatomic, readonly) BOOL secureTimeUpdated;
@property (nonatomic, readonly) NSTimeInterval lockoutWaitTime;

+ (instancetype)sharedInstance;


- (BOOL)hasPin:(NSError *_Nullable __autoreleasing *_Nullable)outError;

/**
 Set PIN without presenting any UI to the user.

 @return Returns NO in case of failure
 */
- (BOOL)setPin:(NSString *)pin;

- (void)seedWithPrompt:(NSString * _Nullable)authprompt forWallet:(DSWallet*)wallet forAmount:(uint64_t)amount forceAuthentication:(BOOL)forceAuthentication completion:(_Nullable SeedCompletionBlock)completion;//auth user,return seed
- (void)authenticateWithPrompt:(NSString * _Nullable)authprompt andTouchId:(BOOL)touchId alertIfLockout:(BOOL)alertIfLockout completion:(_Nullable PinCompletionBlock)completion; // prompt user to authenticate
- (void)setPinIfNeededWithCompletion:(void (^ _Nullable)(BOOL needed, BOOL success))completion; // prompts the user to set his pin if he has never set one before
- (void)setPinWithCompletion:(void (^ _Nullable)(BOOL success))completion; // prompts the user to set or change wallet pin and returns true if the pin was successfully set
- (void)removePin;

- (void)requestKeyPasswordForSweepCompletion:(void (^)(DSTransaction *tx, uint64_t fee, NSError *error))sweepCompletion userInfo:(NSDictionary*)userInfo completion:(void (^)(void (^sweepCompletion)(DSTransaction *tx, uint64_t fee, NSError *error),NSDictionary * userInfo, NSString * password))completion cancel:(void (^)(void))cancel;
- (NSString *)promptForAmount:(uint64_t)amount fee:(uint64_t)fee address:(NSString *)address name:(NSString * _Nullable)name memo:(NSString * _Nullable)memo isSecure:(BOOL)isSecure errorMessage:(NSString * _Nullable)errorMessage localCurrency:(NSString * _Nullable)localCurrency;

-(void)badKeyPasswordForSweepCompletion:(void (^)(void))completion cancel:(void (^)(void))cancel;

-(void)deauthenticate;

-(void)setOneTimeShouldUseAuthentication:(BOOL)shouldUseAuthentication; // you can not set this to false after it being true

-(void)showResetWalletWithWipeHandler:(_Nullable ResetWipeHandlerBlock)resetWipeHandlerBlock cancelHandler:(_Nullable ResetCancelHandlerBlock)resetCancelHandlerBlock;

@end

NS_ASSUME_NONNULL_END
