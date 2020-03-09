//
//  DSWalletDetailViewController.h
//  DashSync_Example
//
//  Created by Sam Westrich on 3/6/19.
//  Copyright © 2019 Dash Core Group. All rights reserved.
//

#import <DashSync/DashSync.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DSWalletDetailViewController : UITableViewController

@property (nonatomic, strong) DSWallet *wallet;

@end

NS_ASSUME_NONNULL_END
