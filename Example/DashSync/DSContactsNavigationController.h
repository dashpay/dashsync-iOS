//
//  DSContactsNavigationController.h
//  DashSync_Example
//
//  Created by Andrew Podkovyrin on 09/03/2019.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class DSChainManager, DSBlockchainUser;

@interface DSContactsNavigationController : UINavigationController

+ (instancetype)controllerWithChainManager:(DSChainManager *)chainManager blockchainUser:(DSBlockchainUser *)blockchainUser;

@end

NS_ASSUME_NONNULL_END
