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

typedef NS_ENUM(NSUInteger, DSTwoPagePinAnimationDirection) {
    /// RTL
    DSTwoPagePinAnimationDirection_Forward,
    /// LTR
    DSTwoPagePinAnimationDirection_Backward,
};

@class DSTwoPagePinViewController;

@protocol DSTwoPagePinViewControllerDelegate <NSObject>

- (void)twoPagePinViewController:(DSTwoPagePinViewController *)controller
    didFinishInputFirstPageWithPin:(NSString *)inputPin;
- (void)twoPagePinViewController:(DSTwoPagePinViewController *)controller
    didFinishInputSecondPageWithPin:(NSString *)inputPin;

@end

@interface DSTwoPagePinViewController : UIViewController

@property (nullable, nonatomic, copy) NSString *firstTitleText;
@property (nullable, nonatomic, copy) NSString *firstMessageText;
@property (nullable, nonatomic, copy) NSString *secondTitleText;
@property (nullable, nonatomic, copy) NSString *secondMessageText;

@property (readonly, nonatomic) NSString *firstPin;
@property (readonly, nonatomic) NSString *secondPin;

@property (nullable, nonatomic, weak) id<DSTwoPagePinViewControllerDelegate> delegate;

- (void)firstClearAndShakePin:(void (^)(void))completion;
- (void)secondClearAndShakePin:(void (^)(void))completion;

- (void)switchFromFirstToSecondAnimation:(DSTwoPagePinAnimationDirection)animationDirection
                              completion:(void (^_Nullable)(void))completion;
- (void)switchFromSecondToFirstAnimation:(DSTwoPagePinAnimationDirection)animationDirection
                              completion:(void (^_Nullable)(void))completion;

- (void)firstClear;
- (void)secondClear;

- (void)setSecondPageVisible;

@end

NS_ASSUME_NONNULL_END
