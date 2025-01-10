//
//  DSIdentityActionsViewController.h
//  DashSync_Example
//
//  Created by Sam Westrich on 8/16/18.
//  Copyright © 2018 Dash Core Group. All rights reserved.
//

#import <DashSync/DashSync.h>
#import <UIKit/UIKit.h>

@interface DSIdentityActionsViewController : UITableViewController

@property (nonatomic, strong) DSChainManager *chainManager;
@property (nonatomic, strong) DSIdentity *identity;

@end
