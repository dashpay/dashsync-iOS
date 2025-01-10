//
//  DSContactsTabBarViewController.h
//  DashSync_Example
//
//  Created by Andrew Podkovyrin on 08/03/2019.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class DSChainManager, DSIdentity;


@interface DSContactsTabBarViewController : UITabBarController

@property (nonatomic, strong) DSChainManager *chainManager;
@property (nonatomic, strong) DSIdentity *identity;

@end

NS_ASSUME_NONNULL_END
