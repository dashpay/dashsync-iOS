//
//  UIWindow+DSUtils.h
//  DashSync
//
//  Created by Sam Westrich on 11/25/18.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIWindow (DSUtils)

+ (nullable UIWindow *)keyWindow;
- (UIViewController *)ds_presentingViewController;

@end

NS_ASSUME_NONNULL_END
