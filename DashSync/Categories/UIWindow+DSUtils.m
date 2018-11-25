//
//  UIWindow+DSUtils.m
//  DashSync
//
//  Created by Sam Westrich on 11/25/18.
//

#import "UIWindow+DSUtils.h"

@implementation UIWindow (DSUtils)

-(UIViewController*)ds_presentingViewController {
    UIViewController *topController = [self rootViewController];
    while (topController.presentedViewController && ![topController.presentedViewController isKindOfClass:[UIAlertController class]]) {
        topController = topController.presentedViewController;
    }
    if ([topController isKindOfClass:[UINavigationController class]]) {
        topController = ((UINavigationController*)topController).topViewController;
    }
    return topController;
}

@end
