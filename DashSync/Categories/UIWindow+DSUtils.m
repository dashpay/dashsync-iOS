//
//  UIWindow+DSUtils.m
//  DashSync
//
//  Created by Sam Westrich on 11/25/18.
//

#import "UIWindow+DSUtils.h"

NS_ASSUME_NONNULL_BEGIN

@implementation UIWindow (DSUtils)

- (UIViewController *)ds_presentingViewController {
    UIViewController *controller = [self rootViewController];
    return [self ds_topViewControllerWithRootViewController:controller];
}

#pragma mark - Private

- (UIViewController *)ds_topViewControllerWithRootViewController:(UIViewController *)rootViewController {
    if ([rootViewController isKindOfClass:UITabBarController.class]) {
        UITabBarController *tabBarController = (UITabBarController *)rootViewController;
        if (!tabBarController.selectedViewController || (tabBarController.selectedViewController == tabBarController)) {
            return tabBarController;
        }
        return [self ds_topViewControllerWithRootViewController:tabBarController.selectedViewController];
    }
    else if ([rootViewController isKindOfClass:UINavigationController.class]) {
        UINavigationController *navigationController = (UINavigationController *)rootViewController;
        if (!navigationController.visibleViewController || (navigationController.visibleViewController == navigationController)) {
            return navigationController;
        }
        return [self ds_topViewControllerWithRootViewController:navigationController.visibleViewController];
    }
    else if (rootViewController.presentedViewController) {
        UIViewController *presentedViewController = rootViewController.presentedViewController;
        if (presentedViewController == rootViewController) return presentedViewController;
        return [self ds_topViewControllerWithRootViewController:presentedViewController];
    }
    else {
        return rootViewController;
    }
}


@end

NS_ASSUME_NONNULL_END
