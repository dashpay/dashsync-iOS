//
//  DSActionsViewController.h
//  DashSync_Example
//
//  Created by Sam Westrich on 12/5/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import <DashSync/DashSync.h>

NS_ASSUME_NONNULL_BEGIN

@interface DSActionsViewController : UITableViewController

@property (nonatomic, strong) DSChainManager *chainManager;

@end

NS_ASSUME_NONNULL_END
