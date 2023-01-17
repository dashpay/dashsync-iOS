//
//  UIWindow+DSUtils.m
//  DashSync
//
//  Created by Sam Westrich on 11/25/18.
//

#import "UIWindow+DSUtils.h"

NS_ASSUME_NONNULL_BEGIN

@implementation UIWindow (DSUtils)

+ (nullable UIWindow *)keyWindow {
    if (@available(iOS 15.0, *)) {
        UIApplication *app = [UIApplication sharedApplication];
        NSSet<UIScene *> *connectedScenes = app.connectedScenes;

        for (UIScene *scene in connectedScenes) {
            if ([scene isKindOfClass:UIWindowScene.class]) {
                UIWindowScene *windowScene = (UIWindowScene *)scene;
                UIWindow *window = windowScene.keyWindow;
                if (window) return window;
            }
        }
    } else if (@available(iOS 13.0, *)) {
        UIApplication *app = [UIApplication sharedApplication];
        NSSet<UIScene *> *connectedScenes = app.connectedScenes;
        
        for (UIScene *scene in connectedScenes) {
            if ([scene isKindOfClass:UIWindowScene.class]) {
                UIWindowScene *windowScene = (UIWindowScene *)scene;
                for (UIWindow *window in windowScene.windows) {
                    if (window.keyWindow) return window;
                }
            }
        }
    } else {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        return [[UIApplication sharedApplication] keyWindow];
        #pragma clang diagnostic pop
    }

    return nil;
}

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
    } else if ([rootViewController isKindOfClass:UINavigationController.class]) {
        UINavigationController *navigationController = (UINavigationController *)rootViewController;
        if (!navigationController.visibleViewController || (navigationController.visibleViewController == navigationController)) {
            return navigationController;
        }
        return [self ds_topViewControllerWithRootViewController:navigationController.visibleViewController];
    } else if (rootViewController.presentedViewController) {
        UIViewController *presentedViewController = rootViewController.presentedViewController;
        if (presentedViewController == rootViewController) return presentedViewController;
        return [self ds_topViewControllerWithRootViewController:presentedViewController];
    } else {
        return rootViewController;
    }
}


@end

NS_ASSUME_NONNULL_END
