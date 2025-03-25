//
//  DSContactsNavigationController.m
//  DashSync_Example
//
//  Created by Andrew Podkovyrin on 09/03/2019.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import "DSContactsNavigationController.h"

#import "DSContactsTabBarViewController.h"

NS_ASSUME_NONNULL_BEGIN

@implementation DSContactsNavigationController

+ (instancetype)controllerWithChainManager:(DSChainManager *)chainManager identity:(DSIdentity *)identity {
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Contacts" bundle:nil];
    DSContactsTabBarViewController *tabbar = [storyboard instantiateInitialViewController];
    tabbar.chainManager = chainManager;
    tabbar.identity = identity;

    DSContactsNavigationController *navigation = [[DSContactsNavigationController alloc] initWithRootViewController:tabbar];
    return navigation;
}

@end

NS_ASSUME_NONNULL_END
